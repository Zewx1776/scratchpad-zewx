local menu = require("menu")
local enums = require("data.enums")
local StashService = require("services.stash_service")

local SalvageService = {
    CONSTANTS = {
        INTERACTION_DISTANCE = 3.0,
        PROCESS_DELAY = 0.5
    },

    state = {
        is_processing = false,
        last_salvage_time = 0,
        items_processed = 0
    }
}

local function calculate_distance(point1, point2)
    if not point1 or not point2 then return 999999 end
    return point1:dist_to_ignore_z(point2)
end


function SalvageService:interact_vendor(vendor_pos)
    if not vendor_pos then 
        console.print("Invalid vendor position")
        return false 
    end
    
    
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
            if name == enums.misc.blacksmith then
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


function SalvageService:should_salvage_item(item_data, ignore_threshold)
    if not item_data then return false end
    
        
    if StashService:should_stash_item(item_data, ignore_threshold) then
        return false
    end
    
    local display_name = item_data:get_display_name()
    if not display_name then return false end
    
    -- Conta Greater Affixes
    local greater_affix_count = 0
    for _ in display_name:gmatch("GreaterAffix") do
        greater_affix_count = greater_affix_count + 1
    end
    
    return greater_affix_count < menu.greater_affix_threshold:get()
end


function SalvageService:has_items_to_salvage(ignore_threshold)
    local local_player = get_local_player()
    if not local_player then return false end
    
    local inventory_items = local_player:get_inventory_items()
    if not inventory_items then return false end
    
    
    if not ignore_threshold then
        local items_threshold = menu.items_threshold:get()
        local total_items = #inventory_items
        
        if total_items < items_threshold then
            console.print(string.format("Total items (%d) less than threshold (%d)", 
                total_items, items_threshold))
            return false
        end
    end
    
    
    for _, item_data in ipairs(inventory_items) do
        if self:should_salvage_item(item_data, ignore_threshold) then
            return true
        end
    end
    
    return false
end


function SalvageService:find_blacksmith()
    return enums.positions.blacksmith_position
end


function SalvageService:process_salvage_items(vendor_pos)
    if self.state.is_processing then 
        console.print("Already processing salvage")
        return false 
    end
    
    console.print("Starting salvage process...")
    
    
    if not loot_manager.is_in_vendor_screen() then
        if not self:interact_vendor(vendor_pos) then
            console.print("Failed to open blacksmith window, aborting salvage")
            return false
        end
    else
        console.print("It's already on the blacksmith screen, continuing with salvage")
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
    self.state.items_salvaged = 0
    local initial_count = local_player:get_item_count()
    local current_time = os.clock()
    
    
    for _, item_data in ipairs(inventory_items) do
        
        if not loot_manager.is_in_vendor_screen() then
            console.print("Lost connection with blacksmith, trying to reconnect...")
            if not self:interact_blacksmith(blacksmith) then
                console.print("Failed to reconnect with blacksmith, aborting salvage")
                break
            end
        end
        
        if self:should_salvage_item(item_data) then
            local display_name = item_data:get_display_name()
            console.print(string.format("Trying to salvage: %s", display_name))
            
            if loot_manager.salvage_specific_item(item_data) then
                while os.clock() - current_time < self.CONSTANTS.PROCESS_DELAY do end
                current_time = os.clock()
                
                local new_count = local_player:get_item_count()
                if new_count < initial_count then
                    self.state.items_salvaged = self.state.items_salvaged + 1
                    initial_count = new_count
                    console.print(string.format("Item successfully salvaged: %s", display_name))
                else
                    console.print(string.format("Failed to save item: %s (count did not change)", display_name))
                end
            else
                console.print(string.format("Failed to salvage item: %s", display_name))
            end
        end
    end
    
    local success = self.state.items_salvaged > 0
    self.state.is_processing = false
    
    if success then
        console.print(string.format("Salvage completed successfully. Total salvaged items: %d", 
            self.state.items_salvaged))
    else
        console.print("No items were salvaged")
    end
    
    return success
end


function SalvageService:get_stats()
    return {
        items_processed = self.state.items_processed,
        is_processing = self.state.is_processing,
        last_process_time = self.state.last_salvage_time
    }
end

return SalvageService