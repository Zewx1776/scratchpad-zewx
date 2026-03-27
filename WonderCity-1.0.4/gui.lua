local plugin_label = 'wonder_city'
local plugin_version = '1.0.4'
console.print("Lua Plugin - WonderCity - Leoric - v" .. plugin_version)

local gui = {}

local create_checkbox = function (value, key)
    return checkbox:new(value, get_hash(plugin_label .. '_' .. key))
end

gui.party_modes_enum = {
    LEADER = 0,
    FOLLOWER = 1
}
gui.party_mode = { 'Leader', 'Follower'}

gui.tributes = {}
gui.tributes_enum = {}
gui.tributes_data = {
    {sno_id = 2125049, skin_name = 'Tribute of Ascendance', name = 'Ascendance', enum = 'ASCENDANCE'},
    {sno_id = 2485152, skin_name = 'Major Tribute of Andariel', name = 'Major Andariel', enum = 'MAJOR_ANDARIEL'},
    {sno_id = 2485144, skin_name = 'Tribute of Andariel', name = 'Andariel', enum = 'ANDARIEL'},
    {sno_id = 2090358, skin_name = 'Tribute of Titans', name = 'Titans', enum = 'TITANS'},
    {sno_id = 2447394, skin_name = 'Minor Tribute of Andariel', name = 'Minor Andariel', enum = 'MINOR_ANDARIEL'},
    {sno_id = 2077995, skin_name = 'Tribute of Refinement', name = 'Refinement', enum = 'REFINEMENT'},
    {sno_id = 2090362, skin_name = 'Tribute of Ascendance (Resolute)', name = 'Ascendance (R)', enum = 'ASCENDANCE_RESOLUTE'},
    {sno_id = 2125691, skin_name = 'Tribute of Harmony', name = 'Harmony', enum = 'HARMONY'},
    {sno_id = 2131528, skin_name = 'Tribute of Mystique', name = 'Mystique', enum = 'MYSTIQUE'},
    {sno_id = 2125047, skin_name = 'Tribute of Radiance', name = 'Radiance', enum = 'RADIANCE'},
    {sno_id = 2090360, skin_name = 'Tribute of Pride', name = 'Pride', enum = 'PRIDE'},
    {sno_id = 2077998, skin_name = 'Tribute of Radiance (Resolute)', name = 'Radiance (R)', enum = 'RADIUS_RESOLUTE'},
    {sno_id = 2125688, skin_name = 'Tribute of Growth', name = 'Growth', enum = 'GROWTH'},
    {sno_id = 2077993, skin_name = 'Tribute of Heritage', name = 'Heritage', enum = 'HERITAGE'},
}
gui.batmobile_priority = {
    'direction',
    'distance'
}
gui.batmobile_priority_enum = {
    DIRECTION = 0,
    DISTANCE = 1
}
for _, tribute in ipairs(gui.tributes_data) do
    gui.tributes[#gui.tributes+1] = tribute.name
    gui.tributes_enum[#gui.tributes_enum+1] = tribute.sno_id
end


gui.plugin_label = plugin_label
gui.plugin_version = plugin_version
gui.elements = {
    main_tree = tree_node:new(0),
    main_toggle = create_checkbox(false, 'main_toggle'),
    use_keybind = create_checkbox(false, 'use_keybind'),
    keybind_toggle = keybind:new(0x0A, true, get_hash(plugin_label .. '_keybind_toggle' )),
    undercity_settings_tree = tree_node:new(1),
    reset_timeout = slider_int:new(30, 900, 600, get_hash(plugin_label .. '_' .. 'reset_timeout')),
    boss_delay = slider_int:new(0, 30, 10, get_hash(plugin_label .. '_' .. 'boss_delay')),
    exit_undercity_delay = slider_int:new(0, 300, 10, get_hash(plugin_label .. '_' .. 'exit_undercity_delay')),
    loot_obols = create_checkbox(true, 'loot_obols'),
    max_enticement = slider_int:new(0, 9, 5, get_hash(plugin_label .. '_' .. 'max_enticement')),
    enticement_timeout = slider_int:new(0, 10, 4, get_hash(plugin_label .. '_' .. 'enticement_timeout')),
    beacon_timeout = slider_int:new(0, 30, 10, get_hash(plugin_label .. '_' .. 'beacon_timeout')),
    batmobile_priority = combo_box:new(1, get_hash(plugin_label .. '_' .. 'batmobile_priority')),

    reorder_tribute = create_checkbox(false, 'reorder_tribute'),
    tribute_1 = combo_box:new(0, get_hash(plugin_label .. '_' .. 'tribute_1')),
    tribute_2 = combo_box:new(0, get_hash(plugin_label .. '_' .. 'tribute_2')),
    tribute_3 = combo_box:new(0, get_hash(plugin_label .. '_' .. 'tribute_3')),


    party_settings_tree = tree_node:new(1),
    party_enabled = create_checkbox(false, 'party_enabled'),
    party_mode = combo_box:new(0, get_hash(plugin_label .. '_' .. 'party_mode')),
    -- start_undercity_delay = slider_int:new(1, 300, 5, get_hash(plugin_label .. '_' .. 'start_undercity_delay')),
    confirm_delay = slider_int:new(1, 300, 5, get_hash(plugin_label .. '_' .. 'confirm_delay')),
    use_magoogle_tool = create_checkbox(false, 'use_magoogle_tool'),
    follower_explore = create_checkbox(false, 'follower_explore'),
}
gui.render = function ()
    if not gui.elements.main_tree:push('WonderCity | Leoric | v' .. gui.plugin_version) then return end
    if AlfredTheButlerPlugin == nil then
        render_menu_header('This plugin requires AlfredTheButlerPlugin to work')
    end
    if BatmobilePlugin == nil then
        render_menu_header('This plugin requires BatmobilePlugin to work')
    end
    if LooteerPlugin == nil then
        render_menu_header('This plugin requires LooteerPlugin to work')
    end
    if BatmobilePlugin == nil or AlfredTheButlerPlugin == nil or LooteerPlugin == nil then
        gui.elements.main_tree:pop()
        return
    end
    gui.elements.main_toggle:render('Enable', 'Enable WonderCity')
    gui.elements.use_keybind:render('Use keybind', 'Keybind to quick toggle the bot')
    if gui.elements.use_keybind:get() then
        gui.elements.keybind_toggle:render('Toggle Keybind', 'Toggle the bot for quick enable')
    end
    if gui.elements.undercity_settings_tree:push('Undercity Settings') then
        gui.elements.batmobile_priority:render('Batmobile priority', gui.batmobile_priority, 'Select whether to priortize direction or distance while exploring')
        if gui.elements.batmobile_priority:get() == 1 then
            render_menu_header('[EXPERIMENTAL] Priortizing distance will use more processing power. ' ..
                'Depending on layout, might result in more backtracking.' ..
                'In general, it should be better for undercity.....')
        end
        gui.elements.reset_timeout:render("Reset Time (s)", "Set the time in seconds for resetting all dungeons")
        gui.elements.exit_undercity_delay:render('Exit delay (s)', 'time in seconds to wait before ending undercity')
        gui.elements.boss_delay:render('Boss delay (s)', 'time in seconds to wait before engaging undercity boss')
        gui.elements.max_enticement:render('Max Enticement', 'maximum number of enticement to interact excluding beacon')
        gui.elements.enticement_timeout:render('Enticement delay (s)', 'time in seconds to wait before leaving enticement')
        gui.elements.beacon_timeout:render('Beacon delay (s)', 'time in seconds to wait before leaving beacon')
        gui.elements.loot_obols:render('Loot Obols', 'Loot Obols')
        gui.elements.reorder_tribute:render('Reorder tribute', 'Use stash to reorder specific tribute to use')
        if gui.elements.reorder_tribute:get() then
            render_menu_header('Use stash to reorder dungeon keys inventory if the first slot is not any of the following tributes.')
            gui.elements.tribute_1:render('Tribute 1', gui.tributes, 'Select which tribute to be priority 1')
            gui.elements.tribute_2:render('Tribute 2', gui.tributes, 'Select which tribute to be priority 2')
            gui.elements.tribute_3:render('Tribute 3', gui.tributes, 'Select which tribute to be priority 3')
        end
        gui.elements.undercity_settings_tree:pop()
    end
    if gui.elements.party_settings_tree:push('Party Settings') then
        render_menu_header('Coming soon')
        -- gui.elements.party_enabled:render('enable party mode', 'enable party mode')
        -- if gui.elements.party_enabled:get() then
        --     -- gui.elements.use_magoogle_tool:render('use magoogle tools', 'use magoogle tools')
        --     gui.elements.party_mode:render('party mode', gui.party_mode, 'Select if your character is leader or follower')
        --     if gui.elements.party_mode:get() == 0 then
        --         gui.elements.confirm_delay:render('Accept delay (s)', 'time in seconds to wait for accept start/reset from party member')
        --     else
        --         gui.elements.follower_explore:render('Follower explore?', 'explore undercity as a follow')
        --     end
        -- end
        -- gui.elements.party_settings_tree:pop()
    end
    gui.elements.main_tree:pop()
end

return gui