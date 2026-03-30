-----------------------------------------------------------
-- MapRevealPathTest
--   reveal    : reveal minimap
--   set target: pin cursor position as path goal (snaps Z via world API)
--   calc path : calculate path player → target  (world:calculate_path)
--   walk      : toggle walking along path        (pathfinder.request_move)
--   All keybinds are user-configurable via the menu.
-----------------------------------------------------------

local plugin_label = 'map_reveal_pathtest'

local gui = {}
gui.elements = {
    reveal_key     = keybind:new(0x0A, true, get_hash(plugin_label .. '_reveal')),
    set_target_key = keybind:new(0x0A, true, get_hash(plugin_label .. '_set_target')),
    calc_path_key  = keybind:new(0x0A, true, get_hash(plugin_label .. '_calc_path')),
    walk_key       = keybind:new(0x0A, true, get_hash(plugin_label .. '_walk')),
    auto_walk      = checkbox:new(false, get_hash(plugin_label .. '_auto_walk')),
    main_tree      = tree_node:new(0),
}

local pinned_target  = nil   -- vec3 pinned by F6
local current_path   = {}    -- result of world:calculate_path()
local current_wp_idx = 1
local is_walking     = false
local path_calc_ms   = 0.0

-- key debounce
local last_reveal_time     = 0.0
local last_set_target_time = 0.0
local last_calc_time       = 0.0
local last_walk_time       = 0.0
local KEY_COOLDOWN         = 0.3
local REVEAL_COOLDOWN      = 1.0

-----------------------------------------------------------
-- helpers
-----------------------------------------------------------
local function stop_walk()
    is_walking       = false
    current_wp_idx   = 1
end

local function fmt_pos(v)
    return string.format("(%.1f, %.1f, %.1f)", v:x(), v:y(), v:z())
end

-----------------------------------------------------------
-- menu
-----------------------------------------------------------
on_render_menu(function()
    if gui.elements.main_tree:push("Map Reveal + Path Test") then
        gui.elements.reveal_key:render("Reveal Map", "Reveal the minimap for the current zone")
        gui.elements.set_target_key:render("Pin Target at Cursor", "Pin the cursor world position as the path goal (snaps to nav mesh height)")
        gui.elements.calc_path_key:render("Calculate Path", "Run world:calculate_path from player to pinned target and log waypoints")
        gui.elements.walk_key:render("Toggle Walk", "Start or stop walking the calculated path via pathfinder.request_move")
        gui.elements.auto_walk:render("Auto-walk on calculate", "Automatically start walking as soon as a path is found")
        gui.elements.main_tree:pop()
    end
end)

-----------------------------------------------------------
-- update
-----------------------------------------------------------
on_update(function()
    local world  = get_current_world()
    local player = get_local_player()
    if not world or not player then return end

    local player_pos = player:get_position()
    local now        = get_time_since_inject()

    -- reveal minimap
    if gui.elements.reveal_key:get_state() == 1 and (now - last_reveal_time) > REVEAL_COOLDOWN then
        last_reveal_time = now
        if utility.reveal_minimap then
            utility.reveal_minimap()
            console.print("[MapRevealPathTest] Map revealed")
        else
            console.print("[MapRevealPathTest] utility.reveal_minimap not available in this runtime")
        end
    end

    -- pin target at cursor
    if gui.elements.set_target_key:get_state() == 1 and (now - last_set_target_time) > KEY_COOLDOWN then
        last_set_target_time = now
        local cursor = get_cursor_position()
        if cursor then
            -- snap Z to valid nav mesh height
            world:set_height_of_valid_position(cursor)
            pinned_target = cursor
            stop_walk()
            current_path  = {}
            console.print("[MapRevealPathTest] Target pinned at " .. fmt_pos(pinned_target))
        else
            console.print("[MapRevealPathTest] No cursor position available")
        end
    end

    -- calculate path to pinned target
    if gui.elements.calc_path_key:get_state() == 1 and (now - last_calc_time) > KEY_COOLDOWN then
        last_calc_time = now
        if not pinned_target then
            console.print("[MapRevealPathTest] No target pinned — press F6 first")
        else
            stop_walk()
            local t0 = get_time_since_inject()
            current_path = world:calculate_path(player_pos, pinned_target)
            path_calc_ms = (get_time_since_inject() - t0) * 1000.0

            if #current_path > 0 then
                console.print(string.format(
                    "[MapRevealPathTest] Path found: %d waypoints (%.1f ms)",
                    #current_path, path_calc_ms))
                for i, wp in ipairs(current_path) do
                    console.print(string.format("  [%d] %s", i, fmt_pos(wp)))
                end
                current_wp_idx = 1
                if gui.elements.auto_walk:get() then
                    is_walking = true
                    console.print("[MapRevealPathTest] Auto-walk started")
                end
            else
                console.print("[MapRevealPathTest] No path found to target")
            end
        end
    end

    -- toggle walk
    if gui.elements.walk_key:get_state() == 1 and (now - last_walk_time) > KEY_COOLDOWN then
        last_walk_time = now
        if #current_path == 0 then
            console.print("[MapRevealPathTest] No path — press F7 to calculate first")
        else
            is_walking = not is_walking
            if is_walking then
                current_wp_idx = 1
                console.print("[MapRevealPathTest] Walking started")
            else
                console.print("[MapRevealPathTest] Walking stopped")
            end
        end
    end

    -- walk logic: follow path waypoints via pathfinder.request_move
    if is_walking and #current_path > 0 then
        if current_wp_idx > #current_path then
            console.print("[MapRevealPathTest] Destination reached!")
            stop_walk()
        else
            local target_wp = current_path[current_wp_idx]
            local dist      = player_pos:dist_to(target_wp)
            if dist < 1.5 then
                current_wp_idx = current_wp_idx + 1
            else
                pathfinder.request_move(target_wp)
            end
        end
    end
end)

-----------------------------------------------------------
-- render: draw path and status
-----------------------------------------------------------
on_render(function()
    -- draw pinned target marker
    if pinned_target then
        graphics.circle_3d(pinned_target, 0.5, color_red(220), 2.0)
    end

    -- draw path waypoints and connecting lines
    if #current_path > 0 then
        for i = 1, #current_path do
            local wp       = current_path[i]
            local is_curr  = (i == current_wp_idx)
            local col      = is_curr and color_green(220) or color_cyan(160)
            graphics.circle_3d(wp, 0.3, col, 2.0)
            if i < #current_path then
                graphics.line(wp, current_path[i + 1], color_cyan(120), 2.0)
            end
        end

        -- HUD status
        local status
        if is_walking then
            status = string.format("Walking [%d/%d]", current_wp_idx, #current_path)
        else
            status = string.format("Path ready [%d wp, %.0f ms]", #current_path, path_calc_ms)
        end
        graphics.text_2d(status, vec2:new(10, 60), 18, color_green(255))
    end

    -- show pinned target coords on HUD
    if pinned_target then
        local info = string.format("Target: %s", fmt_pos(pinned_target))
        graphics.text_2d(info, vec2:new(10, 82), 16, color_red(200))
    end
end)

-----------------------------------------------------------
console.print("[MapRevealPathTest] loaded — bind keys via menu: reveal / pin target / calc path / walk")
