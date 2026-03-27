# Azmodan Farm
#### V1.0.13
## Description
A very simple script to farm azmodan divine blessing level.
All it does is interact belial altar to start event, stand afk in center while waiting for Azmodan to spawn. 
Once Azmodan is spawned, it will stick to the boss

## Steps
- Walk to Azmodan area manually
- Enable script
- Afk

## Changelog
### V1.0.13
- add back alfred (accidentally removed) and also auto turn off clear toggle when alfred is running
- added move back to center if distance > 30

### V1.0.12
- extend range to find azmodan so timer doesnt reset mid way

### V1.0.11
- added kill time tracker

### V1.0.10
- added drop items keybind (equipments)

### V1.0.9
- fix bug with enabled

### V1.0.8
- fix bug with chest delay

### V1.0.7
- fix bug with string match

### V1.0.6
- added teleport and walking to azmodan
    - orbwalker clear toggle will be turned off while walking so that it doesnt deviate from path
- added 10s delay for after opening chest
- added keybind to drop all non-favourite sigil
    - this can be activated even if this plugin is toggled off
    - it also disable looter for 10 seconds
    - usage:
        - press toggle keybind to disable plugin  (toggle it off) before loot drops (or alternatively disable alfred so no teleport trigger)
        - walk to an empty area
        - filter through sigils to find mythic prankster and favourite it
        - press drop sigil keybind
        - walk back to original loot location
        - repeat step 2 to 4 until no more loot in original location
        - teleport back and clear sigils
        - re-enable plugin/alfred (after clearing all sigils)

### V1.0.5
- added chest priority
    - it will first use up all corrupted mats for the priority you set and then move on to others
- added Andariel and Duriel altars
    - follows whichever materials u have first in inventory

### V1.0.4
- added keybind
### V1.0.3
- added revive
- added randomize position every 5 seconds
- added alfred
- add open chest 
    - it checks your inventory for corrupted materails >= 5
    - priority = depends on how you organize your inventory

## To do
- update alfred integration to not trigger teleport too quickly