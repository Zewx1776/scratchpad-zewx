-- ============================================================
--  Reaper - core/map_nav.lua
--
--  Flow:
--    1. If not in anchor zone → teleport_to_waypoint(anchor)
--    2. Wait to confirm arrival in correct zone
--    3. Walk to Waypoint_Temp stone and interact_object it
--    4. Wait 1.5s for map UI to open
--    5. Click boss icon
--    6. Wait 0.5s
--    7. Click Accept (888, 640)
--    8. Wait for boss zone to load
--    If zone never arrives → retry from step 1
-- ============================================================

local map_nav = {}

-- -------------------------------------------------------
-- Waypoint IDs (confirmed)
-- -------------------------------------------------------
local NEVESK_WP    = 0x6D945
local ZARBINZET_WP = 0xA46E5

-- Confirmed zone names on arrival
local NEVESK_ZONE    = "Frac_Taiga_S"
local ZARBINZET_ZONE = "Hawe_Zarbinzet"

local TWO_CLICK = { zir = true }

-- -------------------------------------------------------
-- Boss → anchor
-- -------------------------------------------------------
local BOSS_ANCHOR = {
    grigoire = "nevesk",
    beast    = "nevesk",
    zir      = "nevesk",
    varshan  = "nevesk",
    belial   = "nevesk",
    andariel = "nevesk",
    duriel   = "nevesk",
    butcher  = "nevesk",
    urivar   = "zarbinzet",
    harbinger= "zarbinzet",
}

local gui = require "gui"

-- -------------------------------------------------------
-- Click helpers — read live pixel values from GUI sliders
-- -------------------------------------------------------
local function click_boss(boss_id, step2)
    local rx, ry
    if step2 then
        rx, ry = gui.get_zir2_icon()
    else
        rx, ry = gui.get_boss_icon(boss_id)
    end
    if not rx then
        console.print("[MapNav] No icon coords for: " .. tostring(boss_id))
        return
    end
    local sw = get_screen_width()
    local sh = get_screen_height()
    local x  = math.floor(sw * rx)
    local y  = math.floor(sh * ry)
    console.print(string.format(
        "[MapNav] click boss %s  screen=%dx%d  ratio=(%.4f,%.4f)  px=(%d,%d)",
        boss_id, sw, sh, rx, ry, x, y))
    utility.send_mouse_move(x, y)
    utility.send_mouse_click(x, y)
end

local function click_accept()
    local rx, ry = gui.get_accept()
    local sw = get_screen_width()
    local sh = get_screen_height()
    local x  = math.floor(sw * rx)
    local y  = math.floor(sh * ry)
    console.print(string.format(
        "[MapNav] click Accept  screen=%dx%d  ratio=(%.4f,%.4f)  px=(%d,%d)",
        sw, sh, rx, ry, x, y))
    utility.send_mouse_move(x, y)
    utility.send_mouse_click(x, y)
end

-- -------------------------------------------------------
-- Helpers
-- -------------------------------------------------------
local function get_anchor_wp(anchor)
    return anchor == "zarbinzet" and ZARBINZET_WP or NEVESK_WP
end

local function get_anchor_zone(anchor)
    return anchor == "zarbinzet" and ZARBINZET_ZONE or NEVESK_ZONE
end

local function current_zone()
    return get_current_world():get_current_zone_name()
end

local function in_anchor_zone(anchor)
    return current_zone() == get_anchor_zone(anchor)
end

local function find_waypoint_stone()
    local lp = get_local_player()
    if not lp then return nil end
    local pp = lp:get_position()
    local best, best_dist = nil, 20.0
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local n = actor:get_skin_name()
        if type(n) == "string" and n:find("^Waypoint") then
            local ok, inter = pcall(function() return actor:is_interactable() end)
            if ok and inter then
                local d = pp:dist_to(actor:get_position())
                if d < best_dist then best = actor; best_dist = d end
            end
        end
    end
    return best
end

-- -------------------------------------------------------
-- State machine
-- -------------------------------------------------------
local STATE = {
    IDLE         = "IDLE",
    WAIT_ANCHOR  = "WAIT_ANCHOR",    -- waiting to land in nevesk/zarbinzet
    WALK_TO_WP   = "WALK_TO_WP",     -- walking to waypoint stone
    INTERACT_WP  = "INTERACT_WP",    -- interacting with stone
    WAIT_MAP     = "WAIT_MAP",       -- waiting for map UI
    CLICK_BOSS   = "CLICK_BOSS",     -- clicking boss icon
    CLICK_BOSS2  = "CLICK_BOSS2",    -- second click (Zir)
    WAIT_ACCEPT  = "WAIT_ACCEPT",    -- brief pause before Accept
    CLICK_ACCEPT = "CLICK_ACCEPT",   -- clicking Accept
    WAIT_ZONE    = "WAIT_ZONE",      -- waiting to land in boss zone
    DONE         = "DONE",
}

local s = {
    state       = STATE.IDLE,
    t           = -999,  -- far in the past so no stale timeouts on first check
    boss_id     = nil,
    anchor      = nil,
    attempts    = 0,
    click_tries = 0,
    last_nudge  = 0,
}
local MAX_ATTEMPTS  = 3
local T_TELEPORT    = 20.0   -- max wait for zone after teleport
local T_MAP_OPEN    = 1.0    -- wait after interact_object before clicking boss icon
local T_BETWEEN     = 0.5    -- pause between sequential clicks
local T_ZONE        = 40.0   -- max wait for boss zone to load
local T_CLICK_RETRY = 0.5    -- gap between click retries
local MAX_CLICK_TRIES = 3    -- max click attempts for boss icon
local MAX_ACCEPT_TRIES = 1   -- accept only needs one click

local function now()      return get_time_since_inject() end
local function set_state(st) s.state = st; s.t = now() end
local function elapsed()  return now() - s.t end

-- -------------------------------------------------------
-- Public API
-- -------------------------------------------------------
function map_nav.start(boss_id)
    s.boss_id  = boss_id
    s.anchor   = BOSS_ANCHOR[boss_id] or "nevesk"
    s.attempts = 0
    console.print(string.format("[MapNav] Starting nav to %s via %s", boss_id, s.anchor))

    if in_anchor_zone(s.anchor) then
        console.print("[MapNav] Already in anchor zone.")
        set_state(STATE.WALK_TO_WP)
    else
        teleport_to_waypoint(get_anchor_wp(s.anchor))
        set_state(STATE.WAIT_ANCHOR)
    end
end

function map_nav.is_done()   return s.state == STATE.DONE end
function map_nav.is_active() return s.state ~= STATE.IDLE and s.state ~= STATE.DONE end
function map_nav.reset()     s.state = STATE.IDLE; s.boss_id = nil end
function map_nav.get_state() return s.state end

local function retry()
    s.attempts = s.attempts + 1
    console.print(string.format("[MapNav] Retry %d/%d", s.attempts, MAX_ATTEMPTS))
    if s.attempts >= MAX_ATTEMPTS then
        console.print("[MapNav] Giving up.")
        map_nav.reset()
        return
    end
    -- Go back to anchor teleport
    teleport_to_waypoint(get_anchor_wp(s.anchor))
    set_state(STATE.WAIT_ANCHOR)
end

function map_nav.update()
    if s.state == STATE.IDLE or s.state == STATE.DONE then return end

    -- ---- WAIT_ANCHOR ----
    if s.state == STATE.WAIT_ANCHOR then
        if in_anchor_zone(s.anchor) then
            console.print("[MapNav] Arrived at " .. s.anchor .. " (" .. current_zone() .. ")")
            -- Wait 2s for actors to load, then walk to stone
            if elapsed() >= 2.0 then
                set_state(STATE.WALK_TO_WP)
            end
            return
        end
        if elapsed() >= T_TELEPORT then
            s.attempts = s.attempts + 1
            if s.attempts >= MAX_ATTEMPTS then map_nav.reset(); return end
            teleport_to_waypoint(get_anchor_wp(s.anchor))
            set_state(STATE.WAIT_ANCHOR)
        end
        return
    end

    -- ---- WALK_TO_WP ----
    if s.state == STATE.WALK_TO_WP then
        local stone = find_waypoint_stone()
        if not stone then
            if elapsed() >= 10.0 then
                console.print("[MapNav] Cannot find waypoint stone.")
                retry(); return
            end
            return
        end
        local lp = get_local_player()
        local dist = lp and lp:get_position():dist_to(stone:get_position()) or 999
        if dist <= 3.0 then
            set_state(STATE.INTERACT_WP)
        else
            pathfinder.request_move(stone:get_position())
        end
        return
    end

    -- ---- INTERACT_WP ----
    -- Walk to the stone and send the first interact, then hand off to WAIT_MAP.
    if s.state == STATE.INTERACT_WP then
        local stone = find_waypoint_stone()
        if not stone then
            set_state(STATE.WALK_TO_WP)
            return
        end
        local lp   = get_local_player()
        local dist = lp and lp:get_position():dist_to(stone:get_position()) or 999
        if dist > 3.0 then
            pathfinder.request_move(stone:get_position())
            return
        end
        interact_object(stone)
        console.print("[MapNav] Interacting with waypoint stone...")
        set_state(STATE.WAIT_MAP)
        return
    end

    -- ---- WAIT_MAP ----
    -- Brief pause after interact_object so the map UI has time to open.
    -- The map opens quickly (~0.3-0.5s); 1s gives comfortable headroom
    -- without leaving it open long enough to auto-dismiss.
    if s.state == STATE.WAIT_MAP then
        if elapsed() >= T_MAP_OPEN then
            console.print("[MapNav] Map should be open - clicking boss.")
            s.click_tries = 0
            set_state(STATE.CLICK_BOSS)
            return
        end
        -- Nudge stone every 0.8s while waiting
        local time_since_nudge = now() - (s.last_nudge or 0)
        if time_since_nudge >= 0.8 then
            local stone = find_waypoint_stone()
            if stone then
                local lp   = get_local_player()
                local dist = lp and lp:get_position():dist_to(stone:get_position()) or 999
                if dist <= 3.0 then
                    interact_object(stone)
                    console.print("[MapNav] Re-interacting with waypoint stone...")
                end
            end
            s.last_nudge = now()
        end
        return
    end

    -- ---- CLICK_BOSS ----
    -- Clicks the boss icon and retries up to MAX_CLICK_TRIES times with a short
    -- delay between attempts, in case the map UI was still animating open.
    if s.state == STATE.CLICK_BOSS then
        if elapsed() >= T_CLICK_RETRY or s.click_tries == 0 then
            s.click_tries = s.click_tries + 1
            click_boss(s.boss_id, false)
            console.print(string.format("[MapNav] Clicked boss: %s (attempt %d/%d)",
                s.boss_id, s.click_tries, MAX_CLICK_TRIES))

            if s.click_tries >= MAX_CLICK_TRIES then
                -- Enough clicks sent — move on regardless
                s.click_tries = 0
                if TWO_CLICK[s.boss_id] then
                    set_state(STATE.CLICK_BOSS2)
                else
                    set_state(STATE.WAIT_ACCEPT)
                end
            else
                -- Reset timer so we wait T_CLICK_RETRY before the next attempt
                s.t = now()
            end
        end
        return
    end

    -- ---- CLICK_BOSS2 (Zir only) ----
    if s.state == STATE.CLICK_BOSS2 then
        if elapsed() >= T_BETWEEN then
            click_boss(s.boss_id, true)
            console.print("[MapNav] Clicked boss step2.")
            set_state(STATE.WAIT_ACCEPT)
        end
        return
    end

    -- ---- WAIT_ACCEPT ----
    if s.state == STATE.WAIT_ACCEPT then
        if elapsed() >= T_BETWEEN then
            s.click_tries = 0
            set_state(STATE.CLICK_ACCEPT)
        end
        return
    end

    -- ---- CLICK_ACCEPT ----
    -- Retries the Accept click a couple of times in case the confirm dialog
    -- was not yet visible when the first click fired.
    if s.state == STATE.CLICK_ACCEPT then
        if elapsed() >= T_CLICK_RETRY or s.click_tries == 0 then
            s.click_tries = s.click_tries + 1
            click_accept()
            console.print(string.format("[MapNav] Clicked Accept (attempt %d/%d)",
                s.click_tries, MAX_ACCEPT_TRIES))

            if s.click_tries >= MAX_ACCEPT_TRIES then
                s.click_tries = 0
                -- Close the map in case the accept dialog never appeared,
                -- so the UI is in a clean state for the next retry.
                utility.send_key_press(0x1B)
                set_state(STATE.WAIT_ZONE)
            else
                s.t = now()
            end
        end
        return
    end

    -- ---- WAIT_ZONE ----
    if s.state == STATE.WAIT_ZONE then
        -- After 3s, if still in anchor zone, Accept didn't land — redo the map click
        if elapsed() >= 3.0 and in_anchor_zone(s.anchor) then
            console.print("[MapNav] Still in anchor zone after Accept – redoing map click.")
            set_state(STATE.WALK_TO_WP)
            return
        end
        -- navigate_to_boss checks zone arrival; we just enforce timeout
        if elapsed() >= T_ZONE then
            console.print("[MapNav] Boss zone timeout – retrying.")
            retry()
        end
        return
    end
end

return map_nav
