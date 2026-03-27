local utils = require "core.utils"
local explorer = require "core.explorer"
local tracker = require "core.tracker"
local enums = require "data.enums"

local task = {
    name = "Kill Boss",
    shouldExecute = function()
        local boss = utils.get_boss()
        return boss and tracker.player_in_boss_room
    end,
    Execute = function()
        local boss = utils.get_boss()
        local boss_pos = boss:get_position()
        explorer:set_custom_target(boss_pos)
        pathfinder.request_move(boss_pos)
        tracker.killing_boss = true

        console.print("Moving to boss, killing boss")
    end
}

return task