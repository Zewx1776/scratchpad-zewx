local plugin_label = 'arkham_asylum' -- change to your plugin name

local utils = require "core.utils"
local settings = require 'core.settings'
local tracker = require 'core.tracker'

local status_enum = {
    IDLE = 'idle',
    EXPLORING = 'exploring',
    RESETING = 'reseting explorer',
    INTERACTING = 'interacting with portal',
    WALKING = 'walking to portal'
}
local task = {
    name = 'portal', -- change to your choice of task name
    status = status_enum['IDLE'],
    portal_found = false,
    portal_exit = -1
}
-- Cache portal scan to avoid double actor iteration per frame (shouldExecute + Execute)
local _portal_cache = nil
local _portal_cache_time = -1
local _portal_cache_duration = 0.01 -- 10ms, well within a single frame

local get_portal = function ()
    local now = get_time_since_inject()
    if now - _portal_cache_time < _portal_cache_duration then
        return _portal_cache
    end
    local local_player = get_local_player()
    if not local_player then return end
    local player_pos = get_player_position()
    local actors = actors_manager:get_ally_actors()
    for _, actor in pairs(actors) do
        if actor:is_interactable() then
            local actor_name = actor:get_skin_name()
            if actor_name == 'EGD_MSWK_World_PortalTileSetTravel' or
                actor_name == 'EGD_MSWK_World_PortalToFinalEncounter' or
                actor_name == 'S11_EGD_MSWK_World_BelialPortalToFinalEncounter'
            then
                local dist = utils.distance(player_pos, actor)
                if dist <= settings.check_distance then
                    _portal_cache = actor
                    _portal_cache_time = now
                    return actor
                end
            end
        end
    end
    _portal_cache = nil
    _portal_cache_time = now
    return nil
end
task.shouldExecute = function ()
    return (utils.player_in_zone("EGD_MSWK_World_02") or
        utils.player_in_zone("EGD_MSWK_World_01")) and
        (get_portal() ~= nil or task.portal_found or
        task.portal_exit + 1 >= get_time_since_inject())
end
task.Execute = function ()
    local local_player = get_local_player()
    if not local_player then return end
    orbwalker.set_clear_toggle(true)
    local portal = get_portal()
    if portal == nil then
        if task.portal_found then
            task.portal_found = false
            task.status = status_enum['RESETING']
            task.portal_exit = get_time_since_inject()
            BatmobilePlugin.reset(plugin_label)
            return
        end
    elseif utils.distance(local_player, portal) > 2 then
        local disable_spell = false
        if utils.distance(local_player, portal) <= 4 then
            disable_spell = true
        end
        BatmobilePlugin.pause(plugin_label)
        BatmobilePlugin.update(plugin_label)
        BatmobilePlugin.set_target(plugin_label, portal, disable_spell)
        BatmobilePlugin.move(plugin_label)
        task.status = status_enum['WALKING']
    else
        task.portal_found = true
        interact_object(portal)
        task.status = status_enum['INTERACTING']
    end
end

return task