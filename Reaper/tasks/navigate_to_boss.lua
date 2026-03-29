-- ============================================================
--  Reaper - tasks/navigate_to_boss.lua
--
--  Flow (D4Assistant mode, default):
--    D4A_TELEPORT → write command.txt, wait for D4Assistant to teleport
--    PATHWALKING  → walk recorded path to altar
--    WALKING      → walk to dungeon entrance portal
--    ENTERING     → interact with portal to enter
--
--  Flow (map-click fallback, use_d4a disabled):
--    MAP_NAV      → delegate to core/map_nav.lua (waypoint → map click → boss)
--    (then same PATHWALKING / WALKING / ENTERING)
-- ============================================================

local utils        = require "core.utils"
local enums        = require "data.enums"
local explorerlite = require "core.explorerlite"
local pathwalker   = require "core.pathwalker"
local map_nav      = require "core.map_nav"
local d4a          = require "core.d4a_command"
local settings     = require "core.settings"
local rotation     = require "core.boss_rotation"
local tracker      = require "core.tracker"

local plugin_label  = 'reaper'
local CERRIGAR_WP   = 0x76D58

-- -------------------------------------------------------
-- Altar paths
-- -------------------------------------------------------
local cached_variants = {}
local VARIANT_SUFFIXES = { "_a", "_b", "_c", "_d" }

local function load_variants(boss_id)
    if cached_variants[boss_id] ~= nil then return end
    local found = {}
    for _, suffix in ipairs(VARIANT_SUFFIXES) do
        local mod = "paths." .. boss_id .. suffix
        local ok, result = pcall(require, mod)
        if ok and type(result) == "table" and #result > 0 then
            table.insert(found, { name = mod, points = result })
            console.print(string.format("[Reaper] Path loaded: %s (%d pts)", mod, #result))
        end
    end
    cached_variants[boss_id] = (#found > 0) and found or false
end

local function pick_best_path(boss_id)
    load_variants(boss_id)
    local variants = cached_variants[boss_id]
    if not variants then return nil end
    if #variants == 1 then return variants[1].points end
    local player_pos = get_player_position()
    if not player_pos then return variants[1].points end
    local best, best_dist = variants[1], math.huge
    for _, v in ipairs(variants) do
        local dist = player_pos:dist_to_ignore_z(v.points[1].pos or v.points[1])
        if dist < best_dist then best = v; best_dist = dist end
    end
    console.print(string.format("[Reaper] Variant: %s (%.1fm)", best.name, best_dist))
    return best.points
end

local function needs_path_walk(boss_id)
    load_variants(boss_id)
    local v = cached_variants[boss_id]
    return v and #v > 0
end

-- -------------------------------------------------------
-- Zone helpers
-- -------------------------------------------------------
local function in_target_zone(boss)
    local zone = utils.get_zone()
    -- For sigil runs the lair dungeon zone won't match the boss zone_prefix,
    -- so accept any lair boss zone as valid
    if boss.run_type == "sigil" then
        return zone:find("BloodyLair") ~= nil
            or zone:find("S12_Boss")   ~= nil
            or zone:find("Boss_WT")    ~= nil
            or zone:find("Boss_Kehj")  ~= nil
    end
    return zone:match(boss.zone_prefix) ~= nil
end

local function chest_visible()
    local actors = actors_manager.get_all_actors()
    if type(actors) ~= "table" then return false end
    for _, a in pairs(actors) do
        local ok, inter = pcall(function() return a:is_interactable() end)
        if ok and inter then
            local name = a:get_skin_name()
            if type(name) == "string" then
                if name:find("^EGB_Chest") or name:find("^Boss_WT_Belial_") or name:find("^Chest_Boss") then
                    return true
                end
            end
        end
    end
    return false
end

-- -------------------------------------------------------
-- Sigil helpers
-- -------------------------------------------------------
local SIGIL_SNO = 2565553

local function find_sigil_for_boss(boss_id)
    local lp = get_local_player()
    if not lp then return nil end
    local ok, keys = pcall(function() return lp:get_dungeon_key_items() end)
    if not ok or type(keys) ~= "table" then return nil end

    local mats = require "core.materials"
    local first_sigil = nil

    for _, item in ipairs(keys) do
        local ok_sno, sno = pcall(function() return item:get_sno_id() end)
        if ok_sno and sno == SIGIL_SNO then
            -- Track the first sigil as fallback
            if not first_sigil then first_sigil = item end

            local ok_d, display = pcall(function() return item:get_display_name() end)
            if ok_d and display then
                local mapped = mats.boss_from_display(display)
                if mapped == boss_id then
                    return item  -- exact match
                end
            end
        end
    end

    -- No exact match — return first available sigil (unmapped location)
    return first_sigil
end

-- -------------------------------------------------------
-- State machine
-- -------------------------------------------------------
local STATE = {
    IDLE          = "IDLE",
    USE_SIGIL     = "USE_SIGIL",      -- activate sigil item
    CONFIRM_SIGIL = "CONFIRM_SIGIL",  -- confirm consume dialog
    WAIT_PORTAL   = "WAIT_PORTAL",    -- wait for zone to change to boss dungeon (D4A path)
    D4A_TELEPORT  = "D4A_TELEPORT",   -- waiting for D4Assistant to teleport us
    MAP_NAV       = "MAP_NAV",        -- map_nav handles waypoint + click (fallback)
    PATHWALKING   = "PATHWALKING",    -- one-shot: fires navigate_long_path then transitions
    LONG_PATHING  = "LONG_PATHING",   -- waiting for Batmobile long path nav to finish
    EXPLORING     = "EXPLORING",      -- long path blocked (traversal); drive Batmobile normally, retry long path every 10s
    WALKING      = "WALKING",
    ENTERING     = "ENTERING",
    WAIT_EXIT    = "WAIT_EXIT",       -- teleported out of completed sigil dungeon, waiting to land elsewhere
}

local T_CONFIRM    = 0.8    -- wait after use_item before confirming
local T_PORTAL_MAX = 60.0   -- max wait for D4A to teleport us into the dungeon

local nav = {
    state              = STATE.IDLE,
    target_boss        = nil,
    phase_start        = -999,  -- initialised far in the past so no stale timeouts
    attempts           = 0,
    max_attempts       = 5,
    last_enter_try     = 0,
    path_exhausted     = false,
    d4a_sent           = false,
    exploring_retries  = 0,   -- long-path retry count while in EXPLORING state
}

local T_ZONE      = 45.0
local T_D4A_RETRY = 8.0
local T_SETTLE    = 2.5
local T_ENTER     = 15.0

local function now() return get_time_since_inject() end
local function set_state(s) nav.state = s; nav.phase_start = now() end

local function reset_nav()
    nav.state             = STATE.IDLE
    nav.target_boss       = nil
    nav.phase_start       = now()  -- always current so timeout checks start fresh
    nav.attempts          = 0
    nav.path_exhausted    = false
    nav.d4a_sent          = false
    nav.exploring_retries = 0
    map_nav.reset()
    pathwalker.stop_walking()
    if BatmobilePlugin then
        BatmobilePlugin.stop_long_path(plugin_label)
        BatmobilePlugin.clear_target(plugin_label)
    end
end

-- -------------------------------------------------------
-- shouldExecute
-- -------------------------------------------------------
local task = { name = "Navigate to Boss" }

function task.shouldExecute()
    local boss = rotation.current()
    if not boss then return false end
    if rotation.is_done() then return false end

    -- Clear path_exhausted after death
    if tracker.just_revived then
        nav.path_exhausted   = false
        tracker.just_revived = false
        console.print("[Reaper] Post-revive: re-enabling path walk.")
    end

    if tracker.altar_activated then return false end
    if in_target_zone(boss) and chest_visible() then return false end
    if in_target_zone(boss) and utils.get_altar() ~= nil then return false end

    if in_target_zone(boss) then
        -- Stay active while long path navigates to the altar
        if not nav.path_exhausted then
            if nav.state == STATE.IDLE or nav.state == STATE.PATHWALKING or nav.state == STATE.LONG_PATHING or nav.state == STATE.EXPLORING then
                -- After 60s in a sigil dungeon with no enemies, yield to sigil_complete
                if boss.run_type == "sigil" and tracker.sigil_entry_t > 0
                        and (now() - tracker.sigil_entry_t) >= 60.0 then
                    local has_enemy = utils.get_closest_enemy() ~= nil or utils.get_suppressor() ~= nil
                    if not has_enemy then
                        return false  -- let sigil_complete handle the exit
                    end
                end
                return true
            end
        end
        if nav.state ~= STATE.IDLE then
            -- Arriving in the dungeon via MAP_NAV or D4A — refresh the entry timer so the
            -- 60 s stale window counts from dungeon arrival, not from sigil activation.
            local fresh = nav.state == STATE.MAP_NAV
                       or nav.state == STATE.D4A_TELEPORT
                       or nav.state == STATE.WAIT_PORTAL
                       or nav.state == STATE.WALKING
                       or nav.state == STATE.ENTERING
            reset_nav()
            if fresh then tracker.sigil_entry_t = now() end
        end
        return false
    end

    if nav.state ~= STATE.IDLE then return true end
    return true
end

-- -------------------------------------------------------
-- Execute
-- -------------------------------------------------------
function task.Execute()
    local boss = rotation.current()
    if not boss then return end
    local t = now()

    -- ---- IDLE: decide first step ----
    if nav.state == STATE.IDLE then
        console.print(string.format("[Reaper] IDLE — zone=%s  boss=%s  prefix=%s",
            utils.get_zone(), boss.id, boss.zone_prefix))
        nav.target_boss    = boss
        nav.attempts       = 0
        nav.path_exhausted = false
        nav.d4a_sent       = false

        if in_target_zone(boss) then
            if utils.get_altar() ~= nil then reset_nav(); return end
            -- Stale/completed sigil dungeon: tracker.reset_run() sets sigil_entry_t = -999,
            -- so if Alfred returns us here after the run was consumed, the elapsed time will be
            -- huge (now - (-999)) and we exit immediately.  Fresh entry sets sigil_entry_t = now()
            -- in IDLE just before activating the sigil, giving a 60 s grace window to find the altar.
            if boss.run_type == "sigil" and (now() - tracker.sigil_entry_t) > 60.0 then
                console.print("[Reaper] Sigil zone with no altar and entry expired — stale dungeon, teleporting out.")
                teleport_to_waypoint(CERRIGAR_WP)
                set_state(STATE.WAIT_EXIT)
                return
            end
            console.print("[Reaper] In zone – using Batmobile to navigate to altar area.")
            BatmobilePlugin.reset(plugin_label)   -- clear blacklists from prior run
            BatmobilePlugin.resume(plugin_label)
            set_state(STATE.PATHWALKING)
            return
        end

        -- Sigil run: activate the sigil, don't use D4A teleport
        if boss.run_type == "sigil" then
            local sigil = find_sigil_for_boss(boss.id)
            if not sigil then
                console.print("[Reaper] No sigil found for " .. boss.label .. " — skipping.")
                rotation.advance()
                reset_nav()
                return
            end
            console.print("[Reaper] Using sigil for " .. boss.label)
            tracker.sigil_entry_t = now()  -- starts the 60 s fresh-entry window
            local ok, err = pcall(use_item, sigil)
            if not ok then
                console.print("[Reaper] use_item failed: " .. tostring(err))
                tracker.sigil_entry_t = -999
                reset_nav()
                return
            end
            set_state(STATE.USE_SIGIL)
            return
        end

        if settings.use_d4a then
            local sent = d4a.send_teleport(boss.id)
            if sent then
                console.print(string.format("[Reaper] D4A teleport sent for %s.", boss.id))
                nav.d4a_sent = true
            else
                console.print("[Reaper] D4A command failed – will retry.")
            end
            set_state(STATE.D4A_TELEPORT)
        else
            map_nav.start(boss.id)
            set_state(STATE.MAP_NAV)
        end
        return
    end

    -- ---- USE_SIGIL: wait then confirm the consume dialog ----
    if nav.state == STATE.USE_SIGIL then
        if (t - nav.phase_start) >= T_CONFIRM then
            console.print("[Reaper] Confirming sigil notification...")
            utility.confirm_sigil_notification()
            set_state(STATE.CONFIRM_SIGIL)
        end
        return
    end

    -- ---- CONFIRM_SIGIL: wait a moment then navigate to the dungeon ----
    if nav.state == STATE.CONFIRM_SIGIL then
        if (t - nav.phase_start) >= 1.0 then
            if settings.use_sigil_clicks and boss.id ~= "sigil_generic" then
                -- Known boss: teleport to anchor, open map, click boss icon.
                console.print("[Reaper] Sigil confirmed – starting map-nav to " .. boss.id)
                map_nav.start(boss.id)
                set_state(STATE.MAP_NAV)
            else
                -- Unknown/generic sigil: a dungeon portal spawned nearby.
                -- Walk to it and enter directly.
                console.print("[Reaper] Sigil confirmed (generic) – walking to dungeon portal.")
                BatmobilePlugin.resume(plugin_label)
                set_state(STATE.WALKING)
            end
        end
        return
    end

    -- ---- WAIT_PORTAL: wait for zone to change to boss dungeon ----
    if nav.state == STATE.WAIT_PORTAL then
        -- Check if we've loaded into a boss zone
        if in_target_zone(boss) then
            console.print("[Reaper] Entered sigil dungeon: " .. utils.get_zone())
            reset_nav()
            return
        end

        -- Also check for generic lair boss zone pattern
        local zone = utils.get_zone()
        if zone:find("Boss_WT") or zone:find("Boss_Kehj") or zone:find("S12_Boss") then
            console.print("[Reaper] Entered boss zone: " .. zone)
            reset_nav()
            return
        end

        if (t - nav.phase_start) >= T_PORTAL_MAX then
            nav.attempts = nav.attempts + 1
            console.print(string.format("[Reaper] Sigil zone timeout — attempt %d/%d",
                nav.attempts, nav.max_attempts))
            if nav.attempts >= nav.max_attempts then
                console.print("[Reaper] Giving up on sigil run — skipping.")
                rotation.advance()
                reset_nav()
            else
                -- Retry D4A command
                d4a.send_start_nmd_skip_sigil()
                nav.phase_start = t
            end
        end
        return
    end

    -- ---- D4A_TELEPORT: wait for D4Assistant to teleport us ----
    if nav.state == STATE.D4A_TELEPORT then
        -- Success: we arrived in the target zone
        if in_target_zone(boss) then
            console.print("[Reaper] D4A teleport arrived: " .. utils.get_zone())
            nav.attempts  = 0
            nav.d4a_sent  = false
            BatmobilePlugin.resume(plugin_label)
            set_state(STATE.PATHWALKING)
            return
        end

        local elapsed = t - nav.phase_start

        -- Retry: resend command if D4A consumed it but zone never arrived
        if elapsed >= T_D4A_RETRY then
            nav.attempts = nav.attempts + 1
            console.print(string.format("[Reaper] D4A teleport attempt %d/%d timed out – retrying.",
                nav.attempts, nav.max_attempts))
            if nav.attempts >= nav.max_attempts then
                console.print("[Reaper] D4A teleport giving up after " .. nav.max_attempts .. " attempts.")
                reset_nav()
                return
            end
            local sent = d4a.send_teleport(boss.id)
            if sent then
                console.print(string.format("[Reaper] D4A retry %d sent for %s.", nav.attempts, boss.id))
                nav.d4a_sent = true
            end
            nav.phase_start = t  -- reset timer for next wait period
        end
        return
    end

    -- ---- MAP_NAV: drive map_nav state machine (fallback mode) ----
    if nav.state == STATE.MAP_NAV then
        map_nav.update()

        if in_target_zone(boss) then
            console.print("[Reaper] Arrived: " .. utils.get_zone())
            nav.attempts       = 0
            nav.path_exhausted = false
            map_nav.reset()
            BatmobilePlugin.resume(plugin_label)
            set_state(STATE.PATHWALKING)
            return
        end

        if not map_nav.is_active() then
            nav.attempts = nav.attempts + 1
            console.print(string.format("[Reaper] Map nav attempt %d/%d failed – retrying.",
                nav.attempts, nav.max_attempts))
            if nav.attempts >= nav.max_attempts then
                console.print("[Reaper] Giving up after " .. nav.max_attempts .. " attempts.")
                reset_nav(); return
            end
            map_nav.start(boss.id)
        end
        return
    end

    -- ---- PATHWALKING: fire one uncapped long-path request then hand off ----
    if nav.state == STATE.PATHWALKING then
        local altar = utils.get_altar()
        if altar and utils.distance_to(altar) <= 5.0 then
            console.print("[Reaper] Altar in range – navigation done.")
            reset_nav()
            return
        end
        -- Prefer navigating directly to the altar if it is already visible;
        -- fall back to the pre-recorded boss room seed position otherwise.
        local target = altar or enums.positions.getBossRoomPosition(boss.zone_prefix)
        console.print(string.format("[Reaper] Starting long path to %s (no caps, iterate until found)...",
            altar and "altar" or "boss room seed"))
        local ok = BatmobilePlugin.navigate_long_path(plugin_label, target)
        if ok then
            set_state(STATE.LONG_PATHING)
        else
            -- Long path failed — likely a traversal/gap at the dungeon entrance.
            -- Fall back to normal Batmobile navigation which crosses traversals
            -- via navigator.move(), and retry long path every 10s.
            console.print("[Reaper] Long path blocked (traversal?) – switching to EXPLORING.")
            nav.exploring_retries = 0
            set_state(STATE.EXPLORING)
        end
        return
    end

    -- ---- EXPLORING: traversal blocking long path; drive Batmobile normally ----
    -- navigator.move() handles traversal nodes on the fly.
    -- Every 10s we retry long path — it will succeed once we're past the gap.
    if nav.state == STATE.EXPLORING then
        local altar = utils.get_altar()
        if altar and utils.distance_to(altar) <= 5.0 then
            console.print("[Reaper] Altar in range – done.")
            reset_nav()
            return
        end
        if (now() - nav.phase_start) >= 10.0 then
            nav.exploring_retries = nav.exploring_retries + 1
            console.print(string.format("[Reaper] EXPLORING: long path retry %d (traversal crossed?)...",
                nav.exploring_retries))
            local target = altar or enums.positions.getBossRoomPosition(boss.zone_prefix)
            local ok = BatmobilePlugin.navigate_long_path(plugin_label, target)
            if ok then
                console.print("[Reaper] Long path found – switching to LONG_PATHING.")
                set_state(STATE.LONG_PATHING)
                return
            end
            nav.phase_start = now()  -- reset 10s window for next retry
            if nav.exploring_retries >= 10 then
                if boss.run_type == "sigil" then
                    -- Sigil dungeon exhausted — likely a completed/stale dungeon.
                    -- Teleport out and let the sigil flow restart from town.
                    console.print("[Reaper] EXPLORING: sigil dungeon exhausted – teleporting out.")
                    teleport_to_waypoint(CERRIGAR_WP)
                    set_state(STATE.WAIT_EXIT)
                else
                    console.print("[Reaper] EXPLORING: max retries exceeded – resetting.")
                    nav.path_exhausted = true
                    reset_nav()
                end
                return
            end
        end
        -- Drive Batmobile normally — set_target + update + move handles traversals
        local accepted = false
        if altar then
            accepted = BatmobilePlugin.set_target(plugin_label, altar)
        end
        if not accepted then
            accepted = BatmobilePlugin.set_target(plugin_label,
                enums.positions.getBossRoomPosition(boss.zone_prefix))
        end
        if not accepted then
            BatmobilePlugin.clear_target(plugin_label)
        end
        BatmobilePlugin.resume(plugin_label)
        BatmobilePlugin.update(plugin_label)
        BatmobilePlugin.move(plugin_label)
        return
    end

    -- ---- LONG_PATHING: Batmobile drives navigation; we just wait ----
    if nav.state == STATE.LONG_PATHING then
        local altar = utils.get_altar()
        if altar and utils.distance_to(altar) <= 5.0 then
            console.print("[Reaper] Altar in range – long path navigation done.")
            reset_nav()
            return
        end
        -- If long path navigation finished (reached seed position or exhausted path)
        if not BatmobilePlugin.is_long_path_navigating() then
            if altar then
                -- We reached the boss room seed; altar is now visible — navigate to it directly
                console.print("[Reaper] Seed reached – altar visible, starting long path to altar.")
                local ok = BatmobilePlugin.navigate_long_path(plugin_label, altar)
                if not ok then
                    console.print("[Reaper] Altar path failed – resetting.")
                    reset_nav()
                end
                nav.phase_start = now()  -- reset timeout for this final leg
            else
                -- Reached seed but no altar — explore around the boss room to find it.
                -- Avoids instantly resetting to IDLE (which can cause PATHWALKING loops).
                console.print("[Reaper] Seed reached but altar not visible – switching to EXPLORING.")
                nav.exploring_retries = 0
                set_state(STATE.EXPLORING)
            end
            return
        end
        -- Generous timeout: path finding is already done, this is pure walking time
        if (now() - nav.phase_start) > 120.0 then
            console.print("[Reaper] Long path navigation timeout – resetting.")
            reset_nav()
        end
        return
    end

    -- ---- WALKING: walk to dungeon entrance ----
    if nav.state == STATE.WALKING then
        if in_target_zone(boss) and not utils.get_dungeon_entrance() then
            reset_nav(); return
        end
        if (t - nav.phase_start) < T_SETTLE then return end

        local entrance = utils.get_dungeon_entrance()
        if entrance then
            if utils.distance_to(entrance) <= 3.5 then
                BatmobilePlugin.clear_target(plugin_label)
                nav.last_enter_try = 0
                set_state(STATE.ENTERING)
            else
                BatmobilePlugin.set_target(plugin_label, entrance)
                BatmobilePlugin.update(plugin_label)
                BatmobilePlugin.move(plugin_label)
            end
        elseif boss.id ~= "sigil_generic" then
            -- Known boss: walk toward the boss room seed while portal loads
            local seed = enums.positions.getBossRoomPosition(boss.zone_prefix)
            BatmobilePlugin.set_target(plugin_label, seed)
            BatmobilePlugin.update(plugin_label)
            BatmobilePlugin.move(plugin_label)
        end
        -- sigil_generic with no portal yet: stand still and wait
        return
    end

    -- ---- WAIT_EXIT: waiting to leave a completed sigil dungeon ----
    if nav.state == STATE.WAIT_EXIT then
        if not in_target_zone(boss) then
            console.print("[Reaper] Left completed dungeon — restarting run.")
            reset_nav()
            return
        end
        if (now() - nav.phase_start) > 20.0 then
            console.print("[Reaper] WAIT_EXIT timeout — retrying teleport.")
            teleport_to_waypoint(CERRIGAR_WP)
            nav.phase_start = now()
        end
        return
    end

    -- ---- ENTERING ----
    if nav.state == STATE.ENTERING then
        if in_target_zone(boss) and not utils.get_dungeon_entrance() then
            console.print("[Reaper] Entered " .. utils.get_zone())
            reset_nav()
            return
        end
        if (t - nav.phase_start) > T_ENTER then reset_nav(); return end
        if (t - nav.last_enter_try) >= 1.5 then
            nav.last_enter_try = t
            local entrance = utils.get_dungeon_entrance()
            if entrance then
                loot_manager.interact_with_object(entrance)
            else
                set_state(STATE.WALKING)
            end
        end
        return
    end
end

function task.description()
    local s = nav.state
    if s == STATE.IDLE         then return nil end
    if s == STATE.D4A_TELEPORT then
        return string.format("D4A teleport — attempt %d/%d", nav.attempts, nav.max_attempts)
    end
    if s == STATE.MAP_NAV      then return "Map nav — walking to entrance" end
    if s == STATE.USE_SIGIL    then return "Activating sigil..." end
    if s == STATE.CONFIRM_SIGIL then return "Confirming sigil..." end
    if s == STATE.WAIT_PORTAL  then return "Waiting for dungeon portal..." end
    if s == STATE.PATHWALKING  then return "Starting long path to altar..." end
    if s == STATE.LONG_PATHING then return "Long path — walking to altar" end
    if s == STATE.EXPLORING    then
        return string.format("Exploring (traversal) — retry %d/10", nav.exploring_retries)
    end
    if s == STATE.WALKING      then return "Walking to dungeon entrance" end
    if s == STATE.ENTERING     then return "Entering dungeon..." end
    if s == STATE.WAIT_EXIT    then return "Exiting completed dungeon..." end
    return s
end

return task
