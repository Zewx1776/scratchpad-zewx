local plugin_label = 'wonder_city' -- change to your plugin name

local utils = require "core.utils"
local settings = require 'core.settings'
local tracker = require 'core.tracker'

local status_enum = {
    IDLE = 'idle',
    WALKING = 'walking to ',
    OPENING = 'opening undercity',
    ENTERING = 'entering undercity',
    WAITING = 'waiting '
}
local task = {
    name = 'enter_undercity', -- change to your choice of task name
    status = status_enum['IDLE'],
    interacted = false,
    debounce_time = -1
}
local open_portal = function (delay)
    task.status = status_enum['OPENING']
    local spirit_brazier = utils.get_spirit_brazier()
    if spirit_brazier.get_position == nil then return end
    if not loot_manager:is_in_vendor_screen() and not task.interacted then
        interact_object(spirit_brazier)
    elseif not task.interacted then
        task.interacted = true
        -- call d4asistant here to trigger focus and insert tribute
    end
    if loot_manager:is_in_vendor_screen() then
        task.status = status_enum['WAITING'] .. 'for d4 assistant'
    elseif delay and
        task.debounce_time + settings.confirm_delay > get_time_since_inject()
    then
        task.status = status_enum['WAITING'] .. 'for confirmation'
        return
    else
        task.interacted = false
    end
    task.debounce_time = get_time_since_inject()
end
local enter_portal = function (portal)
    interact_object(portal)
    BatmobilePlugin.reset(plugin_label)
    tracker.undercity_start_time = get_time_since_inject()
    tracker.exit_trigger_time = nil
    tracker.exit_reset = false
    tracker.boss_trigger_time = nil
    tracker.boss_kill_time = nil
    tracker.enticement = {}
    tracker.done = false
    task.status = status_enum['ENTERING']
end
local walk_to_activator = function (activator)
    BatmobilePlugin.set_target(plugin_label, activator)
    BatmobilePlugin.move(plugin_label)
    task.status = status_enum['WALKING'] .. 'spirit brazier'
end
task.shouldExecute = function ()
    local should_execute =  utils.player_in_zone('Naha_Kurast')
    return should_execute
end
task.Execute = function ()
    local local_player = get_local_player()
    if not local_player then return end
    BatmobilePlugin.pause(plugin_label)

    local player_pos = local_player:get_position()
    local spirit_brazier = utils.get_spirit_brazier()
    local portal = utils.get_entrance_portal()

    if portal ~= nil then
        if utils.distance(player_pos, portal) > 2 then
            BatmobilePlugin.set_target(plugin_label, portal)
            BatmobilePlugin.move(plugin_label)
            task.status = status_enum['WALKING'] .. 'portal'
        else
            enter_portal(portal)
        end
    elseif utils.distance(player_pos, spirit_brazier) > 2 then
        walk_to_activator(spirit_brazier)
    elseif not settings.party_enabled then
        BatmobilePlugin.clear_target(plugin_label)
        open_portal(false)
    elseif settings.party_mode == 0 then
        BatmobilePlugin.clear_target(plugin_label)
        open_portal(true)
    else
        BatmobilePlugin.clear_target(plugin_label)
        if task.status ~= status_enum['WAITING'] .. 'for portal' and
            settings.use_magoogle_tool and settings.party_enabled and
            settings.party_mode == 1
        then
            -- contact magoogle tool accepting portal
        end
        task.status = status_enum['WAITING'] .. 'for portal'
    end
end

return task