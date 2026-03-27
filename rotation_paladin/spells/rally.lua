local my_utility = require("my_utility/my_utility")

local menu_elements = {
    tree_tab = tree_node:new(1),
    main_boolean = checkbox:new(false, get_hash(my_utility.plugin_label .. "rally_main_bool")),
    cooldown = slider_float:new(0.0, 5.0, 0.5, get_hash(my_utility.plugin_label .. "rally_cooldown")),
}

local function menu()
    if menu_elements.tree_tab:push("Rally") then
        menu_elements.main_boolean:render("Enable Spell", "Movement buff")
        
        if menu_elements.main_boolean:get() then
            menu_elements.cooldown:render("Cooldown", "Time between casts in seconds", 2)
        end
        
        menu_elements.tree_tab:pop()
    end
    return menu_elements
end

local spell_id = 2303677
local next_time_allowed_cast = 0.0

local function logics(target)
    local menu_boolean = menu_elements.main_boolean:get()
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean,
        next_time_allowed_cast,
        spell_id
    )

    if not is_logic_allowed then
        return false
    end

    if cast_spell.self(spell_id, 0.5) then
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
