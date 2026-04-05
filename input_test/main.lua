local plugin_label = 'input_test'

local saved_x = nil
local saved_y = nil

local menu_elements = {
    main_tree        = tree_node:new(0),
    save_pos_key     = keybind:new(0x74, false, get_hash(plugin_label .. '_save_pos')),      -- F5: save current mouse pos
    click_saved_key  = keybind:new(0x75, false, get_hash(plugin_label .. '_click_saved')),   -- F6: click at saved pos
    rclick_saved_key = keybind:new(0x76, false, get_hash(plugin_label .. '_rclick_saved')),  -- F7: right click at saved pos
}

local function render_menu()
    if menu_elements.main_tree:push("Input Test") then
        menu_elements.save_pos_key:render("Save Cursor Pos", "F5: save current cursor screen position")
        menu_elements.click_saved_key:render("Left Click Saved", "F6: left click at saved position")
        menu_elements.rclick_saved_key:render("Right Click Saved", "F7: right click at saved position")
        menu_elements.main_tree:pop()
    end
end

local function on_updates()
    if menu_elements.save_pos_key:get_state() == 1 then
        saved_x, saved_y = utility.get_cursor_screen_position()
        console.print(string.format("[input test] SAVED position: %d, %d", saved_x, saved_y))
    end

    if menu_elements.click_saved_key:get_state() == 1 then
        if saved_x then
            console.print(string.format("[input test] LEFT click at SAVED %d, %d (mouse is elsewhere)", saved_x, saved_y))
            utility.send_mouse_click(saved_x, saved_y)
        else
            console.print("[input test] no position saved yet, press F5 first")
        end
    end

    if menu_elements.rclick_saved_key:get_state() == 1 then
        if saved_x then
            console.print(string.format("[input test] RIGHT click at SAVED %d, %d (mouse is elsewhere)", saved_x, saved_y))
            utility.send_mouse_right_click(saved_x, saved_y)
        else
            console.print("[input test] no position saved yet, press F5 first")
        end
    end
end

-- callbacks
on_render_menu(render_menu)
on_update(on_updates)

console.print("[input test] F5 = save cursor pos, F6 = left click saved, F7 = right click saved")
