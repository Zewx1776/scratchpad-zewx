local my_utility = require("my_utility/my_utility")
local spell_data = require("my_utility/spell_data")

local menu_elements =
{
    tree_tab            = tree_node:new(1),
    main_boolean        = checkbox:new(true, get_hash(my_utility.plugin_label .. "blood_wave_main_boolean")),
    targeting_mode      = combo_box:new(3, get_hash(my_utility.plugin_label .. "blood_wave_targeting_mode")),
    gather_blood_orbs   = checkbox:new(true, get_hash(my_utility.plugin_label .. "blood_wave_gather_blood_orbs")),
    evade_blood_orbs    = checkbox:new(true, get_hash(my_utility.plugin_label .. "blood_wave_evade_blood_orbs")),
    reset_rathmas_vigor = checkbox:new(true, get_hash(my_utility.plugin_label .. "blood_wave_evade_blood_orbs")),
    rathmas_vigor_stop_at = slider_int:new(1, 15, 15, get_hash(my_utility.plugin_label .. "blood_wave_rathmas_vigor_stop_at")),
    min_hits            = slider_int:new(0, 30, 5, get_hash(my_utility.plugin_label .. "blood_wave_min_hits_base")),
    effect_size_affix_mult = slider_float:new(0.0, 200.0, 0.0, get_hash(my_utility.plugin_label .. "blood_wave_effect_size_affix_mult_slider_base")),
}

local function menu()
    if menu_elements.tree_tab:push("Blood Wave") then
        menu_elements.main_boolean:render("Enable Spell", "")

        if menu_elements.main_boolean:get() then
            menu_elements.gather_blood_orbs:render("Gather blood orbs", "Ultimat cooldown reduction with Fastblood")

            if menu_elements.gather_blood_orbs:get() then
                menu_elements.evade_blood_orbs:render("Use evade as well", "If enabled uses evade to gather blood orbs")
                menu_elements.reset_rathmas_vigor:render("Reset Rathma's Vigor",
                    "If enabled collects blood orbs even after cooldown is reset but not at the chosen number of Rathma's Vigor stacks for a guaranteed overpower.")
                menu_elements.rathmas_vigor_stop_at:render("Rathma's Vigor Stop At", "Stop collecting blood orbs at this many stacks of Rathma's Vigor.")
            end

            menu_elements.min_hits:render("Min Hits", "Minimum enemies to hit for Blood Wave to cast")
            menu_elements.effect_size_affix_mult:render("Effect Size Affix Mult", "Increase Blood Wave radius (%)", 1)
            menu_elements.targeting_mode:render("Targeting Mode", my_utility.targeting_modes,
                my_utility.targeting_mode_description)
        end

        menu_elements.tree_tab:pop()
    end
end

local next_time_allowed_cast = 0.0;
local function logics(target)

    local menu_boolean = menu_elements.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean,
        next_time_allowed_cast,
        spell_data.blood_wave.spell_id);

    if not is_logic_allowed then 

        return false 
    end;

    -- DEBUG: Dump all player buffs to diagnose Rathma's Vigor stack issues
    local local_player = get_local_player()
    if local_player then
        local buffs = local_player:get_buffs()
        if buffs then
            for _, buff in ipairs(buffs) do
                local stack_count = "N/A"
                local buff_name = "N/A"
                local ok1, res1 = pcall(function() return buff.get_stack_count and buff:get_stack_count() or "N/A" end)
                if ok1 then stack_count = res1 end
                local ok2, res2 = pcall(function() return buff.get_name and buff:get_name() or "N/A" end)
                if ok2 then buff_name = res2 end
                console.print("[BUFF DEBUG] name_hash=" .. tostring(buff.name_hash)
                    .. ", type=" .. tostring(buff.type)
                    .. ", stacks=" .. tostring(buff.stacks)
                    .. ", id=" .. tostring(buff.id)
                    .. ", value=" .. tostring(buff.value)
                    .. ", amount=" .. tostring(buff.amount)
                    .. ", count=" .. tostring(buff.count)
                    .. ", level=" .. tostring(buff.level)
                    .. ", charges=" .. tostring(buff.charges)
                    .. ", get_stack_count=" .. tostring(stack_count)
                    .. ", get_name=" .. tostring(buff_name))
            end
        else
            console.print("[BUFF DEBUG] No buffs found on player.")
        end
    else
        console.print("[BUFF DEBUG] No local player found.")
    end

    local reset_rathmas_vigor = menu_elements.reset_rathmas_vigor:get();
    local rathmas_vigor_stop_at = menu_elements.rathmas_vigor_stop_at:get();
    local rathmas_vigor_stacks = my_utility.buff_stack_count(spell_data.rathmas_vigor.spell_id,
        spell_data.rathmas_vigor.stack_counter);
    console.print("[RATHMA DEBUG] Checking orb collection: reset_rathmas_vigor=" .. tostring(reset_rathmas_vigor) .. ", stacks=" .. tostring(rathmas_vigor_stacks) .. ", threshold=" .. tostring(rathmas_vigor_stop_at))
    if reset_rathmas_vigor then
        if rathmas_vigor_stacks < rathmas_vigor_stop_at then
            console.print("[RATHMA DEBUG] Rathma's stacks (" .. tostring(rathmas_vigor_stacks) .. ") < threshold (" .. tostring(rathmas_vigor_stop_at) .. "): orb collection allowed.")
            local blood_orb_data = my_utility.get_blood_orb_data();
            if blood_orb_data.is_valid then
                console.print("[RATHMA DEBUG] Blood orb found, collection will proceed.")
                return false;
            end
        else
            console.print("[RATHMA DEBUG] Rathma's stacks (" .. tostring(rathmas_vigor_stacks) .. ") >= threshold (" .. tostring(rathmas_vigor_stop_at) .. "): orb collection stopped.")
        end
    end

    -- Enhanced logic: Use min hits targeting if enabled
    local use_min_hits = menu_elements.min_hits:get() and menu_elements.min_hits:get() > 0

    if use_min_hits then
    
        local menu_module = nil
        local menu_settings = nil
        local success, result = pcall(require, 'menu')
        if success and result and type(result) == 'table' and result.menu_elements then
            menu_settings = result.menu_elements
        end
        local raw_radius = 7.0
        local multiplier = menu_elements.effect_size_affix_mult:get() / 100
        local wave_radius = raw_radius * (1.0 + multiplier)
    
        local player_position = get_player_position()
    
        -- Add error handling around the target selection
        local area_data = nil
        local status, err = pcall(function()
        
            area_data = target_selector.get_most_hits_target_circular_area_heavy(player_position, 8.0, wave_radius)
            console.print("[DEBUG] Blood Wave: Successfully called get_most_hits_target_circular_area_heavy")
        end)
        
        if not status then
            console.print("[DEBUG] Blood Wave: ERROR in target selection: " .. tostring(err))
            return false
        end
        
        if not area_data then
            console.print("[DEBUG] Blood Wave: area_data is nil")
            return false
        end
        
        console.print("[DEBUG] Blood Wave: Got area_data")
        local best_target = area_data.main_target
        if not best_target then
            console.print("[DEBUG] Blood Wave: No best target found in area targeting")
            return false
        end
        console.print("[DEBUG] Blood Wave: Found best target")
        local best_target_position = best_target:get_position()
        console.print("[DEBUG] Blood Wave: best_target_position = " .. tostring(best_target_position.x) .. ", " .. tostring(best_target_position.y) .. ", " .. tostring(best_target_position.z))
        
        -- Check if target is a boss
        local is_boss_target = best_target:is_boss()
        console.print("[DEBUG] Blood Wave: is_boss_target = " .. tostring(is_boss_target))
        
        -- Wall/line-of-sight check: do not target through walls (unless it's a boss)
        local is_wall_collision = false
        if prediction and prediction.is_wall_collision then
            local player_position = get_player_position()
            is_wall_collision = prediction.is_wall_collision(player_position, best_target_position, 1)
        elseif my_utility and my_utility.is_wall_collision then
            local player_position = get_player_position()
            is_wall_collision = my_utility.is_wall_collision(player_position, best_target_position, 1)
        end
        console.print("[DEBUG] Blood Wave: is_wall_collision = " .. tostring(is_wall_collision))
        
        -- Skip wall collision check for boss targets
        if is_wall_collision and not is_boss_target then
            console.print("[DEBUG] Blood Wave: Wall collision detected (not a boss), returning false")
            return false
        elseif is_wall_collision and is_boss_target then
            console.print("[DEBUG] Blood Wave: Wall collision detected but target is a boss, proceeding anyway")
        end
        local best_cast_data = my_utility.get_best_point(best_target_position, wave_radius, area_data.victim_list)
        local victim_list = best_cast_data.victim_list or {}
        console.print("[DEBUG] Blood Wave: Number of victims found = " .. tostring(#victim_list))

        -- Get custom enemy weights from menu (fallback to defaults if not set)
        local normal_weight = 2
        local elite_weight = 10
        local champion_weight = 15
        local boss_weight = 50
        if menu_settings then
            normal_weight = (menu_settings.enemy_weight_normal and menu_settings.enemy_weight_normal:get()) or normal_weight
            elite_weight = (menu_settings.enemy_weight_elite and menu_settings.enemy_weight_elite:get()) or elite_weight
            champion_weight = (menu_settings.enemy_weight_champion and menu_settings.enemy_weight_champion:get()) or champion_weight
            boss_weight = (menu_settings.enemy_weight_boss and menu_settings.enemy_weight_boss:get()) or boss_weight
        end

        -- Sum weighted value of all enemies in victim_list
        local total_weight = 0
        for _, unit in ipairs(victim_list) do
            if unit:is_boss() then
                total_weight = total_weight + boss_weight
                console.print("[DEBUG] Blood Wave: Found boss, weight +" .. tostring(boss_weight))
            elseif unit:is_champion() then
                total_weight = total_weight + champion_weight
                console.print("[DEBUG] Blood Wave: Found champion, weight +" .. tostring(champion_weight))
            elseif unit:is_elite() then
                total_weight = total_weight + elite_weight
                console.print("[DEBUG] Blood Wave: Found elite, weight +" .. tostring(elite_weight))
            else
                total_weight = total_weight + normal_weight
                console.print("[DEBUG] Blood Wave: Found normal, weight +" .. tostring(normal_weight))
            end
        end
        console.print("[DEBUG] Blood Wave: total_weight = " .. tostring(total_weight) .. ", min_hits required = " .. tostring(menu_elements.min_hits:get()))

        if total_weight < menu_elements.min_hits:get() then
            console.print("[DEBUG] Blood Wave: total_weight < min_hits, returning false")
            return false
        end
        console.print("[DEBUG] Blood Wave: Weight check passed, proceeding with cast")
        pathfinder.request_move(best_target_position)
        
        -- Use 4.5 range for boss targets, otherwise use 3.5
        local range_to_use = is_boss_target and 6.5 or 3.5
        local in_range = my_utility.is_in_range(best_target, range_to_use)
        console.print("[DEBUG] Blood Wave: in_range (min_hits path) = " .. tostring(in_range) .. " (using range " .. range_to_use .. ")")
        
        if not in_range then
            console.print("[DEBUG] Blood Wave: Not in range (min_hits path), returning false")
            return false
        end
        if cast_spell.target(best_target, spell_data.blood_wave.spell_id, 0, false) then
            local current_time = get_time_since_inject();
            next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast;
            console.print("Cast Blood Wave - Target (Weighted Min Hits): " .. total_weight)
            return true
        end
        return false
    end

    -- Fallback to original logic if min hits is not enabled
    if not target then 
        console.print("[DEBUG] Blood Wave: Target is nil, returning false")
        return false 
    end;
    
    local status, err = pcall(function()
        console.print("[DEBUG] Blood Wave: Using standard targeting logic")
        local target_position = target:get_position()
        console.print("[DEBUG] Blood Wave: Target position = " .. tostring(target_position.x) .. ", " .. tostring(target_position.y) .. ", " .. tostring(target_position.z))
        pathfinder.request_move(target_position)
    end)
    
    if not status then
        console.print("[DEBUG] Blood Wave: ERROR in standard targeting: " .. tostring(err))
        return false
    end
    
    -- Check if target is a boss
    local is_boss_target = target:is_boss()
    console.print("[DEBUG] Blood Wave: Standard path is_boss_target = " .. tostring(is_boss_target))
    
    -- Use different range based on target type
    local range_to_use = is_boss_target and 4.5 or 9.5
    local in_range = my_utility.is_in_range(target, range_to_use)
    console.print("[DEBUG] Blood Wave: in_range = " .. tostring(in_range) .. " (using range " .. range_to_use .. ")")
    
    if not in_range then
        console.print("[DEBUG] Blood Wave: Not in range, returning false")
        return false;
    end
    console.print("[DEBUG] Blood Wave: In range, attempting to cast")
    local cast_result = cast_spell.target(target, spell_data.blood_wave.spell_id, 0, false)
    console.print("[DEBUG] Blood Wave: cast_result = " .. tostring(cast_result))
    if cast_result then
        local current_time = get_time_since_inject();
        next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast;
        console.print("Cast Blood Wave - Target: " ..
            my_utility.targeting_modes[menu_elements.targeting_mode:get() + 1]);
        return true;
    else
        console.print("[DEBUG] Blood Wave: Cast failed")
    end;
    console.print("[DEBUG] Blood Wave: Reached end of function, returning false")
    return false;
end

return
{
    menu = menu,
    logics = logics,
    menu_elements = menu_elements
}
