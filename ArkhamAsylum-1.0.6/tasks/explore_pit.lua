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
    name = 'explore_pit', -- change to your choice of task name
    status = status_enum['IDLE'],
    portal_found = false,
    portal_exit = -1
}
task.shouldExecute = function ()
    return (utils.player_in_zone("EGD_MSWK_World_02") or
        utils.player_in_zone("EGD_MSWK_World_01"))
end
task.Execute = function ()
    local local_player = get_local_player()
    if not local_player then return end
    orbwalker.set_clear_toggle(true)
    BatmobilePlugin.set_priority(plugin_label, settings.batmobile_priority)
    BatmobilePlugin.resume(plugin_label)
    BatmobilePlugin.update(plugin_label)
    BatmobilePlugin.move(plugin_label)
    task.status = status_enum['EXPLORING']
end

return task