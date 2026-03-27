local my_utility = require("my_utility/my_utility")
local spell_data = require("my_utility/spell_data")

local menu_elements_claw = 
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "claw_main_bool_base")),
    targeting_mode        = combo_box:new(5, get_hash(my_utility.plugin_label .. "claw_targeting_mode")),
    
    -- Much more restrictive buff management
    buff_management_mode  = checkbox:new(true, get_hash(my_utility.plugin_label .. "claw_buff_management")),
    buff_refresh_threshold = slider_float:new(0.1, 3.0, 0.5, get_hash(my_utility.plugin_label .. "claw_buff_threshold")),
    min_enemies_for_buff  = slider_int:new(0, 10, 1, get_hash(my_utility.plugin_label .. "claw_min_enemies")),
    cast_cooldown         = slider_float:new(3.0, 15.0, 8.0, get_hash(my_utility.plugin_label .. "claw_cast_cooldown")),
    
    -- Original filler options (for when not in buff mode)
    use_as_filler_only    = checkbox:new(false, get_hash(my_utility.plugin_label .. "claw_use_as_filler_only")),
    max_spirit            = slider_int:new(1, 100, 35, get_hash(my_utility.plugin_label .. "claw_max_spirit")),
    
    -- Debug options
    debug_buffs           = checkbox:new(false, get_hash(my_utility.plugin_label .. "claw_debug_buffs"))
}

local function menu()
    if menu_elements_claw.tree_tab:push("Claw") then
        menu_elements_claw.main_boolean:render("Enable Spell", "")

        if menu_elements_claw.main_boolean:get() then
            menu_elements_claw.targeting_mode:render("Targeting Mode", my_utility.targeting_modes, 
                my_utility.targeting_mode_description)
            
            menu_elements_claw.buff_management_mode:render("Buff Management Mode", 
                "Cast Claw ONLY to maintain Heightened Senses buff (very restrictive)")
            
            if menu_elements_claw.buff_management_mode:get() then
                menu_elements_claw.buff_refresh_threshold:render("Buff Refresh Threshold", 
                    "ONLY refresh when buff has this many seconds left (VERY LOW = less casting)", 1)
                menu_elements_claw.min_enemies_for_buff:render("Min Enemies for Buff Cast", 
                    "Only cast for buff if this many enemies are nearby")
                menu_elements_claw.cast_cooldown:render("Claw Cast Cooldown", 
                    "Minimum time between Claw casts (prevents spam)", 1)
                menu_elements_claw.debug_buffs:render("Debug Buff Status", 
                    "Print debug information about Heightened Senses buff status")
            else
                menu_elements_claw.use_as_filler_only:render("Filler Only", "Prevent casting with a lot of spirit")
                if menu_elements_claw.use_as_filler_only:get() then
                    menu_elements_claw.max_spirit:render("Max Spirit", "Prevent casting with more spirit than this value")
                end
            end
        end

        menu_elements_claw.tree_tab:pop()
    end 
end

local local_player = get_local_player()
if local_player == nil then
    return
end

local next_time_allowed_cast = 0.0
local last_successful_cast_time = 0.0

-- Function to check Heightened Senses buff status
local function check_heightened_senses_buff()
    local local_player = get_local_player()
    if not local_player then return false, 0 end
    
    local buffs = local_player:get_buffs()
    if not buffs then return false, 0 end
    
    for _, buff in ipairs(buffs) do
        if buff.name_hash == spell_data.heightened_senses.spell_id then
            local remaining_time = buff:get_remaining_time()
            return true, remaining_time
        end
    end
    
    return false, 0
end

-- Check if there are enough enemies nearby
local function check_enemy_count(min_enemies)
    if min_enemies <= 0 then return true end
    
    local player_position = get_player_position()
    local nearby_enemies = target_selector.get_near_target_list(player_position, 15)
    local valid_count = 0
    
    for _, enemy in ipairs(nearby_enemies) do
        if enemy:is_enemy() and not enemy:is_untargetable() and not enemy:is_immune() then
            valid_count = valid_count + 1
        end
    end
    
    return valid_count >= min_enemies
end

local function logics(target)
    if not target then return false end
    
    local menu_boolean = menu_elements_claw.main_boolean:get()
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean, 
        next_time_allowed_cast,
        spell_data.claw.spell_id)

    if not is_logic_allowed then return false end

    local current_time = get_time_since_inject()

    -- Enhanced buff management mode with STRICT restrictions
    if menu_elements_claw.buff_management_mode:get() then
        local cast_cooldown = menu_elements_claw.cast_cooldown:get()
        
        -- Enforce minimum cooldown between casts (prevents spam)
        if current_time - last_successful_cast_time < cast_cooldown then
            if menu_elements_claw.debug_buffs:get() then
                local remaining_cooldown = cast_cooldown - (current_time - last_successful_cast_time)
                console.print("Claw Debug - On cooldown for " .. string.format("%.1f", remaining_cooldown) .. "s more")
            end
            return false
        end
        
        -- Check enemy requirement
        local min_enemies = menu_elements_claw.min_enemies_for_buff:get()
        if not check_enemy_count(min_enemies) then
            if menu_elements_claw.debug_buffs:get() then
                console.print("Claw Debug - Not enough enemies for buff cast")
            end
            return false
        end
        
        local has_heightened_senses, remaining_time = check_heightened_senses_buff()
        local refresh_threshold = menu_elements_claw.buff_refresh_threshold:get()
        
        -- Debug output
        if menu_elements_claw.debug_buffs:get() then
            console.print("Claw Debug - Heightened Senses active: " .. tostring(has_heightened_senses) .. 
                ", Remaining: " .. string.format("%.1f", remaining_time) .. 
                "s, Threshold: " .. string.format("%.1f", refresh_threshold) .. "s")
        end
        
        -- ONLY cast if buff is missing OR has very little time left
        if not has_heightened_senses or remaining_time <= refresh_threshold then
            if cast_spell.target(target, spell_data.claw.spell_id, 0, false) then
                next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast
                last_successful_cast_time = current_time

                console.print("Cast Claw - Buff Management - Heightened Senses refresh (was: " .. 
                    string.format("%.1f", remaining_time) .. "s remaining)")
                return true
            end
        else
            -- Buff is still active and not expiring soon - DON'T CAST
            if menu_elements_claw.debug_buffs:get() then
                console.print("Claw Debug - Heightened Senses still active, skipping cast")
            end
            return false
        end
    else
        -- Original filler logic (very restrictive)
        local is_filler_enabled = menu_elements_claw.use_as_filler_only:get()
        if is_filler_enabled then
            local player_local = get_local_player()
            local current_resource_ws = player_local:get_primary_resource_current()
            local max_spirit = menu_elements_claw.max_spirit:get()
            local low_in_spirit = current_resource_ws < max_spirit

            if not low_in_spirit then
                return false
            end
        end

        if cast_spell.target(target, spell_data.claw.spell_id, 0, false) then
            next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast
            last_successful_cast_time = current_time

            console.print("Cast Claw - Filler Mode - Target: " .. 
                my_utility.targeting_modes[menu_elements_claw.targeting_mode:get() + 1])
            return true
        end
    end

    return false
end

return 
{
    menu = menu,
    logics = logics,
    menu_elements = menu_elements_claw
}