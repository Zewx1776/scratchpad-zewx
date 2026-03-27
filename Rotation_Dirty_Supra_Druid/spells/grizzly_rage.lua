local my_utility = require("my_utility/my_utility")
local spell_data = require("my_utility/spell_data")

local menu_elements = 
{
    main_tab           = tree_node:new(1),
    main_boolean       = checkbox:new(true, get_hash(my_utility.plugin_label .. "grizzly_rage_disable_enable_ability")),
    targeting_mode     = combo_box:new(3, get_hash(my_utility.plugin_label .. "grizzly_rage_base_targeting_mode")),
    
    -- Enhanced usage options
    cast_on_cooldown   = checkbox:new(true, get_hash(my_utility.plugin_label .. "grizzly_rage_cast_on_cooldown")),
    min_enemies_nearby = slider_int:new(0, 10, 1, get_hash(my_utility.plugin_label .. "grizzly_rage_min_enemies")),
    check_range        = slider_int:new(5, 25, 15, get_hash(my_utility.plugin_label .. "grizzly_rage_check_range")),
    
    -- Original manual casting options
    cast_range         = slider_int:new(1, 35, 15, get_hash(my_utility.plugin_label .. "grizzly_rage_cast_range")),
    debug_usage        = checkbox:new(false, get_hash(my_utility.plugin_label .. "grizzly_rage_debug_usage"))
}

local function menu()                                                                                    
    if menu_elements.main_tab:push("Grizzly Rage") then
        menu_elements.main_boolean:render("Enable Spell", "")

        if menu_elements.main_boolean:get() then
            menu_elements.targeting_mode:render("Targeting Mode", my_utility.targeting_modes,
                my_utility.targeting_mode_description)
            
            menu_elements.cast_on_cooldown:render("Cast on Cooldown", 
                "Automatically cast Grizzly Rage whenever it's available")
            
            if menu_elements.cast_on_cooldown:get() then
                menu_elements.min_enemies_nearby:render("Min Enemies Nearby", 
                    "Minimum number of enemies required to cast (0 = always cast)")
                menu_elements.check_range:render("Enemy Check Range", 
                    "Range to check for nearby enemies")
                menu_elements.debug_usage:render("Debug Usage", 
                    "Print debug information about Grizzly Rage casting decisions")
            else
                menu_elements.cast_range:render("Manual Cast Range", "Range in yards to cast Grizzly Rage")
            end
        end
 
        menu_elements.main_tab:pop()
    end
end

local next_time_allowed_cast = 0.0
local next_time_allowed_move = 0.0
local move_delay = 0.5

local function logics(target)
    if not target then return false end
    
    local menu_boolean = menu_elements.main_boolean:get()
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean, 
        next_time_allowed_cast, 
        spell_data.grizzly_rage.spell_id)

    if not is_logic_allowed then
        return false
    end

    -- Enhanced on-cooldown casting mode
    if menu_elements.cast_on_cooldown:get() then
        local min_enemies = menu_elements.min_enemies_nearby:get()
        local check_range = menu_elements.check_range:get()
        
        -- Count nearby enemies if minimum is required
        if min_enemies > 0 then
            local player_position = get_player_position()
            local nearby_enemies = target_selector.get_near_target_list(player_position, check_range)
            local valid_enemy_count = 0
            
            for _, enemy in ipairs(nearby_enemies) do
                if enemy:is_enemy() and not enemy:is_untargetable() and not enemy:is_immune() then
                    valid_enemy_count = valid_enemy_count + 1
                end
            end
            
            -- Debug output
            if menu_elements.debug_usage:get() then
                console.print("Grizzly Rage Debug - Enemies nearby: " .. valid_enemy_count .. 
                    ", Required: " .. min_enemies)
            end
            
            -- Don't cast if not enough enemies
            if valid_enemy_count < min_enemies then
                return false
            end
        end
        
        -- Cast on any valid target (since we're just trying to activate the buff)
        if cast_spell.target(target, spell_data.grizzly_rage.spell_id, 0, false) then
            local current_time = get_time_since_inject()
            next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast

            console.print("Cast Grizzly Rage - On Cooldown Mode - MASSIVE DAMAGE ACTIVATED!")
            return true
        end
    else
        -- Original manual casting logic with movement
        local cast_range = menu_elements.cast_range:get()
        local in_range = my_utility.is_in_range(target, cast_range)
        
        if not in_range then
            -- Check if we can move again
            local current_time = get_time_since_inject()
            if current_time >= next_time_allowed_move then
                -- move to target
                local target_position = target:get_position()
                pathfinder.force_move_raw(target_position)
                next_time_allowed_move = current_time + move_delay
            end
            return false
        end

        if cast_spell.target(target, spell_data.grizzly_rage.spell_id, 0, false) then
            local current_time = get_time_since_inject()
            next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast

            console.print("Cast Grizzly Rage - Manual Mode - Target: " ..
                my_utility.targeting_modes[menu_elements.targeting_mode:get() + 1] .. 
                " - Range: " .. cast_range)
            return true
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