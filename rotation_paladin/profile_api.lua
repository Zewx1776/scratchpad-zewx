-- profile_api.lua
-- Convenience wrapper with Save / Load / List / Delete profile functions.
-- Place next to main.lua and require it from main.lua (or run require("profile_api") in the Dev Console).
--
-- Exposed globals:
--   Paladin_SaveProfile(name)     -- saves current enabled skills into 'name'
--   Paladin_LoadProfile(name)     -- loads profile 'name'
--   Paladin_ListProfiles()        -- prints saved profile names (returns a table)
--   Paladin_DeleteProfile(name)   -- deletes profile 'name'
--
-- All operations are guarded and will print concise status messages to the console.

local ok_bs, build_saver = pcall(require, "build_saver")
if not ok_bs then build_saver = nil end
local spells = _G and _G.spells or nil

local function safe_print(msg)
    if type(console) == "table" and type(console.print) == "function" then
        pcall(console.print, tostring(msg))
    else
        pcall(print, tostring(msg))
    end
end

local function trim(s)
    if not s then return s end
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local api = {}

-- Save current enabled skills into a named profile
function api.save_profile(name)
    name = trim(name or "")
    if name == "" then
        safe_print("Paladin API: provide a non-empty profile name to save")
        return false, "invalid_name"
    end
    if not build_saver or type(build_saver.save_current_build) ~= "function" then
        safe_print("Paladin API: build_saver.save_current_build not available")
        return false, "no_api"
    end
    local ok, res = pcall(build_saver.save_current_build, name, spells)
    safe_print("Paladin API: save_profile -> " .. tostring(ok) .. " : " .. tostring(res))
    return ok, res
end

-- Load a named profile
function api.load_profile(name)
    name = trim(name or "")
    if name == "" then
        safe_print("Paladin API: provide a non-empty profile name to load")
        return false, "invalid_name"
    end
    if not build_saver or type(build_saver.load_build) ~= "function" then
        safe_print("Paladin API: build_saver.load_build not available")
        return false, "no_api"
    end
    local ok, res = pcall(build_saver.load_build, name, spells)
    safe_print("Paladin API: load_profile -> " .. tostring(ok) .. " : " .. tostring(res))
    return ok, res
end

-- List saved profiles (prints them) and returns a table (name -> data if available)
function api.list_profiles()
    if not build_saver then
        safe_print("Paladin API: build_saver not available")
        return {}
    end

    -- Preferred API
    if type(build_saver.get_saved_builds) == "function" then
        local ok, tbl = pcall(build_saver.get_saved_builds)
        if ok and type(tbl) == "table" then
            for name,_ in pairs(tbl) do safe_print("Profile: " .. tostring(name)) end
            return tbl
        end
    end

    -- Known field
    if type(build_saver.saved_builds) == "table" then
        for name,_ in pairs(build_saver.saved_builds) do safe_print("Profile: " .. tostring(name)) end
        return build_saver.saved_builds
    end

    -- Fallback: read paladin_saved_builds.lua
    local f = io.open("paladin_saved_builds.lua", "r")
    if not f then
        safe_print("Paladin API: no saved builds found")
        return {}
    end
    local content = f:read("*a"); f:close()
    local ok, chunk = pcall(loadstring or load, content)
    if ok and type(chunk) == "function" then
        local ok2, tbl = pcall(function() return chunk() end)
        if ok2 and type(tbl) == "table" then
            for name,_ in pairs(tbl) do safe_print("Profile: " .. tostring(name)) end
            return tbl
        end
    end

    safe_print("Paladin API: could not enumerate saved builds")
    return {}
end

-- Delete a named profile
-- Tries build_saver.delete_saved_build(name) if available, otherwise edits paladin_saved_builds.lua with a backup.
function api.delete_profile(name)
    name = trim(name or "")
    if name == "" then
        safe_print("Paladin API: provide a non-empty profile name to delete")
        return false, "invalid_name"
    end

    -- Preferred API
    if build_saver and type(build_saver.delete_saved_build) == "function" then
        local ok, res = pcall(build_saver.delete_saved_build, name)
        if ok then
            safe_print("Paladin API: delete_profile -> " .. tostring(ok) .. " : " .. tostring(res))
            return ok, res
        else
            safe_print("Paladin API: delete_profile API call failed: " .. tostring(res))
            -- fall through to file fallback
        end
    end

    -- File fallback
    local path = "paladin_saved_builds.lua"
    local f = io.open(path, "r")
    if not f then
        safe_print("Paladin API: saved builds file not found (" .. path .. ")")
        return false, "file_not_found"
    end
    local content = f:read("*a"); f:close()

    local ok, chunk = pcall(loadstring or load, content)
    if not ok or type(chunk) ~= "function" then
        safe_print("Paladin API: failed to load saved builds file")
        return false, "load_failed"
    end

    local ok2, tbl = pcall(function() return chunk() end)
    if not ok2 or type(tbl) ~= "table" then
        safe_print("Paladin API: unexpected saved builds format")
        return false, "bad_format"
    end

    if tbl[name] == nil then
        safe_print("Paladin API: profile '" .. tostring(name) .. "' not found in saved builds")
        return false, "not_found"
    end

    -- Backup
    local bak = path .. ".bak"
    pcall(function()
        local fb = io.open(bak, "w")
        if fb then fb:write(content); fb:close() end
    end)

    -- Remove the entry and write back
    tbl[name] = nil
    local okw, err = pcall(function()
        local fout = io.open(path, "w")
        if not fout then error("could not open file for write") end
        fout:write("return {\n")
        for k,v in pairs(tbl) do
            fout:write(string.format("  [%q] = {\n", tostring(k)))
            if type(v) == "table" then
                for _, skill in ipairs(v) do
                    fout:write(string.format("    %q,\n", tostring(skill)))
                end
            end
            fout:write("  },\n")
        end
        fout:write("}\n")
        fout:close()
    end)
    if not okw then
        safe_print("Paladin API: failed to write saved builds file: " .. tostring(err))
        return false, "write_failed"
    end

    safe_print("Paladin API: delete_profile -> success (profile removed and backup saved to " .. tostring(bak) .. ")")
    return true, "deleted"
end

-- Expose convenient globals for Dev Console
_G.Paladin_SaveProfile = api.save_profile
_G.Paladin_LoadProfile = api.load_profile
_G.Paladin_ListProfiles = api.list_profiles
_G.Paladin_DeleteProfile = api.delete_profile

return api