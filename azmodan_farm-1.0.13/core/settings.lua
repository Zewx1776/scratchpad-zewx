local gui = require 'gui'

local settings = {
    plugin_label = gui.plugin_label,
    plugin_version = gui.plugin_version,
    enabled = false,
    path_angle = 10,
    use_evade = false,
    aggresive_movement = false,
    open_chest = false,
    priority = 'Belial',
    track_kill = false,
    use_alfred = true
}

function settings.get_keybind_state()
    local toggle_key = gui.elements.keybind_toggle:get_key();
    local toggle_state = gui.elements.keybind_toggle:get_state();
    local use_keybind = gui.elements.use_keybind:get()
    -- If not using keybind, skip
    if not use_keybind then
        return true
    end

    if use_keybind and toggle_key ~= 0x0A and toggle_state == 1 then
        return true
    end
    return false
end


function settings:update_settings()
    settings.enabled = gui.elements.main_toggle:get()
    settings.open_chest = gui.elements.chest_toggle:get()
    settings.priority = gui.priority_options[gui.elements.priority:get()+1]
    settings.track_kill = gui.elements.kill_tracker_toggle:get()
    settings.use_alfred = gui.elements.use_alfred:get()
end

return settings