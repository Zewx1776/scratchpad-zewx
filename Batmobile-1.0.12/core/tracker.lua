local plugin_label = 'batmobile_explorer'
-- kept plugin label instead of waiting for update_tracker to set it

local tracker = {
    name        = plugin_label,
    external_caller = nil,
    timer_update = 0,
    timer_move = 0,
    timer_draw = 0,
    debug_pos = nil,
    debug_node = nil,
    debug_actor = nil,
    paused = false,
    done = false,
    evaluated = {},
    -- benchmark system
    bench_enabled = true,
    bench_data = {},
    bench_counters = {},   -- event counters (no timing)
    bench_starts = {},
    bench_last_report = -1,
    bench_report_interval = 5,
    bench_first_report = true,
    bench_nav_state = nil, -- set each frame by navigator.move()
}

tracker.bench_start = function(name)
    if not tracker.bench_enabled then return end
    tracker.bench_starts[name] = os.clock()
end

tracker.bench_stop = function(name)
    if not tracker.bench_enabled then return end
    local start = tracker.bench_starts[name]
    if not start then return end
    local elapsed = os.clock() - start
    tracker.bench_starts[name] = nil
    local entry = tracker.bench_data[name]
    if not entry then
        entry = {total = 0, count = 0, max = 0}
        tracker.bench_data[name] = entry
    end
    entry.total = entry.total + elapsed
    entry.count = entry.count + 1
    if elapsed > entry.max then entry.max = elapsed end
end

tracker.bench_count = function(name)
    if not tracker.bench_enabled then return end
    tracker.bench_counters[name] = (tracker.bench_counters[name] or 0) + 1
end

tracker.bench_report = function()
    if not tracker.bench_enabled then return end
    local now = os.clock()
    if now - tracker.bench_last_report < tracker.bench_report_interval then return end
    local window = now - tracker.bench_last_report
    tracker.bench_last_report = now

    if tracker.bench_first_report then
        console.print("[BATMOBILE PERF] Benchmark enabled - reporting every " .. tracker.bench_report_interval .. "s")
        tracker.bench_first_report = false
        return
    end

    -- collect and sort entries by total time descending
    local entries = {}
    for name, data in pairs(tracker.bench_data) do
        entries[#entries+1] = {name = name, data = data}
    end
    if #entries == 0 then return end
    table.sort(entries, function(a, b) return a.data.total > b.data.total end)

    console.print(string.format("[BATMOBILE PERF] === %.1fs window ===", window))

    -- Navigator state snapshot (set every frame by navigator.move)
    if tracker.bench_nav_state then
        console.print("  [NAV STATE] " .. tracker.bench_nav_state)
    end

    -- Timed sections sorted by total time descending
    console.print("  [TIMING]  name                   calls    avg(ms)   max(ms)  total(ms)")
    for _, entry in ipairs(entries) do
        local d = entry.data
        local avg_ms = d.count > 0 and (d.total / d.count * 1000) or 0
        local rate = d.count / window
        console.print(string.format("  %-24s %4d(%4.1f/s)  avg %7.3fms  max %7.3fms  total %7.1fms",
            entry.name, d.count, rate, avg_ms, d.max * 1000, d.total * 1000))
    end

    -- Event counters
    local cnt_entries = {}
    for name, cnt in pairs(tracker.bench_counters) do
        cnt_entries[#cnt_entries + 1] = { name = name, cnt = cnt }
    end
    if #cnt_entries > 0 then
        table.sort(cnt_entries, function(a, b) return a.name < b.name end)
        local parts = {}
        for _, e in ipairs(cnt_entries) do
            parts[#parts + 1] = string.format("%s=%d(%.1f/s)", e.name, e.cnt, e.cnt / window)
        end
        console.print("  [EVENTS]  " .. table.concat(parts, "   "))
    end

    -- reset for next window
    tracker.bench_data = {}
    tracker.bench_counters = {}
end

return tracker
