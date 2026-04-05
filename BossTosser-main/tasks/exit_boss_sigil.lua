local utils    = require "core.utils"
local settings = require "core.settings"
local enums    = require "data.enums"

-- How long conditions must persist before we exit (avoids firing during altar→boss spawn transition)
local WAIT_BEFORE_EXIT = 5.0

local run_complete_detected_time = 0

local function no_altar_present()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name == "Boss_WT4_Varshan"        or name == "Boss_WT4_Duriel"
        or name == "Boss_WT4_PenitantKnight" or name == "Boss_WT4_Andariel"
        or name == "Boss_WT4_MegaDemon"      or name == "Boss_WT4_S2VampireLord"
        or name == "Boss_WT5_Urivar"         or name == "Boss_WT_Belial" then
            return false
        end
    end
    return true
end

local function no_chest_present()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name:find("EGB_Chest") == 1 or name == "Boss_WT_Belial_Chest"
        or name:find("S12_Prop_Theme_Chest") == 1 then
            return false
        end
    end
    return true
end

local task = {
    name = "Exit Boss Sigil",

    shouldExecute = function()
        -- Only relevant if we actually activated an altar this run
        if not settings.altar_activated then
            run_complete_detected_time = 0
            return false
        end

        local is_in_boss_zone = utils.match_player_zone("Boss_WT4_")
                             or utils.match_player_zone("Boss_WT3_")
                             or utils.match_player_zone("Boss_Kehj_Belial")
                             or utils.match_player_zone("Boss_WT5_")
        if not is_in_boss_zone then
            run_complete_detected_time = 0
            return false
        end

        -- Boss must be dead (no enemies in range)
        if utils.get_closest_enemy() then
            run_complete_detected_time = 0
            return false
        end

        -- Altar must be gone (consumed by summoning)
        if not no_altar_present() then
            run_complete_detected_time = 0
            return false
        end

        -- No reward chest present (wait for open_chest to handle it first)
        if not no_chest_present() then
            run_complete_detected_time = 0
            return false
        end

        return true
    end,

    Execute = function()
        local current_time = get_time_since_inject()

        if run_complete_detected_time == 0 then
            run_complete_detected_time = current_time
            console.print("Exit Boss Sigil: run complete detected, waiting " .. WAIT_BEFORE_EXIT .. "s before exit")
            return
        end

        local elapsed = current_time - run_complete_detected_time
        if elapsed < WAIT_BEFORE_EXIT then
            console.print(string.format("Exit Boss Sigil: exiting in %.1fs...", WAIT_BEFORE_EXIT - elapsed))
            return
        end

        console.print("Exit Boss Sigil: teleporting to town to restart run")
        settings.altar_activated = false
        run_complete_detected_time = 0
        teleport_to_waypoint(enums.waypoints.CERRIGAR)
    end
}

return task
