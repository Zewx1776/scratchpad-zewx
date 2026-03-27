local utils      = require "core.utils"
local enums      = require "data.enums"
local tracker    = require "core.tracker"
local explorerlite = require "core.explorerlite"
local settings   = require "core.settings"


local last_reset = 0
local task = {
    name = "Enter Boss Dungeon",
    shouldExecute = function()
        --console.print("Checking if the task 'Exit Pit' should be executed.")

        return not utils.player_on_quest(get_current_world():get_current_zone_name()) and utils.get_dungeon_entrance()
    end,
    Execute = function()
      --  console.print("Executing the task: Enter Boss Dungeon.")
        explorerlite.is_task_running = true  -- Set the flag
      --  console.print("Setting explorer task running flag to true.")
        explorerlite:clear_path_and_target()
      --  console.print("Clearing path and target in explorer.")

        tracker.start_time = 0  -- Reset the start time for the next execution
        tracker.finished_time = 0
        settings.can_exit = false
        settings.first_item_dropped = false
        settings.altar_activated = false
        
        local entrance = utils.get_dungeon_entrance()
        if entrance then
            loot_manager.interact_with_object(entrance)
        end

        explorerlite.is_task_running = false  -- Reset the flag
     --   console.print("Setting explorer task running flag to false.")
    end
}

return task