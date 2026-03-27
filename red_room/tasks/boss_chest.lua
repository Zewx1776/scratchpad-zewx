local plugin_label = 'red_room' -- change to your plugin name

local utils = require "core.utils"
local explorerlite = require "core.explorerlite"
local tracker = require "core.tracker"

local status_enum = {
    INIT = "INIT",
    MOVING_TO_NPC = "MOVING_TO_NPC",
    INTERACTING_WITH_NPC = "INTERACTING_WITH_NPC",
    WAITING = 'WAITING_FOR_LOOT'
}
local task = {
    name = 'open_chest', -- change to your choice of task name
    status = status_enum.INIT,
    last_opened = -1,
    debounce_time = -1,
    debounce_timeout = 5
}
local function getInteractableChest()
    local actors = actors_manager:get_ally_actors()
    for _, actor in pairs(actors) do
        if actor:is_interactable() then
            local actor_name = actor:get_skin_name()
            if actor_name == "S11_TierFight_Chest" then
                return actor
            end
        end
    end
    return nil
end
local function init_interact()
    task.current_state = status_enum.MOVING_TO_NPC
end

local function move_to_npc(npc)
    if npc then
        explorerlite:set_custom_target(npc:get_position())
        explorerlite:move_to_target()
        if utils.distance_to(npc) < 2 then
            -- console.print("Reached npc")
            task.current_state = status_enum.INTERACTING_WITH_NPC
        end
    end
end
local function interact_npc(npc)
    if npc then
        interact_object(npc)
        task.last_opened = get_time_since_inject()
        task.current_state = status_enum.WAITING
    end
end

local floor_has_loot = function ()
    return loot_manager.any_item_around(get_player_position(), 50, true, true)
end
local function wait_for_loot(npc)
    local status = AlfredTheButlerPlugin.get_status()
    if task.last_opened + 10 < get_time_since_inject() and
        floor_has_loot() and not LooteerPlugin.getSettings('looting') and
         not status.need_trigger
    then
        task.current_state = status_enum.INIT
        tracker.done = true
        tracker.done_time = get_time_since_inject()
    end
    if npc then
        interact_object(npc)
    end
end


function task.shouldExecute()
    return utils.player_in_zone('S11_WorldBossArena_BossTierAzmodan')
end

function task.Execute()
    local npc = getInteractableChest()
    local local_player = get_local_player()
    local player_pos = local_player:get_position()
    if (task.last_pos == nil or utils.distance_to(task.last_pos) < 1) and
        (task.debounce_time + task.debounce_timeout < get_time_since_inject())
    then
        local unstuck_node = vec3:new(player_pos:x() + 3, player_pos:y() +3, player_pos:z())
        cast_spell.position(337031, unstuck_node, 0)
        task.last_pos = player_pos
        task.debounce_time = get_time_since_inject()
    end
    task.last_pos = player_pos
    if task.current_state == status_enum.INIT then
        init_interact()
    elseif npc == nil and task.current_state == status_enum.MOVING_TO_NPC then
        local center_1 = vec3:new(35.845703125, 20.2001953125,46.7099609375)
        local center_2 = vec3:new(99.845703125, 20.2001953125,46.7099609375)
        if utils.distance_to(center_1) < utils.distance_to(center_2) then
            explorerlite:set_custom_target(center_1)
        else
            explorerlite:set_custom_target(center_2)
        end
        explorerlite:move_to_target()
    elseif npc and utils.distance_to(npc) > 2 and task.current_state ~= status_enum.MOVING_TO_NPC then
        init_interact()
    elseif task.current_state == status_enum.MOVING_TO_NPC then
        move_to_npc(npc)
    elseif task.current_state == status_enum.INTERACTING_WITH_NPC then
        interact_npc(npc)
    elseif task.current_state == status_enum.WAITING then
        wait_for_loot(npc)
    else
        local center_1 = vec3:new(35.845703125, 20.2001953125,46.7099609375)
        local center_2 = vec3:new(99.845703125, 20.2001953125,46.7099609375)
        if utils.distance_to(center_1) < utils.distance_to(center_2) then
            explorerlite:set_custom_target(center_1)
        else
            explorerlite:set_custom_target(center_2)
        end
        explorerlite:move_to_target()
    end
end

return task