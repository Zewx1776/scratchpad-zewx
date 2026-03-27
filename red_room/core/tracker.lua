local plugin_label = 'red_room'
-- kept plugin label instead of waiting for update_tracker to set it

local tracker = {
    name        = plugin_label,
    drop_sigils = false,
    drop_items = false,
    azmodan_start = nil,
    azmodan_timer = {},
    done = false,
    done_time = nil
}

return tracker