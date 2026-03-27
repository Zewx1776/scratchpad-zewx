-- Paladin Plugin Utility Functions
local plugin_label = "paladin_karnage_"

local function is_auto_play_enabled()
    -- auto play fire spells without orbwalker
    if not auto_play then return false end
    local is_auto_play_active = auto_play.is_active and auto_play.is_active()
    if not is_auto_play_active then return false end
    
    local auto_play_objective = auto_play.get_objective and auto_play.get_objective()
    local is_auto_play_fighting = auto_play_objective == objective.fight
    if is_auto_play_active and is_auto_play_fighting then
        return true
    end

    return false
end

local function is_action_allowed()
    -- evade abort
    local local_player = get_local_player()
    if not local_player then
        return false
    end  
    
    local player_position = local_player:get_position()
    if evade and evade.is_dangerous_position and evade.is_dangerous_position(player_position) then
        return false
    end
 
    -- Check if player is mounted or in special states
    local is_mounted = false
    local local_player_buffs = local_player:get_buffs()
    if local_player_buffs then
        for _, buff in ipairs(local_player_buffs) do
            local buff_name = buff:name()
            if buff_name and string.find(buff_name, "Mount") then
                is_mounted = true
                break
            end
        end
    end
    
    if is_mounted then
        return false
    end

    return true
end

local function is_spell_allowed(menu_boolean, next_time_allowed_cast, spell_id)
    if not menu_boolean then
        return false
    end

    local current_time = get_time_since_inject()
    if current_time < next_time_allowed_cast then
        return false
    end

    if not is_action_allowed() then
        return false
    end

    local player_local = get_local_player()
    if not player_local then
        return false
    end

    if orbwalker and orbwalker.get_orb_mode then
        local orb_mode = orbwalker.get_orb_mode()
        if orb_mode == 0 then
            return false
        end
    end

    -- Check if spell is on skill bar
    if spell_id and utility and utility.is_spell_on_bar then
        if not utility.is_spell_on_bar(spell_id) then
            return false
        end
    end

    return true
end

local function get_nearby_enemy_count(center_position, max_range)
    if not center_position or not max_range then return 0 end
    
    local actors = actors_manager.get_enemy_npcs()
    if not actors then return 0 end
    
    local count = 0
    for _, actor in ipairs(actors) do
        if actor and actor:is_enemy() then
            local actor_position = actor:get_position()
            if actor_position then
                local distance_sqr = center_position:squared_dist_to_ignore_z(actor_position)
                if distance_sqr <= (max_range * max_range) then
                    count = count + 1
                end
            end
        end
    end
    
    return count
end

return {
    plugin_label = plugin_label,
    is_auto_play_enabled = is_auto_play_enabled,
    is_action_allowed = is_action_allowed,
    is_spell_allowed = is_spell_allowed,
    get_nearby_enemy_count = get_nearby_enemy_count,
}
