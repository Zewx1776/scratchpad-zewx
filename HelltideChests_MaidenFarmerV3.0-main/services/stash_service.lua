local menu = require("menu")
local enums = require("data.enums")
local BossMaterialsService = require("services.boss_materials_service")

local StashService = {
    CONSTANTS = {
        INTERACTION_DISTANCE = 3.0,
        PROCESS_DELAY = 0.1
    },

    state = {
        is_processing = false,
        last_stash_time = 0,
        items_stashed = 0
    }
}

local function calculate_distance(point1, point2)
    if not point1 or not point2 then return 999999 end
    return point1:dist_to_ignore_z(point2)
end


function StashService:interact_stash(stash_pos)
    if not stash_pos then 
        console.print("Invalid stash position")
        return false 
    end
    
    console.print("Trying to interact with stash...")
    
    
    local actors = actors_manager:get_all_actors()
    local closest_stash = nil
    local min_distance = 999999
    
    for _, actor in pairs(actors) do
        if actor:is_interactable() then
            local name = actor:get_skin_name()
            if name == enums.misc.stash then
                local distance = calculate_distance(actor:get_position(), stash_pos)
                if distance < min_distance then
                    min_distance = distance
                    closest_stash = actor
                end
            end
        end
    end
    
    if not closest_stash then
        console.print("No stash found at position")
        return false
    end
    
    
    console.print("Calling interact_vendor with stash...")
    interact_vendor(closest_stash)
    
    
    local current_time = os.clock()
    while os.clock() - current_time < self.CONSTANTS.PROCESS_DELAY do end
    
    
    console.print("Interaction with stash performed")
    return true
end


function StashService:should_stash_item(item_data)
    
    if type(item_data) == "table" then
        local local_player = get_local_player()
        if not local_player then return false end
        
        
        local item_count = local_player:get_item_count() or 0
        if item_count < menu.items_threshold:get() then
            return false
        end
        
        
        for _, item in ipairs(item_data) do
            if item and self:should_stash_item(item) then
                return true
            end
        end
        return false
    end

    
    if not item_data then return false end

    
    if BossMaterialsService:should_stash_material(item_data) then
        return true
    end
    
    
    if menu.auto_stash:get() then
        local display_name = item_data:get_display_name()
        if not display_name then return false end
        
        local greater_affix_count = 0
        for _ in display_name:gmatch("GreaterAffix") do
            greater_affix_count = greater_affix_count + 1
        end
        
        return greater_affix_count >= menu.greater_affix_threshold:get()
    end
    
    return false
end


function StashService:find_nearest_stash()
    return enums.positions.stash_position
end


function StashService:process_stash_items(stash)
    if self.state.is_processing then 
        console.print("Already processing stash")
        return false 
    end
    
    console.print("Starting stash process...")
    
    
    if not self:interact_stash(stash) then
        console.print("Failed to interact with stash, aborting operation")
        return false
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
    self.state.items_stashed = 0
    local initial_count = local_player:get_item_count()
    local current_time = os.clock()
    
    
    for _, item_data in ipairs(inventory_items) do
        if self:should_stash_item(item_data) then
            local display_name = item_data:get_display_name()
            console.print(string.format("Trying to save to stash: %s", display_name))
            
            
            if loot_manager.move_item_to_stash(item_data) then
                while os.clock() - current_time < self.CONSTANTS.PROCESS_DELAY do end
                current_time = os.clock()
                
                local new_count = local_player:get_item_count()
                if new_count < initial_count then
                    self.state.items_stashed = self.state.items_stashed + 1
                    initial_count = new_count
                    console.print(string.format("Item saved successfully: %s", display_name))
                else
                    
                    self:interact_stash(stash)
                    
                    if loot_manager.move_item_to_stash(item_data) then
                        while os.clock() - current_time < self.CONSTANTS.PROCESS_DELAY do end
                        current_time = os.clock()
                        new_count = local_player:get_item_count()
                        if new_count < initial_count then
                            self.state.items_stashed = self.state.items_stashed + 1
                            initial_count = new_count
                            console.print(string.format("Item saved successfully on the second attempt: %s", display_name))
                        else
                            console.print(string.format("Failed to save item after second attempt: %s", display_name))
                        end
                    end
                end
            else
                console.print(string.format("Failed to move item to stash: %s", display_name))
                
                self:interact_stash(stash)
            end
        end
    end
    
    local success = self.state.items_stashed > 0
    self.state.is_processing = false
    
    if success then
        console.print(string.format("Stash completed successfully. Total saved items: %d", 
            self.state.items_stashed))
    else
        console.print("No items were stashed")
    end
    
    return success
end


function StashService:process_boss_materials(stash)
    if self.state.is_processing then 
        console.print("Already processing stash")
        return false 
    end
    
    console.print("Starting stash process for boss materials...")
    
    
    if not self:interact_stash(stash) then
        console.print("Failed to interact with stash, aborting operation")
        return false
    end
    
    local local_player = get_local_player()
    if not local_player then 
        console.print("Player not found")
        return false 
    end
    
    local consumable_items = local_player:get_consumable_items()
    if not consumable_items then 
        console.print("Unable to obtain consumable items")
        return false 
    end
    
    console.print(string.format("Found %d consumable items", #consumable_items))
    
    self.state.is_processing = true
    self.state.items_stashed = 0
    local initial_count = local_player:get_item_count()
    local current_time = os.clock()
    
    
    for _, item_data in pairs(consumable_items) do
        if BossMaterialsService:should_stash_material(item_data) then
            local stack_count = item_data:get_stack_count() or 0
            console.print(string.format("Trying to save stack of %d in stash", stack_count))
            
            
            if loot_manager.move_item_to_stash(item_data) then
                while os.clock() - current_time < self.CONSTANTS.PROCESS_DELAY do end
                current_time = os.clock()
                
                local new_count = local_player:get_item_count()
                if new_count < initial_count then
                    self.state.items_stashed = self.state.items_stashed + 1
                    initial_count = new_count
                    console.print(string.format("Material saved successfully (stack %d)", stack_count))
                    self.state.is_processing = false
                    return true 
                else
                    
                    self:interact_stash(stash)
                    
                    if loot_manager.move_item_to_stash(item_data) then
                        while os.clock() - current_time < self.CONSTANTS.PROCESS_DELAY do end
                        current_time = os.clock()
                        new_count = local_player:get_item_count()
                        if new_count < initial_count then
                            self.state.items_stashed = self.state.items_stashed + 1
                            initial_count = new_count
                            console.print(string.format("Material saved on the second attempt (stack %d)", stack_count))
                            self.state.is_processing = false
                            return true 
                        else
                            console.print("Failed to save material after second attempt")
                        end
                    end
                end
            else
                console.print("Failed to move material to stash")
                
                self:interact_stash(stash)
            end
        end
    end
    
    self.state.is_processing = false
    return self.state.items_stashed > 0
end

return StashService