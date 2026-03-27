local gui = require "gui"
local settings = {
    enabled = false,
    is_stuck = false,
    first_item_dropped = false,
    can_exit = false,
    altar_activated = false,
    solved_runs = 0,
    found_ubers = {},
    ga_threshold = 1,
    uber_ga_threshold = 1,
    use_alfred = true,
    enable_ground_items_teleport = true
}

function settings:update_settings()
    settings.enabled = gui.elements.main_toggle:get()
    settings.loot_modes = gui.elements.loot_modes:get()
    settings.ga_threshold = gui.elements.ga_slider:get()
    settings.uber_ga_threshold = gui.elements.uber_ga_slider:get()
    settings.enable_ground_items_teleport = gui.elements.enable_ground_items_teleport:get()
end

return settings