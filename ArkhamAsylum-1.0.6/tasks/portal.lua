local plugin_label = 'arkham_asylum' -- change to your plugin name

local utils = require "core.utils"
local settings = require 'core.settings'
local tracker = require 'core.tracker'

local status_enum = {
    IDLE = 'idle',
    EXPLORING = 'exploring',
    RESETING = 'reseting explorer',
    INTERACTING = 'interacting with portal',
    WALKING = 'walking to portal'
}
local task = {
    name = 'portal', -- change to your choice of task name
    status = status_enum['IDLE'],
    portal_found = false,
    portal_exit = -1
}
-- Cache portal scan to avoid double actor iteration per frame (shouldExecute + Execute)
local _portal_cache = nil
local _portal_cache_time = -1
local _portal_cache_duration = 0.01 -- 10ms, well within a single frame

-- Back-portal blacklist: Prefab_Portal_Dungeon_Generic is the actor name for both the
-- next-floor portal and the previous-floor portal. After teleporting, the player spawns
-- on top of the back-portal. We snapshot the spawn position on world change and exclude
-- any portal within BACK_PORTAL_RADIUS of it for the duration of the new world.
local current_world_name = nil
local back_portal_pos = nil
local portal_just_used = false
local portal_used_time = -math.huge
local PORTAL_TRANSITION_WINDOW = 5  -- seconds to accept world-change as portal-induced
-- The game offsets the spawn 4-7 units from the back-portal so the player doesn't
-- immediately re-trigger it. Confirmed via log: spawns at distances 4.9 and 6.1 from
-- the back-portal. Use 10 to safely catch them without snagging a descend portal,
-- which is typically 30+ units away on multi-portal floors.
local BACK_PORTAL_RADIUS = 10
-- Portal task engages at a larger radius than settings.check_distance (12). The explorer
-- doesn't seek portal actors directly — it picks walkable-tile frontiers — so the bot can
-- circle a portal at distance 13–28 forever without crossing the 12-unit threshold.
-- Once a non-back portal is visible within this radius, take it.
local PORTAL_DETECTION_RADIUS = 25

local function update_back_portal_tracking()
    if not utils.player_in_pit() then
        if current_world_name ~= nil then
            console.print("[portal] left pit, clearing back-portal state")
        end
        current_world_name = nil
        back_portal_pos = nil
        portal_just_used = false
        return
    end
    local world = get_current_world()
    if not world then return end
    local wname = world:get_name()
    if wname == current_world_name then
        -- Drop stale portal_just_used flag if no transition occurred (interaction failed?)
        if portal_just_used and (get_time_since_inject() - portal_used_time) > PORTAL_TRANSITION_WINDOW then
            console.print("[portal] portal_just_used timed out without world change, clearing")
            portal_just_used = false
        end
        return
    end
    -- World changed
    if portal_just_used and (get_time_since_inject() - portal_used_time) < PORTAL_TRANSITION_WINDOW then
        local pos = get_player_position()
        if pos then
            back_portal_pos = vec3:new(pos:x(), pos:y(), pos:z())
            console.print(string.format("[portal] arrived in '%s' via portal — back-portal blacklisted near (%.1f,%.1f) radius=%.0f",
                wname, pos:x(), pos:y(), BACK_PORTAL_RADIUS))
        end
    else
        back_portal_pos = nil
        console.print(string.format("[portal] entered '%s' (not via portal) — no back-portal blacklist", wname))
    end
    current_world_name = wname
    portal_just_used = false
    -- Invalidate cache: actor pointers from previous world are no longer relevant
    _portal_cache = nil
    _portal_cache_time = -1
end

local function is_back_portal(actor)
    if not back_portal_pos then return false end
    local pos = actor:get_position()
    return utils.distance(pos, back_portal_pos) < BACK_PORTAL_RADIUS
end

-- Periodic debug dump of all Portal-named actors so we can see exactly what the scan
-- finds and why each is filtered. Throttled to once every 2 seconds.
local _last_portal_dump = -math.huge
local PORTAL_DUMP_INTERVAL = 2

local get_portal = function ()
    update_back_portal_tracking()
    local now = get_time_since_inject()
    if now - _portal_cache_time < _portal_cache_duration then
        return _portal_cache
    end
    local local_player = get_local_player()
    if not local_player then return end
    local player_pos = get_player_position()
    -- get_all_actors covers non-ally actors too — Batmobile's traversal scan uses this
    local actors = actors_manager:get_all_actors()
    local found_portal = nil
    local dump_now = (now - _last_portal_dump) >= PORTAL_DUMP_INTERVAL
    for _, actor in pairs(actors) do
        local actor_name = actor:get_skin_name()
        if actor_name and actor_name:match('Portal')
            -- Light_NoShadows_Portal_Dungeon_Generic is a decorative lighting actor
            -- that mirrors the portal's position; never use it for pathing.
            and not actor_name:match('Light_NoShadows')
        then
            local interactable = actor:is_interactable()
            local apos = actor:get_position()
            local dist = utils.distance(player_pos, actor)
            local is_back = is_back_portal(actor)
            if dump_now then
                console.print(string.format(
                    "[portal] candidate name=%s interactable=%s dist=%.1f pos=(%.1f,%.1f) back=%s",
                    actor_name, tostring(interactable), dist, apos:x(), apos:y(), tostring(is_back)
                ))
            end
            -- Match any Portal_Dungeon_* variant (Generic, Sightless_Skov, etc.).
            -- Safe to be permissive now that get_closeby_node handles non-walkable
            -- portal meshes — if the variant ever turns out to be undesirable, the
            -- back-portal blacklist still excludes ones we just came through.
            if interactable and actor_name:match('Portal_Dungeon') and not is_back
                and dist <= PORTAL_DETECTION_RADIUS and found_portal == nil
            then
                found_portal = actor
            end
        end
    end
    if dump_now then _last_portal_dump = now end
    if found_portal ~= nil then
        _portal_cache = found_portal
        _portal_cache_time = now
        return found_portal
    end
    _portal_cache = nil
    _portal_cache_time = now
    return nil
end
task.shouldExecute = function ()
    return utils.player_in_pit() and
        (get_portal() ~= nil or task.portal_found or
        task.portal_exit + 1 >= get_time_since_inject())
end
-- Track which portal position we last issued a long-path to, so we don't recompute
-- the uncapped A* every frame. Also track time of last issue so we can re-issue if
-- the long-path navigation ended without reaching the portal.
local _long_path_target = nil
local _last_path_issue = -math.huge
local PATH_RETRY_INTERVAL = 2  -- seconds; if long-path stops navigating, retry no more often than this

task.Execute = function ()
    local local_player = get_local_player()
    if not local_player then return end
    orbwalker.set_clear_toggle(true)
    local portal = get_portal()
    if portal == nil then
        if task.portal_found then
            task.portal_found = false
            task.status = status_enum['RESETING']
            task.portal_exit = get_time_since_inject()
            _long_path_target = nil
            BatmobilePlugin.stop_long_path(plugin_label)
            BatmobilePlugin.reset(plugin_label)
            return
        end
    elseif utils.distance(local_player, portal) > 2 then
        BatmobilePlugin.pause(plugin_label)
        BatmobilePlugin.update(plugin_label)
        local portal_pos = portal:get_position()
        local now = get_time_since_inject()
        -- Re-issue long-path when:
        --   1. No path target set yet
        --   2. Portal position changed (shouldn't happen, but defensive)
        --   3. Long-path navigation has stopped (path completed or got cleared) and we
        --      still aren't within interact range. Without this check we end up paused
        --      forever staring at a portal we already half-walked toward.
        -- Throttle (3) to PATH_RETRY_INTERVAL so we don't burn get_closeby_node CPU.
        local need_repath = false
        if _long_path_target == nil then
            need_repath = true
        elseif utils.distance(portal_pos, _long_path_target) > 3 then
            need_repath = true
        elseif not BatmobilePlugin.is_long_path_navigating()
            and (now - _last_path_issue) > PATH_RETRY_INTERVAL
        then
            console.print('[portal] long-path navigation ended but still ' ..
                string.format('%.1f', utils.distance(local_player, portal)) ..
                ' from portal — retrying')
            need_repath = true
        end
        if need_repath then
            local approach = BatmobilePlugin.get_closeby_node(plugin_label, portal_pos, 5)
            if approach == nil then
                console.print('[portal] no walkable approach within 5 of portal — releasing')
                BatmobilePlugin.stop_long_path(plugin_label)
                _long_path_target = nil
                task.status = status_enum['IDLE']
                return
            end
            console.print(string.format(
                "[portal] long_path to approach (%.1f,%.1f) for portal at (%.1f,%.1f) dist=%.1f",
                approach:x(), approach:y(), portal_pos:x(), portal_pos:y(),
                utils.distance(local_player, portal)
            ))
            local started = BatmobilePlugin.navigate_long_path(plugin_label, approach)
            if started == false then
                console.print('[portal] long_path FAILED — approach unreachable, releasing')
                BatmobilePlugin.stop_long_path(plugin_label)
                _long_path_target = nil
                task.status = status_enum['IDLE']
                return
            end
            _long_path_target = portal_pos
            _last_path_issue = now
        end
        BatmobilePlugin.move(plugin_label)
        task.status = status_enum['WALKING']
    else
        task.portal_found = true
        portal_just_used = true
        portal_used_time = get_time_since_inject()
        _long_path_target = nil
        BatmobilePlugin.stop_long_path(plugin_label)
        interact_object(portal)
        task.status = status_enum['INTERACTING']
    end
end

return task
