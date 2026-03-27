-- Import required modules
local utils      = require "core.utils"
local enums      = require "data.enums"
local tracker    = require "core.tracker"
local explorer   = require "core.explorer"
local settings   = require "core.settings"
local explorerlite = require "core.explorerlite"

-- Add this function at the top of the file after the imports
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
                console.print("Successfully used movement spell to unstuck target.")
            end
        end
    end
end

-- Variables for stuck detection
local last_position = nil
local last_move_time = 0
local stuck_threshold = 2  -- Seconds before considering player stuck
local last_unstuck_attempt_time = 0
local unstuck_cooldown = 3  -- Seconds between unstuck attempts
local unstuck_attempt_timeout = 5  -- 5 seconds timeout
local unstuck_attempt_start = 0

-- Function to find and return the altar actor
local function interact_with_altar()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        -- Check if the actor is one of the boss altars
        if name == "Boss_WT4_Varshan" or name == "Boss_WT4_Duriel" or name == "Boss_WT4_PenitantKnight" or name == "Boss_WT4_Andariel" or name == "Boss_WT4_MegaDemon" or name == "Boss_WT4_S2VampireLord" or name == "Boss_WT5_Urivar" or name == "Boss_WT_Belial" then
            return actor
        end
    end
    return nil
end

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

-- Variable to track the time when the boss was last summoned
local boss_summon_time = 0

-- Define the task
local task = {
    name = "Interact Altar",
    
    -- Function to determine if the task should be executed
    shouldExecute = function()
        -- Get current zone silently without debug prints
        local current_zone = get_current_world():get_current_zone_name()
        
        local is_wt4 = utils.match_player_zone("Boss_WT4_")
        local is_wt3 = utils.match_player_zone("Boss_WT3_")
        local is_belial = utils.match_player_zone("Boss_Kehj_Belial")
        local is_wt5 = utils.match_player_zone("Boss_WT5_")
        
        local is_in_boss_zone = is_wt4 or is_wt3 or is_belial or is_wt5
        
        local altar = interact_with_altar()
        
        local should_execute = is_in_boss_zone and altar ~= nil
        
        return should_execute
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
                --explorerlite:clear_path_and_target()
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

        -- Wait for 5 seconds after boss summon before allowing interaction again
        if boss_summon_time > 0 and current_time - boss_summon_time < 1 then
            return
        end

        local altar = interact_with_altar()
        if altar then
            local actor_position = altar:get_position()
            -- Move towards the altar if not close enough
            if utils.distance_to(actor_position) > 2 then
                console.print("Moving to altar")
                --explorerlite:clear_path_and_target()
                explorerlite:set_custom_target(actor_position)
                explorerlite:move_to_target()
            end

            -- Interact with the altar when close enough
            if utils.distance_to(actor_position) <= 2 then
                console.print("Interacting with altar")
                interact_object(altar)
                utility.summon_boss()
                settings.altar_activated = true
                boss_summon_time = current_time  -- Update the boss summon time
            end
        end

        -- Mark the task as not running
        explorer.is_task_running = false
    end
}

-- Return the task
return task