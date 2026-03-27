local explorer = require 'core.explorer'
local navigator = require 'core.navigator'
local settings = require 'core.settings'
local utils = require 'core.utils'
local tracker = require 'core.tracker'

local get_max_length = function(messages)
    local max = 0
    for _, msg in ipairs(messages) do
        if #msg > max then max = #msg end
    end
    return max
end
local drawing = {}

drawing.draw_nodes = function (local_player)
    local start_draw = os.clock()
    local max_dist = 50

    local visited_count = explorer.visited_count
    local frontier_count = explorer.frontier_count
    local backtrack = explorer.backtrack
    local retry_count = explorer.retry_count

    local player_pos = local_player:get_position()
    local valid_z = player_pos:z()
    local cur_node = utils.normalize_node(player_pos)
    local path = navigator.path
    local counter = 0

    -- for node_str,_ in pairs(explorer.frontier) do
    --     local node = utils.string_to_vec(node_str)
    --     local valid = vec3:new(node:x(), node:y(), valid_z)
    --     graphics.circle_3d(valid, 0.05, color_blue(255))
    -- end
    -- local perimeter = explorer.get_perimeter(cur_node)
    -- for _, node in pairs(perimeter) do
    --     local valid = vec3:new(node:x(), node:y(), valid_z)
    --     -- valid = utility.set_height_of_valid_position(node)
    --     if utils.distance(cur_node, node) <= max_dist then
    --         graphics.circle_3d(valid, 0.05, color_blue(255))
    --     end
    -- end
    local prev_node = nil
    for index = #backtrack, 1, -1 do
        if counter < 30 then
            local node = backtrack[index]
            local valid = vec3:new(node:x(), node:y(), valid_z)
            graphics.circle_3d(valid, 0.05, color_yellow(255))
            if prev_node ~= nil then
                graphics.line(valid, prev_node, color_yellow(255), 1)
            else
                graphics.line(player_pos, valid, color_yellow(255), 1)
            end
            prev_node = valid
            counter = counter + 1
        else
            break
        end
    end
    prev_node = nil
    for _, node in pairs(path) do
        local valid = vec3:new(node:x(), node:y(), valid_z)
        if utils.distance(cur_node, node) <= max_dist then
            graphics.circle_3d(valid, 0.05, color_red(255))
            if prev_node ~= nil then
                graphics.line(valid, prev_node, color_red(255), 1)
            else
                graphics.line(player_pos, valid, color_red(255), 1)
            end
            prev_node = valid
        end
    end

    for node_str, result in pairs(tracker.evaluated) do
        local node = utils.string_to_vec(node_str)
        local valid_node = vec3:new(node:x(), node:y(), valid_z)
        if result ~= nil and result[1] then
            graphics.circle_3d(valid_node, 0.05, color_green(255))
        else
            graphics.circle_3d(valid_node, 0.05, color_blue(255))
        end
    end

    if tracker.debug_pos ~= nil then
        local valid = utility.set_height_of_valid_position(tracker.debug_pos)
        graphics.circle_3d(valid, 5, color_white(255))
        graphics.line(player_pos, valid, color_white(255), 1)
    end
    if tracker.debug_node ~= nil then
        local valid = vec3:new(tracker.debug_node:x(),tracker.debug_node:y(), valid_z)
        graphics.circle_3d(valid, 5, color_white(255))
        graphics.line(player_pos, valid, color_white(255), 1)
    end
    if tracker.debug_actor ~= nil then
        local valid = tracker.debug_actor:get_position()
        graphics.circle_3d(valid, 5, color_white(255))
        graphics.line(player_pos, valid, color_white(255), 1)
    end

    local in_combat =  utils.in_combat(local_player)
    local is_cced = utils.is_cced(local_player)
    local speed = local_player:get_current_speed()
    local speed_str = string.format("%.3f",local_player:get_current_speed())
    if speed < 10 then
        speed_str = speed_str .. '  '
    elseif speed < 100 then
        speed_str = speed_str .. ' '
    end
    local messages_left = {
        ' Speed     ' .. speed_str,
        ' Path      ' .. tostring(#path),
        ' Visited   ' .. tostring(visited_count),
        ' Frontier  ' .. tostring(frontier_count),
        ' Backtrack ' .. tostring(#backtrack),
        ' Retry     ' .. tostring(retry_count),
    }
    local messages_right = {
        ' Movespell ' .. tostring(settings.use_movement),
        ' In_combat ' .. tostring(in_combat),
        ' Is_cc\'ed  ' .. tostring(is_cced),
        ' U_time    ' .. string.format("%.3f",tracker.timer_update),
        ' M_time    ' .. string.format("%.3f",tracker.timer_move),
    }
    local max_left = get_max_length(messages_left)
    local max_right = get_max_length(messages_right)
    local x_pos = get_screen_width() - 20 - (max_left * 11) - (max_right * 11)
    local y_pos = get_screen_height() - 20 - (#messages_left * 20)
    for _, msg in ipairs(messages_left) do
        graphics.text_2d(msg, vec2:new(x_pos, y_pos), 20, color_white(255))
        y_pos = y_pos + 20
    end
    x_pos = get_screen_width() - 20 - (max_right * 11)
    y_pos = get_screen_height() - 40 - (#messages_right * 20)
    for _, msg in ipairs(messages_right) do
        graphics.text_2d(msg, vec2:new(x_pos, y_pos), 20, color_white(255))
        y_pos = y_pos + 20
    end
    tracker.timer_draw = os.clock() - start_draw
    local msg = ' D_time    ' .. string.format("%.3f",tracker.timer_draw)
    graphics.text_2d(msg, vec2:new(x_pos, y_pos), 20, color_white(255))
    -- collectgarbage("collect")
end

return drawing
