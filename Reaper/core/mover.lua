-- ============================================================
--  Magoogle's Boss Farmer - core/mover.lua
--
--  Simple movement helpers used by tasks.
--  Replaces the generic explorerlite.lua with only what
--  this script actually needs.
-- ============================================================

local mover = {}

-- -------------------------------------------------------
-- Custom target movement
-- -------------------------------------------------------
local custom_target = nil

function mover:set_custom_target(pos)
    custom_target = pos
end

function mover:move_to_target()
    if custom_target then
        pathfinder.request_move(custom_target)
    end
end

-- -------------------------------------------------------
-- Stuck detection
-- -------------------------------------------------------
local last_stuck_pos  = nil
local last_move_time  = 0
local STUCK_THRESHOLD = 3.0  -- seconds without moving

function mover.check_if_stuck()
    local pos = get_player_position()
    if not pos then return false end
    local t = get_time_since_inject()

    if last_stuck_pos then
        local dist = pos:dist_to_ignore_z(last_stuck_pos)
        if dist < 0.5 then
            if (t - last_move_time) >= STUCK_THRESHOLD then
                return true
            end
        else
            last_move_time = t
            last_stuck_pos = pos
        end
    else
        last_move_time = t
        last_stuck_pos = pos
    end
    return false
end

-- -------------------------------------------------------
-- Find a nearby unstuck target (random nearby navigable point)
-- -------------------------------------------------------
function mover.find_unstuck_target()
    local pos = get_player_position()
    if not pos then return nil end
    -- Try a few offsets and return the first navigable one
    local offsets = {
        vec3:new(pos:x() + 5, pos:y(),     pos:z()),
        vec3:new(pos:x() - 5, pos:y(),     pos:z()),
        vec3:new(pos:x(),     pos:y() + 5, pos:z()),
        vec3:new(pos:x(),     pos:y() - 5, pos:z()),
        vec3:new(pos:x() + 8, pos:y() + 8, pos:z()),
    }
    for _, off in ipairs(offsets) do
        return off  -- pathfinder will handle navigability
    end
    return nil
end

return mover
