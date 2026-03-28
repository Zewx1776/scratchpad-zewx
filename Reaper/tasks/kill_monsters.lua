-- ============================================================
--  Reaper - tasks/kill_monsters.lua
--
--  Handles fighting — moves toward enemies and suppressor
--  orbs. When no enemy is in range, drifts back toward the
--  altar position so the orbwalker stays close to the boss.
-- ============================================================

local utils        = require "core.utils"
local tracker      = require "core.tracker"
local rotation     = require "core.boss_rotation"
local enums        = require "data.enums"

local plugin_label   = 'reaper'
local stuck_position = nil

local function in_target_boss_zone()
    local boss = rotation.current()
    if not boss then return false end
    local zone = utils.get_zone()
    if boss.run_type == "sigil" then
        return zone:find("BloodyLair") ~= nil
            or zone:find("S12_Boss")   ~= nil
            or zone:find("Boss_WT")    ~= nil
            or zone:find("Boss_Kehj")  ~= nil
    end
    return zone:match(boss.zone_prefix) ~= nil
end

-- Returns the altar position if we can find it, or the boss room
-- seed position from enums as a fallback
local function get_anchor_position()
    local altar = utils.get_altar()
    if altar then return altar:get_position() end

    local boss = rotation.current()
    if boss then
        return enums.positions.getBossRoomPosition(boss.zone_prefix)
    end
    return nil
end

local task = { name = "Kill Monsters" }

function task.shouldExecute()
    if not in_target_boss_zone() then return false end
    if not tracker.altar_activated then return false end
    if utils.get_suppressor() then return true end
    return utils.get_closest_enemy() ~= nil
end

function task.Execute()
    local player_pos = get_player_position()

    -- Move to burst suppressor barrier orbs
    local suppressor = utils.get_suppressor()
    if suppressor then
        BatmobilePlugin.set_target(plugin_label, suppressor)
        BatmobilePlugin.update(plugin_label)
        BatmobilePlugin.move(plugin_label)
        return
    end

    local enemy = utils.get_closest_enemy()
    if not enemy then
        BatmobilePlugin.clear_target(plugin_label)
        return
    end

    local dist = utils.distance_to(enemy)

    if dist >= 6.5 then
        -- Enemy is far — use Batmobile to navigate toward it
        BatmobilePlugin.set_target(plugin_label, enemy)
        BatmobilePlugin.update(plugin_label)
        BatmobilePlugin.move(plugin_label)
    else
        BatmobilePlugin.clear_target(plugin_label)
        -- Within orbwalker range — drift back toward altar so we
        -- don't wander away from the boss fight area
        local anchor = get_anchor_position()
        if anchor and utils.distance_to(anchor) > 8.0 then
            pathfinder.request_move(anchor)
        end
        -- Within range and near altar: orbwalker handles casting
    end
end

return task
