local Movement = require("functions.movement")
local interactive_patterns = require("enums.interactive_patterns")
local explorer = require("data.explorer")
local PathCalculator = require("functions.path_calculator")
local RouteOptimizer = require("functions.route_optimizer")

local waypoints_visited = {}  -- Table for tracking visited waypoints
local total_waypoints = 0     -- Total waypoints on the route
local ChestsInteractor = {}
local missed_chests = {}
local current_direction = "forward" -- "forward" or "backward"
local last_waypoint_index = nil
local target_missed_chest = nil
local MAX_INTERACTION_ATTEMPTS = 5
local current_attempt = 0
local last_interaction_time = 0
local INTERACTION_COOLDOWN = 0.5 -- seconds between attempts
local check_start_time = nil
local cinders_before = nil
local VFX_CHECK_INITIAL_WAIT = 4  -- Initial waiting time
local VFX_CHECK_TIMEOUT = 5       -- Maximum waiting time
local failed_attempts = 0
local MAX_TIME_STUCK_ON_CHEST = 30  -- maximum seconds trying to interact with a chest
local MAX_ATTEMPTS_BEFORE_SKIP = 3   -- maximum attempts before jumping the chest
local last_chest_interaction_time = 0 -- time of last interaction with the current chest
local COMPLETION_THRESHOLD = 0.95 -- 95% of waypoints
local MAX_TIME_TRYING_TO_REACH = 60  -- Maximum time trying to reach the chest
local MIN_MOVEMENT_DISTANCE = 1.0 -- Minimum distance to consider movement
local STUCK_CHECK_INTERVAL = 15          -- More spaced out checks if you are stuck at is stuck reaching chest
local MAX_STUCK_COUNT = 3               -- Even more attempts
local INTERACTION_RETRY_DISTANCE = 2     

-- Variáveis de controle
local last_explorer_position = nil
local explorer_start_time = nil
local last_check_time = nil
local stuck_count = 0

local function find_valid_chest(objects, interactive_patterns)
    for _, obj in ipairs(objects) do
        if is_valid_chest(obj, interactive_patterns) and not is_blacklisted(obj) then
            local obj_name = obj:get_skin_name()
            console.print(string.format("Found valid chest: %s", obj_name))
            return obj
        end
    end
    return nil
end

local function is_valid_chest(obj, interactive_patterns)
    if not obj then return false end
    
    local obj_name = obj:get_skin_name()
    if not obj_name then return false end
    
    -- Verifica se está na tabela de padrões interativos
    if not interactive_patterns[obj_name] then
        console.print(string.format("Object '%s' is not in the pattern table", obj_name))
        return false
    end
    
    return true
end

local function reset_chest_tracking()
    explorer_start_time = nil
    last_explorer_position = nil
    last_check_time = nil
    stuck_count = 0
    console.print("Chest tracking status reset")
end

local function is_stuck_reaching_chest()
    local current_time = os.clock()
    
    -- Inicialização
    if not explorer_start_time then
        explorer_start_time = current_time
        last_explorer_position = get_local_player():get_position()
        last_check_time = current_time
        stuck_count = 0
        console.print("Starting tracking the new chest")
        return false
    end

    if current_time - explorer_start_time > MAX_TIME_TRYING_TO_REACH then
        console.print("Maximum time exceeded trying to reach chest")
        reset_chest_tracking()
        return true  -- This would make the script give up and move on
    end
    
    -- Initial grace period (15 seconds)
    if current_time - explorer_start_time < 15 then
        return false
    end
    
    -- Check if you are close enough to try to interact
    if targetObject then
        local player_pos = get_local_player():get_position()
        local target_pos = targetObject:get_position()
        local distance = player_pos:dist_to(target_pos)
        
        if distance <= INTERACTION_RETRY_DISTANCE then
            console.print(string.format("Near the chest (%.2f meters) - Trying to interact", distance))
            return false
        end
    end
    
    -- Check movement periodically
    if current_time - last_check_time >= STUCK_CHECK_INTERVAL then
        local current_position = get_local_player():get_position()
        local distance_moved = current_position:dist_to(last_explorer_position)
        
        console.print(string.format(
            "Progress to the chest:\n" ..
            "- Distance moved: %.2f\n" ..
            "- Elapsed time: %.1f/%.1f seconds\n" ..
            "- Attempts: %d/%d",
            distance_moved,
            current_time - explorer_start_time,
            MAX_TIME_TRYING_TO_REACH,
            stuck_count,
            MAX_STUCK_COUNT
        ))
        
        -- Update position and time
        last_explorer_position = current_position
        last_check_time = current_time
        
        if distance_moved < MIN_MOVEMENT_DISTANCE then
            stuck_count = stuck_count + 1
            console.print(string.format("Warning: Limited motion detected (%d/%d)", 
                stuck_count, MAX_STUCK_COUNT))
            
            -- Try repositioning if it is close
            if targetObject then
                local distance_to_chest = current_position:dist_to(targetObject:get_position())
                if distance_to_chest <= INTERACTION_RETRY_DISTANCE then
                    console.print("Near the chest - Trying to reposition")
                    return false
                end
            end
            
            if stuck_count >= MAX_STUCK_COUNT then
                console.print("Giving up after multiple attempts without progress")
                reset_chest_tracking()
                return true
            end
        else
            if stuck_count > 0 then
                console.print("Motion detected - resetting counter")
                stuck_count = 0
            end
        end
    end
    
    return false
end

local function should_return_to_missed_chests()
    local current_cinders = get_helltide_coin_cinders()
    local player_pos = get_local_player():get_position()
    local MAX_RETURN_DISTANCE = 10
    
    --console.print("Verificando baús perdidos. Cinders atuais: " .. current_cinders)
    
    for key, chest in pairs(missed_chests) do
        local distance = player_pos:dist_to(chest.position)
        console.print(string.format("Lost chest: %s requires %d cinders (distance: %.2f meters)", 
            chest.name, chest.required_cinders, distance))
            
        if current_cinders >= chest.required_cinders and distance <= MAX_RETURN_DISTANCE then
            console.print("We have enough cinders and adequate distance to return!")
            return true
        end
    end
    
    if next(missed_chests) == nil then
        --console.print("Nenhum baú perdido registrado")
    end
    return false
end

local function get_nearest_missed_chest()
    local player_pos = get_local_player():get_position()
    local nearest_chest = nil
    local min_distance = math.huge
    local current_cinders = get_helltide_coin_cinders()
    
    for key, chest in pairs(missed_chests) do
        if current_cinders >= chest.required_cinders then
            local distance = player_pos:dist_to(chest.position)
            if distance < min_distance then
                min_distance = distance
                nearest_chest = chest
            end
        end
    end
    
    return nearest_chest
end

function ChestsInteractor.check_missed_chests()
    if should_return_to_missed_chests() and current_direction == "forward" then
        local nearest_chest = get_nearest_missed_chest()
        if nearest_chest then
            target_missed_chest = nearest_chest
            current_direction = "backward"
            Movement.reverse_waypoint_direction(nearest_chest.waypoint_index)
            console.print("Returning to lost chest at waypoint " .. nearest_chest.waypoint_index)
            return true
        end
    end
    return false
end

-- Colors
local color_red = color.new(255, 0, 0)
local color_green = color.new(0, 255, 0)
local color_white = color.new(255, 255, 255, 255)

-- States
local States = {
    IDLE = "IDLE",
    MOVING = "MOVING",
    INTERACTING = "INTERACTING",
    MOVING_TO_MISSED_CHEST = "MOVING_TO_MISSED_CHEST",
    VERIFYING_CHEST_OPEN = "VERIFYING_CHEST_OPEN"
}

-- State variables
local currentState = States.IDLE
local targetObject = nil
local interactedObjects = {}
local expiration_time = 0
local permanent_blacklist = {}
local temporary_blacklist = {}
local temporary_blacklist_duration = 60 -- 1 minute
local max_attempts = 5
local max_return_attempts = 2
local vfx_check_start_time = 0
local vfx_check_duration = 8
local successful_chests_opened = 0
local state_start_time = 0
local max_state_duration = 30
local max_interaction_distance = 2
local last_known_chest_position = nil
local max_chest_search_attempts = 5
local chest_search_attempts = 0
local cinders_before_interaction = 0

-- New table to track attempts by chest
local chest_attempts = {}
local current_chest_key = nil

local function increment_successful_chests()
    successful_chests_opened = successful_chests_opened + 1
    console.print("Total Helltide chests opened: " .. successful_chests_opened)
end

-- Funções auxiliares
local function get_chest_key(obj)
    if not obj then return nil end
    if type(obj) == "table" and obj.position then
        -- If it is a table with position (like target_missed_chest)
        local pos = obj.position
        return string.format("%s_%.2f_%.2f_%.2f", obj.name or "unknown", pos:x(), pos:y(), pos:z())
    elseif type(obj.get_skin_name) == "function" and type(obj.get_position) == "function" then
        -- If it is a game object
        local obj_name = obj:get_skin_name()
        local obj_pos = obj:get_position()
        return string.format("%s_%.2f_%.2f_%.2f", obj_name, obj_pos:x(), obj_pos:y(), obj_pos:z())
    end
    return nil
end

local function init_waypoint_tracking()
    waypoints_visited = {}
    total_waypoints = #Movement.get_waypoints()
    console.print(string.format("Starting tracking: %d total waypoints", total_waypoints))
end

local function count_visited_waypoints()
    local count = 0
    for _ in pairs(waypoints_visited) do
        count = count + 1
    end
    return count
end

local function has_visited_all_waypoints()
    local visited_count = count_visited_waypoints()
    local threshold = math.floor(total_waypoints * COMPLETION_THRESHOLD)
    return visited_count >= threshold
end

local function count_missed_chests()
    local count = 0
    for _ in pairs(missed_chests) do
        count = count + 1
    end
    return count
end


local function clear_chest_state()
    console.print("Clearing current chest state")
    
    -- Remove the current chest from the missed_chests list
    if targetObject then
        local chest_key = get_chest_key(targetObject)
        if chest_key and missed_chests[chest_key] then
            missed_chests[chest_key] = nil
            console.print("Current chest removed from the missed_chests list")
        end
    end
    
    -- Remove target chest from missed_chests list
    if target_missed_chest then
        local chest_key = get_chest_key(target_missed_chest)
        if chest_key and missed_chests[chest_key] then
            missed_chests[chest_key] = nil
            console.print("Target chest removed from the missed_chests list")
        end
    end
    
    target_missed_chest = nil
    current_direction = "forward"
    Movement.reset_reverse_mode()
    Movement.set_moving(true)
    Movement.set_explorer_control(false)
    Movement.enable_anti_stuck()
    explorer.disable()
    currentState = States.IDLE
    
    console.print("Current chest status successfully cleared")
end

-- Function to get the next chest cost
local function get_next_cost(obj_name, current_cinders)
    local costs = interactive_patterns[obj_name]
    if type(costs) ~= "table" then 
        return nil 
    end
    
    -- Sort costs in ascending order
    local sorted_costs = {}
    for _, cost in ipairs(costs) do
        table.insert(sorted_costs, cost)
    end
    table.sort(sorted_costs)
    
    -- Look for the next cost higher than current cinders
    for _, cost in ipairs(sorted_costs) do
        if cost > current_cinders then
            console.print(string.format("Next cost for %s: %d cinders", obj_name, cost))
            return cost
        end
    end
    
    console.print(string.format("There is no next cost for %s (current cinders: %d)", obj_name, current_cinders))
    return nil
end

function ChestsInteractor.get_missed_chest_position()
    if target_missed_chest then
        return target_missed_chest.position
    end
    return nil
end

function ChestsInteractor.update_cinders()
    local current_cinders = get_helltide_coin_cinders()
end

local function get_required_cinders(obj_name)
    local required = interactive_patterns[obj_name]
    if type(required) == "table" then
        if #required > 0 then
            return math.max(unpack(required))
        else
            console.print("Warning: Empty table for " .. obj_name)
            return 0
        end
    elseif type(required) == "number" then
        return required
    else
        console.print("Warning: Standard not recognized for " .. obj_name)
        return 0
    end
end

-- Constant for pause duration
local CHEST_INTERACTION_DURATION = 5  -- seconds

local function pause_movement_for_interaction()
    Movement.set_moving(false)  -- stop movement
    Movement.set_explorer_control(false)  
    Movement.disable_anti_stuck()
    explorer.disable()
    Movement.set_interaction_end_time(os.clock() + CHEST_INTERACTION_DURATION)
    Movement.set_interacting(true)
end

-- register_missed_chest function to include all costs
local function register_missed_chest(obj, waypoint_index)
    if not obj then
        console.print("Error: Null object passed to register_missed_chest")
        return
    end

    local obj_name = obj:get_skin_name()
    if not obj_name then
        console.print("Error: Object name is null")
        return
    end

    local current_cinders = get_helltide_coin_cinders()
    local next_cost = get_next_cost(obj_name, current_cinders)
    
    if not next_cost then
        console.print("There is no next cost available for " .. obj_name)
        return
    end

    local chest_key = get_chest_key(obj)
    if not chest_key then
        console.print("Error: Unable to generate chest key")
        return
    end
    
    if not missed_chests[chest_key] then
        local obj_pos = obj:get_position()
        if not obj_pos then
            console.print("Error: Unable to obtain object position")
            return
        end

        local current_waypoint_index = Movement.get_current_waypoint_index()
        missed_chests[chest_key] = {
            name = obj_name,
            position = obj_pos,
            waypoint_index = waypoint_index or current_waypoint_index,
            required_cinders = next_cost,
            timestamp = os.clock()
        }
        
        console.print(string.format("Lost chest registered at waypoint %d. Next cost: %d cinders", 
            missed_chests[chest_key].waypoint_index, next_cost))
    end
end

local function add_to_permanent_blacklist(obj)
    if not obj then return end
    local obj_name = obj:get_skin_name()
    local obj_pos = obj:get_position()
    table.insert(permanent_blacklist, {name = obj_name, position = obj_pos})
end


local function add_to_temporary_blacklist(obj)
    if not obj then return end
    local obj_name = obj:get_skin_name()
    local obj_pos = obj:get_position()
    local expiration_time = os.clock() + temporary_blacklist_duration
    table.insert(temporary_blacklist, {name = obj_name, position = obj_pos, expires_at = expiration_time})
end


local function handle_after_interaction(obj)
    if not obj then return end
    
    -- Add to permanent blacklist if spent cinders
    local current_cinders = get_helltide_coin_cinders()
    if cinders_before_interaction > current_cinders then
        add_to_permanent_blacklist(obj)
        return
    end
    
    -- If you didn't spend cinders, check the next cost
    local obj_name = obj:get_skin_name()
    local next_cost = get_next_cost(obj_name, current_cinders)
    
    if next_cost then
        console.print(string.format("Chest has next cost of %d cinders, registering as missed chest", next_cost))
        register_missed_chest(obj)
    end
    
    add_to_temporary_blacklist(obj)
end

local function is_player_too_far_from_target()
    if not targetObject then return true end
    local player = get_local_player()
    if not player then return true end
    local player_pos = player:get_position()
    local target_pos = targetObject:get_position()
    return player_pos:dist_to(target_pos) > max_interaction_distance
end

local function has_enough_cinders(obj_name)
    local current_cinders = get_helltide_coin_cinders()
    local required_cinders = interactive_patterns[obj_name]
    
    if type(required_cinders) == "table" then
        -- Sort costs in ascending order
        local sorted_costs = {}
        for _, cost in ipairs(required_cinders) do
            table.insert(sorted_costs, cost)
        end
        table.sort(sorted_costs)
        
        -- Check the lowest cost we can pay
        for _, cost in ipairs(sorted_costs) do
            if current_cinders >= cost then
                return true
            end
        end
    elseif type(required_cinders) == "number" then
        if current_cinders >= required_cinders then
            return true
        end
    end
    
    return false
end

local function isObjectInteractable(obj, interactive_patterns, current_waypoint_index)
    if not obj then return false end
    local obj_name = obj:get_skin_name()
    local is_interactable = obj:is_interactable()
    local has_cinders = has_enough_cinders(obj_name)
    
    -- Debug temporário
    --if is_interactable then
        --console.print(string.format(
            --"Objeto verificado: %s\n" ..
            --"- Na tabela de padrões: %s\n" ..
            --"- Tem cinders: %s\n" ..
            --"- Já interagido: %s",
            --obj_name,
            --interactive_patterns[obj_name] and "Sim" or "Não",
            --has_cinders and "Sim" or "Não",
            --interactedObjects[obj_name] and "Sim" or "Não"
        --))
    --end
    
    if not has_cinders and is_interactable and interactive_patterns[obj_name] then
        register_missed_chest(obj, current_waypoint_index)
    end
    
    return interactive_patterns[obj_name] and 
           (not interactedObjects[obj_name] or os.clock() > interactedObjects[obj_name]) and
           has_cinders and
           is_interactable
end

local function is_blacklisted(obj)
    if not obj then return false end
    local obj_name = obj:get_skin_name()
    local obj_pos = obj:get_position()
    
    -- Check permanent blacklist
    for _, blacklisted_obj in ipairs(permanent_blacklist) do
        if blacklisted_obj.name == obj_name and blacklisted_obj.position:dist_to(obj_pos) < 0.1 then
            return true
        end
    end
    
    -- Check temporary blacklist
    local current_time = os.clock()
    for i, blacklisted_obj in ipairs(temporary_blacklist) do
        if blacklisted_obj.name == obj_name and blacklisted_obj.position:dist_to(obj_pos) < 0.1 then
            if current_time < blacklisted_obj.expires_at then
                return true
            else
                table.remove(temporary_blacklist, i)
                return false
            end
        end
    end
    
    return false
end

local function increment_chest_attempts()
    if current_chest_key then
        chest_attempts[current_chest_key] = (chest_attempts[current_chest_key] or 0) + 1
        return chest_attempts[current_chest_key]
    end
    return 0
end

local function get_chest_attempts()
    return current_chest_key and chest_attempts[current_chest_key] or 0
end

local function reset_chest_attempts()
    if current_chest_key then
        chest_attempts[current_chest_key] = nil
    end
end

-- Function to check if the chest has been opened
local function check_chest_opened()
    local success_by_actor = false
    local success_by_cinders = false
    
    -- Check 1: By actor name
    local actors = actors_manager.get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name == "Hell_Prop_Chest_Helltide_01_Client_Dyn" then
            console.print("Successfully opened chest (detected by actor)")
            success_by_actor = true
            break
        end
    end
    
    -- Check 2: By the difference in cinders
    local current_cinders = get_helltide_coin_cinders()
    if cinders_before_interaction and current_cinders < cinders_before_interaction then
        console.print(string.format(
            "Chest opened successfully (cinders: %d -> %d)", 
            cinders_before_interaction, 
            current_cinders
        ))
        success_by_cinders = true
    end
    
    -- If any of the checks are successful
    if success_by_actor or success_by_cinders then
        successful_chests_opened = successful_chests_opened + 1
        console.print("Total open chests: " .. successful_chests_opened)
        return true
    end
    
    return false
end

local function resume_waypoint_movement()
    -- Check if you are still in the pause time
    if Movement.get_interaction_end_time() and os.clock() < Movement.get_interaction_end_time() then
        return false  -- Does not resume movement if still in pause time
    end

    Movement.set_explorer_control(false)
    Movement.set_moving(true)
    return true
end

local function reset_state()
    -- Check if you are still in the pause time
    if Movement.get_interaction_end_time() and os.clock() < Movement.get_interaction_end_time() then
        return  -- Maintains current state if still in pause time
    end

    targetObject = nil
    last_known_chest_position = nil
    chest_search_attempts = 0
    current_attempt = 0
    last_interaction_time = 0
    last_chest_interaction_time = 0  -- Reset the time of the last interaction
    Movement.set_interacting(false)
    explorer.disable()
    Movement.set_explorer_control(false)
    Movement.enable_anti_stuck()
    state_start_time = os.clock()
    resume_waypoint_movement()
end

local function move_to_object(obj)
    -- Check if you have been trying to interact with the same chest for a long time
    if last_chest_interaction_time > 0 and os.clock() - last_chest_interaction_time > MAX_TIME_STUCK_ON_CHEST then
        console.print("Maximum time exceeded trying to interact with the chest, giving up...")
        add_to_temporary_blacklist(targetObject)
        reset_state()
        return States.IDLE
    end

    if not obj then 
        if last_known_chest_position then
            explorer.set_target(last_known_chest_position)
            explorer.enable()
            Movement.set_explorer_control(true)
            Movement.disable_anti_stuck()
            chest_search_attempts = chest_search_attempts + 1
            
            -- Check number of attempts
            if chest_search_attempts >= MAX_ATTEMPTS_BEFORE_SKIP then
                console.print("Maximum attempts reached, giving up the chest...")
                add_to_temporary_blacklist(targetObject)
                reset_state()
                return States.IDLE
            end
            
            console.print("Returning to the chest. Current attempt: " .. get_chest_attempts())
            return States.MOVING
        else
            reset_state()
            return States.IDLE
        end
    end
    
    local obj_pos = obj:get_position()
    last_known_chest_position = obj_pos
    explorer.set_target(obj_pos)
    explorer.enable()
    Movement.set_explorer_control(true)
    Movement.disable_anti_stuck()
    chest_search_attempts = 0
    last_chest_interaction_time = os.clock()  -- Updates the time of the last interaction
    console.print("Moving to the chest. Current attempt: " .. get_chest_attempts())
    return States.MOVING
end

-- Add new function to manage lost chest interaction
function ChestsInteractor.handle_missed_chest()
    if not target_missed_chest then
        console.print("Error: No target chest defined")
        return
    end

    -- Saves a copy of the chest information
    local saved_chest = {
        position = target_missed_chest.position,
        name = target_missed_chest.name,
        required_cinders = target_missed_chest.required_cinders,
        waypoint_index = target_missed_chest.waypoint_index
    }
    
    console.print("Starting interaction process with lost chestStarting interaction process with lost chest")
    Movement.set_explorer_control(true)
    explorer.set_target(saved_chest.position)
    explorer.enable()
    currentState = States.MOVING_TO_MISSED_CHEST
    
    -- Update target_missed_chest with the copy
    target_missed_chest = saved_chest
end

local stateFunctions = {
    [States.IDLE] = function(objects, interactive_patterns)
        reset_state()
        for _, obj in ipairs(objects) do
            if isObjectInteractable(obj, interactive_patterns) and not is_blacklisted(obj) then
                local new_chest_key = get_chest_key(obj)
                if new_chest_key ~= current_chest_key then
                    current_chest_key = new_chest_key
                    reset_chest_tracking()  -- Resets the trunk stuck control
                    reset_chest_attempts()
                    console.print("New chest selected. Reset attempt counter.")
                end
                targetObject = obj
                return move_to_object(obj)
            end
        end
        return States.IDLE
    end,

    [States.MOVING] = function(objects, interactive_patterns)
        if not targetObject then
            console.print("Target lost during movement")
            return States.IDLE
        end

        if not is_valid_chest(targetObject, interactive_patterns) then
            console.print("Current target is not a valid chest - resetting")
            targetObject = nil
            return States.IDLE
        end
        
        local player = get_local_player()
        if not player then return States.IDLE end
        
        local distance = player:get_position():dist_to(targetObject:get_position())
        --console.print(string.format("Distância atual até o baú: %.2f metros", distance))
        
        -- If you are close, try to interact even if you seem trapped
        if distance <= max_interaction_distance then
            console.print("Reached interaction distance - Preparing interaction")
            pause_movement_for_interaction()
            return States.INTERACTING
        end
        
        -- Only checks if it's stuck if it's far from the chest
        if Movement.is_explorer_control() and is_stuck_reaching_chest() and distance > INTERACTION_RETRY_DISTANCE then
            console.print("Detected stuck away from chest - giving up")
            add_to_temporary_blacklist(targetObject)
            reset_chest_tracking()
            
            targetObject = nil
            Movement.set_moving(true)
            Movement.set_explorer_control(false)
            Movement.enable_anti_stuck()
            explorer.disable()
            
            return States.IDLE
        end
        
        return States.MOVING
    end,

    [States.INTERACTING] = function()
        if not targetObject or not targetObject:is_interactable() then 
            console.print("Non-interactive target object")
            targetObject = nil
            if target_missed_chest then
                clear_chest_state()
                return States.IDLE
            end
            return move_to_object(targetObject)
        end
    
        if is_player_too_far_from_target() then
            console.print("Player too far from target")
            return move_to_object(targetObject)
        end
    
        -- Add cinders check before interaction
        cinders_before_interaction = get_helltide_coin_cinders()
        console.print("Cinders before interaction: " .. cinders_before_interaction)
    
        pause_movement_for_interaction()
        Movement.set_interacting(true)
        
        local obj_name = targetObject:get_skin_name()
        interactedObjects[obj_name] = os.clock() + expiration_time
        interact_object(targetObject)
        console.print("Interacting with " .. obj_name)
        
        vfx_check_start_time = os.clock()
        console.print("=== DEBUG INTERACTING ===")
        console.print("vfx_check_start_time set to: " .. vfx_check_start_time)
        return States.VERIFYING_CHEST_OPEN
    end,

    [States.VERIFYING_CHEST_OPEN] = function()
        if not vfx_check_start_time then
            vfx_check_start_time = os.clock()
            cinders_before_interaction = get_helltide_coin_cinders()
            return States.VERIFYING_CHEST_OPEN
        end
    
        local current_time = os.clock()
        local elapsed_time = current_time - vfx_check_start_time
        
        -- Checks if the cinders have change
        local current_cinders = get_helltide_coin_cinders()
        if current_cinders < cinders_before_interaction then
            console.print("Worn Cinders! Chest opened successfully")
            
            -- Pause after success
            Movement.set_moving(false)
            Movement.set_explorer_control(false)
            Movement.disable_anti_stuck()
            explorer.disable()
            Movement.set_interaction_end_time(os.clock() + CHEST_INTERACTION_DURATION)
            Movement.set_interacting(true)
            
            -- Remove the chest from the missed_chests list if it exists
            if targetObject then
                local chest_key = get_chest_key(targetObject)
                if chest_key and missed_chests[chest_key] then
                    missed_chests[chest_key] = nil
                    console.print("Chest removed from missed_chests list")
                end
                add_to_permanent_blacklist(targetObject)
            end
            
            if target_missed_chest then
                clear_chest_state()
            end

            -- Increment only once
            successful_chests_opened = successful_chests_opened + 1
            
            -- Clear the state
            failed_attempts = 0
            vfx_check_start_time = nil
            cinders_before_interaction = nil
            targetObject = nil
            
            -- Maintains the state until the end of the pause
            if Movement.get_interaction_end_time() and os.clock() < Movement.get_interaction_end_time() then
                return States.INTERACTING
            end

            -- Reset everything and go back to IDLE
            Movement.set_interacting(false)
            Movement.set_moving(true)
            Movement.enable_anti_stuck()
            Movement.set_interacting(false)
            return States.IDLE
        end
    
        -- Verify timeout
        if elapsed_time > vfx_check_duration then
            failed_attempts = failed_attempts + 1
            console.print(string.format(
                "Attempt %d failed - Cinders did not change (Before: %d, Current: %d)",
                failed_attempts,
                cinders_before_interaction,
                current_cinders
            ))
            
            if failed_attempts >= max_attempts then
                console.print("Maximum attempts reached")
                
                if targetObject then
                    local obj_name = targetObject:get_skin_name()
                    
                    -- Add temp blacklist
                    add_to_temporary_blacklist(targetObject)
                    
                    -- Verify next cost
                    local next_cost = get_next_cost(obj_name, current_cinders)
                    if next_cost then
                        console.print(string.format(
                            "Chest %s has next cost: %d cinders",
                            obj_name,
                            next_cost
                        ))
                    else
                        console.print(string.format(
                            "Chest %s has no higher costs. Keeping it on the list to try again later.",
                            obj_name
                        ))
                    end
                    
                    -- Registers as missed chest in both cases
                    register_missed_chest(targetObject, Movement.get_current_waypoint_index())
                end

                -- Clears the state completely
                failed_attempts = 0
                vfx_check_start_time = nil
                cinders_before_interaction = nil
                targetObject = nil
                
                -- Pause after maximum failure
                Movement.set_moving(false)
                Movement.set_explorer_control(false)
                Movement.disable_anti_stuck()
                explorer.disable()
                Movement.set_interaction_end_time(os.clock() + CHEST_INTERACTION_DURATION)
                Movement.set_interacting(true)

                -- Clear state
                failed_attempts = 0
                vfx_check_start_time = nil
                cinders_before_interaction = nil
                
                -- Maintains the state until the end of the pause
                if Movement.get_interaction_end_time() and os.clock() < Movement.get_interaction_end_time() then
                    return States.INTERACTING
                end
                
                -- Reset everything and go back to IDLE
                Movement.set_interacting(false)
                Movement.set_moving(true)
                Movement.enable_anti_stuck()
                return States.IDLE
            else
                -- Pause before trying again
                Movement.set_moving(false)
                Movement.set_explorer_control(false)
                Movement.disable_anti_stuck()
                explorer.disable()
                Movement.set_interaction_end_time(os.clock() + CHEST_INTERACTION_DURATION)
                Movement.set_interacting(true)
                
                -- Maintains the state until the end of the pause
                if Movement.get_interaction_end_time() and os.clock() < Movement.get_interaction_end_time() then
                    return States.INTERACTING
                end
                
                -- Tenta interagir novamente
                if targetObject and targetObject:is_interactable() then
                    vfx_check_start_time = nil
                    cinders_before_interaction = current_cinders
                    interact_object(targetObject)
                    console.print("Trying to interact with the chest again")
                    return States.VERIFYING_CHEST_OPEN
                end

                -- If unable to interact, return to movement
                Movement.set_interacting(false)
                Movement.set_moving(true)
                Movement.enable_anti_stuck()
                return move_to_object(targetObject)
            end
        end
    
        return States.VERIFYING_CHEST_OPEN
    end,

    [States.MOVING_TO_MISSED_CHEST] = function(objects, interactive_patterns)
        if not target_missed_chest then
            console.print("Error: Missed target chest reference")
            clear_chest_state()
            reset_state()
            return States.IDLE
        end
    
        -- Verifica se está preso
        if Movement.is_explorer_control() and Movement.is_stuck() then
            console.print("Chest location inaccessible, removing from list")
            clear_chest_state()
            current_attempt = 0
            return States.IDLE
        end
    
        if explorer.is_target_reached() then
            console.print("Explorer reached the lost chest, looking for object")
            
            -- Check cooldown between attempts
            if os.clock() - last_interaction_time < INTERACTION_COOLDOWN then
                return States.MOVING_TO_MISSED_CHEST
            end
            
            -- Search the nearby chest object
            for _, obj in ipairs(objects) do
                if obj:get_position():dist_to(target_missed_chest.position) < 3.0 then
                    console.print(string.format("%d/%d attempt to interact with the chest", 
                        current_attempt + 1, MAX_INTERACTION_ATTEMPTS))
                    
                    targetObject = obj
                    last_interaction_time = os.clock()
                    
                    if current_attempt >= MAX_INTERACTION_ATTEMPTS then
                        console.print("Maximum attempts reached, removing chest")
                        clear_chest_state()
                        current_attempt = 0
                        return States.IDLE
                    end
                    
                    current_attempt = current_attempt + 1
                    pause_movement_for_interaction()
                    return States.INTERACTING
                end
            end
            
            -- If you didn't find the chest, try repositioning it
            explorer.set_target(target_missed_chest.position:add(vec3:new(1, 0, 1)))
            return States.MOVING_TO_MISSED_CHEST
        end
        
        return States.MOVING_TO_MISSED_CHEST
    end
}

function ChestsInteractor.reset_after_reaching_missed_chest()
    console.print("Resetting state and resuming forward movement")
    current_direction = "forward"
    Movement.reset_reverse_mode()
    Movement.set_moving(true)
    
    if target_missed_chest then
        local chest_key = get_chest_key(target_missed_chest)
        if chest_key then
            missed_chests[chest_key] = nil
            console.print("Removed lost chest from list")
        end
    end
    
    target_missed_chest = nil
    Movement.set_explorer_control(false)
    Movement.enable_anti_stuck()
end

function render_waypoints_3d()
    local waypoints = Movement.get_waypoints()
    local current_index = Movement.get_current_waypoint_index()

    for _, chest in pairs(missed_chests) do
        local target_waypoint = waypoints[chest.waypoint_index]
        if target_waypoint then
            graphics.circle_3d(target_waypoint, 5, color.new(255, 0, 0))
            graphics.text_3d("Lost Chest", target_waypoint, 20, color_green)
        else
            console.print("Waypoint not found for chest lost in index " .. chest.waypoint_index)
        end
    end

    if Movement.is_reverse_mode() and target_missed_chest then
        local target_index = target_missed_chest.waypoint_index
        
        for i = current_index, target_index, -1 do
            local waypoint = waypoints[i]
            if waypoint then
                graphics.text_3d("Backward", waypoint, 20, color_red)
            end
        end
    else
        for i = current_index, math.min(current_index + 5, #waypoints) do
            local waypoint = waypoints[i]
            if waypoint then
                graphics.text_3d("Forward", waypoint, 20, color_green)
            end
        end
    end
end

local retry_count = 0
local max_retries = math.huge


local function handle_player_too_far()
    if targetObject and is_player_too_far_from_target() and currentState ~= States.IDLE then
        retry_count = retry_count + 1
        --console.print("Tentativa " .. retry_count .. " de se aproximar do alvo")
        local target_pos = targetObject:get_position()
        explorer.set_target(target_pos)
        explorer.enable()
        currentState = States.MOVING
        return true
    else
        retry_count = 0
        return true
    end
end


function ChestsInteractor.interactWithObjects(doorsEnabled, interactive_patterns, current_waypoint_index)
    local local_player = get_local_player()
    if not local_player then return end
    
    
    local objects = actors_manager.get_ally_actors()
    if not objects then
        objects = {} 
    end
    
    -- Initialize trace if necessary
    if total_waypoints == 0 then
        init_waypoint_tracking()
    end
    
    -- During the initial loop
    if not RouteOptimizer.has_completed_initial_loop() then
        -- Records current waypoint
        if current_waypoint_index then
            if not waypoints_visited[current_waypoint_index] then
                waypoints_visited[current_waypoint_index] = true
            end
        end
        
        local visited_count = count_visited_waypoints()
        -- Consider the loop complete if it reaches 95% of the waypoints
        local completion_threshold = math.floor(total_waypoints * 0.95)
        
        -- Checks whether the initial loop with threshold has been completed
        if visited_count >= completion_threshold and RouteOptimizer.is_in_city() then
            console.print(string.format(
                "Loop considered complete (%d/%d waypoints - %.1f%%)",
                visited_count,
                total_waypoints,
                (visited_count/total_waypoints) * 100
            ))
            
            RouteOptimizer.complete_initial_loop()
            console.print(string.format(
                "Initial loop complete! Lost chests: %d",
                count_missed_chests()
            ))
            
            -- Plan optimized route if there are missing chests
            if next(missed_chests) then
                if RouteOptimizer.plan_optimized_route(missed_chests) then
                    console.print("Planned optimized route!")
                end
            end
        end
        
        -- Continues with normal interaction during initial loop
        local newState = stateFunctions[currentState](objects, interactive_patterns)
        if newState ~= currentState then
            currentState = newState
        end
        return
    end
    
    -- If you have already completed the initial loop, continue with the normal logic
    if Movement.is_interacting() then
        if os.clock() < Movement.get_interaction_end_time() then
            return -- Ainda está no tempo de pausa
        else
            Movement.set_interacting(false)
            Movement.set_moving(true)
            Movement.set_explorer_control(false)
            Movement.enable_anti_stuck()
            explorer.disable()
        end
    end
    
    -- Check if you need to return to lost chests
    if ChestsInteractor.check_missed_chests() then
        return
    end
    
    -- Updates state based on available objects
    local newState = stateFunctions[currentState](objects, interactive_patterns)
    if newState ~= currentState then
        currentState = newState
    end
    
    
    if not handle_player_too_far() then
        return
    end
    
    
    ChestsInteractor.clearTemporaryBlacklist()
end

function ChestsInteractor.clearInteractedObjects()
    interactedObjects = {}
end

function ChestsInteractor.clearTemporaryBlacklist()
    local current_time = os.clock()
    for i = #temporary_blacklist, 1, -1 do
        if current_time >= temporary_blacklist[i].expires_at then
            table.remove(temporary_blacklist, i)
        end
    end
end

function ChestsInteractor.printBlacklists()
    console.print("Permanent Blacklist:")
    for i, item in ipairs(permanent_blacklist) do
        local pos_string = string.format("(%.2f, %.2f, %.2f)", item.position:x(), item.position:y(), item.position:z())
        console.print(string.format("Item %d: %s in %s", i, item.name, pos_string))
    end
    
    console.print("\nTemporary Blacklist:")
    local current_time = os.clock()
    for i, item in ipairs(temporary_blacklist) do
        local pos_string = string.format("(%.2f, %.2f, %.2f)", item.position:x(), item.position:y(), item.position:z())
        local time_remaining = math.max(0, item.expires_at - current_time)
        console.print(string.format("Item %d: %s in %s, remaining time: %.2f seconds", i, item.name, pos_string, time_remaining))
    end
end

function ChestsInteractor.getSuccessfulChestsOpened()
    return successful_chests_opened
end

function ChestsInteractor.getSuccessfulChestsOpened()
    return successful_chests_opened
end

function ChestsInteractor.draw_chest_info()
    -- Centralized UI Settings
    local UI_CONFIG = {
        base_x = 10,
        base_y = 550,
        line_height = 17,
        category_spacing = 0,
        indent = 10,
        font_size = 20
    }
    local current_y = UI_CONFIG.base_y

    -- Helper function for drawing section headers
    local function draw_section_header(text)
        graphics.text_2d("=== " .. text .. " ===", 
            vec2:new(UI_CONFIG.base_x, current_y), 
            UI_CONFIG.font_size, 
            color_yellow(255))
        current_y = current_y + UI_CONFIG.line_height
    end

    -- HELLTIDE CHESTS STATUS
    draw_section_header("HELLTIDE CHESTS STATUS")
    graphics.text_2d(
        string.format("Total Helltide Chests Opened: %d", successful_chests_opened), 
        vec2:new(UI_CONFIG.base_x, current_y), 
        UI_CONFIG.font_size, 
        color_white
    )

    -- ROUTE STATUS
    current_y = current_y + UI_CONFIG.line_height + UI_CONFIG.category_spacing
    draw_section_header("ROUTE STATUS")
    
    -- Initial loop status
    local visited_count = count_visited_waypoints()
    local loop_status = RouteOptimizer.has_completed_initial_loop() 
        and "Complete" 
        or string.format("In Progress (%d/%d WPs)", visited_count, total_waypoints)
    graphics.text_2d(
        "Initial Loop: " .. loop_status, 
        vec2:new(UI_CONFIG.base_x, current_y), 
        UI_CONFIG.font_size, 
        color_white
    )
    current_y = current_y + UI_CONFIG.line_height

    -- Optimized route information
    if RouteOptimizer.in_optimized_route and RouteOptimizer.current_route then
        local route = RouteOptimizer.current_route
        graphics.text_2d(
            string.format(
                "Optimized Route: %d chests (Waypoint %d, Direction: %s)",
                #route.chests,
                route.waypoints[1],
                route.direction
            ),
            vec2:new(UI_CONFIG.base_x, current_y),
            UI_CONFIG.font_size,
            color_green
        )
        current_y = current_y + UI_CONFIG.line_height
    end

    -- CURRENT STATUS
    current_y = current_y + UI_CONFIG.category_spacing
    draw_section_header("CURRENT STATUS")

    -- Current state
    graphics.text_2d(
        string.format(
            "Current State: %s%s",
            currentState,
            Movement.is_interacting() and " (Interacting)" or ""
        ), 
        vec2:new(UI_CONFIG.base_x, current_y), 
        UI_CONFIG.font_size, 
        color_white
    )
    current_y = current_y + UI_CONFIG.line_height

    -- Cinders
    graphics.text_2d(
        string.format("Cinders: %d", get_helltide_coin_cinders()), 
        vec2:new(UI_CONFIG.base_x, current_y), 
        UI_CONFIG.font_size, 
        color_white
    )
    current_y = current_y + UI_CONFIG.line_height

    -- MISSED CHESTS
    current_y = current_y + UI_CONFIG.category_spacing
    draw_section_header("MISSED CHESTS")

    if next(missed_chests) then
        local player_pos = get_local_player():get_position()
        local current_cinders = get_helltide_coin_cinders()
        
        for _, chest in pairs(missed_chests) do
            local can_afford = current_cinders >= chest.required_cinders
            local status_symbol = can_afford and "✓" or "✗"
            local color_to_use = can_afford and color_green or color_red
            
            graphics.text_2d(
                string.format(
                    "• %s (%.0fm) - Cost: %d cinders %s", 
                    chest.name,
                    player_pos:dist_to(chest.position),
                    chest.required_cinders,
                    status_symbol
                ), 
                vec2:new(UI_CONFIG.base_x + UI_CONFIG.indent, current_y), 
                UI_CONFIG.font_size, 
                color_to_use
            )
            current_y = current_y + UI_CONFIG.line_height
        end
    else
        graphics.text_2d(
            "No missed chests recorded", 
            vec2:new(UI_CONFIG.base_x, current_y), 
            UI_CONFIG.font_size, 
            color_white
        )
    end

    -- If you are returning to a specific chest
    if target_missed_chest then
        current_y = current_y + UI_CONFIG.line_height
        graphics.text_2d(
            string.format(
                "Returning to: %s (Waypoint %d)", 
                target_missed_chest.name,
                target_missed_chest.waypoint_index
            ),
            vec2:new(UI_CONFIG.base_x, current_y),
            UI_CONFIG.font_size,
            color_green
        )
    end
end

function ChestsInteractor.is_active()
    return currentState ~= States.IDLE
end

function ChestsInteractor.clearPermanentBlacklist()
    permanent_blacklist = {}
end

function ChestsInteractor.clearAllBlacklists()
    ChestsInteractor.clearTemporaryBlacklist()
    ChestsInteractor.clearPermanentBlacklist()
end

function ChestsInteractor.clear_missed_chests()
    missed_chests = {}
    console.print("Clean lost chest list")
end

function ChestsInteractor.reset_for_new_helltide()
    -- Reseta variáveis de estado
    currentState = States.IDLE
    targetObject = nil
    last_known_chest_position = nil
    chest_search_attempts = 0
    current_attempt = 0
    failed_attempts = 0
    -- Removido: successful_chests_opened = 0  (mantém a contagem total)
    
    -- Clear all lists
    missed_chests = {}
    permanent_blacklist = {}
    temporary_blacklist = {}
    interactedObjects = {}
    waypoints_visited = {}
    total_waypoints = 0
    
    -- Reset variables
    last_interaction_time = 0
    last_chest_interaction_time = 0
    vfx_check_start_time = nil
    state_start_time = os.clock()
    
    -- Reset movement
    Movement.set_interacting(false)
    Movement.set_explorer_control(false)
    Movement.enable_anti_stuck()
    explorer.disable()
    
    -- Reset direction and mode
    current_direction = "forward"
    Movement.reset_reverse_mode()
    
    -- Clear missed chest target
    target_missed_chest = nil
    
    -- Reset chest attempts
    chest_attempts = {}
    current_chest_key = nil
    
    console.print("State reset to new Helltide (maintaining total chest count)")
end

on_render(render_waypoints_3d)

return ChestsInteractor