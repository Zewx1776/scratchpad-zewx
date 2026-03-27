local utils = require "core.utils"
local enums = require "data.enums"
local explorerlite = require "core.explorerlite"
local settings = require "core.settings"
local tracker = require "core.tracker"

local teleport_state = {
    INIT = "INIT",
    TELEPORTING = "TELEPORTING",
    MOVING_TO_PORTAL = "MOVING_TO_PORTAL",
    INTERACTING_WITH_PORTAL = "INTERACTING_WITH_PORTAL",
    RETURNING = "RETURNING",
    FINISHED = "FINISHED"
}

local function count_items_on_ground()
    local items = loot_manager.get_all_items_chest_sort_by_distance()
    return #items
end

local task = {
    name = "Ground Items Teleport",
    current_state = teleport_state.INIT,
    last_teleport_check_time = 0,
    teleport_attempts = 0,
    max_teleport_attempts = 5,
    last_portal_interaction_time = 0,
    portal_interact_time = 0,
    
    shouldExecute = function()
        -- First check if the feature is enabled in settings
        if not settings.enable_ground_items_teleport then
            return false
        end

        local in_cerrigar = utils.player_in_zone("Scos_Cerrigar")
        
        -- Execute if too many items on ground and not in town
        if count_items_on_ground() > 20 and not in_cerrigar then
            tracker.needs_itemreset = true
            return true
        end
        
        -- Continue the process if in Cerrigar and needs item reset
        if in_cerrigar and tracker.needs_itemreset then
            return true
        end
        
        return false
    end,

    Execute = function(self)
        if self.current_state == teleport_state.INIT then
            console.print("Teleporting to town due to too many ground items")
            explorerlite:clear_path_and_target()
            teleport_to_waypoint(enums.waypoints.CERRIGAR)
            self.teleport_attempts = 1
            self.last_teleport_check_time = get_time_since_inject()
            self.current_state = teleport_state.TELEPORTING
            
        elseif self.current_state == teleport_state.TELEPORTING then
            local current_time = get_time_since_inject()
            if current_time - self.last_teleport_check_time >= 2 then
                self.last_teleport_check_time = current_time
                
                if utils.player_in_zone("Scos_Cerrigar") then
                    console.print("Successfully teleported to town")
                    self.current_state = teleport_state.MOVING_TO_PORTAL
                    self.portal_interact_time = 0
                else
                    self.teleport_attempts = self.teleport_attempts + 1
                    if self.teleport_attempts >= self.max_teleport_attempts then
                        console.print("Failed to teleport after max attempts")
                        self:reset()
                        return
                    end
                    teleport_to_waypoint(enums.waypoints.CERRIGAR)
                end
            end
            
        elseif self.current_state == teleport_state.MOVING_TO_PORTAL then
            console.print("Moving to portal")
            explorerlite:set_custom_target(enums.positions.portal_position)
            explorerlite:move_to_target()
            if utils.distance_to(enums.positions.portal_position) < 5 then
                console.print("Reached portal")
                self.current_state = teleport_state.INTERACTING_WITH_PORTAL
                self.portal_interact_time = 0
            end
            
        elseif self.current_state == teleport_state.INTERACTING_WITH_PORTAL then
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
                    tracker.needs_itemreset = false
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
                tracker.needs_itemreset = true
                if utils.player_in_zone("Scos_Cerrigar") then
                    self.current_state = teleport_state.INTERACTING_WITH_PORTAL
                else
                    self.current_state = teleport_state.INIT
                end
            end
        end
    end,

    reset = function(self)
        self.current_state = teleport_state.INIT
        self.teleport_attempts = 0
        self.last_teleport_check_time = 0
        self.last_portal_interaction_time = nil
        self.portal_interact_time = 0
    end
}

return task 