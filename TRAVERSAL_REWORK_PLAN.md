# Traversal Navigation — Full Audit & Rework Plan (Revised)

## Table of Contents
1. [Current Architecture Overview](#1-current-architecture-overview)
2. [How Traversals Work Today (Batmobile)](#2-how-traversals-work-today-batmobile)
3. [How ArkhamAsylum Uses Traversals](#3-how-arkhamasylum-uses-traversals)
4. [How HelltideRevamped Uses Traversals](#4-how-helltiderevamped-uses-traversals)
5. [Root Cause Analysis — Why Things Break](#5-root-cause-analysis)
6. [How piteertest-Main Handled Traversals (The Old Way That Worked)](#6-piteertest-analysis)
7. [Revised Rework — Path-Through Traversals](#7-revised-rework)
8. [Implementation Plan](#8-implementation-plan)

---

## 1. Current Architecture Overview

### Script Roles
| Script | Role | Traversal Involvement |
|--------|------|----------------------|
| **Batmobile** (`core/navigator.lua`) | Movement engine — pathfinding, traversal detection, interaction, escape | **Primary owner** of all traversal logic |
| **Batmobile** (`core/explorer.lua`) | Frontier-based BFS exploration (visited/frontier/backtrack) | **Zero traversal awareness** — picks flat 2D frontiers |
| **Batmobile** (`core/pathfinder.lua`) | A* pathfinding on walkable 2D grid | **Zero traversal awareness** — cannot route through elevation changes |
| **Batmobile** (`core/long_path.lua`) | Uncapped A* for long-range paths | Same 2D A* — no traversal awareness |
| **ArkhamAsylum** (`tasks/explore_pit.lua`) | Pit exploration, delegates to Batmobile | Clears traversal blacklist on stuck |
| **ArkhamAsylum** (`tasks/portal.lua`) | Portal detection + long_path navigation | Uses `get_closeby_node` for approach; no traversal routing |
| **ArkhamAsylum** (`tasks/kill_monster.lua`) | Enemy targeting + navigation | Skips enemies with Z > 5 diff; 12s unreachable timeout |
| **HelltideRevamped** (`tasks/helltide.lua`) | Full helltide state machine | Has its own traversal recovery, descent lock, prioritize-traversals toggle |
| **HelltideRevamped** (`core/helltide_explorer.lua`) | Zone-wide grid explorer | Returns intermediates for far nodes; no traversal awareness |

### Key Engine APIs Used
- `actors_manager:get_all_actors()` — scan for `Traversal_Gizmo` actors
- `utility.is_point_walkeable(pos)` — 2D walkability check (ignores elevation connections)
- `utility.set_height_of_valid_position(pos)` — snap position to valid ground Z
- `interact_object(actor)` — trigger traversal interaction (climb, jump, etc.)
- `get_buffs() → Player_Traversal` — detect active traversal animation
- `pathfinder.request_move(pos)` — low-level movement command

---

## 2. How Traversals Work Today (Batmobile)

### 2.1 Traversal Detection
**File:** `Batmobile-1.0.12/core/navigator.lua` lines 86-105

```lua
get_nearby_travs(local_player)
```
- Scans `actors_manager:get_all_actors()` for actors with skin name matching `[Tt]raversal_Gizmo`
- Results cached for 10ms (one frame) to avoid redundant scans
- Returns raw array of traversal actor objects

### 2.2 Traversal Selection (select_target)
**File:** `navigator.lua` lines 220-275

This is where traversal routing **begins and fails**. The function:

1. Calls `get_nearby_travs()` to find all traversal gizmos
2. Filters traversals by:
   - **Not blacklisted** (`navigator.blacklisted_trav[trav_str] == nil`)
   - **Within 15 units XY distance** (`utils.distance(player_pos, trav_pos) <= 15`)
   - **Within ±3 units Z** (`math.abs(closest_pos:z() - player_pos:z()) <= 3`) ← **CRITICAL FILTER**
   - **No active traversal** (`navigator.last_trav == nil`)
   - **Cooldown expired** (`navigator.trav_delay == nil or past`)
3. Sorts by Z-distance (`distance_z`) and picks the closest
4. Calls `get_closeby_node(trav_pos, 2)` to find a walkable approach tile near the gizmo
5. If no walkable approach → blacklists the traversal and recurses
6. Sets `navigator.last_trav = closest_trav` and returns the approach node as target

**CRITICAL PROBLEM:** Traversals are only selected **opportunistically** when the player happens to be within 15 XY units and ±3 Z units. There is **no intentional routing** to a traversal to reach a destination on a different elevation.

### 2.3 Traversal Interaction
**File:** `navigator.lua` lines 533-652 (inside `navigator.move()`)

When `navigator.last_trav` is set and player is within 3 units:

**Jump traversals** (`name:match('Jump')`):
- Calls `interact_object(trav)`
- Clears path, blacklists the jumped traversal + all traversals within 10 units (landing-side)
- Sets 4s `trav_delay` cooldown
- Computes an **escape point** 5-20 units away from the traversal (away from the gizmo direction)
- Stores `trav_escape_pos` and optionally `post_trav_target` (the original custom target to restore after escape)

**Non-jump traversals** (ladders, FreeClimb):
- Calls `interact_object(trav)`
- Sets 2s `trav_delay` cooldown immediately (buff can be too short to catch at 50ms polling)
- Clears path and target

**Traversal buff detected** (`Player_Traversal`):
- Blacklists the traversal + all within 10 units on landing side
- 4s cooldown
- Computes escape point, stores `trav_escape_pos`
- If `trav_final_target` was set → stores as `post_trav_target` for restoration after escape

### 2.4 Post-Traversal Escape
**File:** `navigator.lua` lines 699-727

After crossing, `navigator.trav_escape_pos` is set. The escape completes when:
- Player moves `TRAV_ESCAPE_DIST` (20) units from the crossing point, OR
- Player reaches the escape target (within 2 units)

Then restores `post_trav_target` if one was stored, or picks a new explorer target.

### 2.5 Buff-Missed Fallback
**File:** `navigator.lua` lines 654-697

If `last_trav` is still set after the 2s cooldown expired AND player moved > 8 units from the gizmo → the buff was never caught. Treats it as a successful crossing.

### 2.6 Traversal Routing on Pathfind Failure
**File:** `navigator.lua` lines 941-976

After 3 consecutive A* failures on a target:
1. Scans for non-blacklisted traversals within 30 units
2. Finds a walkable approach node via `get_closeby_node`
3. Sets `navigator.last_trav` to that traversal
4. If the navigator was paused (custom target from kill_monster), stores `trav_final_target` for restoration
5. Replaces current target with the approach node

**This is the ONLY "intentional" traversal routing** — but it only fires after 3 pathfind failures (each burning 200-600ms), and only looks for traversals within 30 units.

### 2.7 Blacklisting System
Traversals are keyed as `skin_name .. "x,y"` strings.

**When blacklisted:**
- After crossing (jump, buff, or buff-missed) — both source and all landing-side traversals within 10 units
- After failing to find a walkable approach node
- After the approach-node pathfind fails 3+ times

**When cleared:**
- `clear_traversal_blacklist()` — external API, clears all blacklists + failed_target
- When no traversals are visible at all (`#traversals == 0`) — blanket reset
- `reset_movement()` / `reset()` — full state wipe

### 2.8 The A* Pathfinder (pathfinder.lua)
**File:** `Batmobile-1.0.12/core/pathfinder.lua`

- Standard A* on a **flat 2D grid** with step size from `settings.step` (default 2 units)
- Checks `utility.is_point_walkeable()` for each neighbor
- Uses `utility.set_height_of_valid_position()` + Z tolerance to handle gentle slopes
- **Has zero concept of traversals** — a cliff edge is simply an unwalkable barrier
- Distance-scaled iteration/time limits (max 10k iter / 350ms for custom targets, 300ms for explorer)
- `find_path_debug` — uncapped variant (100k iter / 15s) used by `long_path.lua`

### 2.9 The Explorer (explorer.lua)
**File:** `Batmobile-1.0.12/core/explorer.lua`

- Frontier-based BFS: marks tiles within `radius` (12) as visited, tiles at `frontier_radius` (20) as frontier candidates
- `frontier_max_dist` (40) — max distance to target a frontier directly
- **Completely 2D** — frontiers are placed at current Z height
- When fronts exhausted → backtracks along the `backtrack` array
- Two priority modes: `direction` (maintain heading) and `distance` (furthest from spawn)
- **No awareness of traversals or elevation** — a frontier on a different Z level will be visited-marked but never pathable

---

## 3. How ArkhamAsylum Uses Traversals

### 3.1 explore_pit.lua
- Simply calls `BatmobilePlugin.resume/update/move` — all traversal handling delegated to Batmobile
- Speed mode: charges through packs, falls back to normal exploration
- **Stuck recovery** (line 138): after 5s stuck, calls `clear_traversal_blacklist()` + `reset_movement()`
- **No traversal-aware routing** — entirely dependent on Batmobile's opportunistic selection

### 3.2 portal.lua
- Detects `Portal_Dungeon` actors within `PORTAL_DETECTION_RADIUS` (25)
- Uses `BatmobilePlugin.get_closeby_node(portal_pos, 5)` to find walkable approach
- Calls `BatmobilePlugin.navigate_long_path(approach)` — uncapped A* to the approach point
- **Problem:** If the portal is on a different Z level (up a traversal), `navigate_long_path` A* will fail because it's 2D-only. The portal is marked unreachable and the bot stalls.
- Back-portal blacklisting: tracks spawn position to avoid re-entering the previous floor's portal

### 3.3 kill_monster.lua
- **Z-level filter** (line 64): `math.abs(player_pos:z() - enemy_pos:z()) > 5` → skip entirely
  - Comment: *"they're only reachable via a traversal, which the pathfinder can't model"*
- 12s unreachable timeout (longer than normal to account for traversal routing time)
- Uses either `navigate_long_path` or `set_target` depending on `settings.use_long_path`

---

## 4. How HelltideRevamped Uses Traversals

### 4.1 Prioritize Traversals Toggle
**File:** `helltide.lua` lines 918-963

- Optional scan (once/second) for `Traversal_Gizmo` actors within 30 units
- Filters by: Z-diff ≤ 3, not blacklisted, within range
- Enters `MOVING_TO_TRAVERSAL` state
- Uses its **own** blacklist (`trav_blacklist`) separate from Batmobile's
- After crossing: blacklists source + return traversals for 30s

### 4.2 MOVING_TO_TRAVERSAL State
**File:** `helltide.lua` lines 1208-1300

- Lets Batmobile route autonomously (`BatmobilePlugin.resume()`) — does NOT set the traversal as a custom target
- Monitors: Z-change > 2 OR got-close-then-dist > 20 → crossing confirmed
- 20s timeout → blacklist and return to EXPLORE_HELLTIDE
- **Problem:** Batmobile is resumed (free-roam), so it picks its own frontiers and may not even go toward the traversal

### 4.3 Traversal Recovery (try_traversal_recovery)
**File:** `helltide.lua` lines 434-519

Triggered when stuck in free-explore for `TRAVERSAL_RECOVERY_TIMEOUT` (5s):

1. Clears Batmobile's traversal blacklist
2. Scans all actors for traversals, classifies by Z-delta:
   - **Down-traversal**: player_z - trav_z > `TRAVERSAL_DESCENT_Z_DELTA` (2m), within 30 XY
   - **Any traversal**: nearest regardless of Z
3. If down-traversal found → **descent lock**:
   - Uses `get_closeby_node` for walkable approach
   - Sets Batmobile target to approach node
   - Monitors player Z drop; interacts when within 3 units
   - 15s timeout
4. If only same-level traversal → clears Batmobile target, lets `select_target()` route naturally
5. If no traversal → `reset_movement()`

### 4.4 Descent Lock
**File:** `helltide.lua` lines 240-283

Active during free-explore when `descent_actor ~= nil`:
- Keeps re-asserting the approach node as Batmobile target every 1s if it drifts
- Calls `interact_object` when within 3 units (1s cooldown)
- Completes on Z drop ≥ 3m or 15s timeout

### 4.5 navigate_to() — Stuck Detection
**File:** `helltide.lua` lines 179-407

- Wraps `BatmobilePlugin.set_target/update/move`
- Tracks stuck: if player hasn't moved > 5 units in 4s → `FREE_EXPLORE` mode
- In free-explore: Batmobile explores autonomously, traversal recovery triggers after 5s
- Exits free-explore when player moves > 15 units from stuck position
- Reassert-fail tracking: after 4 consecutive re-asserts with no progress → `helltide_explorer.report_intermediate_fail()`

### 4.6 helltide_explorer.lua
- Zone-wide grid (40m spacing, 200m expansion beyond waypoint bounds)
- Scores nodes by: unvisited = highest priority, then age/(dist + 50)
- Returns **intermediate steps** for far nodes (< 40m increments, walkable)
- Stuck timeout: 20s → fail count → permanently unreachable after 3 failures
- **No traversal awareness** — intermediates are straight-line XY projections; if a traversal is needed to reach a grid node, the node eventually becomes "unreachable"

---

## 5. Root Cause Analysis

### The Fundamental Problem
**The A* pathfinder operates on a flat 2D walkable grid. Traversals are vertical transitions (ladders, cliffs, jumps) that connect two walkable areas at different Z levels. The pathfinder cannot "see through" a traversal — it simply sees an unwalkable cliff edge and fails.**

This creates a cascade of failures:

### 5.1 Pit Layout Change Breakage
The game update changed pit layouts. With the new layouts:
- Floors now have more elevation changes and traversals connecting sections
- Explorer frontiers get placed on tiles across traversals (same XY area, different Z)
- A* fails → 3 failures → area blacklisted → frontiers wiped → exploration stalls
- Or: traversal routing fires → player crosses → escape phase → but now on wrong level → backtracks

### 5.2 Getting Stuck
**Sequence:**
1. Explorer picks a frontier across a traversal (or on a platform reached via traversal)
2. A* fails (unwalkable cliff)
3. After 3 failures: traversal routing fires → finds nearby traversal → approaches → interacts
4. Player crosses traversal → escape phase pushes player 20 units away
5. Now on new elevation: old frontiers are unreachable, new area hasn't been scanned
6. Explorer has no frontiers → backtracks → backtrack points are on OLD elevation → A* fails again
7. Bot is stuck oscillating between "try to backtrack" and "can't path there"

### 5.3 Backtracking
**Sequence:**
1. Player crosses traversal (either intentionally or opportunistically)
2. Escape phase completes → explorer scans new area → frontiers generated
3. But `backtrack` array still contains points from the old elevation
4. When current-area frontiers exhausted → backtrack kicks in → tries to path to old-elevation point
5. A* fails → blacklists area → wipes frontiers from the new elevation too
6. Eventually triggers exploration reset → loses ALL progress

### 5.4 Helltide — Going Up Traversals Unintentionally
**Sequence:**
1. Player is navigating to a chest/waypoint on flat ground
2. Path passes near a traversal gizmo (within 15 XY + ±3 Z)
3. `select_target()` sees the traversal, **overrides** the exploration target
4. Player climbs the traversal → ends up on a platform → original destination is now below
5. Batmobile explores the platform → stuck → traversal recovery → descent lock → eventually gets back down
6. Net result: player wasted 30-60 seconds going up and back down

### 5.5 Helltide — Not Going Up When Needed
**Sequence:**
1. `helltide_explorer` targets a grid node on a hilltop (needs traversal)
2. `navigate_to()` sets Batmobile target → A* fails (cliff)
3. Batmobile pathfind-failure handler tries traversal routing → but the traversal might be > 30 units away
4. Falls back to blacklisting → node marked as unreachable → explorer skips it
5. Entire hilltop area becomes permanently inaccessible

---

## 6. How piteertest-Main Handled Traversals (The Old Way That Worked)

### 6.1 Architecture — Traversals as a Separate Task, Not Part of Pathfinding

The old system (`piteertest-Main`) had a fundamentally different philosophy: **traversal interaction was a standalone high-priority task**, completely decoupled from pathfinding.

**Task priority order** (from `task_manager.lua` lines 54-72):
```
cheat_death → interact_shrine → move_to_cerrigar → enter_portal →
STUPID_LADDER → kill_boss → kill_monsters → ... → explore_pit
```

The `stupid_ladder` task runs **before** both `kill_monsters` and `explore_pit`. When a traversal is nearby, the task system naturally interrupts whatever the explorer is doing, handles the traversal, then resumes.

### 6.2 The `stupid_ladder.lua` Task

**shouldExecute()** (line 57-65):
- Finds any actor matching `[Tt]raversal` within Z ≤ 5 of player
- Only fires if `tracker.traversal_controller_reached == false`
- Also checks for `enums.misc.traversal_controller = "traversal_footprints_01_fxMesh"` — a visual indicator near traversals

**Execute()** (line 66-118):
```lua
-- If far from traversal: use explorer's A* to path to it
explorer:clear_path_and_target()
explorer:set_custom_target(target_pos)
explorer:move_to_target()

-- If close enough: force-move directly to gizmo position
pathfinder.force_move_raw(actor_pos)

-- If within 1 unit: interact
interact_object(traversal_actor)
tracker.traversal_controller_reached = true
```

**Key design:** The task simply paths to the traversal using the same explorer A* used for everything else. No special traversal pathfinding, no blacklisting, no escape phases.

### 6.3 kill_monsters.lua — Yields to Traversals

```lua
shouldExecute = function()
    local traversal_controller = utils.get_object_by_name(enums.misc.traversal_controller)
    if traversal_controller ~= nil then
        return false  -- Don't kill monsters if a traversal is nearby — let stupid_ladder handle it
    end
    ...
end
```

**No Z-level filtering at all** — enemies at any Z are targeted. The philosophy: if a traversal is needed, the task system will handle it.

### 6.4 enter_portal.lua — Simple Direct Pathing

```lua
explorer:clear_path_and_target()
explorer:set_custom_target(portal:get_position())
explorer:move_to_target()
-- Interact when within 7 units
```

No `get_closeby_node`, no `navigate_long_path`, no approach-node calculation. Just set the portal position as target and walk there. If a traversal is in the way, `stupid_ladder` fires first (higher priority).

### 6.5 The Explorer — `dist_to_ignore_z` Is the Secret Sauce

The critical difference in the old explorer (`piteertest-Main/piteer/core/explorer.lua`):

**All distance calculations use `dist_to_ignore_z`** (line 154-173):
```lua
local function calculate_distance(pos1, pos2)
    -- All cases return dist_to_ignore_z
    return pos1:dist_to_ignore_z(pos2:get_position())
    return pos1:dist_to_ignore_z(pos2)
end
```

This means:
1. **Target selection ignores Z** — an unexplored cluster across a traversal (different Z) is scored the same as one on the same level
2. **A* pathfinding ignores Z in distance** — the heuristic and g-score don't penalize Z differences
3. **Path waypoints are Z-snapped** via `set_height_of_valid_position()` — so they land on valid ground
4. When A* walks toward a destination across a cliff, it generates a **partial path** toward the cliff edge (the last walkable point before the unwalkable cliff), getting the player close enough to detect the traversal gizmo

**A* iteration limit: only 666** (vs Batmobile's 10,000). When it can't find a full path (cliff in the way), it **fails fast** and the explorer tries a closer target. No expensive spin-up.

**On A* failure:** Progressively reduces `max_target_distance` (60→90→100→125) and picks a new target. No blacklisting, no traversal routing, no complex recovery.

### 6.6 Circle-Based Exploration (Not Frontier BFS)

The old explorer uses **explored circles** (not Batmobile's frontier/visited/backtrack BFS):
- Player position is periodically added as an explored circle (radius 16)
- `find_central_unexplored_target()` scans a grid around the player, finds walkable+unexplored points, clusters them, and picks the center of the largest cluster
- When no unexplored points remain: switches to "explored mode" and navigates to distant explored circles to check for nearby unexplored areas

This is more resilient to Z-changes because circles are placed at the player's actual position (including post-traversal Z). After crossing a traversal, the player is at a new Z, and the area around them is unexplored → the explorer naturally targets it.

### 6.7 Why It Worked (Unreliably)

The flow for crossing a traversal was:
1. Explorer picks an unexplored target (ignoring Z → might be across a traversal)
2. A* generates a partial path toward the cliff edge (furthest walkable point in that direction)
3. Player walks along the partial path, gets close to the cliff
4. Traversal gizmo comes into detection range (~15 units from the actor)
5. `stupid_ladder` task fires (higher priority than explore), interrupts explorer
6. `stupid_ladder` paths to the gizmo, interacts, player crosses
7. On the new elevation: `stupid_ladder` marks `traversal_controller_reached = true`
8. Explorer resumes: current position is at new Z, area around is unexplored → picks new targets naturally
9. Portal/monster tasks can also fire since they have higher priority than explore

**Why it was "unreliable":**
- The 2D A* might not generate a path toward the cliff at all (might route away from it)
- With only 666 iterations, complex paths around obstacles might not be found
- No guarantee the partial path gets close enough for traversal detection
- `traversal_controller_reached` flag doesn't reset properly between traversals
- No mechanism to intentionally seek traversals when exploration stalls

---

## 7. Revised Rework — Path-Through Traversals

### Core Philosophy Change

**OLD plan (scrapped):** Pre-build a traversal graph with entry/exit pairs, compute composite paths through traversals before starting navigation.

**Problem:** We can't know traversal locations in advance. In helltide's large zones and pit's varying layouts, traversals are discovered dynamically. Caching exit positions is unreliable since each traversal is typically only used once.

**NEW plan:** Follow the old piteertest approach but fix its unreliability. The core loop is:

1. **Pick a far-away destination** (frontier, portal, chest) — Z-agnostic selection
2. **Path toward it as far as A* can reach** — partial path to cliff edge is fine
3. **Walk the partial path** — gets player close enough to discover traversals
4. **When traversal detected AND path is blocked:** cross it as an intentional step toward the destination
5. **After crossing: keep the original destination** — re-plan from new position, don't clear/escape
6. **Only backtrack if new plane is fully explored and no portal/target found**

### 7.1 Pathfinder Changes (`pathfinder.lua`)

**A. Return partial paths on failure instead of nil**

Currently, when A* exhausts its iterations or can't reach the goal, it returns `nil`. Instead, return the **best partial path** — the path to the node closest to the goal that was reached.

```lua
-- On A* failure (iteration limit or no path):
-- Instead of: return nil
-- Do: return reconstruct_path(came_from, best_node), false
-- Where best_node = the closed-set node with lowest heuristic to goal
```

This is the single most important change. It means:
- Explorer targets across a traversal → A* gets as close as it can → player walks to cliff edge → traversal detection kicks in
- No more "3 failures → blacklist → exploration stalls" cascade

**B. Use Z-tolerant heuristic**

The heuristic should not overly penalize Z differences. Use XY distance (or `dist_to_ignore_z`) as the heuristic, but keep Z-aware neighbor validation (`is_point_walkeable` already handles this). This lets A* "aim toward" a destination that's at a different Z level.

**C. Reduce iteration ceiling for faster fail+retry**

Consider reducing from 10k back toward the piteertest range (666-2000). Fewer iterations = faster failure = faster re-targeting = more responsive navigation. The partial-path return makes high iteration counts less necessary.

### 7.2 Navigator Changes (`navigator.lua`)

**A. Traversal crossing should preserve the destination**

Current behavior (bad):
```
trav_escape_pos = trav_pos           -- enters escape phase
navigator.target = escape_pt         -- replaces destination with escape point
navigator.path = {}                  -- clears the path
post_trav_target = original_target   -- stores original for later... maybe
```

New behavior:
```
-- After crossing a traversal:
-- 1. Do NOT set an escape target (or use a very short escape: 3-5 units, not 20)
-- 2. Keep the original destination (navigator.target stays the same)
-- 3. Clear the path (it was for the old elevation) but NOT the target
-- 4. Let the next update() cycle re-plan from the new position toward the same destination
-- 5. Blacklist only the traversal we just crossed (not everything within 10 units)
```

**B. Traversal selection should be destination-aware**

Current `select_target()` picks traversals opportunistically whenever one is within 15 units, regardless of whether the destination requires it.

New behavior:
```
-- Only select a traversal when:
-- 1. The current A* path to destination has FAILED (partial path returned), AND
-- 2. The traversal is roughly in the direction of the destination, AND  
-- 3. The traversal hasn't been recently crossed (simple cooldown, not aggressive blacklisting)
--
-- This prevents: "walking near a traversal → climbing it when we didn't need to"
```

**C. Remove or greatly reduce escape phase**

The 20-unit escape after crossing is the #1 cause of "bouncing back." After crossing:
- Move 3-5 units from the landing-side gizmo (just enough to not re-trigger it)
- Then immediately re-plan toward the original destination
- Do NOT set `trav_escape_pos` with a long escape target

**D. Reduce blacklisting aggressiveness**

Current: blacklists the crossed traversal + all gizmos within 10 units on the landing side.
New: blacklist ONLY the exact gizmo just crossed, with a short cooldown (10-15s, not permanent until cleared).

### 7.3 Explorer Changes (`explorer.lua`)

**A. Z-agnostic frontier scoring**

Frontiers should be scored by XY distance only, so that frontiers across a traversal are not deprioritized. Use `dist_to_ignore_z` or strip Z from the distance calculation in `select_node`.

**B. Partial-path awareness**

When the pathfinder returns a partial path (couldn't reach the frontier), the explorer should NOT immediately blacklist/skip that frontier. Instead:
- Walk the partial path to get as close as possible
- If a traversal is discovered near the end of the partial path → cross it
- After crossing, retry the same frontier from the new position
- Only mark the frontier as unreachable after N attempts with no progress (measured in XY distance to frontier)

**C. Z-aware backtracking**

Tag backtrack entries with the Z level they were recorded at. When selecting a backtrack target:
- Prefer backtrack points at the current Z level
- Don't attempt backtrack points at a significantly different Z unless all same-Z options are exhausted
- When backtracking to a different Z is attempted and fails → don't wipe current-Z frontiers

**D. Post-traversal exploration continuation**

After crossing a traversal and arriving at a new elevation:
- Immediately scan the new area for unexplored tiles
- If the new area has significant unexplored content → explore it first
- Keep the previous-elevation frontiers in a "deferred" list (don't delete them)
- Only return to deferred frontiers when the current elevation is fully explored

### 7.4 Consumer Script Changes

**ArkhamAsylum — portal.lua:**
- Use partial-path navigation: set portal as target, walk as far as A* can go, traversal detection will handle elevation changes
- Remove the `get_closeby_node` approach-node calculation — just target the portal position directly, let the pathfinder + navigator handle it
- Keep back-portal blacklisting (that's good)

**ArkhamAsylum — kill_monster.lua:**
- Relax the Z-filter: instead of `abs(Z) > 5 → skip`, use a larger threshold or remove it entirely
- If targeting an enemy across a traversal and A* returns a partial path, follow it — traversal detection may bridge the gap
- Increase the unreachable timeout to give traversal crossing time

**ArkhamAsylum — explore_pit.lua:**
- Minimal changes needed — just benefits from the Batmobile improvements

**HelltideRevamped — helltide.lua:**
- Remove/simplify `try_traversal_recovery()` — the improved navigator should handle traversals naturally
- Remove the descent lock machinery — if the player is on a platform, the partial-path approach will naturally path toward a down-traversal when the destination is below
- Simplify `MOVING_TO_TRAVERSAL` state — traversal crossing is now handled by Batmobile, not by the helltide state machine
- Keep the `navigate_to()` stuck detection but remove the traversal-specific recovery

**HelltideRevamped — helltide_explorer.lua:**
- Score grid nodes using XY distance only (already partially done with `dist_to`)
- Don't mark nodes as unreachable when A* fails — they may just need a traversal
- After traversal crossing, the grid node that was previously "stuck" may now be reachable

### 7.5 The Complete Flow (How It Should Work After Rework)

**Scenario: Portal on top of a hill with a traversal**

1. `portal.lua` detects portal at distance 30, Z +8 above player
2. Sets portal position as Batmobile target
3. Batmobile A* runs: can't find full path (cliff), returns **partial path** to cliff edge (closest walkable point toward portal XY)
4. Player follows partial path, arrives at cliff edge
5. `Traversal_Gizmo` detected within 15 units, **roughly in the direction of the portal** (destination-aware check)
6. Navigator selects traversal as a waypoint, paths to approach node
7. Player reaches gizmo → `interact_object` → crosses
8. Brief 3-unit escape from landing-side gizmo
9. **Original destination (portal) is still the target** — A* re-plans from new position
10. This time A* finds a path to the portal (same elevation now) → player walks to portal → interacts

**Scenario: Helltide exploration, traversal encountered while patrolling**

1. `helltide_explorer` targets grid node 80m away, at same Z
2. Batmobile A* finds a path, player follows it
3. Path happens to go near a traversal gizmo (within 15 units)
4. **Destination-aware check:** A* path to current target is succeeding → traversal is NOT selected (no need to climb)
5. Player walks past the traversal and continues to the grid node
6. ✅ No unintentional climbing

**Scenario: Pit exploration, everything on current level explored**

1. Explorer has no more frontiers at current Z
2. Explorer picks a frontier from deferred list (different Z)
3. A* returns partial path toward the frontier (cliff edge)
4. Player follows partial path, discovers traversal
5. Traversal is in direction of frontier → selected, crossed
6. New elevation: fresh unexplored area → explorer targets it
7. If portal found on new level → `portal.lua` takes over
8. If no portal and everything explored → explorer returns to deferred frontiers at old Z (may need to cross traversal back down)

---

## 8. Implementation Plan

### Phase 1: Partial-Path Returns (Batmobile `pathfinder.lua`)
**Priority: HIGHEST — this unblocks everything else**

- Modify `find_path()` and `find_path_debug()` to return partial paths on failure
- Track the best (closest-to-goal) node during A* search
- Return `path, true` on success, `partial_path, false` on failure
- Update all callers to handle the boolean return
- Switch heuristic to XY-only (ignore Z in distance estimation)

### Phase 2: Destination-Preserving Traversal Crossing (Batmobile `navigator.lua`)
**Priority: HIGH**

- After traversal crossing: keep original target, clear path only, re-plan next tick
- Reduce escape distance from 20 to 3-5 units
- Make `select_target()` destination-aware: only select traversals when path is failing AND traversal is toward destination
- Reduce blacklisting: only the exact crossed gizmo, short cooldown (10-15s)

### Phase 3: Explorer Z-Tolerance (Batmobile `explorer.lua`)
**Priority: HIGH**

- Use XY-only distance for frontier scoring
- Don't blacklist frontiers on A* failure (they may need a traversal)
- Z-partition backtrack entries
- Add deferred frontier list for different-Z frontiers

### Phase 4: Consumer Script Simplification
**Priority: MEDIUM**

- `portal.lua`: Remove approach-node calculation, use direct targeting
- `kill_monster.lua`: Relax Z-filter threshold
- `helltide.lua`: Strip traversal recovery/descent lock machinery
- `helltide_explorer.lua`: XY-only node scoring, remove unreachable marking on A* failure

### Risk Mitigation
- **Feature flag**: `settings.partial_path_enabled` toggle — when off, reverts to nil-on-failure behavior
- **Minimal changes first**: Phase 1 alone (partial paths) should improve behavior significantly even without other phases
- **No new files needed**: All changes are modifications to existing code
- **Backwards compatible**: Consumer scripts that check `path == nil` just need to also check the boolean
- **Performance**: Partial paths are computed from existing A* data (no extra computation)

---

## Key Functions Reference

### Batmobile navigator.lua
| Function | Line | Purpose |
|----------|------|---------|
| `get_nearby_travs()` | 86 | Scan actors for Traversal_Gizmo (cached 10ms) |
| `has_traversal_buff()` | 106 | Check Player_Traversal buff (cached 10ms) |
| `get_closeby_node()` | 124 | Find walkable approach node near a position |
| `compute_escape_target()` | 51 | Calculate post-traversal escape waypoint |
| `select_target()` | 221 | Pick next movement target (traversal or frontier) |
| `navigator.move()` | 514 | Main movement loop — traversal interaction, escape, pathing |
| `navigator.update()` | 395 | Update explorer, detect death/respawn |
| `navigator.set_target()` | 457 | External target API — handles mid-traversal protection |
| `navigator.reset_movement()` | 426 | Clear movement state, preserve exploration |
| `navigator.clear_target()` | 507 | Clear current target and path |

### Batmobile pathfinder.lua
| Function | Line | Purpose |
|----------|------|---------|
| `pathfinder.find_path()` | 142 | Distance-capped A* (main) |
| `pathfinder.find_path_debug()` | 235 | Uncapped A* (long_path) |
| `get_valid_neighbor()` | 73 | Check walkability of adjacent tile |
| `get_neighbors()` | 122 | Get all walkable neighbors of a tile |
| `heuristic()` | 57 | Octile distance heuristic |

### Batmobile explorer.lua
| Function | Line | Purpose |
|----------|------|---------|
| `explorer.update()` | 388 | Scan grid, mark visited/frontier |
| `explorer.select_node()` | 449 | Pick next exploration target |
| `select_node_direction()` | 248 | Direction-priority node selection |
| `select_node_distance()` | 167 | Distance-priority node selection |
| `get_perimeter()` | 83 | Get unvisited edge tiles around position |
| `restore_backtrack()` | 109 | Rebuild backtrack path for alternative frontiers |

### Batmobile external.lua (Public API)
| Function | Purpose |
|----------|---------|
| `pause/resume/reset/reset_movement` | Control navigation state |
| `move/update` | Drive the navigation loop |
| `set_target/clear_target` | Set/clear custom navigation target |
| `find_long_path/navigate_long_path/stop_long_path` | Uncapped A* pathfinding |
| `get_closeby_node` | Find walkable approach near a position |
| `clear_traversal_blacklist` | Clear all traversal blacklists |
| `get_target/get_path` | Query current state |
| `is_done/is_paused/is_long_path_navigating` | Status queries |

### HelltideRevamped helltide.lua
| Function | Line | Purpose |
|----------|------|---------|
| `navigate_to()` | 179 | Wrapped Batmobile navigation with stuck/free-explore fallback |
| `try_traversal_recovery()` | 434 | Clear blacklists, engage descent lock if stranded |
| `move_to_traversal()` | 1208 | MOVING_TO_TRAVERSAL state handler |
| `check_events()` | 860 | Priority dispatcher (chests > traversals > kill > events) |
| `reset_navigate_state()` | 410 | Clear all navigate_to tracking state |

### ArkhamAsylum
| File | Function | Purpose |
|------|----------|---------|
| `portal.lua` | `get_portal()` | Scan for Portal_Dungeon actors |
| `portal.lua` | `Execute()` | Long-path to portal approach node |
| `kill_monster.lua` | `get_closest_enemies()` | Filter enemies by Z ≤ 5 |
| `explore_pit.lua` | `Execute()` | Drive Batmobile + speed-mode charging |
