-- ============================================================
--  Reaper - tasks/sigil_complete.lua
--
--  Detects when a sigil run is complete (no enemies for 45s)
--  then:
--    1. Teleports back to Cerrigar
--    2. Waits to land
--    3. Calls rotation.consume_run() to count the kill
--    4. Resets tracker for next run
-- ============================================================

local utils    = require "core.utils"
local tracker  = require "core.tracker"
local rotation = require "core.boss_rotation"
local settings = require "core.settings"
local d4a      = require "core.d4a_command"

local CERRIGAR_WP   = 0x76D58
local CERRIGAR_ZONE = "Scos_Cerrigar"
local NO_ENEMY_TIMEOUT = 5.0   -- seconds with no enemies before declaring run complete
                                -- (kill_monsters already clears enemies before we get here)

local STATE = {
    IDLE         = "IDLE",
    WATCHING     = "WATCHING",   -- altar activated, watching for enemies to clear
    TELEPORTING  = "TELEPORTING",
    WAIT_TOWN    = "WAIT_TOWN",
    DONE         = "DONE",
}

local s = {
    state        = STATE.IDLE,
    t            = -999,
    last_enemy_t = -999,
    last_log_t   = -999,
}

local function now()         return get_time_since_inject() end
local function set_state(st) s.state = st; s.t = now() end

local function in_sigil_zone()
    local boss = rotation.current()
    if not boss or boss.run_type ~= "sigil" then return false end
    local zone = utils.get_zone()
    return zone:find("BloodyLair") ~= nil
        or zone:find("S12_Boss")   ~= nil
        or zone:find("Boss_WT")    ~= nil
        or zone:find("Boss_Kehj")  ~= nil
end

local DOOM_CHEST_SKIN = "s12_prop_theme_chest_"  -- lowercase for case-insensitive match

local function doom_chest_opened()
    -- Returns true if no Doom chest is visible (already opened or never spawned)
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local ok, name = pcall(function() return actor:get_skin_name() end)
        if ok and type(name) == "string" and name:lower():find(DOOM_CHEST_SKIN) then
            local ok2, inter = pcall(function() return actor:is_interactable() end)
            if ok2 and inter then
                return false  -- chest still interactable = not opened yet
            end
        end
    end
    return true  -- no interactable doom chest found = opened or not present
end

local task = { name = "Sigil Complete" }

function task.shouldExecute()
    local boss = rotation.current()
    if not boss or boss.run_type ~= "sigil" then return false end

    -- Yield to open_chest when the Doom chest is visible and not yet opened
    if not doom_chest_opened() then return false end

    -- Keep running mid-sequence
    if s.state ~= STATE.IDLE then return true end

    -- Normal activation: altar was activated and we're in the zone
    if tracker.altar_activated and in_sigil_zone() then return true end

    -- Timer-based fallback: activate 60s after dungeon entry even if altar was never found
    if tracker.sigil_entry_t > 0 and in_sigil_zone()
            and (now() - tracker.sigil_entry_t) >= 60.0 then
        return true
    end

    return false
end

function task.Execute()
    local t = now()

    -- ---- IDLE: start watching ----
    if s.state == STATE.IDLE then
        s.last_enemy_t = t
        set_state(STATE.WATCHING)
        if tracker.altar_activated then
            console.print("[Reaper] Sigil run in progress — watching for clear.")
        else
            console.print(string.format("[Reaper] Sigil timer elapsed (%.0fs) — watching for boss clear.",
                t - tracker.sigil_entry_t))
        end
        return
    end

    -- ---- WATCHING: wait for no enemies ----
    if s.state == STATE.WATCHING then
        if not in_sigil_zone() then
            set_state(STATE.IDLE)
            return
        end

        local has_enemy = utils.get_closest_enemy() ~= nil
                       or utils.get_suppressor() ~= nil

        if has_enemy then
            s.last_enemy_t = t  -- reset timer whenever enemies are present
            s.last_log_t   = -999  -- allow immediate log next time enemies are gone
            return
        end

        local idle_time = t - s.last_enemy_t

        -- Log once every 5s so console isn't spammed
        if (t - s.last_log_t) >= 5.0 then
            console.print(string.format("[Reaper] No enemies for %.0fs / %ds",
                idle_time, NO_ENEMY_TIMEOUT))
            s.last_log_t = t
        end

        if idle_time >= NO_ENEMY_TIMEOUT then
            -- Make sure the Doom chest is opened before leaving (30s hard timeout)
            if not doom_chest_opened() then
                local chest_wait = t - s.last_enemy_t - NO_ENEMY_TIMEOUT
                if (t - s.last_log_t) >= 5.0 then
                    console.print(string.format("[Reaper] Waiting for Doom chest to be opened... (%.0fs/30s)",
                        chest_wait))
                    s.last_log_t = t
                end
                if chest_wait < 30.0 then return end
                console.print("[Reaper] Doom chest wait timed out — proceeding anyway.")
            end
            console.print("[Reaper] Sigil run complete — counting run and teleporting to town.")
            rotation.consume_run()
            tracker.reset_run()
            teleport_to_waypoint(CERRIGAR_WP)
            set_state(STATE.TELEPORTING)
        end
        return
    end

    -- ---- TELEPORTING: run already counted — just give Alfred time to trigger ----
    if s.state == STATE.TELEPORTING then
        if (t - s.t) >= 3.0 then
            set_state(STATE.IDLE)
        end
        return
    end
end

function task.description()
    if s.state == STATE.WATCHING then
        local idle = now() - s.last_enemy_t
        return string.format("Watching: %.0fs / %.0fs — clear", idle, NO_ENEMY_TIMEOUT)
    end
    if s.state == STATE.TELEPORTING then return "Teleporting to town..." end
    if s.state == STATE.WAIT_TOWN   then return "Waiting to arrive in town..." end
    return nil
end

return task
