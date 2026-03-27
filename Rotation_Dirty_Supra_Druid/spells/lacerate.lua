local my_utility = require("my_utility/my_utility")
local spell_data = require("my_utility/spell_data")

local menu_elements = 
{
    main_tab           = tree_node:new(1),
    main_boolean       = checkbox:new(true, get_hash(my_utility.plugin_label .. "lacerate_disable_enable_ability")),
    targeting_mode     = combo_box:new(3, get_hash(my_utility.plugin_label .. "lacerate_base_targeting_mode")),
    cast_range         = slider_int:new(1, 35, 15, get_hash(my_utility.plugin_label .. "lacerate_cast_range")),
}

local function menu()                                                                                    
    if menu_elements.main_tab:push("Lacerate")then
        menu_elements.main_boolean:render("Enable Spell", "")

        if menu_elements.main_boolean:get() then
            menu_elements.targeting_mode:render("Targeting Mode", my_utility.targeting_modes,
                my_utility.targeting_mode_description)
            menu_elements.cast_range:render("Cast Range", "Range in yards to cast Lacerate")
        end
 
        menu_elements.main_tab:pop()
    end
end

local next_time_allowed_cast = 1.1;
local next_time_allowed_move = 0.0;
local move_delay = 0.5; 

local local_player = get_local_player();
if local_player == nil then
    return
end

local function logics(target)
    if not target then return false end;
    local menu_boolean = menu_elements.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_data.lacerate.spell_id);

    if not is_logic_allowed then
        return false;
    end;

    -- Checking for target distance using custom range
    local cast_range = menu_elements.cast_range:get()
    local in_range = my_utility.is_in_range(target, cast_range)
    if not in_range then
        -- Check if we can move again
        local current_time = get_time_since_inject();
        if current_time >= next_time_allowed_move then
            -- move to target
            local target_position = target:get_position()
            pathfinder.force_move_raw(target_position)
            next_time_allowed_move = current_time + move_delay;
        end
        return false;
    end

    if cast_spell.target(target, spell_data.lacerate.spell_id, 0, false) then
        local current_time = get_time_since_inject();
        next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast;

        console.print("Cast Lacerate - Target: " ..
            my_utility.targeting_modes[menu_elements.targeting_mode:get() + 1] .. 
            " - Range: " .. cast_range);
        return true;
    end;
            
    return false;
end

return 
{
    menu = menu,
    logics = logics,   
    menu_elements = menu_elements
}
