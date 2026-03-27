local utils = require "core.utils"
local explorer = require "core.explorer"
local tracker = require "core.tracker"

local task = {
    name = "Interact Beacon",
    shouldExecute = function()
        local beacon = utils.get_beacon()
        if beacon then
            local is_beacon_interactable = beacon:is_interactable()
            if not is_beacon_interactable then
                tracker.interacting_beacon = false
            end
            return is_beacon_interactable
        end
        return false
    end,
    Execute = function()
        local beacon = utils.get_beacon()
        if beacon then
            if beacon:is_interactable() then
                explorer:clear_path_and_target()
                explorer:set_custom_target(beacon:get_position())
                if utils.distance_to(beacon) < 4 then
                    tracker.interacting_beacon = true
                    interact_object(beacon)
                    console.print("Interacting with beacon")
                else
                    explorer:move_to_target()
                    console.print("Moving to beacon")
                end
            end
        else
            console.print("Found but not interactable")
        end
    end
}
return task
