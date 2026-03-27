local gui = {}
local plugin_label = "Bosser"

local function create_checkbox(value, key)
    return checkbox:new(value, get_hash(plugin_label .. '_' .. key))
end

gui.loot_modes_options = {
    "Nothing",  -- will get stuck
    "Sell",     -- will sell all and keep going
    "Salvage",  -- will salvage all and keep going
    "Stash",    -- nothing for now, will get stuck, but in future can be added
}

gui.loot_modes_enum = {
    NOTHING = 0,
    SELL = 1,
    SALVAGE = 2,
    STASH = 3,
}

gui.elements = {
    main_tree = tree_node:new(0),
    main_toggle = create_checkbox(false,"main_toggle"),
    settings_tree = tree_node:new(1),
    loot_modes = combo_box:new(0, get_hash("bosser_loot_modes")),
    ga_slider = slider_int:new(1, 4, 1, get_hash(plugin_label .. "_ga_slider")),
    uber_ga_slider = slider_int:new(1, 4, 1, get_hash(plugin_label .. "_uber_ga_slider")),
    use_alfred = create_checkbox(false, "use_alfred"),
    enable_ground_items_teleport = create_checkbox(true, "enable_ground_items_teleport")
}

function gui.render()
    if not gui.elements.main_tree:push(plugin_label) then return end

    gui.elements.main_toggle:render("Enable", "Enable the bot")

    if gui.elements.settings_tree:push("Settings") then
        gui.elements.loot_modes:render("Loot Modes", gui.loot_modes_options, "Nothing and Stash will get you stuck for now")
        gui.elements.ga_slider:render("Min Unique GA Counter", "Select minimum Greater Affix to keep?")
        gui.elements.uber_ga_slider:render("Min Uber GA Counter", "Select minimum Greater Affix to keep")
        gui.elements.enable_ground_items_teleport:render("Enable Ground Items Teleport", "Enable teleporting to town when too many items are on ground")
        
        if PLUGIN_alfred_the_butler then
            local alfred_status = PLUGIN_alfred_the_butler.get_status()
            if alfred_status.enabled then
                gui.elements.use_alfred:render("Use alfred", "use alfred to manage town tasks")
            end
        end
        
        gui.elements.settings_tree:pop()
    end

    gui.elements.main_tree:pop()
end

return gui
