-- Import required modules
local utils = require "core.utils"
local enums = require "data.enums"
local explorerlite = require "core.explorerlite"
local settings = require "core.settings"

-- Variables for stuck detection
local last_position = nil
local last_move_time = 0
local stuck_threshold = 20  -- Seconds before considering player stuck
local last_unstuck_attempt_time = 0
local unstuck_cooldown = 30  -- Seconds between unstuck attempts
local unstuck_attempt_timeout = 5  -- 5 seconds timeout
local unstuck_attempt_start = 0

-- Variables for chest interaction cooldown
local last_chest_interaction_time = 0
local chest_interaction_cooldown = 10  -- 5 seconds cooldown between chest interactions

-- Function to find and return any EGB chest actor or Boss_WT_Belial_Chest
local function find_egb_chest()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        -- Check if the actor name starts with EGB_Chest or is Boss_WT_Belial_Chest
        if name:find("EGB_Chest") == 1 or name == "Boss_WT_Belial_Chest" then
            console.print("Found chest: " .. name)
            return actor
        end
    end
    return nil
end

-- Function to check if player is stuck
local function check_if_stuck()
    local current_pos = get_player_position()
    local current_time = os.time()

    if last_position and utils.distance_to(last_position) < 0.1 then
        if current_time - last_move_time > stuck_threshold then
            -- Check cooldown
            if current_time - last_unstuck_attempt_time >= unstuck_cooldown then
                last_unstuck_attempt_time = current_time
                return true
            end
        end
    else
        last_move_time = current_time
    end

    last_position = current_pos
    return false
end

-- Add this function to use movement abilities to unstuck
local function movement_spell_to_target(target)
    local local_player = get_local_player()
    if not local_player then return end

    local movement_spell_id = {
        288106, -- Sorcerer teleport
        358761, -- Rogue dash
        355606, -- Rogue shadow step
        1663206, -- spiritborn hunter 
        1871821, -- spiritborn soar
        337031, -- General Evade
    }

    -- Check if the dash spell is off cooldown and ready to cast
    for _, spell_id in ipairs(movement_spell_id) do
        if local_player:is_spell_ready(spell_id) then
            -- Cast the dash spell towards the target's position
            local success = cast_spell.position(spell_id, target, 3.0)
            if success then
                console.print("Successfully used movement spell to target.")
                return true
            end
        end
    end
    return false
end

-- Define the task
local task = {
    name = "Open EGB Chest",
    
    -- Function to determine if the task should be executed
    shouldExecute = function()
        -- Check if any EGB chest is present
        local chest = find_egb_chest()
        return chest ~= nil
    end,

    -- Main execution function for the task
    Execute = function()
        local current_time = get_time_since_inject()
        
        -- Check if player is stuck
        if check_if_stuck() then
            local current_time = get_time_since_inject()
            
            if unstuck_attempt_start == 0 then
                unstuck_attempt_start = current_time
            elseif current_time - unstuck_attempt_start > unstuck_attempt_timeout then
                console.print("Unstuck attempt timed out, resetting")
                unstuck_attempt_start = 0
                return
            end
            
            console.print("Player appears to be stuck, finding unstuck target")
            local unstuck_target = explorerlite.find_unstuck_target()
            if unstuck_target then
                console.print("Moving to unstuck target")
                explorerlite:set_custom_target(unstuck_target)
                -- Try movement spell first
                movement_spell_to_target(unstuck_target)
                -- Then force move as backup
                pathfinder.force_move_raw(unstuck_target)
                
                -- Check if we've reached the unstuck target
                if utils.distance_to(unstuck_target) < 1 then
                    console.print("Reached unstuck target")
                    return
                else
                    console.print("Distance to unstuck target: " .. utils.distance_to(unstuck_target))
                end
            else
                console.print("Failed to find unstuck target")
            end
        else
            unstuck_attempt_start = 0
        end

        -- Find any EGB chest
        local chest = find_egb_chest()
        if chest then
            local actor_position = chest:get_position()
            local chest_name = chest:get_skin_name()
            console.print("Moving to chest: " .. chest_name)
            
            -- Move towards the chest if not close enough
            if utils.distance_to(actor_position) > 2 then
                explorerlite:set_custom_target(actor_position)
                explorerlite:move_to_target()
            end

            -- Interact with the chest when close enough and cooldown has passed
            if utils.distance_to(actor_position) <= 2 then
                local current_time = os.time()
                
                -- Check if cooldown has passed since last interaction
                if current_time - last_chest_interaction_time >= chest_interaction_cooldown then
                    local chest_name = chest:get_skin_name()
                    console.print("Interacting with chest: " .. chest_name)
                    interact_object(chest)
                    
                    -- Update the last interaction time
                    last_chest_interaction_time = current_time
                    console.print("Chest interaction cooldown started. Next interaction in " .. chest_interaction_cooldown .. " seconds.")
                else
                    local remaining = chest_interaction_cooldown - (current_time - last_chest_interaction_time)
                    console.print("Chest interaction on cooldown. " .. remaining .. " seconds remaining.")
                end
            end
        end
    end
}

-- Return the task
return task
