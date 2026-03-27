local utils = require "core.utils"
local explorer = require "core.explorer"
local tracker = require "core.tracker"

local task = {
    name = "Interact Enticement",
    shouldExecute = function()
        local enticement = utils.get_enticement()
        if enticement then
            local enticement_pos = enticement:get_position()
            local enticement_pos_text = "x" .. tostring(enticement_pos:x()) .. " y" .. tostring(enticement_pos:y())
            local actived_enticement = utils.is_actived_enticement(enticement_pos_text)
            return enticement and not actived_enticement
        end
        return false
    end,
    Execute = function()
        local enticement = utils.get_enticement()
        if enticement then
            local enticement_pos = enticement:get_position()
            local enticement_pos_text = "x" .. tostring(enticement_pos:x()) .. " y" .. tostring(enticement_pos:y())
            local actived_enticement = utils.is_actived_enticement(enticement_pos_text)
            if not actived_enticement then
                explorer:clear_path_and_target()
                explorer:set_custom_target(enticement:get_position())
                if utils.distance_to(enticement) < 2 then
                    interact_object(enticement)
                    if not enticement:is_interactable() then
                        tracker.actived_enticement[enticement_pos_text] = true
                        tracker.enticement_active = tracker.enticement_active + 1
                        console.print("Finished interacting with enticement")
                    end
                else
                    explorer:move_to_target()

                    console.print("Moving to enticement")
                end
            end
        else
            console.print("Found but not interactable")
        end
    end
}
return task
