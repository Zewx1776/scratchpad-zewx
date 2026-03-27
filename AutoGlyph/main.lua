console.print("[AutoGlyph] main.lua loaded")

local gui = require "autoglyph_gui"
local settings = require "autoglyph_settings"
local upgrade_task = require "tasks.upgrade_glyph"

local local_player

local function update_locals()
    local_player = get_local_player()
end

local function main_pulse()
    settings:update_settings()
    if not local_player or not settings.enabled then return end
    upgrade_task.Execute()
end

local function render_pulse()
    -- No 3D rendering for now; Autoglyph is menu-driven only
end

AutoGlyphPlugin = {
    enable = function ()
        gui.elements.main_toggle:set(true)
    end,
    disable = function ()
        gui.elements.main_toggle:set(false)
    end,
    status = function ()
        return {
            ['enabled'] = gui.elements.main_toggle:get(),
        }
    end,
}

on_update(function()
    update_locals()
    main_pulse()
end)

on_render_menu(gui.render)
on_render(render_pulse)
