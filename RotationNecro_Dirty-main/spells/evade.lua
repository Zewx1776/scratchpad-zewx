local my_utility = require("my_utility/my_utility")
local spell_data = require("my_utility/spell_data")

local max_spell_range = 17.0
local menu_elements =
{
    tree_tab               = tree_node:new(1),
    main_boolean           = checkbox:new(true, get_hash(my_utility.plugin_label .. "evade_main_bool_base")),
    use_out_of_combat      = checkbox:new(true, get_hash(my_utility.plugin_label .. "evade_use_out_of_combat")),
    targeting_mode         = combo_box:new(1, get_hash(my_utility.plugin_label .. "evade_targeting_mode")),
    mobility_only          = checkbox:new(true, get_hash(my_utility.plugin_label .. "evade_mobility_only")),
    no_blood_wave_cooldown = checkbox:new(true, get_hash(my_utility.plugin_label .. "no_blood_wave_cooldown")),
}

local function menu()
    if menu_elements.tree_tab:push("Evade") then
        menu_elements.main_boolean:render("Enable Evade - In combat", "")
        if menu_elements.main_boolean:get() then
            menu_elements.targeting_mode:render("Targeting Mode", my_utility.targeting_modes,
                my_utility.targeting_mode_description)
            menu_elements.mobility_only:render("Only use for mobility", "")
            menu_elements.no_blood_wave_cooldown:render(
                "Only evade when blood wave is not on cooldown", "")
        end

        menu_elements.use_out_of_combat:render("Enable Evade - Out of combat", "")

        menu_elements.tree_tab:pop()
    end
end

local next_time_allowed_cast = 0;

local function logics(target)
    if not target then return false end;
    local menu_boolean = menu_elements.main_boolean:get();
    local evade_data = my_utility.get_evade_data()
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean,
        next_time_allowed_cast,
        evade_data.spell_id);

    if not is_logic_allowed then return false end;

    local no_blood_wave_cooldown = menu_elements.no_blood_wave_cooldown:get();
    if no_blood_wave_cooldown then
        local blood_wave_ready = utility.is_spell_ready(spell_data.blood_wave.spell_id)
        if not blood_wave_ready then
            return false
        end
    end

    local target_position = target:get_position()
    local min_evade_distance = evade_data.distance - 2
    local mobility_only = menu_elements.mobility_only:get();
    if mobility_only then
        if not my_utility.is_in_range(target, max_spell_range) or my_utility.is_in_range(target, min_evade_distance) then
            return false
        end
    end

    if cast_spell.position(evade_data.spell_id, target_position, 0) then
        local current_time = get_time_since_inject();
        next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast;
        console.print("Cast Evade - Target: " ..
            my_utility.targeting_modes[menu_elements.targeting_mode:get() + 1] .. ", Mobility Only: " ..
            tostring(mobility_only));
        return true;
    end;

    return false;
end

local function out_of_combat()
    local menu_boolean = menu_elements.use_out_of_combat:get();
    local evade_data = my_utility.get_evade_data()
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean,
        next_time_allowed_cast,
        evade_data.spell_id);

    if not is_logic_allowed then return false end;

    -- check if we are in a safezone
    local is_mounted = my_utility.is_buff_active(spell_data.is_mounted.spell_id,
        spell_data.is_mounted.buff_id);
    if is_mounted then return false end;

    local local_player = get_local_player()
    local is_moving = local_player:is_moving()
    local is_dashing = local_player:is_dashing()

    -- if standing still
    if not is_moving then return false end;

    local targeting_mode = menu_elements.targeting_mode:get();
    -- if we are using cursor targeting modes then its safe to assume self play
    if targeting_mode == 6 or targeting_mode == 7 then
        local destination = get_cursor_position()
        if cast_spell.position(evade_data.spell_id, destination, 0) then
            local current_time = get_time_since_inject();
            next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast;
            console.print("Cast Evade - Out of Combat - Cursor")
            return true;
        end
    end

    -- if not self play then we dont want to spam evade
    if is_dashing then return false end;

    local destination = local_player:get_move_destination()
    local player_position = local_player:get_position()
    local travel_distance_sqr = player_position:squared_dist_to_ignore_z(destination)
    local min_evade_distance = evade_data.distance - 1
    local min_distance_sqr = min_evade_distance * min_evade_distance

    if travel_distance_sqr >= min_distance_sqr then
        if cast_spell.position(evade_data.spell_id, destination, 0) then
            local current_time = get_time_since_inject();
            next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast;
            console.print("Cast Evade - Out of Combat - Move Destination")
            return true;
        end
    end

    return false;
end

local function to_position(position)
    local evade_data = my_utility.get_evade_data()
    local is_logic_allowed = my_utility.is_spell_allowed(
        true,
        next_time_allowed_cast,
        evade_data.spell_id);

    if not is_logic_allowed then return false end;

    -- check if we are in a safezone
    local is_mounted = my_utility.is_buff_active(spell_data.is_mounted.spell_id,
        spell_data.is_mounted.buff_id);
    if is_mounted then return false end;

    -- if we have a position, use it
    if position then
        if cast_spell.position(evade_data.spell_id, position, 0) then
            local current_time = get_time_since_inject();
            next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast;
            console.print("Cast Evade - Custom Position")
            return true;
        end
    end
end

return
{
    menu = menu,
    logics = logics,
    out_of_combat = out_of_combat,
    to_position = to_position,
    menu_elements = menu_elements
}
