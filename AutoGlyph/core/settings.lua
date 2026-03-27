local gui = require "autoglyph_gui"

local settings = {
    enabled = false,
    upgrade_threshold = 50,
    minimum_glyph_level = 1,
    maximum_glyph_level = 100,
}

function settings:update_settings()
    settings.enabled = gui.elements.main_toggle:get()
    settings.upgrade_threshold = gui.elements.upgrade_threshold:get()
    settings.minimum_glyph_level = gui.elements.minimum_glyph_level:get()
    settings.maximum_glyph_level = gui.elements.maximum_glyph_level:get()
end

return settings
