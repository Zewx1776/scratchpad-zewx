local enums = require "data.enums"
local settings = require "core.settings"
local tracker = require "core.tracker"
local utils = {}

function utils.is_actived_enticement(enticement_pos_text)
    return tracker.actived_enticement[enticement_pos_text]
end

function utils.get_undercity_brazier()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name == enums.brazier_names.brazier then
            return actor
        end
    end
    return nil
end

function utils.find_nearby_items()
    local items = actors_manager:get_all_items()
    for _, item in pairs(items) do
        local item_info = item:get_item_info()
        if item_info:get_rarity() >= 5 then
            return item, item:get_position()
        end
    end
    return nil, nil
end

function utils.player_in_boss_room()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name == "Healing_Well_Basic" then
            return utils.distance_to(actor) < 100
        end
    end
    return false
end

function utils.check_if_there_is_a_stash()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name == "Stash_NoCollision" then
            return utils.distance_to(actor) < 100
        end
    end

    return false
end

function utils.distance_to(target)
    local player_pos = get_player_position()
    local target_pos = target:get_position()
    return player_pos:dist_to_ignore_z(target_pos)
end

function utils.get_undercity_portal()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name == enums.portal_names.undercity_portal or name == enums.portal_names.undercity_portal_floor then
            return actor
        end
    end
    return nil
end

function utils.get_warp_pad()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name:find(enums.warp_pad_names.warp_pad) then
            return actor
        end
    end
end

function utils.player_in_zone(zone_name)
    return get_current_world():get_current_zone_name() == zone_name
end

function utils.player_in_find_zone(zone_name)
    return get_current_world():get_current_zone_name():find(zone_name) ~= nil
end

function utils.player_on_find_quest(quest_name)
    local quests = get_quests()
    for _, quest in pairs(quests) do
        if quest:get_name():find(quest_name) ~= nil then
            return true
        end
    end
    return false
end

function utils.get_boss()
    local enemies = target_selector.get_near_target_list(get_player_position(), 90)
    for _, enemy in pairs(enemies) do
        if enemy:is_boss() then
            return enemy
        end
    end
    return nil
end

function utils.get_closest_enemy()
    local elite_only = settings.elites_only
    local player_pos = get_player_position()
    local enemies = target_selector.get_near_target_list(player_pos, 90)
    local closest_elite, closest_normal
    local min_elite_dist, min_normal_dist = math.huge, math.huge

    for _, enemy in pairs(enemies) do
        local dist = player_pos:dist_to(enemy:get_position())
        local is_elite = enemy:is_elite() or enemy:is_champion() or enemy:is_boss()

        if is_elite then
            if dist < min_elite_dist then
                closest_elite = enemy
                min_elite_dist = dist
            end
        elseif not elite_only then
            if dist < min_normal_dist then
                closest_normal = enemy
                min_normal_dist = dist
            end
        end
    end

    return closest_elite or (not elite_only and closest_normal) or nil
end

function utils.get_enticement()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name:find(enums.enticement_names.enticement) then
            return actor
        end
    end
    return nil
end

function utils.get_beacon()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name == enums.beacon_names.beacon then
            return actor
        end
    end
    return nil
end

return utils
