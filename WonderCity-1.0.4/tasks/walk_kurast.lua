local plugin_label = 'wonder_city' -- change to your plugin name

local utils = require 'core.utils'
local path = require 'data.path'

local status_enum = {
    IDLE = 'idle',
    WALKING = 'walking to spirit brazier'
}
local task = {
    name = 'walk_kurast', -- change to your choice of task name
    status = status_enum['IDLE'],
    debounce_time = -1,
    debounce_timeout = 3
}

task.shouldExecute = function ()
    local local_player = get_local_player()
    if not local_player then return false end
    local player_pos = local_player:get_position()
    local brazier = utils.get_spirit_brazier()
    local portal = utils.get_entrance_portal()
    return utils.player_in_zone('Naha_Kurast') and
        player_pos:x() ~= 0 and player_pos:y() ~= 0 and
        (portal == nil or utils.distance(player_pos, portal) > 5 ) and
        (brazier == nil or utils.distance(player_pos, path[#path-1]) > 4)
end
task.Execute = function ()
    local local_player = get_local_player()
    if not local_player then return end
    local player_pos = local_player:get_position()
    BatmobilePlugin.pause(plugin_label)
    local closest_distance = nil
    local closest_key = nil
    for key,point in pairs(path) do
        if closest_distance == nil or utils.distance(player_pos, point) < closest_distance then
            closest_distance = utils.distance(player_pos, point)
            closest_key = key
        end
    end
    if path[closest_key+2] ~= nil then
        BatmobilePlugin.set_target(plugin_label, path[closest_key+2])
    elseif path[closest_key+1] ~= nil then
        BatmobilePlugin.set_target(plugin_label, path[closest_key+1])
    elseif path[closest_key] ~= nil and
        utils.distance(path[closest_key], player_pos) < 30
    then
        BatmobilePlugin.set_target(plugin_label, path[closest_key])
    else
        BatmobilePlugin.clear_target(plugin_label)
        task.status = status_enum['IDLE']
        return
    end
    BatmobilePlugin.move(plugin_label)
    task.status = status_enum['WALKING']
end

return task