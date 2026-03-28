local developer_id = "resource_debug_zewx"
local print_interval = 2.0 -- seconds between prints
local last_print_time = 0.0

local main_tree = tree_node:new(0)
local enabled = checkbox:new(true, get_hash(developer_id .. "enabled"))

on_render_menu(function()
    if main_tree:push("Resource Debug") then
        enabled:render("Enable", "Print resource and spell info to console")
        main_tree:pop()
    end
end)

on_update(function()
    if not enabled:get() then
        return
    end

    local now = get_time_since_inject()
    if now - last_print_time < print_interval then
        return
    end
    last_print_time = now

    local local_player = get_local_player()
    if not local_player then
        console.print("[ResourceDebug] No local player found")
        return
    end

    -- Class info
    local class_id = local_player:get_character_class_id()
    local class_names = {
        [0] = "Sorcerer",
        [1] = "Barbarian",
        [3] = "Rogue",
        [5] = "Druid",
        [6] = "Necromancer",
        [7] = "Spiritborn",
        [9] = "Paladin",
    }
    local class_name = class_names[class_id] or ("Unknown(id=" .. tostring(class_id) .. ")")

    -- Resource info
    local current_resource = local_player:get_primary_resource_current()
    local max_resource = local_player:get_primary_resource_max()
    local resource_pct = 0
    if max_resource and max_resource > 0 then
        resource_pct = (current_resource / max_resource) * 100
    end

    -- Health info
    local current_health = local_player:get_current_health()
    local max_health = local_player:get_max_health()
    local health_pct = 0
    if max_health and max_health > 0 then
        health_pct = (current_health / max_health) * 100
    end

    -- Potions
    local potion_count = local_player:get_health_potion_count()
    local potion_max = local_player:get_health_potion_max_count()

    -- Position
    local pos = get_player_position()

    -- Equipped spells
    local spell_ids = get_equipped_spell_ids()

    console.print("========== [ResourceDebug] ==========")
    console.print("[Class] " .. class_name .. " (class_id=" .. tostring(class_id) .. ") | Level: " .. tostring(local_player:get_level()))
    console.print("[Health] " .. string.format("%.0f / %.0f (%.1f%%)", current_health, max_health, health_pct))
    console.print("[Resource] " .. string.format("%.0f / %.0f (%.1f%%)", current_resource, max_resource, resource_pct))
    console.print("[Potions] " .. tostring(potion_count) .. " / " .. tostring(potion_max))
    console.print("[Position] " .. string.format("x=%.1f y=%.1f z=%.1f", pos:x(), pos:y(), pos:z()))

    if spell_ids and #spell_ids > 0 then
        console.print("[Equipped Spells]")
        for i, spell_id in ipairs(spell_ids) do
            local name = get_name_for_spell(spell_id) or "Unknown"
            local is_ready = utility.is_spell_ready(spell_id)
            local is_affordable = utility.is_spell_affordable(spell_id)
            local can_cast = utility.can_cast_spell(spell_id)

            console.print(string.format(
                "  [%d] %s (id=%d) | ready=%s | affordable=%s | can_cast=%s",
                i, name, spell_id,
                tostring(is_ready),
                tostring(is_affordable),
                tostring(can_cast)
            ))
        end
    else
        console.print("[Equipped Spells] None found")
    end

    console.print("======================================")
end)
