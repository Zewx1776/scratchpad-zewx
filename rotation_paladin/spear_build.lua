-- Spear Build Profile (normalized export)
-- Spear of the Heavens focused Paladin build

-- safe_require helper (optional)
local function safe_require(name)
    local ok, mod = pcall(require, name)
    if not ok then
        if console and console.print then console.print("Warning: optional module '" .. tostring(name) .. "' not found; continuing") end
        return nil
    end
    return mod
end

local spear_build = {
    name = "Spear Build",
    description = "Spear of the Heavens focused build with ranged AoE damage",
    skills = {
        spear_of_the_heavens = true,
        fanaticism_aura = true,
        holy_light_aura = true,
    }
}

local function apply(spells)
    console.print("Applying Spear Build profile...")
    for skill_name, should_enable in pairs(spear_build.skills) do
        if spells[skill_name] and spells[skill_name].set_enabled then
            spells[skill_name].set_enabled(should_enable)
            if should_enable then
                console.print("Enabled: " .. skill_name)
            else
                console.print("Disabled: " .. skill_name)
            end
        end
    end
    console.print("Spear Build profile applied successfully!")
end

return {
    profile = spear_build,
    apply = apply
}