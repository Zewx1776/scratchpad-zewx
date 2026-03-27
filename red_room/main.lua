local plugin_label = 'red_room'

local task_manager = require 'core.task_manager'
local tracker      = require 'core.tracker'
local utils      = require 'core.utils'
local gui          = require 'gui'

local local_player, player_position

local function update_locals()
    local_player = get_local_player()
    player_position = local_player and local_player:get_position()
end

local function main_pulse()
    if utils.player_in_zone('[sno none]') then
        tracker.done = false
        tracker.done_time = nil
    end
    if not gui.elements.main_toggle:get() then return end
    if not local_player then return end
    if local_player:is_dead() then
        revive_at_checkpoint()
    else
        task_manager.execute_tasks()
    end
end

local function render_pulse()
    -- console.print(tostring(tracker.done))
    -- console.print(tostring(tracker.done_time))
    if not gui.elements.main_toggle:get() then return end
    if not local_player then return end
    if not utils.player_in_zone('S11_WorldBossArena_BossTierAzmodan') then return end
    local x_pos = get_screen_width()/2
    local y_pos = get_screen_height()/2
    local current_task = task_manager.get_current_task()
    if current_task then
        local px, py, pz = player_position:x(), player_position:y(), player_position:z()
        local draw_pos = vec3:new(px, py - 2, pz + 3)
        graphics.text_3d("Current Task: " .. current_task.name, draw_pos, 14, color_white(255))
    end
    if tracker.done and (tracker.done_time ~= nil and
        tracker.done_time + 2 < get_time_since_inject() and
        tracker.done_time + 6.5 > get_time_since_inject())
    then
        graphics.circle_filled_2d(vec2:new(x_pos, y_pos), 30, color_green(255))
    end
    if tracker.done and (tracker.done_time ~= nil and
        tracker.done_time + 6.5 < get_time_since_inject())
    then
        graphics.circle_filled_2d(vec2:new(x_pos, y_pos), 30, color_red(255))
    end
    if gui.elements.set_up:get() then
        graphics.circle_filled_2d(vec2:new(x_pos, y_pos), 30, color_green(255))
    end
    if gui.elements.set_up2:get() then
        graphics.circle_filled_2d(vec2:new(x_pos, y_pos), 30, color_red(255))
    end
end


on_update(function()
    update_locals()
    main_pulse()
end)

on_render_menu(function ()
    gui.render()
end)
on_render(render_pulse)
