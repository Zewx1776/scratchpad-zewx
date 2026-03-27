local plugin_label = 'azmodan_farm' -- change to your plugin name

local tracker = require "core.tracker"

local status_enum = {
    IDLE = 'idle'
}
local task = {
    name = 'drop_sigil', -- change to your choice of task name
    status = status_enum['IDLE'],
    last_drop = -1,
    reset_orbwalker_clear = false,
}
function task.shouldExecute()
    return tracker.drop_sigils
end

function task.Execute()
    local local_player = get_local_player()
    if not local_player then return end
    local items = local_player:get_dungeon_key_items()
    for _, item in pairs(items) do
        local name = item:get_display_name()
        if not item:is_locked() and string.lower(name):match('sigil') then
            loot_manager.drop_item(item)
            task.last_drop = get_time_since_inject()
            if orbwalker.get_orb_mode() == 3 then
                orbwalker.set_clear_toggle(false);
                task.reset_orbwalker_clear = true
            end
        end
    end
    if task.last_drop + 5 < get_time_since_inject() then
        if task.reset_orbwalker_clear then
            orbwalker.set_clear_toggle(true);
        end
        tracker.drop_sigils = false
    end
end

return task