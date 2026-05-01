local utils      = require 'core.utils'
local pathfinder = require 'core.pathfinder'
local navigator  = require 'core.navigator'

-- Long-path debug + future external API module.
-- set_target()      : pins current player position as path goal
-- test_path()       : runs uncapped A*, draws the route, and moves to the target
-- find_long_path()  : external API — finds path without normal distance-scaled limits
local long_path = {
    pinned_target = nil,   -- vec3 saved by set_target()
    active_path   = nil,   -- full computed path (for drawing the full route)
    navigating    = false, -- true while moving to target
}

function long_path.set_target()
    local player = get_local_player()
    if not player then
        console.print("[LONG PATH] No player — cannot set target")
        return
    end
    long_path.pinned_target = player:get_position()
    console.print(string.format("[LONG PATH] Target pinned at (%.2f, %.2f, %.2f)",
        long_path.pinned_target:x(),
        long_path.pinned_target:y(),
        long_path.pinned_target:z()))
end

function long_path.set_target_cursor()
    local cursor = get_cursor_position()
    if not cursor then
        console.print("[LONG PATH] No cursor position available")
        return
    end
    -- Snap to valid Z so the pinned point renders correctly on the ground
    local snapped = utility.set_height_of_valid_position(cursor)
    long_path.pinned_target = snapped
    console.print(string.format("[LONG PATH] Target pinned at cursor (%.2f, %.2f, %.2f)",
        snapped:x(), snapped:y(), snapped:z()))
end

local function start_navigation(path, goal)
    long_path.active_path = path
    long_path.navigating  = true
    -- Inject path into navigator without calling navigator.reset(), which would wipe
    -- explorer.backtrack and explorer.visited — shared state used by explore_pit.
    -- Reset only the navigator-level fields so both modes share the same backtrack.
    navigator.done                   = false
    navigator.done_delay             = nil
    navigator.last_trav              = nil
    navigator.trav_delay             = nil
    navigator.trav_final_target      = nil
    navigator.unstuck_nodes          = {}
    navigator.unstuck_count          = 0
    navigator.pathfind_fail_count    = 0
    navigator.failed_target          = nil
    navigator.failed_target_time     = -1
    navigator.failed_target_radius   = 15
    navigator.target           = utils.normalize_node(goal)
    navigator.is_custom_target = true
    navigator.path             = path
    navigator.paused           = false
    console.print(string.format("[LONG PATH] Navigation started | nodes=%d | target=(%.1f, %.1f)",
        #path, navigator.target:x(), navigator.target:y()))
end

function long_path.stop_navigation()
    if not long_path.navigating then return end
    long_path.navigating  = false
    long_path.active_path = nil
    navigator.clear_target()
    console.print("[LONG PATH] Navigation stopped")
end

function long_path.test_path()
    -- If already navigating, stop first
    if long_path.navigating then
        long_path.stop_navigation()
        return
    end
    if not long_path.pinned_target then
        console.print("[LONG PATH] No target pinned — click 'Set Target' first")
        return
    end
    local player = get_local_player()
    if not player then
        console.print("[LONG PATH] No player")
        return
    end
    local start = player:get_position()
    local goal  = long_path.pinned_target
    local dist  = utils.distance(start, goal)
    console.print("[LONG PATH] === Test Long Path ===")
    console.print(string.format("[LONG PATH] From (%.2f, %.2f)  To (%.2f, %.2f)  dist=%.1f",
        start:x(), start:y(), goal:x(), goal:y(), dist))
    console.print("[LONG PATH] Running uncapped A* (safety caps: 100k iter / 15s) ...")

    local path, iters, elapsed, status = pathfinder.find_path_debug(start, goal)
    local ms = elapsed * 1000

    local normal_iter = math.max(1500, math.min(5000, math.floor(dist * 150)))
    local normal_ms   = math.max(100,  math.min(300,  dist * 12))
    console.print(string.format("[LONG PATH] Normal limits at this dist: iter=%d  time=%.0fms",
        normal_iter, normal_ms))

    if status == "found" then
        console.print(string.format("[LONG PATH] RESULT: SUCCESS | nodes=%d | iters=%d | time=%.1fms",
            #path, iters, ms))
        start_navigation(path, goal)
    elseif status == "no_path_partial" or status == "iter_limit_partial" or status == "time_limit_partial" then
        console.print(string.format("[LONG PATH] RESULT: PARTIAL PATH (%s) | nodes=%d | iters=%d | time=%.1fms",
            status, #path, iters, ms))
        start_navigation(path, goal)
    elseif status == "no_path" then
        console.print(string.format("[LONG PATH] RESULT: NO PATH (open-set exhausted) | iters=%d | time=%.1fms",
            iters, ms))
    elseif status == "iter_limit" then
        console.print(string.format("[LONG PATH] RESULT: HIT SAFETY ITER LIMIT (100k) | iters=%d | time=%.1fms",
            iters, ms))
    elseif status == "time_limit" then
        console.print(string.format("[LONG PATH] RESULT: HIT SAFETY TIME LIMIT (15s) | iters=%d | time=%.1fms",
            iters, ms))
    end
end

-- External API: find a path without normal distance-scaled caps.
-- Returns the path table (array of vec3), or nil on failure.
-- Intended for future use: BatmobilePlugin.find_long_path(caller, target)
function long_path.find_long_path(start, goal)
    if goal.get_position then goal = goal:get_position() end
    local dist = utils.distance(start, goal)
    local path, iters, elapsed, status = pathfinder.find_path_debug(start, goal)
    local ms = elapsed * 1000
    console.print(string.format("[LONG PATH] find_long_path: dist=%.1f  status=%s  %s  iters=%d  time=%.1fms",
        dist, status,
        path and ("nodes=" .. #path) or "NO PATH",
        iters, ms))
    return path
end

-- Navigate to a goal using uncapped A*.  Finds the path then immediately starts
-- walking it via the navigator.  Returns true if a path was found and navigation
-- was started, false if A* failed to find a path.
function long_path.navigate_to(goal)
    if goal.get_position then goal = goal:get_position() end
    local player = get_local_player()
    if not player then
        console.print("[LONG PATH] navigate_to: no player")
        return false
    end
    local start = player:get_position()
    local dist  = utils.distance(start, goal)
    console.print(string.format("[LONG PATH] navigate_to: finding uncapped path (dist=%.1f) ...", dist))
    local path, iters, elapsed, status = pathfinder.find_path_debug(start, goal)
    local ms = elapsed * 1000
    local is_partial = status == "no_path_partial" or status == "iter_limit_partial" or status == "time_limit_partial"
    if status == "found" or (is_partial and path ~= nil and #path > 0) then
        console.print(string.format("[LONG PATH] navigate_to: %s  nodes=%d  iters=%d  time=%.1fms",
            status, #path, iters, ms))
        start_navigation(path, goal)
        -- Mark partial so the navigator's stall-escape can engage traversal
        -- routing if the player can't make progress (e.g. portal across a
        -- climb gizmo). Without this, long_path's partial paths look like
        -- normal navigation to the navigator and traversal logic never fires.
        if is_partial then
            navigator.is_partial_path = true
            navigator.partial_target_ref = navigator.target
            navigator.partial_target_best_dist = utils.distance(start, goal)
            navigator.partial_target_last_progress_time = get_time_since_inject()
        end
        return true
    else
        console.print(string.format("[LONG PATH] navigate_to: %s  iters=%d  time=%.1fms",
            status, iters, ms))
        return false
    end
end

return long_path
