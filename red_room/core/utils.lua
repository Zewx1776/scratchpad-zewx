local utils    = {}
function utils.distance_to(target)
    local player_pos = get_player_position()
    local target_pos

    if target.get_position then
        target_pos = target:get_position()
    elseif target.x then
        target_pos = target
    end

    return player_pos:dist_to(target_pos)
end
function utils.is_same_position(pos1, pos2)
    return pos1:x() == pos2:x() and pos1:y() == pos2:y() and pos1:z() == pos2:z()
end
function utils.is_mounted()
    local local_player = get_local_player()
    return local_player:get_attribute(attributes.CURRENT_MOUNT) < 0
end
function utils.player_in_zone(zname)
    return get_current_world():get_current_zone_name() == zname
end
return utils
