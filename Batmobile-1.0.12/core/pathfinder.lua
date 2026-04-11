local utils = require 'core.utils'
local settings = require 'core.settings'
local tracker = require 'core.tracker'

local pathfinder = {}

-- Pre-computed constant
local SQRT2_MINUS1 = math.sqrt(2) - 1

-- Min-heap priority queue used by A* open set.
-- Replaces the previous O(n) linear scan (get_lowest_f_score) with O(log n)
-- push/pop, dramatically reducing pathfind time on large or complex maps.
-- Uses lazy deletion: stale heap entries (node already closed) are skipped on pop.
local Heap = {}
Heap.__index = Heap
local function new_heap()
    return setmetatable({ data = {}, size = 0 }, Heap)
end
function Heap:push(f, node_str, node)
    self.size = self.size + 1
    self.data[self.size] = { f = f, s = node_str, n = node }
    -- sift up
    local i = self.size
    local d = self.data
    while i > 1 do
        local p = math.floor(i / 2)
        if d[p].f <= d[i].f then break end
        d[p], d[i] = d[i], d[p]
        i = p
    end
end
function Heap:pop()
    local top = self.data[1]
    local last = self.data[self.size]
    self.data[self.size] = nil
    self.size = self.size - 1
    if self.size > 0 then
        self.data[1] = last
        -- sift down
        local i = 1
        local d = self.data
        local sz = self.size
        while true do
            local s = i
            local l = i * 2
            local r = l + 1
            if l <= sz and d[l].f < d[s].f then s = l end
            if r <= sz and d[r].f < d[s].f then s = r end
            if s == i then break end
            d[i], d[s] = d[s], d[i]
            i = s
        end
    end
    return top.f, top.s, top.n
end
function Heap:empty() return self.size == 0 end
local heuristic = function (a, b)
    local dx = math.abs(a:x() - b:x())
    local dy = math.abs(a:y() - b:y())
    return math.max(dx, dy) + SQRT2_MINUS1 * math.min(dx, dy)
end
local reconstruct_path = function (closed_set, prev_nodes, cur_node)
    local path = {cur_node}
    local cur_str = utils.vec_to_string(cur_node)
    while prev_nodes[cur_str] ~= nil do
        cur_str = prev_nodes[cur_str]
        cur_node = closed_set[cur_str]
        table.insert(path, 1, cur_node)
    end
    return path
end

local get_valid_neighbor = function (cur_node, goal, x, y, evaluated, ignore_walls, directions)
    local node, node_str, result, valid
    node_str = tostring(x) .. ',' .. tostring(y)
    result = evaluated[node_str]
    if result == nil then
        node = vec3:new(x, y, cur_node:z())
        node = utils.get_valid_node(node, goal:z())
        valid = node ~= nil
    else
        valid, node = result[1], result[2]
    end

    evaluated[node_str] = {valid, node}
    if not valid then
        return nil, evaluated
    end

    if ignore_walls then
        return node, evaluated
    end

    -- Use pre-computed directions table instead of creating a new one each call
    for _, direction in ipairs(directions) do
        local dx = direction[1]
        local dy = direction[2]
        local newx = node:x() + dx
        local newy = node:y() + dy
        local new_node_str = tostring(newx) .. ',' .. tostring(newy)
        result = evaluated[new_node_str]
        if result == nil then
            local new_node = vec3:new(newx, newy, cur_node:z())
            if newx == goal:x() and newy == goal:y() then
                evaluated[new_node_str] = {true, new_node}
                return node, evaluated
            end
            new_node = utils.get_valid_node(new_node, goal:z())
            evaluated[new_node_str] = {new_node ~= nil, new_node}
            if new_node == nil then
                return nil, evaluated
            end
        else
            if not result[1] then
                return nil, evaluated
            end
        end
    end

    return node, evaluated
end
local get_neighbors = function (node, goal, evaluated, ignore_walls, directions)
    local neighbors = {}
    for _, direction in ipairs(directions) do
        local dx = direction[1]
        local dy = direction[2]
        local newx = node:x() + dx
        local newy = node:y() + dy
        if (newx == goal:x() and newy == goal:y()) then
            neighbors = {goal}
            break
        end
        local valid = nil
        valid, evaluated = get_valid_neighbor(node, goal, newx, newy, evaluated, ignore_walls, directions)

        if valid ~= nil then
            neighbors[#neighbors+1] = valid
        end
    end
    return neighbors, evaluated
end
pathfinder.find_path = function (start, goal, is_custom_target, shared_evaluated)
    tracker.bench_start("find_path")
    utils.log(2, 'start find path')
    local start_node = utils.normalize_node(start)
    local goal_node  = utils.normalize_node(goal)
    local start_str  = utils.vec_to_string(start_node)

    -- Min-heap open set (lazy deletion — stale entries skipped when popped)
    local heap      = new_heap()
    local in_open   = {}   -- node_str -> best g_score pushed so far (for duplicate suppression)
    local closed_set = {}
    local g_score   = { [start_str] = 0 }
    local prev_nodes = {}
    local counter   = 0
    local evaluated = shared_evaluated or {}
    local path_start_time = os.clock()

    -- Scale limits by distance: far targets need more A* iterations.
    -- Custom targets (kill_monster) get the full 600ms budget; explorer targets are
    -- capped at 300ms so a single unreachable frontier can't freeze the game for half a second.
    local goal_dist   = heuristic(start_node, goal_node)
    local iter_limit  = math.max(3000, math.min(10000, math.floor(goal_dist * 300)))
    local time_cap    = is_custom_target and 0.350 or 0.300
    local time_limit  = math.max(0.100, math.min(time_cap, goal_dist * 0.024))

    -- Pre-compute directions once per find_path call
    local dist = settings.step
    local directions = {
        {-dist, 0},
        {0,  dist},
        { dist, 0},
        {0, -dist},
        {-dist,  dist},
        {-dist, -dist},
        { dist,  dist},
        { dist, -dist},
    }

    local start_h = heuristic(start_node, goal_node)
    heap:push(start_h, start_str, start_node)
    in_open[start_str] = 0

    while not heap:empty() do
        if counter > iter_limit or (os.clock() - path_start_time) > time_limit then
            utils.log(1, 'no path (over limit) ' .. utils.vec_to_string(start) .. '>' .. utils.vec_to_string(goal))
            tracker.bench_stop("find_path")
            return {}
        end

        local _, cur_str, cur_node = heap:pop()

        -- Lazy deletion: skip if already closed (stale heap entry)
        if closed_set[cur_str] then goto continue end

        counter = counter + 1

        if utils.distance(cur_node, goal_node) == 0 then
            utils.log(2, 'path found')
            tracker.bench_stop("find_path")
            return reconstruct_path(closed_set, prev_nodes, cur_node)
        end

        closed_set[cur_str] = cur_node

        local ignore_walls = is_custom_target or utils.distance(start_node, cur_node) < 1
        local neighbours
        neighbours, evaluated = get_neighbors(cur_node, goal_node, evaluated, ignore_walls, directions)

        for _, neighbor in ipairs(neighbours) do
            local neigh_str = utils.vec_to_string(neighbor)
            if not closed_set[neigh_str] then
                local t_g = g_score[cur_str] + utils.distance(cur_node, neighbor)
                if g_score[neigh_str] == nil or t_g < g_score[neigh_str] then
                    prev_nodes[neigh_str] = cur_str
                    g_score[neigh_str]    = t_g
                    local f = t_g + heuristic(neighbor, goal_node)
                    heap:push(f, neigh_str, neighbor)
                    in_open[neigh_str] = t_g
                end
            end
        end

        ::continue::
    end

    utils.log(1, 'no path (no openset) ' .. utils.vec_to_string(start) .. '>' .. utils.vec_to_string(goal))
    tracker.bench_stop("find_path")
    return {}
end

-- Debug variant: no distance-scaled limits — runs until path found, open-set exhausted,
-- or safety caps hit. Returns (path_or_nil, iterations, elapsed_seconds, status_string).
-- status: "found" | "no_path" | "iter_limit" | "time_limit"
pathfinder.find_path_debug = function(start, goal)
    local start_node = utils.normalize_node(start)
    local goal_node  = utils.normalize_node(goal)
    local start_str  = utils.vec_to_string(start_node)
    local open_set   = {[start_str] = start_node}
    local closed_set = {}
    local g_score    = {[start_str] = 0}
    local f_score    = {[start_str] = heuristic(start_node, goal_node)}
    local prev_nodes = {}
    local counter    = 0
    local evaluated  = {}
    local t0         = os.clock()

    -- Safety ceiling — prevents total game freeze; still far above normal 5000/0.3s limits
    local HARD_ITER_LIMIT = 100000
    local HARD_TIME_LIMIT = 15.0

    local dist = settings.step
    local directions = {
        {-dist, 0}, {0, dist}, {dist, 0}, {0, -dist},
        {-dist, dist}, {-dist, -dist}, {dist, dist}, {dist, -dist},
    }

    while true do
        local cur_str, cur_node = get_lowest_f_score(open_set, f_score)
        if cur_str == nil then
            return nil, counter, os.clock() - t0, "no_path"
        end
        if counter >= HARD_ITER_LIMIT then
            return nil, counter, os.clock() - t0, "iter_limit"
        end
        if (os.clock() - t0) >= HARD_TIME_LIMIT then
            return nil, counter, os.clock() - t0, "time_limit"
        end
        counter = counter + 1
        if utils.distance(cur_node, goal_node) == 0 then
            return reconstruct_path(closed_set, prev_nodes, cur_node), counter, os.clock() - t0, "found"
        end
        open_set[cur_str] = nil
        closed_set[cur_str] = cur_node

        local neighbours
        neighbours, evaluated = get_neighbors(cur_node, goal_node, evaluated, true, directions)
        for _, neighbor in ipairs(neighbours) do
            local neigh_str = utils.vec_to_string(neighbor)
            if closed_set[neigh_str] == nil then
                local t_g = g_score[cur_str] + utils.distance(cur_node, neighbor)
                if open_set[neigh_str] == nil or t_g < g_score[neigh_str] then
                    prev_nodes[neigh_str] = cur_str
                    g_score[neigh_str]    = t_g
                    f_score[neigh_str]    = t_g + heuristic(neighbor, goal_node)
                end
                if open_set[neigh_str] == nil then
                    open_set[neigh_str] = neighbor
                end
            end
        end
    end
end

return pathfinder
