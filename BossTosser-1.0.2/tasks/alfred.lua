local plugin_label = "Bosser" -- change to your plugin name

local settings = require 'core.settings'
-- need use_alfred to enable
-- settings.use_alfred = true

local status_enum = {
    IDLE = 'idle',
    WAITING = 'waiting for alfred to complete',
}
local task = {
    name = 'alfred_running', -- change to your choice of task name
    status = status_enum['IDLE']
}

local function reset()
    if AlfredTheButlerPlugin then
        AlfredTheButlerPlugin.pause(plugin_label)
    elseif PLUGIN_alfred_the_butler then
        PLUGIN_alfred_the_butler.pause(plugin_label)
    end
    -- add more stuff here if you need to do something after alfred is done
    task.status = status_enum['IDLE']
end

function task.shouldExecute()
    if settings.use_alfred then
        local status = {enabled = false}
        if AlfredTheButlerPlugin then
            status = AlfredTheButlerPlugin.get_status()
            -- add additional conditions to trigger if required
            if (status.enabled and status.need_trigger) or
                task.status == status_enum['WAITING']
            then
                return true
            end
        elseif PLUGIN_alfred_the_butler then
            status = PLUGIN_alfred_the_butler.get_status()
            if status.enabled and (
                status.inventory_full or
                status.restock_count > 0 or
                status.need_repair or
                status.teleport or
                task.status == status_enum['WAITING']
            ) then
                return true
            end
        end
    end
    return false
end

function task.Execute()
    if task.status == status_enum['IDLE'] then
        if AlfredTheButlerPlugin then
            AlfredTheButlerPlugin.resume()
            -- AlfredTheButlerPlugin.trigger_tasks(plugin_label,reset)
            AlfredTheButlerPlugin.trigger_tasks_with_teleport(plugin_label,reset)
        elseif PLUGIN_alfred_the_butler then
            PLUGIN_alfred_the_butler.resume()
            -- PLUGIN_alfred_the_butler.trigger_tasks(plugin_label,reset)
            PLUGIN_alfred_the_butler.trigger_tasks_with_teleport(plugin_label,reset)
        end
        task.status = status_enum['WAITING']
    end
end

if settings.enabled and settings.use_alfred and
    (AlfredTheButlerPlugin or PLUGIN_alfred_the_butler)
then
    -- do an initial reset
    reset()
end

return task