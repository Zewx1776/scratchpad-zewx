local plugin_label = 'batmobile'
-- kept plugin label instead of waiting for update_tracker to set it
local navigator  = require 'core.navigator'
local explorer   = require 'core.explorer'
local tracker    = require 'core.tracker'
local utils      = require 'core.utils'
local long_path  = require 'core.long_path'

local external = {
    name          = plugin_label
}
external.is_done = function ()
    return navigator.is_done()
end
external.is_paused = function ()
    return navigator.paused
end
external.pause = function (caller)
    if caller == nil then
        utils.log(2,'pause called with no caller')
        return
    end
    tracker.external_caller = caller
    utils.log(2, 'pause called by ' .. tostring(caller))
    navigator.pause()
end
external.resume = function (caller)
    if caller == nil then
        utils.log(2,'resume called with no caller')
        return
    end
    tracker.external_caller = caller
    utils.log(2, 'resume called by ' .. tostring(caller))
    navigator.unpause()
end
external.reset = function (caller)
    if caller == nil then
        utils.log(2,'reset called with no caller')
        return
    end
    tracker.external_caller = caller
    utils.log(2, 'reset called by ' .. tostring(caller))
    navigator.reset()
end
external.move = function (caller)
    if caller == nil then
        utils.log(2,'move called with no caller')
        return
    end
    tracker.external_caller = caller
    utils.log(2, 'move called by ' .. tostring(caller))
    tracker.bench_start("total_move")
    local start_move = os.clock()
    navigator.move()
    tracker.timer_move = os.clock() - start_move
    tracker.bench_stop("total_move")
    tracker.bench_report()
end
external.update = function (caller)
    if caller == nil then
        utils.log(2,'update called with no caller')
        return
    end
    tracker.external_caller = caller
    utils.log(2, 'update called by ' .. tostring(caller))
    tracker.bench_start("total_update")
    local start_update = os.clock()
    navigator.update()
    tracker.timer_update = os.clock() - start_update
    tracker.bench_stop("total_update")
end
external.set_target = function(caller, target, disable_spell)
    if caller == nil then
        utils.log(2,'set_target called with no caller')
        return false
    end
    tracker.external_caller = caller
    utils.log(2, 'set_target called by ' .. tostring(caller))
    return navigator.set_target(target, disable_spell)
end
external.clear_target = function (caller)
    if caller == nil then
        utils.log(2,'clear_target called with no caller')
        return
    end
    tracker.external_caller = caller
    utils.log(2, 'clear_target called by ' .. tostring(caller))
    navigator.clear_target()
end
external.get_backtrack = function(caller)
    if caller == nil then
        utils.log(2,'get_backtrack called with no caller')
        return
    end
    tracker.external_caller = caller
    utils.log(2, 'get_backtrack called by ' .. tostring(caller))
    return explorer.backtrack
end
external.set_priority = function(caller, priority)
    if caller == nil then
        utils.log(2,'set_priority called with no caller')
        return
    end
    tracker.external_caller = caller
    utils.log(2, 'set_priority called by ' .. tostring(caller) .. ' to priortize ' .. tostring(priority))
    explorer.set_priority(priority)
end

-- Find a path without normal distance-scaled caps.
-- Returns path (array of vec3 nodes) or nil on failure.
-- Prints a result line to console automatically.
external.find_long_path = function(caller, target)
    if caller == nil then
        utils.log(2, 'find_long_path called with no caller')
        return nil
    end
    tracker.external_caller = caller
    utils.log(2, 'find_long_path called by ' .. tostring(caller))
    local player = get_local_player()
    if not player then return nil end
    local start = player:get_position()
    return long_path.find_long_path(start, target)
end

-- Find an uncapped path to target and immediately start walking it.
-- Returns true if path was found and navigation started, false otherwise.
external.navigate_long_path = function(caller, target)
    if caller == nil then
        utils.log(2, 'navigate_long_path called with no caller')
        return false
    end
    tracker.external_caller = caller
    utils.log(2, 'navigate_long_path called by ' .. tostring(caller))
    return long_path.navigate_to(target)
end

-- True while long path navigation is actively driving the navigator.
external.is_long_path_navigating = function()
    return long_path.navigating
end

-- Stop long path navigation and clear the navigator target.
external.stop_long_path = function(caller)
    if caller == nil then
        utils.log(2, 'stop_long_path called with no caller')
        return
    end
    tracker.external_caller = caller
    utils.log(2, 'stop_long_path called by ' .. tostring(caller))
    long_path.stop_navigation()
end

return external