local task_manager = {}
local tasks = {}
local current_task = nil
local last_call_time = 0.0
local tracker = require "core.tracker"

function task_manager.get_current_task()
    return current_task or { name = "Idle" }
end

function task_manager.register_task(task)
    table.insert(tasks, task)
end

function task_manager.execute_tasks()
    local current_core_time = get_time_since_inject()
    if current_core_time - last_call_time < 0.2 then
        return
    end

    last_call_time = current_core_time

    for _, task in ipairs(tasks) do
        if task.shouldExecute() then
            current_task = task
            task.Execute()
            break
        end
    end

    -- Set the flag in the explorer module

    if not current_task then
        current_task = { name = "Idle" } -- Default state when no task is active
    end
end

local task_files = {
    "interact_enticement",
    "interact_beacon",
    "interact_undercity_portal",
    "kill_boss",
    "kill_monsters",
    "alfred",
    "exit_undercity",
    "explore_undercity",
    "open_undercity_portal",
    "enter_portal",
}

for _, file in ipairs(task_files) do
    local task = require("tasks." .. file)
    task_manager.register_task(task)
end

return task_manager
