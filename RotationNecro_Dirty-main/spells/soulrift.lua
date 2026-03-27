local my_utility = require("my_utility/my_utility");

local my_utility = require("my_utility/my_utility")

local menu_elements_soulrift_base = {
    tree_tab = tree_node:new(1),
    main_boolean = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_soulrift_base")),
    min_enemies = slider_int:new(0, 30, 3, get_hash(my_utility.plugin_label .. "soulrift_base_min_enemies")),
}

local function menu()
    if menu_elements_soulrift_base.tree_tab:push("Soulrift") then
        menu_elements_soulrift_base.main_boolean:render("Enable Spell", "")
        if menu_elements_soulrift_base.main_boolean:get() then
            menu_elements_soulrift_base.min_enemies:render("Min Enemies Around", "Minimum enemies to cast the spell")
        end
        menu_elements_soulrift_base.tree_tab:pop()
    end
end

local soulrift_spell_id = 1644584 -- TODO: Replace with actual Soulrift spell ID
local next_time_allowed_cast = 0.0

local function logics()
    local menu_boolean = menu_elements_soulrift_base.main_boolean:get()
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean,
        next_time_allowed_cast,
        soulrift_spell_id
    )
    if not is_logic_allowed then
        return false
    end

    local player_pos = get_player_position()
    local area_data = target_selector.get_most_hits_target_circular_area_light(player_pos, 3.0, 3.0, false)
    local units = area_data.n_hits

    if units < menu_elements_soulrift_base.min_enemies:get() then
        return false
    end

    cast_spell.self(soulrift_spell_id, 0.4)
    local current_time = get_time_since_inject()
    next_time_allowed_cast = current_time + 0.7
    console.print("[Necromancer] [SpellCast] [Soulrift] Hits ", units)
    return true
end

return {
    menu = menu,
    logics = logics,
    menu_elements = menu_elements_soulrift_base,
}