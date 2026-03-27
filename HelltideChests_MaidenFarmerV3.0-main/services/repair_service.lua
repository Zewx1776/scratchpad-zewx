local menu = require("menu")
local enums = require("data.enums")

local RepairService = {
    CONSTANTS = {
        INTERACTION_DISTANCE = 3.0,
        PROCESS_DELAY = 0.2
    },

    state = {
        is_processing = false,
        last_repair_time = 0
    }
}

local function calculate_distance(point1, point2)
    if not point1 or not point2 then return 999999 end
    return point1:dist_to_ignore_z(point2)
end

-- Find the nearest blacksmith
function RepairService:find_nearest_blacksmith()
    return enums.positions.blacksmith_position
end

-- Function to interact with the vendor
function RepairService:interact_vendor(vendor_pos)
    if not vendor_pos then 
        console.print("Invalid vendor position")
        return false 
    end
    
    -- Check if you are already on the vendor screen
    if loot_manager.is_in_vendor_screen() then
        console.print("It's already on the vendor screen")
        return true
    end
    
    -- Finds the vendor at the specified position
    local actors = actors_manager:get_all_actors()
    local closest_vendor = nil
    local min_distance = 999999
    
    for _, actor in pairs(actors) do
        if actor:is_interactable() then
            local name = actor:get_skin_name()
            if name == enums.misc.blacksmith then
                local distance = calculate_distance(actor:get_position(), vendor_pos)
                if distance < min_distance then
                    min_distance = distance
                    closest_vendor = actor
                end
            end
        end
    end
    
    if not closest_vendor then
        console.print("No vendors found in the position")
        return false
    end
    
    -- Tenta interagir com o vendor encontrado
    interact_vendor(closest_vendor)
    
    -- Aguarda um pouco para a janela abrir
    local current_time = os.clock()
    while os.clock() - current_time < self.CONSTANTS.PROCESS_DELAY do end
    
    -- Verifica se a janela abriu
    if loot_manager.is_in_vendor_screen() then
        console.print("Vendor window opened successfully")
        return true
    end
    
    console.print("Failed to open vendor window")
    return false
end

-- Verifica se há itens para reparar
function RepairService:has_items_to_repair()
    local local_player = get_local_player()
    if not local_player then 
        console.print("Unable to get local player")
        return false 
    end
    
    local equipped_items = local_player:get_equipped_items()
    if not equipped_items then
        console.print("Unable to obtain equipped items")
        return false
    end
    
    -- Verifica cada item equipado
    for _, item in ipairs(equipped_items) do
        if item then
            local durability = item:get_durability()
            if durability and durability < 100 then
                -- Verifica se a durabilidade não está próxima de 100
                if math.abs(durability - 100) > 0.1 then
                    return true
                end
            end
        end
    end
    
    return false
end

-- Processa reparo dos itens
function RepairService:process_repair_items(vendor_pos)
    if self.state.is_processing then 
        console.print("Already processing repair")
        return false 
    end
    
    if not self:has_items_to_repair() then
        console.print("There are no items to repair")
        return true
    end
    
    console.print("Starting repair process...")
    
    -- Encontra o vendor mais próximo
    local actors = actors_manager:get_all_actors()
    local closest_vendor = nil
    local min_distance = 999999
    
    for _, actor in pairs(actors) do
        if actor:is_interactable() then
            local name = actor:get_skin_name()
            if name == enums.misc.blacksmith then
                local distance = calculate_distance(actor:get_position(), vendor_pos)
                if distance < min_distance then
                    min_distance = distance
                    closest_vendor = actor
                end
            end
        end
    end
    
    if not closest_vendor then
        console.print("No vendors found in the position")
        return false
    end
    
    -- Verifica se já está na tela do vendor antes de tentar interagir
    if not loot_manager.is_in_vendor_screen() then
        if not self:interact_vendor(vendor_pos) then
            console.print("Failed to open vendor window, aborting repair")
            return false
        end
    else
        console.print("It's already on the vendor screen, continuing with repair")
    end
    
    -- Processa o reparo
    self.state.is_processing = true
    local current_time = os.clock()
    
    -- Usa o closest_vendor que encontramos
    if loot_manager.interact_with_vendor_and_repair_all(closest_vendor) then
        while os.clock() - current_time < self.CONSTANTS.PROCESS_DELAY do end
        console.print("Repair completed successfully")
        self.state.is_processing = false
        return true
    end
    
    console.print("Failed to repair items")
    self.state.is_processing = false
    return false
end

return RepairService