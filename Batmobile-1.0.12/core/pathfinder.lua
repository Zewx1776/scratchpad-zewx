local utils = require 'core.utils'
local settings = require 'core.settings'
local tracker = require 'core.tracker'

local pathfinder = {}

-- Pre-computed constant
local SQRT2_MINUS1 = math.sqrt(2) - 1

local get_lowest_f_score = function (open_set, f_score)
    local lowest = nil
    local lowest_node = nil
    for node_str, node in pairs(open_set) do
        if lowest == nil or f_score[node_str] < f_score[lowest] then
            lowest = node_str
            lowest_node = node
        end
    end
    return lowest, lowest_node
end
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
    local goal_node = utils.normalize_node(goal)
    local start_str = utils.vec_to_string(start_node)
    local open_set = {[start_str] = start_node}
    local closed_set = {}
    local g_score = {[start_str] = 0}
    local f_score = {[start_str] = heuristic(start_node, goal_node)}
    local prev_nodes = {}
    local counter = 0
    local evaluated = shared_evaluated or {}
    local path_start_time = os.clock()
    -- Scale limits by distance: far targets need more A* iterations
    local goal_dist = heuristic(start_node, goal_node)
    local iter_limit = math.max(1500, math.min(5000, math.floor(goal_dist * 150)))
    local time_limit = math.max(0.100, math.min(0.300, goal_dist * 0.012))

    -- Pre-compute directions once per find_path call
    -- (previously recreated inside get_valid_neighbor and get_neighbors on every call)
    local dist = settings.step
    local directions = {
        {-dist, 0},
        {0, dist},
        {dist, 0},
        {0, -dist},
        {-dist, dist},
        {-dist, -dist},
        {dist, dist},
        {dist, -dist},
    }

    -- Replaced: while utils.get_set_count(open_set) > 0
    -- Old approach iterated entire open_set just to count elements: O(n) per iteration
    -- New approach: get_lowest_f_score returns nil when open_set is empty: O(1) check
    while true do
        local cur_str, cur_node = get_lowest_f_score(open_set, f_score)
        if cur_str == nil then break end
        if counter > iter_limit or (os.clock() - path_start_time) > time_limit then
            utils.log(1, 'no path (over limit) ' .. utils.vec_to_string(start) .. '>' .. utils.vec_to_string(goal))
            tracker.bench_stop("find_path")
            return {}
        end
        counter = counter + 1
        if utils.distance(cur_node, goal_node) == 0 then
            utils.log(2, 'path found')
            -- tracker.evaluated = evaluated
            tracker.bench_stop("find_path")
            return reconstruct_path(closed_set, prev_nodes, cur_node)
        end
        open_set[cur_str] = nil
        closed_set[cur_str] = cur_node

        local ignore_walls = is_custom_target or utils.distance(start_node, cur_node) < 1
        local neighbours
        neighbours, evaluated = get_neighbors(cur_node, goal_node, evaluated, ignore_walls, directions)

        for _, neighbor in ipairs(neighbours) do
            local neigh_str = utils.vec_to_string(neighbor)
            if closed_set[neigh_str] == nil then
                local t_g_score = g_score[cur_str] + utils.distance(cur_node, neighbor)
                if open_set[neigh_str] == nil or t_g_score < g_score[neigh_str] then
                    prev_nodes[neigh_str] = cur_str
                    g_score[neigh_str] = t_g_score
                    f_score[neigh_str] = t_g_score + heuristic(neighbor, goal_node)
                end
                if open_set[neigh_str] == nil then
                    open_set[neigh_str] = neighbor
                end
            end
        end
    end
    utils.log(1, 'no path (no openset) ' .. utils.vec_to_string(start) .. '>' .. utils.vec_to_string(goal))
    tracker.bench_stop("find_path")
    return {}
end

return pathfinder
