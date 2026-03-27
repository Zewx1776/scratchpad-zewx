local plugin_label = 'azmodan_farm' -- change to your plugin name

local explorerlite = require "core.explorerlite"
local tracker = require "core.tracker"

local status_enum = {
    IDLE = 'idle'
}
local task = {
    name = 'timer', -- change to your choice of task name
    status = status_enum['IDLE'],
}

local function get_azmodan_enemy()
    local player_pos = get_player_position()
    local enemies = target_selector.get_near_target_list(player_pos, 50)
    for _, enemy in pairs(enemies) do
        if enemy.get_skin_name(enemy) == 'Azmodan_EventBoss' then
            return enemy
        end
    end
    return nil
end

function task.shouldExecute()
    return get_azmodan_enemy() == nil and tracker.azmodan_start ~= nil
end

function task.Execute()
    local timer = os.clock() - tracker.azmodan_start
    local min = string.format("%.0f",timer/60)
    local sec = string.format("%.2f",timer%60)
    tracker.azmodan_timer[#tracker.azmodan_timer+1] = min .. 'm ' .. sec .. 's'
    tracker.azmodan_start = nil
end

return task