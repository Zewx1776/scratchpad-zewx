local utils = require "core.utils"
local enums = require "data.enums"
local tracker = require "core.tracker"
local settings = require "core.settings"
local explorer = require "core.explorer"

local task  = {
    name = "Explore Undercity",
    shouldExecute = function()
        return utils.player_in_find_zone(enums.zone_names.undercity_zone) and not tracker.exit_undercity
    end,
    Execute = function()
        local warp_pad = utils.get_warp_pad()
        if warp_pad then
            if tracker.warp_pad_position == nil then
                tracker.warp_pad_position = warp_pad:get_position()
                console.print("Saved warp pad position")
            end
        end

        if tracker.enticement_active >= settings.enticement_slider and tracker.warp_pad_position then
            console.print("Moving to warp pad")
            explorer:clear_path_and_target()
            explorer:set_custom_target(tracker.warp_pad_position)
            explorer:move_to_target()
            return
        end

        if utils.player_in_boss_room() then
            tracker.player_in_boss_room = true
        end

        if tracker.killing_boss and tracker.player_in_boss_room then
            if not utils.get_boss() then
                tracker.killing_boss = false
                tracker.finish_undercity = true
                console.print("Boss has been killed!")
            end
        end

        if tracker.finish_undercity then
            if utils.check_if_there_is_a_stash() then
                local have_item, item_pos = utils.find_nearby_items()
                if have_item then
                    local player_pos = get_player_position()
                    if player_pos:dist_to_ignore_z(item_pos) > 3 then
                        console.print("Move near items")
                        pathfinder.request_move(item_pos)
                    end
                end

                if tracker.wait_to_exit == 0 and tracker.player_in_boss_room and utils.player_in_find_zone(enums.zone_names.undercity_zone) then
                    tracker.wait_to_exit = 11
                    console.print("Wait to exit: " .. tostring(tracker.wait_to_exit) .. " seconds")
                end
            end
        end
    end
}
return task
