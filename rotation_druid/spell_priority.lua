-- To modify spell priority, edit the spell_priority table below.
-- The table is sorted from highest priority to lowest priority.
-- The priority is used to determine which spell to cast when multiple spells are valid to cast.

local spell_priority = {
    -- defensive abilities
    "hurricane",
    "blood_howls",
    "debilitating_roar",
    "cataclysm",
    "earthen_bulwark",
    "cyclone_armor",
    "petrify",
    "grizzly_rage",
    "evade",

    -- summons and pets
    "wolves",
    "ravens",
    "poison_creeper",


    -- instant cast
    "earth_spike",
    "wind_shear",
    "storm_strike",
    "tornado",
    "lightningstorm",
    "landslide",
    "stone_burst",
    "boulder",

    -- main damage abilities
    "pulverize",
    "claw",
    "shred",
    "trample",
    "rabies",
    "lacerate",
    
    -- filler abilities
    "maul",
}

return spell_priority
