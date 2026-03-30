-----------------------------------------------------------
-- pathfinding_test — test plugin for the pathfinding API
-- F5: calculate path from player to cursor
-- F6: clear the drawn path
-- F7: walk to cursor using the calculated path
-----------------------------------------------------------

local plugin_label = 'pathfinding_test'

local gui = {}
gui.elements = {
    calc_path_key  = keybind:new(0x74, false, get_hash(plugin_label .. '_calc_path')),
    clear_path_key = keybind:new(0x75, false, get_hash(plugin_label .. '_clear_path')),
    walk_path_key  = keybind:new(0x76, false, get_hash(plugin_label .. '_walk_path')),
    auto_walk      = checkbox:new(false, get_hash(plugin_label .. '_auto_walk')),
    main_tree      = tree_node:new(0),
}

local current_path    = {}
local current_wp_idx  = 0
local is_walking      = false
local path_calc_ms    = 0.0

-- debounce
local last_calc_time  = 0.0
local last_clear_time = 0.0
local last_walk_time  = 0.0
local KEY_COOLDOWN    = 0.3

-----------------------------------------------------------
-- menu
-----------------------------------------------------------
on_render_menu(function()
    if gui.elements.main_tree:push("Pathfinding Test") then
        gui.elements.calc_path_key:render("Calculate Path (F5)")
        gui.elements.clear_path_key:render("Clear Path (F6)")
        gui.elements.walk_path_key:render("Walk Path (F7)")
        gui.elements.auto_walk:render("Auto-walk on calculate")
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

    -- F5: calculate path (with debounce)
    if gui.elements.calc_path_key:get_state() == 1 and (now - last_calc_time) > KEY_COOLDOWN then
        last_calc_time = now

        local cursor_pos = get_cursor_position()
        local t0 = now
        current_path = world:calculate_path(player_pos, cursor_pos)
        local t1 = get_time_since_inject()
        path_calc_ms = (t1 - t0) * 1000.0

        if #current_path > 0 then
            console.print(string.format(
                "[pathfinding] Path found: %d waypoints (%.1f ms)",
                #current_path, path_calc_ms))

            for i, wp in ipairs(current_path) do
                console.print(string.format(
                    "  [%d] (%.1f, %.1f, %.1f)", i, wp:x(), wp:y(), wp:z()))
            end

            current_wp_idx = 1

            if gui.elements.auto_walk:get() then
                is_walking = true
                console.print("[pathfinding] Auto-walk started")
            end
        else
            console.print("[pathfinding] No path found")
            is_walking = false
        end
    end

    -- F6: clear (with debounce)
    if gui.elements.clear_path_key:get_state() == 1 and (now - last_clear_time) > KEY_COOLDOWN then
        last_clear_time = now
        current_path    = {}
        current_wp_idx  = 0
        is_walking      = false
        console.print("[pathfinding] Path cleared")
    end

    -- F7: toggle walk (with debounce)
    if gui.elements.walk_path_key:get_state() == 1 and (now - last_walk_time) > KEY_COOLDOWN then
        last_walk_time = now
        if #current_path > 0 then
            is_walking = not is_walking
            if is_walking then
                current_wp_idx = 1
                console.print("[pathfinding] Walking started")
            else
                console.print("[pathfinding] Walking stopped")
            end
        else
            console.print("[pathfinding] No path to walk, press F5 first")
        end
    end

    -- walk logic
    if is_walking and #current_path > 0 and current_wp_idx <= #current_path then
        local target_wp = current_path[current_wp_idx]
        local dist      = player_pos:dist_to(target_wp)

        if dist < 1.5 then
            current_wp_idx = current_wp_idx + 1
            if current_wp_idx > #current_path then
                console.print("[pathfinding] Destination reached!")
                is_walking = false
            end
        else
            pathfinder.request_move(target_wp)
        end
    end
end)

-----------------------------------------------------------
-- render
-----------------------------------------------------------
on_render(function()
    if #current_path < 1 then return end

    -- draw path lines and waypoint circles
    for i = 1, #current_path do
        local wp = current_path[i]
        local is_current = (i == current_wp_idx)
        local color = is_current and color_green(220) or color_cyan(160)

        -- waypoint circle
        graphics.circle_3d(wp, 0.3, color, 2.0)

        -- line to next
        if i < #current_path then
            graphics.line(wp, current_path[i + 1], color_cyan(120), 2.0)
        end
    end

    -- status text
    local status = is_walking
        and string.format("Walking [%d/%d]", current_wp_idx, #current_path)
        or  string.format("Path ready [%d wp, %.0fms]", #current_path, path_calc_ms)

    graphics.text_2d(status, vec2:new(10, 60), 18, color_green(255))
end)

-----------------------------------------------------------
console.print("[pathfinding_test] loaded — F5=calc, F6=clear, F7=walk")