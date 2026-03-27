-- Paladin Rotation Plugin - Main Entry Point
-- Based on Karnage's Paladin rotation

local local_player = get_local_player()
if not local_player then
    return
end

-- Note: Removed class ID check to allow menu to show up for testing
-- The rotation will only work properly on the correct character class
console.print("Paladin Plugin: Initializing...")

-- Safe require function
local function safe_require(module_name)
    local success, result = pcall(require, module_name)
    if success then
        return result
    else
        console.print("Failed to load module: " .. module_name .. " - " .. tostring(result))
        return nil
    end
end

-- Load utilities
local my_utility = safe_require("my_utility/my_utility")
local my_target_selector = safe_require("my_utility/my_target_selector")

-- Safe print function
local function safe_print_console(msg)
    if console and console.print then
        pcall(function() console.print(msg) end)
    end
end

-- Debug print function
local function debug_print(msg)
    if menu and menu.debug_boolean and type(menu.debug_boolean.get) == "function" and menu.debug_boolean:get() then
        safe_print_console("[DEBUG] " .. msg)
    end
end

-- Menu system
local menu = {
    main_tree = tree_node and tree_node:new(0) or nil,
    main_boolean = checkbox and checkbox:new(true, get_hash("paladin_main_enable")) or nil,
    debug_boolean = checkbox and checkbox:new(false, get_hash("paladin_debug_enable")) or nil,
    load_build_boolean = checkbox and checkbox:new(false, get_hash("paladin_load_build_bool")) or nil,
}

-- Spell modules - will be populated as we create them
local spells = {}
local cached_priority_list = nil

-- Try to load spell modules
local spell_names = {
    "holy_bolt",
    "blessed_shield",
    "clash",
    "purify",
    "advance",
    "zeal",
    "brandish",
    "arbiter_of_justice",
    "judgement_day",
    "spear_of_the_heavens",
    "blessed_hammer",
    "falling_star",
    "consecration",
    "condemn",
    "rally",
    "fortress",
    "aegis",
    "holy_light_aura",
    "defiance_aura",
    "fanaticism_aura",
}

-- Load available spell modules
for _, spell_name in ipairs(spell_names) do
    local spell_module = safe_require("spells/" .. spell_name)
    if spell_module then
        spells[spell_name] = spell_module
    end
end

-- Build sorted spell name list once (used by menu renderers)
local sorted_spell_names = {}
for spell_name, _ in pairs(spells) do
    table.insert(sorted_spell_names, spell_name)
end
table.sort(sorted_spell_names)

-- Load build profiles
local build_profiles = safe_require("build_profiles")

-- Current selected build (1-based index)
local current_build_index = 1
local previous_dropdown_index = nil  -- Track previous dropdown selection
local build_selector_combo = nil
local dropdown_initialized = false  -- Track if dropdown has been initialized

-- Initialize build selector
if type(combo_box) == "table" and type(combo_box.new) == "function" then
    local ok, combo = pcall(function()
        return combo_box:new(0, get_hash("paladin_build_selector"))
    end)
    if ok and combo then
        build_selector_combo = combo
    end
end

-- Apply build function - enables/disables spells based on build
local function apply_build(build_id)
    if not build_profiles or not build_id then 
        debug_print("Apply build failed: missing build_profiles or build_id")
        return 
    end
    
    local build = build_profiles.get_build(build_id)
    if not build or not build.enabled_spells then 
        debug_print("Apply build failed: build or enabled_spells not found for " .. tostring(build_id))
        return 
    end
    
    debug_print("Applying build: " .. (build.name or build_id) .. " with " .. #build.enabled_spells .. " spells")
    
    -- First, disable all spells
    local disabled_count = 0
    for spell_name, spell_module in pairs(spells) do
        if spell_module and spell_module.menu_elements and spell_module.menu_elements.main_boolean then
            if type(spell_module.menu_elements.main_boolean.set) == "function" then
                pcall(function()
                    spell_module.menu_elements.main_boolean:set(false)
                    disabled_count = disabled_count + 1
                end)
            end
        end
    end
    
    debug_print("Disabled " .. disabled_count .. " spells")
    
    -- Then enable spells from the build
    local enabled_count = 0
    for _, spell_name in ipairs(build.enabled_spells) do
        local spell_module = spells[spell_name]
        if spell_module and spell_module.menu_elements and spell_module.menu_elements.main_boolean then
            if type(spell_module.menu_elements.main_boolean.set) == "function" then
                pcall(function()
                    spell_module.menu_elements.main_boolean:set(true)
                    enabled_count = enabled_count + 1
                    debug_print("Enabled spell: " .. spell_name)
                end)
            else
                debug_print("Failed to enable spell " .. spell_name .. " - no set function")
            end
        else
            debug_print("Failed to enable spell " .. spell_name .. " - module or menu_elements not found")
        end
    end
    
    debug_print("Enabled " .. enabled_count .. " spells for build " .. (build.name or build_id))
    safe_print_console("Paladin: Applied build - " .. (build.name or build_id) .. " (" .. enabled_count .. " spells)")

    -- Rebuild cached rotation priority list for on_update
    cached_priority_list = {}
    local build_for_cache = build_profiles.get_build(build_id)
    for spell_name_c, spell_module_c in pairs(spells) do
        if spell_module_c then
            local priority = (build_for_cache and build_for_cache.rotation_priority and build_for_cache.rotation_priority[spell_name_c]) or 50
            table.insert(cached_priority_list, {
                name = spell_name_c,
                module = spell_module_c,
                priority = priority
            })
        end
    end
    table.sort(cached_priority_list, function(a, b) return a.priority > b.priority end)
end

-- Spell menu rendering - Only show ENABLED spells
local function render_active_skills_menu()
    if not menu.main_tree or type(menu.main_tree.push) ~= "function" then return end
    
    if menu.main_tree:push("Active Skills") then
        for _, spell_name in ipairs(sorted_spell_names) do
            local spell_module = spells[spell_name]
            if spell_module and spell_module.menu then
                -- Check if spell is enabled using get_enabled function (doesn't render)
                local is_enabled = spell_module.get_enabled and spell_module.get_enabled()
                
                -- Only render menu if spell is enabled
                if is_enabled then
                    spell_module.menu()
                end
            end
        end
        
        menu.main_tree:pop()
    end
end

-- Spell menu rendering - Only show DISABLED spells  
local function render_inactive_skills_menu()
    if not menu.main_tree or type(menu.main_tree.push) ~= "function" then return end
    
    if menu.main_tree:push("Inactive Skills") then
        for _, spell_name in ipairs(sorted_spell_names) do
            local spell_module = spells[spell_name]
            if spell_module and spell_module.menu then
                -- Check if spell is disabled using get_enabled function (doesn't render)
                local is_enabled = spell_module.get_enabled and spell_module.get_enabled()
                
                -- Only render menu if spell is disabled
                if not is_enabled then
                    spell_module.menu()
                end
            end
        end
        
        menu.main_tree:pop()
    end
end

-- Cast timing
local cast_end_time = 0
local can_move = 0

-- Sticky target state (prevents frame-to-frame target flipping)
local _sticky_target = nil
local _sticky_target_time = 0
local _sticky_target_priority = 0  -- 0=normal, 1=elite, 2=champion, 3=boss

-- Returns a priority number for a target based on its type
local function get_target_priority(target, tsd)
    if tsd.has_boss and tsd.closest_boss == target then return 3 end
    if tsd.has_champion and tsd.closest_champion == target then return 2 end
    if tsd.has_elite and tsd.closest_elite == target then return 1 end
    return 0
end

-- Helper function to safely call spell logic
local function call_logic_safe(spell_module, target)
    if not spell_module or not spell_module.logics then
        return false
    end
    
    -- Additional validation
    if not target or not target.is_enemy or not target:is_enemy() then
        return false
    end
    
    local target_position = target:get_position()
    if not target_position then
        return false
    end
    
    local success, result = pcall(spell_module.logics, target)
    if success and result then
        return true
    end
    
    -- Log the error for debugging
    if not success then
        safe_print_console("Paladin: Spell logic error - " .. tostring(result))
    end
    return false
end

-- Safe push/pop helpers
local function safe_push(tree, name)
    if tree and type(tree.push) == "function" then
        return tree:push(name)
    end
    return false
end

local function safe_pop(tree)
    if tree and type(tree.pop) == "function" then
        tree:pop()
    end
end

-- Main rotation logic
on_update(function()
    if not menu or not menu.main_boolean or type(menu.main_boolean.get) ~= "function" or not menu.main_boolean:get() then
        return
    end
    local debug_on = menu.debug_boolean and type(menu.debug_boolean.get) == "function" and menu.debug_boolean:get()

    local current_time = get_time_since_inject and get_time_since_inject() or 0
    if current_time < cast_end_time then
        return
    end

    if not my_target_selector then 
        my_target_selector = safe_require("my_utility/my_target_selector")
    end
    if not my_target_selector then 
        return 
    end

    local selected_position = my_target_selector.get_current_selected_position and my_target_selector.get_current_selected_position()
    if not selected_position then return end

    if not my_utility then 
        my_utility = safe_require("my_utility/my_utility") 
    end
    if not my_utility or not my_utility.is_action_allowed or not my_utility.is_action_allowed() then 
        return 
    end

    local is_auto_play_active = my_utility and my_utility.is_auto_play_enabled and my_utility.is_auto_play_enabled()
    if not is_auto_play_active then
        if not (orbwalker and type(orbwalker.get_orb_mode) == "function") then
            return
        end

        local ok_mode, orb_mode = pcall(function()
            return orbwalker.get_orb_mode()
        end)

        if (not ok_mode) or (type(orb_mode) ~= "number") or orb_mode == 0 then
            return
        end
    end

    local is_auto_play_ui_active = auto_play and type(auto_play.is_active) == "function" and auto_play.is_active()
    local max_range = is_auto_play_ui_active and 12.0 or 8.5
    local screen_range = is_auto_play_ui_active and 20.0 or 16.0

    local entity_list = my_target_selector.get_target_list and my_target_selector.get_target_list(selected_position, screen_range, { false, 2.0 }, { true, 5.0 }, { false, 90.0 })
    local target_selector_data = my_target_selector.get_target_selector_data and my_target_selector.get_target_selector_data(selected_position, entity_list)
    if not target_selector_data or not target_selector_data.is_valid then 
        return 
    end

    local best_target = target_selector_data.closest_unit
    
    -- Prioritize special enemies
    if target_selector_data.has_elite then
        local unit = target_selector_data.closest_elite
        if unit then
            local unit_position = unit:get_position()
            local distance_sqr = unit_position and unit_position:squared_dist_to_ignore_z(selected_position)
            if distance_sqr and distance_sqr < (max_range * max_range) then 
                best_target = unit 
            end
        end
    end
    
    if target_selector_data.has_champion then
        local unit = target_selector_data.closest_champion
        if unit then
            local unit_position = unit:get_position()
            local distance_sqr = unit_position and unit_position:squared_dist_to_ignore_z(selected_position)
            if distance_sqr and distance_sqr < (max_range * max_range) then
                best_target = unit
            end
        end
    end

    if target_selector_data.has_boss then
        local unit = target_selector_data.closest_boss
        if unit then
            local unit_position = unit:get_position()
            local distance_sqr = unit_position and unit_position:squared_dist_to_ignore_z(selected_position)
            if distance_sqr and distance_sqr < (max_range * max_range) then
                best_target = unit
            end
        end
    end

    if not best_target then 
        debug_print("No valid target found")
        return 
    end

    local best_target_position = best_target:get_position()
    if not best_target_position then 
        debug_print("Target position invalid")
        return 
    end
    
    local distance_sqr = best_target_position:squared_dist_to_ignore_z(selected_position)
    if distance_sqr and distance_sqr > (max_range * max_range) then
        debug_print("Target too far: " .. math.sqrt(distance_sqr) .. " > " .. max_range)
        best_target = target_selector_data.closest_unit
        if best_target then
            local closer_pos = best_target:get_position()
            if closer_pos then
                local distance_sqr_2 = closer_pos:squared_dist_to_ignore_z(selected_position)
                if not distance_sqr_2 or distance_sqr_2 > (max_range * max_range) then 
                    debug_print("Fallback target also too far")
                    return 
                end
            else
                debug_print("Fallback target position invalid")
                return
            end
        else
            debug_print("No fallback target available")
            return
        end
    end
    
    if debug_on then safe_print_console("[DEBUG] Target selected: distance=" .. math.sqrt(distance_sqr) .. ", range=" .. max_range) end

    -- Sticky target: stabilise best_target across frames to prevent rapid flip
    do
        -- Validate existing sticky target is still alive
        if _sticky_target then
            local ok, still_valid = pcall(function()
                return _sticky_target:is_enemy() and _sticky_target:get_position() ~= nil
            end)
            if not ok or not still_valid then
                _sticky_target = nil
            end
        end

        local new_priority = get_target_priority(best_target, target_selector_data)
        local should_switch = false

        if _sticky_target == nil then
            should_switch = true
        elseif new_priority > _sticky_target_priority then
            -- Higher-priority target type available (e.g. boss appeared) — switch immediately
            should_switch = true
        elseif (current_time - _sticky_target_time) > 0.5 then
            -- Lock time expired — allow switching to any target
            should_switch = true
        end

        if should_switch then
            _sticky_target = best_target
            _sticky_target_time = current_time
            _sticky_target_priority = new_priority
        else
            best_target = _sticky_target
        end
    end

    -- Execute spells using cached priority list (rebuilt only on build change)
    if cached_priority_list then
        for _, spell_info in ipairs(cached_priority_list) do
            if call_logic_safe(spell_info.module, best_target) then
                cast_end_time = current_time + 0.4
                if debug_on then safe_print_console("[DEBUG] Casted spell: " .. spell_info.name) end
                return
            end
        end
    end
    if debug_on then safe_print_console("[DEBUG] No spells were cast") end

    -- Movement / auto-play
    local move_timer = (type(get_time_since_inject) == "function") and get_time_since_inject() or 0
    if move_timer < can_move then return end

    local is_auto_play = my_utility and my_utility.is_auto_play_enabled and my_utility.is_auto_play_enabled()
    if is_auto_play then
        local player_position = (type(get_player_position) == "function") and get_player_position() or nil
        if player_position and best_target then
            local move_target_position = best_target:get_position()
            if move_target_position then
                local move_pos = move_target_position:get_extended(player_position, -2.0)
                if pathfinder and type(pathfinder.request_move) == "function" and pathfinder.request_move(move_pos) then
                    can_move = move_timer + 1.20
                end
            end
        end
    end
end)

-- Rendering overlays
on_render(function()
    if menu and menu.main_boolean and type(menu.main_boolean.get) == "function" and not menu.main_boolean:get() then 
        return 
    end
    
    local local_player = get_local_player()
    if not local_player then return end

    if not my_target_selector then 
        my_target_selector = safe_require("my_utility/my_target_selector") 
    end
    if not my_target_selector then return end

    local selected_position = my_target_selector.get_current_selected_position and my_target_selector.get_current_selected_position()
    if not selected_position then return end

    -- Visual overlays for debugging
    local entity_list = my_target_selector.get_target_list and my_target_selector.get_target_list(selected_position, 16.0, { false, 2.0 }, { true, 5.0 }, { false, 90.0 })
    local target_selector_data = my_target_selector.get_target_selector_data and my_target_selector.get_target_selector_data(selected_position, entity_list)
    if not target_selector_data or not target_selector_data.is_valid then return end

    local best_target = target_selector_data.closest_unit
    if best_target and type(best_target.is_enemy) == "function" and best_target:is_enemy() then
        pcall(function()
            local pos = best_target:get_position()
            if graphics and type(graphics.w2s) == "function" then
                local screen = graphics.w2s(pos)
                local player_pos = get_local_player():get_position()
                local player_screen = graphics.w2s(player_pos)
                if color_red then
                    graphics.line(screen, player_screen, color_red(150), 2.0)
                    graphics.circle_3d(pos, 0.8, color_red(200), 2.0)
                end
            end
        end)
    end
end)

-- Menu render
on_render_menu(function()
    if not menu or not menu.main_tree or type(menu.main_tree.push) ~= "function" then
        safe_print_console("Paladin plugin active (no menu helper available).")
        return
    end

    if not safe_push(menu.main_tree, "Paladin: Karnage | Profiles") then return end

    if menu.main_boolean and type(menu.main_boolean.render) == "function" then 
        menu.main_boolean:render("Enable Plugin", "") 
    end
    
    -- Debug option
    if menu.debug_boolean and type(menu.debug_boolean.render) == "function" then 
        menu.debug_boolean:render("Enable Debug", "Show detailed casting information") 
    end
    
    if menu.main_boolean and type(menu.main_boolean.get) == "function" and not menu.main_boolean:get() then 
        safe_pop(menu.main_tree)
        return 
    end

    -- Targeting mode dropdown
    if type(combo_box) == "table" and type(combo_box.new) == "function" then
        local ok, targeting_dropdown = pcall(function() 
            return combo_box:new(0, get_hash("targeting_mode_dropdown_paladin")) 
        end)
        if ok and targeting_dropdown and type(targeting_dropdown.render) == "function" then
            pcall(function() 
                targeting_dropdown:render("Targeting Mode", {"cursor", "player"}, "Target closest to PLAYER or closest to CURSOR") 
            end)
        end
    end

    -- Build Profiles UI
    if build_selector_combo and type(build_selector_combo.render) == "function" and build_profiles then
        local build_names = build_profiles.get_build_display_names()
        if build_names and #build_names > 0 then
            if safe_push(menu.main_tree, "Build Profiles") then
                -- Only set dropdown value on first initialization
                if not dropdown_initialized then
                    local dropdown_index = (current_build_index or 1) - 1
                    build_selector_combo:set(dropdown_index)
                    dropdown_initialized = true
                    safe_print_console("Paladin: Initializing dropdown to index " .. dropdown_index .. " (build index " .. (current_build_index or 1) .. ")")
                end
                
                local ok, selected_index = pcall(function()
                    return build_selector_combo:render("Select Build", build_names, "Choose a pre-configured build")
                end)
                
                -- Try to get current dropdown value if render returns nil
                if ok and selected_index == nil then
                    local get_ok, current_value = pcall(function()
                        return build_selector_combo:get()
                    end)
                    if get_ok and current_value and type(current_value) == "number" then
                        selected_index = current_value
                    end
                end
                
                -- Check if dropdown selection changed
                if ok and selected_index and type(selected_index) == "number" and selected_index >= 0 and selected_index < #build_names then
                    -- Only apply if selection changed or first time
                    if previous_dropdown_index == nil or selected_index ~= previous_dropdown_index then
                        safe_print_console("Paladin: Dropdown selection changed from " .. tostring(previous_dropdown_index) .. " to " .. selected_index)
                        
                        -- Convert 0-based dropdown index to 1-based build index
                        local new_index = selected_index + 1
                        
                        -- Apply the selected build
                        current_build_index = new_index
                        local build_id = build_profiles.get_build_id_by_index(current_build_index)
                        if build_id then
                            apply_build(build_id)
                            safe_print_console("Paladin: Build changed to " .. (build_profiles.get_build(build_id).name or "Unknown"))
                        else
                            safe_print_console("Paladin: Failed to get build ID for index " .. current_build_index)
                        end
                        
                        -- Update previous selection
                        previous_dropdown_index = selected_index
                    end
                end
                
                -- Load Build option
                if menu.load_build_boolean and type(menu.load_build_boolean.render) == "function" then 
                    local current_state = menu.load_build_boolean:get()
                    local render_result = menu.load_build_boolean:render("Load Current Build", "Force reload skills for selected build")
                    local new_state = menu.load_build_boolean:get()
                    
                    -- Check if it was just clicked (state changed from false to true)
                    if not current_state and new_state then
                        -- Try to get current dropdown value
                        local get_ok, dropdown_value = pcall(function()
                            return build_selector_combo:get()
                        end)
                        
                        local build_to_load = current_build_index  -- Default to current
                        if get_ok and dropdown_value and type(dropdown_value) == "number" then
                            -- Use dropdown value (convert 0-based to 1-based)
                            build_to_load = dropdown_value + 1
                        end
                        
                        -- Load the build
                        local build_id = build_profiles.get_build_id_by_index(build_to_load)
                        if build_id then
                            apply_build(build_id)
                            safe_print_console("Paladin: Manual build load triggered - " .. (build_profiles.get_build(build_id).name or "Unknown"))
                        else
                            safe_print_console("Paladin: No build selected to load")
                        end
                        -- Reset checkbox state
                        menu.load_build_boolean:set(false)
                    end
                end
                
                -- Show current build info
                local build_id = build_profiles.get_build_id_by_index(current_build_index)
                if build_id then
                    local build = build_profiles.get_build(build_id)
                    if build then
                        if type(menu.main_tree.push) == "function" then
                            pcall(function()
                                local text_node = tree_node:new(1)
                                if text_node and type(text_node.push) == "function" then
                                    if text_node:push("CURRENT BUILD: " .. (build.name or "Unknown")) then
                                        -- Show build guide link only (much shorter and green)
                                        if build.build_info then
                                            local info = build.build_info
                                            if info.link then
                                                if type(menu.main_tree.push) == "function" then
                                                    pcall(function()
                                                        local link_node = tree_node:new(1)
                                                        if link_node and type(link_node.push) == "function" then
                                                            if link_node:push("🔗 Guide:") then
                                                                -- Display very short green link
                                                                if type(menu.main_tree.push) == "function" then
                                                                    pcall(function()
                                                                        local link_text_node = tree_node:new(1)
                                                                        if link_text_node and type(link_text_node.push) == "function" then
                                                                            -- Make link very short - just domain name
                                                                            local short_link = "mobalytics"
                                                                            if link_text_node:push("  " .. short_link) then
                                                                                link_text_node:pop()
                                                                            end
                                                                        end
                                                                    end)
                                                                end
                                                                link_node:pop()
                                                            end
                                                        end
                                                    end)
                                                end
                                            end
                                        end
                                        text_node:pop()
                                    end
                                end
                            end)
                        end
                    end
                end
                
                safe_pop(menu.main_tree)
            end
        end
    end

    -- Profiles UI removed to eliminate crashes
    -- Users can configure spells directly in Active/Inactive Skills menus

    -- Skills UI
    render_active_skills_menu()
    render_inactive_skills_menu()

    safe_pop(menu.main_tree)
end)

-- Auto-load the first build (Blessed Hammer) on initialization
local function auto_load_initial_build()
    if not build_profiles then return end
    
    -- Start with index 1 (1-based)
    current_build_index = 1
    local first_build_id = build_profiles.get_build_id_by_index(current_build_index)
    if first_build_id then
        apply_build(first_build_id)
        local build = build_profiles.get_build(first_build_id)
        safe_print_console("Paladin Plugin: Auto-applied first build - " .. (build and build.name or "Unknown"))
    else
        safe_print_console("Paladin Plugin: No builds found to auto-load")
    end
end

-- Start auto-load
auto_load_initial_build()

safe_print_console("Paladin Plugin: Loaded successfully")
