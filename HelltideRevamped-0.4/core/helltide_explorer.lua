local utils    = require "core.utils"
local enums    = require "data.enums"
local tracker  = require "core.tracker"
local settings = require "core.settings"

-- ============================================================
-- Constants
-- ============================================================
local GRID_SPACING      = 60    -- meters between grid node centers
local SCOUT_RADIUS      = 30    -- meters: player within this = node scouted
local CHEST_SCAN_RADIUS = 50    -- meters: actor scan range for chests
local STUCK_TIMEOUT     = 30    -- seconds with NO player movement before skipping node
local STUCK_MOVE_THRESH = 3     -- units player must move to reset stuck timer (any movement counts)
local STUCK_BACKOFF     = 300   -- seconds to push a stuck node's last_scouted forward
local SCAN_THROTTLE     = 2.0   -- seconds between chest actor scans

-- ============================================================
-- Module state
-- ============================================================
local coverage_nodes     = nil  -- array of { pos=vec3, last_scouted=number }
local coverage_wp_count  = 0    -- fingerprint: #tracker.waypoints at build time
local current_target_idx = nil  -- index into coverage_nodes of active nav target
local stuck_start_time   = nil
local stuck_target_idx   = nil
local stuck_check_pos    = nil  -- player pos at last stuck-timer reset; movement resets timer

local found_chests  = {}        -- key -> { position, name, cost, first_seen, last_seen }
local opened_chests = {}        -- key -> true

local was_in_helltide  = false
local last_scan_time   = 0
local scan_total       = 0       -- cumulative discovered chests (for logging)
local last_update_time = nil     -- wall-clock of last update_coverage call (gap detection)

local helltide_explorer = {}

-- ============================================================
-- Internal helpers
-- ============================================================
local function chest_key(pos)
    return math.floor(pos:x()) .. "," .. math.floor(pos:y())
end

local function full_reset()
    found_chests       = {}
    opened_chests      = {}
    coverage_nodes     = nil
    coverage_wp_count  = 0
    current_target_idx = nil
    stuck_start_time   = nil
    stuck_target_idx   = nil
    stuck_check_pos    = nil
    last_scan_time     = 0
    scan_total         = 0
    console.print("[EXPLORER] Full reset — chest registry and coverage cleared for new helltide")
end

local function get_next_coverage_idx()
    if not coverage_nodes or #coverage_nodes == 0 then return nil end
    local best_idx, best_time = nil, math.huge
    for i, node in ipairs(coverage_nodes) do
        if node.last_scouted < best_time then
            best_time = node.last_scouted
            best_idx  = i
        end
    end
    return best_idx
end

-- ============================================================
-- Zone-wide grid coverage
-- ============================================================

-- Build a uniform grid of coverage nodes from the current zone's waypoints.
-- Waypoints define the bounding box; the grid covers the full zone area
-- including off-path regions where chests can spawn.
-- Nodes that fail a walkability check are skipped at build time to avoid
-- running expensive uncapped A* against impassable terrain (cliffs, water).
function helltide_explorer.init_coverage()
    local wps = tracker.waypoints
    if not wps or #wps == 0 then return end
    -- Already built for this waypoint set
    if coverage_nodes and coverage_wp_count == #wps then return end

    -- Compute bounding box from all waypoints
    local min_x, max_x =  math.huge, -math.huge
    local min_y, max_y =  math.huge, -math.huge
    local ref_z = 0
    for _, wp in ipairs(wps) do
        local x, y = wp:x(), wp:y()
        if x < min_x then min_x = x end
        if x > max_x then max_x = x end
        if y < min_y then min_y = y end
        if y > max_y then max_y = y end
        ref_z = wp:z()
    end

    -- Expand by one grid cell so edge-of-zone chests aren't missed
    min_x = min_x - GRID_SPACING
    max_x = max_x + GRID_SPACING
    min_y = min_y - GRID_SPACING
    max_y = max_y + GRID_SPACING

    -- Generate the grid.
    -- Pre-filter: only keep nodes where is_point_walkeable passes.
    -- This eliminates water/cliff/wall centers before we ever attempt A* on them,
    -- avoiding 4-second synchronous pathfinding freezes for unreachable terrain.
    coverage_nodes = {}
    local skipped = 0
    for gx = min_x, max_x, GRID_SPACING do
        for gy = min_y, max_y, GRID_SPACING do
            local node = vec3:new(gx, gy, ref_z)
            node = utility.set_height_of_valid_position(node)
            if utility.is_point_walkeable(node) then
                coverage_nodes[#coverage_nodes + 1] = { pos = node, last_scouted = 0 }
            else
                skipped = skipped + 1
            end
        end
    end

    coverage_wp_count  = #wps
    current_target_idx = nil
    stuck_start_time   = nil
    stuck_target_idx   = nil
    stuck_check_pos    = nil

    console.print(string.format(
        "[EXPLORER] Grid built: %d walkable nodes (%d skipped non-walkable) | bounds (%.0f,%.0f)-(%.0f,%.0f) | spacing=%dm",
        #coverage_nodes, skipped, min_x, min_y, max_x, max_y, GRID_SPACING))
end

-- Called every frame from explore_helltide when experimental explorer is enabled.
-- Marks the current target node as scouted when player arrives, handles stuck
-- detection (movement-based, not purely time-based), and returns the vec3 to
-- navigate toward (or nil when just arrived or no nodes left).
function helltide_explorer.update_coverage(player_pos)
    if not coverage_nodes or #coverage_nodes == 0 then return nil end

    local now = get_time_since_inject()

    -- Gap detection: if this function wasn't called for >3s (e.g. player was in
    -- KILL_MONSTERS state), the accumulated wall-clock time would falsely trigger
    -- stuck detection. Reset stuck tracking on resume so only real no-movement counts.
    if last_update_time ~= nil and (now - last_update_time) > 3.0 then
        stuck_start_time = now
        stuck_check_pos  = player_pos
    end
    last_update_time = now

    -- Pick a new target if we don't have one
    if not current_target_idx then
        current_target_idx = get_next_coverage_idx()
        stuck_start_time   = now
        stuck_target_idx   = current_target_idx
        stuck_check_pos    = player_pos
        if current_target_idx then
            local n = coverage_nodes[current_target_idx]
            console.print(string.format(
                "[EXPLORER] New target: node %d at (%.1f,%.1f) | last_scouted=%.0f",
                current_target_idx, n.pos:x(), n.pos:y(), n.last_scouted))
        end
    end

    if not current_target_idx then return nil end

    local node = coverage_nodes[current_target_idx]
    local dist = player_pos:dist_to(node.pos)

    -- Arrived: mark scouted and clear target so next node is picked next frame
    if dist <= SCOUT_RADIUS then
        node.last_scouted  = now
        console.print(string.format(
            "[EXPLORER] Node %d scouted (dist=%.1f) — picking next target",
            current_target_idx, dist))
        current_target_idx = nil
        stuck_start_time   = nil
        stuck_target_idx   = nil
        stuck_check_pos    = nil
        return nil
    end

    -- Movement-based stuck detection:
    -- Reset the stuck timer whenever the player moves STUCK_MOVE_THRESH units.
    -- This prevents the timeout from firing during active long-path navigation.
    if stuck_target_idx == current_target_idx then
        if stuck_check_pos and player_pos:dist_to(stuck_check_pos) >= STUCK_MOVE_THRESH then
            stuck_start_time = now
            stuck_check_pos  = player_pos
        end

        if stuck_start_time and (now - stuck_start_time) > STUCK_TIMEOUT then
            console.print(string.format(
                "[EXPLORER] No movement on node %d for %ds — backoff %.0fs, trying next",
                current_target_idx, STUCK_TIMEOUT, STUCK_BACKOFF))
            node.last_scouted  = now + STUCK_BACKOFF
            current_target_idx = nil
            stuck_start_time   = nil
            stuck_target_idx   = nil
            stuck_check_pos    = nil
            return nil
        end
    else
        -- Target was reassigned; reset all stuck tracking
        stuck_start_time = now
        stuck_target_idx = current_target_idx
        stuck_check_pos  = player_pos
    end

    return node.pos
end

-- Entry point called from explore_helltide each frame.
function helltide_explorer.get_exploration_target(player_pos)
    helltide_explorer.init_coverage()
    return helltide_explorer.update_coverage(player_pos)
end

-- ============================================================
-- Chest registry
-- ============================================================

-- Scan the actor list for helltide chest actors within CHEST_SCAN_RADIUS.
-- Records new discoveries and logs them. Throttled to SCAN_THROTTLE seconds.
-- Accepts the cached actors table from get_cached_actors() in helltide.lua.
function helltide_explorer.scan_nearby_chests(actors, player_pos)
    if not actors then return end
    local now = get_time_since_inject()
    if now - last_scan_time < SCAN_THROTTLE then return end
    last_scan_time = now

    local current_cinders = get_helltide_coin_cinders()
    local newly_found = 0

    for _, actor in pairs(actors) do
        local skin = actor:get_skin_name()
        for chest_name, cost in pairs(enums.chest_types) do
            if skin:match(chest_name) then
                local pos  = actor:get_position()
                local dist = player_pos:dist_to(pos)
                if dist <= CHEST_SCAN_RADIUS then
                    local key = chest_key(pos)
                    if not opened_chests[key] and not found_chests[key] then
                        found_chests[key] = {
                            position   = pos,
                            name       = chest_name,
                            cost       = cost,
                            first_seen = now,
                            last_seen  = now,
                        }
                        scan_total  = scan_total + 1
                        newly_found = newly_found + 1
                        console.print(string.format(
                            "[EXPLORER] Chest found: %s | cost=%d cinders | pos=(%.1f,%.1f) | affordable=%s",
                            chest_name, cost, pos:x(), pos:y(),
                            tostring(current_cinders >= cost)))
                    elseif found_chests[key] then
                        found_chests[key].last_seen = now
                    end
                end
                break  -- matched chest_name for this actor, skip remaining types
            end
        end
    end

    if newly_found > 0 then
        console.print(string.format(
            "[EXPLORER] +%d new chest(s) this scan (total this helltide: %d)",
            newly_found, scan_total))
    end
end

-- Called after any helltide chest is successfully opened.
function helltide_explorer.mark_chest_opened(position)
    local key = chest_key(position)
    opened_chests[key] = true
    found_chests[key]  = nil
    console.print(string.format(
        "[EXPLORER] Chest opened at (%.1f,%.1f) — added to opened registry",
        position:x(), position:y()))
end

-- Called when Batmobile navigate_long_path returns false (no route found).
-- Marks the node permanently unreachable (math.huge) so the 4-second A* freeze
-- never repeats for this node during the current helltide hour.
function helltide_explorer.on_path_failed()
    if current_target_idx then
        console.print(string.format(
            "[EXPLORER] No route to node %d — marking permanently unreachable",
            current_target_idx))
        coverage_nodes[current_target_idx].last_scouted = math.huge
        current_target_idx = nil
        stuck_start_time   = nil
        stuck_target_idx   = nil
        stuck_check_pos    = nil
    end
end

-- Returns the vec3 position of the cheapest affordable found (unopened) chest,
-- or nil. Available for external use but chest routing is handled by check_events.
function helltide_explorer.get_affordable_found_chest()
    local cinders   = get_helltide_coin_cinders()
    local best_pos  = nil
    local best_cost = math.huge
    for _, entry in pairs(found_chests) do
        if cinders >= entry.cost and entry.cost < best_cost then
            best_pos  = entry.position
            best_cost = entry.cost
        end
    end
    return best_pos
end

-- ============================================================
-- Helltide-end detection
-- ============================================================

-- Detects the helltide->no-helltide transition and fires full_reset().
-- Registered as an on_update callback so it runs every frame regardless
-- of which task is active — the reset fires even when the helltide task
-- has yielded control to search_helltide.
function helltide_explorer.update()
    local lp = get_local_player()
    if not lp then return end
    local in_helltide = utils.is_in_helltide()
    if was_in_helltide and not in_helltide then
        full_reset()
    end
    was_in_helltide = in_helltide
end

on_update(function()
    helltide_explorer.update()
end)

return helltide_explorer
