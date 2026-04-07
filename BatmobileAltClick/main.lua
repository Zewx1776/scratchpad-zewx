-- BatmobileAltClick
-- Moves the cursor to the nearest monster (or nav point) then clicks on the next tick.
-- Draws a green circle at the move target and a blue circle at the click target.

local plugin_label = 'batmobile_alt_click'

local enabled_toggle = checkbox:new(false, get_hash(plugin_label .. '_enabled'))
local dist_slider    = slider_int:new(0, 50, 20, get_hash(plugin_label .. '_dist'))
local main_tree      = tree_node:new(0)

local MOVE_INTERVAL = 0.5   -- seconds between move+click cycles
local CLICK_DELAY   = 0.05  -- seconds after move before clicking

local last_move     = -math.huge
local pending_click = nil  -- { x, y, time, label, world }

local draw_move_pos  = nil  -- vec3 for green circle
local draw_click_pos = nil  -- vec3 for blue circle

local function get_nav_point()
    if not BatmobilePlugin then return nil end
    local path = BatmobilePlugin.get_path()
    if path and #path > 0 then return path[1] end
    return BatmobilePlugin.get_target()
end

on_update(function()
    if not enabled_toggle:get() then return end

    local now = get_time_since_inject()

    -- Fire pending click once delay has elapsed
    if pending_click and now >= pending_click.time then
        console.print(string.format('[AltClick] click -> screen (%d, %d) [%s]',
            pending_click.x, pending_click.y, pending_click.label))
        utility.send_mouse_click(pending_click.x, pending_click.y)
        draw_click_pos = pending_click.world
        pending_click  = nil
    end

    if now - last_move < MOVE_INTERVAL then return end
    last_move = now

    local player_pos = get_player_position()
    if not player_pos then return end

    local max_dist = dist_slider:get()
    local target = target_selector.get_target_closer(player_pos, max_dist)

    local world_point, label
    if target then
        world_point = target:get_position()
        label = 'monster'
    else
        world_point = get_nav_point()
        label = 'nav'
    end

    if not world_point then return end

    local screen = graphics.w2s(world_point)
    if not screen or screen:is_zero() then return end

    local sx = math.floor(screen.x)
    local sy = math.floor(screen.y)

    console.print(string.format('[AltClick] move -> screen (%d, %d) [%s] (%.1f, %.1f, %.1f)',
        sx, sy, label, world_point:x(), world_point:y(), world_point:z()))

    utility.send_mouse_move(sx, sy)
    draw_move_pos  = world_point
    pending_click  = { x = sx, y = sy, time = now + CLICK_DELAY, label = label, world = world_point }
end)

on_render(function()
    if not enabled_toggle:get() then return end

    if draw_move_pos then
        graphics.circle_3d(draw_move_pos, 1.5, color_green(200))
    end

    if draw_click_pos then
        graphics.circle_3d(draw_click_pos, 0.75, color_blue(200))
    end
end)

on_render_menu(function()
    if not main_tree:push('Batmobile Alt Click') then return end
    enabled_toggle:render('Enable', 'Move cursor to nearest monster then click; falls back to nav point')
    dist_slider:render('Monster range', 'Max distance to look for monsters before falling back to nav point')
    main_tree:pop()
end)
