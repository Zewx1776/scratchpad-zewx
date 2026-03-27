local menu = require("menu")
local enums = require("data.enums")
local StashService = require("services.stash_service")
local SalvageService = require("services.salvage_service")

local SellService = {
    CONSTANTS = {
        INTERACTION_DISTANCE = 3.0,
        PROCESS_DELAY = 0.1
    },

    state = {
        is_processing = false,
        last_sell_time = 0,
        items_sold = 0
    }
}

local function calculate_distance(point1, point2)
    if not point1 or not point2 then return 999999 end
    return point1:dist_to_ignore_z(point2)
end


function SellService:interact_vendor(vendor_pos)
    if not vendor_pos then 
        console.print("Invalid vendor position")
        return false 
    end
    
    console.print("Trying to interact with vendor...")
    
    
    if loot_manager.is_in_vendor_screen() then
        console.print("It's already on the vendor screen")
        return true
    end
    
    
    local actors = actors_manager:get_all_actors()
    local closest_vendor = nil
    local min_distance = 999999
    
    for _, actor in pairs(actors) do
        if actor:is_interactable() then
            local name = actor:get_skin_name()
            if name == enums.misc.jeweler then
                local distance = calculate_distance(actor:get_position(), vendor_pos)
                if distance < min_distance then
                    min_distance = distance
                    closest_vendor = actor
                end
            end
        end
    end
    
    if not closest_vendor then
        console.print("No vendors found in the position")
        return false
    end
    
    
    interact_vendor(closest_vendor)
    
    
    local current_time = os.clock()
    while os.clock() - current_time < self.CONSTANTS.PROCESS_DELAY do end
    
    
    if loot_manager.is_in_vendor_screen() then
        console.print("Vendor window opened successfully")
        return true
    end
    
    console.print("Failed to open vendor window")
    return false
end


function SellService:should_sell_item(item_data, ignore_threshold)
    if not item_data then return false end
    
        
    if StashService:should_stash_item(item_data, ignore_threshold) then
        return false
    end
    
    
    if menu.auto_salvage:get() and SalvageService:should_salvage_item(item_data, ignore_threshold) then
        return false
    end
    
    local display_name = item_data:get_display_name()
    if not display_name then return false end
    
    
    local greater_affix_count = 0
    for _ in display_name:gmatch("GreaterAffix") do
        greater_affix_count = greater_affix_count + 1
    end
    
    return greater_affix_count < menu.greater_affix_threshold:get()
end


function SellService:has_items_to_sell(ignore_threshold)
    local local_player = get_local_player()
    if not local_player then return false end
    
    local inventory_items = local_player:get_inventory_items()
    if not inventory_items then return false end
    
    
    if not ignore_threshold then
        local items_threshold = menu.items_threshold:get()
        if #inventory_items < items_threshold then
            console.print(string.format("Total items (%d) less than threshold (%d)", 
                #inventory_items, items_threshold))
            return false
        end
    end
    
    
    for _, item_data in ipairs(inventory_items) do
        if self:should_sell_item(item_data, ignore_threshold) then
            return true
        end
    end
    
    return false
end


function SellService:find_jeweler()
    return enums.positions.jeweler_position
end


function SellService:process_sell_items(vendor)
    if self.state.is_processing then 
        console.print("Already processing sale")
        return false 
    end
    
    console.print("Starting the sales process...")
    
    
    if not loot_manager.is_in_vendor_screen() then
        if not self:interact_vendor(vendor) then
            console.print("Failed to open vendor window, aborting sale")
            return false
        end
    else
        console.print("It's already on the vendor screen, continuing with the sale")
    end
    
    local local_player = get_local_player()
    if not local_player then 
        console.print("Player not found")
        return false 
    end
    
    local inventory_items = local_player:get_inventory_items()
    if not inventory_items then 
        console.print("Unable to get inventory items")
        return false 
    end
    
    console.print(string.format("Found %d items in inventory", #inventory_items))
    
    self.state.is_processing = true
    self.state.items_sold = 0
    local initial_count = local_player:get_item_count()
    local current_time = os.clock()
    
    
    for _, item_data in ipairs(inventory_items) do
        
        if not loot_manager.is_in_vendor_screen() then
            console.print("Lost connection with vendor, trying to reconnect...")
            if not self:interact_vendor(vendor) then
                console.print("Failed to reconnect with vendor, aborting sale")
                break
            end
        end
        
        if self:should_sell_item(item_data) then
            local display_name = item_data:get_display_name()
            console.print(string.format("Trying to sell: %s", display_name))
            
            if loot_manager.sell_specific_item(item_data) then
                while os.clock() - current_time < self.CONSTANTS.PROCESS_DELAY do end
                current_time = os.clock()
                
                local new_count = local_player:get_item_count()
                if new_count < initial_count then
                    self.state.items_sold = self.state.items_sold + 1
                    initial_count = new_count
                    console.print(string.format("Item successfully sold: %s", display_name))
                else
                    console.print(string.format("Failed to sell item: %s (count did not change)", display_name))
                end
            else
                console.print(string.format("Failed to sell the item: %s", display_name))
            end
        end
    end
    
    local success = self.state.items_sold > 0
    self.state.is_processing = false
    
    if success then
        console.print(string.format("Sale completed successfully. Total items sold: %d", 
            self.state.items_sold))
    else
        console.print("No items were sold")
    end
    
    return success
end


function SellService:get_stats()
    return {
        items_sold = self.state.items_sold,
        is_processing = self.state.is_processing,
        last_sell_time = self.state.last_sell_time
    }
end

return SellService