local gui = require "autoglyph_gui"

local settings = {
    enabled = false,
    profile_enabled = false,
    upgrade_threshold = 50,
    minimum_glyph_level = 1,
    maximum_glyph_level = 100,
    status_text = "Idle",
    debug_enabled = false,
}

function settings:update_settings()
    settings.enabled = gui.elements.main_toggle:get()
    settings.profile_enabled = gui.elements.profile_enabled:get()
    settings.upgrade_threshold = gui.elements.upgrade_threshold:get()
    settings.minimum_glyph_level = gui.elements.minimum_glyph_level:get()
    settings.maximum_glyph_level = gui.elements.maximum_glyph_level:get()
    settings.debug_enabled = gui.elements.debug_enabled and gui.elements.debug_enabled:get() or false
end

return settings
