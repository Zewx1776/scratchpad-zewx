local plugin_label = 'minimap_reveal'

local gui = {}
gui.elements = {
    reveal_key     = keybind:new(0x74, false, get_hash(plugin_label .. '_reveal')), -- F5
    cooldown_slider = slider_float:new(0.1, 5.0, 1.0, get_hash(plugin_label .. '_cooldown')),
    main_tree      = tree_node:new(0),
}

local last_reveal_time = 0.0

on_render_menu(function()
    if gui.elements.main_tree:push("Minimap Reveal") then
        gui.elements.reveal_key:render("Reveal Map (F5)")
        gui.elements.cooldown_slider:render("Reveal Cooldown (s)", "Time in seconds between each reveal call", 2)
        gui.elements.main_tree:pop()
    end
end)

on_update(function()
    local now = get_time_since_inject()
    if gui.elements.reveal_key:get_state() == 1 and (now - last_reveal_time) > gui.elements.cooldown_slider:get() then
        last_reveal_time = now
        utility.reveal_minimap()
        console.print("[minimap] Map revealed")
    end
end)

console.print("[minimap_reveal] loaded — F5 to reveal map")
