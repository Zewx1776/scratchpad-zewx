local utils = require "core.utils"
local tracker = require "core.tracker"
local settings = require "core.settings"
local enums = require "data.enums"

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

local navigate_to_debug_time = 0
local navigate_to_start_pos = nil -- position when stuck timer started

local function navigate_to(target)
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
            BatmobilePlugin.update(plugin_label)
            BatmobilePlugin.move(plugin_label)

            -- Check if player has actually moved significantly from where we got stuck
            if navigate_to_start_pos and player_pos:dist_to(navigate_to_start_pos) > 15 then
                console.print("[NAV] Moved >15 units in free explore, re-trying target")
                navigate_to_free_explore = false
                navigate_to_stuck_time = nil
                navigate_to_start_pos = nil
            end
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
end

-- Reset navigate_to state (call when switching away from navigate_to usage)
local function reset_navigate_state()
    navigate_to_stuck_time = nil
    navigate_to_start_pos = nil
    navigate_to_free_explore = false
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

local function find_closest_target(name)
    local actors = actors_manager:get_all_actors()
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
local function scan_and_remember_chests()
    if not settings.helltide_chest then return end
    local current_cinders = get_helltide_coin_cinders()
    local actors = actors_manager:get_all_actors()

    for _, actor in pairs(actors) do
        local skin = actor:get_skin_name()
        for chest_name, cost in pairs(enums.chest_types) do
            if skin:match(chest_name) and actor:is_interactable() and current_cinders < cost then
                remember_chest(chest_name, cost, actor)
            end
        end
    end
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

-- Kill monster tracking
local km_unreachable = {}
local KM_UNREACHABLE_TIMEOUT = 30
local km_nav = { pos = nil, time = 0, dist = nil }

local function km_is_unreachable(pos)
    local now = get_time_since_inject()
    local key = math.floor(pos:x()) .. ',' .. math.floor(pos:y())
    if km_unreachable[key] and now - km_unreachable[key] > KM_UNREACHABLE_TIMEOUT then
        km_unreachable[key] = nil
    end
    return km_unreachable[key] ~= nil
end

local function km_mark_unreachable(pos)
    local key = math.floor(pos:x()) .. ',' .. math.floor(pos:y())
    km_unreachable[key] = get_time_since_inject()
    console.print(string.format("[KILL MONSTERS] Marked unreachable: (%.1f, %.1f)", pos:x(), pos:y()))
end

local function get_kill_target()
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
    return closest_boss or closest_champ or closest_elite or closest_enemy
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

    -- Priority 2: Kill monsters when enabled
    if settings.kill_monsters then
        local km_target = get_kill_target()
        if km_target then
            self.current_state = helltide_state.KILL_MONSTERS
            return
        end
    end

    -- Priority 3: Nearby events / interactables while patrolling
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
            self:kill_monsters()
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

    explore_helltide = function(self)
        if #tracker.waypoints == 0 then
            self.current_state = helltide_state.INIT
            return
        end

        check_events(self)
        if self.current_state ~= helltide_state.EXPLORE_HELLTIDE then
            last_target_ni = nil
            patrol_free_explore = false
            patrol_stuck_time = nil
            patrol_stuck_pos = nil
            return
        end

        local total = #tracker.waypoints
        local player_pos = get_player_position()
        local now = get_time_since_inject()

        -- FREE EXPLORE MODE: Batmobile explores autonomously (like ArkhamAsylum)
        if patrol_free_explore then
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
                console.print(string.format("[PATROL] FREE_EXPLORE | moved=%.1f from stuck pos | player=(%.1f,%.1f)",
                    dist_from_stuck, player_pos:x(), player_pos:y()))
                if BatmobilePlugin then
                    console.print(string.format("[PATROL] Batmobile: done=%s paused=%s",
                        tostring(BatmobilePlugin.is_done()), tostring(BatmobilePlugin.is_paused())))
                end
            end

            if dist_from_stuck > 15 then
                console.print("[PATROL] Moved >15 from stuck pos, resuming waypoint patrol")
                patrol_free_explore = false
                patrol_stuck_time = nil
                patrol_stuck_pos = nil
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
                console.print(string.format("[PATROL] Waypoint too far (%.0f), re-snapped ni %d -> %d (dist=%.1f)",
                    dist_to_target, old_ni, ni, utils.distance_to(tracker.waypoints[ni])))
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
            clear_movement()
            self.current_state = helltide_state.EXPLORE_HELLTIDE
            return
        end

        local dist = utils.distance_to(entry.position)
        local has_batmobile = BatmobilePlugin ~= nil

        -- Too far to realistically navigate back — forget this chest and keep patrolling
        if dist > WAYPOINT_MAX_DIST then
            console.print(string.format("[CHEST RECALL] %s is too far (%.0f > %d), forgetting it",
                entry.name, dist, WAYPOINT_MAX_DIST))
            remembered_chests[remembered_chest_target] = nil
            remembered_chest_target = nil
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
            console.print(string.format("[CHEST RECALL] %s | dist=%.1f | speed=%.1f | cinders=%d/%d | batmobile=%s",
                entry.name, dist, player_speed, current_cinders, entry.cost, tostring(has_batmobile)))
            console.print(string.format("[CHEST RECALL] player=(%.1f,%.1f) target=(%.1f,%.1f)",
                player_pos:x(), player_pos:y(), entry.position:x(), entry.position:y()))
            if has_batmobile then
                console.print(string.format("[CHEST RECALL] Batmobile: done=%s paused=%s",
                    tostring(BatmobilePlugin.is_done()), tostring(BatmobilePlugin.is_paused())))
            end
        end

        -- Once close enough, try to find the actual actor
        if dist < 15 then
            local chest = find_closest_target(entry.name)
            if chest and chest:is_interactable() then
                local chest_dist = utils.distance_to(chest)

                if chest_dist <= 2 then
                    console.print(string.format("[CHEST RECALL] Opening remembered %s", entry.name))
                    interact_object(chest)
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

        -- Far away — long-range navigation
        navigate_to(entry.position)
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
            km_nav.pos = nil
            if BatmobilePlugin then BatmobilePlugin.clear_target(plugin_label) end
            console.print("[KILL MONSTERS] No targets, resuming patrol")
            clear_movement()
            self.current_state = helltide_state.EXPLORE_HELLTIDE
            return
        end

        local target_pos = target:get_position()
        local cur_dist = utils.distance_to(target)

        -- Nav progress tracking
        if km_nav.pos == nil or target_pos:dist_to(km_nav.pos) > 5 then
            km_nav.pos = target_pos
            km_nav.time = get_time_since_inject()
            km_nav.dist = cur_dist
        elseif cur_dist < km_nav.dist - 2 then
            km_nav.dist = cur_dist
            km_nav.time = get_time_since_inject()
        elseif get_time_since_inject() - km_nav.time > 12 then
            km_mark_unreachable(target_pos)
            km_nav.pos = nil
            if BatmobilePlugin then BatmobilePlugin.clear_target(plugin_label) end
            return
        end

        if cur_dist > 2 then
            if BatmobilePlugin then
                BatmobilePlugin.resume(plugin_label)
                local accepted = BatmobilePlugin.set_target(plugin_label, target)
                if accepted == false then
                    km_mark_unreachable(target_pos)
                    km_nav.pos = nil
                    BatmobilePlugin.clear_target(plugin_label)
                    return
                end
                BatmobilePlugin.update(plugin_label)
                BatmobilePlugin.move(plugin_label)
            else
                pathfinder.request_move(target_pos)
            end
        else
            km_nav.pos = nil
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
        patrol_stuck_time = nil
        patrol_stuck_pos = nil
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
        km_nav = { pos = nil, time = 0, dist = nil }
        clear_movement()
        if BatmobilePlugin then
            BatmobilePlugin.reset(plugin_label)
        end
    end
}

return helltide_task
