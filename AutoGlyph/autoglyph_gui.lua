local gui = {}
local plugin_label = "AutoGlyph"
local profiles = require "autoglyph_profiles"

local function create_checkbox(key)
    return checkbox:new(false, get_hash(plugin_label .. "_" .. key))
end

local function create_slider_int(min, max, default, key)
    return slider_int:new(min, max, default, get_hash(plugin_label .. "_" .. key))
end

local function create_combo(default_index, key)
    return combo_box:new(default_index, get_hash(plugin_label .. "_" .. key))
end

gui.profile_class_override_labels = {
    "Auto",
    "barbarian",
    "druid",
    "necromancer",
    "paladin",
    "rogue",
    "sorcerer",
    "spiritborn",
}

gui.profile_class_override_values = {
    nil,
    "barbarian",
    "druid",
    "necromancer",
    "paladin",
    "rogue",
    "sorcerer",
    "spiritborn",
}

function gui.get_character_class()
    local local_player = get_local_player();
    if not local_player then return 'default' end

    if gui.elements and gui.elements.profile_class_override then
        local override_index = gui.elements.profile_class_override:get()
        local override_value = gui.profile_class_override_values[override_index + 1]
        if override_value then
            return override_value
        end
    end

    local class_id = local_player:get_character_class_id()
    local character_classes = {
        [0] = 'sorcerer',
        [1] = 'barbarian',
        [3] = 'rogue',
        [5] = 'druid',
        [6] = 'necromancer',
        [7] = 'spiritborn',
        -- [TODO] Paladin class_id unknown; replace 999 with the correct value.
        [999] = 'paladin'
    }
    if character_classes[class_id] then
        return character_classes[class_id]
    else
        return 'default'
    end
end

gui.elements = {
    main_tree = tree_node:new(0),
    glyph_tree = tree_node:new(1),
    main_toggle = create_checkbox("main_toggle"),
    profile_enabled = create_checkbox("profile_enabled"),
    profile_class_override = create_combo(0, "profile_class_override"),
    debug_enabled = create_checkbox("debug_enabled"),
    status_dummy = create_checkbox("status_dummy"),
    upgrade_threshold = create_slider_int(10, 100, 50, "upgrade_threshold"),
    minimum_glyph_level = create_slider_int(1, 100, 1, "minimum_glyph_level"),
    maximum_glyph_level = create_slider_int(1, 100, 100, "maximum_glyph_level"),
    glyph_checkboxes = {},
    glyph_master = {},
}

gui.upgrade_modes_enum = {
    PROFILE = 0,
}

gui.upgrade_mode_labels = {
    "Profile (per class)",
}

local function ensure_glyph_checkbox(class, hash)
    if not gui.elements.glyph_checkboxes[class] then
        gui.elements.glyph_checkboxes[class] = {}
    end
    if not gui.elements.glyph_checkboxes[class][hash] then
        gui.elements.glyph_checkboxes[class][hash] = create_checkbox("glyph_" .. class .. "_" .. tostring(hash))
    end
    return gui.elements.glyph_checkboxes[class][hash]
end

local function ensure_glyph_master_checkbox(class, key)
    if not gui.elements.glyph_master[class] then
        gui.elements.glyph_master[class] = {}
    end
    if not gui.elements.glyph_master[class][key] then
        gui.elements.glyph_master[class][key] = create_checkbox("glyph_" .. class .. "_" .. key)
        gui.elements.glyph_master[class][key]:set(false)
    end
    return gui.elements.glyph_master[class][key]
end

function gui.is_glyph_selected(class, hash)
    local class_profile = profiles[class]
    if not class_profile or not class_profile[hash] then
        return false
    end
    -- Lazily ensure the checkbox exists so selection works even before the GUI tree has been rendered
    local cb = ensure_glyph_checkbox(class, hash)
    return cb:get()
end

function gui.render()
    if not gui.elements.main_tree:push(plugin_label) then return end

    gui.elements.main_toggle:render("Enable AutoGlyph", "Enable automatic glyph upgrading")

    -- Status line (read from global set by upgrade task), rendered as a dummy checkbox label
    gui.elements.status_dummy:render(
        "Status: " .. tostring(AutoGlyphStatusText or "Idle"),
        "Current AutoGlyph status (label only)"
    )

    if gui.elements.main_toggle:get() then
        gui.elements.profile_enabled:render("Enable Glyph Profile Upgrading", "When off, AutoGlyph will not upgrade any glyphs even if the main toggle is on")
        gui.elements.profile_class_override:render("Profile override", gui.profile_class_override_labels, "Force which class glyph profile to use")
        gui.elements.upgrade_threshold:render("Upgrade threshold", "Only upgrade glyph if the % chance is greater or equal to this value")
        gui.elements.minimum_glyph_level:render("Minimum level", "Only upgrade glyphs with level >= this value")
        gui.elements.maximum_glyph_level:render("Maximum level", "Only upgrade glyphs with level <= this value")
        gui.elements.debug_enabled:render("Enable debug logging", "Show AutoGlyph debug output in the console")

        local class = gui.get_character_class()
        local class_profile = profiles[class]
        local order = profiles.__order and profiles.__order[class]
        if class_profile then
            if gui.elements.glyph_tree:push("Glyph Profile (" .. class .. ")") then
                local all_cb = ensure_glyph_master_checkbox(class, "all")
                local none_cb = ensure_glyph_master_checkbox(class, "none")
                all_cb:render("All", "Select all glyphs for " .. class)
                none_cb:render("None", "Deselect all glyphs for " .. class)

                if all_cb:get() or none_cb:get() then
                    local value = all_cb:get() and true or false
                    if none_cb:get() then value = false end
                    for hash, _ in pairs(class_profile) do
                        local cb = ensure_glyph_checkbox(class, hash)
                        cb:set(value)
                    end
                    all_cb:set(false)
                    none_cb:set(false)
                end

                if order then
                    for _, hash in ipairs(order) do
                        local data = class_profile[hash]
                        if data then
                            local cb = ensure_glyph_checkbox(class, hash)
                            local label = (data and data.label) or tostring(hash)
                            cb:render(label, "Upgrade " .. label .. " glyph (hash " .. tostring(hash) .. ")")
                        end
                    end
                else
                    for hash, data in pairs(class_profile) do
                        local cb = ensure_glyph_checkbox(class, hash)
                        local label = (data and data.label) or tostring(hash)
                        cb:render(label, "Upgrade " .. label .. " glyph (hash " .. tostring(hash) .. ")")
                    end
                end

                gui.elements.glyph_tree:pop()
            end
        end
    end

    gui.elements.main_tree:pop()
end

return gui
