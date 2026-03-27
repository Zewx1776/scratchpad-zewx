local my_utility = require("my_utility/my_utility")

local menu_elements_paladin = {
    main_tree = tree_node:new(0),
    main_boolean = checkbox:new(false, get_hash(my_utility.plugin_label .. "main_boolean")),
    targeting_mode_dropdown = combo_box:new(0, get_hash(my_utility.plugin_label .. "targeting_mode_dropdown")),
    
    -- Build Profiles
    profiles_tree = tree_node:new(0),
    hammerdin_checkbox = checkbox:new(false, get_hash(my_utility.plugin_label .. "hammerdin_checkbox")),
    hammerdin_save_btn = checkbox:new(false, get_hash(my_utility.plugin_label .. "hammerdin_save_btn")),
    hammerdin_load_btn = checkbox:new(false, get_hash(my_utility.plugin_label .. "hammerdin_load_btn")),
    
    spear_checkbox = checkbox:new(false, get_hash(my_utility.plugin_label .. "spear_checkbox")),
    spear_save_btn = checkbox:new(false, get_hash(my_utility.plugin_label .. "spear_save_btn")),
    spear_load_btn = checkbox:new(false, get_hash(my_utility.plugin_label .. "spear_load_btn")),
    
    judgment_checkbox = checkbox:new(false, get_hash(my_utility.plugin_label .. "judgment_checkbox")),
    judgment_save_btn = checkbox:new(false, get_hash(my_utility.plugin_label .. "judgment_save_btn")),
    judgment_load_btn = checkbox:new(false, get_hash(my_utility.plugin_label .. "judgment_load_btn")),

    -- Import Build control (visible checkbox-style entry)
    -- Main.lua expects menu.import_checkbox to exist; this creates it in the same style.
    import_checkbox = checkbox:new(false, get_hash(my_utility.plugin_label .. "import_checkbox")),
}

return menu_elements_paladin