# Paladin Spell ID Reference

This document provides the actual Paladin spell IDs configured in the rotation plugin.

## Configured Spell IDs

All spell files have been updated with the following actual game spell IDs:

### Core Build Spells (Original 6)

| Spell Name | Spell ID | File | In-Game Ability |
|------------|----------|------|-----------------|
| Holy Light Aura | `2297097` | `holy_light_aura.lua` | Holy Light Aura |
| Spear of the Heavens | `2100457` | `spear_of_the_heavens.lua` | Spear of the Heavens |
| Fist of the Heavens | `2273081` | `fist_of_the_heavens.lua` | Heaven's Fury |
| Judgement | `2297125` | `judgement.lua` | Arbiter of Justice |
| Wing Strikes | `2265693` | `wing_strikes.lua` | Brandish |
| Basic Strike | `2120228` | `basic_strike.lua` | Divine Lance |

### Additional Paladin Spells (All Implemented)

| Spell Name | Spell ID | File | Description |
|------------|----------|------|-------------|
| Advance | `2329865` | `advance.lua` | Movement ability |
| Aegis | `2292204` | `aegis.lua` | Defense ability |
| Arbiter of Justice | `2297125` | `arbiter_of_justice.lua` | AOE judgement ability |
| Blessed Hammer | `2107555` | `blessed_hammer.lua` | Hammer attack |
| Blessed Shield | `2082021` | `blessed_shield.lua` | Shield ability |
| Brandish | `2265693` | `brandish.lua` | Fast melee strikes |
| Clash | `2097465` | `clash.lua` | Combat ability |
| Condemn | `2226109` | `condemn.lua` | AOE damage |
| Consecration | `2283781` | `consecration.lua` | Ground AOE |
| Defiance Aura | `2187578` | `defiance_aura.lua` | Defensive aura |
| Falling Star | `2106904` | `falling_star.lua` | Ranged attack |
| Fanaticism Aura | `2187741` | `fanaticism_aura.lua` | Offensive aura |
| Fortress | `2301078` | `fortress.lua` | Defense ability |
| Holy Bolt | `2174078` | `holy_bolt.lua` | Projectile attack |
| Purify | `2261380` | `purify.lua` | Cleanse ability |
| Rally | `2303677` | `rally.lua` | Support ability |
| Zeal | `2132824` | `zeal.lua` | Fast attack ability |

## Total Spells: 23

All Paladin abilities are now fully implemented and integrated into the rotation system!

## How to Add New Spells

## Rotation Priority

The plugin uses the following rotation priority (all spells disabled by default except core 6):

1. **Auras** - Fanaticism Aura, Defiance Aura, Holy Light Aura
2. **Defensive** - Aegis, Fortress, Rally
3. **AOE Damage** - Fist of Heavens, Condemn, Consecration, Falling Star, Blessed Hammer
4. **Ranged** - Spear of Heavens, Judgement, Arbiter of Justice
5. **Melee** - Wing Strikes, Brandish, Zeal
6. **Movement** - Advance
7. **Single Target** - Blessed Shield, Holy Bolt, Clash
8. **Support** - Purify
9. **Filler** - Basic Strike

Users can enable/disable any spell through the in-game menu to customize their rotation.

## Spell ID Source

All spell IDs provided by @Karnage8i2 from in-game discovery tools.

## Notes

- All IDs are for Spiritborn (character_id: 6) abilities
- These are the actual in-game spell IDs for Diablo 4
- IDs may change with game patches/updates
- All spells are disabled by default except the original 6 core build spells
- Enable spells in the in-game menu based on your build preferences
- Test each spell to ensure proper functionality

## Version

- Last Updated: 2025-12-29
- Plugin Version: 1.3
- Game Version: Diablo 4 with Vessel of Hatred
- Total Implemented Spells: 23
