local utils = require "core.utils"
local enums = require "data.enums"
local explorer = require "core.explorer"
local tracker = require "core.tracker"

local walking_to_horde_task = {
    name = "Walking to Horde",
    last_teleport_time = 0,
    teleport_wait_time = 10, -- Wait time in seconds
    current_waypoint_index = 1,
    waypoints = require "data.library",
    arrived_destination = false
}

local function near_horde_gate()
    local gate = utils.get_horde_gate()
    if gate then
        if utils.distance_to(gate) < 10 then
            return true
        else
            return false
        end
    else
        return false
    end
end

local function is_loading_or_limbo()
    local current_world = world.get_current_world()
    if not current_world then
        return true
    end
    local world_name = current_world:get_name()
    return world_name:find("Limbo") ~= nil or world_name:find("Loading") ~= nil
end

-- Task should execute function (without self)
function walking_to_horde_task.shouldExecute()
    return not is_loading_or_limbo() and not (utils.player_in_zone("Kehj_Caldeum") or utils.player_in_zone("S05_BSK_Prototype02")) or
        (utils.player_in_zone("Kehj_Caldeum") and not near_horde_gate())
end

-- Task execute function (without self)
function walking_to_horde_task.Execute()
    console.print("Executing Walking to Horde task")

    local current_time = get_time_since_inject()

    if utils.get_horde_gate() and utils.distance_to(utils.get_horde_gate()) < 25 then
        explorer:set_custom_target(utils.get_horde_gate():get_position())
        explorer:move_to_target()
    elseif not tracker.teleported_from_town or not (utils.player_in_zone("Kehj_Caldeum") or utils.player_in_zone("S05_BSK_Prototype02")) then
        -- Teleport to the Library waypoint
        teleport_to_waypoint(enums.waypoints.LIBRARY)

        -- Set the flag to true after teleporting
        tracker.teleported_from_town = true
        walking_to_horde_task.last_teleport_time = current_time
        walking_to_horde_task.current_waypoint_index = 1

        console.print("Teleported to Library waypoint, waiting for " .. walking_to_horde_task.teleport_wait_time .. " seconds")
    elseif current_time - walking_to_horde_task.last_teleport_time >= walking_to_horde_task.teleport_wait_time then
        local current_waypoint = walking_to_horde_task.waypoints[walking_to_horde_task.current_waypoint_index]
        
        if current_waypoint then
            -- Set the custom target to the current waypoint
            explorer:set_custom_target(current_waypoint)

            -- Move to the target
            explorer:move_to_target()

            -- Check distance to current waypoint
            local distance_to_waypoint = utils.distance_to(current_waypoint)
            if distance_to_waypoint < 2 then
                -- Move to the next waypoint
                walking_to_horde_task.current_waypoint_index = walking_to_horde_task.current_waypoint_index + 1
                console.print("Reached waypoint " .. (walking_to_horde_task.current_waypoint_index - 1) .. ", moving to next")
            end
        else
            -- All waypoints have been reached
            tracker.teleported_from_town = false
            walking_to_horde_task.current_waypoint_index = 1
            walking_to_horde_task.arrived_destination = true
            console.print("Walking to Horde task completed")
            return true
        end
    else
        console.print("Waiting for teleport cooldown... " .. string.format("%.2f", walking_to_horde_task.teleport_wait_time - (current_time - walking_to_horde_task.last_teleport_time)) .. " seconds left")
    end

    return false
end

return walking_to_horde_task