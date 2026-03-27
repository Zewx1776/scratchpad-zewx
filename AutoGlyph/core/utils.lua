local utils = {}

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

function utils.get_object_by_name(object_name)
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name == object_name then
            return actor
        end
    end
    return nil
end

return utils
