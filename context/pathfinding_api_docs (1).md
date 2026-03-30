# Pathfinding API Documentation

## Overview

The pathfinding API provides nav mesh-based pathfinding for Diablo IV. It uses the game's internal nav mesh to determine walkable terrain, then runs a custom A* algorithm to find paths that avoid walls, structures, and impassable terrain.

## World Methods

### `world:is_movable_position(pos)`

Checks whether a given world position is on walkable nav mesh terrain.

**Parameters:**
- `pos` (`vec3`) — The world position to check.

**Returns:** `boolean` — `true` if the position is walkable, `false` otherwise.

**Example:**
```lua
local world = get_current_world()
local target = vec3(-1420.0, 165.0, 101.0)

if world:is_movable_position(target) then
    console.print("Position is walkable")
else
    console.print("Position is blocked")
end
```

---

### `world:calculate_path(start, finish)`

Calculates a walkable path between two world positions using A* pathfinding on the game's nav mesh. Automatically resolves heights for both positions and avoids walls, structures, and impassable terrain.

**Parameters:**
- `start` (`vec3`) — The starting world position (typically player position).
- `finish` (`vec3`) — The destination world position.

**Returns:** `table` of `vec3` — An ordered list of waypoints from start to finish. Returns an empty table if no path is found.

**Notes:**
- Maximum path range is 150 world units.
- Grid resolution is 0.5 world units per cell.
- Heights are automatically resolved via the nav mesh. Positions do not need exact Z values.
- Paths will not cross between different elevation floors (5 unit height tolerance).
- The returned path is simplified — collinear waypoints are removed for cleaner movement.

**Example:**
```lua
local world = get_current_world()
local player = get_local_player()
local player_pos = player:get_position()
local target_pos = vec3(-1410.0, 155.0, 101.0)

local path = world:calculate_path(player_pos, target_pos)
if #path > 0 then
    console.print(string.format("Path found with %d waypoints", #path))
    for i, wp in ipairs(path) do
        console.print(string.format("  [%d] (%.1f, %.1f, %.1f)", i, wp:x(), wp:y(), wp:z()))
    end
else
    console.print("No path found")
end
```

---

### `world:set_height_of_valid_position(pos)`

Resolves the Z (height) component of a position by searching upward on the nav mesh. Modifies the input `vec3` in-place.

**Parameters:**
- `pos` (`vec3`) — The position to resolve. Z is modified in-place.

**Example:**
```lua
local world = get_current_world()
local pos = vec3(-1420.0, 165.0, 0.0) -- unknown height
world:set_height_of_valid_position(pos)
console.print(string.format("Resolved height: %.2f", pos:z()))
```

---

### `world:get_world_id()`

Returns the current world's unique identifier.

**Returns:** `number` — The world ID.

---

### `world:get_name()`

Returns the current world/level name.

**Returns:** `string` — The world name.

---

### `world:get_current_zone_name()`

Returns the current zone/subzone name.

**Returns:** `string` — The zone name.

---

## Global Functions

### `get_current_world()`

Returns the current world instance.

**Returns:** `world` or `nil` — The current world object.

**Example:**
```lua
local world = get_current_world()
if world then
    console.print("World: " .. world:get_name())
end
```

---

## Typical Usage Pattern

```lua
local function move_along_path(path)
    if #path < 2 then return end

    local player = get_local_player()
    local player_pos = player:get_position()

    -- Find the next waypoint that we haven't reached yet
    for i, wp in ipairs(path) do
        local dist = player_pos:dist_to(wp)
        if dist > 1.0 then
            -- Move toward this waypoint
            -- (use your movement API here)
            return wp
        end
    end

    return nil -- path complete
end

-- Calculate path on keypress, then follow it
local path = {}

on_update(function()
    local world = get_current_world()
    local player = get_local_player()
    if not world or not player then return end

    -- Recalculate on some condition
    if should_recalculate then
        local target = get_cursor_position()
        path = world:calculate_path(player:get_position(), target)
    end

    -- Follow the path
    if #path > 0 then
        local next_wp = move_along_path(path)
        if not next_wp then
            path = {} -- done
        end
    end
end)
```

---

