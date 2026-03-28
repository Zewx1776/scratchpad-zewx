-- ============================================================
--  Reaper - tasks/restock.lua
--
--  Restocks materials and sigils from the Cerrigar stash.
--  Fires when:
--    1. Startup: rotation could not be built (empty inventory)
--    2. Mid-session: all queued runs exhausted
--
--  Flow:
--    TELEPORT   → teleport_to_waypoint(CERRIGAR)
--    WAIT_ZONE  → wait to land in Cerrigar
--    WALK       → walk recorded path to stash
--    OPEN_STASH → interact_vendor(stash) to open stash UI
--    WAIT_LOOT  → wait for loot_manager to pull items
--    REBUILD    → close stash, rebuild rotation
-- ============================================================

local settings   = require "core.settings"
local rotation   = require "core.boss_rotation"
local materials  = require "core.materials"
local tracker    = require "core.tracker"
local pathwalker = require "core.pathwalker"
local utils      = require "core.utils"

local CERRIGAR_WP   = 0x76D58
local CERRIGAR_ZONE = "Scos_Cerrigar"
local STASH_PATH    = require "paths.stash"

-- Known stash position in Cerrigar (from Alfred)
local STASH_POSITION = vec3:new(-1684.1199951172, -592.11602783203, 37.606800079346)

-- -------------------------------------------------------
-- Find stash actor by exact skin name (same as Alfred)
-- -------------------------------------------------------
local function find_stash()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local ok, name = pcall(function() return actor:get_skin_name() end)
        if ok and name == "Stash" then
            return actor
        end
    end
    return nil
end

-- -------------------------------------------------------
-- State machine
-- -------------------------------------------------------
local STATE = {
    IDLE       = "IDLE",
    TELEPORT   = "TELEPORT",
    WAIT_ZONE  = "WAIT_ZONE",
    WALK       = "WALK",
    OPEN_STASH = "OPEN_STASH",
    WAIT_LOOT  = "WAIT_LOOT",
    REBUILD    = "REBUILD",
}

local s = {
    state    = STATE.IDLE,
    t        = 0,
    reason   = "",
    attempts = 0,
}

local MAX_ATTEMPTS = 3
local T_ZONE_WAIT  = 20.0
local T_STASH_OPEN = 3.0   -- wait after interact_vendor for stash UI to open
local T_LOOT_WAIT  = 4.0   -- wait at open stash for items to transfer

local function now()         return get_time_since_inject() end
local function set_state(st) s.state = st; s.t = now() end
local function elapsed()     return now() - s.t end

local function in_cerrigar()
    return utils.player_in_zone(CERRIGAR_ZONE)
end

-- -------------------------------------------------------
local task = { name = "Restock" }

function task.shouldExecute()
    -- Keep running mid-sequence
    if s.state ~= STATE.IDLE then return true end

    -- Case 1: mid-session ran dry
    if rotation.initialized and rotation.is_done() then
        s.reason = "mid-session restock"
        return true
    end

    -- Case 2: startup with empty inventory
    if not rotation.initialized then
        s.reason = "startup stash fetch"
        return true
    end

    return false
end

function task.Execute()
    -- ---- IDLE: kick off ----
    if s.state == STATE.IDLE then
        console.print(string.format("[Reaper] Restock triggered (%s).", s.reason))
        s.attempts = 0

        if in_cerrigar() then
            console.print("[Reaper] Already in Cerrigar — walking to stash.")
            pathwalker.start_walking_path_with_points(STASH_PATH, "stash", false)
            set_state(STATE.WALK)
        else
            console.print("[Reaper] Teleporting to Cerrigar...")
            teleport_to_waypoint(CERRIGAR_WP)
            set_state(STATE.TELEPORT)
        end
        return
    end

    -- ---- TELEPORT: brief wait for teleport animation ----
    if s.state == STATE.TELEPORT then
        if elapsed() >= 1.5 then
            set_state(STATE.WAIT_ZONE)
        end
        return
    end

    -- ---- WAIT_ZONE: wait to land in Cerrigar ----
    if s.state == STATE.WAIT_ZONE then
        if in_cerrigar() then
            if elapsed() >= 2.0 then
                console.print("[Reaper] Arrived in Cerrigar — walking to stash.")
                pathwalker.start_walking_path_with_points(STASH_PATH, "stash", false)
                set_state(STATE.WALK)
            end
            return
        end
        if elapsed() >= T_ZONE_WAIT then
            s.attempts = s.attempts + 1
            if s.attempts >= MAX_ATTEMPTS then
                console.print("[Reaper] Could not reach Cerrigar — aborting restock.")
                set_state(STATE.IDLE)
                return
            end
            console.print(string.format("[Reaper] Zone wait timeout, retry %d/%d", s.attempts, MAX_ATTEMPTS))
            teleport_to_waypoint(CERRIGAR_WP)
            set_state(STATE.TELEPORT)
        end
        return
    end

    -- ---- WALK: walk recorded path to stash ----
    if s.state == STATE.WALK then
        local stash = find_stash()
        if stash and utils.distance_to(stash) <= 4.0 then
            console.print("[Reaper] At stash — opening.")
            pathwalker.stop_walking()
            set_state(STATE.OPEN_STASH)
            return
        end

        if pathwalker.is_path_completed() or pathwalker.is_at_final_waypoint() then
            console.print("[Reaper] Path complete — attempting to open stash.")
            pathwalker.stop_walking()
            set_state(STATE.OPEN_STASH)
            return
        end

        pathwalker.update_path_walking()
        return
    end

    -- ---- OPEN_STASH: use interact_vendor (same as Alfred) ----
    if s.state == STATE.OPEN_STASH then
        local stash = find_stash()

        if not stash then
            -- Walk toward known stash position and keep trying
            pathfinder.request_move(STASH_POSITION)
            if elapsed() >= T_STASH_OPEN then
                console.print("[Reaper] Stash actor not found after " .. T_STASH_OPEN .. "s — moving on.")
                set_state(STATE.REBUILD)
            end
            return
        end

        -- Walk closer if needed
        local dist = utils.distance_to(stash)
        if dist > 3.0 then
            pathfinder.request_move(stash:get_position())
            return
        end

        -- interact_vendor opens the stash UI (interact_object opens game menu)
        console.print(string.format("[Reaper] Opening stash (dist=%.1fm)...", dist))
        interact_vendor(stash)
        set_state(STATE.WAIT_LOOT)
        return
    end

    -- ---- WAIT_LOOT: wait for stash to transfer items ----
    if s.state == STATE.WAIT_LOOT then
        if elapsed() >= T_LOOT_WAIT then
            console.print("[Reaper] Stash interaction complete — closing and rebuilding.")
            utility.send_key_press(0x1B)  -- Escape closes stash UI
            set_state(STATE.REBUILD)
        end
        return
    end

    -- ---- REBUILD: rebuild rotation with fresh inventory ----
    if s.state == STATE.REBUILD then
        rotation.build(settings)
        tracker.reset_run()
        set_state(STATE.IDLE)

        if rotation.initialized then
            console.print("[Reaper] Restock complete — resuming farming.")
        else
            console.print("[Reaper] Nothing to farm after restock. Stopping.")
        end
        return
    end
end

return task
