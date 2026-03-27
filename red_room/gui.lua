local plugin_label = 'red_room'
local plugin_version = '1.0.13'

local gui = {}

local function create_checkbox(value, key)
    return checkbox:new(value, get_hash(plugin_label .. '_' .. key))
end

gui.elements = {
    main_tree = tree_node:new(0),
    main_toggle = create_checkbox(false, 'main_toggle'),
    set_up = create_checkbox(false, 'set_up'),
    set_up2 = create_checkbox(false, 'set_up2'),
}
function gui.render()
    if not gui.elements.main_tree:push('Red Room | Leoric | v' .. plugin_version) then return end
    gui.elements.main_toggle:render('Enable', 'Enable red room farm')
    gui.elements.set_up:render('setup', 'Draw green circle')
    gui.elements.set_up2:render('setup 2', 'Draw red circle')
    gui.elements.main_tree:pop()
end

return gui