local utils = require "core.utils"
local enums = require "data.enums"
local explorer = require "core.explorer"
local settings = require "core.settings"

local task = {
    name = "Move to Suppressor",
    shouldExecute = function()
        local is_in_boss_zone = utils.match_player_zone("Boss_WT4_") or utils.match_player_zone("Boss_WT3_")
        return is_in_boss_zone and utils.get_suppressor() ~= nil
    end,

    Execute = function()
        local suppressor = utils.get_suppressor()
        if suppressor then
            local suppressor_pos = suppressor:get_position()
            --explorer:clear_path_and_target()
            --explorer:set_custom_target(suppressor_pos)
            --explorer:move_to_target()
            pathfinder.force_move_raw(suppressor_pos)
            console.print("Moving to suppressor")
        else
            console.print("No suppressor found")
        end
    end
}

return task