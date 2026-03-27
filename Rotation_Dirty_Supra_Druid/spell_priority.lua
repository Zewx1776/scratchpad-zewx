-- Fixed spell priority - PULVERIZE SPAM FIRST!
-- Pulverize gets absolute priority when enemies are present

local spell_priority = {
    -- CORE DAMAGE - HIGHEST PRIORITY
    "pulverize",             -- PRIMARY SPAM ABILITY - ALWAYS FIRST!
    
    -- Ultimate damage (only when available)
    "grizzly_rage",          -- Cast on cooldown for massive damage
    
    -- Buff maintenance (ONLY when buffs are missing/expiring)
    "maul",                  -- For Quickshift buff (restricted)
    "claw",                  -- For Heightened Senses buff (restricted) 
    "debilitating_roar",     -- For damage and survivability buffs (restricted)
    
    -- Defensive abilities (low priority)
    "cyclone_armor",         -- Added higher for buff management
    "blood_howls",
    "earthen_bulwark",
    "petrify",
    "evade",
    "hurricane",
    "cataclysm",
    
    -- Everything else (very low priority)
    "wolves",
    "ravens",
    "poison_creeper",
    "earth_spike",
    "wind_shear",
    "storm_strike",
    "tornado",
    "lightningstorm",
    "landslide",
    "stone_burst",
    "boulder",
    "lacerate",
    "shred",
    "trample",
    "rabies",
}

return spell_priority