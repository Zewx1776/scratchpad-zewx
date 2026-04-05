local utils = require "core.utils"
local tracker = require "core.tracker"
local settings = require "core.settings"
local enums = require "data.enums"
local perf = require "core.perf"
local helltide_explorer = require "core.helltide_explorer"

local found_chest = nil
local found_chest_position = nil -- cached position so we can navigate even when actor unloads
local found_silent_chest_position = nil
local found_ore = nil
local found_herb = nil

-- Remembered chests: chests we saw but couldn't afford at the time
-- Key: "name_x_y" to deduplicate, Value: { name, cost, position (vec3), discovered_at }
local remembered_chests = {}
local remembered_chest_target = nil -- the key of the chest we're currently navigating to

local plugin_label = "helltide_revamped"
local was_dead = false
local ni = 1
local last_target_ni = nil -- track which waypoint we last sent to Batmobile to avoid redundant set_target calls
local WAYPOINT_LOOKAHEAD = 5 -- skip ahead 5 waypoints (~20m) so Batmobile gets a real long-distance target
local WAYPOINT_ARRIVAL_DIST = 8 -- consider waypoints "reached" within 8m — prevents stalling on exact points
local WAYPOINT_MAX_DIST = 50 -- if target waypoint is further than this, re-snap to nearest
local PATROL_STUCK_TIMEOUT = 10 -- seconds without progress before switching to free explore
local patrol_stuck_time = nil
local patrol_stuck_pos = nil
local patrol_free_explore = false
local patrol_free_explore_start = nil -- time when we entered free-explore mode

local explorer_last_target        = nil  -- tracks current long-path target so we detect changes
local explorer_path_complete_time = nil  -- wall-clock when navigate_long_path last stopped (for cooldown)
local explorer_came_from_combat   = false -- set when kill_monsters yields back to explore

local TRAVERSAL_RECOVERY_TIMEOUT  = 15 -- seconds in free-explore before clearing traversal blacklist
local TRAVERSAL_RECOVERY_COOLDOWN = 25 -- minimum seconds between recovery attempts
local traversal_recovery_time = nil    -- wall-clock of last triggered recovery

-- ============================================================
-- Movement helpers: BatmobilePlugin with pathfinder fallback
-- ============================================================

local function move_to(target, disable_spell)
    if BatmobilePlugin then
        BatmobilePlugin.pause(plugin_label)
        BatmobilePlugin.set_target(plugin_label, target, disable_spell or false)
        BatmobilePlugin.update(plugin_label)
        BatmobilePlugin.move(plugin_label)
    else
        local pos = target
        if type(target) ~= "userdata" or (target.get_position and target:get_position()) then
            if target.get_position then
                pos = target:get_position()
            end
        end
        pathfinder.request_move(pos)
    end
end

local function patrol_move(waypoint)
    if BatmobilePlugin then
        BatmobilePlugin.resume(plugin_label)
        BatmobilePlugin.set_target(plugin_label, waypoint, false)
        BatmobilePlugin.update(plugin_label)
        BatmobilePlugin.move(plugin_label)
    else
        pathfinder.request_move(waypoint)
    end
end

-- Navigate long-range: Batmobile resumed so it handles traversals + pathfinding
-- If Batmobile can't path to the target (unreachable, e.g. on a cliff), enter
-- free-explore mode so Batmobile discovers traversals on its own.
local navigate_to_stuck_time = nil
local navigate_to_free_explore = false -- when true, don't set custom target
local navigate_to_free_explore_start = nil -- time when we entered free-explore

local try_traversal_recovery  -- forward declaration; defined after reset_navigate_state

local navigate_to_debug_time = 0
local navigate_to_start_pos = nil -- position when stuck timer started

local function navigate_to(target)
    perf.start("navigate_to")
    if BatmobilePlugin then
        BatmobilePlugin.resume(plugin_label)
        local now = get_time_since_inject()
        local player_pos = get_player_position()

        -- Throttled debug every 1s
        local should_log = (now - navigate_to_debug_time > 1)
        if should_log then
            navigate_to_debug_time = now
            local stuck_elapsed = navigate_to_stuck_time and (now - navigate_to_stuck_time) or 0
            local moved = navigate_to_start_pos and player_pos:dist_to(navigate_to_start_pos) or 0
            console.print(string.format("[NAV] mode=%s stuck=%.1fs moved=%.1f paused=%s done=%s",
                navigate_to_free_explore and "FREE_EXPLORE" or "CUSTOM_TARGET",
                stuck_elapsed, moved,
                tostring(BatmobilePlugin.is_paused()),
                tostring(BatmobilePlugin.is_done())))
        end

        if navigate_to_free_explore then
            -- Track how long we've been in free-explore
            if navigate_to_free_explore_start == nil then
                navigate_to_free_explore_start = now
            end

            BatmobilePlugin.update(plugin_label)
            BatmobilePlugin.move(plugin_label)

            -- If stuck in free-explore too long, clear traversal blacklist so Batmobile
            -- can use a nearby traversal to escape the platform
            if now - navigate_to_free_explore_start > TRAVERSAL_RECOVERY_TIMEOUT then
                if try_traversal_recovery(now) then
                    navigate_to_free_explore_start = now  -- reset so we don't spam-call
                end
            end

            -- Check if player has actually moved significantly from where we got stuck
            if navigate_to_start_pos and player_pos:dist_to(navigate_to_start_pos) > 15 then
                console.print("[NAV] Moved >15 units in free explore, re-trying target")
                navigate_to_free_explore = false
                navigate_to_stuck_time = nil
                navigate_to_start_pos = nil
                navigate_to_free_explore_start = nil
            end
            perf.stop("navigate_to")
            return
        end

        -- Normal mode: set custom target
        BatmobilePlugin.set_target(plugin_label, target, false)
        BatmobilePlugin.update(plugin_label)
        BatmobilePlugin.move(plugin_label)

        -- Detect stuck by actual position change (not speed — speed spikes from failed pathing)
        if navigate_to_stuck_time == nil then
            navigate_to_stuck_time = now
            navigate_to_start_pos = player_pos
        else
            local dist_moved = player_pos:dist_to(navigate_to_start_pos)
            if dist_moved > 5 then
                -- Actually made real progress (not just drift), reset timer
                navigate_to_stuck_time = now
                navigate_to_start_pos = player_pos
            elseif now - navigate_to_stuck_time > 10 then
                -- Hasn't moved >5 units in 10 seconds — stuck (allow time for traversal routing)
                console.print(string.format("[NAV] Stuck 10s (moved only %.1f), switching to FREE_EXPLORE", dist_moved))
                BatmobilePlugin.clear_target(plugin_label)
                navigate_to_free_explore = true
                navigate_to_stuck_time = nil
                -- Keep navigate_to_start_pos so free explore can detect when we've moved away
            end
        end
    else
        local pos = target
        if target.get_position then
            pos = target:get_position()
        end
        pathfinder.request_move(pos)
    end
    perf.stop("navigate_to")
end

-- Reset navigate_to state (call when switching away from navigate_to usage)
local function reset_navigate_state()
    navigate_to_stuck_time = nil
    navigate_to_start_pos = nil
    navigate_to_free_explore = false
    navigate_to_free_explore_start = nil
end

-- Traversal recovery: called when the player has been stuck in free-explore mode
-- for TRAVERSAL_RECOVERY_TIMEOUT seconds without moving.  Clears Batmobile's
-- traversal blacklist + failed-target so a nearby traversal can be selected,
-- then navigates to it explicitly.  Returns true if recovery was triggered.
try_traversal_recovery = function(now)
    if traversal_recovery_time and now - traversal_recovery_time < TRAVERSAL_RECOVERY_COOLDOWN then
        return false
    end
    if not BatmobilePlugin then return false end

    console.print("[TRAVERSAL RECOVERY] Stuck on platform — clearing traversal blacklist + failed-target")
    if BatmobilePlugin.clear_traversal_blacklist then
        BatmobilePlugin.clear_traversal_blacklist(plugin_label)
    end

    -- Find nearest Traversal_Gizmo actor and navigate to it so Batmobile
    -- can interact with it and carry the player to the other side.
    local actors = get_cached_actors()
    local nearest_trav = nil
    local nearest_dist = math.huge
    for _, actor in pairs(actors) do
        if actor:get_skin_name():match('[Tt]raversal_Gizmo') then
            local d = utils.distance_to(actor:get_position())
            if d < nearest_dist then
                nearest_trav = actor
                nearest_dist = d
            end
        end
    end

    BatmobilePlugin.resume(plugin_label)
    if nearest_trav and nearest_dist < 50 then
        console.print(string.format("[TRAVERSAL RECOVERY] Moving to %s dist=%.1f",
            nearest_trav:get_skin_name(), nearest_dist))
        BatmobilePlugin.set_target(plugin_label, nearest_trav:get_position(), false)
    else
        console.print("[TRAVERSAL RECOVERY] No traversal nearby — resetting Batmobile explorer")
        BatmobilePlugin.reset(plugin_label)
    end
    BatmobilePlugin.update(plugin_label)
    BatmobilePlugin.move(plugin_label)

    traversal_recovery_time = now
    return true
end

local function clear_movement()
    reset_navigate_state()
    if BatmobilePlugin then
        BatmobilePlugin.clear_target(plugin_label)
    end
end

-- ============================================================

local helltide_state = {
    INIT = "INIT",
    EXPLORE_HELLTIDE = "EXPLORE_HELLTIDE",
    MOVING_TO_TRAVERSAL = "MOVING_TO_TRAVERSAL",
    MOVING_TO_PYRE = "MOVING_TO_PYRE",
    INTERACT_PYRE = "INTERACT_PYRE",
    STAY_NEAR_PYRE = "STAY_NEAR_PYRE",
    MOVING_TO_HELLTIDE_CHEST = "MOVING_TO_HELLTIDE_CHEST",
    MOVING_TO_SILENT_CHEST = "MOVING_TO_SILENT_CHEST",
    MOVING_TO_ORE = "MOVING_TO_ORE",
    MOVING_TO_HERB = "MOVING_TO_HERB",
    MOVING_TO_SHRINE = "MOVING_TO_SHRINE",
    MOVING_TO_CHAOS_RIFT = "MOVING_TO_CHAOS_RIFT",
    INTERACT_CHAOS_RIFT = "INTERACT_CHAOS_RIFT",
    STAY_NEAR_CHAOS_RIFT = "STAY_NEAR_CHAOS_RIFT",
    CHASE_GOBLIN = "CHASE_GOBLIN",
    KILL_MONSTERS = "KILL_MONSTERS",
    MOVING_TO_REMEMBERED_CHEST = "MOVING_TO_REMEMBERED_CHEST",
    BACK_TO_TOWN = "BACK_TO_TOWN"
}

-- DEBUG: scan for all chest actors every 2 seconds
local last_chest_debug_time = 0
local function debug_chest_scan()
    local now = get_time_since_inject()
    if now - last_chest_debug_time < 2 then return end
    last_chest_debug_time = now

    local current_cinders = get_helltide_coin_cinders()
    local actors = actors_manager:get_all_actors()
    local found_any = false

    for _, actor in pairs(actors) do
        local skin = actor:get_skin_name()
        for chest_name, cost in pairs(enums.chest_types) do
            if skin:match(chest_name) then
                local dist = utils.distance_to(actor:get_position())
                local interactable = actor:is_interactable()
                console.print("[CHEST DEBUG] " .. chest_name .. " | dist: " .. string.format("%.1f", dist) .. " | interactable: " .. tostring(interactable) .. " | cinders: " .. current_cinders .. "/" .. cost)
                found_any = true
            end
        end
    end

    if not found_any and current_cinders >= 75 then
        console.print("[CHEST DEBUG] No chest actors in actor list | cinders: " .. current_cinders)
    end
end

-- Cached actor list: get_all_actors() is expensive, share one snapshot across all
-- find_closest_target() and scan_and_remember_chests() calls within the same frame.
local cached_actors = nil
local cached_actors_time = 0
local ACTOR_CACHE_TTL = 0.5

local function get_cached_actors()
    local now = get_time_since_inject()
    if cached_actors == nil or now - cached_actors_time >= ACTOR_CACHE_TTL then
        perf.inc("actor_cache_miss")
        perf.start("get_all_actors")
        cached_actors = actors_manager:get_all_actors()
        perf.stop("get_all_actors")
        cached_actors_time = now
    else
        perf.inc("actor_cache_hit")
    end
    return cached_actors
end

local function find_closest_target(name)
    perf.inc("find_closest_target")
    local actors = get_cached_actors()
    local closest_target = nil
    local closest_distance = math.huge

    for _, actor in pairs(actors) do
        if actor:get_skin_name():match(name) then
            local actor_pos = actor:get_position()
            local distance = utils.distance_to(actor_pos)
            if distance < closest_distance then
                closest_target = actor
                closest_distance = distance
            end
        end
    end

    if closest_target then
        return closest_target
    end
    return nil
end

local function find_closest_waypoint_index(waypoints)
    local index = nil
    local closest_coordinate = 10000

    for i, coordinate in ipairs(waypoints) do
        local d = utils.distance_to(coordinate)
        if d < closest_coordinate then
            closest_coordinate = d
            index = i
        end
    end
    return index
end

local function load_waypoints(file)
    if file == "menestad" then
        tracker.waypoints = require("waypoints.menestad")
        console.print("Loaded waypoints: menestad")
    elseif file == "marowen" then
        tracker.waypoints = require("waypoints.marowen")
        console.print("Loaded waypoints: marowen")
    elseif file == "ironwolfs" then
        tracker.waypoints = require("waypoints.ironwolfs")
        console.print("Loaded waypoints: ironwolfs")
    elseif file == "wejinhani" then
        tracker.waypoints = require("waypoints.wejinhani")
        console.print("Loaded waypoints: wejinhani")
    elseif file == "jirandai" then
        tracker.waypoints = require("waypoints.jirandai")
        console.print("Loaded waypoints: jirandai")
    else
        console.print("No waypoints loaded")
    end
end

local function check_and_load_waypoints()
    for _, tp in ipairs(enums.helltide_tps) do
        if utils.player_in_region(tp.region) then
            load_waypoints(tp.file)
            return
        end
    end
end

local function randomize_waypoint(waypoint, max_offset)
    max_offset = max_offset or 1.5
    local random_x = math.random() * max_offset * 2 - max_offset
    local random_y = math.random() * max_offset * 2 - max_offset

    local randomized_point = vec3:new(
        waypoint:x() + random_x,
        waypoint:y() + random_y,
        waypoint:z()
    )

    randomized_point = utility.set_height_of_valid_position(randomized_point)
    if utility.is_point_walkeable(randomized_point) then
        return randomized_point
    else
        return waypoint
    end
end

-- Build a dedup key from chest name + approximate position (rounded to 1m)
local function chest_key(name, pos)
    return string.format("%s_%d_%d", name, math.floor(pos:x()), math.floor(pos:y()))
end

-- Remember a chest we can see but can't afford
local function remember_chest(name, cost, actor)
    local pos = actor:get_position()
    local key = chest_key(name, pos)
    if remembered_chests[key] then
        return -- already known
    end
    remembered_chests[key] = {
        name = name,
        cost = cost,
        position = pos,
        discovered_at = get_time_since_inject()
    }
    console.print(string.format("[CHEST REMEMBER] %s (cost: %d cinders) at (%.1f, %.1f, %.1f) — not enough cinders, saving location",
        name, cost, pos:x(), pos:y(), pos:z()))
end

-- Scan nearby actors for unaffordable chests and remember them
local last_chest_scan_time = 0
local CHEST_SCAN_TTL = 2.0
local function scan_and_remember_chests()
    if not settings.helltide_chest then return end
    local now = get_time_since_inject()
    if now - last_chest_scan_time < CHEST_SCAN_TTL then
        perf.inc("chest_scan_skip")
        return
    end
    last_chest_scan_time = now
    perf.start("scan_remember_chests")
    local current_cinders = get_helltide_coin_cinders()
    local actors = get_cached_actors()

    for _, actor in pairs(actors) do
        local skin = actor:get_skin_name()
        for chest_name, cost in pairs(enums.chest_types) do
            if skin:match(chest_name) and actor:is_interactable() and current_cinders < cost then
                remember_chest(chest_name, cost, actor)
            end
        end
    end
    perf.stop("scan_remember_chests")
end

-- Check if we can now afford any remembered chest — returns the key + entry of the cheapest affordable one
local function find_affordable_remembered_chest()
    local current_cinders = get_helltide_coin_cinders()
    local best_key, best_entry = nil, nil

    for key, entry in pairs(remembered_chests) do
        if current_cinders >= entry.cost then
            if not best_entry or entry.cost < best_entry.cost then
                best_key = key
                best_entry = entry
            end
        end
    end

    return best_key, best_entry
end

-- Prioritize-traversals tracking
local trav_blacklist = {}         -- key -> timestamp: traversals blacklisted as unreachable or recently used
local TRAV_BLACKLIST_TIMEOUT = 30 -- seconds before a blacklisted traversal can be targeted again
local trav_scan_time = 0          -- last time we ran the actor scan for traversals
local TRAV_SCAN_TTL = 1.0         -- only scan actors for traversals once per second
local trav_target_pos = nil       -- vec3 position of the traversal we're navigating to
local trav_target_str = nil       -- unique key for the target traversal
local trav_start_time = nil       -- time when we started navigating to this traversal
local trav_start_pos = nil        -- player position when we started (for crossing detection)
local trav_got_close = false      -- true once player came within 5 units of the traversal
local TRAV_NAV_TIMEOUT = 20       -- seconds before giving up on reaching a traversal

-- Kill monster tracking
local km_unreachable = {}
local KM_UNREACHABLE_TIMEOUT = 30
local km_nav_map = {}  -- per-position progress tracking: key -> {time, dist}

local function km_is_unreachable(pos)
    local now = get_time_since_inject()
    local key = math.floor(pos:x()) .. ',' .. math.floor(pos:y())
    if km_unreachable[key] and now - km_unreachable[key] > KM_UNREACHABLE_TIMEOUT then
        km_unreachable[key] = nil
    end
    return km_unreachable[key] ~= nil
end

local km_target_cache = nil
local km_cache_valid = false  -- separate flag: cache populated (result may be nil)
local km_target_cache_time = 0
local KM_TARGET_CACHE_TTL = 1.0  -- increased from 0.3; nil result was never cached before

local function km_mark_unreachable(pos)
    local key = math.floor(pos:x()) .. ',' .. math.floor(pos:y())
    km_unreachable[key] = get_time_since_inject()
    km_cache_valid = false  -- invalidate so next call re-scans without the now-unreachable enemy
    console.print(string.format("[KILL MONSTERS] Marked unreachable: (%.1f, %.1f)", pos:x(), pos:y()))
end

local function get_kill_target()
    local now = get_time_since_inject()
    if km_cache_valid and now - km_target_cache_time < KM_TARGET_CACHE_TTL then
        perf.inc("km_cache_hit")
        return km_target_cache
    end
    km_cache_valid = false
    perf.inc("km_cache_miss")
    perf.start("get_kill_target")
    local player_pos = get_player_position()
    local enemies = target_selector.get_near_target_list(player_pos, 50)
    local closest_enemy, closest_enemy_dist
    local closest_elite, closest_elite_dist
    local closest_champ, closest_champ_dist
    local closest_boss, closest_boss_dist

    for _, enemy in pairs(enemies) do
        local enemy_pos = enemy:get_position()
        if math.abs(player_pos:z() - enemy_pos:z()) > 5 then goto continue end
        if km_is_unreachable(enemy_pos) then goto continue end
        local health = enemy:get_current_health()
        if health <= 1 then goto continue end
        local dist = utils.distance_to(enemy)
        if enemy:is_boss() and (closest_boss_dist == nil or dist < closest_boss_dist) then
            closest_boss = enemy
            closest_boss_dist = dist
        end
        if dist <= 50 then
            if closest_enemy_dist == nil or dist < closest_enemy_dist then
                closest_enemy = enemy
                closest_enemy_dist = dist
            end
            if enemy:is_elite() and (closest_elite_dist == nil or dist < closest_elite_dist) then
                closest_elite = enemy
                closest_elite_dist = dist
            end
            if enemy:is_champion() and (closest_champ_dist == nil or dist < closest_champ_dist) then
                closest_champ = enemy
                closest_champ_dist = dist
            end
        end
        ::continue::
    end
    local result = closest_boss or closest_champ or closest_elite or closest_enemy
    perf.stop("get_kill_target")
    km_target_cache = result
    km_cache_valid = true  -- mark valid even when result is nil (no targets found)
    km_target_cache_time = get_time_since_inject()
    return result
end

local function check_events(self)
    local target -- reusable local for caching find_closest_target results

    -- Priority 1: Cinder chests when player can afford one
    if settings.helltide_chest then
        local current_cinders = get_helltide_coin_cinders()
        for chest_name, cost in pairs(enums.chest_types) do
            if current_cinders >= cost then
                target = find_closest_target(chest_name)
                if target and target:is_interactable() then
                    found_chest = chest_name
                    found_chest_position = target:get_position()
                    local key = chest_key(chest_name, found_chest_position)
                    if remembered_chests[key] then
                        console.print(string.format("[CHEST RECALL] Opening previously remembered %s", chest_name))
                        remembered_chests[key] = nil
                    end
                    console.print(string.format("[HELLTIDE CHEST] Detected %s at dist=%.1f pos=(%.1f,%.1f,%.1f) cinders=%d/%d",
                        chest_name, utils.distance_to(target), found_chest_position:x(), found_chest_position:y(), found_chest_position:z(),
                        current_cinders, cost))
                    self.current_state = helltide_state.MOVING_TO_HELLTIDE_CHEST
                    return
                end
            end
        end

        -- Scan for unaffordable chests in range and remember them
        scan_and_remember_chests()

        -- Check if we can now afford a previously remembered chest and navigate back
        local rkey, rentry = find_affordable_remembered_chest()
        if rkey and rentry then
            console.print(string.format("[CHEST RECALL] Now have enough cinders (%d/%d) for %s — navigating back to (%.1f, %.1f)",
                current_cinders, rentry.cost, rentry.name, rentry.position:x(), rentry.position:y()))
            remembered_chest_target = rkey
            self.current_state = helltide_state.MOVING_TO_REMEMBERED_CHEST
            return
        end
    end

    -- Priority 2: Prioritize traversals (between chests and kill monsters)
    -- Scan is throttled to once per second to avoid iterating all actors every frame
    if settings.prioritize_traversals then
        local now = get_time_since_inject()
        if now - trav_scan_time >= TRAV_SCAN_TTL then
            trav_scan_time = now
            local actors = get_cached_actors()
            local player_pos_z = get_player_position():z()
            for _, actor in pairs(actors) do
                local name = actor:get_skin_name()
                if name:match('[Tt]raversal_Gizmo') then
                    local pos = actor:get_position()
                    -- Mirror Batmobile's own z-diff constraint: only route to traversals
                    -- on the same level (z_diff <= 3).  FreeClimb_Up gizmos sit at the
                    -- bottom of a ladder — if the player is already at the top (z_diff > 3)
                    -- Batmobile will never select them, so skip them here too.
                    if math.abs(pos:z() - player_pos_z) > 3 then goto continue_trav end
                    local key = math.floor(pos:x()) .. ',' .. math.floor(pos:y()) .. ',' .. math.floor(pos:z())
                    local blacklisted_at = trav_blacklist[key]
                    if (blacklisted_at == nil or now - blacklisted_at > TRAV_BLACKLIST_TIMEOUT)
                        and utils.distance_to(pos) < 30
                    then
                        console.print(string.format("[TRAVERSAL] Targeting %s dist=%.1f pos=(%.1f,%.1f,%.1f)",
                            name, utils.distance_to(pos), pos:x(), pos:y(), pos:z()))
                        trav_target_pos = pos
                        trav_target_str = key
                        trav_start_time = now
                        trav_start_pos = get_player_position()
                        trav_got_close = false
                        self.current_state = helltide_state.MOVING_TO_TRAVERSAL
                        return
                    end
                end
                ::continue_trav::
            end
        end
    end

    -- Priority 3: Kill monsters when enabled
    if settings.kill_monsters then
        local km_target = get_kill_target()
        if km_target then
            self.current_state = helltide_state.KILL_MONSTERS
            return
        end
    end

    -- Priority 4: Nearby events / interactables while patrolling
    if settings.event and utils.do_events() then
        target = find_closest_target("S04_Helltide_Prop_SoulSyphon_01_Dyn")
        if target and target:is_interactable() and utils.distance_to(target) < 12 then
            self.current_state = helltide_state.MOVING_TO_PYRE
            return
        end
        target = find_closest_target("S04_Helltide_FlamePillar_Switch_Dyn")
        if target and target:is_interactable() and utils.distance_to(target) < 12 then
            self.current_state = helltide_state.MOVING_TO_PYRE
            return
        end
    end

    if settings.chaos_rift then
        target = find_closest_target("S10_ChaosRiftChoiceGizmo")
        if target and target:is_interactable() and utils.distance_to(target) < 16 then
            self.current_state = helltide_state.MOVING_TO_CHAOS_RIFT
            return
        end
    end

    if settings.silent_chest and utils.have_whispering_key() then
        target = find_closest_target("Hell_Prop_Chest_Rare_Locked")
        if target and target:is_interactable() and utils.distance_to(target) < 12 then
            found_silent_chest_position = target:get_position()
            console.print(string.format("[SILENT CHEST] Detected at dist=%.1f pos=(%.1f,%.1f,%.1f)",
                utils.distance_to(target), found_silent_chest_position:x(), found_silent_chest_position:y(), found_silent_chest_position:z()))
            self.current_state = helltide_state.MOVING_TO_SILENT_CHEST
            return
        end
    end

    if settings.ore then
        target = find_closest_target("HarvestNode_Ore")
        if target and target:is_interactable() and utils.distance_to(target) < 12 and utils.check_z_distance(target, 2.5) then
            found_ore = target
            self.current_state = helltide_state.MOVING_TO_ORE
            return
        end
    end

    if settings.herb then
        target = find_closest_target("HarvestNode_Herb")
        if target and target:is_interactable() and utils.distance_to(target) < 12 and utils.check_z_distance(target, 2.5) then
            found_herb = target
            self.current_state = helltide_state.MOVING_TO_HERB
            return
        end
    end

    if settings.shrine then
        target = find_closest_target("Shrine_")
        if target and target:is_interactable() and utils.distance_to(target) < 8 then
            self.current_state = helltide_state.MOVING_TO_SHRINE
            return
        end
    end

    if settings.goblin then
        target = find_closest_target("treasure_goblin")
        if target and target:get_current_health() > 1 then
            self.current_state = helltide_state.CHASE_GOBLIN
            return
        end
    end
end

local helltide_task = {
    name = "Explore Helltide",
    current_state = helltide_state.INIT,

    shouldExecute = function()
        return utils.is_in_helltide()
    end,

    Execute = function(self)
        perf.report()
        perf.inc("state_" .. self.current_state)
        debug_chest_scan() -- DEBUG: remove when done testing
        self.name = "Explore Helltide (" .. self.current_state .. ")"
        local lp = get_local_player()
        local is_dead = lp and lp:is_dead()
        if is_dead then
            was_dead = true
            revive_at_checkpoint()
            return
        elseif was_dead then
            was_dead = false
            console.print("[HelltideRevamped] Revived — resetting Batmobile explorer")
            if BatmobilePlugin then
                BatmobilePlugin.reset(plugin_label)
                BatmobilePlugin.resume(plugin_label)
            end
        end

        if LooteerPlugin then
            local looting = LooteerPlugin.getSettings('looting')
            if looting then
                clear_movement()
                return
            end
        end

        if tracker.has_salvaged then
            self:return_from_salvage()
        elseif utils.is_inventory_full() then
            self:back_to_town()
        elseif self.current_state == helltide_state.INIT then
            self:initiate_waypoints()
        elseif self.current_state == helltide_state.EXPLORE_HELLTIDE then
            self:explore_helltide()
        elseif self.current_state == helltide_state.MOVING_TO_TRAVERSAL then
            self:move_to_traversal()
        elseif self.current_state == helltide_state.MOVING_TO_PYRE then
            self:move_to_pyre()
        elseif self.current_state == helltide_state.INTERACT_PYRE then
            self:interact_pyre()
        elseif self.current_state == helltide_state.STAY_NEAR_PYRE then
            self:stay_near_pyre()
        elseif self.current_state == helltide_state.MOVING_TO_SILENT_CHEST then
            self:move_to_silent_chest()
        elseif self.current_state == helltide_state.MOVING_TO_HELLTIDE_CHEST then
            self:move_to_helltide_chest()
        elseif self.current_state == helltide_state.MOVING_TO_ORE then
            self:move_to_ore()
        elseif self.current_state == helltide_state.MOVING_TO_HERB then
            self:move_to_herb()
        elseif self.current_state == helltide_state.MOVING_TO_SHRINE then
            self:move_to_shrine()
        elseif self.current_state == helltide_state.CHASE_GOBLIN then
            self:chase_goblin()
        elseif self.current_state == helltide_state.KILL_MONSTERS then
            perf.start("kill_monsters")
            self:kill_monsters()
            perf.stop("kill_monsters")
        elseif self.current_state == helltide_state.MOVING_TO_REMEMBERED_CHEST then
            self:move_to_remembered_chest()
        elseif self.current_state == helltide_state.MOVING_TO_CHAOS_RIFT then
            self:move_to_chaos_rift()
        elseif self.current_state == helltide_state.INTERACT_CHAOS_RIFT then
            self:interact_chaos_rift()
        elseif self.current_state == helltide_state.STAY_NEAR_CHAOS_RIFT then
            self:stay_near_chaos_rift()
        elseif self.current_state == helltide_state.BACK_TO_TOWN then
            self:back_to_town()
        end
    end,

    initiate_waypoints = function(self)
        check_and_load_waypoints()
        last_target_ni = nil
        self.current_state = helltide_state.EXPLORE_HELLTIDE
    end,

    move_to_traversal = function(self)
        if not trav_target_pos then
            self.current_state = helltide_state.EXPLORE_HELLTIDE
            return
        end

        local now = get_time_since_inject()
        local player_pos = get_player_position()
        local dist = utils.distance_to(trav_target_pos)

        -- Track once we're within interaction range (matches Batmobile's interact threshold)
        if not trav_got_close and dist < 3 then
            trav_got_close = true
            console.print("[TRAVERSAL] Reached traversal, waiting for crossing")
        end

        -- Crossing detected: z changed from start (ladder) or player teleported away (portal)
        local z_crossed = trav_start_pos and math.abs(player_pos:z() - trav_start_pos:z()) > 2
        local portal_crossed = trav_got_close and dist > 20
        if z_crossed or portal_crossed then
            console.print(string.format("[TRAVERSAL] Crossed (z_diff=%.1f got_close=%s dist=%.1f) — blacklisting source + nearby return traversals for %ds",
                trav_start_pos and math.abs(player_pos:z() - trav_start_pos:z()) or 0,
                tostring(trav_got_close), dist, TRAV_BLACKLIST_TIMEOUT))
            -- Blacklist the source traversal we just crossed
            trav_blacklist[trav_target_str] = now
            -- Blacklist any traversal near the player's NEW position (the "return" traversal on
            -- the other side) so we don't immediately route back through the same crossing.
            local actors = get_cached_actors()
            for _, actor in pairs(actors) do
                if actor:get_skin_name():match('[Tt]raversal_Gizmo') then
                    local apos = actor:get_position()
                    if player_pos:dist_to(apos) < 20 then
                        local akey = math.floor(apos:x()) .. ',' .. math.floor(apos:y()) .. ',' .. math.floor(apos:z())
                        trav_blacklist[akey] = now
                        console.print(string.format("[TRAVERSAL] Blacklisting return traversal at (%.0f,%.0f,%.0f)",
                            apos:x(), apos:y(), apos:z()))
                    end
                end
            end
            trav_target_pos = nil
            trav_target_str = nil
            trav_start_time = nil
            trav_start_pos = nil
            trav_got_close = false
            reset_navigate_state()
            self.current_state = helltide_state.EXPLORE_HELLTIDE
            return
        end

        -- Timeout — traversal is unreachable from current position
        if now - trav_start_time > TRAV_NAV_TIMEOUT then
            console.print(string.format("[TRAVERSAL] Timeout (%.0fs, dist=%.1f) — blacklisting traversal",
                TRAV_NAV_TIMEOUT, dist))
            trav_blacklist[trav_target_str] = now
            trav_target_pos = nil
            trav_target_str = nil
            trav_start_time = nil
            trav_start_pos = nil
            trav_got_close = false
            reset_navigate_state()
            clear_movement()
            self.current_state = helltide_state.EXPLORE_HELLTIDE
            return
        end

        -- Throttled debug
        if not self._last_trav_debug then self._last_trav_debug = 0 end
        if now - self._last_trav_debug > 2 then
            self._last_trav_debug = now
            local elapsed = now - trav_start_time
            local z_diff = trav_start_pos and math.abs(player_pos:z() - trav_start_pos:z()) or 0
            console.print(string.format("[TRAVERSAL] dist=%.1f elapsed=%.1fs z_diff=%.1f got_close=%s player=(%.1f,%.1f,%.1f)",
                dist, elapsed, z_diff, tostring(trav_got_close),
                player_pos:x(), player_pos:y(), player_pos:z()))
        end

        -- Let Batmobile route to the traversal autonomously.
        -- set_target() with the exact gizmo position fails (non-walkable cell).
        -- Batmobile's select_target() uses get_closeby_node() to find a walkable
        -- approach node — this only works when is_custom_target=false.
        if BatmobilePlugin then
            BatmobilePlugin.resume(plugin_label)
            BatmobilePlugin.update(plugin_label)
            BatmobilePlugin.move(plugin_label)
        end
    end,

    explore_helltide = function(self)
        if #tracker.waypoints == 0 then
            self.current_state = helltide_state.INIT
            return
        end

        perf.start("check_events")
        check_events(self)
        perf.stop("check_events")
        if self.current_state ~= helltide_state.EXPLORE_HELLTIDE then
            last_target_ni = nil
            patrol_free_explore = false
            patrol_stuck_time = nil
            patrol_stuck_pos = nil
            return
        end

        -- EXPERIMENTAL EXPLORER: zone-wide grid coverage, no Batmobile frontier
        if settings.experimental_explorer then
            local player_pos = get_player_position()
            -- Register any chests visible from current position
            helltide_explorer.scan_nearby_chests(get_cached_actors(), player_pos)
            -- Get next grid node to navigate toward
            local target = helltide_explorer.get_exploration_target(player_pos)

            if target then
                local dist = player_pos:dist_to(target)
                -- Detect if target changed (new node selected after scout or backoff)
                local target_changed = explorer_last_target == nil
                    or explorer_last_target:dist_to(target) > 1

                if BatmobilePlugin then
                    local has_long_path = BatmobilePlugin.navigate_long_path ~= nil
                        and BatmobilePlugin.is_long_path_navigating ~= nil

                    if dist > 30 and has_long_path then
                        -- Far target: use uncapped long-path pathfinder
                        local now = get_time_since_inject()
                        local long_path_active = BatmobilePlugin.is_long_path_navigating()

                        -- Track when navigation stops so cooldown is from COMPLETION, not start.
                        -- Reset while actively navigating; stamp first frame after nav ends.
                        if long_path_active then
                            explorer_path_complete_time = nil
                        elseif not explorer_path_complete_time then
                            explorer_path_complete_time = now
                        end

                        -- Restart when: target changed, returning from combat (no cooldown),
                        -- or nav stopped and 3s elapsed since completion (stuck-loop guard).
                        local should_start = target_changed
                            or explorer_came_from_combat
                            or (not long_path_active
                                and explorer_path_complete_time ~= nil
                                and (now - explorer_path_complete_time) >= 3.0)

                        if should_start then
                            explorer_came_from_combat = false  -- consumed
                            -- Always stop first: clears navigator stuck-state from previous path
                            BatmobilePlugin.stop_long_path(plugin_label)
                            local ok = BatmobilePlugin.navigate_long_path(plugin_label, target)
                            if not ok then
                                helltide_explorer.on_path_failed()
                                explorer_last_target       = nil
                                explorer_path_complete_time = nil
                                return
                            end
                            explorer_path_complete_time = nil
                            console.print(string.format("[EXPLORER] Long path started to (%.1f,%.1f) dist=%.0f",
                                target:x(), target:y(), dist))
                        end

                        explorer_last_target = target
                        -- While long_path is active: let Batmobile drive it normally.
                        -- During cooldown (path finished early): pause Batmobile so frontier
                        -- doesn't take over, and use the game pathfinder to keep heading toward
                        -- the target until the 3s cooldown expires and we restart.
                        if BatmobilePlugin.is_long_path_navigating() then
                            BatmobilePlugin.resume(plugin_label)
                            BatmobilePlugin.update(plugin_label)
                            BatmobilePlugin.move(plugin_label)
                        else
                            BatmobilePlugin.pause(plugin_label)
                            pathfinder.request_move(target)
                        end
                    else
                        -- Close target: standard set_target
                        explorer_last_target = target
                        BatmobilePlugin.resume(plugin_label)
                        BatmobilePlugin.set_target(plugin_label, target, false)
                        BatmobilePlugin.update(plugin_label)
                        BatmobilePlugin.move(plugin_label)
                    end
                else
                    pathfinder.request_move(target)
                end
            else
                -- Just scouted a node — stop any active long path and wait for next selection
                explorer_last_target       = nil
                explorer_path_complete_time = nil
                if BatmobilePlugin and BatmobilePlugin.stop_long_path
                    and BatmobilePlugin.is_long_path_navigating
                    and BatmobilePlugin.is_long_path_navigating()
                then
                    BatmobilePlugin.stop_long_path(plugin_label)
                end
            end
            return
        end

        local total = #tracker.waypoints
        local player_pos = get_player_position()
        local now = get_time_since_inject()

        -- FREE EXPLORE MODE: Batmobile explores autonomously (like ArkhamAsylum)
        if patrol_free_explore then
            -- Track how long we've been in free-explore
            if patrol_free_explore_start == nil then
                patrol_free_explore_start = now
            end

            if BatmobilePlugin then
                BatmobilePlugin.resume(plugin_label)
                BatmobilePlugin.update(plugin_label)
                BatmobilePlugin.move(plugin_label)
            end

            -- Check if we've moved significantly — time to re-snap to waypoints
            local dist_from_stuck = patrol_stuck_pos and player_pos:dist_to(patrol_stuck_pos) or 0
            -- Throttled debug
            if not self._last_patrol_debug then self._last_patrol_debug = 0 end
            if now - self._last_patrol_debug > 2 then
                self._last_patrol_debug = now
                console.print(string.format("[PATROL] FREE_EXPLORE | moved=%.1f stuck_for=%.1fs | player=(%.1f,%.1f)",
                    dist_from_stuck, now - patrol_free_explore_start, player_pos:x(), player_pos:y()))
                if BatmobilePlugin then
                    console.print(string.format("[PATROL] Batmobile: done=%s paused=%s",
                        tostring(BatmobilePlugin.is_done()), tostring(BatmobilePlugin.is_paused())))
                end
            end

            -- If stuck in free-explore too long, player is likely on a platform after a
            -- traversal.  Clear the traversal blacklist so Batmobile can find a way back.
            if now - patrol_free_explore_start > TRAVERSAL_RECOVERY_TIMEOUT then
                if try_traversal_recovery(now) then
                    patrol_free_explore_start = now  -- reset so we don't spam-call
                end
            end

            if dist_from_stuck > 15 then
                console.print("[PATROL] Moved >15 from stuck pos, resuming waypoint patrol")
                patrol_free_explore = false
                patrol_stuck_time = nil
                patrol_stuck_pos = nil
                patrol_free_explore_start = nil
                last_target_ni = nil -- force re-snap
            end
            return
        end

        -- WAYPOINT PATROL MODE
        -- On first entry or after interaction, snap to nearest and look ahead
        if last_target_ni == nil then
            local nearest = find_closest_waypoint_index(tracker.waypoints)
            if nearest then
                ni = nearest + WAYPOINT_LOOKAHEAD
                if ni > total then ni = 1 end
                console.print(string.format("[PATROL] Init: nearest=%d, targeting ni=%d/%d", nearest, ni, total))
            end
        end

        -- Check distance to our current target waypoint — advance when close
        local dist_to_target = utils.distance_to(tracker.waypoints[ni])
        if dist_to_target < WAYPOINT_ARRIVAL_DIST then
            local old_ni = ni
            ni = ni + WAYPOINT_LOOKAHEAD
            if ni > total then ni = 1 end
            console.print(string.format("[PATROL] Arrived (dist=%.1f < %d), advancing ni %d -> %d", dist_to_target, WAYPOINT_ARRIVAL_DIST, old_ni, ni))
            patrol_stuck_time = nil
            patrol_stuck_pos = nil
        end

        -- If target waypoint is too far, re-snap to nearest
        dist_to_target = utils.distance_to(tracker.waypoints[ni])
        if dist_to_target > WAYPOINT_MAX_DIST then
            local nearest = find_closest_waypoint_index(tracker.waypoints)
            if nearest then
                local old_ni = ni
                ni = nearest + WAYPOINT_LOOKAHEAD
                if ni > total then ni = 1 end
                -- If even the re-snapped waypoint is far, just use nearest
                if utils.distance_to(tracker.waypoints[ni]) > WAYPOINT_MAX_DIST then
                    ni = nearest
                end
            end
        end

        -- Stuck detection: if player hasn't moved >5 units in PATROL_STUCK_TIMEOUT, switch to free explore
        if patrol_stuck_time == nil then
            patrol_stuck_time = now
            patrol_stuck_pos = player_pos
        else
            local dist_moved = player_pos:dist_to(patrol_stuck_pos)
            if dist_moved > 5 then
                patrol_stuck_time = now
                patrol_stuck_pos = player_pos
            elseif now - patrol_stuck_time > PATROL_STUCK_TIMEOUT then
                console.print(string.format("[PATROL] Stuck %ds (moved %.1f), switching to FREE_EXPLORE",
                    PATROL_STUCK_TIMEOUT, dist_moved))
                if BatmobilePlugin then
                    BatmobilePlugin.clear_target(plugin_label)
                    BatmobilePlugin.reset(plugin_label)
                end
                patrol_free_explore = true
                patrol_free_explore_start = now  -- track entry time for traversal recovery
                -- Keep patrol_stuck_pos so free explore knows where we got stuck
                last_target_ni = nil
                return
            end
        end

        -- Send target to Batmobile only when ni changes
        if ni ~= last_target_ni then
            local wp = tracker.waypoints[ni]
            console.print(string.format("[PATROL] New target ni=%d dist=%.1f pos=(%.1f,%.1f,%.1f)", ni, utils.distance_to(wp), wp:x(), wp:y(), wp:z()))
            last_target_ni = ni
            patrol_move(randomize_waypoint(wp))
        else
            -- Same target, keep moving
            local wp = tracker.waypoints[ni]
            if not self._last_patrol_debug then self._last_patrol_debug = 0 end
            if now - self._last_patrol_debug > 2 then
                self._last_patrol_debug = now
                local player_speed = get_local_player():get_current_speed()
                local stuck_elapsed = patrol_stuck_time and (now - patrol_stuck_time) or 0
                console.print(string.format("[PATROL] ni=%d dist=%.1f speed=%.1f stuck=%.0fs player=(%.1f,%.1f) wp=(%.1f,%.1f)",
                    ni, utils.distance_to(wp), player_speed, stuck_elapsed, player_pos:x(), player_pos:y(), wp:x(), wp:y()))
                if BatmobilePlugin then
                    console.print(string.format("[PATROL] Batmobile: done=%s paused=%s",
                        tostring(BatmobilePlugin.is_done()), tostring(BatmobilePlugin.is_paused())))
                end
            end

            if BatmobilePlugin then
                BatmobilePlugin.update(plugin_label)
                BatmobilePlugin.move(plugin_label)
            else
                patrol_move(tracker.waypoints[ni])
            end
        end
    end,

    move_to_pyre = function(self)
        local pyre = find_closest_target("S04_Helltide_Prop_SoulSyphon_01_Dyn") or find_closest_target("S04_Helltide_FlamePillar_Switch_Dyn")
        if pyre then
            local dist = utils.distance_to(pyre)
            if dist > 2 then
                move_to(pyre, dist <= 4)
                return
            else
                self.current_state = helltide_state.INTERACT_PYRE
            end
        else
            clear_movement()
            self.current_state = helltide_state.EXPLORE_HELLTIDE
        end
    end,

    interact_pyre = function(self)
        local pyre = find_closest_target("S04_Helltide_Prop_SoulSyphon_01_Dyn") or find_closest_target("S04_Helltide_FlamePillar_Switch_Dyn")
        if pyre then
            if pyre:is_interactable() then
                interact_object(pyre)
            else
                self.current_state = helltide_state.STAY_NEAR_PYRE
            end
        else
            clear_movement()
            self.current_state = helltide_state.EXPLORE_HELLTIDE
        end
    end,

    stay_near_pyre = function(self)
        local pyre = find_closest_target("S04_Helltide_Prop_SoulSyphon_01_Dyn") or find_closest_target("S04_Helltide_FlamePillar_Switch_Dyn")
        if pyre then
            if pyre:is_interactable() then
                self.current_state = helltide_state.INTERACT_PYRE
            elseif utils.distance_to(pyre) > 1 then
                move_to(pyre, true)
                return
            end
        else
            clear_movement()
            self.current_state = helltide_state.EXPLORE_HELLTIDE
        end
    end,

    move_to_silent_chest = function(self)
        if not found_silent_chest_position then
            console.print("[SILENT CHEST] No position data, returning to patrol")
            clear_movement()
            self.current_state = helltide_state.EXPLORE_HELLTIDE
            return
        end

        local dist_to_saved = utils.distance_to(found_silent_chest_position)

        -- Too far — give up
        if dist_to_saved > WAYPOINT_MAX_DIST then
            console.print(string.format("[SILENT CHEST] Too far (%.0f > %d), giving up", dist_to_saved, WAYPOINT_MAX_DIST))
            found_silent_chest_position = nil
            clear_movement()
            self.current_state = helltide_state.EXPLORE_HELLTIDE
            return
        end

        -- Try to find the actual actor
        local chest = find_closest_target("Hell_Prop_Chest_Rare_Locked")
        if chest and chest:is_interactable() then
            found_silent_chest_position = chest:get_position()
            local chest_dist = utils.distance_to(chest)

            if chest_dist <= 2 then
                interact_object(chest)
                found_silent_chest_position = nil
                clear_movement()
                return
            elseif chest_dist <= 6 then
                move_to(chest, chest_dist <= 4)
                return
            else
                navigate_to(chest)
                return
            end
        end

        -- Actor not loaded — navigate to cached position
        if dist_to_saved > 2 then
            navigate_to(found_silent_chest_position)
            return
        end

        -- At position but actor not loaded — wait with timeout
        if not tracker.check_time("chest_drop_time", 8) then
            return
        end

        console.print("[SILENT CHEST] Timed out waiting for actor, giving up")
        tracker.clear_key('chest_drop_time')
        found_silent_chest_position = nil
        clear_movement()
        self.current_state = helltide_state.EXPLORE_HELLTIDE
    end,

    move_to_helltide_chest = function(self)
        if not found_chest or not found_chest_position then
            console.print("[HELLTIDE CHEST] No chest data, returning to patrol")
            found_chest = nil
            found_chest_position = nil
            clear_movement()
            self.current_state = helltide_state.EXPLORE_HELLTIDE
            return
        end

        local has_batmobile = BatmobilePlugin ~= nil
        local dist_to_saved = utils.distance_to(found_chest_position)

        -- Too far or drifting away — give up and resume patrol
        if dist_to_saved > WAYPOINT_MAX_DIST then
            console.print(string.format("[HELLTIDE CHEST] %s too far (%.0f > %d), giving up", found_chest, dist_to_saved, WAYPOINT_MAX_DIST))
            found_chest = nil
            found_chest_position = nil
            clear_movement()
            self.current_state = helltide_state.EXPLORE_HELLTIDE
            return
        end

        -- Throttled debug
        if not self._last_hchest_debug then self._last_hchest_debug = 0 end
        local now = get_time_since_inject()
        if now - self._last_hchest_debug > 2 then
            self._last_hchest_debug = now
            local player_pos = get_player_position()
            local speed = get_local_player():get_current_speed()
            console.print(string.format("[HELLTIDE CHEST] %s | dist_to_pos=%.1f | speed=%.1f | player=(%.1f,%.1f) target=(%.1f,%.1f)",
                found_chest, dist_to_saved, speed,
                player_pos:x(), player_pos:y(), found_chest_position:x(), found_chest_position:y()))
            if has_batmobile then
                console.print(string.format("[HELLTIDE CHEST] Batmobile: done=%s paused=%s",
                    tostring(BatmobilePlugin.is_done()), tostring(BatmobilePlugin.is_paused())))
            end
        end

        -- Try to find the actual actor
        local chest = find_closest_target(found_chest)
        if chest and chest:is_interactable() then
            found_chest_position = chest:get_position()
            local chest_dist = utils.distance_to(chest)

            if chest_dist <= 2 then
                console.print(string.format("[HELLTIDE CHEST] Interacting with %s", found_chest))
                interact_object(chest)
                if settings.experimental_explorer then
                    helltide_explorer.mark_chest_opened(chest:get_position())
                end
                found_chest = nil
                found_chest_position = nil
                clear_movement()
                return
            elseif chest_dist <= 6 then
                -- Close range: actor is directly reachable, use pause for precision
                move_to(chest, chest_dist <= 4)
                return
            else
                navigate_to(chest)
                return
            end
        end

        -- Actor not loaded — navigate to cached position (may need traversal)
        if dist_to_saved > 2 then
            navigate_to(found_chest_position)
            return
        end

        -- At the position but actor still not loaded — wait with timeout
        if not tracker.check_time("chest_drop_time", 8) then
            return
        end

        console.print(string.format("[HELLTIDE CHEST] Timed out waiting for %s actor, giving up", found_chest))
        tracker.clear_key('chest_drop_time')
        found_chest = nil
        found_chest_position = nil
        clear_movement()
        self.current_state = helltide_state.EXPLORE_HELLTIDE
    end,

    move_to_remembered_chest = function(self)
        local entry = remembered_chests[remembered_chest_target]
        if not entry then
            console.print("[CHEST RECALL] Remembered chest no longer valid, resuming patrol")
            remembered_chest_target = nil
            if BatmobilePlugin and BatmobilePlugin.stop_long_path then
                BatmobilePlugin.stop_long_path(plugin_label)
            end
            clear_movement()
            self.current_state = helltide_state.EXPLORE_HELLTIDE
            return
        end

        -- Check we can still afford it
        local current_cinders = get_helltide_coin_cinders()
        if current_cinders < entry.cost then
            console.print(string.format("[CHEST RECALL] Cinders dropped below %d, aborting return to %s", entry.cost, entry.name))
            remembered_chests[remembered_chest_target] = nil
            remembered_chest_target = nil
            if BatmobilePlugin and BatmobilePlugin.stop_long_path then
                BatmobilePlugin.stop_long_path(plugin_label)
            end
            clear_movement()
            self.current_state = helltide_state.EXPLORE_HELLTIDE
            return
        end

        local dist = utils.distance_to(entry.position)
        local has_batmobile = BatmobilePlugin ~= nil
        local long_path_active = has_batmobile
            and BatmobilePlugin.is_long_path_navigating
            and BatmobilePlugin.is_long_path_navigating()

        -- Long path is uncapped so allow reasonable map-distance; give up beyond 300 units
        if dist > 300 then
            console.print(string.format("[CHEST RECALL] %s is too far (%.0f), forgetting it", entry.name, dist))
            remembered_chests[remembered_chest_target] = nil
            remembered_chest_target = nil
            if has_batmobile and BatmobilePlugin.stop_long_path then
                BatmobilePlugin.stop_long_path(plugin_label)
            end
            clear_movement()
            self.current_state = helltide_state.EXPLORE_HELLTIDE
            return
        end

        -- Throttled debug logging
        if not self._last_recall_debug then self._last_recall_debug = 0 end
        local now = get_time_since_inject()
        if now - self._last_recall_debug > 2 then
            self._last_recall_debug = now
            local player_pos = get_player_position()
            local player_speed = get_local_player():get_current_speed()
            console.print(string.format("[CHEST RECALL] %s | dist=%.1f | speed=%.1f | cinders=%d/%d | long_path=%s",
                entry.name, dist, player_speed, current_cinders, entry.cost, tostring(long_path_active)))
            console.print(string.format("[CHEST RECALL] player=(%.1f,%.1f) target=(%.1f,%.1f)",
                player_pos:x(), player_pos:y(), entry.position:x(), entry.position:y()))
            if has_batmobile then
                console.print(string.format("[CHEST RECALL] Batmobile: done=%s paused=%s",
                    tostring(BatmobilePlugin.is_done()), tostring(BatmobilePlugin.is_paused())))
            end
        end

        -- Close range: stop long path and use precision nav
        if dist < 15 then
            if has_batmobile and BatmobilePlugin.stop_long_path then
                BatmobilePlugin.stop_long_path(plugin_label)
            end

            local chest = find_closest_target(entry.name)
            if chest and chest:is_interactable() then
                local chest_dist = utils.distance_to(chest)

                if chest_dist <= 2 then
                    console.print(string.format("[CHEST RECALL] Opening remembered %s", entry.name))
                    interact_object(chest)
                    if settings.experimental_explorer then
                        helltide_explorer.mark_chest_opened(chest:get_position())
                    end
                    remembered_chests[remembered_chest_target] = nil
                    remembered_chest_target = nil
                    clear_movement()
                    return
                elseif chest_dist <= 6 then
                    move_to(chest, chest_dist <= 4)
                    return
                else
                    navigate_to(chest)
                    return
                end
            end

            -- Close but actor not found — chest may have despawned
            if not tracker.check_time("remembered_chest_timeout", 6) then
                navigate_to(entry.position)
                return
            end

            console.print(string.format("[CHEST RECALL] %s not found at saved location, removing", entry.name))
            remembered_chests[remembered_chest_target] = nil
            remembered_chest_target = nil
            tracker.clear_key("remembered_chest_timeout")
            clear_movement()
            self.current_state = helltide_state.EXPLORE_HELLTIDE
            return
        end

        -- Far away: use long path (uncapped pathfinding, handles traversals)
        if has_batmobile and BatmobilePlugin.navigate_long_path and BatmobilePlugin.is_long_path_navigating then
            if not long_path_active then
                -- Not yet navigating — start the long path
                local ok = BatmobilePlugin.navigate_long_path(plugin_label, entry.position)
                if ok then
                    console.print(string.format("[CHEST RECALL] Long path started to %s (%.1f,%.1f)",
                        entry.name, entry.position:x(), entry.position:y()))
                else
                    console.print("[CHEST RECALL] Long path failed to find route, falling back to navigate_to")
                    navigate_to(entry.position)
                    return
                end
            end
            -- Long path is active — drive it
            BatmobilePlugin.update(plugin_label)
            BatmobilePlugin.move(plugin_label)
        else
            navigate_to(entry.position)
        end
    end,

    move_to_ore = function(self)
        if found_ore and found_ore:is_interactable() then
            local dist = utils.distance_to(found_ore)
            if dist >= 2 then
                move_to(found_ore, dist <= 4)
                return
            end
            interact_object(found_ore)
        else
            found_ore = nil
            clear_movement()
            self.current_state = helltide_state.EXPLORE_HELLTIDE
        end
    end,

    move_to_herb = function(self)
        if found_herb and found_herb:is_interactable() then
            local dist = utils.distance_to(found_herb)
            if dist >= 2 then
                move_to(found_herb, dist <= 4)
                return
            end
            interact_object(found_herb)
        else
            found_herb = nil
            clear_movement()
            self.current_state = helltide_state.EXPLORE_HELLTIDE
        end
    end,

    move_to_shrine = function(self)
        local shrine = find_closest_target("Shrine_")
        if shrine and shrine:is_interactable() then
            local dist = utils.distance_to(shrine)
            if dist > 2 then
                move_to(shrine, dist <= 4)
                return
            else
                interact_object(shrine)
            end
        else
            clear_movement()
            self.current_state = helltide_state.EXPLORE_HELLTIDE
        end
    end,

    chase_goblin = function(self)
        local goblin = find_closest_target("treasure_goblin")
        if goblin and goblin:get_current_health() > 1 then
            if utils.distance_to(goblin) > 2 then
                move_to(goblin, false) -- never disable spells chasing goblins
                return
            end
        else
            if not tracker.check_time("goblin_drop_time", 4) then
                return
            end
            tracker.clear_key('goblin_drop_time')
            clear_movement()
            self.current_state = helltide_state.EXPLORE_HELLTIDE
        end
    end,

    kill_monsters = function(self)
        orbwalker.set_clear_toggle(true)
        local local_player = get_local_player()
        if not local_player then
            self.current_state = helltide_state.EXPLORE_HELLTIDE
            return
        end

        local target = get_kill_target()
        if not target then
            if BatmobilePlugin then BatmobilePlugin.clear_target(plugin_label) end
            console.print("[KILL MONSTERS] No targets, resuming patrol")
            clear_movement()
            explorer_came_from_combat = true  -- skip path cooldown on return to explore
            self.current_state = helltide_state.EXPLORE_HELLTIDE
            return
        end

        local target_pos = target:get_position()
        local cur_dist = utils.distance_to(target)

        -- Per-position progress tracking: timer persists across target switches
        -- so a monster that's intermittently targeted still accumulates time toward the unreachable timeout
        local nav_key = math.floor(target_pos:x()) .. ',' .. math.floor(target_pos:y())
        local now = get_time_since_inject()
        local nav = km_nav_map[nav_key]
        if not nav then
            km_nav_map[nav_key] = { time = now, dist = cur_dist }
        elseif cur_dist < nav.dist - 2 then
            nav.dist = cur_dist
            nav.time = now
        elseif now - nav.time > 5 then
            km_nav_map[nav_key] = nil
            km_mark_unreachable(target_pos)
            if BatmobilePlugin then BatmobilePlugin.clear_target(plugin_label) end
            return
        end

        if cur_dist > 2 then
            if BatmobilePlugin then
                -- Use pause (not resume) so the long-path navigator state is frozen
                -- while fighting — long_path.navigating stays true, path resumes after combat.
                BatmobilePlugin.pause(plugin_label)
                local accepted = BatmobilePlugin.set_target(plugin_label, target)
                if accepted == false then
                    km_mark_unreachable(target_pos)
                    km_nav_map[nav_key] = nil
                    BatmobilePlugin.clear_target(plugin_label)
                    return
                end
                BatmobilePlugin.update(plugin_label)
                BatmobilePlugin.move(plugin_label)
            else
                pathfinder.request_move(target_pos)
            end
        else
            km_nav_map[nav_key] = nil  -- reached target, clear tracking entry
            if BatmobilePlugin then BatmobilePlugin.clear_target(plugin_label) end
        end
    end,

    move_to_chaos_rift = function(self)
        local chaos_rift = find_closest_target("S10_ChaosRiftChoiceGizmo")
        if chaos_rift then
            local dist = utils.distance_to(chaos_rift)
            if dist > 2 then
                move_to(chaos_rift, dist <= 4)
                return
            else
                self.current_state = helltide_state.INTERACT_CHAOS_RIFT
            end
        else
            clear_movement()
            self.current_state = helltide_state.EXPLORE_HELLTIDE
        end
    end,

    interact_chaos_rift = function(self)
        local chaos_rift = find_closest_target("S10_ChaosRiftChoiceGizmo")
        if chaos_rift then
            if chaos_rift:is_interactable() then
                interact_object(chaos_rift)
            else
                self.current_state = helltide_state.STAY_NEAR_CHAOS_RIFT
            end
        else
            clear_movement()
            self.current_state = helltide_state.EXPLORE_HELLTIDE
        end
    end,

    stay_near_chaos_rift = function(self)
        local chaos_rift = find_closest_target("S10_ChaosRiftChoiceGizmo") or find_closest_target("S10_ChaosRiftPortal") or find_closest_target("MarkerLocation_BSK_Occupied")
        if chaos_rift then
            if chaos_rift:is_interactable() then
                self.current_state = helltide_state.INTERACT_CHAOS_RIFT
            elseif utils.distance_to(chaos_rift) > 1 then
                move_to(chaos_rift, true)
                return
            end
        else
            -- Chaos rift finished but wait for loot
            if not tracker.check_time("chaos_rift_loot_time", 4) then
                return
            end
            tracker.clear_key('chaos_rift_loot_time')
            clear_movement()
            self.current_state = helltide_state.EXPLORE_HELLTIDE
        end
    end,

    back_to_town = function(self)
        clear_movement()
        if settings.salvage then
            tracker.needs_salvage = true
        end
    end,

    return_from_salvage = function(self)
        if not tracker.check_time("salvage_return_time", 3) then
            return
        end
        tracker.has_salvaged = false
        tracker.clear_key('salvage_return_time')
        self.current_state = helltide_state.EXPLORE_HELLTIDE
    end,

    reset = function(self)
        ni = 1
        last_target_ni = nil
        patrol_free_explore = false
        patrol_free_explore_start = nil
        patrol_stuck_time = nil
        patrol_stuck_pos = nil
        traversal_recovery_time = nil
        trav_blacklist = {}
        trav_target_pos = nil
        trav_target_str = nil
        trav_start_time = nil
        trav_start_pos = nil
        trav_got_close = false
        self.current_state = helltide_state.INIT
        tracker.has_salvaged = false
        tracker.needs_salvage = false
        found_chest = nil
        found_chest_position = nil
        found_silent_chest_position = nil
        found_ore = nil
        found_herb = nil
        remembered_chests = {}
        remembered_chest_target = nil
        km_unreachable = {}
        km_nav_map = {}
        km_target_cache = nil
        km_cache_valid = false
        cached_actors = nil
        clear_movement()
        if BatmobilePlugin then
            BatmobilePlugin.reset(plugin_label)
        end
    end
}

return helltide_task
