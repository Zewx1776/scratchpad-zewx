local explorerlite = {}

local current_target = nil

function explorerlite:set_custom_target(pos)
    current_target = pos
end

function explorerlite:move_to_target()
    if not current_target then return end
    -- Simple movement: ask pathfinder to move directly towards target
    pathfinder.force_move_raw(current_target)
end

return explorerlite
