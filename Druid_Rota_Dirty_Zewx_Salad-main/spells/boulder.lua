local my_utility = require("my_utility/my_utility")
local spell_data = require("my_utility/spell_data")

local boulder_menu_elements =
{
    tree_tab            = tree_node:new(1),
    main_boolean        = checkbox:new(false, get_hash(my_utility.plugin_label .. "boulder_main_bool_base")),
    targeting_mode      = combo_box:new(5, get_hash(my_utility.plugin_label .. "boulder_targeting_mode")),
}

local function menu()
    
    if boulder_menu_elements.tree_tab:push("Boulder")then
        boulder_menu_elements.main_boolean:render("Enable Spell", "")

        if boulder_menu_elements.main_boolean:get() then
            boulder_menu_elements.targeting_mode:render("Targeting Mode", my_utility.targeting_modes,
                my_utility.targeting_mode_description)
        end
 
        boulder_menu_elements.tree_tab:pop()
    end
end

local next_time_allowed_cast = 0.0;
local function logics(target)
    if not target then return false end;
    local menu_boolean = boulder_menu_elements.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_data.boulder.spell_id);

    if not is_logic_allowed then return false end;

    if cast_spell.target(target, spell_data.boulder.spell_id, 0, false) then
        local current_time = get_time_since_inject();
        next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast;

        console.print("Cast Boulder - Target: " ..
            my_utility.targeting_modes[boulder_menu_elements.targeting_mode:get() + 1]);
        return true;
    end;

    return false;
end

return 
{
    menu = menu,
    logics = logics,   
    menu_elements = boulder_menu_elements
}