-- Paladin Build Profiles
-- Based on top-tier Mobalytics builds with optimized rotations

local build_profiles = {}

-- Build 1: Blessed Hammer (Mekuna) - Hammerkuna
build_profiles.blessed_hammer_mekuna = {
    name = "Blessed Hammer (Mekuna)",
    description = "Speed-clearing build with auto-casting hammers. Focus on mobility and Arbiter form.",
    
    -- Enabled spells for this build
    enabled_spells = {
        "blessed_hammer",      -- Core damage - hammers circle around
        "falling_star",        -- Mobility + triggers auto-cast
        "condemn",            -- Pull enemies, extend Arbiter form
        "arbiter_of_justice", -- Maintain Arbiter form permanently
        "rally",              -- Faith management
        "fanaticism_aura",    -- Attack speed and damage
        "defiance_aura",      -- Armor and survivability
        "advance",            -- Movement when well-geared
    },
    
    -- Rotation priority (higher number = higher priority)
    rotation_priority = {
        fanaticism_aura = 100,    -- Keep auras up
        defiance_aura = 99,
        arbiter_of_justice = 95,  -- Maintain Arbiter form
        falling_star = 90,        -- Mobility + hammer auto-cast
        condemn = 85,             -- Pull and extend Arbiter
        blessed_hammer = 80,      -- Main DPS
        rally = 75,               -- Resource when needed
        advance = 70,             -- Movement
    }
}

-- Build 2: Auradin (Holy Light Aura) - Walking Simulator
build_profiles.auradin_holy_light = {
    name = "Auradin (Holy Light Aura)",
    description = "Passive AFK playstyle. Auras melt everything as you walk. Ultimate lazy build.",
    
    enabled_spells = {
        "holy_light_aura",     -- Core damage - passive screen-wide
        "fanaticism_aura",     -- Attack speed buff
        "defiance_aura",       -- Defense buff
        "arbiter_of_justice",  -- Maintain Arbiter form
        "falling_star",        -- Mobility + Arbiter trigger
        "consecration",        -- Boss/pack damage
        "rally",               -- Cooldown management
        "advance",             -- Movement
    },
    
    rotation_priority = {
        holy_light_aura = 100,     -- Always active
        fanaticism_aura = 99,      -- Keep auras up
        defiance_aura = 98,
        arbiter_of_justice = 95,   -- Maintain Arbiter form
        falling_star = 90,         -- Mobility
        consecration = 85,         -- Boss damage
        rally = 75,                -- Resource
        advance = 70,              -- Movement
    }
}

-- Build 3: Judgement (Lawkuna) - Chain Explosions
build_profiles.judgement_lawkuna = {
    name = "Judgement (Lawkuna)",
    description = "Chain explosion build focused on Judgement marks. High Pit pushing potential.",
    
    enabled_spells = {
        "judgement_day",       -- Main skill
        "spear_of_the_heavens", -- Judgement applicator
        "arbiter_of_justice",  -- Maintain Arbiter form
        "fanaticism_aura",     -- Attack speed
        "defiance_aura",       -- Defense
        "condemn",             -- Group enemies
        "consecration",        -- Sustain
        "falling_star",        -- Mobility
        "blessed_hammer",      -- Judgement detonator (early game)
    },
    
    rotation_priority = {
        arbiter_of_justice = 100,  -- Always maintain
        fanaticism_aura = 99,      -- Keep auras up
        defiance_aura = 98,
        spear_of_the_heavens = 95, -- Spam for Judgement
        judgement_day = 90,        -- Main damage
        condemn = 85,              -- Group enemies
        consecration = 80,         -- Sustain
        blessed_hammer = 75,       -- Detonator
        falling_star = 70,         -- Movement
    }
}

-- Build 4: Blessed Shield - Captain America
build_profiles.blessed_shield = {
    name = "Blessed Shield",
    description = "Shield throw build with auto-casting. Captain America style with bouncing shields.",
    
    enabled_spells = {
        "blessed_shield",      -- Core damage - shield throws
        "arbiter_of_justice",  -- Maintain Arbiter form
        "judgement_day",       -- Apply marks for shield bounces
        "rally",               -- Evade reset + resource
        "condemn",             -- Group enemies
        "falling_star",        -- Mobility
        "fanaticism_aura",     -- Attack speed
        "defiance_aura",       -- Defense
    },
    
    rotation_priority = {
        arbiter_of_justice = 100,  -- Always maintain
        fanaticism_aura = 99,      -- Keep auras up
        defiance_aura = 98,
        blessed_shield = 95,       -- Main DPS
        judgement_day = 90,        -- Apply marks
        rally = 85,                -- Evade reset
        condemn = 80,              -- Group
        falling_star = 75,         -- Movement
    }
}

-- Build 5: Brandish - Supplication
build_profiles.brandish = {
    name = "Brandish",
    description = "Melee weapon swing build with Supplication projectiles. Stand on enemies for max damage.",
    
    enabled_spells = {
        "brandish",            -- Core damage - spam constantly
        "arbiter_of_justice",  -- Maintain Arbiter form
        "condemn",             -- Pull enemies close
        "falling_star",        -- Mobility + Arbiter trigger
        "fanaticism_aura",     -- Attack speed
        "defiance_aura",       -- Defense
        "consecration",        -- Healing + damage
        "fortress",            -- Boss survivability
    },
    
    rotation_priority = {
        arbiter_of_justice = 100,  -- Always maintain
        fanaticism_aura = 99,      -- Keep auras up
        defiance_aura = 98,
        brandish = 95,             -- Spam constantly
        condemn = 90,              -- Pull enemies
        falling_star = 85,         -- Movement
        consecration = 80,         -- Sustain
        fortress = 75,             -- Boss defense
    }
}

-- Build 6: Spear of the Heavens - Judgement Variant
build_profiles.spear_of_heavens = {
    name = "Spear of the Heavens",
    description = "Ranged spear build with Judgement chain explosions. Spam spears for endless chains.",
    
    enabled_spells = {
        "spear_of_the_heavens", -- Core damage - spam
        "judgement_day",        -- Apply marks
        "arbiter_of_justice",   -- Maintain Arbiter form
        "blessed_hammer",       -- Judgement detonator
        "condemn",              -- Group + Vulnerable
        "consecration",         -- Healing
        "fanaticism_aura",      -- Attack speed
        "defiance_aura",        -- Defense
        "falling_star",         -- Mobility
    },
    
    rotation_priority = {
        arbiter_of_justice = 100,  -- Always maintain
        fanaticism_aura = 99,      -- Keep auras up
        defiance_aura = 98,
        spear_of_the_heavens = 95, -- Spam constantly
        judgement_day = 90,        -- Apply marks
        blessed_hammer = 85,       -- Detonate
        condemn = 80,              -- Group
        consecration = 75,         -- Sustain
        falling_star = 70,         -- Movement
    }
}

-- Get list of all build names for dropdown
local _BUILD_ORDER = {
    "blessed_hammer_mekuna",
    "auradin_holy_light",
    "judgement_lawkuna",
    "blessed_shield",
    "brandish",
    "spear_of_heavens",
}

function build_profiles.get_build_list()
    return _BUILD_ORDER
end

-- Get build names for display
function build_profiles.get_build_display_names()
    local builds = build_profiles.get_build_list()
    local display_names = {}
    for _, build_id in ipairs(builds) do
        local build = build_profiles[build_id]
        if build then
            table.insert(display_names, build.name)
        end
    end
    return display_names
end

-- Get build by ID
function build_profiles.get_build(build_id)
    return build_profiles[build_id]
end

-- Get build ID by index (1-based)
function build_profiles.get_build_id_by_index(index)
    local builds = build_profiles.get_build_list()
    return builds[index]
end

return build_profiles
