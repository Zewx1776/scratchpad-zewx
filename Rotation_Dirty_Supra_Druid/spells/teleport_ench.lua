local my_utility = require("my_utility/my_utility")

local menu_elements_teleport_ench =
{
    tree_tab            = tree_node:new(1),
    main_boolean        = checkbox:new(true, get_hash(my_utility.plugin_label .. "base_teleport_ench_base_main_bool")),
    debug_mode          = checkbox:new(false, get_hash(my_utility.plugin_label .. "teleport_ench_debug_mode")),
    cast_on_self        = checkbox:new(false, get_hash(my_utility.plugin_label .. "base_teleport_ench_cast_on_self_bool")),
    short_range_tp      = checkbox:new(false, get_hash(my_utility.plugin_label .. "base_teleport_ench_short_range_tp_bool")),
    priority_target     = checkbox:new(false, get_hash(my_utility.plugin_label .. "base_teleport_ench_priority_target_bool")),
    cast_at_cursor      = checkbox:new(false, get_hash(my_utility.plugin_label .. "teleport_ench_cast_at_cursor")),
    use_custom_cooldown = checkbox:new(false, get_hash(my_utility.plugin_label .. "teleport_ench_use_custom_cooldown")),
    internal_cooldown   = slider_float:new(0.1, 1.0, 0.5, get_hash(my_utility.plugin_label .. "teleport_ench_internal_cooldown")),
}

local function menu()
    
    if menu_elements_teleport_ench.tree_tab:push("teleport_ench") then
        menu_elements_teleport_ench.main_boolean:render("Enable Spell", "")
        menu_elements_teleport_ench.debug_mode:render("Debug Mode", "Enable debug logging for troubleshooting")
        
        if menu_elements_teleport_ench.main_boolean:get() then
            -- Track previous states before rendering
            local prev_self = menu_elements_teleport_ench.cast_on_self:get()
            local prev_priority = menu_elements_teleport_ench.priority_target:get()
            local prev_cursor = menu_elements_teleport_ench.cast_at_cursor:get()
            
            -- Render the checkboxes
            local self_clicked = menu_elements_teleport_ench.cast_on_self:render("Cast on Self", "Casts Teleport at where you stand")
            local priority_clicked = menu_elements_teleport_ench.priority_target:render("Cast on Priority Target (Ignore weighted targeting)", "Targets Boss > Champion > Elite > Any")
            local cursor_clicked = menu_elements_teleport_ench.cast_at_cursor:render("Cast at Cursor Position", "Casts Teleport at cursor position for fast dungeon navigation")
            
            -- Get current states after rendering
            local curr_self = menu_elements_teleport_ench.cast_on_self:get()
            local curr_priority = menu_elements_teleport_ench.priority_target:get()
            local curr_cursor = menu_elements_teleport_ench.cast_at_cursor:get()
            
            -- Check if any option was just enabled
            local self_just_enabled = not prev_self and curr_self
            local priority_just_enabled = not prev_priority and curr_priority
            local cursor_just_enabled = not prev_cursor and curr_cursor
            
            -- Handle mutual exclusivity between all three options
            if self_just_enabled then
                -- Cast on Self was just enabled, disable others
                menu_elements_teleport_ench.priority_target:set(false)
                menu_elements_teleport_ench.cast_at_cursor:set(false)
            elseif priority_just_enabled then
                -- Priority Target was just enabled, disable others
                menu_elements_teleport_ench.cast_on_self:set(false)
                menu_elements_teleport_ench.cast_at_cursor:set(false)
            elseif cursor_just_enabled then
                -- Cast at Cursor was just enabled, disable others
                menu_elements_teleport_ench.cast_on_self:set(false)
                menu_elements_teleport_ench.priority_target:set(false)
            end
            
            -- Additional check for when clicking directly on an already disabled option
            if self_clicked and not prev_self then
                menu_elements_teleport_ench.cast_on_self:set(true)
                menu_elements_teleport_ench.priority_target:set(false)
                menu_elements_teleport_ench.cast_at_cursor:set(false)
            elseif priority_clicked and not prev_priority then
                menu_elements_teleport_ench.priority_target:set(true)
                menu_elements_teleport_ench.cast_on_self:set(false)
                menu_elements_teleport_ench.cast_at_cursor:set(false)
            elseif cursor_clicked and not prev_cursor then
                menu_elements_teleport_ench.cast_at_cursor:set(true)
                menu_elements_teleport_ench.cast_on_self:set(false)
                menu_elements_teleport_ench.priority_target:set(false)
            end
            
            -- Final safety check to ensure only one option is enabled
            local active_count = 0
            if menu_elements_teleport_ench.cast_on_self:get() then active_count = active_count + 1 end
            if menu_elements_teleport_ench.priority_target:get() then active_count = active_count + 1 end
            if menu_elements_teleport_ench.cast_at_cursor:get() then active_count = active_count + 1 end
            
            if active_count > 1 then
                -- Multiple options enabled, keep only the most recently clicked
                if cursor_clicked then
                    menu_elements_teleport_ench.cast_on_self:set(false)
                    menu_elements_teleport_ench.priority_target:set(false)
                elseif priority_clicked then
                    menu_elements_teleport_ench.cast_on_self:set(false)
                    menu_elements_teleport_ench.cast_at_cursor:set(false)
                elseif self_clicked then
                    menu_elements_teleport_ench.priority_target:set(false)
                    menu_elements_teleport_ench.cast_at_cursor:set(false)
                end
            end
            
            menu_elements_teleport_ench.short_range_tp:render("Short Range Tele", "Stop teleport to random hill ufak")
            
            -- Custom Cooldown section
            menu_elements_teleport_ench.use_custom_cooldown:render("Use Custom Cooldown", "Enable custom internal cooldown to control casting frequency")
            if menu_elements_teleport_ench.use_custom_cooldown:get() then
                menu_elements_teleport_ench.internal_cooldown:render("Internal Cooldown (seconds)", "Time to wait between teleport_ench casts", 1)
            end
        end
        
        menu_elements_teleport_ench.tree_tab:pop()
    end
end

local spell_id_teleport_ench = 959728

local spell_data_teleport_ench = spell_data:new(
    5.0,                        -- radius
    8.0,                        -- range
    1.0,                        -- cast_delay
    0.7,                        -- projectile_speed
    false,                      -- has_collision
    spell_id_teleport_ench,     -- spell_id
    spell_geometry.circular,    -- geometry_type
    targeting_type.skillshot    -- targeting_type
)

local next_time_allowed_cast = 0.0
local_player = get_local_player()

-- Function to get the best target based on priority (Boss > Champion > Elite > Any)
local function get_priority_target(target_selector_data)
    local best_target = nil
    local target_type = "none"
    
    -- Check for boss targets first (highest priority)
    if target_selector_data and target_selector_data.has_boss then
        best_target = target_selector_data.closest_boss
        target_type = "Boss"
        return best_target, target_type
    end
    
    -- Then check for champion targets
    if target_selector_data and target_selector_data.has_champion then
        best_target = target_selector_data.closest_champion
        target_type = "Champion"
        return best_target, target_type
    end
    
    -- Then check for elite targets
    if target_selector_data and target_selector_data.has_elite then
        best_target = target_selector_data.closest_elite
        target_type = "Elite"
        return best_target, target_type
    end
    
    -- Finally, use any available target
    if target_selector_data and target_selector_data.closest_unit then
        best_target = target_selector_data.closest_unit
        target_type = "Regular"
        return best_target, target_type
    end
    
    return nil, "none"
end

local function logics(target, target_selector_data)
    local_player = get_local_player()
    local menu_boolean = menu_elements_teleport_ench.main_boolean:get()
    local debug_enabled = menu_elements_teleport_ench.debug_mode:get()
    local cast_on_self = menu_elements_teleport_ench.cast_on_self:get()
    local priority_target = menu_elements_teleport_ench.priority_target:get()
    local cast_at_cursor = menu_elements_teleport_ench.cast_at_cursor:get()
    local short_range_tp = menu_elements_teleport_ench.short_range_tp:get()

    -- Short Range Teleport Range
    if short_range_tp then
        spell_data_teleport_ench.range = 5.0
    else
        spell_data_teleport_ench.range = 8.0
    end
    
    if debug_enabled then
        console.print("[TELEPORT ENCH DEBUG] Range: " .. spell_data_teleport_ench.range .. " | Cast on self: " .. (cast_on_self and "Yes" or "No") .. " | Priority: " .. (priority_target and "Yes" or "No") .. " | Cursor: " .. (cast_at_cursor and "Yes" or "No"))
    end
    
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_teleport_ench)

    -- Check if logic is allowed first - this prevents excessive calls
    if not is_logic_allowed then
        if debug_enabled then
            console.print("[TELEPORT ENCH DEBUG] Logic not allowed - spell conditions not met")
        end
        return false, 0
    end

    local current_orb_mode = orbwalker.get_orb_mode()

    if not menu_boolean then
        if debug_enabled then
            console.print("[TELEPORT ENCH DEBUG] Spell disabled")
        end
        return false, 0
    end

    if current_orb_mode == orb_mode.none then
        if debug_enabled then
            console.print("[TELEPORT ENCH DEBUG] Orb mode is none")
        end
        return false, 0
    end

    if not local_player:is_spell_ready(spell_id_teleport_ench) then
        if debug_enabled then
            console.print("[TELEPORT ENCH DEBUG] Spell not ready")
        end
        return false, 0
    end

    -- Cast at Cursor Position (highest priority)
    if cast_at_cursor then
        local cursor_position = get_cursor_position()
        
        if debug_enabled then
            console.print("[TELEPORT ENCH DEBUG] Casting at cursor position")
        end
        
        if cursor_position then
            local player_position = get_player_position()
            
            -- Apply short range teleport setting if enabled
            if short_range_tp then
                local cursor_distance = player_position:dist_to(cursor_position)
                if cursor_distance > 5.0 then
                    -- Calculate position 5 units towards cursor
                    local direction = (cursor_position - player_position):normalize()
                    cursor_position = player_position + direction * 5.0
                    if debug_enabled then
                        console.print("[TELEPORT ENCH DEBUG] Short range mode - limiting distance to 5.0")
                    end
                end
            end
            
            if cast_spell.position(spell_id_teleport_ench, cursor_position, 0.5) then
                local current_time = get_time_since_inject()
                
                -- Use custom cooldown if enabled, otherwise use default
                local internal_cooldown_time = 0.1
                if menu_elements_teleport_ench.use_custom_cooldown:get() then
                    internal_cooldown_time = menu_elements_teleport_ench.internal_cooldown:get()
                end
                
                next_time_allowed_cast = current_time + internal_cooldown_time

                if debug_enabled then
                    console.print("[TELEPORT ENCH DEBUG] Cast at cursor successful")
                else
                    console.print("Casted Teleport Enchantment at Cursor")
                end
                return true, 0.1
            end
        else
            if debug_enabled then
                console.print("[TELEPORT ENCH DEBUG] No cursor position available")
            end
        end
    -- Cast on self mode
    elseif cast_on_self then
        if debug_enabled then
            console.print("[TELEPORT ENCH DEBUG] Casting on self")
        end
        if cast_spell.self(spell_id_teleport_ench, 0.5) then
            local current_time = get_time_since_inject()
            
            -- Use custom cooldown if enabled, otherwise use default
            local internal_cooldown_time = 0.1
            if menu_elements_teleport_ench.use_custom_cooldown:get() then
                internal_cooldown_time = menu_elements_teleport_ench.internal_cooldown:get()
            end
            
            next_time_allowed_cast = current_time + internal_cooldown_time

            if debug_enabled then
                console.print("[TELEPORT ENCH DEBUG] Cast on self successful")
            else
                console.print("Casted Teleport Enchantment on Self")
            end
            return true, 0.1
        end
    -- Priority target mode
    elseif priority_target and target_selector_data then
        local best_target, target_type = get_priority_target(target_selector_data)
        
        if debug_enabled then
            console.print("[TELEPORT ENCH DEBUG] Priority target mode - Target type: " .. target_type)
        end
        
        if best_target then
            if cast_spell.target(best_target, spell_data_teleport_ench, false) then
                local current_time = get_time_since_inject()
                
                -- Use custom cooldown if enabled, otherwise use default
                local internal_cooldown_time = 0.1
                if menu_elements_teleport_ench.use_custom_cooldown:get() then
                    internal_cooldown_time = menu_elements_teleport_ench.internal_cooldown:get()
                end
                
                next_time_allowed_cast = current_time + internal_cooldown_time

                if debug_enabled then
                    console.print("[TELEPORT ENCH DEBUG] Priority target cast successful: " .. target_type)
                else
                    console.print("Casted Teleport Enchantment on Priority Target: " .. target_type)
                end
                return true, 0.1
            end
        else
            if debug_enabled then
                console.print("[TELEPORT ENCH DEBUG] No valid priority target found")
            else
                console.print("No valid priority target found for Teleport Enchantment")
            end
        end
    -- Regular target mode (using the target passed from main.lua)
    else
        if debug_enabled then
            console.print("[TELEPORT ENCH DEBUG] Regular target mode")
        end
        if target and cast_spell.target(target, spell_data_teleport_ench, false) then
            local current_time = get_time_since_inject()
            
            -- Use custom cooldown if enabled, otherwise use default
            local internal_cooldown_time = 0.1
            if menu_elements_teleport_ench.use_custom_cooldown:get() then
                internal_cooldown_time = menu_elements_teleport_ench.internal_cooldown:get()
            end
            
            next_time_allowed_cast = current_time + internal_cooldown_time

            if debug_enabled then
                console.print("[TELEPORT ENCH DEBUG] Regular target cast successful")
            else
                console.print("Casted Teleport Enchantment on Target")
            end
            return true, 0.1
        end
    end

    if debug_enabled then
        console.print("[TELEPORT ENCH DEBUG] Cast failed or no valid conditions met")
    end
    return false, 0
end

return 
{
    menu = menu,
    logics = logics,   
    menu_elements_teleport_ench = menu_elements_teleport_ench,
}
