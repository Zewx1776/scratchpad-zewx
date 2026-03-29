local explorer = require 'core.explorer'
local path_finder = require 'core.pathfinder'
local utils = require 'core.utils'
local settings = require 'core.settings'
local tracker = require 'core.tracker'

local navigator = {
    last_pos = nil,
    last_update = nil,
    target = nil,
    done = false,
    paused = false,
    path = {},
    last_trav = nil,
    trav_delay = nil,
    done_delay = nil,
    movement_step = 4,
    movement_dist = math.sqrt(4*4*2), -- diagonal dist
    spell_dist = 12,
    spell_time = -1,
    spell_timeout = 0.5,
    blacklisted_spell_node = {},
    unstuck_nodes = {},
    unstuck_count = 0,
    pathfind_fail_count = 0,
    exploration_resets = 0,
    failed_target = nil,
    failed_target_time = -1,
    failed_target_cooldown = 15,
    failed_target_radius = 15,
    trav_final_target = nil,
    blacklisted_trav = {},
    move_time = -1,
    move_timeout = 0.05,
    update_time = -1,
    update_timeout = 0.05,
    disable_spell = nil,
    is_custom_target = false,
}

-- Per-frame caching to avoid redundant expensive calls
-- Cache expires after 10ms (well within a single 50ms frame)
local _cache_duration = 0.01
local _trav_cache = nil
local _trav_cache_time = -1
local _buff_cache = nil
local _buff_cache_time = -1
local get_nearby_travs = function (local_player)
    -- Cache: scanning all actors is expensive, avoid doing it 2-3x per frame
    local now = get_time_since_inject()
    if now - _trav_cache_time < _cache_duration then
        return _trav_cache
    end
    tracker.bench_start("get_nearby_travs")
    local traversals = {}
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name:match('[Tt]raversal_Gizmo') then
            traversals[#traversals+1] = actor
        end
    end
    _trav_cache = traversals
    _trav_cache_time = now
    tracker.bench_stop("get_nearby_travs")
    return traversals
end
local has_traversal_buff = function (local_player)
    -- Cache: buff scanning called 3-4x per frame, only need to scan once
    local now = get_time_since_inject()
    if _buff_cache ~= nil and now - _buff_cache_time < _cache_duration then
        return _buff_cache
    end
    local buffs = local_player:get_buffs()
    for _, buff in pairs(buffs) do
        if buff:name():match('Player_Traversal')  then
            _buff_cache = true
            _buff_cache_time = now
            return true
        end
    end
    _buff_cache = false
    _buff_cache_time = now
    return false
end
local get_closeby_node = function (trav_node, max_dist)
    tracker.bench_start("get_closeby_node")
    local local_player = get_local_player()
    if not local_player then
        tracker.bench_stop("get_closeby_node")
        return nil
    end
    local cur_node = utils.normalize_node(local_player:get_position())
    local norm_trav = utils.normalize_node(trav_node)
    local step = settings.step

    local nodes = {}
    for i = norm_trav:x()-max_dist, norm_trav:x()+max_dist, step do
        for j = norm_trav:y()-max_dist, norm_trav:y()+max_dist, step do
            local new_node =  vec3:new(i, j, cur_node:z())
            local valid = utility.set_height_of_valid_position(new_node)
            local walkable = utility.is_point_walkeable(valid)
            local diff_z = utils.distance_z(trav_node, valid)
            if walkable and diff_z < 1 then
                nodes[#nodes+1] = new_node
            end
        end
    end
    table.sort(nodes, function(a, b)
        return utils.distance(a, norm_trav) < utils.distance(b, norm_trav)
    end)
    -- Share evaluated (walkability) cache across find_path calls:
    -- nearby goals overlap heavily in A* exploration, so reusing the cache
    -- avoids thousands of redundant engine walkability checks
    local shared_eval = {}
    local max_attempts = 8  -- limit expensive pathfinding; if closest 8 nodes unreachable, portal is blocked
    local attempts = 0
    for _, node in ipairs(nodes) do
        if attempts >= max_attempts then break end
        local result = path_finder.find_path(cur_node, node, navigator.is_custom_target, shared_eval)
        attempts = attempts + 1
        if #result > 0 then
            tracker.bench_stop("get_closeby_node")
            return node
        end
    end
    tracker.bench_stop("get_closeby_node")
    return nil
end
local get_movement_spell_id = function(local_player)
    if not settings.use_movement then return end
    if navigator.disable_spell == true then return end
    if navigator.spell_time + navigator.spell_timeout > get_time_since_inject() then return end
    navigator.spell_time = get_time_since_inject()
    local class = utils.get_character_class(local_player)
    if class == 'sorcerer' then
        if settings.use_teleport and utility.can_cast_spell(288106) then
            return 288106, false
        end
        if settings.use_teleport_enchanted and utility.can_cast_spell(959728) then
            return 959728, false
        end
    elseif class == 'spiritborn' then
        if settings.use_soar and utility.can_cast_spell(1871821) then
            return 1871821, false
        end
        if settings.use_rushing_claw and utility.can_cast_spell(1871761) then
            return 1871761, false
        end
        if settings.use_hunter and utility.can_cast_spell(1663206) then
            return 1663206, false
        end
    elseif class == 'rogue' then
        if settings.use_dash and utility.can_cast_spell(358761) then
            return 358761, false
        end
    elseif class == 'barbarian' then
        if settings.use_leap and utility.can_cast_spell(196545) then
            return 196545, false
        end
        if settings.use_charge and utility.can_cast_spell(204662) then
            return 204662, true
        end
    elseif class == 'paladin' then
        if settings.use_advance and utility.can_cast_spell(2329865) then
            return 2329865, true
        end
        if settings.use_falling_star and utility.can_cast_spell(2106904) then
            return 2106904, true
        end
        if settings.use_aoj and utility.can_cast_spell(2297125) then
            return 2297125, true
        end
    end
    -- class == 'default' or class == 'druid' or class == 'necromancer'
    -- everyone has evade (hopefully)
    if settings.use_evade and utility.can_cast_spell(337031) then
        return 337031, false
    end
    return nil, false
end
local select_target
select_target = function (prev_target)
    local local_player = get_local_player()
    if not local_player then return nil end
    local player_pos = local_player:get_position()
    local traversals = get_nearby_travs(local_player)
    if #traversals > 0 then
        local closest_trav = nil
        local closest_dist = nil
        local closest_pos = nil
        local closest_str = nil
        for _, trav in ipairs(traversals) do
            local trav_pos = trav:get_position()
            local trav_name = trav:get_skin_name()
            local trav_str = trav_name .. utils.vec_to_string(trav_pos)
            local cur_dist = utils.distance_z(player_pos, trav_pos)
            if navigator.blacklisted_trav[trav_str] == nil and
                (closest_trav == nil or cur_dist < closest_dist) and
                utils.distance(player_pos, trav_pos) <= 15
            then
                closest_dist = cur_dist
                closest_trav = trav
                closest_pos = trav_pos
                closest_str = trav_str
            end
        end
        -- local diff_z = utils.distance_z(closest_pos, player_pos)
        if closest_trav ~= nil and
            closest_dist <= 15 and
            navigator.last_trav == nil and
            closest_pos ~= nil and
            math.abs(closest_pos:z() - player_pos:z()) <= 3 and
            (navigator.trav_delay == nil or get_time_since_inject() > navigator.trav_delay)
        then
            local closest_node = get_closeby_node(closest_trav:get_position(), 2)
            if closest_node == nil then
                navigator.blacklisted_trav[closest_str] = closest_str
                return select_target(prev_target)
            end
            navigator.last_trav = closest_trav
            utils.log(1, 'selecting traversal ' .. closest_trav:get_skin_name())
            return closest_node
        end
    else
        navigator.last_trav = nil
        navigator.blacklisted_trav = {}
    end
    local target = explorer.select_node(local_player, prev_target)
    if target ~= nil then
        local dist = utils.distance(local_player:get_position(), target)
        console.print('[select_target] picked ' .. utils.vec_to_string(target) .. ' dist=' .. string.format('%.1f', dist) .. ' frontiers=' .. explorer.frontier_count .. ' bt=#' .. #explorer.backtrack .. ' bting=' .. tostring(explorer.backtracking))
    else
        console.print('[select_target] nil, frontiers=' .. explorer.frontier_count .. ' bt=#' .. #explorer.backtrack)
    end
    return target
end
local function shuffle_table(tbl)
    local len = #tbl
    for i = len, 2, -1 do
        -- Generate a random index 'j' between 1 and 'i' (inclusive)
        local j = math.random(i)
        -- Swap the elements at positions 'i' and 'j'
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end
local get_unstuck_node = function ()
    -- get a node that is perpendicular to the first node in path from current node
    -- i.e. turn 90 degress left or right 
    local cur_node = navigator.last_pos
    local step = navigator.movement_step
    local test_node, test_node_str, valid, walkable

    if cur_node ~= nil then
        local x = cur_node:x()
        local y = cur_node:y()

        local directions = {
            {-step, 0},  -- up
            {0, step}, -- right
            {step, 0}, -- down
            {0, -step}, -- left
            {-step, step}, -- up-right
            {-step, -step}, -- up-left
            {step, step}, -- down-right
            {step, -step}, -- down-left
        }
        -- randomize direction order
        directions = shuffle_table(directions)
        for _, direction in ipairs(directions) do
            local dx = direction[1]
            local dy = direction[2]
            local new_x = x + dx
            local new_y = y + dy
            test_node = vec3:new(new_x, new_y, cur_node:z())
            test_node_str = utils.vec_to_string(test_node)
            valid = utility.set_height_of_valid_position(test_node)
            walkable = utility.is_point_walkeable(valid)
            if walkable and navigator.unstuck_nodes[test_node_str] ~= 'injected' then
                return valid, test_node_str
            end
        end
    end
    return nil, nil
end
local unstuck = function (local_player)
    navigator.unstuck_count = navigator.unstuck_count + 1

    -- After too many consecutive unstuck attempts, blacklist the area and force a new target
    if navigator.unstuck_count >= 5 then
        console.print('[unstuck] EXHAUSTED (' .. navigator.unstuck_count .. ' attempts), blacklisting 16x16 area around ' .. (navigator.last_pos and utils.vec_to_string(navigator.last_pos) or 'nil'))
        local pos = navigator.last_pos
        if pos then
            local step = settings.step or 2
            for i = -8, 8, step do
                for j = -8, 8, step do
                    local node_str = tostring(utils.normalize_value(pos:x() + i)) .. ',' .. tostring(utils.normalize_value(pos:y() + j))
                    explorer.visited[node_str] = node_str
                end
            end
        end
        navigator.target = select_target(navigator.target)
        navigator.is_custom_target = false
        navigator.unstuck_nodes = {}
        navigator.unstuck_count = 0
        return
    end

    local unstuck_node, unstuck_node_str = get_unstuck_node()
    if unstuck_node ~= nil and unstuck_node_str ~= nil then
        -- try evade if not add to path
        local movement_spell_id, need_raycast = get_movement_spell_id(local_player)
        local raycast_success = true
        if need_raycast then
            local dist = utils.distance(navigator.last_pos, unstuck_node)
            raycast_success = utility.is_ray_cast_walkeable(navigator.last_pos, unstuck_node, 0.5, dist)
        end
        if utility.can_cast_spell(337031) and
            navigator.unstuck_nodes[unstuck_node_str] == nil
        then
            utils.log(1, 'unstuck by evading')
            navigator.unstuck_nodes[unstuck_node_str] = 'evaded'
            cast_spell.position(337031, unstuck_node, 0)
            return
        elseif movement_spell_id ~= nil and raycast_success and
            (navigator.unstuck_nodes[unstuck_node_str] == nil or
            navigator.unstuck_nodes[unstuck_node_str] == 'evaded')
        then
            utils.log(1, 'unstuck by movement spell')
            navigator.unstuck_nodes[unstuck_node_str] = 'teleporting'
            cast_spell.position(movement_spell_id, unstuck_node, 0)
            return
        else
            utils.log(1, 'unstuck by injecting path')
            navigator.unstuck_nodes[unstuck_node_str] = 'injected'
            table.insert(navigator.path, 1, unstuck_node)
            return
        end
    end
    utils.log(1, 'unstuck by choosing new target')
    navigator.target = select_target(navigator.target)
    navigator.is_custom_target = false
    navigator.unstuck_nodes = {}
end
navigator.is_done = function ()
    return navigator.done
end
navigator.pause = function ()
    navigator.paused = true
    tracker.paused = true
end
navigator.unpause = function ()
    navigator.paused = false
    tracker.paused = false
end
navigator.update = function ()
    if navigator.update_time + navigator.update_timeout > get_time_since_inject() then return end
    navigator.update_time = get_time_since_inject()
    local local_player = get_local_player()
    if not local_player then return end
    if has_traversal_buff(local_player) then return end
    -- Detect death/respawn: sudden large position jump (>50 units) that is not a traversal.
    -- After respawn the checkpoint position must NOT be appended to the backtrack path —
    -- doing so creates a spurious backtrack entry that doubles up the exploration route.
    -- Setting backtracking=true prevents set_current_pos from adding the checkpoint,
    -- so the next select_target call directly pops the real last-explored point.
    if explorer.cur_pos ~= nil and
        (navigator.trav_delay == nil or get_time_since_inject() > navigator.trav_delay)
    then
        local jump_dist = utils.distance(local_player:get_position(), explorer.cur_pos)
        if jump_dist > 50 then
            console.print('[nav] respawn detected (jumped ' .. string.format('%.1f', jump_dist) .. ' units), resuming from last backtrack point')
            explorer.backtracking = true
            navigator.target = nil
            navigator.is_custom_target = false
            navigator.path = {}
            navigator.trav_final_target = nil
            navigator.failed_target = nil
        end
    end
    explorer.update(local_player)
end
navigator.reset = function ()
    utils.log(1, 'reseting')
    explorer.reset()
    navigator.target = nil
    navigator.is_custom_target = false
    navigator.done = false
    navigator.done_delay = nil
    navigator.path = {}
    navigator.last_trav = nil
    navigator.trav_delay = nil
    navigator.last_pos = nil
    navigator.last_update = nil
    navigator.done_delay = nil
    navigator.unstuck_nodes = {}
    navigator.unstuck_count = 0
    navigator.pathfind_fail_count = 0
    navigator.exploration_resets = 0
    navigator.failed_target = nil
    navigator.failed_target_time = -1
    navigator.failed_target_radius = 15
    navigator.trav_final_target = nil
    navigator.blacklisted_trav = {}
    navigator.blacklisted_spell_node = {}
end
navigator.set_target = function (target, disable_spell)
    if target.get_position then
        target = target:get_position()
    end
    local new_target = utils.normalize_node(target)
    -- Reject targets near a recently-failed position
    if navigator.failed_target and
        utils.distance(new_target, navigator.failed_target) < navigator.failed_target_radius and
        get_time_since_inject() - navigator.failed_target_time < navigator.failed_target_cooldown
    then
        return false
    end
    -- If we are mid-traversal to reach a custom target, don't disrupt the route
    -- (kill_monster keeps calling set_target every frame; return true so it doesn't
    -- mark the enemy unreachable, but keep routing to the traversal node)
    if navigator.trav_final_target ~= nil and navigator.last_trav ~= nil then
        if utils.distance(new_target, navigator.trav_final_target) < 50 then
            return true  -- silently accepted — traversal route in progress
        else
            -- Different enemy: abort traversal route, accept new target
            navigator.trav_final_target = nil
        end
    end
    if navigator.target == nil or
        utils.distance(navigator.target, new_target) > 0 or
        navigator.disable_spell ~= disable_spell
    then
        navigator.failed_target = nil
        navigator.target = new_target
        navigator.is_custom_target = true
        navigator.path = {}
        navigator.disable_spell = disable_spell
        navigator.pathfind_fail_count = 0  -- each new target starts fresh
    end
    explorer.backtracking = false
    return true
end
navigator.clear_target = function ()
    navigator.target = nil
    navigator.is_custom_target = false
    navigator.path = {}
    navigator.disable_spell = nil
end
navigator.move = function ()
    if navigator.move_time + navigator.move_timeout > get_time_since_inject() then return end
    navigator.move_time = get_time_since_inject()
    local local_player = get_local_player()
    if not local_player then return end
    local player_pos = local_player:get_position()
    local cur_node = utils.normalize_node(player_pos)
    -- Update nav state snapshot for perf report (cheap string, overwritten every allowed frame)
    if tracker.bench_enabled then
        tracker.bench_nav_state = string.format(
            "paused=%s  custom=%s  trav_routing=%s  last_trav=%s  pfail=%d  unstuck=%d  path_len=%d",
            tostring(navigator.paused),
            tostring(navigator.is_custom_target),
            tostring(navigator.trav_final_target ~= nil),
            tostring(navigator.last_trav ~= nil),
            navigator.pathfind_fail_count,
            navigator.unstuck_count,
            #navigator.path)
    end
    local traversals = get_nearby_travs(local_player)
    if #traversals > 0 then
        local trav = navigator.last_trav
        if trav ~= nil and utils.distance(player_pos, trav:get_position()) <= 3 and
            (navigator.trav_delay == nil or get_time_since_inject() > navigator.trav_delay)
        then
            interact_object(trav)
            local name = trav:get_skin_name()
            if name:match('Jump') then
                -- jump doesnt have traversal buff for some reason
                navigator.path = {}
                navigator.disable_spell = nil
                local crossed_str = trav:get_skin_name() .. utils.vec_to_string(trav:get_position())
                navigator.blacklisted_trav[crossed_str] = crossed_str
                console.print('[nav] blacklisting jumped traversal ' .. trav:get_skin_name())
                navigator.last_trav = nil
                navigator.trav_delay = get_time_since_inject() + 4
                navigator.failed_target = nil
                navigator.failed_target_radius = 15
                if navigator.trav_final_target ~= nil then
                    console.print('[nav] jump crossed, restoring custom target ' .. utils.vec_to_string(navigator.trav_final_target))
                    navigator.target = navigator.trav_final_target
                    navigator.is_custom_target = true
                    navigator.pathfind_fail_count = 0
                    navigator.trav_final_target = nil
                else
                    if not navigator.paused then
                        navigator.target = nil
                        navigator.is_custom_target = false
                    end
                end
            end
        end
        if has_traversal_buff(local_player) then
            tracker.bench_count("trav_crossed")
            navigator.trav_delay = get_time_since_inject() + 4
            navigator.path = {}
            navigator.disable_spell = nil
            if navigator.last_trav ~= nil then
                local crossed_str = navigator.last_trav:get_skin_name() .. utils.vec_to_string(navigator.last_trav:get_position())
                navigator.blacklisted_trav[crossed_str] = crossed_str
                console.print('[nav] blacklisting crossed traversal ' .. navigator.last_trav:get_skin_name())
            end
            navigator.last_trav = nil
            navigator.failed_target = nil
            navigator.failed_target_radius = 15
            if navigator.trav_final_target ~= nil then
                console.print('[nav] traversal crossed, restoring custom target ' .. utils.vec_to_string(navigator.trav_final_target))
                navigator.target = navigator.trav_final_target
                navigator.is_custom_target = true
                navigator.pathfind_fail_count = 0
                navigator.trav_final_target = nil
            else
                if not navigator.paused then
                    navigator.target = nil
                    navigator.is_custom_target = false
                end
            end
        end
    end

    -- movement spells
    if not utils.player_in_town() and #navigator.path > 0 then
        local movement_spell_id, need_raycast = get_movement_spell_id(local_player)
        if movement_spell_id ~= nil then
            local spell_node = nil
            local node_dist = -1
            local new_path = {}
            local selected = false
            for _, node in ipairs(navigator.path) do
                local dist = utils.distance(node, cur_node)
                local node_str = utils.vec_to_string(node)
                if selected or dist > navigator.spell_dist or node_dist > dist then
                    new_path[#new_path+1] = node
                    selected = true
                elseif navigator.blacklisted_spell_node[node_str] == nil and
                    -- move to nodes that is >= movement step 
                    utils.distance(node, cur_node) >= navigator.movement_step
                then
                    spell_node = node
                    node_dist = dist
                end
            end
            if spell_node ~= nil then
                local raycast_success = true
                if need_raycast then
                    local dist = utils.distance(cur_node, spell_node)
                    raycast_success = utility.is_ray_cast_walkeable(cur_node, spell_node, 0.5, dist)
                end
                if raycast_success then
                    local success = cast_spell.position(movement_spell_id, spell_node, 0)
                    if success then
                        utils.log(2, 'movement spell to ' .. utils.vec_to_string(spell_node))
                        if not navigator.paused then navigator.update() end
                        player_pos = local_player:get_position()
                        cur_node = utils.normalize_node(player_pos)
                        navigator.path = new_path
                        local node_str = utils.vec_to_string(spell_node)
                        navigator.blacklisted_spell_node[node_str] = spell_node
                    end
                end
            end
        end
    end

    local update_timeout = 1
    if utils.player_in_town() then update_timeout = 10 end
    if not has_traversal_buff(local_player) and
        navigator.last_trav == nil and
        (navigator.target == nil or utils.distance(cur_node, navigator.target) <= 1)
    then
        console.print('[nav] no target or reached, selecting new (prev=' .. (navigator.target and utils.vec_to_string(navigator.target) or 'nil') .. ')')
        navigator.blacklisted_spell_node = {}
        if navigator.paused then return end
        tracker.bench_start("select_target")
        navigator.target = select_target(nil)
        tracker.bench_stop("select_target")
        navigator.is_custom_target = false
        navigator.path = {}
        navigator.disable_spell = nil
        console.print('[nav] new target=' .. (navigator.target and utils.vec_to_string(navigator.target) or 'nil'))
    elseif navigator.target ~= nil and
        navigator.last_update ~= nil and
        navigator.last_update + update_timeout < get_time_since_inject() and
        not utils.is_cced(local_player)
    then
        local dist_to_target = utils.distance(cur_node, navigator.target)
        console.print('[nav] STUCK target=' .. utils.vec_to_string(navigator.target) .. ' dist=' .. string.format('%.1f', dist_to_target) .. ' path=#' .. #navigator.path .. ' unstuck_count=' .. navigator.unstuck_count)
        tracker.bench_start("unstuck")
        unstuck(local_player)
        tracker.bench_stop("unstuck")
        navigator.last_update = navigator.last_update + 0.25
    end
    if navigator.last_pos == nil or
        utils.distance(cur_node, navigator.last_pos) >= 0.5 or
        has_traversal_buff(local_player) or
        utils.is_cced(local_player)
    then
        navigator.last_pos = cur_node
        navigator.unstuck_nodes = {}
        navigator.unstuck_count = 0
        if navigator.last_update == nil or navigator.last_update < get_time_since_inject() then
            navigator.last_update = get_time_since_inject()
        end
    end

    if navigator.target == nil and
        navigator.last_trav == nil and
        not has_traversal_buff(local_player)
    then
        if navigator.done_delay ~= nil and navigator.done_delay < get_time_since_inject() then
            if explorer.frontier_count > 0 and #explorer.backtrack == 0 then
                console.print('[nav] not done but no more backtrack, reseting')
                navigator.reset()
                return
            elseif explorer.frontier_count == 0 and #explorer.backtrack > 0 then
                -- Still have backtracks — moving there may reveal new frontiers
                console.print('[nav] no frontiers but ' .. #explorer.backtrack .. ' backtracks, retrying')
                navigator.done_delay = nil
            elseif navigator.exploration_resets < 2 then
                -- Both frontiers and backtracks exhausted but dungeon may not be done
                -- Reset explorer visited set so re-scanning can find missed branches
                navigator.exploration_resets = navigator.exploration_resets + 1
                console.print('[nav] exploration stalled, resetting explorer (attempt ' .. navigator.exploration_resets .. '/2)')
                explorer.reset()
                navigator.target = nil
                navigator.is_custom_target = false
                navigator.path = {}
                navigator.done_delay = nil
            else
                navigator.done = true
                navigator.exploration_resets = 0
                console.print('[nav] finish exploration (frontiers=' .. explorer.frontier_count .. ' bt=#' .. #explorer.backtrack .. ')')
            end
        elseif navigator.done_delay == nil then
            navigator.done_delay = get_time_since_inject() + 1
        end
        return
    else
        navigator.done_delay = nil
    end

    if navigator.target ~= nil and (#navigator.path == 0 or
        utils.distance(navigator.path[1], navigator.last_pos) > navigator.movement_dist)
    then
        local dist_to_target = utils.distance(navigator.last_pos, navigator.target)
        console.print('[nav] pathfinding to=' .. utils.vec_to_string(navigator.target) .. ' dist=' .. string.format('%.1f', dist_to_target) .. ' custom=' .. tostring(navigator.is_custom_target))
        local result = path_finder.find_path(navigator.last_pos, navigator.target, navigator.is_custom_target)
        if #result == 0 then
            tracker.debug_node = navigator.target
            navigator.pathfind_fail_count = navigator.pathfind_fail_count + 1
            tracker.bench_count("pathfind_fail")
            console.print('[nav] PATHFIND FAILED #' .. navigator.pathfind_fail_count .. ' target=' .. utils.vec_to_string(navigator.target) .. ' dist=' .. string.format('%.1f', dist_to_target) .. ' paused=' .. tostring(navigator.paused) .. ' frontiers=' .. explorer.frontier_count)
            -- After N consecutive pathfind failures, handle unreachable target
            -- Custom targets (kill_monster): 3 failures (quick give-up, mark unreachable)
            -- Explorer targets: 6 failures (more patient — adjacent nodes fail individually)
            local fail_threshold = navigator.is_custom_target and 3 or 6
            -- After a traversal crossing, walkability data for the new area may not be
            -- loaded yet — be more patient before giving up on the custom target
            if navigator.trav_delay ~= nil and get_time_since_inject() < navigator.trav_delay then
                fail_threshold = 15
            end
            if navigator.pathfind_fail_count >= fail_threshold then
                navigator.pathfind_fail_count = 0
                -- If paused (external caller like kill_monster set target), just mark
                -- as unreachable and clear — do NOT blacklist explorer.visited since
                -- the explorer didn't pick this target and blacklisting corrupts its state
                if navigator.paused then
                    -- Check if a traversal is nearby — target is likely behind it.
                    -- Try routing via the traversal first before giving up.
                    local nearby_travs = get_nearby_travs(local_player)
                    local closest_trav = nil
                    local closest_trav_dist = math.huge
                    for _, trav in ipairs(nearby_travs) do
                        local d = utils.distance(player_pos, trav:get_position())
                        local trav_str = trav:get_skin_name() .. utils.vec_to_string(trav:get_position())
                        if d <= 30 and d < closest_trav_dist and navigator.blacklisted_trav[trav_str] == nil then
                            closest_trav = trav
                            closest_trav_dist = d
                        end
                    end
                    if closest_trav ~= nil then
                        -- Find a walkable approach node beside the traversal
                        local approach_node = get_closeby_node(closest_trav:get_position(), 2)
                        if approach_node ~= nil then
                            console.print('[nav] routing via traversal ' .. closest_trav:get_skin_name() .. ' to reach ' .. utils.vec_to_string(navigator.target))
                            tracker.bench_count("trav_route_attempt")
                            navigator.trav_final_target = navigator.target
                            navigator.last_trav = closest_trav
                            navigator.target = approach_node
                            navigator.is_custom_target = false
                            navigator.path = {}
                            navigator.pathfind_fail_count = 0
                            return  -- don't set failed_target — we will retry after crossing
                        end
                    end
                    -- No traversal route available — mark area as unreachable
                    local block_radius = closest_trav ~= nil and 50 or 15
                    console.print('[nav] clearing unreachable custom target ' .. utils.vec_to_string(navigator.target) .. ', cooldown=' .. navigator.failed_target_cooldown .. 's radius=' .. block_radius .. (closest_trav ~= nil and ' (no traversal route)' or ''))
                    navigator.failed_target = navigator.target
                    navigator.failed_target_time = get_time_since_inject()
                    navigator.failed_target_radius = block_radius
                    navigator.target = nil
                    navigator.is_custom_target = false
                    navigator.path = {}
                    navigator.disable_spell = nil
                    return
                end
                -- Only blacklist explorer area for explorer-picked targets
                console.print('[nav] BLACKLISTING 24x24 area around ' .. utils.vec_to_string(navigator.target))
                local failed_pos = navigator.target
                if failed_pos then
                    local step = settings.step or 2
                    for i = -12, 12, step do
                        for j = -12, 12, step do
                            local node_str = tostring(utils.normalize_value(failed_pos:x() + i)) .. ',' .. tostring(utils.normalize_value(failed_pos:y() + j))
                            explorer.visited[node_str] = node_str
                        end
                    end
                end
            end
            if navigator.paused then return end
            tracker.bench_start("select_target")
            navigator.target = select_target(navigator.target)
            tracker.bench_stop("select_target")
            console.print('[nav] new target after fail=' .. (navigator.target and utils.vec_to_string(navigator.target) or 'nil') .. (navigator.target and (' dist=' .. string.format('%.1f', utils.distance(cur_node, navigator.target))) or ''))
            navigator.is_custom_target = false
            navigator.path = {}
            navigator.disable_spell = nil
            return
        end
        console.print('[nav] pathfind OK, path=#' .. #result)
        tracker.debug_node = nil
        navigator.pathfind_fail_count = 0
        navigator.path = result
    end

    local moved = false
    local new_path = {}
    for _, node in ipairs(navigator.path) do
        if utils.distance(node, cur_node) >= 1 then
            if not moved and
                -- move to nodes that is >= movement step
                (utils.distance(node, cur_node) >= navigator.movement_step or
                -- or if it is close to target
                (navigator.target ~= nil and utils.distance(node, navigator.target) == 0))
            then
                pathfinder.request_move(node)
                moved = true
            end
            new_path[#new_path+1] = node
        else
            new_path = {}
        end
    end
    if not moved and #navigator.path > 0 then
        console.print('[nav] has path (#' .. #navigator.path .. ') but no move, remaining=#' .. #new_path .. ' target=' .. (navigator.target and utils.vec_to_string(navigator.target) or 'nil'))
    end
    navigator.path = new_path
end


return navigator