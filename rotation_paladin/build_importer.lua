-- Build Importer (updated for your skill list + typo variants)
-- Best-effort parser for pasted build text from Maxroll / D4Build / Mobalytics or plain lists
-- Usage: local importer = require("build_importer"); local skills = importer.parse_import_text(text)

local function safe_require(name)
    local ok, mod = pcall(require, name)
    if not ok then
        if console and console.print then console.print("Warning: optional module '" .. tostring(name) .. "' not found; continuing") end
        return nil
    end
    return mod
end

local M = {}

-- Expanded mapping including the skills you provided and common variants/typos
local name_map = {
    -- User-provided skills
    ["fallen star"] = "fallen_star",
    ["Fallen Star"] = "fallen_star",
    ["fallen_star"] = "fallen_star",

    ["defiance aura"] = "defiance_aura",
    ["Defiance Aura"] = "defiance_aura",
    ["defiance_aura"] = "defiance_aura",

    -- user typo + correct spelling
    ["fantacism aura"] = "fanaticism_aura", -- typo fix
    ["fanTacism aura"] = "fanaticism_aura",
    ["fanaticism aura"] = "fanaticism_aura",
    ["Fanaticism Aura"] = "fanaticism_aura",
    ["fanaticism_aura"] = "fanaticism_aura",

    ["rally"] = "rally",
    ["Rally"] = "rally",
    ["rallying cry"] = "rally",
    ["Rallying Cry"] = "rally",
    ["rallying_cry"] = "rally",

    ["blessed hammer"] = "blessed_hammer",
    ["Blessed Hammer"] = "blessed_hammer",
    ["blessed_hammer"] = "blessed_hammer",

    ["holy light aura"] = "holy_light_aura",
    ["Holy Light Aura"] = "holy_light_aura",
    ["holy_light_aura"] = "holy_light_aura",

    -- keep previous helpful entries (safe to have)
    ["BlessedHammer"] = "blessed_hammer",
    ["to_blessed_hammer"] = "blessed_hammer",
    ["Spear of the Heavens"] = "spear_of_the_heavens",
    ["Judgement"] = "judgement",
    ["Judgment"] = "judgement",
    ["to_core_skills"] = "core_skills",
}

local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- Normalize a candidate skill name and map to internal key if possible
local function map_name_to_key(name)
    if not name then return nil end
    name = trim(name)
    if name == "" then return nil end

    -- direct map (case-sensitive)
    if name_map[name] then return name_map[name] end

    -- case-insensitive match
    local lower = name:lower()
    for k, v in pairs(name_map) do
        if k:lower() == lower then return v end
    end

    -- remove punctuation/whitespace and try simplified match
    local simple = name:gsub("%W", ""):lower()
    for k, v in pairs(name_map) do
        local ks = k:gsub("%W", ""):lower()
        if ks == simple then return v end
    end

    -- token-style 'to_foo_bar' detection
    local token = string.match(name, "to_[%w_]+")
    if token and name_map[token] then return name_map[token] end
    if token then
        local inferred = token:gsub("^to_", "")
        return inferred
    end

    -- fallback: convert spaces to underscores and return that
    local candidate = name:gsub("%s+", "_"):gsub("[^%w_]", ""):lower()
    return candidate
end

-- Try to extract quoted strings or JSON array of strings
local function extract_quoted_strings(s)
    local out = {}
    for q in string.gmatch(s, '"([^"]+)"') do
        table.insert(out, q)
    end
    return out
end

-- Split by comma or newline
local function split_comma_newline(s)
    local out = {}
    for part in string.gmatch(s, "([^,\n\r]+)") do
        table.insert(out, trim(part))
    end
    return out
end

-- Extract tokens like to_blessed_hammer
local function extract_tokens(s)
    local out = {}
    for token in string.gmatch(s, "to_[%w_]+") do
        table.insert(out, token)
    end
    return out
end

-- Public: parse import text and return list of internal skill keys (array)
function M.parse_import_text(s)
    if not s or s == "" then return {} end

    local results = {}

    -- Heuristic 1: quoted strings
    local quoted = extract_quoted_strings(s)
    if #quoted > 0 then
        for _, name in ipairs(quoted) do
            local key = map_name_to_key(name)
            if key then table.insert(results, key) end
        end
        if #results > 0 then return results end
    end

    -- Heuristic 2: JSON-style array
    local arr = string.match(s, "%[(.-)%]")
    if arr then
        for item in string.gmatch(arr, '([^,]+)') do
            local cleaned = item:gsub('^%s*"', ''):gsub('"%s*$', ''):gsub("^%s*", ""):gsub("%s*$", "")
            local key = map_name_to_key(cleaned)
            if key then table.insert(results, key) end
        end
        if #results > 0 then return results end
    end

    -- Heuristic 3: comma/newline separated values
    local parts = split_comma_newline(s)
    if #parts > 0 then
        for _, p in ipairs(parts) do
            if p and p ~= "" then
                local key = map_name_to_key(p)
                if key then table.insert(results, key) end
            end
        end
        if #results > 0 then return results end
    end

    -- Heuristic 4: token scanner
    local tokens = extract_tokens(s)
    if #tokens > 0 then
        for _, tok in ipairs(tokens) do
            local key = map_name_to_key(tok)
            if key then table.insert(results, key) end
        end
        if #results > 0 then return results end
    end

    -- Heuristic 5: scan known display names anywhere
    for display, key in pairs(name_map) do
        if string.find(s:lower(), display:lower(), 1, true) then
            table.insert(results, key)
        end
    end

    -- Deduplicate while preserving order
    local seen = {}
    local deduped = {}
    for _, k in ipairs(results) do
        if k and not seen[k] then
            seen[k] = true
            table.insert(deduped, k)
        end
    end

    return deduped
end

return M