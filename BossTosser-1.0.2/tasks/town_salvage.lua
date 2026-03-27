local utils = require "core.utils"
local enums = require "data.enums"
local explorerlite = require "core.explorerlite"
local settings = require "core.settings"
local tracker = require "core.tracker"
local gui = require "gui"

local salvage_state = {
    INIT = "INIT",
    TELEPORTING = "TELEPORTING",
    MOVING_TO_BLACKSMITH = "MOVING_TO_BLACKSMITH",
    INTERACTING_WITH_BLACKSMITH = "INTERACTING_WITH_BLACKSMITH",
    SALVAGING = "SALVAGING",
    MOVING_TO_PORTAL = "MOVING_TO_PORTAL",
    INTERACTING_WITH_PORTAL = "INTERACTING_WITH_PORTAL",
    FINISHED = "FINISHED",
}

local uber_table = {
    { name = "Tyrael's Might", sno = 1901484 },
    { name = "The Grandfather", sno = 223271 },
    { name = "Andariel's Visage", sno = 241930 },
    { name = "Ahavarion, Spear of Lycander", sno = 359165 },
    { name = "Doombringer", sno = 221017 },
    { name = "Harlequin Crest", sno = 609820 },
    { name = "Melted Heart of Selig", sno = 1275935 },
    { name = "Ring of Starless Skies", sno = 1306338 },
    { name = "Shroud of False Death", sno = 2059803 },
    { name = "Nesekem, the Herald", sno = 1982241 },
    { name = "Heir of Perdition", sno = 2059799 },
    { name = "Shattered Vow", sno = 2059813 }
}


function is_uber_item(sno_to_check)
    for _, entry in ipairs(uber_table) do
        if entry.sno == sno_to_check then
            return true
        end
    end
    return false
end


function salvage_low_greater_affix_items()
    local local_player = get_local_player()
    if not local_player then
        return
    end

    local inventory_items = local_player:get_inventory_items()
    local ga_threshold = settings.ga_threshold
    local uber_ga_threshold = settings.uber_ga_threshold
    
    for _, inventory_item in pairs(inventory_items) do
        if inventory_item and not inventory_item:is_locked() then
            local display_name = inventory_item:get_display_name()
            local greater_affix_count = utils.get_greater_affix_count(display_name)
            local item_id = inventory_item:get_sno_id()

            if is_uber_item(item_id) then
                if greater_affix_count < uber_ga_threshold then
                    loot_manager.salvage_specific_item(inventory_item)
                    console.print("Salvaged uber item: " .. display_name .. " with " .. greater_affix_count .. " GA.")
                end

            elseif greater_affix_count < ga_threshold then
                loot_manager.salvage_specific_item(inventory_item)
                console.print("Salvaged non-uber item: " .. display_name .. " with " .. greater_affix_count .. " GA.")
            end
        end
    end
end



local town_salvage_task = {
    name = "Town Salvage",
    current_state = salvage_state.INIT,
    max_retries = 5,
    current_retries = 0,
    max_teleport_attempts = 5,
    teleport_wait_time = 30,
    last_teleport_check_time = 0,
    last_blacksmith_interaction_time = 0,
    last_salvage_action_time = 0,
    last_salvage_completion_check_time = 0,
    last_portal_interaction_time = 0,

    
    




shouldExecute = function()
    local player = get_local_player()
    local inventory_full = utils.is_inventory_full()
    local in_cerrigar = utils.player_in_zone("Scos_Cerrigar")
    
    -- Always execute if the inventory is full, regardless of the player's location
    if inventory_full then
        tracker.needs_salvage = true
        return true
    end
    
    -- Continue the salvage process if in Cerrigar
    if in_cerrigar and tracker.needs_salvage then
        return true
    end
    
    -- If inventory is not full and not in Cerrigar, follow the usual conditions
    return false
end,

    

    Execute = function(self)
        console.print("Executing Town Salvage Task")
        console.print("Current state: " .. self.current_state)

        if self.current_retries >= self.max_retries then
            console.print("Max retries reached. Resetting task.")
            self:reset()
            return
        end

        if self.current_state == salvage_state.INIT then
            self:init_salvage()
        elseif self.current_state == salvage_state.TELEPORTING then
            self:handle_teleporting()
        elseif self.current_state == salvage_state.MOVING_TO_BLACKSMITH then
            self:move_to_blacksmith()
        elseif self.current_state == salvage_state.INTERACTING_WITH_BLACKSMITH then
            self:interact_with_blacksmith()
        elseif self.current_state == salvage_state.SALVAGING then
            self:salvage_items()
        elseif self.current_state == salvage_state.MOVING_TO_PORTAL then
            self:move_to_portal()
        elseif self.current_state == salvage_state.INTERACTING_WITH_PORTAL then
            self:interact_with_portal()
        elseif self.current_state == salvage_state.FINISHED then
            self:finish_salvage()
        end
    end,

    init_salvage = function(self)
        console.print("Initializing salvage process")
        if not utils.player_in_zone("Scos_Cerrigar") and get_local_player():get_item_count() >= 21 then
            self.current_state = salvage_state.TELEPORTING
            self.teleport_start_time = get_time_since_inject()
            self.teleport_attempts = 0
            self:teleport_to_town()
            console.print("Player not in Cerrigar, initiating teleport")
        else
            self.current_state = salvage_state.MOVING_TO_BLACKSMITH
            console.print("Player in Cerrigar, moving to blacksmith")
        end
    end,
    
    teleport_to_town = function(self)
        console.print("Teleporting to town")
        explorerlite:clear_path_and_target()
        teleport_to_waypoint(enums.waypoints.CERRIGAR)
        self.teleport_start_time = get_time_since_inject()
        console.print("Teleport command issued")
    end,
    
    handle_teleporting = function(self)
        local current_time = get_time_since_inject()
        if current_time - self.last_teleport_check_time >= 5 then
            self.last_teleport_check_time = current_time
            local current_zone = get_current_world():get_current_zone_name()
            console.print("Current zone: " .. tostring(current_zone))
            
            if current_zone:find("Cerrigar") or utils.player_in_zone("Scos_Cerrigar") then
                console.print("Teleport complete, moving to blacksmith")
                self.current_state = salvage_state.MOVING_TO_BLACKSMITH
                self.teleport_attempts = 0 -- Reset attempts counter
            else
                console.print("Teleport unsuccessful, retrying...")
                self.teleport_attempts = (self.teleport_attempts or 0) + 1
                
                if self.teleport_attempts >= self.max_teleport_attempts then
                    console.print("Max teleport attempts reached. Resetting task.")
                    self:reset()
                    return
                end
                
                self:teleport_to_town()
            end
        end
    end,

    move_to_blacksmith = function(self)
        console.print("Moving to blacksmith")
        console.print("Explorerlite object: " .. tostring(explorerlite))
        console.print("set_custom_target exists: " .. tostring(type(explorerlite.set_custom_target) == "function"))
        console.print("move_to_target exists: " .. tostring(type(explorerlite.move_to_target) == "function"))
        local blacksmith = utils.get_blacksmith()
        if blacksmith then
            explorerlite:set_custom_target(blacksmith:get_position())
            explorerlite:move_to_target()
            if utils.distance_to(blacksmith) < 2 then
                console.print("Reached blacksmith")
                self.current_state = salvage_state.INTERACTING_WITH_BLACKSMITH
            end
        else
            console.print("No blacksmith found, retrying...")
            self.current_retries = self.current_retries + 1
            explorerlite:set_custom_target(enums.positions.blacksmith_position)
            explorerlite:move_to_target()
        end
    end,

    interact_with_blacksmith = function(self)
        console.print("Interacting with blacksmith")
        local blacksmith = utils.get_blacksmith()
        if blacksmith then
            local current_time = get_time_since_inject()
            if current_time - self.last_blacksmith_interaction_time >= 2 then
                self.last_blacksmith_interaction_time = current_time
                interact_vendor(blacksmith)
                console.print("Interacted with blacksmith, waiting 5 seconds before salvaging")
                self.interaction_time = current_time
                self.current_state = salvage_state.SALVAGING
            end
        else
            console.print("Blacksmith not found, moving back")
            self.current_state = salvage_state.MOVING_TO_BLACKSMITH
        end
    end,
    
    salvage_items = function(self)
        console.print("Salvaging items")
        
        local current_time = get_time_since_inject()
        
        if not self.interaction_time or current_time - self.interaction_time >= 5 then
            if not self.last_salvage_time then
                salvage_low_greater_affix_items()
                self.last_salvage_time = current_time
                console.print("Salvage action performed, waiting 2 seconds before checking results")
            elseif current_time - self.last_salvage_time >= 2 then
                local item_count = get_local_player():get_item_count()
                console.print("Current item count: " .. item_count)
                
                if item_count <= 21 then
                    tracker.has_salvaged = true
                    tracker.needs_salvage = true
                    console.print("Salvage complete, item count is 15 or less. Moving to portal")
                    self.current_state = salvage_state.MOVING_TO_PORTAL
                else
                    console.print("Item count is still above 15, retrying salvage")
                    self.current_retries = self.current_retries + 1
                    if self.current_retries >= self.max_retries then
                        console.print("Max retries reached numb2. Resetting task.")
                        self:reset()
                    else
                        self.last_salvage_time = nil  -- Reset this to allow immediate salvage on next cycle
                        self.current_state = salvage_state.INTERACTING_WITH_BLACKSMITH
                    end
                end
            end
        else
            console.print("Waiting for 5-second delay after blacksmith interaction")
        end
    end,

    move_to_portal = function(self)
        console.print("Moving to portal")
        explorerlite:set_custom_target(enums.positions.portal_position)
        explorerlite:move_to_target()
        if utils.distance_to(enums.positions.portal_position) < 5 then
            console.print("Reached portal")
            self.current_state = salvage_state.INTERACTING_WITH_PORTAL
            self.portal_interact_time = 0  -- Initialize portal interaction timer
        end
    end,
    
    interact_with_portal = function(self)
        console.print("Interacting with portal")
        local portal = utils.get_town_portal()
        local current_time = get_time_since_inject()
        local current_zone = get_current_world():get_current_zone_name()
    
        if portal then
            if current_zone:find("Cerrigar") or utils.player_in_zone("Scos_Cerrigar") then
                if self.last_portal_interaction_time == nil or current_time - self.last_portal_interaction_time >= 1 then
                    console.print("Still in Cerrigar, attempting to interact with portal")
                    interact_object(portal)
                    self.last_portal_interaction_time = current_time
                end
            else
                console.print("Successfully left Cerrigar")
                tracker.has_salvaged = false
                tracker.needs_salvage = false
                self:reset()
                return
            end
    
            if self.portal_interact_time == 0 then
                console.print("Starting portal interaction timer.")
                self.portal_interact_time = current_time
            elseif current_time - self.portal_interact_time >= 30 then
                console.print("Portal interaction timed out after 30 seconds. Resetting task.")
                self:reset()
            else
                console.print(string.format("Waiting for portal interaction... Time elapsed: %.2f seconds", current_time - self.portal_interact_time))
            end
        else
            console.print("Town portal not found")
            tracker.has_salvaged = false
            tracker.needs_salvage = false
            self:reset()
            self.current_state = salvage_state.INIT  -- Go back to moving if portal not found
        end
    end,

    finish_salvage = function(self)
        console.print("Finishing salvage task")
        tracker.has_salvaged = true
        tracker.needs_salvage = true
        self.current_state = salvage_state.MOVING_TO_PORTAL
        self.current_retries = 0
        console.print("Town salvage task finished")
    end,

    reset = function(self)
        console.print("Resetting town salvage task")
        self.current_state = salvage_state.INIT
        self.portal_interact_time = 0
        self.reset_salvage_time = 0
        self.current_retries = 0
        console.print("Reset town_salvage_task and related tracker flags")
    end,
}

return town_salvage_task