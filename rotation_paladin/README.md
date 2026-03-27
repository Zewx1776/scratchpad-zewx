# rotation_paladin

## Overview
This is a QQT Lua plugin for automating Paladin rotations in Diablo 4. It provides automatic spell rotation with a priority system, targeting modes, and extensive customization options.

## ⚠️ Implementation Status
This plugin provides the **structural framework** for a Paladin rotation system. The spell modules are **templates** that need to be completed with:
1. **Actual spell IDs** from the game (currently set to 0 as placeholders)
2. **Spell casting logic** specific to each ability
3. **Spell data parameters** (range, cast delay, projectile speed, etc.)

To complete the implementation, reference the Barbarian plugin's spell modules for examples of proper spell casting implementation.

## Features
- Automatic spell rotation with priority system
- Multiple targeting modes (cursor/player)
- Customizable spell settings per ability
- Profile management system for different builds
- Auto-play integration
- Evade system integration
- Visual overlays for target selection

## Installation
1. Place the `rotation_paladin` folder in your QQT scripts directory
2. Launch Diablo 4 and QQT loader
3. The plugin will load automatically
4. Configure settings in the in-game menu

## Configuration
Access the configuration menu in-game to:
- Enable/disable the plugin
- Choose targeting mode (cursor/player)
- Configure individual spells
- Adjust spell priorities
- Enable/disable specific abilities
- Manage build profiles

## Supported Abilities

### Basic Skills
- Holy Bolt - Basic ranged attack
- Clash - Melee attack
- Purify - Cleansing ability
- Basic Strike - Fallback attack

### Core Skills
- Blessed Shield - Shield throw attack
- Blessed Hammer - Spinning hammer attack
- Spear of the Heavens - Ranged spear attack
- Consecration - Ground AOE damage
- Falling Star - Meteor attack

### Defensive/Utility Skills
- Aegis - Defensive buff
- Fortress - Defensive stance
- Rally - Party buff

### Advanced Skills
- Advance - Mobility skill
- Zeal - Multi-hit attack
- Brandish - Weapon attack
- Wing Strikes - Angelic wings attack
- Arbiter of Justice - Judgment ability
- Judgement - Holy judgment
- Condemn - AOE damage
- Fist of the Heavens - Ultimate attack

### Auras
- Holy Light Aura - Healing aura
- Defiance Aura - Defensive aura
- Fanaticism Aura - Offensive aura

## Rotation Priority

The plugin follows this priority order:
1. Auras (Fanaticism → Defiance → Holy Light)
2. Defensive buffs (Aegis → Fortress → Rally)
3. High damage abilities (Fist of Heavens → Condemn → Consecration)
4. Core attacks (Falling Star → Blessed Hammer → Spear)
5. Special abilities (Judgement → Arbiter → Wing Strikes)
6. Basic attacks (Brandish → Zeal → Advance)
7. Filler skills (Blessed Shield → Holy Bolt → Clash)
8. Utility (Purify)
9. Fallback (Basic Strike)

## File Structure
```
rotation_paladin/
├── main.lua                        # Main rotation logic
├── README.md                       # This file
│
├── spells/                         # Spell implementations (templates)
│   ├── holy_bolt.lua
│   ├── blessed_shield.lua
│   ├── blessed_hammer.lua
│   ├── consecration.lua
│   ├── aegis.lua
│   ├── rally.lua
│   ├── fanaticism_aura.lua
│   └── ... (all spell files)
│
└── my_utility/                     # Utility functions
    ├── my_utility.lua              # Core utility functions
    └── my_target_selector.lua      # Target selection logic
```

## Usage Tips
- Start by enabling the plugin in the main menu
- Choose your preferred targeting mode (cursor for precision, player for auto-targeting)
- Enable the spells you want to use in your build
- The plugin will automatically prioritize and cast spells
- Use manual control when needed via keybinds
- Monitor console for spell cast feedback

## Targeting System
The plugin includes an intelligent targeting system that:
- Prioritizes bosses and elite enemies
- Considers champion and elite units
- Adjusts range based on auto-play mode
- Provides visual feedback for current target
- Supports both cursor-based and player-based targeting

## Auto-Play Integration
When auto-play is active:
- Extended range for spell casting (12.0 vs 8.5)
- Automatic movement toward enemies
- Increased screen range for target detection
- Optimized for autonomous gameplay

## Completing the Implementation

To finish implementing this plugin, you need to:

1. **Add Spell IDs**: Replace `spell_id = 0` in each spell module with the actual game spell ID
2. **Implement Spell Casting**: Add the actual casting logic in each spell's `logics()` function
3. **Configure Spell Data**: Set proper spell parameters (range, delay, geometry, etc.)
4. **Test Each Spell**: Verify each spell casts correctly in-game
5. **Tune Priorities**: Adjust the rotation priority order based on gameplay

Reference the `rotation_barbarian` plugin for implementation examples, particularly:
- `/rotation_barbarian/spells/bash.lua` - Good example of basic spell implementation
- `/rotation_barbarian/spells/hammer_of_ancients.lua` - Example of core damage spell

## Troubleshooting
- **Plugin not working:** Check if main toggle is enabled in menu
- **Spells not casting:** Verify spell IDs are correct and spell logic is implemented
- **No damage:** Ensure your damage spells are enabled in the menu
- **Wrong targeting:** Adjust targeting mode in the menu settings
- **Performance issues:** Disable unused spells to reduce overhead

## Technical Details
- Compatible with QQT Diablo Lua Plugin System
- Uses modular spell system for easy customization
- Implements safe error handling to prevent crashes
- Supports profile management for different builds

## Version
- Version: 1.0
- Last Updated: 2025-12-30
- Created by: Karnage
- Compatible with: QQT Diablo Lua Plugin System
- Status: Framework complete, spell implementations pending

## Credits
- Created by Karnage
- Based on Diablo 4 Paladin mechanics
- QQT Lua system by qqtnn

## Support
Join the Discord for support and updates: https://discord.gg/VE2gztW23q

## License
This plugin is provided as-is for use with the QQT Diablo platform.
