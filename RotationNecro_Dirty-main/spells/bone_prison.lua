local my_utility = require("my_utility/my_utility")

local menu_elements_bone_prison_base = {
    tree_tab_bone_prison = tree_node:new(1),
    main_boolean = checkbox:new(true, get_hash(my_utility.plugin_label .. "bone_prison_boolean_base")),
    min_enemies = slider_int:new(0, 30, 3, get_hash(my_utility.plugin_label .. "bone_prison_min_enemies_base")),
}

local function menu()
    if menu_elements_bone_prison_base.tree_tab_bone_prison:push("Bone Prison") then
        menu_elements_bone_prison_base.main_boolean:render("Enable Spell", "")
        if menu_elements_bone_prison_base.main_boolean:get() then
            menu_elements_bone_prison_base.min_enemies:render("Min Enemies Around", "Minimum enemies to cast the spell")
        end
        menu_elements_bone_prison_base.tree_tab_bone_prison:pop()
    end
end

local spell_id_bone_prison = 493453
local next_time_allowed_cast = 0.0
local bone_prison_spell_data = spell_data:new(
    2.0,                        -- radius
    7.0,                        -- range
    1.0,                        -- cast_delay
    1.0,                        -- projectile_speed
    true,                       -- has_collision
    spell_id_bone_prison,       -- spell_id
    spell_geometry.circular,    -- geometry_type
    targeting_type.skillshot    -- targeting_type
)

local function find_best_bone_prison_target()
    local player_position = get_player_position()
    local area_data = target_selector.get_most_hits_target_circular_area_light(player_position, 7.0, 2.0, false)
    local main_target = area_data.main_target
    local n_hits = area_data.n_hits
    if main_target and n_hits >= menu_elements_bone_prison_base.min_enemies:get() then
        return { is_valid = true, target = main_target, hits = n_hits }
    end
    return { is_valid = false, target = nil, hits = 0 }
end

local function logics()
    local menu_boolean = menu_elements_bone_prison_base.main_boolean:get()
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean,
        next_time_allowed_cast,
        spell_id_bone_prison
    )
    if not is_logic_allowed then
        return false
    end

    local best_target_data = find_best_bone_prison_target()
    if not best_target_data.is_valid then
        return false
    end

    if cast_spell.target(best_target_data.target, spell_id_bone_prison, 2.0, false) then
        local current_time = get_time_since_inject()
        next_time_allowed_cast = current_time + 0.7
        console.print("[Necromancer] [SpellCast] [Bone Prison] Hits ", best_target_data.hits)
        return true
    end
    return false
end

return {
    menu = menu,
    logics = logics,
    menu_elements = menu_elements_bone_prison_base,
}