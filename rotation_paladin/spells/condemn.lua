local my_utility = require("my_utility/my_utility")

local menu_elements = {
    tree_tab = tree_node:new(1),
    main_boolean = checkbox:new(false, get_hash(my_utility.plugin_label .. "condemn_main_bool")),
    cast_on_boss = checkbox:new(true, get_hash(my_utility.plugin_label .. "condemn_cast_on_boss")),
    cast_on_elite = checkbox:new(true, get_hash(my_utility.plugin_label .. "condemn_cast_on_elite")),
    cast_on_champion = checkbox:new(true, get_hash(my_utility.plugin_label .. "condemn_cast_on_champion")),
    min_range = slider_float:new(0.0, 25.0, 12.0, get_hash(my_utility.plugin_label .. "condemn_min_range")),
    aoe_range = slider_float:new(0.0, 25.0, 10.0, get_hash(my_utility.plugin_label .. "condemn_aoe_range")),
    min_enemies_aoe = slider_int:new(0, 10, 1, get_hash(my_utility.plugin_label .. "condemn_min_enemies")),
    cooldown = slider_float:new(0.0, 2.0, 0.5, get_hash(my_utility.plugin_label .. "condemn_cooldown")),
}

local function menu()
    if menu_elements.tree_tab:push("Condemn") then
        menu_elements.main_boolean:render("Enable Spell", "Pull and damage enemies")
        
        if menu_elements.main_boolean:get() then
            menu_elements.cast_on_boss:render("Boss", "Cast on bosses")
            menu_elements.cast_on_elite:render("Elite", "Cast on elites")
            menu_elements.cast_on_champion:render("Champion", "Cast on champions")
            menu_elements.min_range:render("Max Range", "Maximum range to cast spell", 1)
            menu_elements.aoe_range:render("AOE Range", "Enemy scan range around target", 1)
            menu_elements.min_enemies_aoe:render("Min Enemies for AOE", "Minimum number of enemies nearby to cast")
            menu_elements.cooldown:render("Cooldown", "Time between casts in seconds", 2)
        end
        
        menu_elements.tree_tab:pop()
    end
    return menu_elements
end

local spell_id = 2226109
local next_time_allowed_cast = 0.0

local spell_data_condemn = spell_data:new(
    4.0,                        -- radius
    12.0,                       -- range
    0.4,                       -- cast_delay
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

    local should_cast = false

    if menu_elements.cast_on_boss:get() and target.is_boss and target:is_boss() then
        should_cast = true
    end

    if (not should_cast) and menu_elements.cast_on_elite:get() and target.is_elite and target:is_elite() then
        should_cast = true
    end

    if (not should_cast) and menu_elements.cast_on_champion:get() and target.is_champion and target:is_champion() then
        should_cast = true
    end

    if not should_cast then
        local min_enemies = menu_elements.min_enemies_aoe:get()
        if min_enemies and min_enemies > 0 then
            local range = menu_elements.aoe_range:get()
            local enemy_count = my_utility.get_nearby_enemy_count(target_position, range)
            if enemy_count >= min_enemies then
                should_cast = true
            end
        end
    end

    if not should_cast then
        return false
    end

    if cast_spell.target(target, spell_data_condemn, false) then
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
    menu_elements = menu_elements,
}
