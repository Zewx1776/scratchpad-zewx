local utils = require "core.utils"

local task = {
    name = "Open Undercity Portal",
    shouldExecute = function()
        local portal = utils.get_undercity_portal()
        return utils.get_undercity_brazier() and not portal
    end,
    Execute = function()
        local brazier = utils.get_undercity_brazier()
        if brazier then
            if utils.distance_to(brazier) < 2 then
                interact_object(brazier)
            else
                pathfinder.request_move(brazier:get_position())
            end
        end
    end
}

return task
