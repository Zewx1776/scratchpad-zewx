-- Profile Manager for Paladin Plugin
-- Handles saving/loading spell configurations for different builds

local profile_manager = {}

-- Available builds
profile_manager.available_builds = {
    "Custom",
    "Blessed Hammer (Mekuna)",
}

-- Current profile data
profile_manager.current_profile = {
    name = "Custom",
    enabled_spells = {},
}

-- Saved custom profiles (persisted in memory)
-- Format: {profile_name = {name = "...", enabled_spells = {...}, timestamp = ...}}
profile_manager.saved_profiles = {}

-- Counter for auto-naming
local save_counter = 1

-- Load a build configuration
function profile_manager.load_build(build_name, spells)
    if build_name == "Blessed Hammer (Mekuna)" then
        local success, build_config = pcall(require, "blessed_hammer_build")
        if success and build_config then
            -- Apply build settings to spells
            for spell_name, spell_module in pairs(spells) do
                if build_config.spell_settings[spell_name] then
                    local settings = build_config.spell_settings[spell_name]
                    
                    -- Update spell enabled state
                    if spell_module.menu then
                        local menu_elements = spell_module.menu()
                        if menu_elements and menu_elements.main_boolean then
                            -- Get the checkbox and set its value
                            if type(menu_elements.main_boolean.set) == "function" then
                                menu_elements.main_boolean:set(settings.enabled or false)
                            end
                        end
                    end
                    
                    -- Track enabled state
                    profile_manager.current_profile.enabled_spells[spell_name] = settings.enabled or false
                end
            end
            
            profile_manager.current_profile.name = build_name
            console.print("Loaded build: " .. build_name)
            return true
        end
    elseif build_name == "Custom" then
        profile_manager.current_profile.name = "Custom"
        return true
    end
    
    return false
end

-- Save current configuration as custom profile
function profile_manager.save_custom_profile(spells)
    profile_manager.current_profile.name = "Custom"
    profile_manager.current_profile.enabled_spells = {}
    
    for spell_name, spell_module in pairs(spells) do
        if spell_module.menu then
            local menu_elements = spell_module.menu()
            if menu_elements and menu_elements.main_boolean then
                local is_enabled = false
                if type(menu_elements.main_boolean.get) == "function" then
                    is_enabled = menu_elements.main_boolean:get()
                end
                profile_manager.current_profile.enabled_spells[spell_name] = is_enabled
            end
        end
    end
end

-- Generate automatic profile name
function profile_manager.generate_profile_name()
    local name = "Custom Build " .. save_counter
    save_counter = save_counter + 1
    return name
end

-- Save current configuration with auto-generated or custom name
function profile_manager.save_profile_with_name(profile_name, spells)
    if not profile_name or profile_name == "" then
        profile_name = profile_manager.generate_profile_name()
    end
    
    local saved_config = {
        name = profile_name,
        enabled_spells = {},
        timestamp = os.time()
    }
    
    for spell_name, spell_module in pairs(spells) do
        if spell_module.get_enabled then
            saved_config.enabled_spells[spell_name] = spell_module.get_enabled()
        end
    end
    
    profile_manager.saved_profiles[profile_name] = saved_config
    console.print("Saved profile: " .. profile_name)
    return profile_name
end

-- Save current configuration with a name (backwards compatibility)
function profile_manager.save_profile_to_slot(profile_name, spells)
    return profile_manager.save_profile_with_name(profile_name, spells)
end

-- Load a saved profile by name
function profile_manager.load_saved_profile(profile_name, spells)
    local saved_config = profile_manager.saved_profiles[profile_name]
    if not saved_config then
        console.print("Profile not found: " .. profile_name)
        return false
    end
    
    -- Apply saved settings to spells
    for spell_name, is_enabled in pairs(saved_config.enabled_spells) do
        local spell_module = spells[spell_name]
        if spell_module and spell_module.menu then
            local menu_elements = spell_module.menu()
            if menu_elements and menu_elements.main_boolean then
                if type(menu_elements.main_boolean.set) == "function" then
                    menu_elements.main_boolean:set(is_enabled)
                end
            end
        end
    end
    
    profile_manager.current_profile.name = profile_name
    profile_manager.current_profile.enabled_spells = saved_config.enabled_spells
    console.print("Loaded profile: " .. profile_name)
    return true
end

-- Update an existing saved profile with current spell configuration
function profile_manager.update_profile(profile_name, spells)
    if not profile_manager.saved_profiles[profile_name] then
        console.print("Profile not found: " .. profile_name)
        return false
    end
    
    local updated_config = {
        name = profile_name,
        enabled_spells = {},
        timestamp = os.time()  -- Update timestamp
    }
    
    for spell_name, spell_module in pairs(spells) do
        if spell_module.get_enabled then
            updated_config.enabled_spells[spell_name] = spell_module.get_enabled()
        end
    end
    
    profile_manager.saved_profiles[profile_name] = updated_config
    console.print("Updated profile: " .. profile_name)
    return true
end

-- Delete a saved profile
function profile_manager.delete_profile(profile_name)
    if profile_manager.saved_profiles[profile_name] then
        profile_manager.saved_profiles[profile_name] = nil
        console.print("Deleted profile: " .. profile_name)
        return true
    end
    return false
end

-- Get list of saved profile names sorted by timestamp (newest first)
function profile_manager.get_saved_profile_names()
    local profiles = {}
    for name, config in pairs(profile_manager.saved_profiles) do
        table.insert(profiles, {name = name, timestamp = config.timestamp or 0})
    end
    
    -- Sort by timestamp descending (newest first)
    table.sort(profiles, function(a, b) return a.timestamp > b.timestamp end)
    
    local names = {}
    for _, profile in ipairs(profiles) do
        table.insert(names, profile.name)
    end
    
    return names
end

-- Check if a spell is enabled
function profile_manager.is_spell_enabled(spell_name, spell_module)
    if spell_module and spell_module.menu then
        local menu_elements = spell_module.menu()
        if menu_elements and menu_elements.main_boolean then
            if type(menu_elements.main_boolean.get) == "function" then
                return menu_elements.main_boolean:get()
            end
        end
    end
    return false
end

-- Get enabled spells list
function profile_manager.get_enabled_spells(spells)
    local enabled = {}
    for spell_name, spell_module in pairs(spells) do
        if profile_manager.is_spell_enabled(spell_name, spell_module) then
            table.insert(enabled, spell_name)
        end
    end
    return enabled
end

-- Get disabled spells list
function profile_manager.get_disabled_spells(spells)
    local disabled = {}
    for spell_name, spell_module in pairs(spells) do
        if not profile_manager.is_spell_enabled(spell_name, spell_module) then
            table.insert(disabled, spell_name)
        end
    end
    return disabled
end

return profile_manager
