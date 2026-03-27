local plugin_label = 'azmodan_farm'

local gui          = require 'gui'
local settings     = require 'core.settings'
local task_manager = require 'core.task_manager'
local tracker      = require 'core.tracker'

local local_player, player_position
local debounce_time = nil
local debounce_timeout = 1

local function update_locals()
    local_player = get_local_player()
    player_position = local_player and local_player:get_position()
end

local function main_pulse()
    if not local_player then return end
    if gui.elements.drop_sigil_keybind:get_state() == 1 then
        if debounce_time ~= nil and debounce_time + debounce_timeout > get_time_since_inject() then return end
        gui.elements.drop_sigil_keybind:set(false)
        tracker.drop_sigils = true
        task_manager.execute_tasks()
    end
    if gui.elements.drop_item_keybind:get_state() == 1 then
        if debounce_time ~= nil and debounce_time + debounce_timeout > get_time_since_inject() then return end
        gui.elements.drop_item_keybind:set(false)
        tracker.drop_items = true
        task_manager.execute_tasks()
    end

    settings:update_settings()
    if (not settings.enabled or not settings.get_keybind_state()) then return end

    if local_player:is_dead() then
        revive_at_checkpoint()
    else
        task_manager.execute_tasks()
    end
end

local function render_pulse()
    if not (settings.get_keybind_state()) then return end
    if not local_player or not settings.enabled then return end
    local current_task = task_manager.get_current_task()
    if current_task then
        local px, py, pz = player_position:x(), player_position:y(), player_position:z()
        local draw_pos = vec3:new(px, py - 2, pz + 3)
        graphics.text_3d("Current Task: " .. current_task.name, draw_pos, 14, color_white(255))
    end
    if settings.track_kill then
        local counter = #tracker.azmodan_timer
        if counter == 0 then counter = 1 end
        local x_pos = get_screen_width() - 20 - (33 * 11)
        local y_pos = get_screen_height() - 160 - (counter * 20)
        if #tracker.azmodan_timer == 0 then
            local msg = 'Azmodan kill time : no kills yet'
            graphics.text_2d(msg, vec2:new(x_pos, y_pos), 20, color_white(255))
        end

        for _, timer in ipairs(tracker.azmodan_timer) do
            local msg = 'Azmodan kill time : ' .. timer
            graphics.text_2d(msg, vec2:new(x_pos, y_pos), 20, color_white(255))
            y_pos = y_pos + 20
        end
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
