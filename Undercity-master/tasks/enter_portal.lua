local utils = require "core.utils"
local enums = require "data.enums"
local tracker = require "core.tracker"
local explorer = require "core.explorer"

local task = {
    name = "Enter Portal",
    shouldExecute = function()
        return utils.get_undercity_portal() and utils.player_in_zone(enums.zone_names.naha_zone)
    end,
    Execute = function()
        local portal = utils.get_undercity_portal()
        if portal then
            local player_in_naha = utils.player_in_zone(enums.zone_names.naha_zone)
            if player_in_naha then
                interact_object(portal)
                explorer.reset_exploration()
            end
        end
    end
}

return task