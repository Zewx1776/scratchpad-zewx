local my_utility = require("my_utility/my_utility")
local spell_data = require("my_utility/spell_data")

local menu_elements_pulverize =
{
    tree_tab                    = tree_node:new(1),
    main_boolean                = checkbox:new(true, get_hash(my_utility.plugin_label .. "pulverize_base_main_bool")),
    targeting_mode              = combo_box:new(3, get_hash(my_utility.plugin_label .. "pulverize_base_targeting_mode")),
    
    -- Enhanced spam options
    enable_spam_mode            = checkbox:new(true, get_hash(my_utility.plugin_label .. "pulverize_enable_spam_mode")),
    
    -- Elite/Champion/Boss auto-spam
    auto_spam_priority_targets  = checkbox:new(true, get_hash(my_utility.plugin_label .. "pulverize_auto_spam_priority")),
    
    -- 10 Groups of enemy-count-based settings
    -- Group 1
    group1_min_enemies          = slider_int:new(1, 20, 1, get_hash(my_utility.plugin_label .. "pulverize_g1_min_enemies")),
    group1_movement_distance    = slider_float:new(0.5, 6.0, 3.0, get_hash(my_utility.plugin_label .. "pulverize_g1_mov_dist")),
    group1_movement_frequency   = slider_float:new(0.1, 5.0, 2.0, get_hash(my_utility.plugin_label .. "pulverize_g1_mov_freq")),
    group1_pulverize_frequency  = slider_float:new(0.05, 1.0, 0.1, get_hash(my_utility.plugin_label .. "pulverize_g1_cast_freq")),
    
    -- Group 2
    group2_min_enemies          = slider_int:new(1, 20, 2, get_hash(my_utility.plugin_label .. "pulverize_g2_min_enemies")),
    group2_movement_distance    = slider_float:new(0.5, 6.0, 2.8, get_hash(my_utility.plugin_label .. "pulverize_g2_mov_dist")),
    group2_movement_frequency   = slider_float:new(0.1, 5.0, 1.8, get_hash(my_utility.plugin_label .. "pulverize_g2_mov_freq")),
    group2_pulverize_frequency  = slider_float:new(0.05, 1.0, 0.1, get_hash(my_utility.plugin_label .. "pulverize_g2_cast_freq")),
    
    -- Group 3
    group3_min_enemies          = slider_int:new(1, 20, 3, get_hash(my_utility.plugin_label .. "pulverize_g3_min_enemies")),
    group3_movement_distance    = slider_float:new(0.5, 6.0, 2.6, get_hash(my_utility.plugin_label .. "pulverize_g3_mov_dist")),
    group3_movement_frequency   = slider_float:new(0.1, 5.0, 1.6, get_hash(my_utility.plugin_label .. "pulverize_g3_mov_freq")),
    group3_pulverize_frequency  = slider_float:new(0.05, 1.0, 0.08, get_hash(my_utility.plugin_label .. "pulverize_g3_cast_freq")),
    
    -- Group 4
    group4_min_enemies          = slider_int:new(1, 20, 4, get_hash(my_utility.plugin_label .. "pulverize_g4_min_enemies")),
    group4_movement_distance    = slider_float:new(0.5, 6.0, 2.4, get_hash(my_utility.plugin_label .. "pulverize_g4_mov_dist")),
    group4_movement_frequency   = slider_float:new(0.1, 5.0, 1.4, get_hash(my_utility.plugin_label .. "pulverize_g4_mov_freq")),
    group4_pulverize_frequency  = slider_float:new(0.05, 1.0, 0.08, get_hash(my_utility.plugin_label .. "pulverize_g4_cast_freq")),
    
    -- Group 5
    group5_min_enemies          = slider_int:new(1, 20, 5, get_hash(my_utility.plugin_label .. "pulverize_g5_min_enemies")),
    group5_movement_distance    = slider_float:new(0.5, 6.0, 2.2, get_hash(my_utility.plugin_label .. "pulverize_g5_mov_dist")),
    group5_movement_frequency   = slider_float:new(0.1, 5.0, 1.2, get_hash(my_utility.plugin_label .. "pulverize_g5_mov_freq")),
    group5_pulverize_frequency  = slider_float:new(0.05, 1.0, 0.06, get_hash(my_utility.plugin_label .. "pulverize_g5_cast_freq")),
    
    -- Group 6
    group6_min_enemies          = slider_int:new(1, 20, 6, get_hash(my_utility.plugin_label .. "pulverize_g6_min_enemies")),
    group6_movement_distance    = slider_float:new(0.5, 6.0, 2.0, get_hash(my_utility.plugin_label .. "pulverize_g6_mov_dist")),
    group6_movement_frequency   = slider_float:new(0.1, 5.0, 1.0, get_hash(my_utility.plugin_label .. "pulverize_g6_mov_freq")),
    group6_pulverize_frequency  = slider_float:new(0.05, 1.0, 0.06, get_hash(my_utility.plugin_label .. "pulverize_g6_cast_freq")),
    
    -- Group 7
    group7_min_enemies          = slider_int:new(1, 20, 8, get_hash(my_utility.plugin_label .. "pulverize_g7_min_enemies")),
    group7_movement_distance    = slider_float:new(0.5, 6.0, 1.8, get_hash(my_utility.plugin_label .. "pulverize_g7_mov_dist")),
    group7_movement_frequency   = slider_float:new(0.1, 5.0, 0.8, get_hash(my_utility.plugin_label .. "pulverize_g7_mov_freq")),
    group7_pulverize_frequency  = slider_float:new(0.05, 1.0, 0.05, get_hash(my_utility.plugin_label .. "pulverize_g7_cast_freq")),
    
    -- Group 8
    group8_min_enemies          = slider_int:new(1, 20, 10, get_hash(my_utility.plugin_label .. "pulverize_g8_min_enemies")),
    group8_movement_distance    = slider_float:new(0.5, 6.0, 1.6, get_hash(my_utility.plugin_label .. "pulverize_g8_mov_dist")),
    group8_movement_frequency   = slider_float:new(0.1, 5.0, 0.6, get_hash(my_utility.plugin_label .. "pulverize_g8_mov_freq")),
    group8_pulverize_frequency  = slider_float:new(0.05, 1.0, 0.05, get_hash(my_utility.plugin_label .. "pulverize_g8_cast_freq")),
    
    -- Group 9
    group9_min_enemies          = slider_int:new(1, 20, 12, get_hash(my_utility.plugin_label .. "pulverize_g9_min_enemies")),
    group9_movement_distance    = slider_float:new(0.5, 6.0, 1.4, get_hash(my_utility.plugin_label .. "pulverize_g9_mov_dist")),
    group9_movement_frequency   = slider_float:new(0.1, 5.0, 0.4, get_hash(my_utility.plugin_label .. "pulverize_g9_mov_freq")),
    group9_pulverize_frequency  = slider_float:new(0.05, 1.0, 0.04, get_hash(my_utility.plugin_label .. "pulverize_g9_cast_freq")),
    
    -- Group 10
    group10_min_enemies         = slider_int:new(1, 20, 15, get_hash(my_utility.plugin_label .. "pulverize_g10_min_enemies")),
    group10_movement_distance   = slider_float:new(0.5, 6.0, 1.2, get_hash(my_utility.plugin_label .. "pulverize_g10_mov_dist")),
    group10_movement_frequency  = slider_float:new(0.1, 5.0, 0.3, get_hash(my_utility.plugin_label .. "pulverize_g10_mov_freq")),
    group10_pulverize_frequency = slider_float:new(0.05, 1.0, 0.03, get_hash(my_utility.plugin_label .. "pulverize_g10_cast_freq")),
    
    -- Global settings
    detection_range             = slider_float:new(5.0, 25.0, 15.0, get_hash(my_utility.plugin_label .. "pulverize_detection_range")),
    movement_enabled            = checkbox:new(true, get_hash(my_utility.plugin_label .. "pulverize_movement_enabled")),
    cast_after_movement         = checkbox:new(true, get_hash(my_utility.plugin_label .. "pulverize_cast_after_move")),
    aggressive_positioning      = checkbox:new(true, get_hash(my_utility.plugin_label .. "pulverize_aggressive_pos")),
    
    -- Debug
    debug_spam                  = checkbox:new(false, get_hash(my_utility.plugin_label .. "pulverize_debug_spam")),
}

local function menu()
    if menu_elements_pulverize.tree_tab:push("Pulverize") then
        menu_elements_pulverize.main_boolean:render("Enable Spell", "")

        if menu_elements_pulverize.main_boolean:get() then
            menu_elements_pulverize.targeting_mode:render("Targeting Mode", my_utility.targeting_modes,
                my_utility.targeting_mode_description)
            
            menu_elements_pulverize.enable_spam_mode:render("Enable Dynamic Pulverize Mode", 
                "Automatically adjust behavior based on enemy count with custom settings per group")
            
            if menu_elements_pulverize.enable_spam_mode:get() then
                menu_elements_pulverize.auto_spam_priority_targets:render("Auto-Spam Priority Targets", 
                    "Automatically spam Pulverize when Elites, Champions, or Bosses are present")
                
                menu_elements_pulverize.detection_range:render("Enemy Detection Range", 
                    "Range to detect enemies for all calculations", 1)
                
                -- Group settings organized in sub-menus
                if menu_elements_pulverize.tree_tab:push("Enemy Count Groups (1-5)") then
                    if menu_elements_pulverize.tree_tab:push("Group 1 (Few Enemies)") then
                        menu_elements_pulverize.group1_min_enemies:render("Min Enemies", "Minimum enemies to activate this group")
                        menu_elements_pulverize.group1_movement_distance:render("Movement Distance", "Distance to move per repositioning", 1)
                        menu_elements_pulverize.group1_movement_frequency:render("Movement Frequency", "Time between movements (seconds)", 1)
                        menu_elements_pulverize.group1_pulverize_frequency:render("Pulverize Frequency", "Time between casts (seconds)", 1)
                        menu_elements_pulverize.tree_tab:pop()
                    end
                    
                    if menu_elements_pulverize.tree_tab:push("Group 2") then
                        menu_elements_pulverize.group2_min_enemies:render("Min Enemies", "Minimum enemies to activate this group")
                        menu_elements_pulverize.group2_movement_distance:render("Movement Distance", "Distance to move per repositioning", 1)
                        menu_elements_pulverize.group2_movement_frequency:render("Movement Frequency", "Time between movements (seconds)", 1)
                        menu_elements_pulverize.group2_pulverize_frequency:render("Pulverize Frequency", "Time between casts (seconds)", 1)
                        menu_elements_pulverize.tree_tab:pop()
                    end
                    
                    if menu_elements_pulverize.tree_tab:push("Group 3") then
                        menu_elements_pulverize.group3_min_enemies:render("Min Enemies", "Minimum enemies to activate this group")
                        menu_elements_pulverize.group3_movement_distance:render("Movement Distance", "Distance to move per repositioning", 1)
                        menu_elements_pulverize.group3_movement_frequency:render("Movement Frequency", "Time between movements (seconds)", 1)
                        menu_elements_pulverize.group3_pulverize_frequency:render("Pulverize Frequency", "Time between casts (seconds)", 1)
                        menu_elements_pulverize.tree_tab:pop()
                    end
                    
                    if menu_elements_pulverize.tree_tab:push("Group 4") then
                        menu_elements_pulverize.group4_min_enemies:render("Min Enemies", "Minimum enemies to activate this group")
                        menu_elements_pulverize.group4_movement_distance:render("Movement Distance", "Distance to move per repositioning", 1)
                        menu_elements_pulverize.group4_movement_frequency:render("Movement Frequency", "Time between movements (seconds)", 1)
                        menu_elements_pulverize.group4_pulverize_frequency:render("Pulverize Frequency", "Time between casts (seconds)", 1)
                        menu_elements_pulverize.tree_tab:pop()
                    end
                    
                    if menu_elements_pulverize.tree_tab:push("Group 5") then
                        menu_elements_pulverize.group5_min_enemies:render("Min Enemies", "Minimum enemies to activate this group")
                        menu_elements_pulverize.group5_movement_distance:render("Movement Distance", "Distance to move per repositioning", 1)
                        menu_elements_pulverize.group5_movement_frequency:render("Movement Frequency", "Time between movements (seconds)", 1)
                        menu_elements_pulverize.group5_pulverize_frequency:render("Pulverize Frequency", "Time between casts (seconds)", 1)
                        menu_elements_pulverize.tree_tab:pop()
                    end
                    
                    menu_elements_pulverize.tree_tab:pop()
                end
                
                if menu_elements_pulverize.tree_tab:push("Enemy Count Groups (6-10)") then
                    if menu_elements_pulverize.tree_tab:push("Group 6") then
                        menu_elements_pulverize.group6_min_enemies:render("Min Enemies", "Minimum enemies to activate this group")
                        menu_elements_pulverize.group6_movement_distance:render("Movement Distance", "Distance to move per repositioning", 1)
                        menu_elements_pulverize.group6_movement_frequency:render("Movement Frequency", "Time between movements (seconds)", 1)
                        menu_elements_pulverize.group6_pulverize_frequency:render("Pulverize Frequency", "Time between casts (seconds)", 1)
                        menu_elements_pulverize.tree_tab:pop()
                    end
                    
                    if menu_elements_pulverize.tree_tab:push("Group 7") then
                        menu_elements_pulverize.group7_min_enemies:render("Min Enemies", "Minimum enemies to activate this group")
                        menu_elements_pulverize.group7_movement_distance:render("Movement Distance", "Distance to move per repositioning", 1)
                        menu_elements_pulverize.group7_movement_frequency:render("Movement Frequency", "Time between movements (seconds)", 1)
                        menu_elements_pulverize.group7_pulverize_frequency:render("Pulverize Frequency", "Time between casts (seconds)", 1)
                        menu_elements_pulverize.tree_tab:pop()
                    end
                    
                    if menu_elements_pulverize.tree_tab:push("Group 8") then
                        menu_elements_pulverize.group8_min_enemies:render("Min Enemies", "Minimum enemies to activate this group")
                        menu_elements_pulverize.group8_movement_distance:render("Movement Distance", "Distance to move per repositioning", 1)
                        menu_elements_pulverize.group8_movement_frequency:render("Movement Frequency", "Time between movements (seconds)", 1)
                        menu_elements_pulverize.group8_pulverize_frequency:render("Pulverize Frequency", "Time between casts (seconds)", 1)
                        menu_elements_pulverize.tree_tab:pop()
                    end
                    
                    if menu_elements_pulverize.tree_tab:push("Group 9") then
                        menu_elements_pulverize.group9_min_enemies:render("Min Enemies", "Minimum enemies to activate this group")
                        menu_elements_pulverize.group9_movement_distance:render("Movement Distance", "Distance to move per repositioning", 1)
                        menu_elements_pulverize.group9_movement_frequency:render("Movement Frequency", "Time between movements (seconds)", 1)
                        menu_elements_pulverize.group9_pulverize_frequency:render("Pulverize Frequency", "Time between casts (seconds)", 1)
                        menu_elements_pulverize.tree_tab:pop()
                    end
                    
                    if menu_elements_pulverize.tree_tab:push("Group 10 (Many Enemies)") then
                        menu_elements_pulverize.group10_min_enemies:render("Min Enemies", "Minimum enemies to activate this group")
                        menu_elements_pulverize.group10_movement_distance:render("Movement Distance", "Distance to move per repositioning", 1)
                        menu_elements_pulverize.group10_movement_frequency:render("Movement Frequency", "Time between movements (seconds)", 1)
                        menu_elements_pulverize.group10_pulverize_frequency:render("Pulverize Frequency", "Time between casts (seconds)", 1)
                        menu_elements_pulverize.tree_tab:pop()
                    end
                    
                    menu_elements_pulverize.tree_tab:pop()
                end
                
                if menu_elements_pulverize.tree_tab:push("Movement Settings") then
                    menu_elements_pulverize.movement_enabled:render("Enable Movement", 
                        "Enable automatic movement between casts")
                    menu_elements_pulverize.cast_after_movement:render("Cast After Movement", 
                        "Always cast Pulverize after each movement")
                    menu_elements_pulverize.aggressive_positioning:render("Aggressive Positioning", 
                        "Move directly into enemy clusters for maximum damage")
                    menu_elements_pulverize.tree_tab:pop()
                end
                
                menu_elements_pulverize.debug_spam:render("Debug Dynamic Mode", 
                    "Show debug info for group selection and behavior adaptation")
            end
        end

        menu_elements_pulverize.tree_tab:pop()
    end
end

local next_time_allowed_cast = 0.0
local next_time_allowed_move = 0.0
local last_cast_position = nil
local last_movement_time = 0.0
local movement_count = 0

-- Get the appropriate group settings based on enemy count
local function get_group_settings_for_enemy_count(enemy_count)
    local groups = {
        {menu_elements_pulverize.group1_min_enemies:get(), menu_elements_pulverize.group1_movement_distance:get(), 
         menu_elements_pulverize.group1_movement_frequency:get(), menu_elements_pulverize.group1_pulverize_frequency:get(), "Group 1"},
        {menu_elements_pulverize.group2_min_enemies:get(), menu_elements_pulverize.group2_movement_distance:get(), 
         menu_elements_pulverize.group2_movement_frequency:get(), menu_elements_pulverize.group2_pulverize_frequency:get(), "Group 2"},
        {menu_elements_pulverize.group3_min_enemies:get(), menu_elements_pulverize.group3_movement_distance:get(), 
         menu_elements_pulverize.group3_movement_frequency:get(), menu_elements_pulverize.group3_pulverize_frequency:get(), "Group 3"},
        {menu_elements_pulverize.group4_min_enemies:get(), menu_elements_pulverize.group4_movement_distance:get(), 
         menu_elements_pulverize.group4_movement_frequency:get(), menu_elements_pulverize.group4_pulverize_frequency:get(), "Group 4"},
        {menu_elements_pulverize.group5_min_enemies:get(), menu_elements_pulverize.group5_movement_distance:get(), 
         menu_elements_pulverize.group5_movement_frequency:get(), menu_elements_pulverize.group5_pulverize_frequency:get(), "Group 5"},
        {menu_elements_pulverize.group6_min_enemies:get(), menu_elements_pulverize.group6_movement_distance:get(), 
         menu_elements_pulverize.group6_movement_frequency:get(), menu_elements_pulverize.group6_pulverize_frequency:get(), "Group 6"},
        {menu_elements_pulverize.group7_min_enemies:get(), menu_elements_pulverize.group7_movement_distance:get(), 
         menu_elements_pulverize.group7_movement_frequency:get(), menu_elements_pulverize.group7_pulverize_frequency:get(), "Group 7"},
        {menu_elements_pulverize.group8_min_enemies:get(), menu_elements_pulverize.group8_movement_distance:get(), 
         menu_elements_pulverize.group8_movement_frequency:get(), menu_elements_pulverize.group8_pulverize_frequency:get(), "Group 8"},
        {menu_elements_pulverize.group9_min_enemies:get(), menu_elements_pulverize.group9_movement_distance:get(), 
         menu_elements_pulverize.group9_movement_frequency:get(), menu_elements_pulverize.group9_pulverize_frequency:get(), "Group 9"},
        {menu_elements_pulverize.group10_min_enemies:get(), menu_elements_pulverize.group10_movement_distance:get(), 
         menu_elements_pulverize.group10_movement_frequency:get(), menu_elements_pulverize.group10_pulverize_frequency:get(), "Group 10"}
    }
    
    -- Find the highest matching group (highest min_enemies that is <= enemy_count)
    local selected_group = groups[1] -- Default to group 1
    for _, group in ipairs(groups) do
        local min_enemies, movement_distance, movement_frequency, pulverize_frequency, group_name = group[1], group[2], group[3], group[4], group[5]
        if enemy_count >= min_enemies then
            selected_group = group
        end
    end
    
    return selected_group[1], selected_group[2], selected_group[3], selected_group[4], selected_group[5]
end

-- Enhanced function to find enemy cluster center with priority target detection
local function find_enemy_cluster_center(player_position, detection_range)
    local enemies = target_selector.get_near_target_list(player_position, detection_range)
    local valid_enemies = {}
    local has_elite = false
    local has_champion = false
    local has_boss = false
    
    for _, enemy in ipairs(enemies) do
        if enemy:is_enemy() and not enemy:is_untargetable() and not enemy:is_immune() then
            table.insert(valid_enemies, enemy)
            
            -- Check for priority targets
            if enemy:is_boss() then
                has_boss = true
            elseif enemy:is_champion() then
                has_champion = true
            elseif enemy:is_elite() then
                has_elite = true
            end
        end
    end
    
    if #valid_enemies == 0 then
        return nil, 0, false, false, false
    end
    
    -- Calculate center of mass for all enemies
    local total_x, total_y, total_z = 0, 0, 0
    local total_weight = 0
    
    for _, enemy in ipairs(valid_enemies) do
        local pos = enemy:get_position()
        local weight = 1
        
        -- Give more weight to elite/boss enemies
        if enemy:is_boss() then
            weight = 10
        elseif enemy:is_champion() then
            weight = 5
        elseif enemy:is_elite() then
            weight = 3
        end
        
        total_x = total_x + (pos:x() * weight)
        total_y = total_y + (pos:y() * weight)
        total_z = total_z + (pos:z() * weight)
        total_weight = total_weight + weight
    end
    
    local center = vec3:new(
        total_x / total_weight,
        total_y / total_weight,
        total_z / total_weight
    )
    
    return center, #valid_enemies, has_elite, has_champion, has_boss
end

-- Aggressive movement toward enemy clusters
local function do_aggressive_movement(player_position, target_position, movement_distance)
    if not target_position then return false end
    
    local direction = target_position - player_position
    local distance_to_target = direction:length()
    
    if distance_to_target < 1.5 then
        -- Already very close, make small circular movement to gather enemies
        local angle = (movement_count * 45) % 360 -- Rotate 45 degrees each time
        local rad = math.rad(angle)
        local move_x = math.cos(rad) * movement_distance
        local move_y = math.sin(rad) * movement_distance
        local move_position = player_position + vec3:new(move_x, move_y, 0)
        
        pathfinder.force_move_raw(move_position)
        movement_count = movement_count + 1
        return true
    else
        -- Move toward enemy cluster center
        direction = direction:normalize()
        local move_position = player_position + (direction * movement_distance)
        
        pathfinder.force_move_raw(move_position)
        return true
    end
end

local function logics(target)
    if not target then return false end
    
    local menu_boolean = menu_elements_pulverize.main_boolean:get()
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean,
        next_time_allowed_cast,
        spell_data.pulverize.spell_id)

    if not is_logic_allowed then return false end

    local player_position = get_player_position()
    local current_time = get_time_since_inject()
    local local_player = get_local_player()
    
    -- Dynamic spam mode with enemy-count-based settings
    if menu_elements_pulverize.enable_spam_mode:get() then
        local detection_range = menu_elements_pulverize.detection_range:get()
        local auto_spam_priority = menu_elements_pulverize.auto_spam_priority_targets:get()
        local movement_enabled = menu_elements_pulverize.movement_enabled:get()
        local cast_after_movement = menu_elements_pulverize.cast_after_movement:get()
        local aggressive_positioning = menu_elements_pulverize.aggressive_positioning:get()
        
        -- Find enemy cluster center and priority targets
        local cluster_center, enemy_count, has_elite, has_champion, has_boss = 
            find_enemy_cluster_center(player_position, detection_range)
        
        local has_priority_targets = has_elite or has_champion or has_boss
        
        -- Get dynamic settings based on enemy count
        local min_enemies, movement_distance, movement_frequency, pulverize_frequency, group_name = 
            get_group_settings_for_enemy_count(enemy_count)
        
        -- Debug output
        if menu_elements_pulverize.debug_spam:get() then
            console.print("Pulverize Debug - Enemies: " .. enemy_count .. 
                ", Active Group: " .. group_name .. 
                " (MinE:" .. min_enemies .. ", MovD:" .. string.format("%.1f", movement_distance) .. 
                ", MovF:" .. string.format("%.1f", movement_frequency) .. 
                ", CastF:" .. string.format("%.2f", pulverize_frequency) .. ")")
            console.print("Pulverize Debug - Priority targets: Elite=" .. tostring(has_elite) .. 
                ", Champion=" .. tostring(has_champion) .. 
                ", Boss=" .. tostring(has_boss))
        end
        
        -- Determine if we should spam
        local should_spam = false
        if cluster_center then
            -- Auto-spam for priority targets (bypasses minimum enemy requirements)
            if auto_spam_priority and has_priority_targets then
                should_spam = true
            -- Normal spam based on enemy count and group settings
            elseif enemy_count >= min_enemies then
                should_spam = true
            end
        end
        
        -- Apply dynamic pulverize frequency
        local dynamic_cast_delay = my_utility.spell_delays.regular_cast + pulverize_frequency
        
        -- CAST Pulverize if conditions are met and enough time has passed
        if should_spam and cluster_center and current_time >= next_time_allowed_cast then
            if cast_spell.position(spell_data.pulverize.spell_id, cluster_center, 0) then
                next_time_allowed_cast = current_time + dynamic_cast_delay
                last_cast_position = cluster_center
                
                local cast_reason = ""
                if auto_spam_priority and has_priority_targets then
                    cast_reason = " [PRIORITY AUTO-SPAM]"
                else
                    cast_reason = " [" .. group_name .. "]"
                end
                
                console.print("Cast Pulverize - Dynamic Mode - Enemies: " .. enemy_count .. 
                    cast_reason)
                return true
            end
        end
        
        -- Dynamic movement logic
        if movement_enabled and current_time >= next_time_allowed_move and 
           current_time - last_movement_time >= movement_frequency and cluster_center then
            
            local moved = false
            if aggressive_positioning then
                moved = do_aggressive_movement(player_position, cluster_center, movement_distance)
            else
                -- Simple movement toward cluster center
                local direction = cluster_center - player_position
                direction = direction:normalize()
                local move_position = player_position + (direction * movement_distance)
                pathfinder.force_move_raw(move_position)
                moved = true
            end
            
            if moved then
                next_time_allowed_move = current_time + 0.1  -- Short movement cooldown
                last_movement_time = current_time
                
                if menu_elements_pulverize.debug_spam:get() then
                    console.print("Pulverize Debug - Moving with " .. group_name .. " settings (dist: " .. 
                        string.format("%.1f", movement_distance) .. ", freq: " .. 
                        string.format("%.1f", movement_frequency) .. ")")
                end
                
                -- Try to cast immediately after movement if enabled
                if cast_after_movement and cluster_center and should_spam and current_time >= next_time_allowed_cast then
                    if cast_spell.position(spell_data.pulverize.spell_id, cluster_center, 0) then
                        next_time_allowed_cast = current_time + dynamic_cast_delay
                        console.print("Cast Pulverize - After Movement - " .. group_name)
                        return true
                    end
                end
            end
        end
        
        return false
    end

    -- Fallback to normal targeting mode
    local in_range = my_utility.is_in_range(target, my_utility.get_melee_range())
    if not in_range then
        local target_position = target:get_position()
        pathfinder.request_move(target_position)
        return false
    end

    if cast_spell.target(target, spell_data.pulverize.spell_id, 0, false) then
        next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast
        console.print("Cast Pulverize - Normal Mode - Target: " ..
            my_utility.targeting_modes[menu_elements_pulverize.targeting_mode:get() + 1])
        return true
    end

    return false
end

return
{
    menu = menu,
    logics = logics,
    menu_elements = menu_elements_pulverize
}