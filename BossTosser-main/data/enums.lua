local enums = {
    triggers = {
        altar = "DRLG_Generic_Boss_Trigger",
        dungeon_entrance = "Portal_Dungeon_Generic"
    },
    positions = {
        blacksmith_position = vec3:new(-1685.5394287109, -596.86566162109, 37.6484375),
        portal_position = vec3:new(-1656.7141113281, -598.21716308594, 36.28515625), 
        boss_room = {
            ["Boss_WT4_S2VampireLord"] = vec3:new(-10.556, -10.419, -3.120),
            ["Boss_WT4_Duriel"] = vec3:new(-3.616, -2.309, -3.689) ,
            ["Boss_WT4_PenitantKnight"] = vec3:new(2.0051, 1.5871, 2),
            ["Boss_WT4_Boss_Andariel"] = vec3:new(8.2821893, -8.73442268, -6.22363),
            ["Boss_WT4_MegaDemon"] = vec3:new(4.9245, 5.30860, 0.1279),
            ["Boss_WT4_Varshan"] = vec3:new(-3.28054, -3.1949, -3.30461279)
        }
    },

    quests = {
        pit_ongoing = 1815152,
        pit_started = 1922713
    },

    misc = {
        obelisk = "TWN_Kehj_IronWolves_PitKey_Crafter",
        blacksmith = "TWN_Scos_Cerrigar_Crafter_Blacksmith",
        jeweler = "TWN_Scos_Cerrigar_Vendor_Weapons",
        portal = "TownPortal",
        suppressor = "monsterAffix_suppressor_barrier"
    },

    waypoints = {
        CERRIGAR = 0x76D58,
        LIBRARY = 0x10D63D
    }
}

enums.positions.getBossRoomPosition = function(world_name)
    local pos = enums.positions.boss_room[world_name]
    if pos == nil then
        return vec3:new(0,0,0)
    end
    return pos
end

return enums