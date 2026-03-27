local local_player = get_local_player();
if local_player == nil then
    return
end

local character_id = local_player:get_character_class_id();
local is_druid = character_id == 5;
if not is_druid then
    return
end;

-- orbwalker settings
orbwalker.set_block_movement(true);
orbwalker.set_clear_toggle(true);

local my_target_selector = require("my_utility/my_target_selector");
local my_utility = require("my_utility/my_utility");
local spell_data = require("my_utility/spell_data");
local spell_priority = require("spell_priority");
local menu = require("menu")

local spells =
{
    blood_howls = require("spells/blood_howls"),
    boulder = require("spells/boulder"),
    cataclysm = require("spells/cataclysm"),
    claw = require("spells/claw"),
    cyclone_armor = require("spells/cyclone_armor"),
    debilitating_roar = require("spells/debilitating_roar"),
    earth_spike = require("spells/earth_spike"),
    earthen_bulwark = require("spells/earthen_bulwark"),
    evade = require("spells/evade"),
    grizzly_rage = require("spells/grizzly_rage"),
    hurricane = require("spells/hurricane"),
    lacerate = require("spells/lacerate"),
    landslide = require("spells/landslide"),
    lightningstorm = require("spells/lightningstorm"),
    maul = require("spells/maul"),
    petrify = require("spells/petrify"),
    poison_creeper = require("spells/poison_creeper"),
    pulverize = require("spells/pulverize"),
    rabies = require("spells/rabies"),
    ravens = require("spells/ravens"),
    shred = require("spells/shred"),
    stone_burst = require("spells/stone_burst"),
    storm_strike = require("spells/storm_strike"),
    tornado = require("spells/tornado"),
    trample = require("spells/trample"),
    wind_shear = require("spells/wind_shear"),
    wolves = require("spells/wolves")
}

on_render_menu(function()
    if not menu.menu_elements.main_tree:push("Druid [Dirty] v1.0.0") then
        return;
    end;

    menu.menu_elements.main_boolean:render("Enable Plugin", "");

    if not menu.menu_elements.main_boolean:get() then
        -- plugin not enabled, stop rendering menu elements
        menu.menu_elements.main_tree:pop();
        return;
    end;

    if menu.menu_elements.weighted_targeting_tree:push("Weighted Targeting System") then
        menu.menu_elements.weighted_targeting_debug:render("Debug Mode", "Enable high-verbosity console logging for weighted targeting decisions")
        menu.menu_elements.weighted_targeting_enabled:render("Enable Weighted Targeting", "Enables the weighted targeting system that prioritizes targets based on type and proximity")
        
        -- Only show configuration if weighted targeting is enabled
        if menu.menu_elements.weighted_targeting_enabled:get() then
            -- Scan settings
            menu.menu_elements.max_targeting_range:render("Max Targeting Range", "Maximum range for targeting")
            menu.menu_elements.targeting_refresh_interval:render("Refresh Rate", "How often to refresh target scanning in seconds (0.1-1.0)", 1)
            menu.menu_elements.min_targets:render("Minimum Targets", "Minimum number of targets required to activate weighted targeting (1-10)")
            menu.menu_elements.comparison_radius:render("Comparison Radius", "Radius to check for nearby targets when calculating weights (0.1-6.0)", 1)
            
            -- Cursor targeting options
            menu.menu_elements.cursor_targeting_radius:render("Cursor Targeting Radius", "Area size for selecting target around the cursor", 1)
            menu.menu_elements.cursor_targeting_angle:render("Cursor Targeting Angle", "Maximum angle between cursor and target to cast targetted spells")
            
            -- Custom Enemy Sliders toggle
            menu.menu_elements.custom_enemy_sliders_enabled:render("Custom Enemy Sliders", "Enable to customize target counts and weights for different enemy types")
            
            -- Only show sliders if custom enemy sliders are enabled
            if menu.menu_elements.custom_enemy_sliders_enabled:get() then
                -- Normal Enemy
                menu.menu_elements.normal_target_count:render("Normal Target Count", "Target count value for normal enemies (1-10)")
                menu.menu_elements.any_weight:render("Normal Weight", "Weight assigned to normal targets (1-100)")
                
                -- Elite Enemy
                menu.menu_elements.elite_target_count:render("Elite Target Count", "Target count value for elite enemies (1-10)")
                menu.menu_elements.elite_weight:render("Elite Weight", "Weight assigned to elite targets (1-100)")
                
                -- Champion Enemy
                menu.menu_elements.champion_target_count:render("Champion Target Count", "Target count value for champion enemies (1-10)")
                menu.menu_elements.champion_weight:render("Champion Weight", "Weight assigned to champion targets (1-100)")
                
                -- Boss Enemy
                menu.menu_elements.boss_target_count:render("Boss Target Count", "Target count value for boss enemies (1-10)")
                menu.menu_elements.boss_weight:render("Boss Weight", "Weight assigned to boss targets (1-100)")
            end
            
            -- Custom Buff Weights section
            menu.menu_elements.custom_buff_weights_enabled:render("Custom Buff Weights", "Enable to customize weights for special buff-related targets")
            if menu.menu_elements.custom_buff_weights_enabled:get() then
                menu.menu_elements.damage_resistance_provider_weight:render("Damage Resistance Provider Bonus", "Weight bonus for enemies providing damage resistance aura (1-100)")
                menu.menu_elements.damage_resistance_receiver_penalty:render("Damage Resistance Receiver Penalty", "Weight penalty for enemies receiving damage resistance (0-20)")
                menu.menu_elements.horde_objective_weight:render("Horde Objective Bonus", "Weight bonus for infernal horde objective targets (1-100)")
                menu.menu_elements.vulnerable_debuff_weight:render("Vulnerable Debuff Bonus", "Weight bonus for targets with VulnerableDebuff (1-5)")
            end
        end
        
        menu.menu_elements.enable_debug:render("Enable Debug", "")
        if menu.menu_elements.enable_debug:get() then
            if menu.menu_elements.debug_tree:push("Debug") then
                menu.menu_elements.draw_targets:render("Display Targets", menu.draw_targets_description)
                menu.menu_elements.draw_max_range:render("Display Max Range", "Draw max range circle")
                menu.menu_elements.draw_melee_range:render("Display Melee Range", "Draw melee range circle")
                menu.menu_elements.draw_enemy_circles:render("Display Enemy Circles", "Draw enemy circles")
                menu.menu_elements.draw_cursor_target:render("Display Cursor Target", menu.cursor_target_description)
                menu.menu_elements.debug_tree:pop()
            end
        end
        
        menu.menu_elements.weighted_targeting_tree:pop()
    end

    local equipped_spells = get_equipped_spell_ids()
    table.insert(equipped_spells, spell_data.evade.spell_id) -- add evade to the list

    -- Create a lookup table for equipped spells
    local equipped_lookup = {}
    for _, spell_id in ipairs(equipped_spells) do
        -- Check each spell in spell_data to find matching spell_id
        for spell_name, data in pairs(spell_data) do
            if data.spell_id == spell_id then
                equipped_lookup[spell_name] = true
                break
            end
        end
    end

    if menu.menu_elements.spells_tree:push("Equipped Spells") then
        -- Display spells in priority order, but only if they're equipped
        for _, spell_name in ipairs(spell_priority) do
            if equipped_lookup[spell_name] then
                local spell = spells[spell_name]
                if spell then
                    spell.menu()
                end
            end
        end
        menu.menu_elements.spells_tree:pop()
    end

    if menu.menu_elements.disabled_spells_tree:push("Inactive Spells") then
        for _, spell_name in ipairs(spell_priority) do
            local spell = spells[spell_name]
            if spell and (not equipped_lookup[spell_name] or not spell.menu_elements.main_boolean:get()) then
                spell.menu()
            end
        end
        menu.menu_elements.disabled_spells_tree:pop()
    end

    menu.menu_elements.main_tree:pop();
end)

-- Targets
local best_ranged_target = nil
local best_ranged_target_visible = nil
local best_melee_target = nil
local best_melee_target_visible = nil
local closest_target = nil
local closest_target_visible = nil
local best_cursor_target = nil
local closest_cursor_target = nil
local closest_cursor_target_angle = 0
-- Targetting scores
local ranged_max_score = 0
local ranged_max_score_visible = 0
local melee_max_score = 0
local melee_max_score_visible = 0
local cursor_max_score = 0

-- Targetting settings
local max_targeting_range = menu.menu_elements.max_targeting_range:get()
local collision_table = { true, 1 } -- collision width
local floor_table = { true, 5.0 }   -- floor height
local angle_table = { false, 90.0 } -- max angle

-- Cache for heavy function results
local next_target_update_time = 0.0 -- Time of next target evaluation
local next_cast_time = 0.0          -- Time of next possible cast
local targeting_refresh_interval = menu.menu_elements.targeting_refresh_interval:get()

-- Default enemy weights for different enemy types
local normal_monster_value = 2
local elite_value = 10
local champion_value = 15
local boss_value = 50
local damage_resistance_provider_weight = 30
local damage_resistance_receiver_penalty = 5
local horde_objective_weight = 50
local vulnerable_debuff_weight = 1

-- Target count values
local normal_target_count = 1
local elite_target_count = 5
local champion_target_count = 5
local boss_target_count = 5

local target_selector_data_all = nil

local function evaluate_targets(target_list, melee_range)
    local best_ranged_target = nil
    local best_melee_target = nil
    local best_cursor_target = nil
    local closest_cursor_target = nil
    local closest_cursor_target_angle = 0

    local ranged_max_score = 0
    local melee_max_score = 0
    local cursor_max_score = 0

    local melee_range_sqr = melee_range * melee_range
    local player_position = get_player_position()
    local cursor_position = get_cursor_position()
    local cursor_targeting_radius = menu.menu_elements.cursor_targeting_radius:get()
    local cursor_targeting_radius_sqr = cursor_targeting_radius * cursor_targeting_radius
    local comparison_radius = menu.menu_elements.comparison_radius:get()
    local cursor_targeting_angle = menu.menu_elements.cursor_targeting_angle:get()
    local min_targets = menu.menu_elements.min_targets:get()
    local closest_cursor_distance_sqr = math.huge
    local debug_enabled = menu.menu_elements.weighted_targeting_debug:get()

    -- Calculate individual weight for each target
    local weighted_targets = {}
    for _, unit in ipairs(target_list) do
        local unit_health = unit:get_current_health()
        local unit_name = unit:get_skin_name()
        local unit_position = unit:get_position()
        local distance_sqr = unit_position:squared_dist_to_ignore_z(player_position)
        local cursor_distance_sqr = unit_position:squared_dist_to_ignore_z(cursor_position)
        local buffs = unit:get_buffs()
        
        -- Calculate base weight based on enemy type
        local base_weight = normal_monster_value
        local target_count_value = normal_target_count
        local unit_type = "Normal"
        
        if unit:is_boss() then
            base_weight = boss_value
            target_count_value = boss_target_count
            unit_type = "Boss"
        elseif unit:is_elite() then
            base_weight = elite_value
            target_count_value = elite_target_count
            unit_type = "Elite"
        elseif unit:is_champion() then
            base_weight = champion_value
            target_count_value = champion_target_count
            unit_type = "Champion"
        end
        
        local original_weight = base_weight
        
        -- Check for damage resistance buff and vulnerable debuff
        local has_vulnerable_debuff = false
        for _, buff in ipairs(buffs) do
            if buff.name_hash == spell_data.enemies.damage_resistance.spell_id then
                -- If the enemy is the provider of the damage resistance aura
                if buff.type == spell_data.enemies.damage_resistance.buff_ids.provider then
                    base_weight = base_weight + damage_resistance_provider_weight
                    break
                else -- Otherwise the enemy is the receiver of the damage resistance aura
                    base_weight = base_weight - damage_resistance_receiver_penalty
                    break
                end
            end
            -- Check for VulnerableDebuff (898635)
            if buff.name_hash == 898635 then
                has_vulnerable_debuff = true
            end
        end
        if has_vulnerable_debuff then
            base_weight = base_weight + vulnerable_debuff_weight
        end
        
        -- Check if unit is an infernal horde objective
        for _, objective_name in ipairs(my_utility.horde_objectives) do
            if unit_name:match(objective_name) and unit_health > 1 then
                base_weight = base_weight + horde_objective_weight
                break
            end
        end
        
        -- Store unit with its calculated weight and target count value
        table.insert(weighted_targets, {
            unit = unit,
            weight = base_weight,
            target_count = target_count_value,
            position = unit_position,
            distance_sqr = distance_sqr,
            cursor_distance_sqr = cursor_distance_sqr,
            unit_type = unit_type
        })
    end
    
    -- Find clusters of enemies and calculate cluster weights
    for i, target in ipairs(weighted_targets) do
        local cluster_weight = target.weight
        local cluster_target_count = target.target_count
        
        -- Find all targets within comparison_radius of this target
        for j, other_target in ipairs(weighted_targets) do
            if i ~= j then
                if target.position:dist_to(other_target.position) <= comparison_radius then
                    -- Add to cluster
                    cluster_weight = cluster_weight + other_target.weight
                    cluster_target_count = cluster_target_count + other_target.target_count
                end
            end
        end
        
        -- Check if cluster meets minimum target count threshold
        local total_score = 0
        if cluster_target_count >= min_targets then
            total_score = cluster_weight
        else
            -- If below threshold, only count this target if it's special (elite, champion, boss, or special buff)
            if target.unit:is_elite() or target.unit:is_champion() or target.unit:is_boss() or target.weight > normal_monster_value then
                total_score = target.weight
            end
        end
        
        -- in max range
        if total_score > ranged_max_score then
            ranged_max_score = total_score
            best_ranged_target = target.unit
        end

        -- in melee range
        if target.distance_sqr < melee_range_sqr and total_score > melee_max_score then
            melee_max_score = total_score
            best_melee_target = target.unit
        end

        -- in cursor angle
        if target.cursor_distance_sqr <= cursor_targeting_radius_sqr then
            local angle_to_cursor = target.position:get_angle(cursor_position, player_position)
            if angle_to_cursor <= cursor_targeting_angle then
                if total_score > cursor_max_score then
                    cursor_max_score = total_score
                    best_cursor_target = target.unit
                end

                if target.cursor_distance_sqr < closest_cursor_distance_sqr then
                    closest_cursor_distance_sqr = target.cursor_distance_sqr
                    closest_cursor_target = target.unit
                    closest_cursor_target_angle = angle_to_cursor
                end
            end
        end
    end

    return best_ranged_target, best_melee_target, best_cursor_target, closest_cursor_target, ranged_max_score,
        melee_max_score, cursor_max_score, closest_cursor_target_angle
end

local function use_ability(spell_name, delay_after_cast)
    local spell = spells[spell_name]
    if not (spell and spell.menu_elements.main_boolean:get()) then
        return false
    end

    local target_unit = nil
    if spell.menu_elements.targeting_mode then
        local targeting_mode = spell.menu_elements.targeting_mode:get()
        target_unit = ({
            [0] = best_ranged_target,
            [1] = best_ranged_target_visible,
            [2] = best_melee_target,
            [3] = best_melee_target_visible,
            [4] = closest_target,
            [5] = closest_target_visible,
            [6] = best_cursor_target,
            [7] = closest_cursor_target
        })[targeting_mode]
    end

    --if target_unit is nil, it means the spell is not targetted and we use the default logic without target
    if (target_unit and spell.logics(target_unit)) or (not target_unit and spell.logics()) then
        next_cast_time = get_time_since_inject() + delay_after_cast
        return true
    end

    return false
end

-- on_update callback
on_update(function()
    local current_time = get_time_since_inject()
    local local_player = get_local_player()
    if not local_player or menu.menu_elements.main_boolean:get() == false or current_time < next_cast_time then
        return
    end

    if not my_utility.is_action_allowed() then
        return;
    end

    -- Out of combat evade
    if spells.evade and spells.evade.menu_elements.use_out_of_combat:get() then
        spells.evade.out_of_combat()
    end

    targeting_refresh_interval = menu.menu_elements.targeting_refresh_interval:get()
    -- Only update targets if targeting_refresh_interval has expired
    if current_time >= next_target_update_time then
        local player_position = get_player_position()
        max_targeting_range = menu.menu_elements.max_targeting_range:get()

        local entity_list_visible, entity_list = my_target_selector.get_target_list(
            player_position,
            max_targeting_range,
            collision_table,
            floor_table,
            angle_table)

        target_selector_data_all = my_target_selector.get_target_selector_data(
            player_position,
            entity_list)

        local target_selector_data_visible = my_target_selector.get_target_selector_data(
            player_position,
            entity_list_visible)

        if not target_selector_data_all or not target_selector_data_all.is_valid then
            return
        end

        -- Reset targets
        best_ranged_target = nil
        best_melee_target = nil
        closest_target = nil
        best_ranged_target_visible = nil
        best_melee_target_visible = nil
        closest_target_visible = nil
        best_cursor_target = nil
        closest_cursor_target = nil
        closest_cursor_target_angle = 0
        local melee_range = my_utility.get_melee_range()

        -- Update enemy weights, use custom weights if enabled
        if menu.menu_elements.custom_enemy_sliders_enabled:get() then
            normal_target_count = menu.menu_elements.normal_target_count:get()
            normal_monster_value = menu.menu_elements.any_weight:get()
            elite_target_count = menu.menu_elements.elite_target_count:get()
            elite_value = menu.menu_elements.elite_weight:get()
            champion_target_count = menu.menu_elements.champion_target_count:get()
            champion_value = menu.menu_elements.champion_weight:get()
            boss_target_count = menu.menu_elements.boss_target_count:get()
            boss_value = menu.menu_elements.boss_weight:get()
        else
            normal_target_count = 1
            normal_monster_value = 2
            elite_target_count = 5
            elite_value = 10
            champion_target_count = 5
            champion_value = 15
            boss_target_count = 5
            boss_value = 50
        end
        
        -- Update buff weights, use custom weights if enabled
        if menu.menu_elements.custom_buff_weights_enabled:get() then
            damage_resistance_provider_weight = menu.menu_elements.damage_resistance_provider_weight:get()
            damage_resistance_receiver_penalty = menu.menu_elements.damage_resistance_receiver_penalty:get()
            horde_objective_weight = menu.menu_elements.horde_objective_weight:get()
            vulnerable_debuff_weight = menu.menu_elements.vulnerable_debuff_weight:get()
        else
            damage_resistance_provider_weight = 30
            damage_resistance_receiver_penalty = 5
            horde_objective_weight = 50
            vulnerable_debuff_weight = 1
        end

        -- Check all targets within max range
        if target_selector_data_all and target_selector_data_all.is_valid then
            best_ranged_target, best_melee_target, best_cursor_target, closest_cursor_target, ranged_max_score,
            melee_max_score, cursor_max_score, closest_cursor_target_angle = evaluate_targets(
                target_selector_data_all.list,
                melee_range)
            closest_target = target_selector_data_all.closest_unit
        end


        -- Check visible targets within max range
        if target_selector_data_visible and target_selector_data_visible.is_valid then
            best_ranged_target_visible, best_melee_target_visible, _, _,
            ranged_max_score_visible, melee_max_score_visible, _ = evaluate_targets(
                target_selector_data_visible.list,
                melee_range)
            closest_target_visible = target_selector_data_visible.closest_unit
        end

        -- Update next target update time
        next_target_update_time = current_time + targeting_refresh_interval
    end

    -- Ability usage - uses spell_priority to determine the order of spells
    for _, spell_name in ipairs(spell_priority) do
        local spell = spells[spell_name]
        if spell then
            if use_ability(spell_name, my_utility.spell_delays.regular_cast) then
                return
            end
        end
    end
end)

-- Debug
local font_size = 16
local y_offset = font_size + 2
local visible_text = 255
local visible_alpha = 180
local alpha = 100
local target_evaluation_radius_alpha = 50
on_render(function()
    if menu.menu_elements.main_boolean:get() == false or not menu.menu_elements.enable_debug:get() then
        return;
    end;

    local local_player = get_local_player();
    if not local_player then
        return;
    end

    local player_position = local_player:get_position();
    local player_screen_position = graphics.w2s(player_position);
    if player_screen_position:is_zero() then
        return;
    end

    -- Draw max range
    max_targeting_range = menu.menu_elements.max_targeting_range:get()
    if menu.menu_elements.draw_max_range:get() then
        graphics.circle_3d(player_position, max_targeting_range, color_white(85), 2.5, 144)
    end

    -- Draw melee range
    if menu.menu_elements.draw_melee_range:get() then
        local melee_range = my_utility.get_melee_range()
        graphics.circle_3d(player_position, melee_range, color_white(85), 2.5, 144)
    end

    -- Draw enemy circles
    if menu.menu_elements.draw_enemy_circles:get() then
        local enemies = actors_manager.get_enemy_npcs()

        for i, obj in ipairs(enemies) do
            local position = obj:get_position();
            graphics.circle_3d(position, 1, color_white(100));

            local future_position = prediction.get_future_unit_position(obj, 0.4);
            graphics.circle_3d(future_position, 0.25, color_yellow(100));
        end;
    end

    if menu.menu_elements.draw_cursor_target:get() then
        local cursor_position = get_cursor_position()
        local cursor_targeting_radius = menu.menu_elements.cursor_targeting_radius:get()

        -- Draw cursor radius
        graphics.circle_3d(cursor_position, cursor_targeting_radius, color_white(target_evaluation_radius_alpha), 1);
    end

    -- Only draw targets if we have valid target selector data
    if not target_selector_data_all or not target_selector_data_all.is_valid then
        return
    end

    local comparison_radius = menu.menu_elements.comparison_radius:get()

    -- Draw targets
    if menu.menu_elements.draw_targets:get() then
        -- Draw visible ranged target
        if best_ranged_target_visible and best_ranged_target_visible:is_enemy() then
            local best_ranged_target_visible_position = best_ranged_target_visible:get_position();
            local best_ranged_target_visible_position_2d = graphics.w2s(best_ranged_target_visible_position);
            graphics.line(best_ranged_target_visible_position_2d, player_screen_position, color_red(visible_alpha),
                2.5)
            graphics.circle_3d(best_ranged_target_visible_position, 0.80, color_red(visible_alpha), 2.0);
            graphics.circle_3d(best_ranged_target_visible_position, comparison_radius,
                color_white(target_evaluation_radius_alpha), 1);
            local text_position = vec2:new(best_ranged_target_visible_position_2d.x,
                best_ranged_target_visible_position_2d.y - y_offset)
            graphics.text_2d("RANGED_VISIBLE - Score:" .. ranged_max_score_visible, text_position, font_size,
                color_red(visible_text))
        end

        -- Draw ranged target if it's not the same as the visible ranged target
        if best_ranged_target_visible ~= best_ranged_target and best_ranged_target and best_ranged_target:is_enemy() then
            local best_ranged_target_position = best_ranged_target:get_position();
            local best_ranged_target_position_2d = graphics.w2s(best_ranged_target_position);
            graphics.circle_3d(best_ranged_target_position, 0.80, color_red_pale(alpha), 2.0);
            graphics.circle_3d(best_ranged_target_position, comparison_radius,
                color_white(target_evaluation_radius_alpha), 1);
            local text_position = vec2:new(best_ranged_target_position_2d.x,
                best_ranged_target_position_2d.y - y_offset)
            graphics.text_2d("RANGED - Score:" .. ranged_max_score, text_position, font_size, color_red_pale(alpha))
        end

        -- Draw visible melee target
        if best_melee_target_visible and best_melee_target_visible:is_enemy() then
            local best_melee_target_visible_position = best_melee_target_visible:get_position();
            local best_melee_target_visible_position_2d = graphics.w2s(best_melee_target_visible_position);
            graphics.line(best_melee_target_visible_position_2d, player_screen_position, color_green(visible_alpha),
                2.5)
            graphics.circle_3d(best_melee_target_visible_position, 0.70, color_green(visible_alpha), 2.0);
            graphics.circle_3d(best_melee_target_visible_position, comparison_radius,
                color_white(target_evaluation_radius_alpha), 1);
            local text_position = vec2:new(best_melee_target_visible_position_2d.x,
                best_melee_target_visible_position_2d.y)
            graphics.text_2d("MELEE_VISIBLE - Score:" .. melee_max_score_visible, text_position, font_size,
                color_green(visible_text))
        end

        -- Draw melee target if it's not the same as the visible melee target
        if best_melee_target_visible ~= best_melee_target and best_melee_target and best_melee_target:is_enemy() then
            local best_melee_target_position = best_melee_target:get_position();
            local best_melee_target_position_2d = graphics.w2s(best_melee_target_position);
            graphics.circle_3d(best_melee_target_position, 0.70, color_green_pale(alpha), 2.0);
            graphics.circle_3d(best_melee_target_position, comparison_radius,
                color_white(target_evaluation_radius_alpha), 1);
            local text_position = vec2:new(best_melee_target_position_2d.x, best_melee_target_position_2d.y)
            graphics.text_2d("MELEE - Score:" .. melee_max_score, text_position, font_size, color_green_pale(alpha))
        end

        -- Draw visible closest target
        if closest_target_visible and closest_target_visible:is_enemy() then
            local closest_target_visible_position = closest_target_visible:get_position();
            local closest_target_visible_position_2d = graphics.w2s(closest_target_visible_position);
            graphics.line(closest_target_visible_position_2d, player_screen_position, color_cyan(visible_alpha), 2.5)
            graphics.circle_3d(closest_target_visible_position, 0.60, color_cyan(visible_alpha), 2.0);
            graphics.circle_3d(closest_target_visible_position, comparison_radius,
                color_white(target_evaluation_radius_alpha), 1);
            local text_position = vec2:new(closest_target_visible_position_2d.x,
                closest_target_visible_position_2d.y + y_offset)
            graphics.text_2d("CLOSEST_VISIBLE", text_position, font_size, color_cyan(visible_text))
        end

        -- Draw closest target if it's not the same as the visible closest target
        if closest_target_visible ~= closest_target and closest_target and closest_target:is_enemy() then
            local closest_target_position = closest_target:get_position();
            local closest_target_position_2d = graphics.w2s(closest_target_position);
            graphics.circle_3d(closest_target_position, 0.60, color_cyan_pale(alpha), 2.0);
            graphics.circle_3d(closest_target_position, comparison_radius,
                color_white(target_evaluation_radius_alpha), 1);
            local text_position = vec2:new(closest_target_position_2d.x, closest_target_position_2d.y + y_offset)
            graphics.text_2d("CLOSEST", text_position, font_size, color_cyan_pale(alpha))
        end
    end

    if menu.menu_elements.draw_cursor_target:get() then
        -- Draw best cursor target
        if best_cursor_target and best_cursor_target:is_enemy() then
            local best_cursor_target_position = best_cursor_target:get_position();
            local best_cursor_target_position_2d = graphics.w2s(best_cursor_target_position);
            graphics.circle_3d(best_cursor_target_position, 0.60, color_orange_red(255), 2.0, 5);
            graphics.text_2d("BEST_CURSOR_TARGET - Score:" .. cursor_max_score, best_cursor_target_position_2d, font_size,
                color_orange_red(255))
        end

        -- Draw closest cursor target
        if closest_cursor_target and closest_cursor_target:is_enemy() then
            local closest_cursor_target_position = closest_cursor_target:get_position();
            local closest_cursor_target_position_2d = graphics.w2s(closest_cursor_target_position);
            graphics.circle_3d(closest_cursor_target_position, 0.40, color_green_pastel(255), 2.0, 5);
            local text_position = vec2:new(closest_cursor_target_position_2d.x,
                closest_cursor_target_position_2d.y + y_offset)
            graphics.text_2d("CLOSEST_CURSOR_TARGET - Angle:" .. string.format("%.1f", closest_cursor_target_angle),
                text_position, font_size,
                color_green_pastel(255))
        end
    end
end);

console.print("Lua Plugin - Druid: Dirty Zewx Salad Edition - v1.0.0")
