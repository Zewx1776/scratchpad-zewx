# RotationNecro_Dirty

# ONLY BLOODWAVE SETUP IS TESTED, IF YOU WANT TO USE OTHER SPELLS, YOU NEED TO UNCOMMENT THEM IN SPELL_PRIORITY.LUA AND CHANGE THEIR PRIORITY TO YOUR LIKING

# Default values are for this build:
# https://maxroll.gg/d4/build-guides/blood-wave-necromancer-guide

## Custom Spell Priority

The priority of spells can be adjusted by changing the sequence in spell_priority.lua file. Spells listed earlier in the sequence have higher priority. To modify the spell priority:

1. Open the spell_priority.lua file.
2. Reorder the entries in `spell_priority` list to match your desired priority.
3. Save the file.
4. Reload the script (Default: F5).

Note: This also reorders the spells in the UI. So you can check in-game if the priority is correct. If a spell is not visible, make sure the the name is correctly spelled and in the list.

## Changelog
### v1.1.1
- Reduced blood wave range to better hit targets
- Added support for Rathma's Vigor stacking
- Improved blood orb gathering logic (maybe no more stutter steps, slowdowns)

### v1.1.0
- Updated default settings
- Better infernal horde prioritization
- Smarter blood orb gathering
- Added support for metamorphosis aspect (now uses the correct evade dynamically)
- Fixed out of combat evade
- Better blood wave movement
- Decreased the frequency of blight casts for debuffing

### v1.0.0
- Initial release

## Settings

### Main Settings

- **Enable Plugin**: Toggles the entire plugin on/off.
- **Custom Melee Range**: Sets the custom melee range for the 'Melee Target' targeting mode (2-8 units).
- **Max Targeting Range**: Sets the maximum range for finding targets around the player (1-16 units).
- **Targeting Refresh Interval**: Sets the time between target refresh checks (0.1-1 seconds).
- **Cursor Targeting Radius**: Sets the area size for selecting targets around the cursor (0.1-6 units).
- **Enemy Evaluation Radius**: Sets the area size around an enemy to evaluate if it's the best target (0.1-6 units).

### Custom Enemy Weights

- **Enable Custom Enemy Weights**: Toggles custom weighting for enemy types.
- **Normal Enemy Weight**: Sets the weight for normal enemies (1-10).
- **Elite Enemy Weight**: Sets the weight for elite enemies (1-50).
- **Champion Enemy Weight**: Sets the weight for champion enemies (1-50).
- **Boss Enemy Weight**: Sets the weight for boss enemies (1-100).

### Debug Settings

- **Enable Debug**: Toggles debug features on/off.
- **Display Targets**: Shows visual indicators for different types of targets.
- **Display Max Range**: Draws a circle indicating the max targeting range.
- **Display Melee Range**: Draws a circle indicating the melee range.
- **Display Enemy Circles**: Draws circles around enemies.
- **Display Cursor Target**: Shows the cursor related targeting features.

## Spells

The plugin includes settings for various Necro spells. Each spell typically has the following options:

- Enable/Disable the spell
- Targeting mode
- Evaluation range
- Filter modes (Any Enemy, Elite & Boss Only, Boss Only)
- Minimum number of enemies for AoE spells
- Buff checking options

Spells tested:

- Blood Mist
- Corpse Explosion
- Blood Wave
- Evade
- Blight


Spells included:

- Blood Mist
- Bone Spear
- Bone Splinters
- Corpse Explosion
- Corpse Tendrils
- Decrepify
- Hemorrhage
- Reap
- Blood Lance
- Blood Surge
- Blight
- Sever
- Bone Prison
- Iron Maiden
- Bone Spirit
- Blood Wave
- Army of the Dead
- Bone Storm
- Raise Skeleton
- Golem Control
- Evade