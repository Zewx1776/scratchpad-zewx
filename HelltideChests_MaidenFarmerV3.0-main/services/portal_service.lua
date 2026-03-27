local enums = require("data.enums")
local explorer = require("data.explorer")

local PortalService = {
    CONSTANTS = {
        INTERACTION_DISTANCE = 3.0,
        MOVEMENT_THRESHOLD = 2.5,
        PROCESS_DELAY = 0.1
    },

    state = {
        is_processing = false,
        last_interaction_time = 0
    }
}


function PortalService:find_portal()
    return {
        object = enums.misc.portal,
        position = enums.positions.portal_position,
        type = "portal"
    }
end


function PortalService:move_to_portal(target_pos)
    if not target_pos then return false end
    
    local player_pos = get_player_position()
    if not player_pos then return false end
    
    local distance = player_pos:dist_to_ignore_z(target_pos)
    
    
    if distance <= self.CONSTANTS.MOVEMENT_THRESHOLD then
        if explorer.is_enabled() then
            explorer.disable()
        end
        return true
    end
    
    
    if not explorer.is_enabled() then
        explorer.enable()
    end
    explorer.set_target(target_pos)
    
    console.print(string.format("Distance to portal: %.2f", distance))
    return false
end


function PortalService:interact_portal(portal_pos)
    if not portal_pos then return false end
    
    
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        if actor:is_interactable() then
            local name = actor:get_skin_name()
            if name == enums.misc.portal then
                local actor_pos = actor:get_position()
                local dist = actor_pos:dist_to_ignore_z(portal_pos)
                if dist < self.CONSTANTS.INTERACTION_DISTANCE then
                    console.print("Portal found, interacting...")
                    return interact_object(actor)
                end
            end
        end
    end
    
    console.print("Portal not found in position")
    return false
end


function PortalService:process_portal(target)
    if self.state.is_processing then return false end
    
    
    if not self:move_to_portal(target.position) then
        return false
    end
    
    
    self.state.is_processing = true
    local success = self:interact_portal(target.position)
    self.state.is_processing = false
    
    return success
end

return PortalService