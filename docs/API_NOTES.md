# Client API notes

What has been measured on the WoW: Forever client, what the addon assumes, and what is still to be checked.
The API reference used is [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/Api) (Mainline branch); only deviations
from it and measured behaviour belong here.

## Measured

Facts carried over from the Nrage Assistant and Forever Achievements projects (`addon-nrage-assistant/docs/API_NOTES.md`,
`addon-forever-achievements/docs/API_NOTES.md`). They were measured on the Forever beta client and must be measured
again on the live client (launch was 2026-11-05).

| Item | Value | Where it matters |
|---|---|---|
| Interface number (`select(4, GetBuildInfo())`) | 16001 (beta) | TOC |
| `COMBAT_LOG_EVENT_UNFILTERED` | registering it raised "blocked from an action only available to the Blizzard UI" | never registered (`Platform.TryRegisterEvent` refuses it) |
| Secret values | in arenas, battlegrounds and closed encounters, auras and cooldowns are secret values: they cannot be compared, stored or used in arithmetic | every client call goes through `Platform`, which gives nil for a secret |
| `UnitName("player")` | only the **first word** of a multi-word name | a character is identified by its GUID (`UnitGUID("player")`) |
| Division by zero | raises an error on this client | every division is guarded; the addon avoids dividing where it can |
| Poisons | crafted bag items (confirmed by the owner in game), applied to weapon slot 16 (main hand) or 17 (off hand) | `Constants.SLOT_MAIN_HAND`, `SLOT_OFF_HAND` |
| Poised | Forever passive, spell `1328825` (wiki/Forever sources) | probe item 3; the buff id is not measured |

## Assumed, not measured yet

- The client uses the Mainline API, so the wrappers in `Core/Platform.lua` follow the Mainline signatures
  (`C_Spell`, `C_UnitAuras`, `C_Container`, `C_Item`, `C_SpellBook`). An API that does not exist or raises gives nil to
  the caller (unavailable, never a guess); `Platform.Has(path)` tells "missing" from "empty".
- `GetWeaponEnchantInfo` exists and returns `hasMH, mhMs, mhCharges, mhEnchantId, hasOH, ohMs, ohCharges, ohEnchantId`.
  It may not tell a poison from a sharpening stone, and what it returns with both on one weapon is unknown (plan risk).
- `C_Spell.GetSpellCooldownDuration` may exist and may return a secret duration object. `Platform` returns it
  untouched for widgets (`Cooldown:SetCooldownFromDurationObject`); it is never compared.
- `C_Secrets` (and `C_Secrets.GetSpellCooldownSecrecy`) may exist. `C_CooldownViewer` is documented for Forever 1.60.1
  (wiki) but not measured.
- The sample spell of the cooldown probe items (`2983`) is a classic Sprint id used only to see whether the API
  answers; it is not a verified Forever id.
- The spellbook is read through `C_SpellBook.GetSpellBookSkillLineInfo` and `C_SpellBook.GetSpellBookItemInfo(index,
  Enum.SpellBookSpellBank.Player)`.
- `SecureActionButtonTemplate` and `SecureHandlerClickTemplate` exist (plan section 5). Probe items 18 and 19 answer it.

## How to run the probe

Run these in game, outside combat, then again inside a dungeon or an encounter, and paste the output back:

1. Log in and wait for the client to finish loading.
2. `/ras debug selftest`
3. `/ras debug probe`
4. `/ras debug bags` (carry your poisons to read their item ids)
5. `/ras debug spells` (finds the spell ids, including Poised and the tracker spells)
6. With Poised active and a target dummy, `/ras debug auras` (finds the buff id of Poised and the debuff ids)
7. `/reload` or log out: the last probe lines are kept in `RogueAssistantDB.debug.lastProbe` (bounded to 200 lines) in
   `WTF/Account/<account>/SavedVariables/RogueAssistant.lua`.

Output format: one `NN key=value` line per API. `missing` is an API that does not exist, `error: <message>` is one
that raised, `<secret>` is a value the client hides, `present` / `missing` for tables such as `C_Secrets`, and
`creatable` / `not creatable` for the secure templates. Tables show their size or first 8 keys.

## Probe: APIs

| # | Question | API | Result |
|---|---|---|---|
| 1 | Class name, token and id? | `UnitClass` | not measured yet |
| 2 | Is the player GUID readable (the identity of a character)? | `UnitGUID` | not measured yet |
| 3 | Does the player know the Poised passive (1328825)? | `IsPlayerSpell` | not measured yet |
| 4 | What does it say about the weapon enchants (poisons)? | `GetWeaponEnchantInfo` | not measured yet |
| 5 | How many slots does the backpack have? | `C_Container.GetContainerNumSlots` | not measured yet |
| 6 | What does a bag slot give (item id, count, link)? | `C_Container.GetContainerItemInfo` | not measured yet |
| 7 | Does it count an item (the Hearthstone)? | `C_Item.GetItemCount` | not measured yet |
| 8 | Is the spell cooldown readable? | `C_Spell.GetSpellCooldown` | not measured yet |
| 9 | Does it give a cooldown duration object, and is it secret? | `C_Spell.GetSpellCooldownDuration` | not measured yet |
| 10 | Does it find the Poised buff on the player? | `C_UnitAuras.GetPlayerAuraBySpellID` | not measured yet |
| 11 | Can the player auras be walked by index? | `C_UnitAuras.GetAuraDataByIndex` | not measured yet |
| 12 | Does the secrets namespace exist? | `C_Secrets` | not measured yet |
| 13 | What does it say about the cooldown secrecy of a spell? | `C_Secrets.GetSpellCooldownSecrecy` | not measured yet |
| 14 | Does the Cooldown Viewer API exist (plan B for the tracker)? | `C_CooldownViewer` | not measured yet |
| 15 | Is the combat lockdown readable? | `InCombatLockdown` | not measured yet |
| 16 | Is the instance state readable? | `IsInInstance` | not measured yet |
| 17 | Does the client have the secret-value test? | `issecretvalue` | not measured yet |
| 18 | Can a secure action button be created? | `SecureActionButtonTemplate` | not measured yet |
| 19 | Can a secure click handler be created? | `SecureHandlerClickTemplate` | not measured yet |
