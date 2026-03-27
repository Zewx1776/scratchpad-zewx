local utils      = require "core.utils"
local enums      = require "data.enums"
local settings   = require "core.settings"
local navigation = require "core.navigation"
local explorerlite = require "core.explorerlite"
local tracker    = require "core.tracker"

local stuck_position = nil

-- Function to move player to specific position in Belial boss zone
local function move_to_belial_position()
    local current_zone = get_current_world():get_current_zone_name()
    if current_zone == "Boss_Kehj_Belial" then
        -- Create a vec3 position object with the provided coordinates
        local belial_position = vec3:new(-2.96484375, -10.4716796875, 0.095703125)
        
        -- Move player to the position directly using pathfinder instead of explorerlite
        console.print("Moving directly to Belial position using pathfinder")
        pathfinder.request_move(belial_position)
        
        return true
    end
    return false
end

local task = {
    name = "Kill Monsters",
    shouldExecute = function()
       -- if not utils.player_on_quest(get_current_world():get_current_zone_name()) then
       --     return false
       -- end

        -- Check if we're in Belial boss zone first
        if get_current_world():get_current_zone_name() == "Boss_Kehj_Belial" then
            return true
        end

        local close_enemy = utils.get_closest_enemy()
        return close_enemy ~= nil
    end,
    Execute = function()
        local player_pos = get_player_position()

        if explorerlite.check_if_stuck() then
            stuck_position = player_pos
            return false
        end

        if stuck_position and utils.distance_to(stuck_position) < 10 then
            return false
        else
            stuck_position = nil
        end

        -- Check if we're in Belial boss zone and move to the specified position if true
        if move_to_belial_position() then
            return true
        end

        local enemy = utils.get_closest_enemy()
        if not enemy then return false end

        local within_distance = utils.distance_to(enemy) < 6.5
        
        tracker.finished_time = 0
        tracker.start_time = 0

        if not within_distance then
            local enemy_pos = enemy:get_position()

            --explorerlite:clear_path_and_target()
            explorerlite:set_custom_target(enemy_pos)
            explorerlite:move_to_target()
        end
    end
}

return task