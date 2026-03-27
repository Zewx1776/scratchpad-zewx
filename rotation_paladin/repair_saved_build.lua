-- repair_saved_builds.lua
-- Safe helper: backup and remove paladin_saved_builds.lua so corrupted saved-build entries are discarded.
-- Usage:
-- 1) Save this file in your addon folder (same as main.lua)
-- 2) In Developer Console run: require("repair_saved_builds")
--    OR temporarily add require("repair_saved_builds") to main.lua and reload the addon once.
-- 3) After it runs, remove the file and any require() you added.

local function safe_print(msg)
    if type(console) == "table" and console.print then
        pcall(console.print, tostring(msg))
    else
        pcall(print, tostring(msg))
    end
end

local SAVE_FILE = "paladin_saved_builds.lua"
local BACKUP_FILE = "paladin_saved_builds.lua.bak"

local function backup_and_remove()
    -- Attempt to back up the file first
    local ok, err = pcall(function()
        -- If backup already exists, add a timestamp suffix
        local bak = BACKUP_FILE
        local f = io.open(SAVE_FILE, "r")
        if not f then
            safe_print("repair_saved_builds: no saved builds file found (" .. SAVE_FILE .. ") - nothing to do")
            return
        end
        f:close()
        -- Try to remove any previous .bak to avoid rename failure
        local _ = os.remove(bak)
        local renamed_ok = os.rename(SAVE_FILE, bak)
        if renamed_ok then
            safe_print("repair_saved_builds: backed up and removed saved builds file. Backup: " .. bak)
        else
            -- Fallback: try to copy contents then delete original
            local fin = io.open(SAVE_FILE, "r")
            if fin then
                local content = fin:read("*a")
                fin:close()
                local fout = io.open(bak, "w")
                if fout then
                    fout:write(content)
                    fout:close()
                    os.remove(SAVE_FILE)
                    safe_print("repair_saved_builds: backed up and removed saved builds file (fallback copy). Backup: " .. bak)
                else
                    safe_print("repair_saved_builds: failed to create backup file: " .. tostring(bak))
                end
            else
                safe_print("repair_saved_builds: failed to open original file for fallback copy")
            end
        end
    end)
    if not ok then
        safe_print("repair_saved_builds: error: " .. tostring(err))
    end
end

backup_and_remove()
return {}