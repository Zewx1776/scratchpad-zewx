local plugin_label = 'arkham_asylum' -- change to your plugin name

local utils = require "core.utils"
local settings = require 'core.settings'
local tracker = require 'core.tracker'

local status_enum = {
    IDLE = 'idle',
    WALKING = 'walking to shrine',
    INTERACTING = 'interacting '
}
local task = {
    name = 'interact_shrine', -- change to your choice of task name
    status = status_enum['IDLE'],
}
local get_closest_shrine = function ()
    local local_player = get_local_player()
    if not local_player then return end
    local actors = actors_manager:get_ally_actors()
    local closest_shrine, closest_dist
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if (name:match('Shrine_DRLG') and actor:is_interactable()) or
            name:match('BetrayersEyeSwitch')
        then
            local dist = utils.distance(local_player, actor)
            if dist < settings.check_distance and (closest_dist == nil or dist < closest_dist) then
                closest_dist = dist
                closest_shrine = actor
            end
        end
    end
    return closest_shrine
end

task.shouldExecute = function ()
    return settings.interact_shrine and
        get_closest_shrine() ~= nil and
        (utils.player_in_zone("EGD_MSWK_World_02") or
        utils.player_in_zone("EGD_MSWK_World_01"))
end
task.Execute = function ()
    local local_player = get_local_player()
    if not local_player then return end
    BatmobilePlugin.pause(plugin_label)
    BatmobilePlugin.update(plugin_label)

    local shrine = get_closest_shrine()
    if shrine ~= nil then
        if utils.distance(local_player, shrine) > 2 then
            local disable_spell = false
            if utils.distance(local_player, shrine) <= 4 then
                disable_spell = true
            end
            BatmobilePlugin.set_target(plugin_label, shrine, disable_spell)
            BatmobilePlugin.move(plugin_label)
            task.status = status_enum['WALKING']
        else
            BatmobilePlugin.clear_target(plugin_label)
            task.status = status_enum['WALKING']
            orbwalker.set_clear_toggle(false)
            interact_object(shrine)
        end
    end
end

return task