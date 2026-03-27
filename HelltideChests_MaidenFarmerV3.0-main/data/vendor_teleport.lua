local vendor_teleport = {}

-- FSM States (Finite State Machine)
local FSM = {
    IDLE = "idle",
    INITIATING = "initiating",
    TELEPORTING = "teleporting",
    STABILIZING = "stabilizing",
    COOLDOWN = "cooldown"
}

-- Variáveis locais
local current_state = FSM.IDLE
local last_position = nil
local stable_position_count = 0
local teleport_start_time = 0
local teleport_timeout = 5
local stable_position_threshold = 2

-- Controle de tentativas e cooldown
local teleport_attempts = 0
local max_teleport_attempts = 3
local teleport_cooldown = 0
local teleport_cooldown_duration = 15

-- Function verify state loading or limbo?
local function is_loading_or_limbo()
    local current_world = world.get_current_world()
    if not current_world then return true end
    local world_name = current_world:get_name()
    return world_name:find("Limbo") ~= nil or world_name:find("Loading") ~= nil
end

-- Function to clean up before teleportation
local function cleanup_before_teleport(ChestsInteractor, Movement)
    if not ChestsInteractor or not Movement then
        console.print("ChestsInteractor ou Movement não disponível")
        return
    end
    collectgarbage("collect")
    ChestsInteractor.clearInteractedObjects()
    Movement.reset()
end

-- Teleport main function
function vendor_teleport.teleport_to_tree(ChestsInteractor, Movement)
    local current_time = get_time_since_inject()
    local current_world = world.get_current_world()
    local local_player = get_local_player()
    
    if not current_world or not local_player then
        return false
    end

    local current_position = local_player:get_position()

    -- Lógic FSM
    if current_state == FSM.IDLE then
        if is_loading_or_limbo() then
            return false
        end
        
        if current_time < teleport_cooldown then
            current_state = FSM.COOLDOWN
            return false
        end

        current_state = FSM.INITIATING
        teleport_start_time = current_time
        cleanup_before_teleport(ChestsInteractor, Movement)
        
        -- Usa o ID do Tree of Whispers do enums
        teleport_to_waypoint(0x90557) -- Tree of Whispers waypoint ID
        last_position = current_position
        console.print("Teleport started to Tree of Whispers")
        
    elseif current_state == FSM.INITIATING then
        if is_loading_or_limbo() then
            current_state = FSM.TELEPORTING
        elseif current_time - teleport_start_time > teleport_timeout then
            console.print("Teleport failed: timeout. Trying again...")
            current_state = FSM.IDLE
            teleport_attempts = teleport_attempts + 1
            if teleport_attempts >= max_teleport_attempts then
                console.print("Maximum number of attempts reached. Entering cooldown.")
                teleport_cooldown = current_time + teleport_cooldown_duration
                current_state = FSM.COOLDOWN
                teleport_attempts = 0
            end
        end
        
    elseif current_state == FSM.TELEPORTING then
        if not is_loading_or_limbo() then
            current_state = FSM.STABILIZING
            last_position = current_position
            stable_position_count = 0
        end
        
    elseif current_state == FSM.STABILIZING then
        if is_loading_or_limbo() then
            current_state = FSM.TELEPORTING
        elseif last_position and current_position:dist_to(last_position) < 0.5 then
            stable_position_count = stable_position_count + 1
            if stable_position_count >= stable_position_threshold then
                current_state = FSM.IDLE
                console.print("Teleport successfully completed to Tree of Whispers")
                teleport_attempts = 0
                return true
            end
        else
            stable_position_count = 0
        end
        last_position = current_position
        
    elseif current_state == FSM.COOLDOWN then
        if current_time >= teleport_cooldown then
            current_state = FSM.IDLE
            console.print("Teleport cooldown completed")
        end
    end

    return false
end

function vendor_teleport.reset()
    current_state = FSM.IDLE
    last_position = nil
    stable_position_count = 0
    teleport_attempts = 0
    teleport_cooldown = 0
    console.print("Teleport status reset")
end

-- Gets the current state of the teleport
function vendor_teleport.get_state()
    return current_state
end

-- Get detailed information about the teleport
function vendor_teleport.get_info()
    return {
        state = current_state,
        attempts = teleport_attempts,
        max_attempts = max_teleport_attempts,
        cooldown = math.max(0, math.floor(teleport_cooldown - get_time_since_inject()))
    }
end

return vendor_teleport