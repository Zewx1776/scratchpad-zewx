local tracker = require "core.tracker"
local utils = require "core.utils"
local enums = require "data.enums"

local task = {
    name = "Exit Undercity",
    shouldExecute = function()
        return tracker.exit_undercity and tracker.player_in_boss_room and utils.player_in_find_zone(enums.zone_names.undercity_zone)
    end,
    Execute = function()
        tracker.exit_undercity = false
        reset_all_dungeons()
    end
}
return task
