local plugin_label = "CAMINHADOR_PLUGIN_"

local menu_elements = 
{
    main_tree = tree_node:new(0),
    plugin_enabled = checkbox:new(false, get_hash(plugin_label .. "plugin_enabled")),
    main_openDoors_enabled = checkbox:new(false, get_hash(plugin_label .. "main_openDoors_enabled")),
    loop_enabled = checkbox:new(false, get_hash(plugin_label .. "loop_enabled")),
    revive_enabled = checkbox:new(false, get_hash(plugin_label .. "revive_enabled")),
        
    -- Subsection Move Threshold
    move_threshold_tree = tree_node:new(2),
    move_threshold_slider = slider_int:new(12, 20, 12, get_hash(plugin_label .. "move_threshold_slider")),

    -- Subsection Vendor Manager
    vendor_manager_tree = tree_node:new(3),
    vendor_enabled = checkbox:new(false, get_hash("VENDOR_MANAGER_enabled")),
    auto_repair = checkbox:new(false, get_hash("VENDOR_MANAGER_repair")),
    auto_sell = checkbox:new(false, get_hash("VENDOR_MANAGER_sell")),
    auto_salvage = checkbox:new(false, get_hash("VENDOR_MANAGER_salvage")),
    auto_stash = checkbox:new(false, get_hash("VENDOR_MANAGER_stash")),
    auto_stash_boss_materials = checkbox:new(false, get_hash("VENDOR_MANAGER_stash_boss")),
    enable_during_helltide = checkbox:new(false, get_hash("VENDOR_MANAGER_during_helltide")),
    --enable_end_helltide = checkbox:new(false, get_hash("VENDOR_MANAGER_end_helltide")),
    --auto_move = checkbox:new(false, get_hash("VENDOR_MANAGER_move")),
    items_threshold = slider_int:new(1, 33, 33, get_hash(plugin_label .. "items_threshold_slider")),
    greater_affix_threshold = slider_int:new(0, 4, 1, get_hash("VENDOR_MANAGER_greater_affix")),
    actions_tree = tree_node:new(4),
    settings_tree = tree_node:new(5),
}

function render_menu()
    menu_elements.main_tree:push("Helltide Farmer (EletroLuz)-V3.0")

    -- Render movement plugin
    menu_elements.plugin_enabled:render("Enable Plugin Chests Farm", "Enable or disable the chest farm plugin")

    -- Render o checkbox enable open chests
    menu_elements.main_openDoors_enabled:render("Open Chests", "Enable or disable the chest plugin")

    -- Render checkbox loop
    menu_elements.loop_enabled:render("Enable Loop", "Enable or disable looping waypoints")

    -- Render revive
    menu_elements.revive_enabled:render("Enable Revive Module", "Enable or disable the revive module")

    -- Subsection Move Threshold
    if menu_elements.move_threshold_tree:push("Chest Move Range Settings") then
        menu_elements.move_threshold_slider:render("Move Threshold", "Set Chest Max Move distance")
        menu_elements.move_threshold_tree:pop()
    end

    -- Subsection Vendor Manager
    if menu_elements.vendor_manager_tree:push("Vendor Manager") then
        menu_elements.vendor_enabled:render("Enable Vendor Manager", "Enable or disable the vendor manager")
        menu_elements.enable_during_helltide:render("Enable During Helltide", "Automatically manage vendors while Helltide is active")
        --menu_elements.enable_end_helltide:render("Enable End Helltide", "Automatically manage vendors when Helltide ends")
        
        if menu_elements.actions_tree:push("Automatic Actions") then
            menu_elements.auto_repair:render("Auto Repair", "Automatically repair items when visiting vendor")
            menu_elements.auto_sell:render("Auto Sell", "Automatically sell items when visiting vendor")
            menu_elements.auto_salvage:render("Auto Salvage", "Automatically salvage items at blacksmith")
            menu_elements.auto_stash:render("Auto Stash", "Automatically stash items with Greater Affixes >= threshold")
            menu_elements.auto_stash_boss_materials:render("Auto Stash Boss Materials", "Automatically stash boss materials when stack reaches 50")
            menu_elements.actions_tree:pop()
        end
        
        if menu_elements.settings_tree:push("Settings") then
            --menu_elements.auto_move:render("Auto Move to Vendor", "Automatically move to nearest vendor")
            menu_elements.items_threshold:render("Items Threshold (1-33)", "Number of items before selling/salvaging")
            menu_elements.greater_affix_threshold:render("Greater Affix Threshold (0-4)", "0=Sell all, 1+=Keep items with X or more Greater Affixes")
            menu_elements.settings_tree:pop()
        end
        
        menu_elements.vendor_manager_tree:pop()
    end

    menu_elements.main_tree:pop()
end

return menu_elements