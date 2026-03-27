local tracker = {
    undercity_start_time = 0,
    interacting_beacon = false,
    killing_boss = false,
    exit_undercity = false,
    finish_undercity = false,
    player_in_boss_room = false,
    wait_to_exit = 0,
    enticement_active = 0,
    warp_pad_position = nil,
    actived_enticement = {}
}

local last_tick_time = 0

local local_player = get_local_player()

on_update(function()

    if not local_player then return end

    local current_time = os.time()

    if current_time > last_tick_time then
        last_tick_time = current_time

        if tracker.wait_to_exit > 0 then
            tracker.wait_to_exit = tracker.wait_to_exit - 1
            if tracker.wait_to_exit == 1 then
                tracker.exit_undercity = true
            end
        end
        
        -- console.print("Current time: " .. tostring(current_time))
        -- console.print("Eenticement active: " .. tostring(tracker.enticement_active))
    end
end)

return tracker