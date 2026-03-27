-- Target Selector for Paladin Plugin

local _targeting_mode_combo = nil
if type(combo_box) == "table" and type(combo_box.new) == "function" then
    pcall(function()
        _targeting_mode_combo = combo_box:new(0, get_hash("targeting_mode_dropdown_paladin"))
    end)
end

local function get_current_selected_position()
    local player = get_local_player()
    if not player then return nil end
    
    -- Check targeting mode preference
    local targeting_mode = "cursor" -- default
    if menu and menu.main_tree and type(menu.main_tree.push) == "function" then
        -- Try to get the targeting mode dropdown value
        if _targeting_mode_combo then
            local ok, mode_value = pcall(function()
                return _targeting_mode_combo:get()
            end)
            if ok and mode_value then
                -- mode_value will be 0 for cursor, 1 for player
                targeting_mode = mode_value == 1 and "player" or "cursor"
            end
        end
    end
    
    -- Try to get cursor position first if in cursor mode
    if targeting_mode == "cursor" then
        local cursor_pos = get_cursor_position()
        if cursor_pos then
            return cursor_pos
        end
    end
    
    -- Fall back to player position
    return player:get_position()
end

local function get_target_list(center_position, max_range, params1, params2, params3)
    local target_list = {}
    
    if not center_position then
        return target_list
    end
    
    local actors = actors_manager.get_enemy_npcs()
    if not actors then
        return target_list
    end
    
    for _, actor in ipairs(actors) do
        if actor and actor:is_enemy() then
            local actor_position = actor:get_position()
            if actor_position then
                local distance_sqr = center_position:squared_dist_to_ignore_z(actor_position)
                if distance_sqr <= (max_range * max_range) then
                    table.insert(target_list, actor)
                end
            end
        end
    end
    
    return target_list
end

local function get_target_selector_data(center_position, entity_list)
    local data = {
        is_valid = false,
        closest_unit = nil,
        closest_elite = nil,
        closest_boss = nil,
        closest_champion = nil,
        has_elite = false,
        has_boss = false,
        has_champion = false,
    }
    
    if not center_position or not entity_list or #entity_list == 0 then
        return data
    end
    
    data.is_valid = true
    
    local min_distance = math.huge
    local min_elite_distance = math.huge
    local min_boss_distance = math.huge
    local min_champion_distance = math.huge
    
    for _, entity in ipairs(entity_list) do
        if entity then
            local entity_position = entity:get_position()
            if entity_position then
                local distance = center_position:squared_dist_to_ignore_z(entity_position)
                
                -- Track closest unit
                if distance < min_distance then
                    min_distance = distance
                    data.closest_unit = entity
                end
                
                -- Track special unit types
                if entity.is_elite and entity:is_elite() then
                    data.has_elite = true
                    if distance < min_elite_distance then
                        min_elite_distance = distance
                        data.closest_elite = entity
                    end
                end
                
                if entity.is_boss and entity:is_boss() then
                    data.has_boss = true
                    if distance < min_boss_distance then
                        min_boss_distance = distance
                        data.closest_boss = entity
                    end
                end
                
                if entity.is_champion and entity:is_champion() then
                    data.has_champion = true
                    if distance < min_champion_distance then
                        min_champion_distance = distance
                        data.closest_champion = entity
                    end
                end
            end
        end
    end
    
    return data
end

return {
    get_current_selected_position = get_current_selected_position,
    get_target_list = get_target_list,
    get_target_selector_data = get_target_selector_data,
}
