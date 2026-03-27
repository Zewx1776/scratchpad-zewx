-- build_saver_patch.lua
-- Small runtime wrapper that prevents a broken saved build from crashing load_build.
-- Usage:
-- 1) Save this file in addon folder.
-- 2) require("build_saver_patch") once (or temporarily add require to main.lua).
-- 3) Remove after you finish repairs if you want.

local ok, bs = pcall(require, "build_saver")
local function safe_print(msg)
    if type(console) == "table" and console.print then pcall(console.print, tostring(msg)) else pcall(print, tostring(msg)) end
end

if not ok or not bs then
    safe_print("build_saver_patch: could not require build_saver")
    return {}
end

local orig_load = bs.load_build
if type(orig_load) ~= "function" then
    safe_print("build_saver_patch: original load_build not found")
    return {}
end

bs.load_build = function(name, spells_tbl)
    -- Defensive guard: call original load_build in pcall and return a safe result on error.
    local okl, a, b = pcall(function() return orig_load(name, spells_tbl) end)
    if not okl then
        safe_print("build_saver_patch: load_build error for '" .. tostring(name) .. "': " .. tostring(a))
        return false, tostring(a)
    end
    return a, b
end

safe_print("build_saver_patch: applied safe wrapper to load_build")
return {}