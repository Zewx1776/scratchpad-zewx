-- Add this to build_saver.lua or require it from main for a quick debug helper.
local M = _G.build_saver or {} -- if build_saver module exists, attach to it

function M.print_working_dir_debug()
  -- attempt to show the source file path for this chunk (may include full path prefixed by '@')
  local info = debug.getinfo(1, "S")
  console.print("debug.getinfo source: " .. tostring(info and info.source or "unknown"))

  -- check for paladin_import.txt in current working dir
  local f = io.open("paladin_import.txt", "r")
  if f then
    console.print("paladin_import.txt FOUND in working dir")
    f:close()
  else
    console.print("paladin_import.txt NOT FOUND in working dir")
  end
end

-- attach back so require("build_saver") can access it
_G.build_saver = M
return M