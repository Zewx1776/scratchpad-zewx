local my_utility = require("my_utility/my_utility")
local spell_data = require("my_utility/spell_data")

local menu_elements =
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_debilitating_roar")),
    
    -- Enhanced buff management with restrictions
    buff_management_mode  = checkbox:new(true, get_hash(my_utility.plugin_label .. "debilitating_roar_buff_management")),
    buff_refresh_threshold = slider_float:new(0.1, 5.0, 1.0, get_hash(my_utility.plugin_label .. "debilitating_roar_buff_threshold")),
    min_enemies_for_buff  = slider_int:new(0, 10, 2, get_hash(my_utility.plugin_label .. "debilitating_roar_min_enemies")),
    cast_cooldown         = slider_float:new(5.0, 20.0, 12.0, get_hash(my_utility.plugin_label .. "debilitating_roar_cast_cooldown")),
    
    -- Original defensive/offensive options
    hp_usage_shield       = slider_float:new(0.0, 1.0, 0.80,
        get_hash(my_utility.plugin_label .. "%_debilitating_roar_hp_usage")),
    use_offensively       = checkbox:new(false, get_hash(my_utility.plugin_label .. "use_offensively_debilitating_roar")),
    filter_mode           = combo_box:new(1, get_hash(my_utility.plugin_label .. "offensive_filter_debilitating_roar")),
    enemy_count_threshold = slider_int:new(0, 30, 5, get_hash(my_utility.plugin_label .. "min_enemy_count_debilitating_roar")),
    evaluation_range      = slider_int:new(1, 16, 6,
        get_hash(my_utility.plugin_label .. "evaluation_range_debilitating_roar")),
    
    -- Debug options
    debug_buffs           = checkbox:new(false, get_hash(my_utility.plugin_label .. "debilitating_roar_debug_buffs"))
}

local function menu()
    if menu_elements.tree_tab:push("Debilitating Roar") then
        menu_elements.main_boolean:render("Enable Spell", "")

        if menu_elements.main_boolean:get() then
            menu_elements.buff_management_mode:render("Buff Management Mode", 
                "Cast Debilitating Roar ONLY to maintain damage/survivability buffs (restrictive)")
            
            if menu_elements.buff_management_mode:get() then
                menu_elements.buff_refresh_threshold:render("Buff Refresh Threshold", 
                    "ONLY refresh when buff has this many seconds left (LOW = less casting)", 1)
                menu_elements.min_enemies_for_buff:render("Min Enemies for Buff Cast", 
                    "Only cast for buff if this many enemies are nearby")
                menu_elements.cast_cooldown:render("Debilitating Roar Cooldown", 
                    "Minimum time between casts (prevents spam)", 1)
                menu_elements.debug_buffs:render("Debug Buff Status", 
                    "Print debug information about Debilitating Roar buff status")
            else
                -- Original defensive/offensive mode options
                menu_elements.hp_usage_shield:render("Min cast HP Percent", "", 1)
                menu_elements.use_offensively:render("Use Offensively", "")

                if menu_elements.use_offensively:get() then
                    menu_elements.evaluation_range:render("Evaluation Range", my_utility.evaluation_range_description)
                    menu_elements.filter_mode:render("Filter Modes", my_utility.activation_filters, "")
                    menu_elements.enemy_count_threshold:render("Minimum Enemy Count",
                        "       Minimum number of enemies in Evaluation Range for spell activation")
                end
            end
        end

        menu_elements.tree_tab:pop()
    end
end

local next_time_allowed_cast = 0.0
local last_successful_cast_time = 0.0

-- Function to check Debilitating Roar buff status
local function check_debilitating_roar_buff()
    local local_player = get_local_player()
    if not local_player then return false, 0 end
    
    local buffs = local_player:get_buffs()
    if not buffs then return false, 0 end
    
    for _, buff in ipairs(buffs) do
        if buff.name_hash == spell_data.debilitating_roar.spell_id then
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

local function logics()
    local menu_boolean = menu_elements.main_boolean:get()
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean,
        next_time_allowed_cast,
        spell_data.debilitating_roar.spell_id)

    if not is_logic_allowed then return false end

    local current_time = get_time_since_inject()

    -- Enhanced buff management mode with STRICT restrictions
    if menu_elements.buff_management_mode:get() then
        local cast_cooldown = menu_elements.cast_cooldown:get()
        
        -- Enforce minimum cooldown between casts (prevents spam)
        if current_time - last_successful_cast_time < cast_cooldown then
            if menu_elements.debug_buffs:get() then
                local remaining_cooldown = cast_cooldown - (current_time - last_successful_cast_time)
                console.print("Debilitating Roar Debug - On cooldown for " .. string.format("%.1f", remaining_cooldown) .. "s more")
            end
            return false
        end
        
        -- Check enemy requirement
        local min_enemies = menu_elements.min_enemies_for_buff:get()
        if not check_enemy_count(min_enemies) then
            if menu_elements.debug_buffs:get() then
                console.print("Debilitating Roar Debug - Not enough enemies for buff cast")
            end
            return false
        end
        
        local has_buff, remaining_time = check_debilitating_roar_buff()
        local refresh_threshold = menu_elements.buff_refresh_threshold:get()
        
        -- Debug output
        if menu_elements.debug_buffs:get() then
            console.print("Debilitating Roar Debug - Buff active: " .. tostring(has_buff) .. 
                ", Remaining: " .. string.format("%.1f", remaining_time) .. 
                "s, Threshold: " .. string.format("%.1f", refresh_threshold) .. "s")
        end
        
        -- ONLY cast if buff is missing OR has very little time left
        if not has_buff or remaining_time <= refresh_threshold then
            if cast_spell.self(spell_data.debilitating_roar.spell_id, 0) then
                next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast
                last_successful_cast_time = current_time
                console.print("Cast Debilitating Roar - Buff Management - Damage/Survivability refresh (was: " .. 
                    string.format("%.1f", remaining_time) .. "s remaining)")
                return true
            end
        else
            -- Buff is still active and not expiring soon - DON'T CAST
            if menu_elements.debug_buffs:get() then
                console.print("Debilitating Roar Debug - Buff still active, skipping cast")
            end
            return false
        end
    else
        -- Original defensive/offensive logic
        local menu_min_percentage = menu_elements.hp_usage_shield:get()
        if menu_min_percentage < 1 then
            local local_player = get_local_player()
            local player_current_health = local_player:get_current_health()
            local player_max_health = local_player:get_max_health()
            local health_percent = player_current_health / player_max_health

            if health_percent <= menu_min_percentage then
                if cast_spell.self(spell_data.debilitating_roar.spell_id, 0) then
                    next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast
                    last_successful_cast_time = current_time
                    console.print("Cast Debilitating Roar - Defensive - " .. string.format("%.1f", health_percent))
                    return true
                end
            end
        end

        -- Checking for offensive use
        local use_offensively = menu_elements.use_offensively:get()
        if use_offensively then
            local filter_mode = menu_elements.filter_mode:get()
            local evaluation_range = menu_elements.evaluation_range:get()
            local all_units_count, _, elite_units_count, champion_units_count, boss_units_count = my_utility
                .enemy_count_in_range(evaluation_range)

            if (filter_mode == 1 and (elite_units_count >= 1 or champion_units_count >= 1 or boss_units_count >= 1))
                or (filter_mode == 2 and boss_units_count >= 1)
                or (all_units_count >= menu_elements.enemy_count_threshold:get())
            then
                if cast_spell.self(spell_data.debilitating_roar.spell_id, 0) then
                    next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast
                    last_successful_cast_time = current_time
                    console.print("Cast Debilitating Roar - Offensive - " .. my_utility.activation_filters[filter_mode + 1])
                    return true
                end
            end
        end
    end

    return false
end

return
{
    menu = menu,
    logics = logics,
    menu_elements = menu_elements
}