local my_utility = require("my_utility/my_utility")
local spell_data = require("my_utility/spell_data")

local menu_elements =
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(false, get_hash(my_utility.plugin_label .. "main_boolean_cyclone_armor")),
    
    -- Enhanced buff management
    buff_management_mode  = checkbox:new(true, get_hash(my_utility.plugin_label .. "cyclone_armor_buff_management")),
    buff_refresh_threshold = slider_float:new(1.0, 10.0, 5.0, get_hash(my_utility.plugin_label .. "cyclone_armor_buff_threshold")),
    cast_cooldown         = slider_float:new(5.0, 20.0, 15.0, get_hash(my_utility.plugin_label .. "cyclone_armor_cast_cooldown")),
    
    -- Original defensive/offensive options
    hp_usage_shield       = slider_float:new(0.0, 1.0, 0.80,
        get_hash(my_utility.plugin_label .. "%_cyclone_armor_hp_usage")),
    use_offensively       = checkbox:new(false, get_hash(my_utility.plugin_label .. "use_offensively_cyclone_armor")),
    filter_mode           = combo_box:new(1, get_hash(my_utility.plugin_label .. "offensive_filter_cyclone_armor")),
    enemy_count_threshold = slider_int:new(0, 30, 5, get_hash(my_utility.plugin_label .. "min_enemy_count_cyclone_armor")),
    evaluation_range      = slider_int:new(1, 16, 6,
        get_hash(my_utility.plugin_label .. "evaluation_range_cyclone_armor")),
    
    -- Debug options
    debug_buffs           = checkbox:new(true, get_hash(my_utility.plugin_label .. "cyclone_armor_debug_buffs"))
}

local function menu()
    if menu_elements.tree_tab:push("Cyclone Armor") then
        menu_elements.main_boolean:render("Enable Spell", "")

        if menu_elements.main_boolean:get() then
            menu_elements.buff_management_mode:render("Buff Management Mode", 
                "Cast Cyclone Armor to maintain protective buffs")
            
            if menu_elements.buff_management_mode:get() then
                menu_elements.buff_refresh_threshold:render("Buff Refresh Threshold", 
                    "Refresh when buff has this many seconds left", 1)
                menu_elements.cast_cooldown:render("Cyclone Armor Cooldown", 
                    "Minimum time between casts", 1)
                menu_elements.debug_buffs:render("Debug Buff Status", 
                    "Print debug information about Cyclone Armor buff detection")
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

-- Enhanced buff detection function with multiple methods
local function check_cyclone_armor_buff()
    local local_player = get_local_player()
    if not local_player then return false, 0 end
    
    local buffs = local_player:get_buffs()
    if not buffs then return false, 0 end
    
    -- Try multiple possible buff IDs for Cyclone Armor
    local possible_cyclone_ids = {280119, 280120, 280118, 1199570, 1199571}
    
    for _, buff in ipairs(buffs) do
        for _, cyclone_id in ipairs(possible_cyclone_ids) do
            if buff.name_hash == cyclone_id then
                local remaining_time = buff:get_remaining_time()
                -- Validate the remaining time is reasonable
                if remaining_time >= 0 and remaining_time <= 300 then
                    return true, remaining_time, cyclone_id
                end
            end
        end
    end
    
    return false, 0, nil
end

-- Debug function to print all active buffs (occasionally)
local function debug_all_buffs()
    if not menu_elements.debug_buffs:get() then return end
    
    local local_player = get_local_player()
    if not local_player then return end
    
    local buffs = local_player:get_buffs()
    if not buffs then return end
    
    console.print("=== CYCLONE ARMOR: ALL ACTIVE BUFFS ===")
    for i, buff in ipairs(buffs) do
        if i <= 15 then -- Show more buffs for Cyclone Armor
            local remaining = buff:get_remaining_time()
            console.print("Buff " .. i .. ": ID=" .. buff.name_hash .. ", Remaining=" .. 
                string.format("%.1f", remaining) .. "s, Stacks=" .. buff.stacks)
        end
    end
    console.print("=====================================")
end

local function logics()
    local menu_boolean = menu_elements.main_boolean:get()
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean,
        next_time_allowed_cast,
        spell_data.cyclone_armor.spell_id)

    if not is_logic_allowed then return false end

    local current_time = get_time_since_inject()

    -- Enhanced buff management mode
    if menu_elements.buff_management_mode:get() then
        local cast_cooldown = menu_elements.cast_cooldown:get()
        
        -- Enforce minimum cooldown between casts
        if current_time - last_successful_cast_time < cast_cooldown then
            if menu_elements.debug_buffs:get() then
                local remaining_cooldown = cast_cooldown - (current_time - last_successful_cast_time)
                console.print("Cyclone Armor Debug - On cooldown for " .. string.format("%.1f", remaining_cooldown) .. "s more")
            end
            return false
        end
        
        local has_buff, remaining_time, found_id = check_cyclone_armor_buff()
        local refresh_threshold = menu_elements.buff_refresh_threshold:get()
        
        -- Debug output with enhanced information
        if menu_elements.debug_buffs:get() then
            console.print("Cyclone Armor Debug - Buff search results:")
            console.print("  Found: " .. tostring(has_buff) .. 
                ", Time: " .. string.format("%.1f", remaining_time) .. 
                "s, Threshold: " .. string.format("%.1f", refresh_threshold) .. "s")
            if found_id then
                console.print("  Found Cyclone Armor ID: " .. found_id)
            end
            
            -- Print all buffs occasionally to help identify correct ID
            if math.random(1, 30) == 1 then -- 3% chance to avoid spam
                debug_all_buffs()
            end
        end
        
        -- Cast if buff is missing or about to expire
        if not has_buff or remaining_time <= refresh_threshold then
            if cast_spell.self(spell_data.cyclone_armor.spell_id, 0) then
                next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast
                last_successful_cast_time = current_time
                console.print("Cast Cyclone Armor - Buff Management - Armor refresh (was: " .. 
                    string.format("%.1f", remaining_time) .. "s remaining)")
                return true
            end
        else
            if menu_elements.debug_buffs:get() then
                console.print("Cyclone Armor Debug - Buff still active (" .. 
                    string.format("%.1f", remaining_time) .. "s), skipping cast")
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
                if cast_spell.self(spell_data.cyclone_armor.spell_id, 0) then
                    next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast
                    last_successful_cast_time = current_time
                    console.print("Cast Cyclone Armor - Defensive - " .. string.format("%.1f", health_percent))
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
                if cast_spell.self(spell_data.cyclone_armor.spell_id, 0) then
                    next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast
                    last_successful_cast_time = current_time
                    console.print("Cast Cyclone Armor - Offensive - " .. my_utility.activation_filters[filter_mode + 1])
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