-- BatmobileAltClick
-- Moves the cursor to the nearest monster (or a path node within min/max range) then clicks.
-- Draws a green circle at the move target and a smaller blue circle at the click target.

local plugin_label = 'batmobile_alt_click'

local enabled_toggle  = checkbox:new(false, get_hash(plugin_label .. '_enabled'))
local monster_min     = slider_int:new(0,  50,  0,  get_hash(plugin_label .. '_monster_min'))
local monster_dist    = slider_int:new(0,  50, 20,  get_hash(plugin_label .. '_monster_dist'))
local path_min_slider = slider_int:new(0,  50,  5,  get_hash(plugin_label .. '_path_min'))
local path_max_slider = slider_int:new(0,  50, 20,  get_hash(plugin_label .. '_path_max'))
local cooldown_slider = slider_float:new(0.1, 2.0, 0.5, get_hash(plugin_label .. '_cooldown'))
local main_tree       = tree_node:new(0)

local CLICK_DELAY   = 0.05  -- seconds after move before clicking

local last_move     = -math.huge
local pending_click = nil   -- { x, y, time, label, world }

local draw_move_pos  = nil  -- vec3 for green circle
local draw_click_pos = nil  -- vec3 for blue circle

local portal_names = {
    ['EGD_MSWK_World_PortalTileSetTravel']              = true,
    ['EGD_MSWK_World_PortalToFinalEncounter']           = true,
    ['S11_EGD_MSWK_World_BelialPortalToFinalEncounter'] = true,
    ['EGD_MSWK_World_Portal_01']                        = true,
}

local function is_portal(obj)
    if not obj then return false end
    local name = obj:get_skin_name()
    return portal_names[name] == true
end

local function dist2d(a, b)
    local dx = a:x() - b:x()
    local dy = a:y() - b:y()
    return math.sqrt(dx*dx + dy*dy)
end

-- Walk the path and return the first node whose distance from player is between min and max.
-- Falls back to closest node to max if none found, then to navigator target.
local function get_path_point(player_pos, min_d, max_d)
    if not BatmobilePlugin then return nil end
    local path = BatmobilePlugin.get_path()
    if path and #path > 0 then
        -- Find first node in [min, max] range
        for _, node in ipairs(path) do
            local d = dist2d(player_pos, node)
            if d >= min_d and d <= max_d then
                return node
            end
        end
        -- No node in range — return the last node (furthest along the path)
        return path[#path]
    end
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

    if now - last_move < cooldown_slider:get() then return end
    last_move = now

    local player_pos = get_player_position()
    if not player_pos then return end

    local min_monster = monster_min:get()
    local raw_target  = target_selector.get_target_closer(player_pos, monster_dist:get())
    local target = raw_target
    if target then
        if is_portal(target) then
            console.print('[AltClick] skipping portal target: ' .. target:get_skin_name())
            target = nil
        elseif min_monster > 0 and dist2d(player_pos, target:get_position()) < min_monster then
            target = nil
        end
    end

    local world_point, label
    if target then
        world_point = target:get_position()
        label = 'monster'
    else
        local min_d = path_min_slider:get()
        local max_d = path_max_slider:get()
        world_point = get_path_point(player_pos, min_d, max_d)
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
    draw_move_pos = world_point
    pending_click = { x = sx, y = sy, time = now + CLICK_DELAY, label = label, world = world_point }
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
    enabled_toggle:render('Enable', 'Move cursor to nearest monster then click; falls back to nav path point')
    monster_min:render('Monster min range', 'Ignore monsters closer than this distance')
    monster_dist:render('Monster max range', 'Max distance to search for monsters')
    path_min_slider:render('Path point min dist', 'Minimum distance along path to target when no monster')
    path_max_slider:render('Path point max dist', 'Maximum distance along path to target when no monster')
    cooldown_slider:render('Cooldown (s)', 'Seconds between each move+click cycle')
    main_tree:pop()
end)
