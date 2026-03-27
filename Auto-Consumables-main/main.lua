local menu = require("menu")
local options = require("data.consumable_options")

local potion_cooldowns = {}
local potion_cooldown_time = 1800 -- 30 minutes (in seconds)

local last_use_time = 0

local local_player, player_position

local function update_locals()
    local_player = get_local_player()
    player_position = local_player and local_player:get_position()
end


local function check_for_player_buff(buffs, item_name)
    local count = 0
    for _, buff in ipairs(buffs) do
        local buff_name = buff:name()
        if buff_name == item_name then
            count = count + 1
        end
    end
    return count
end


local function execute_with_cooldown(item, force_use)
    local item_name = item:get_name()
    local current_time = get_time_since_inject()

    if not potion_cooldowns[item_name] then
        potion_cooldowns[item_name] = 0
    end

    if force_use or current_time - potion_cooldowns[item_name] >= potion_cooldown_time then
        use_item(item)
        potion_cooldowns[item_name] = current_time
        last_use_time = current_time
        if menu.elements.debug_toggle:get() then console.print("Used: " .. item_name) end
    else
        if menu.elements.debug_toggle:get() then console.print("Skipped " .. item_name .. ": cooldown active (" .. math.floor((potion_cooldown_time - (current_time - potion_cooldowns[item_name])) / 60) .. " min remaining)") end
    end
end


local function check_consumables(item_options, chosen_index, toggle, buffs, consumable_items, item_names)
    if toggle then
        local item_name = item_options[chosen_index + 1]
        local buff_name = item_names[chosen_index + 1]
        if item_name and buff_name then
            if check_for_player_buff(buffs, item_name) == 0 then
                for _, item in ipairs(consumable_items) do
                    if item:get_name() == item_name then
                        execute_with_cooldown(item, true)
                        return
                    end
                end
                if menu.elements.debug_toggle:get() then console.print("Skipped " .. item_name .. ": item not found in consumable_items") end
            else
                if menu.elements.debug_toggle:get() then console.print("Skipped " .. item_name .. ": buff '" .. buff_name .. "' active") end
            end
        else
            if menu.elements.debug_toggle:get() then console.print("Skipped: invalid item or buff name at index " .. (chosen_index + 1)) end
        end
    end
end


local function check_inventory(inventory)
    for _, item in ipairs(inventory) do
        if string.find(string.lower(item:get_name()), "temper") then
            execute_with_cooldown(item)
        end
    end
end


local function main_pulse()

    if not menu.elements.main_toggle:get() then
        return
    end
    
    if not local_player then
        return
    end

    local current_time = get_time_since_inject()
    if current_time - last_use_time < 2 then
        return
    end

    local buffs = local_player:get_buffs()
    local consumable_items = local_player:get_consumable_items()
    local inventory_items = local_player:get_inventory_items()

    check_inventory(inventory_items)

if menu.elements.require_target_toggle:get() then
    local closest_target = target_selector.get_target_closer(player_position, 10)
    if not closest_target then
        if menu.elements.debug_toggle:get() then console.print("Skipped all consumables: require target enabled, no enemy within 10 units") end
        return
    end
end

    local chosen_advanced_elixir = menu.elements.advanced_elixir_combo:get()
    local chosen_basic_elixir = menu.elements.basic_elixir_combo:get()

    local chosen_core_stat_incense = menu.elements.core_stat_incense_combo:get()
    local chosen_defensive_incense = menu.elements.defensive_incense_combo:get()
    local chosen_resistance_incense = menu.elements.resistance_incense_combo:get()

    local advanced_elixir_toggle = menu.elements.advanced_elixir_toggle:get()
    local basic_elixir_toggle = menu.elements.basic_elixir_toggle:get()

    local core_stat_incense_toggle = menu.elements.core_stat_incense_toggle:get()
    local defensive_incense_toggle = menu.elements.defensive_incense_toggle:get()
    local resistance_incense_toggle = menu.elements.resistance_incense_toggle:get()

    if advanced_elixir_toggle then
        check_consumables(options.advanced_elixir_options, chosen_advanced_elixir, advanced_elixir_toggle, buffs, consumable_items, options.advanced_elixir_names)
    end
    if basic_elixir_toggle then
        check_consumables(options.basic_elixir_options, chosen_basic_elixir, basic_elixir_toggle, buffs, consumable_items, options.basic_elixir_names)
    end

    if core_stat_incense_toggle then
        check_consumables(options.core_stat_incense_options, chosen_core_stat_incense, core_stat_incense_toggle, buffs, consumable_items, options.core_stat_incense_names)
    end
    if defensive_incense_toggle then
        check_consumables(options.defensive_incense_options, chosen_defensive_incense, defensive_incense_toggle, buffs, consumable_items, options.defensive_incense_names)
    end
    if resistance_incense_toggle then
        check_consumables(options.resistance_incense_options, chosen_resistance_incense, resistance_incense_toggle, buffs, consumable_items, options.resistance_incense_names)
    end
end


on_update(function()
    update_locals()
    main_pulse()
end)

on_render_menu(menu.render)