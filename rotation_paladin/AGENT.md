# Paladin Rotation Plugin — Agent Work Log

## Session: 2026-03-17 — Performance Overhaul

### What Was Done

#### Files deleted (orphaned)
- `hammerdin_build.lua` — `apply()` called `spells[name].set_enabled()` which doesn't exist in actual spell modules. Never loaded by anything.
- `blessed_hammer_build.lua` — Pure data file, never loaded. Superseded by `build_profiles.lua`.

#### `build_profiles.lua`
- Added module-level `_BUILD_ORDER` constant. `get_build_list()` now returns the constant instead of allocating a new table on every call. All callers (`get_build_display_names`, `get_build_id_by_index`) benefit automatically.

#### `my_utility/my_utility.lua`
- `get_nearby_enemy_count`: replaced `dist_to` (computes sqrt) with `squared_dist_to_ignore_z`, comparing against `max_range * max_range`. Eliminates one sqrt per enemy per frame.

#### `my_utility/my_target_selector.lua`
- `get_target_list`: same squared-distance fix as above.
- `get_current_selected_position`: moved `combo_box:new(0, get_hash("targeting_mode_dropdown_paladin"))` from inside the per-frame function to a module-level `_targeting_mode_combo`. Now just calls `:get()` per frame instead of allocating a new UI object.

#### `main.lua` (10 sub-fixes)
1. Removed `get_spell_priority()` — was doing 3 table lookups per spell per frame
2. Added `cached_priority_list = nil` module-level variable
3. `apply_build()` now rebuilds `cached_priority_list` (sorted by priority) at the end of each build switch and on startup
4. Added `sorted_spell_names` built once after spell loading — replaces per-frame sort in both menu render functions
5. `render_active_skills_menu` uses `sorted_spell_names` directly
6. `render_inactive_skills_menu` uses `sorted_spell_names` directly
7. Added `local debug_on` at start of `on_update` — guards expensive `math.sqrt` calls in debug prints
8. Fixed target priority order: was elite→boss→champion (champion wrongly won), now elite→champion→boss (boss correctly wins)
9. Replaced per-frame `spell_priority_list` build+sort+execute (~28 lines) with single loop over `cached_priority_list`
10. Removed redundant `move_timer2` — was calling `get_time_since_inject()` twice back-to-back with duplicate `>= can_move` check; now uses `move_timer`

---

## Known Issue: Target Flip / Opposing Movement

**Status: DIAGNOSED, NOT YET FIXED**

### Symptom
Player is sometimes forced to move in opposing directions rapidly — the target flips frame-to-frame, causing the rotation and movement system to disagree on which enemy to engage.

### Root Causes (in order of impact)

#### Cause 1 (PRIMARY) — Movement targets `closest_unit`, spells target `best_target`
**File:** `main.lua` lines 411-425

The auto-play movement block uses `target_selector_data.closest_unit` to determine where to walk. But `best_target` (used for all spell casts above it) may be a boss or elite on the opposite side of the player. Result: spells fire toward the boss, the pathfinder moves toward a normal mob in the other direction. Two systems fighting each other every frame.

**Fix:** Change line 414 from `target_selector_data.closest_unit` to `best_target`.

#### Cause 2 — Range edge oscillation (hysteresis missing)
**File:** `main.lua` lines 371-391

When `best_target` (e.g., a boss) is sitting exactly at `max_range` distance, it oscillates in/out of range each frame due to minor position updates. When in range: boss is the target. When just out: immediately falls back to `closest_unit`, which may be in a different direction. Next frame boss is back in range. Flip repeats.

**Fix:** Apply a hysteresis band — only fall back when distance exceeds `max_range * 1.15`. Once fallen back, only return to the priority target when it's clearly within range (< `max_range * 0.9`). Requires tracking a `_using_fallback` flag.

#### Cause 3 — No target persistence / sticky target
**File:** `main.lua` lines 324-358

`best_target` is recomputed from scratch every `on_update` tick. If two enemies are near-equidistant, floating-point variance in position updates causes `closest_unit` / `closest_elite` to flip between them every few frames. Each flip sends a spell and movement command in a different direction.

**Fix:** Add a sticky target with a minimum lock-on time (e.g., 0.5s). Only switch targets if: (a) current target is dead/nil, (b) a higher-priority target type appears (normal→elite, elite→boss), or (c) lock time has elapsed. This is the most robust fix but requires tracking `sticky_target` and `sticky_target_last_switch` at module level.

### Recommended Fix Order
1. **Fix Cause 1 first** — one-line change, highest impact, no risk
2. **Fix Cause 2** — medium complexity, eliminates range-edge oscillation
3. **Fix Cause 3** — most robust, eliminates all frame-to-frame flipping

---

## Observations / Notes

- `debug_print` on line 361 and 366-367 still call `debug_print()` (the old function that guards internally), not the new `debug_on` pattern. These are low-traffic paths (only hit when no target) so low priority, but could be unified.
- The `on_render` callback at lines 429-487 duplicates `get_target_list` + `get_target_selector_data` calls with a hardcoded range of 16.0. This work is already done in `on_update`. For now they're separate callbacks so sharing state would require module-level caching of `target_selector_data` — worth doing if render performance becomes an issue.
- `is_auto_play_enabled()` is called twice in `on_update` — once at line 299 (as `is_auto_play_active`) and again at line 411 (as `is_auto_play`). These are redundant; the second call can reuse the first result.
- Several spells (`holy_light_aura`, `defiance_aura`, `fanaticism_aura`) use `cast_spell.self(spell_id, 0.5)` — they don't need a valid `target` but still receive one from `call_logic_safe`. The `call_logic_safe` function validates target before calling logics, which is correct but means auras will silently skip if no enemy is present. This is probably fine for an aggressive rotation but worth noting.
- `hammerdin_build.lua` naming was confusing — `hammerdin` is not a recognized build ID in `build_profiles.lua` (the correct ID is `blessed_hammer_mekuna`). The confusion came from having both files. Now resolved by deletion.

---

## Pending / Future Work
- [ ] Fix target flip Cause 1: align movement target with `best_target`
- [ ] Fix target flip Cause 2: add range hysteresis
- [ ] Fix target flip Cause 3: add sticky target with lock-on time
- [ ] Deduplicate `is_auto_play_enabled()` call in `on_update`
- [ ] Consider caching `target_selector_data` at module level to share between `on_update` and `on_render`
- [ ] Unify remaining `debug_print` calls to use the `debug_on` pattern
