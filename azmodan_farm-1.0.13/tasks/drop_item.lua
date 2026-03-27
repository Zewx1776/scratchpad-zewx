local plugin_label = 'azmodan_farm' -- change to your plugin name

local tracker = require "core.tracker"

local status_enum = {
    IDLE = 'idle'
}
local task = {
    name = 'drop_item', -- change to your choice of task name
    status = status_enum['IDLE'],
    reset_orbwalker_clear = false,
}
function task.shouldExecute()
    return tracker.drop_items
end

function task.Execute()
    local local_player = get_local_player()
    if not local_player then return end
    local items = local_player:get_inventory_items()
    for _, item in pairs(items) do
        if not item:is_locked() then
            loot_manager.drop_item(item)
        end
    end
    tracker.drop_items = false
end

return task