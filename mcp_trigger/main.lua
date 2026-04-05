-- ============================================================
--  MCP Trigger  v1.0
--  Monitors game state and writes events to a JSON file that
--  the QQT MCP Server (watcher.py) reads to trigger an
--  autonomous Claude agent for game recovery.
--
--  Setup:
--    1. Edit EVENTS_FILE_PATH below to match where you installed
--       qqt-mcp-server (use forward slashes).
--    2. Load this plugin in QQT.
--    3. Enable it via the checkbox in the QQT menu.
-- ============================================================

-- EDIT THIS PATH to match your qqt-mcp-server installation folder
local EVENTS_FILE_PATH = "C:/Users/Zewx/Desktop/diablo_qqt/qqt-mcp-server/events.json"

-- ── Menu ──────────────────────────────────────────────────────────────────────

local developer_id = "mcp_trigger_module_unique_id_"

local menu_elements = {
    main_tree      = tree_node:new(0),
    enable         = checkbox:new(true,  get_hash(developer_id .. "enable_checkbox")),

    settings_tree  = tree_node:new(1),
    no_move_threshold = slider_float:new(10.0, 120.0, 30.0, get_hash(developer_id .. "no_move_threshold_slider")),
    event_cooldown    = slider_float:new(10.0, 300.0, 60.0, get_hash(developer_id .. "event_cooldown_slider")),

    debug_checkbox = checkbox:new(false, get_hash(developer_id .. "debug_checkbox")),
}

local function render_menu()
    if menu_elements.main_tree:push("MCP Trigger") then
        menu_elements.enable:render("Enable MCP Trigger", "Monitor game state and write events for the Claude agent")

        if menu_elements.enable:get() then
            if menu_elements.settings_tree:push("Settings") then
                menu_elements.no_move_threshold:render(
                    "No-Move Threshold (s)",
                    "Seconds without player movement before firing the no_movement event",
                    0
                )
                menu_elements.event_cooldown:render(
                    "Event Cooldown (s)",
                    "Minimum seconds between sending the same event type (prevents spam)",
                    0
                )
                menu_elements.debug_checkbox:render(
                    "Debug Logging",
                    "Print extra info to the QQT console for troubleshooting"
                )
                menu_elements.settings_tree:pop()
            end
        end

        menu_elements.main_tree:pop()
    end
end

-- ── State ─────────────────────────────────────────────────────────────────────

local last_position    = nil
local last_move_time   = 0
local last_event_times = {}
local initialized      = false

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function dbg(msg)
    if menu_elements.debug_checkbox:get() then
        console.print("[MCP Trigger] " .. msg)
    end
end

--- Minimal JSON serialiser for flat string / number / boolean tables.
local function to_json(t)
    local parts = {}
    for k, v in pairs(t) do
        local key = '"' .. tostring(k) .. '"'
        local val
        if type(v) == "string" then
            local escaped = v:gsub("\\", "\\\\"):gsub('"', '\\"')
            val = '"' .. escaped .. '"'
        elseif type(v) == "boolean" then
            val = tostring(v)
        else
            val = tostring(v)
        end
        parts[#parts + 1] = key .. ": " .. val
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

--- Write an event to the shared events.json file.
--- @param event_type  string   Short identifier, e.g. "no_movement"
--- @param message     string   Human-readable description
--- @param extra       table?   Optional extra key/value pairs
local function send_event(event_type, message, extra)
    local now     = get_time_since_inject()
    local cooldown = menu_elements.event_cooldown:get()

    -- Per-type cooldown
    if last_event_times[event_type] then
        if (now - last_event_times[event_type]) < cooldown then
            dbg("Event '" .. event_type .. "' skipped (cooldown)")
            return
        end
    end
    last_event_times[event_type] = now

    -- Build payload
    local event = {
        event       = event_type,
        message     = message,
        plugin_time = now,
        player_name = get_local_player_name() or "unknown",
    }
    if extra then
        for k, v in pairs(extra) do
            event[k] = v
        end
    end

    local json_str = to_json(event)

    -- Read existing array
    local existing = "[]"
    local rf = io.open(EVENTS_FILE_PATH, "r")
    if rf then
        existing = rf:read("*a") or "[]"
        rf:close()
    end

    -- Trim and append
    existing = existing:match("^%s*(.-)%s*$")
    if existing == "" then existing = "[]" end

    local without_close = existing:match("^(.-)%s*%]%s*$") or "["
    local new_array

    if without_close:match("^%[%s*$") then
        new_array = "[\n  " .. json_str .. "\n]"
    else
        new_array = without_close .. ",\n  " .. json_str .. "\n]"
    end

    local wf = io.open(EVENTS_FILE_PATH, "w")
    if wf then
        wf:write(new_array)
        wf:close()
        console.print("[MCP Trigger] Event sent: " .. event_type .. " — " .. message)
    else
        console.print("[MCP Trigger] ERROR: Could not write to: " .. EVENTS_FILE_PATH)
        console.print("[MCP Trigger] Check EVENTS_FILE_PATH at the top of main.lua")
    end
end

local function positions_moved(a, b, threshold)
    local dx = a:x() - b:x()
    local dy = a:y() - b:y()
    return (dx * dx + dy * dy) >= (threshold * threshold)
end

-- ── Update ────────────────────────────────────────────────────────────────────

local function on_updates()
    if not menu_elements.enable:get() then
        return
    end

    local now = get_time_since_inject()

    -- One-time init: seed timestamps so we don't fire immediately on load
    if not initialized then
        last_move_time = now
        for _, t in ipairs({"no_movement", "player_not_found"}) do
            last_event_times[t] = now - (menu_elements.event_cooldown:get() * 0.5)
        end
        initialized = true
        console.print("[MCP Trigger] Active. Watching for game state issues.")
        console.print("[MCP Trigger] Events file: " .. EVENTS_FILE_PATH)
    end

    -- ── Check 1: Player object ────────────────────────────────────────────────
    local player = get_local_player()
    if not player then
        send_event(
            "player_not_found",
            "get_local_player() returned nil — player may be disconnected or at the login screen"
        )
        -- Reset movement baseline to avoid stacking a no_movement event too
        last_position  = nil
        last_move_time = now
        return
    end

    -- ── Check 2: Movement detection ───────────────────────────────────────────
    local pos       = get_player_position()
    local threshold = menu_elements.no_move_threshold:get()

    if pos then
        if last_position then
            if positions_moved(pos, last_position, 1.0) then
                dbg("Movement detected, resetting timer")
                last_move_time = now
                last_position  = pos
            end
        else
            last_move_time = now
            last_position  = pos
        end

        local idle = now - last_move_time
        if idle >= threshold then
            send_event(
                "no_movement",
                string.format("No player movement for %.0f seconds", idle),
                { idle_seconds = math.floor(idle) }
            )
            last_move_time = now
        else
            dbg(string.format("Idle: %.1fs / %.0fs threshold", idle, threshold))
        end
    end
end

-- ── Manual test (call from QQT console to verify the pipeline) ────────────────
-- Usage: mcp_test_trigger()
function mcp_test_trigger()
    last_event_times["manual_test"] = nil
    send_event("manual_test", "Manual test trigger fired from QQT console")
end

-- ── Register callbacks ────────────────────────────────────────────────────────

on_render_menu(render_menu)
on_update(on_updates)

console.print("Lua Plugin - MCP Trigger - Version 1.0")
