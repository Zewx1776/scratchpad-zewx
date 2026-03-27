# Paladin Rotation Plugin — Claude Rules

## Project
QQT (Questing/Quality Tools) Diablo 4 rotation plugin for the Paladin class.
Written in Lua, injected into the game via the QQT framework.

## CRITICAL: API Rules
**Never invent or guess API calls.** Only use methods confirmed to exist in the codebase.

### Confirmed global APIs
- `get_local_player()` → player object or nil
- `get_player_position()` → position object or nil
- `get_cursor_position()` → position object or nil
- `get_time_since_inject()` → number (seconds since inject)
- `get_hash(string)` → hash value for menu element IDs
- `actors_manager.get_enemy_npcs()` → array of actor objects
- `pathfinder.request_move(position)` → bool
- `cast_spell.target(target, spell_data, bool)` → bool
- `cast_spell.self(spell_id, delay)` → bool
- `orbwalker.get_orb_mode()` → number (0 = inactive)
- `auto_play.is_active()` → bool
- `auto_play.get_objective()` → objective enum value
- `evade.is_dangerous_position(position)` → bool
- `utility.is_spell_on_bar(spell_id)` → bool

### Confirmed position methods
- `position:get_position()` → position
- `position:squared_dist_to_ignore_z(other_position)` → number
- `position:dist_to(other_position)` → number (use sparingly — computes sqrt)
- `position:get_extended(from_position, distance)` → position

### Confirmed actor methods
- `actor:get_position()` → position or nil
- `actor:is_enemy()` → bool
- `actor:is_elite()` → bool (may not exist on all actors — check with `actor.is_elite`)
- `actor:is_boss()` → bool (may not exist — check with `actor.is_boss`)
- `actor:is_champion()` → bool (may not exist — check with `actor.is_champion`)
- `actor:get_buffs()` → array of buff objects
- `buff:name()` → string

### Confirmed menu/UI constructors (create at module level, not per-frame)
- `tree_node:new(depth)` → tree node
- `checkbox:new(default_bool, hash)` → checkbox
- `slider_float:new(min, max, default, hash)` → float slider
- `slider_int:new(min, max, default, hash)` → int slider
- `combo_box:new(default_index, hash)` → dropdown
- `spell_data:new(radius, range, cast_delay, proj_speed, has_collision, spell_id, geometry, targeting)` → spell data

### Confirmed menu/UI methods
- `element:render(label, ...)` → renders element, may return selected value
- `element:get()` → current value
- `element:set(value)` → set value
- `tree_node:push(label)` → bool (opens tree node)
- `tree_node:pop()` → closes tree node

### Confirmed spell geometry / targeting enums
- `spell_geometry.rectangular`
- `targeting_type.targeted`

### Confirmed event callbacks
- `on_update(function() end)` — fires every frame
- `on_render(function() end)` — fires every render frame
- `on_render_menu(function() end)` — fires during menu render

### Confirmed console
- `console.print(string)` — print to console

### objective enum
- `objective.fight`

## Architecture

```
main.lua                    — entry point, on_update/on_render/on_render_menu
build_profiles.lua          — build definitions with enabled_spells + rotation_priority
my_utility/my_utility.lua   — is_action_allowed, is_spell_allowed, get_nearby_enemy_count
my_utility/my_target_selector.lua — get_target_list, get_target_selector_data, get_current_selected_position
spells/<name>.lua           — each spell: menu(), logics(target), get_enabled(), menu_elements table
```

### Spell module contract
Every spell module must export:
```lua
return {
    menu = function(),             -- renders ImGui tree node with settings
    logics = function(target),     -- returns true if cast was successful
    get_enabled = function(),      -- returns menu_elements.main_boolean:get()
    menu_elements = { main_boolean = ... }  -- required for apply_build()
}
```

### Build profile contract
Each build in `build_profiles.lua` must have:
- `enabled_spells` — ordered list of spell module names (strings matching keys in `spells/`)
- `rotation_priority` — map of spell_name → number (higher = fires first)
- `name` — display string

## Performance rules
- **Never create UI objects (`combo_box:new`, `tree_node:new`, etc.) inside per-frame callbacks.** Create at module level once.
- **Never rebuild sorted lists or priority lists inside `on_update` or `on_render`.** Cache them and invalidate only when state changes (e.g., build switch).
- **Prefer `squared_dist_to_ignore_z` over `dist_to`** for all range comparisons. Only use `dist_to` when you need the actual numeric distance for display.
- **Guard `math.sqrt` calls** behind a debug flag — never call sqrt unconditionally in the hot path.

## Memory rule
**Do not update memory files until the user has confirmed the implementation is working correctly.** After making code changes, wait for explicit feedback before writing to any memory system.

## Code conventions
- All spell files live in `spells/` and are loaded by name via `safe_require`
- Spell IDs are numeric constants defined at the top of each spell file
- `next_time_allowed_cast` is a module-level float per spell, updated after each successful cast
- `my_utility.is_spell_allowed(menu_boolean, next_time_allowed_cast, spell_id)` is the standard gate check
- Use `pcall` around any QQT API call that could fail (UI operations, casts)
- Use `squared_dist_to_ignore_z` for all distance comparisons in logic paths
