local my_utility = require("my_utility/my_utility")

local menu_elements = {
    tree_tab = tree_node:new(1),
    main_boolean = checkbox:new(false, get_hash(my_utility.plugin_label .. "basic_strike_main_bool")),
}

local function menu()
    if menu_elements.tree_tab:push("basic_strike") then
        menu_elements.main_boolean:render("Enable Spell", "")
        menu_elements.tree_tab:pop()
    end
    return menu_elements
end

local spell_id = 0  -- TODO: Spell ID not yet provided
local next_time_allowed_cast = 0.0

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

    -- Spell casting logic placeholder
    -- Would implement actual spell casting here
    
    return false
end

return {
    menu = menu,
    logics = logics,
}
