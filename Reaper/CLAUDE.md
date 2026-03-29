# Reaper — Diablo Boss Farmer

## Project structure

Reaper is a standalone boss-farming plugin. It integrates with **Batmobile-1.0.12** for in-dungeon navigation.

```
Reaper/
  main.lua              — plugin entry, update loop
  gui.lua               — UI elements + boss icon pixel coords + overlay crosshairs
  core/
    settings.lua        — runtime settings (synced from gui each frame)
    boss_rotation.lua   — builds run queue from materials + sigils, tracks current boss
    navigate_to_boss.lua — state machine: teleport → map-click → walk to altar
    map_nav.lua         — waypoint teleport → walk to stone → open map → click boss icon → wait zone
    pathwalker.lua      — walks a recorded path (array of vec3 points)
    materials.lua       — scans materials + sigils from inventory; SIGIL_DISPLAY_MAP here
    tracker.lua         — session kill counts, altar_activated flag, just_revived
    task_manager.lua    — task priority list
    utils.lua           — get_zone, get_altar, get_dungeon_entrance, distance helpers
    d4a_command.lua     — writes command.txt (UNUSED — switched to mouse clicks)
  data/
    enums.lua           — altar names, boss_zones, boss_room seed positions, waypoint IDs
  paths/
    harbinger_a.lua, harbinger_b.lua, ...  — recorded vec3 paths per boss variant
  tasks/
    navigate_to_boss.lua  — main navigation task (see below)
    interact_altar.lua    — finds and interacts with the boss altar
    kill_monsters.lua     — kills enemies during boss fight
    open_chest.lua        — opens reward chest after kill
    sigil_complete.lua    — cleans up after sigil run
```

## Navigation architecture

**All navigation uses mouse clicks — D4A is disabled.**

- `use_d4a = false` (default)
- `use_sigil_clicks = true` (default)

### Material runs (non-sigil)
`IDLE → MAP_NAV → PATHWALKING → LONG_PATHING`

1. `map_nav.start(boss_id)` — teleport to anchor waypoint (nevesk or zarbinzet), walk to waypoint stone, open map, click boss icon, wait for zone load
2. `PATHWALKING` — calls `BatmobilePlugin.navigate_long_path(label, seed_pos)` to navigate to altar area
3. `LONG_PATHING` — waits for Batmobile long-path to complete
4. Falls back to `EXPLORING` if long path fails (traversal blocking)

### Sigil runs — known boss (harbinger, grigoire, etc.)
`IDLE → USE_SIGIL → CONFIRM_SIGIL → MAP_NAV → PATHWALKING → LONG_PATHING`

After sigil confirmed, `map_nav.start(boss_id)` navigates same as material runs.

### Sigil runs — unknown boss (sigil_generic)
`IDLE → USE_SIGIL → CONFIRM_SIGIL → WALKING → ENTERING`

No map click possible (unknown dungeon). After sigil confirmed, immediately look for the dungeon entrance portal that spawns nearby and walk into it.

## Boss anchor waypoints (map_nav.lua)
- **Nevesk**: grigoire, beast, zir, varshan, belial, andariel, duriel, butcher
- **Zarbinzet**: urivar, harbinger

## Boss room seed positions (enums.lua → boss_room table)
Required so `navigate_long_path` knows where to aim inside the dungeon.
Currently defined: zir, duriel, grigoire, andariel, beast, varshan, **harbinger** (added 2026-03-28).
Missing: urivar (needs in-dungeon coordinate capture).

## SIGIL_DISPLAY_MAP (materials.lua)
Maps sigil display name substrings → boss_id. Currently missing:
All 9 bosses mapped (confirmed 2026-03-28):
- duriel    → "Gaping Crevasse"
- butcher   → "The Broiler"
- zir       → "Ancient's Seat"
- varshan   → "Malignant Burrow"
- grigoire  → "Hall of the Penitent"
- urivar    → "Fields of Judgement"
- beast     → "Glacial Fissure"
- andariel  → "Hanged Man's Hall"
- harbinger → "Harbinger's Den"

When those names are captured from console, add entries to `SIGIL_DISPLAY_MAP`.

## Boss icon pixel positions (gui.lua)
Default pixel coords at 1920×1080. Calibrate via "Boss Icon Alignment" section in GUI.
- Nevesk group: grigoire, beast, varshan, belial, andariel, duriel, butcher, zir
- Zarbinzet group: urivar, harbinger

## Key state machine states (navigate_to_boss.lua)
| State | Purpose |
|-------|---------|
| IDLE | Decide first step |
| USE_SIGIL | use_item(sigil) |
| CONFIRM_SIGIL | confirm_sigil_notification(), branch to MAP_NAV or WALKING |
| MAP_NAV | map_nav state machine (teleport → walk → map click → zone wait) |
| PATHWALKING | Fire BatmobilePlugin.navigate_long_path to boss room seed |
| LONG_PATHING | Wait for Batmobile long-path to complete |
| EXPLORING | Batmobile normal nav while retrying long path (traversal recovery) |
| WALKING | Walk to dungeon entrance portal (sigil_generic only) |
| ENTERING | Interact with portal to enter dungeon |

## Debugging
- All console.print calls are intentional — do not remove them
- Log prefix: `[Reaper]`, `[MapNav]`, `[LONG PATH]`, `[nav]`
- User provides log files for diagnosis; work log-driven
- `logzewx.txt` is the active log file in the scripts root

## Pending / needs in-game data
- SIGIL_DISPLAY_MAP entries for andariel, urivar, butcher sigils (capture from `[Reaper] Sigil UNMAPPED:` console output)
- Boss room seed position for urivar (capture in-dungeon coordinate)
- Calibrate harbinger + urivar boss icon pixel coords if user's resolution ≠ 1920×1080
