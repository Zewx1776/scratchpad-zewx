# All Paladin Builds - Configuration Overview

## Build Presets

This document provides quick configuration presets for all five Paladin builds supported by this plugin.

---

## 1. Auradin (Holy Light Aura) Build 🌟

**Focus:** AOE holy damage through auras  
**Playstyle:** Close to mid-range, sustain damage  
**Reference:** [Mobalytics Auradin Build](https://mobalytics.gg/diablo-4/builds/auradin-holy-light-aura-paladin)

### Enable These Spells:
- ✅ Holy Light Aura
- ✅ Basic Strike
- ⚪ Fist of the Heavens (optional)

### Recommended Settings:
```
Holy Light Aura:
  - Spell Range: 8.0
  - Min Enemies: 3

Basic Strike:
  - Spell Range: 3.0
  
Targeting Mode: Player
```

**Quick Guide:** See [AURADIN_QUICKSTART.md](AURADIN_QUICKSTART.md)

---

## 2. Spear of the Heavens Build ⚡

**Focus:** Ranged divine spear attacks  
**Playstyle:** Long-range, kiting  
**Reference:** [Mobalytics Spear Build](https://mobalytics.gg/diablo-4/builds/spear-of-the-heavens-paladin)

### Enable These Spells:
- ✅ Spear of the Heavens
- ✅ Basic Strike
- ⚪ Judgement (optional)

### Recommended Settings:
```
Spear of the Heavens:
  - Spell Range: 12.0
  - Min Enemies: 2

Basic Strike:
  - Spell Range: 3.0
  
Targeting Mode: Cursor (for precision)
```

**Quick Guide:** See [SPEAR_QUICKSTART.md](SPEAR_QUICKSTART.md)

---

## 3. Judgement Lawkuna Build ⚖️

**Focus:** Powerful judgement AOE  
**Playstyle:** Mid-range, burst damage  
**Reference:** [Mobalytics Judgement Build](https://mobalytics.gg/diablo-4/builds/judgement-lawkuna-paladin)

### Enable These Spells:
- ✅ Judgement
- ✅ Basic Strike
- ⚪ Holy Light Aura (optional)

### Recommended Settings:
```
Judgement:
  - Spell Range: 10.0
  - Min Enemies: 2

Basic Strike:
  - Spell Range: 3.0
  
Targeting Mode: Player or Cursor
```

---

## 4. Fist of the Heavens Build 👊

**Focus:** Lightning/holy AOE burst  
**Playstyle:** Mid-range, grouped enemies  
**Reference:** [Mobalytics Fist Build](https://mobalytics.gg/diablo-4/builds/fist-of-the-heavens-paladin)

### Enable These Spells:
- ✅ Fist of the Heavens
- ✅ Basic Strike
- ⚪ Spear of the Heavens (optional)

### Recommended Settings:
```
Fist of the Heavens:
  - Spell Range: 12.0
  - Min Enemies: 3

Basic Strike:
  - Spell Range: 3.0
  
Targeting Mode: Player
```

---

## 5. Wing Strikes Build 🦅

**Focus:** Fast melee wing attacks  
**Playstyle:** Close-range, mobile  
**Reference:** [Mobalytics Wing Strikes Build](https://mobalytics.gg/diablo-4/builds/wing-strikes-paladin)

### Enable These Spells:
- ✅ Wing Strikes
- ✅ Basic Strike
- ⚪ Judgement (optional gap closer)

### Recommended Settings:
```
Wing Strikes:
  - Spell Range: 6.0
  - Min Enemies: 2

Basic Strike:
  - Spell Range: 3.0
  
Targeting Mode: Player
```

---

## Hybrid Builds

You can create hybrid builds by enabling multiple abilities:

### Balanced All-Rounder
```
Enable:
- Holy Light Aura (Min Enemies: 3)
- Spear of the Heavens (Min Enemies: 2)
- Wing Strikes (Min Enemies: 2)
- Basic Strike

Rotation: Aura → Spear → Wing → Basic
```

### Ranged Heavenly Barrage
```
Enable:
- Spear of the Heavens (Min Enemies: 2)
- Fist of the Heavens (Min Enemies: 3)
- Judgement (Min Enemies: 2)
- Basic Strike

Rotation: Fist → Spear → Judgement → Basic
```

### Close-Range Powerhouse
```
Enable:
- Holy Light Aura (Min Enemies: 3)
- Fist of the Heavens (Min Enemies: 3)
- Wing Strikes (Min Enemies: 2)
- Basic Strike

Rotation: Aura → Fist → Wing → Basic
```

---

## General Tips for All Builds

### Performance Optimization
1. **Lower Min Enemies** for faster clearing
2. **Higher Min Enemies** for resource conservation
3. **Adjust Ranges** based on your gear and comfort

### Targeting Modes
- **Player Mode**: Best for auto-play and farming
- **Cursor Mode**: Best for precise control and boss fights

### Priority System
The plugin follows this general priority:
1. AOE damage abilities (when min enemies met)
2. Single target abilities
3. Basic Strike (filler)

Disable abilities you don't want in your rotation by unchecking them in the menu.

---

## Important Notes

### Spell IDs
All spell IDs in the plugin are currently **placeholders**. You will need to:
1. Find actual Spiritborn/Paladin spell IDs
2. Update them in the respective spell .lua files
3. Test each ability in-game

### Character Class
This plugin is configured for **Spiritborn (character_id: 6)** as the Paladin class interpretation in Diablo 4.

---

## Troubleshooting

**Spells Not Casting:**
- Verify plugin is enabled
- Check orbwalker is active
- Ensure spell IDs are correct
- Lower min enemies requirements

**Wrong Spell Priority:**
- Adjust min enemies to change when spells cast
- Disable spells you don't want
- Check spell ranges

**Character Not Detected:**
- Ensure you're playing Spiritborn
- Check character_id in main.lua

---

## Support

For more help:
- Discord: https://discord.gg/VE2gztW23q
- Check individual build quick start guides
- Review the main README.md

Happy hunting! ⚡🔱🌟
