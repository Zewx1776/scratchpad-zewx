local my_utility = require("my_utility/my_utility")
local menu_elements =
{
    main_boolean                   = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean")),
    -- first parameter is the default state, second one the menu element's ID. The ID must be unique,
    -- not only from within the plugin but also it needs to be unique between demo menu elements and
    -- other scripts menu elements. This is why we concatenate the plugin name ("LUA_EXAMPLE_NECROMANCER")
    -- with the menu element name itself.

    main_tree                      = tree_node:new(0),

    -- trees are the menu tabs. The parameter that we pass is the depth of the node. (0 for main menu (bright red rectangle),
    -- 1 for sub-menu of depth 1 (circular red rectangle with white background) and so on)
    weighted_targeting_tree        = tree_node:new(1),
    weighted_targeting_debug       = checkbox:new(false, get_hash(my_utility.plugin_label .. "weighted_targeting_debug")),
    weighted_targeting_enabled     = checkbox:new(true, get_hash(my_utility.plugin_label .. "weighted_targeting_enabled")),
    
    -- Scan settings
    max_targeting_range            = slider_int:new(1, 30, 12, get_hash(my_utility.plugin_label .. "max_targeting_range")),
    targeting_refresh_interval     = slider_float:new(0.1, 1, 0.2, get_hash(my_utility.plugin_label .. "targeting_refresh_interval")),
    min_targets                    = slider_int:new(1, 10, 3, get_hash(my_utility.plugin_label .. "min_targets")),
    comparison_radius              = slider_float:new(0.1, 6.0, 3.0, get_hash(my_utility.plugin_label .. "comparison_radius")),
    
    -- Cursor targeting
    cursor_targeting_radius        = slider_float:new(0.1, 6, 3, get_hash(my_utility.plugin_label .. "cursor_targeting_radius")),
    cursor_targeting_angle         = slider_int:new(20, 50, 30, get_hash(my_utility.plugin_label .. "cursor_targeting_angle")),
    
    -- Custom Enemy Sliders
    custom_enemy_sliders_enabled   = checkbox:new(false, get_hash(my_utility.plugin_label .. "custom_enemy_sliders_enabled")),
    normal_target_count            = slider_int:new(1, 10, 1, get_hash(my_utility.plugin_label .. "normal_target_count")),
    any_weight                     = slider_int:new(1, 100, 2, get_hash(my_utility.plugin_label .. "any_weight")),
    elite_target_count             = slider_int:new(1, 10, 5, get_hash(my_utility.plugin_label .. "elite_target_count")),
    elite_weight                   = slider_int:new(1, 100, 10, get_hash(my_utility.plugin_label .. "elite_weight")),
    champion_target_count          = slider_int:new(1, 10, 5, get_hash(my_utility.plugin_label .. "champion_target_count")),
    champion_weight                = slider_int:new(1, 100, 15, get_hash(my_utility.plugin_label .. "champion_weight")),
    boss_target_count              = slider_int:new(1, 10, 5, get_hash(my_utility.plugin_label .. "boss_target_count")),
    boss_weight                    = slider_int:new(1, 100, 50, get_hash(my_utility.plugin_label .. "boss_weight")),
    
    -- Custom Buff Weights
    custom_buff_weights_enabled    = checkbox:new(false, get_hash(my_utility.plugin_label .. "custom_buff_weights_enabled")),
    damage_resistance_provider_weight = slider_int:new(1, 100, 30, get_hash(my_utility.plugin_label .. "damage_resistance_provider_weight")),
    damage_resistance_receiver_penalty = slider_int:new(0, 20, 5, get_hash(my_utility.plugin_label .. "damage_resistance_receiver_penalty")),
    horde_objective_weight         = slider_int:new(1, 100, 50, get_hash(my_utility.plugin_label .. "horde_objective_weight")),
    vulnerable_debuff_weight       = slider_int:new(1, 5, 1, get_hash(my_utility.plugin_label .. "vulnerable_debuff_weight")),

    enable_debug                   = checkbox:new(false, get_hash(my_utility.plugin_label .. "enable_debug")),
    debug_tree                     = tree_node:new(2),
    draw_targets                   = checkbox:new(false, get_hash(my_utility.plugin_label .. "draw_targets")),
    draw_max_range                 = checkbox:new(false, get_hash(my_utility.plugin_label .. "draw_max_range")),
    draw_melee_range               = checkbox:new(false, get_hash(my_utility.plugin_label .. "draw_melee_range")),
    draw_enemy_circles             = checkbox:new(false, get_hash(my_utility.plugin_label .. "draw_enemy_circles")),
    draw_cursor_target             = checkbox:new(false, get_hash(my_utility.plugin_label .. "draw_cursor_target")),

    spells_tree                    = tree_node:new(1),
    disabled_spells_tree           = tree_node:new(1),
}

local draw_targets_description =
    "\n     Targets in sight:\n" ..
    "     Ranged Target - RED circle with line     \n" ..
    "     Melee Target - GREEN circle with line     \n" ..
    "     Closest Target - CYAN circle with line     \n\n" ..
    "     Targets out of sight (only if they are not the same as targets in sight):\n" ..
    "     Ranged Target - faded RED circle     \n" ..
    "     Melee Target - faded GREEN circle     \n" ..
    "     Closest Target - faded CYAN circle     \n\n" ..
    "     Best Target Evaluation Radius:\n" ..
    "     faded WHITE circle       \n\n"

local cursor_target_description =
    "\n     Best Cursor Target - ORANGE pentagon     \n" ..
    "     Closest Cursor Target - GREEN pentagon     \n\n"

return
{
    menu_elements = menu_elements,
    draw_targets_description = draw_targets_description,
    cursor_target_description = cursor_target_description
}
