local my_utility = require("my_utility/my_utility")
local spell_data = require("my_utility/spell_data")

local menu_elements_maul = 
{
    tree_tab = tree_node:new(1),
    main_boolean = checkbox:new(true, get_hash(my_utility.plugin_label .. "maul_main_bool_base")),
    targeting_mode = combo_box:new(5, get_hash(my_utility.plugin_label .. "maul_targeting_mode")),
    
    -- Simplified buff management
    buff_management_mode = checkbox:new(true, get_hash(my_utility.plugin_label .. "maul_buff_management")),
    buff_refresh_threshold = slider_float:new(1.0, 10.0, 5.0, get_hash(my_utility.plugin_label .. "maul_buff_threshold")),
    cast_cooldown = slider_float:new(5.0, 20.0, 10.0, get_hash(my_utility.plugin_label .. "maul_cast_cooldown")),
    
    -- Original filler options
    use_as_filler_only = checkbox:new(false, get_hash(my_utility.plugin_label .. "maul_use_as_filler_only")),
    max_spirit = slider_int:new(1, 100, 35, get_hash(my_utility.plugin_label .. "maul_max_spirit")),
    
    -- Debug options
    debug_buffs = checkbox:new(true, get_hash(my_utility.plugin_label .. "maul_debug_buffs"))
}

local function menu()
    if menu_elements_maul.tree_tab:push("Maul") then
        menu_elements_maul.main_boolean:render("Enable Spell", "")

        if menu_elements_maul.main_boolean:get() then
            menu_elements_maul.targeting_mode:render("Targeting Mode", my_utility.targeting_modes, 
                my_utility.targeting_mode_description)
            
            menu_elements_maul.buff_management_mode:render("Buff Management Mode", 
                "Cast Maul to maintain Quickshift buff")
            
            if menu_elements_maul.buff_management_mode:get() then
                menu_elements_maul.buff_refresh_threshold:render("Buff Refresh Threshold", 
                    "Refresh when buff has this many seconds left", 1)
                menu_elements_maul.cast_cooldown:render("Maul Cast Cooldown", 
                    "Minimum time between Maul casts", 1)
                menu_elements_maul.debug_buffs:render("Debug Buff Status", 
                    "Print debug information about Quickshift buff detection")
            else
                menu_elements_maul.use_as_filler_only:render("Filler Only", "Prevent casting with a lot of spirit")
                if menu_elements_maul.use_as_filler_only:get() then
                    menu_elements_maul.max_spirit:render("Max Spirit", "Prevent casting with more spirit than this value")
                end
            end
        end

        menu_elements_maul.tree_tab:pop()
    end
end

local spell_id_maul = spell_data.maul.spell_id
local next_time_allowed_cast = 0.0
local last_successful_cast_time = 0.0

-- Enhanced buff detection function with multiple methods
local function check_quickshift_buff()
    local local_player = get_local_player()
    if not local_player then return false, 0 end
    
    local buffs = local_player:get_buffs()
    if not buffs then return false, 0 end
    
    -- Try multiple possible buff IDs for Quickshift
    local possible_quickshift_ids = {290969, 1199567, 1199568, 290970, 290968}
    
    for _, buff in ipairs(buffs) do
        for _, quickshift_id in ipairs(possible_quickshift_ids) do
            if buff.name_hash == quickshift_id then
                local remaining_time = buff:get_remaining_time()
                -- Validate the remaining time is reasonable
                if remaining_time >= 0 and remaining_time <= 300 then
                    return true, remaining_time, quickshift_id
                end
            end
        end
    end
    
    return false, 0, nil
end

-- Debug function to print all active buffs
local function debug_all_buffs()
    if not menu_elements_maul.debug_buffs:get() then return end
    
    local local_player = get_local_player()
    if not local_player then return end
    
    local buffs = local_player:get_buffs()
    if not buffs then return end
    
    console.print("=== ALL ACTIVE BUFFS ===")
    for i, buff in ipairs(buffs) do
        if i <= 10 then -- Limit to first 10 buffs to avoid spam
            local remaining = buff:get_remaining_time()
            console.print("Buff " .. i .. ": ID=" .. buff.name_hash .. ", Remaining=" .. 
                string.format("%.1f", remaining) .. "s, Stacks=" .. buff.stacks)
        end
    end
    console.print("========================")
end

local function logics(target)
    if not target then return false end
    
    local menu_boolean = menu_elements_maul.main_boolean:get()
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean,
        next_time_allowed_cast,
        spell_id_maul)

    if not is_logic_allowed then return false end

    local current_time = get_time_since_inject()
    
    -- Enhanced buff management mode
    if menu_elements_maul.buff_management_mode:get() then
        local cast_cooldown = menu_elements_maul.cast_cooldown:get()
        
        -- Enforce minimum cooldown between casts
        if current_time - last_successful_cast_time < cast_cooldown then
            if menu_elements_maul.debug_buffs:get() then
                local remaining_cooldown = cast_cooldown - (current_time - last_successful_cast_time)
                console.print("Maul Debug - On cooldown for " .. string.format("%.1f", remaining_cooldown) .. "s more")
            end
            return false
        end
        
        local has_quickshift, remaining_time, found_id = check_quickshift_buff()
        local refresh_threshold = menu_elements_maul.buff_refresh_threshold:get()
        
        -- Debug output with enhanced information
        if menu_elements_maul.debug_buffs:get() then
            console.print("Maul Debug - Quickshift search results:")
            console.print("  Found: " .. tostring(has_quickshift) .. 
                ", Time: " .. string.format("%.1f", remaining_time) .. 
                "s, Threshold: " .. string.format("%.1f", refresh_threshold) .. "s")
            if found_id then
                console.print("  Found Quickshift ID: " .. found_id)
            end
            
            -- Print all buffs occasionally to help identify correct ID
            if math.random(1, 20) == 1 then -- 5% chance to avoid spam
                debug_all_buffs()
            end
        end
        
        -- Cast if buff is missing or about to expire
        if not has_quickshift or remaining_time <= refresh_threshold then
            if cast_spell.target(target, spell_id_maul, 0, false) then
                next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast
                last_successful_cast_time = current_time

                console.print("Cast Maul - Buff Management - Quickshift refresh (was: " .. 
                    string.format("%.1f", remaining_time) .. "s remaining)")
                return true
            end
        else
            if menu_elements_maul.debug_buffs:get() then
                console.print("Maul Debug - Quickshift still active (" .. 
                    string.format("%.1f", remaining_time) .. "s), skipping cast")
            end
            return false
        end
    else
        -- Original filler logic
        local is_filler_enabled = menu_elements_maul.use_as_filler_only:get()
        if is_filler_enabled then
            local player_local = get_local_player()
            local current_resource_ws = player_local:get_primary_resource_current()
            local max_spirit = menu_elements_maul.max_spirit:get()
            local low_in_spirit = current_resource_ws < max_spirit

            if not low_in_spirit then
                return false
            end
        end

        if cast_spell.target(target, spell_id_maul, 0, false) then
            next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast
            last_successful_cast_time = current_time

            console.print("Cast Maul - Filler Mode - Target: " .. 
                my_utility.targeting_modes[menu_elements_maul.targeting_mode:get() + 1])
            return true
        end
    end

    return false
end

return 
{
    menu = menu,
    logics = logics,
    menu_elements = menu_elements_maul
}