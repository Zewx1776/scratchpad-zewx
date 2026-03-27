local plugin_label = 'azmodan_farm' -- change to your plugin name

local explorerlite = require "core.explorerlite"
local tracker = require "core.tracker"
local utils = require "core.utils"

local status_enum = {
    IDLE = 'idle'
}
local task = {
    name = 'afk', -- change to your choice of task name
    status = status_enum['IDLE'],
    afk_position = vec3:new(-217.6220703125, 616.873046875, 22),
    debounce_time = -1,
    debounce_timeout = 5
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

local function get_randomize_position()
    if task.debounce_time + task.debounce_timeout > get_time_since_inject() then
        return task.afk_position
    end
    local x = -217.6220703125 + math.random(-10,10)
    local y = 616.873046875 + math.random(-10,10)
    task.debounce_time = get_time_since_inject()
    return vec3:new(x, y, 22)
end

function task.shouldExecute()
    return true
end

function task.Execute()
    if orbwalker.get_orb_mode() ~= 3 then
        orbwalker.set_clear_toggle(true);
    end
    local azmodan = get_azmodan_enemy()
    if azmodan ~= nil then
        if tracker.azmodan_start == nil then
            tracker.azmodan_start = os.clock()
        end
        explorerlite:set_custom_target(azmodan:get_position())
        explorerlite:move_to_target()
    elseif utils.distance_to(vec3:new(-217.6220703125, 616.873046875, 22)) > 30 then
        explorerlite:set_custom_target(vec3:new(-217.6220703125, 616.873046875, 22))
        explorerlite:move_to_target()
    else
        task.afk_position = get_randomize_position()
        explorerlite:set_custom_target(task.afk_position)
        explorerlite:move_to_target()
    end
end

return task