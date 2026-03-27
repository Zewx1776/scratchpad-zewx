local my_utility = require("my_utility/my_utility")

local menu_elements = {
    tree_tab = tree_node:new(1),
    main_boolean = checkbox:new(false, get_hash(my_utility.plugin_label .. "zeal_main_bool")),
    min_range = slider_float:new(0.0, 25.0, 8.0, get_hash(my_utility.plugin_label .. "zeal_min_range")),
    min_enemies_aoe = slider_int:new(0, 10, 1, get_hash(my_utility.plugin_label .. "zeal_min_enemies")),
    cooldown = slider_float:new(0.0, 2.0, 0.3, get_hash(my_utility.plugin_label .. "zeal_cooldown")),
}

local function menu()
    if menu_elements.tree_tab:push("Zeal") then
        menu_elements.main_boolean:render("Enable Spell", "Multi-hit attack")
        
        if menu_elements.main_boolean:get() then
            menu_elements.min_range:render("Max Range", "Maximum range to cast spell", 1)
            menu_elements.min_enemies_aoe:render("Min Enemies for AOE", "Minimum number of enemies nearby to cast")
            menu_elements.cooldown:render("Cooldown", "Time between casts in seconds", 2)
        end
        
        menu_elements.tree_tab:pop()
    end
    return menu_elements
end

local spell_id = 2132824
local next_time_allowed_cast = 0.0

local spell_data_zeal = spell_data:new(
    1.0,                        -- radius
    3.0,                       -- range
    0.25,                       -- cast_delay
    5.0,                        -- projectile_speed
    false,                      -- has_collision
    spell_id,                   -- spell_id
    spell_geometry.rectangular, -- geometry_type
    targeting_type.targeted     -- targeting_type
)

local function logics(target)
    if not target then return false end
    
    local menu_boolean = menu_elements.main_boolean:get()
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean,
        next_time_allowed_cast,
        spell_id
    )

    if not is_logic_allowed then
        return false
    end

    local target_position = target:get_position()
    if not target_position then return false end
    
    local player_position = get_player_position()
    if not player_position then return false end
    
    local distance_sqr = player_position:squared_dist_to_ignore_z(target_position)
    local max_range = menu_elements.min_range:get()
    if distance_sqr > (max_range * max_range) then
        return false
    end


    -- Check minimum enemies for AOE
    local min_enemies = menu_elements.min_enemies_aoe:get()
    if min_enemies > 0 then
        local enemy_count = my_utility.get_nearby_enemy_count(target_position, max_range)
        if enemy_count < min_enemies then
            return false
        end
    end

    if cast_spell.target(target, spell_data_zeal, false) then
        local current_time = get_time_since_inject()
        local cooldown = menu_elements.cooldown:get()
        next_time_allowed_cast = current_time + cooldown
        return true
    end
    
    return false
end


local function get_enabled()
    return menu_elements.main_boolean:get()
end

return {
    menu = menu,
    logics = logics,
    get_enabled = get_enabled,
}
