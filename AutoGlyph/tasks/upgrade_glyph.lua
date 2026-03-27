local utils = require "core.utils"
local explorerlite = require "core.explorerlite"
local enums = require "data.enums"
local autoglyph_gui = require "autoglyph_gui"
local settings = require "autoglyph_settings"
local gui = require "autoglyph_gui"
local glyph_profiles = require "autoglyph_profiles"

local upgrade_state = {
    INIT = "INIT",
    UPGRADING_GLYPH = "UPGRADING_GLYPH",
    FINISHED = "FINISHED",
}


local blacklist = {}
local last_attempted_glyph = nil
local failed_count = 0
local session_finished = false
local last_distance_debug_time = 0
local last_too_far_log_time = 0
local last_no_target_debug_time = 0

local task = {
    name = 'AutoGlyph Upgrade',
    current_state = upgrade_state.INIT,
    last_interaction_time = nil,
}

local function init_upgrade()
    task.current_state = upgrade_state.UPGRADING_GLYPH
    blacklist = {}
    failed_count = 0
    task.last_interaction_time = get_time_since_inject()
    AutoGlyphStatusText = "Running"
    if settings.debug_enabled then
        console.print('[AutoGlyph] init_upgrade -> UPGRADING_GLYPH')
    end
end

local function should_upgrade(glyph)
    -- For level 45+ glyphs, always attempt an upgrade when they are selected in the profile.
    -- We rely on the game itself to reject upgrades if they are not actually possible.
    if glyph:get_level() >= 45 then
        return true
    end

    if last_attempted_glyph ~= nil and
        last_attempted_glyph.glyph_name_hash == glyph.glyph_name_hash and
        last_attempted_glyph:get_level() == glyph:get_level()
    then
        if failed_count < 10 then
            failed_count = failed_count + 1
        else
            blacklist[glyph.glyph_name_hash] = true
            failed_count = 0
        end
    else
        failed_count = 0
    end

    local upgrade_chance = math.floor((glyph:get_upgrade_chance() + 0.005) * 100)
    local chance_ok = upgrade_chance >= settings.upgrade_threshold

    if glyph:can_upgrade() and
        chance_ok and
        blacklist[glyph.glyph_name_hash] == nil and
        glyph:get_level() >= settings.minimum_glyph_level and
        glyph:get_level() <= settings.maximum_glyph_level
    then
        --console.print('[AutoGlyph] should_upgrade true for hash ' .. tostring(glyph.glyph_name_hash) .. ' level ' .. tostring(glyph:get_level()) .. ' chance ' .. tostring(upgrade_chance))
        return true
    end
    return false
end

local function npc_glyph_upgrade()
    local current_time = get_time_since_inject()
    if current_time - (task.last_interaction_time or 0) >= 0.5 then
        local glyphs = get_glyphs()
        local class = gui.get_character_class()
        local profile = glyph_profiles[class]
        local order = glyph_profiles.__order and glyph_profiles.__order[class]
        if not profile then
            task.current_state = upgrade_state.FINISHED
            return
        end

        -- First, prioritize eligible level 45 glyphs (legendary or not) that are in the profile and selected, from high index to low
        for i = glyphs:size(), 1, -1 do
            local current_glyph = glyphs:get(i)
            local hash = current_glyph.glyph_name_hash
            if current_glyph:get_level() == 45 and profile[hash] and gui.is_glyph_selected(class, hash) then
                local ok = should_upgrade(current_glyph)
                if ok then
                    if settings.debug_enabled then
                        console.print('[AutoGlyph] Upgrading high-priority level 45 glyph ' .. tostring(current_glyph.glyph_name_hash))
                    end
                    last_attempted_glyph = current_glyph
                    upgrade_glyph(current_glyph)
                    task.last_interaction_time = get_time_since_inject()
                    return
                else
                    if settings.debug_enabled then
                        console.print(string.format(
                            '[AutoGlyph] Skipping level 45 glyph %s (hash=%s) can_upgrade=%s',
                            tostring(profile[hash] and profile[hash].label or 'unknown'),
                            tostring(hash),
                            tostring(current_glyph:can_upgrade())
                        ))
                    end
                end
            end
        end

        -- If no level 45 glyphs were upgraded, fall back to profile-based selection
        local glyph_by_hash = {}
        for i = 1, glyphs:size() do
            local g = glyphs:get(i)
            glyph_by_hash[g.glyph_name_hash] = g
        end

        local min_level = nil
        for hash, _ in pairs(profile) do
            local g = glyph_by_hash[hash]
            if g and g:get_level() ~= 45 and gui.is_glyph_selected(class, hash) and should_upgrade(g) then
                local lvl = g:get_level()
                if min_level == nil or lvl < min_level then
                    min_level = lvl
                end
            end
        end

        local target_glyph = nil
        if min_level ~= nil then
            if order then
                for _, hash in ipairs(order) do
                    local g = glyph_by_hash[hash]
                    if g and g:get_level() == min_level and gui.is_glyph_selected(class, hash) and should_upgrade(g) then
                        target_glyph = g
                        break
                    end
                end
            else
                for hash, _ in pairs(profile) do
                    local g = glyph_by_hash[hash]
                    if g and g:get_level() == min_level and gui.is_glyph_selected(class, hash) and should_upgrade(g) then
                        target_glyph = g
                        break
                    end
                end
            end
        end

        if target_glyph == nil and settings.debug_enabled then
            local now = get_time_since_inject()
            if now - last_no_target_debug_time > 1.0 then
                console.print(string.format(
                    '[AutoGlyph] No eligible glyph found. class=%s min=%s max=%s threshold=%s',
                    tostring(class),
                    tostring(settings.minimum_glyph_level),
                    tostring(settings.maximum_glyph_level),
                    tostring(settings.upgrade_threshold)
                ))

                for hash, data in pairs(profile) do
                    if gui.is_glyph_selected(class, hash) then
                        local g = glyph_by_hash[hash]
                        if g then
                            local lvl = g:get_level()
                            local chance = math.floor((g:get_upgrade_chance() + 0.005) * 100)
                            console.print(string.format(
                                '[AutoGlyph] Selected glyph %s (hash=%s) level=%s chance=%s can_upgrade=%s blacklisted=%s',
                                tostring(data and data.label or 'unknown'),
                                tostring(hash),
                                tostring(lvl),
                                tostring(chance),
                                tostring(g:can_upgrade()),
                                tostring(blacklist[hash] == true)
                            ))
                        else
                            console.print(string.format(
                                '[AutoGlyph] Selected glyph %s (hash=%s) not found in get_glyphs()',
                                tostring(data and data.label or 'unknown'),
                                tostring(hash)
                            ))
                        end
                    end
                end

                last_no_target_debug_time = now
            end
        end

        if target_glyph ~= nil then
            if settings.debug_enabled then
                console.print('[AutoGlyph] Upgrading glyph ' .. tostring(target_glyph.glyph_name_hash) .. ' level ' .. tostring(target_glyph:get_level()))
            end
            last_attempted_glyph = target_glyph
            upgrade_glyph(target_glyph)
            task.last_interaction_time = get_time_since_inject()
            return
        end

        task.current_state = upgrade_state.FINISHED
    end
end

local function finish_upgrade()
    task.current_state = upgrade_state.FINISHED
    blacklist = {}
    failed_count = 0
    session_finished = true
    last_attempted_glyph = nil
    if settings.debug_enabled then
        console.print('[AutoGlyph] Finished upgrading glyphs for this visit to the glyphstone.')
    end
    AutoGlyphStatusText = "Finished"
end

function task.Execute()
    -- Always refresh settings at the start of the tick so we never use stale values
    settings:update_settings()

    -- If AutoGlyph is disabled, fully reset state
    if not settings.enabled then
        AutoGlyphStatusText = "Idle"
        task.current_state = upgrade_state.INIT
        blacklist = {}
        failed_count = 0
        session_finished = false
        last_attempted_glyph = nil
        return
    end

    if not settings.profile_enabled then
        AutoGlyphStatusText = "Idle"
        task.current_state = upgrade_state.INIT
        blacklist = {}
        failed_count = 0
        session_finished = false
        last_attempted_glyph = nil
        return
    end

    local npc = utils.get_object_by_name(enums.misc.gizmo_paragon_glyph_upgrade)
    if not npc then
        task.current_state = upgrade_state.INIT
        AutoGlyphStatusText = "Idle"
        session_finished = false
        last_attempted_glyph = nil
        return
    end

    -- Only operate when player is already close to the glyphstone
    local dist = utils.distance_to(npc)
    local now = get_time_since_inject()
    if settings.debug_enabled then
        if now - last_distance_debug_time > 1.0 then
            console.print(string.format('[AutoGlyph-Move] Distance to glyphstone: %.2f', dist))
            last_distance_debug_time = now
        end
    end

    if dist > 3 then
        -- Throttle the spammy "too far" message so it only prints occasionally
        if settings.debug_enabled and now - last_too_far_log_time > 1.0 then
            console.print('[AutoGlyph-Move] Too far from glyphstone (>3), not upgrading')
            last_too_far_log_time = now
        end
        task.current_state = upgrade_state.INIT
        AutoGlyphStatusText = "Idle"
        blacklist = {}
        failed_count = 0
        session_finished = false
        last_attempted_glyph = nil
        return
    end

    -- If we already marked this glyphstone visit as finished, allow a new session
    -- when upgrades become available again (e.g., manual upgrade, UI changes) without
    -- requiring the player to walk away or toggle the plugin.
    if session_finished then
        local glyph_profiles = require "autoglyph_profiles"
        local glyphs = get_glyphs()
        local class = gui.get_character_class()
        local profile = glyph_profiles[class]
        if profile then
            for i = 1, glyphs:size() do
                local g = glyphs:get(i)
                local hash = g.glyph_name_hash
                if profile[hash] and gui.is_glyph_selected(class, hash) and should_upgrade(g) then
                    session_finished = false
                    task.current_state = upgrade_state.INIT
                    AutoGlyphStatusText = "Idle"
                    break
                end
            end
        end
    end

    if task.current_state == upgrade_state.INIT then
        -- Only start a new upgrade session if we haven't already finished this visit
        if not session_finished then
            init_upgrade()
        else
            AutoGlyphStatusText = "Finished"
            return
        end
    end

    if task.current_state == upgrade_state.UPGRADING_GLYPH then
        npc_glyph_upgrade()
    elseif task.current_state == upgrade_state.FINISHED then
        -- Only log and finalize once per visit
        if not session_finished then
            finish_upgrade()
        end
        return
    end
end

return task
