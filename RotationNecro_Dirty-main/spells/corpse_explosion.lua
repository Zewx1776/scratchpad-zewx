local my_utility = require("my_utility/my_utility");
local spell_data = require("my_utility/spell_data");

local menu_elements =
{
    tree_tab         = tree_node:new(1),
    main_boolean     = checkbox:new(true, get_hash(my_utility.plugin_label .. "corpse_explosion_base_main_bool")),
    -- filter_mode  = combo_box:new(0, get_hash(my_utility.plugin_label .. "corpse_explosion_base_filter_mode")),
    -- enemy_count_threshold = slider_int:new(0, 30, 1,
    --     get_hash(my_utility.plugin_label .. "corpse_explosion_base_enemy_count_threshold")),
    flesh_eater_only = checkbox:new(true, get_hash(my_utility.plugin_label .. "corpse_explosion_base_flesh_eater_only")),
    avoid_blood_orbs = checkbox:new(true, get_hash(my_utility.plugin_label .. "corpse_explosion_base_avoid_blood_orbs")),
    -- evaluation_range      = slider_int:new(1, 16, 12,
    --     get_hash(my_utility.plugin_label .. "corpse_explosion_base_evaluation_range")),
}

local function menu()
    if menu_elements.tree_tab:push("corpse_explosion") then
        menu_elements.main_boolean:render("Enable Spell", "")

        if menu_elements.main_boolean:get() then
            menu_elements.flesh_eater_only:render("Only recast if Flesh Eater is not active", "")
            menu_elements.avoid_blood_orbs:render("Don't cast when blood orbs are on the ground", "Prioritizes collecting blood orbs over casting Corpse Explosion")
            -- menu_elements.evaluation_range:render("Evaluation Range", my_utility.evaluation_range_description)
            -- menu_elements.filter_mode:render("Filter Modes", my_utility.activation_filters, "")
            -- menu_elements.enemy_count_threshold:render("Minimum Enemy Count",
            -- "       Minimum number of enemies in Evaluation Range for spell activation")
        end

        menu_elements.tree_tab:pop()
    end
end

local next_time_allowed_cast = 2.0;

local function get_corpse_explosion_data()
    -- Hit Calculation: We now calculate the number of enemies each corpse can hit using utility.get_amount_of_units_inside_circle(center, radius).
    -- Sorting: The list of corpses is sorted by the number of hits in descending order.
    -- Return Value: The function returns the corpse that can potentially hit the most enemies. If no such corpse is found, it returns {is_valid = false, corpse = nil, hits = 0}.

    -- local raw_radius = 3.0;                                              -- Base radius for the explosion
    -- local multiplier = menu_elements.effect_size_affix_mult:get() / 100; -- Convert the percentage to a multiplier
    -- local corpse_explosion_range = raw_radius * (1.0 + multiplier);      -- Calculate the new radius
    local corpse_explosion_range = 10; -- default corpse range
    local player_position = get_player_position();
    local actors = actors_manager.get_ally_actors();

    local great_corpse_list = {};
    for _, object in ipairs(actors) do
        local skin_name = object:get_skin_name();
        local is_corpse = skin_name == "Necro_Corpse";

        if is_corpse then
            local corpse_position = object:get_position();
            local distance_to_player_sqr = corpse_position:squared_dist_to_ignore_z(player_position);
            if distance_to_player_sqr <= (9.0 * 9.0) then
                -- Calculate how many enemies this corpse can hit
                local hits = utility.get_amount_of_units_inside_circle(corpse_position, corpse_explosion_range)
                if hits > 0 then
                    table.insert(great_corpse_list, { hits = hits, corpse = object });
                end
            end
        end
    end

    -- Sort the list by the number of hits
    table.sort(great_corpse_list, function(a, b)
        return a.hits > b.hits
    end);

    -- Return the corpse that can hit the most enemies, if any
    if #great_corpse_list > 0 then
        local corpse_ = great_corpse_list[1].corpse;
        if corpse_ then
            return { is_valid = true, corpse = corpse_, hits = great_corpse_list[1].hits };
        end
    end

    return { is_valid = false, corpse = nil, hits = 0 };
end

local function logics()
    local menu_boolean = menu_elements.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean,
        next_time_allowed_cast,
        spell_data.corpse_explosion.spell_id);

    if not is_logic_allowed then return false end;

    -- Check for blood orbs on the ground
    if menu_elements.avoid_blood_orbs:get() then
        local blood_orb_data = my_utility.get_blood_orb_data();
        if blood_orb_data.is_valid then
            return false;
        end
    end

    -- Checking for Flesh Eater
    local flesh_eater_only = menu_elements.flesh_eater_only:get();
    local flesh_eater_active = my_utility.is_buff_active(spell_data.flesh_eater.spell_id,
        spell_data.flesh_eater.buff_id);
    if flesh_eater_only and flesh_eater_active then
        return false;
    end

    local corpses_data = get_corpse_explosion_data();
    if not corpses_data.is_valid then
        return false;
    end

    if cast_spell.target(corpses_data.corpse, spell_data.corpse_explosion.spell_id, 0, false) then
        local current_time = get_time_since_inject();
        next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast;

        console.print("Cast Corpse Explosion - Flesh Eater Only: " ..
            tostring(flesh_eater_only) .. " - Hits: " .. corpses_data.hits);
        return true;
    end

    return false;
end

return
{
    menu = menu,
    logics = logics,
    get_corpse_explosion_data = get_corpse_explosion_data,
    menu_elements = menu_elements
}
