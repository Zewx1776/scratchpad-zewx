local plugin_label = 'azmodan_farm' -- change to your plugin name

local utils = require "core.utils"
local settings = require 'core.settings'
local explorerlite = require "core.explorerlite"

local status_enum = {
    INIT = "INIT",
    MOVING_TO_NPC = "MOVING_TO_NPC",
    INTERACTING_WITH_NPC = "INTERACTING_WITH_NPC",
    WAITING = 'WAITING_FOR_LOOT'
}
local task = {
    name = 'open_chest', -- change to your choice of task name
    status = status_enum.INIT,
    last_opened = -1
}
local key_id_chest_map = {
    [2429465] = "S11_AzmodanTakeover_Chest_Andariel",
    [2429469] = "S11_AzmodanTakeover_Chest_Belial",
    [2429471] = "S11_AzmodanTakeover_Chest_Duriel"
}
local function getInteractableChest()
    local local_player = get_local_player()
    if not local_player then return nil end
    local consumables = local_player:get_consumable_items()
    local chest_name = nil
    for _, item in pairs(consumables) do
        if key_id_chest_map[item:get_sno_id()] ~= nil and
            item:get_stack_count() >= 5
        then
            if chest_name == nil then
                chest_name = key_id_chest_map[item:get_sno_id()]
            elseif key_id_chest_map[item:get_sno_id()]:match(settings.priority) then
                chest_name = key_id_chest_map[item:get_sno_id()]
            end
        end
    end
    local actors = actors_manager:get_ally_actors()
    for _, actor in pairs(actors) do
        if actor:is_interactable() then
            local actor_name = actor:get_skin_name()
            if actor_name == chest_name then
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
local function wait_for_loot(npc)
    if npc then
        interact_object(npc)
    end
    if task.last_opened + 10 < get_time_since_inject() then
        task.current_state = status_enum.INIT
    end
end

function task.shouldExecute()
    return (settings.open_chest and getInteractableChest() ~= nil) or task.current_state == status_enum.WAITING
end

function task.Execute()
    if LooteerPlugin then
        local looting = LooteerPlugin.getSettings('looting')
        if looting then return end
    end
    local npc = getInteractableChest()
    if task.current_state == status_enum.INIT then
        init_interact()
    elseif npc and utils.distance_to(npc) > 2 and task.current_state ~= status_enum.MOVING_TO_NPC then
        init_interact()
    elseif task.current_state == status_enum.MOVING_TO_NPC then
        move_to_npc(npc)
    elseif task.current_state == status_enum.INTERACTING_WITH_NPC then
        interact_npc(npc)
    elseif task.current_state == status_enum.WAITING then
        wait_for_loot(npc)
    end
end

return task