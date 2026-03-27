-- Judgment Build Profile (normalized export)
-- Based Judgment focused Paladin build with crowd control and damage

-- safe_require helper (optional)
local function safe_require(name)
    local ok, mod = pcall(require, name)
    if not ok then
        if console and console.print then console.print("Warning: optional module '" .. tostring(name) .. "' not found; continuing") end
        return nil
    end
    return mod
end

local judgment_build = {
    name = "Judgment Build",
    description = "Judgment focused build with strong crowd control and AoE damage",
    skills = {
        judgement = true,
        fanaticism_aura = true,
        defiance_aura = true,
    }
}

local function apply(spells)
    console.print("Applying Judgment Build profile...")
    for skill_name, should_enable in pairs(judgment_build.skills) do
        if spells[skill_name] and spells[skill_name].set_enabled then
            spells[skill_name].set_enabled(should_enable)
            if should_enable then
                console.print("Enabled: " .. skill_name)
            else
                console.print("Disabled: " .. skill_name)
            end
        end
    end
    console.print("Judgment Build profile applied successfully!")
end

return {
    profile = judgment_build,
    apply = apply
}