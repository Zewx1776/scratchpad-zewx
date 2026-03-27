# Plan: Fix "Only Cast When Not Active" for Cataclysm

## 1. Goal/Problem Statement
The user has identified a bug where the "Only cast when not active" toggle for the Cataclysm spell is not working as intended. The spell continues to be cast even when the corresponding buff is already active on the player. The same functionality for the Cyclone Armor spell is working correctly and can be used as a reference.

## 2. Context and Background
- **`spells/cataclysm.lua`**: Contains the primary logic for the Cataclysm spell. It has a checkbox `check_buff` that controls whether to check for an active buff before casting.
- **`spells/cyclone_armor.lua`**: A reference implementation where the same buff-checking logic is reportedly working correctly.
- **`my_utility/my_utility.lua`**: Implements the `is_buff_active(spell_id, buff_id)` helper function, which checks if a player has a specific buff.
- **`my_utility/spell_data.lua`**: Contains the `spell_id` and `buff_id` for all spells, including Cataclysm and Cyclone Armor.

The core of the logic in `cataclysm.lua` is:
```lua
local check_buff = menu_elements.check_buff:get()
if check_buff then
    local is_buff_active = my_utility.is_buff_active(
        spell_data.cataclysm.spell_id,
        spell_data.cataclysm.buff_id
    )
    if is_buff_active then
        return false
    end
end
```
This logic appears identical to the one in `cyclone_armor.lua`. The `is_buff_active` function checks for a buff where `buff.name_hash` matches the provided `spell_id` and `buff.type` matches the `buff_id`. This suggests the issue is likely not in the control flow but in the data being passed, i.e., the IDs from `spell_data.lua`.

## 3. Proposed Approach
The investigation will focus on comparing the data and implementation details of Cataclysm with Cyclone Armor.

1.  **Analyze `spell_data.lua`**: The most likely cause is an incorrect `spell_id` or `buff_id` for Cataclysm. We will inspect `spell_data.lua` to verify that `spell_data.cataclysm.buff_id` is defined and correct.
2.  **Compare Implementations**: We will compare the `is_buff_active` call in `cataclysm.lua` with the one in `cyclone_armor.lua`. It's possible there's a subtle difference.
3.  **Hypothesize a Fix**: Based on the findings, we will correct the `is_buff_active` call. It's possible Cataclysm's buff doesn't have a distinct `buff_id` and only needs to be checked by its `spell_id`. The `is_spell_active` function in `my_utility.lua` does exactly this.

The proposed fix is to change the buff check in `cataclysm.lua` to use `my_utility.is_spell_active(spell_data.cataclysm.spell_id)` instead of `is_buff_active`, as it seems the Cataclysm buff may not have a separate `buff_id`.

## 4. Step-by-Step Implementation Plan
1.  **Read `my_utility/spell_data.lua`**: Examine the entry for `cataclysm` and `cyclone_armor` to confirm if `buff_id` is present for Cataclysm.
2.  **Read `my_utility/my_utility.lua`**: Review the implementation of `is_buff_active` and `is_spell_active` to confirm their behavior.
3.  **Modify `spells/cataclysm.lua`**:
    - Locate the buff checking logic inside the `logics` function.
    - Replace the call to `my_utility.is_buff_active(spell_data.cataclysm.spell_id, spell_data.cataclysm.buff_id)` with `my_utility.is_spell_active(spell_data.cataclysm.spell_id)`.
    - This change will correctly check for the presence of the Cataclysm buff by its spell ID alone.

## 5. Risks, Edge Cases, and Open Questions
- **Risk**: If the Cataclysm buff *does* have a specific `buff_id` that is simply incorrect in `spell_data.lua`, this change might be a workaround rather than a true fix. However, without the ability to inspect live game data, using `is_spell_active` is a reasonable and robust alternative.
- **Edge Case**: Does the Cataclysm spell apply multiple different buffs? If so, checking only by `spell_id` might be insufficient. Based on the existing code, this seems unlikely.
- **Open Question**: What are the correct `spell_id` and `buff_id` values for Cataclysm? This is difficult to answer without in-game debugging tools, but the proposed fix bypasses the need for the `buff_id`.

## 6. Expected Deliverables
- A modified `spells/cataclysm.lua` file with the corrected buff-checking logic.
- The "Only cast when not active" feature for Cataclysm should now function correctly, preventing the spell from being cast if the player already has the buff.
- The file `plan.md` will be created in the root of the workspace to document this plan.
