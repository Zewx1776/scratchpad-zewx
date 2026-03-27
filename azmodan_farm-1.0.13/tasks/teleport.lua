local plugin_label = 'azmodan_farm' -- change to your plugin name

local utils = require "core.utils"

local status_enum = {
    IDLE = 'idle'
}
local task = {
    name = 'teleport', -- change to your choice of task name
    status = status_enum['IDLE']
}
function task.shouldExecute()
    return not utils.player_in_zone('Hawe_Zarbinzet') and
        not utils.player_in_zone('Hawe_WorldBoss')
end

function task.Execute()
    teleport_to_waypoint(0xA46E5)
end

return task