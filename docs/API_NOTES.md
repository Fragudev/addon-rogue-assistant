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
- **Applying a poison (secure mechanism, read from Blizzard source, not yet run in game).** A poison is used with
  `type="item"`, `item="item:<id>"` and `target-slot=<16|17>` on a `SecureActionButtonTemplate`. Source:
  [`SecureTemplates.lua`](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua)
  (`live` branch of the Gethe mirror, a Mainline snapshot, not the Forever client). `OnActionButtonClick` first runs the
  action (`SECURE_ACTIONS.item` uses the item through `SecureCmdUseItem`), and then, `if SpellCanTargetItem() or
  SpellCanTargetItemID()` (the item started a spell that targets an item), reads `target-bag` / `target-slot` (and
  `target-item`) with the same modifier and button suffix and calls `UseInventoryItem(slot)` (or
  `C_Container.UseContainerItem(bag, slot)` when `target-bag` is set). So `target-slot` **is** honoured after an item that
  starts targeting, which is what a poison does. The `macrotext` fallback (`/use item:<id>` + `/use 16|17`) was not
  needed and is not implemented. To check in game: left click a poison in the flyout, the cast bar must start and the
  main hand must get the poison; right click does the same for the off hand.
  - Clicks: `RegisterForClicks("AnyUp")`. A mouse click on the template reaches `SecureActionButton_OnClick` as a
    secure mouse press, which ignores `ActionButtonUseKeyDown`; registering "AnyDown" would not fire the action.
  - The suffix of the attributes is the mouse button number: `type1` / `item1` / `target-slot1` for the left button,
    `type2` / ... for the right button; the Shift variants are `shift-type1`, `shift-item1`, `shift-target-slot1` (the
    modifier prefix comes first).
  - Toggle in combat. [`SecureHandlers.lua`](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/SecureHandlers.lua)
    (`SecureHandlerWrapScript`, `Wrapped_Click`) runs a pre-body snippet against a header frame before the wrapped
    `OnClick`; the snippet sees `self` (the wrapped frame) and `control` (the header). Returning `false` swallows the
    click, returning nothing lets it through, and a second return value is handed to the post-body. The restricted
    environment offers `IsShiftKeyDown` ([`RestrictedEnvironment.lua`](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/RestrictedEnvironment.lua))
    and handle methods `GetFrameRef`, `IsShown`, `Show` and `Hide` ([`RestrictedFrames.lua`](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/RestrictedFrames.lua));
    `Show` / `Hide` act on a protected frame even in combat.
  - Structure chosen. One frame cannot be both a `SecureHandlerClickTemplate` (its `OnClick` runs `_onclick`) and a
    `SecureActionButtonTemplate` (its `OnClick` runs the action), so the main button is a plain
    `SecureActionButtonTemplate` whose `OnClick` is wrapped by a separate `SecureHandlerBaseTemplate` header: a click
    without Shift toggles the flyout and is swallowed; Shift + left / right click passes through to
    `shift-type1` / `shift-type2` (reapply the last main hand / off hand poison). Each flyout row is also a
    `SecureActionButtonTemplate` whose `OnClick` is wrapped to hide the flyout afterwards. The flyout container is a
    `SecureHandlerBaseTemplate` frame because a snippet can only show or hide a protected frame in combat.
  - The wrap snippets use the header's `control` handle and `GetFrameRef("flyout")`; both were read in source, but the
    exact `self` / `control` binding of wrapped snippets is the first thing to check if the toggle does nothing in game.
- Poison item ids are Classic Era ids (item pages of warcraft.wiki.gg linked from "Rogue abilities (Forever)"); the
  Forever wiki list shows no ids. Each entry in `Data/Poisons.lua` carries `source = "classic-era, not verified on
  Forever"`. `/ras debug bags` lists the ids of the poisons in the bags to confirm them.
- `GetWeaponEnchantInfo` gives an enchant id, not an item. The addon learns `enchantId -> poison item` when it applies a
  poison itself and the enchant of that weapon changes within 30 seconds (`Domain/WeaponState.lua`, persisted in
  `profile.poison.enchants`). A sharpening stone applied in that window would be learned as the poison (not guarded).
- `GetInventoryItemID("player", 17)` returns nil for an empty off hand slot; `Platform.GetInventoryItemID` turns that
  into `false` and keeps `nil` for "API missing, failing or secret".

- **Secret-safe tracker path (read from warcraft.wiki.gg, not run in game yet).** The tracker shows cooldowns and auras
  without reading them when the client makes them secret ([Secret values](https://warcraft.wiki.gg/wiki/Secret_Values):
  no arithmetic, comparison, `#`, indexing or table keys; text, bar and cooldown widget methods accept them). Every call
  goes through a `Platform` wrapper that gives nil when the API is missing or raises.
  - [`C_Spell.GetSpellCooldown`](https://warcraft.wiki.gg/wiki/API_C_Spell.GetSpellCooldown): numbers when readable; a
    secret field becomes nil in `Platform.GetSpellCooldown`.
  - [`C_Spell.GetSpellCooldownDuration(spellIdentifier [, ignoreGCD])`](https://warcraft.wiki.gg/wiki/API_C_Spell.GetSpellCooldownDuration)
    returns a DurationObject (12.0.5 added `ignoreGCD`; "MayReturnNothing"). `Platform.GetSpellCooldownDurationObject`
    returns it raw.
  - [`Cooldown:SetCooldownFromDurationObject(duration [, clearIfZero])`](https://warcraft.wiki.gg/wiki/API_Cooldown_SetCooldownFromDurationObject)
    (12.0.0) is how a secret duration drives the swipe and Blizzard's countdown numbers. `Platform.SetCooldownFromDurationObject`
    calls it through pcall with `clearIfZero = true`; when it refuses, the icon is drawn "hidden".
  - [`C_Spell.GetSpellCharges`](https://warcraft.wiki.gg/wiki/API_C_Spell.GetSpellCharges): `maxCharges` is never secret,
    `currentCharges` can be (it becomes nil, so a charge icon is never "ready" on a guess).
  - [`C_UnitAuras.GetAuraDuration(unit, auraInstanceID)`](https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetAuraDuration)
    returns a DurationObject for an aura (`Platform.GetAuraDurationObject`).
  - [`C_UnitAuras.GetAuraApplicationDisplayCount(unit, auraInstanceID [, minDisplayCount [, maxDisplayCount]])`](https://warcraft.wiki.gg/wiki/API_C_UnitAuras.GetAuraApplicationDisplayCount)
    returns the stack text, possibly secret, only for `FontString:SetText` (`Platform.GetAuraApplicationDisplayCount`,
    `Platform.SetText`).
  - `issecretvalue` is the secret test (`Platform.IsSecret`). `C_Secrets` is not used by the tracker.
  - Rule in the tracker: a state holds a number only when it is readable. A secret cooldown becomes a duration object
    (`durationObject`, never inspected: only tested for nil); if there is none, or the widget refuses it, the icon is
    `hidden`. An aura whose spell id and name are secret cannot be matched, so its entries are `hidden` too (never
    "missing"). `ready` is true only for a readable, finished cooldown.
  - Bars need readable numbers (`StatusBar` fill is computed from them); an entry without them stays an icon.
- **Tracker spell ids** (`Data/Spells.lua`). Ids come from the "External links" of the spell pages on warcraft.wiki.gg
  (the list is [Rogue abilities (Forever)](https://warcraft.wiki.gg/wiki/Rogue_abilities_(Forever)), which shows no ids).
  Linked for Forever (source "warcraft.wiki.gg spell page, Forever link"): Blind 2094, Cold Blood 14177, Blade Flurry
  13877, Ghostly Strike 14278, Premeditation 14183, Death Mark 1316709 (Forever-only), Venom talent 1310703
  (Forever-only; the buff is also called Venom and its id is not listed, so it is matched by name). Every other id is a
  Classic Era id with `source = "classic-era, not verified on Forever"`: Vanish 1856/1857, Evasion 5277/26669, Sprint
  2983/11305, Kick 1766/1769, Kidney Shot 408/8643, Gouge 1776 (classicdb.ch / wowclassicdb.com, the wiki page lists none),
  Adrenaline Rush 13750, Preparation 14185, Stealth 1784, Slice and Dice 5171/6774, Expose Armor 8647/11198, Rupture
  1943/11275, Garrote 703/11290, Cheap Shot 1833, Deadly Poison 2823, Crippling Poison 3408, Wound Poison 8679.
  - Poised: the passive is 1328825; its buff id is not measured, so the aura is matched by the name the client gives for
    1328825 (`Platform.GetSpellInfo`). Run `/ras debug auras` with Poised active to get the real id.
  - The poison debuffs on the target are matched by name too (the debuff id is not the id of the poison spell) and are
    always listed, since poisons are items, not spellbook spells.
  - Not included, no confirmable Forever id or name: Thousand Cuts (the wiki page is the retail Trickster talent, id
    441346) and Cutthroat (Season of Discovery rune, id 462708).
  - A known rank id decides visibility (`IsPlayerSpell`); the cooldown is asked with the highest known rank.

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
