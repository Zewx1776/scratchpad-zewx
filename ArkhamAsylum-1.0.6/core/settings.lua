local gui = require 'gui'

local settings = {
    plugin_label = gui.plugin_label,
    plugin_version = gui.plugin_version,
    enabled = false,
    pit_level = 1,
    reset_timeout = 600,
    exit_mode = 0,
    exit_pit_delay = 10,
    return_for_loot = false,
    upgrade_toggle = false,
    upgrade_mode = 1,
    upgrade_threshold = 1,
    upgrade_legendary_toggle = true,
    minimum_glyph_level = 1,
    maximum_glyph_level = 100,
    interact_shrine = true,
    party_enabled = false,
    party_mode = 0,
    confirm_delay = 5,
    use_magoogle_tool = false,
    check_distance = 12,
    follower_explore = false,
    batmobile_priority = 'distance',
}

settings.get_keybind_state = function ()
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

settings.update_settings = function ()
    settings.enabled = gui.elements.main_toggle:get()
    settings.return_for_loot = gui.elements.return_for_loot:get()
    settings.pit_level = gui.elements.pit_level:get()
    settings.reset_timeout = gui.elements.reset_timeout:get()
    settings.exit_mode = gui.elements.exit_mode:get()
    settings.exit_pit_delay = gui.elements.exit_pit_delay:get()
    settings.upgrade_toggle = gui.elements.upgrade_toggle:get()
    settings.upgrade_mode = gui.elements.upgrade_mode:get()
    settings.upgrade_threshold = gui.elements.upgrade_threshold:get()
    settings.upgrade_legendary_toggle = gui.elements.upgrade_legendary_toggle:get()
    settings.minimum_glyph_level = gui.elements.minimum_glyph_level:get()
    settings.maximum_glyph_level = gui.elements.maximum_glyph_level:get()
    settings.interact_shrine = gui.elements.interact_shrine:get()
    settings.party_enabled = gui.elements.party_enabled:get()
    settings.party_mode = gui.elements.party_mode:get()
    settings.confirm_delay = gui.elements.confirm_delay:get()
    settings.use_magoogle_tool = gui.elements.use_magoogle_tool:get()
    settings.follower_explore = gui.elements.follower_explore:get()
    settings.batmobile_priority = gui.batmobile_priority[gui.elements.batmobile_priority:get()+1]
    
end

return settings