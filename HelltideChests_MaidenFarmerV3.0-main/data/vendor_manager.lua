local menu = require("menu")
local enums = require("data.enums")
local explorer = require("data.explorer")
local InventoryManager = require("services.inventory_manager")
local GameStateChecker = require("functions.game_state_checker")

local VendorManager = {
    CONSTANTS = {
        COLORS = {
            TARGET = color_red(200),
            PATH = color_green(200),
            CURRENT_PATH = color_yellow(200)
        },
        SIZES = {
            TARGET = 25,
            PATH = 20
        },
        UPDATE_INTERVAL = 1/80
    },

    state = {
        render_buffer = {},
        last_update_time = 0,
        last_position_check = 0,
        last_move_time = 0,
        is_moving = false
    }
}


local function calculate_distance(point1, point2)
    if not point1 or not point2 then return 999999 end
    
    if not point2.x and point2 then
        return point1:dist_to_ignore_z(point2:get_position())
    end
    return point1:dist_to_ignore_z(point2)
end


local function check_if_stuck()
    local current_pos = get_player_position()
    local current_time = os.time()
    
    if VendorManager.state.last_position and 
       calculate_distance(current_pos, VendorManager.state.last_position) < 2 then
        if current_time - VendorManager.state.last_move_time > 4 then
            console.print("Player appears to be stuck")
            return true
        end
    else
        VendorManager.state.last_move_time = current_time
    end
    
    VendorManager.state.last_position = current_pos
    return false
end


local function move_to_target(target_pos)
    if not target_pos then return false end
    
    local player_pos = get_player_position()
    if not player_pos then return false end

    local distance = calculate_distance(player_pos, target_pos)
    
    if distance > 50 then  
        console.print("Destination too far to move: " .. tostring(distance))
        if explorer.is_enabled() then
            explorer.disable()
        end
        return false
    end

    
    if distance < InventoryManager.CONSTANTS.MOVEMENT_THRESHOLD then
        if explorer.is_enabled() then
            explorer.disable()
        end
        return true
    end
    
    
    if not explorer.is_enabled() then
        explorer.set_target(target_pos)
        explorer.enable()
    end

    
    if check_if_stuck() then
        explorer.disable()
        explorer.set_target(target_pos)
        explorer.enable()
    end

    return false
end


local function update_render_buffer()
    VendorManager.state.render_buffer = {}
    
    local current_target = InventoryManager.state.current_target
    if current_target then
        local position = current_target
        
        
        if type(current_target.get_position) == "function" then
            position = current_target:get_position()
        end
        
        if position and position.x then
            table.insert(VendorManager.state.render_buffer, {
                text = string.format("%s TARGET", 
                    (InventoryManager.state.current_action or ""):upper()),
                position = position,
                size = VendorManager.CONSTANTS.SIZES.TARGET,
                color = VendorManager.CONSTANTS.COLORS.TARGET
            })
        end
    end
end


on_update(function()
    if not menu.vendor_enabled:get() then 
        
        return 
    end
     
    local local_player = get_local_player()
    if not local_player then return end

    
    local is_helltide = GameStateChecker.is_in_helltide(local_player)
                
    InventoryManager:update()
    
    
    if InventoryManager.state.current_target then
        
        local target_pos = InventoryManager.state.current_target
                
        if type(target_pos.get_position) == "function" then
            target_pos = target_pos:get_position()
        end
        
        
        if target_pos and target_pos.x then
            VendorManager.state.is_moving = not move_to_target(target_pos)
        end
    end
    
    
    local current_time = os.clock()
    if current_time - VendorManager.state.last_update_time >= VendorManager.CONSTANTS.UPDATE_INTERVAL then
        VendorManager.state.last_update_time = current_time
        update_render_buffer()
    end
end)


on_render(function()
    if not menu.vendor_enabled:get() then return end
    
    for _, item in ipairs(VendorManager.state.render_buffer) do
        if item.position then
            graphics.text_3d(
                item.text,
                item.position,
                item.size,
                item.color
            )
        end
    end
    InventoryManager.draw_screen_message()
end)


return {
    is_moving = function() return VendorManager.state.is_moving end,
    get_stats = function() return InventoryManager:get_stats() end,
    calculate_distance = calculate_distance
}