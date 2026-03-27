local plugin_label = 'azmodan_farm'
local plugin_version = '1.0.13'

local gui = {}

local function create_checkbox(value, key)
    return checkbox:new(value, get_hash(plugin_label .. '_' .. key))
end

gui.plugin_label = plugin_label
gui.plugin_version = plugin_version
gui.priority_options = {
    'Andariel',
    'Belial',
    'Duriel'
}

gui.elements = {
    main_tree = tree_node:new(0),
    main_toggle = create_checkbox(false, 'main_toggle'),
    use_keybind = create_checkbox(false, 'use_keybind'),
    keybind_toggle = keybind:new(0x0A, true, get_hash(plugin_label .. '_keybind_toggle' )),
    chest_toggle = create_checkbox(false, 'chest_toggle'),
    priority = combo_box:new(1, get_hash(plugin_label .. '_priority')),
    drop_sigil_keybind = keybind:new(0x0A, true, get_hash(plugin_label .. '_drop_sigil_keybind' )),
    drop_item_keybind = keybind:new(0x0A, true, get_hash(plugin_label .. '_drop_item_keybind' )),
    kill_tracker_toggle = create_checkbox(false, 'kill_tracker_toggle'),
    use_alfred = create_checkbox(true, 'use_alfred'),
}
function gui.render()
    if not gui.elements.main_tree:push('Azmodan Farm | Leoric | v' .. gui.plugin_version) then return end
    gui.elements.main_toggle:render('Enable', 'Enable azmodan farm')
    gui.elements.use_keybind:render('Use keybind', 'Keybind to quick toggle the bot')
    if gui.elements.use_keybind:get() then
        gui.elements.keybind_toggle:render('Toggle Keybind', 'Toggle the bot for quick enable')
        gui.elements.drop_sigil_keybind:render('Drop non-favourite Sigils', 'Press to drop non-favourite sigils')
        gui.elements.drop_item_keybind:render('Drop non-favourite equipment', 'Press to drop non-favourite equipment')
    end
    gui.elements.chest_toggle:render('Open Chest', 'Enable opening chest if enough materials')
    if gui.elements.chest_toggle:get() then
        gui.elements.priority:render('Chest Priority', gui.priority_options, 'Select which test to priortize')
    end
    gui.elements.kill_tracker_toggle:render('show kill tracker', 'Enable to show azmodan kill time, it disappears if u reload/relogin')
    gui.elements.use_alfred:render('use alfred', 'enable alfred integration')
    gui.elements.main_tree:pop()
end

return gui