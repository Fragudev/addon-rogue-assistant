# Client API notes

What has been measured on the WoW: Forever client, what the addon assumes, and what is still to be checked.
The API reference used is [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/Api) (Mainline branch); only deviations
from it and measured behaviour belong here.

## Measured

Facts carried over from the Nrage Assistant and Forever Achievements projects, measured on the Forever beta client.
They must be measured again on the live client (launch was 2026-11-05).

| Item | Value | Where it matters |
|---|---|---|
| Interface number (`select(4, GetBuildInfo())`) | 16001 (beta) | TOC |
| `COMBAT_LOG_EVENT_UNFILTERED` | registering it raised "blocked from an action only available to the Blizzard UI" | never registered |
| Secret values | in arenas, battlegrounds and closed encounters some values are secret: they cannot be compared, stored or used in arithmetic | every client call goes through `Core/Api.lua`, which gives nil for a secret |
| Division by zero | raises an error on this client | the addon only divides by constants |
| Poisons | crafted bag items (confirmed by the owner in game), applied to weapon slot 16 (main hand) or 17 (off hand) | `Constants.SLOT_MAIN_HAND`, `SLOT_OFF_HAND` |

## Assumed, not measured yet

- The client uses the Mainline API, so `Core/Api.lua` follows the Mainline signatures (`C_Container`, `C_Item`). An API
  that does not exist or raises gives nil (unknown), never a guess. When `InCombatLockdown` cannot be read the addon
  assumes combat, so it never touches a secure frame by mistake.
- `GetWeaponEnchantInfo` returns `hasMH, mhMs, mhCharges, mhEnchantId, hasOH, ohMs, ohCharges, ohEnchantId`. An enchant
  id of 0 is treated as "no id".
- **Poison and stone on one weapon (measured on Forever, 2026-11-11, `/ras debug weapon`).** A weapon can carry a
  poison and a temporary enchant (sharpening stone, weightstone) at the same time, each hand on its own.
  - `GetWeaponEnchantInfo` returns 12 values (main hand, off hand, ranged) and reports **only the poison**:
    `true, 1669925, 60, 323, true, 1790515, 60, 323, false, nil, nil, nil` with Instant Poison (enchant 323, 60
    charges) and a weightstone on both maces.
  - The weapon tooltip (`C_TooltipInfo.GetInventoryItem`) lists **both**, in green lines:
    `Weighted +6 (30 min)` and `Instant Poison (28 min) (60 Charges)`. Only the poison line shows charges, and the
    tooltip time is in whole minutes.
- **How the rows are built (`Domain/WeaponEnchants.lua`).** Tooltip lines ending in a time left, optionally followed
  by `(N <word>)` charges, are read with the client strings `ITEM_ENCHANT_TIME_LEFT_HOURS`, `_MIN` and `_SEC`
  ("|4singular:plural;" grammar allowed; English words as a fallback). A line is a poison when it shows charges or its
  text is a poison item name (`C_Item.GetItemNameByID`), and a stone otherwise; oils count as stones. The API enchant
  then replaces the row of its kind with its exact time and charges: a poison when the addon learned that its enchant
  id came from a poison, or else when it has charges.

### Item ids (`Data/Items.lua`)

Poison ranks follow [Rogue abilities (Forever)](https://warcraft.wiki.gg/wiki/Rogue_abilities_(Forever)); the item ids
come from the item pages it links to. Sharpening stones, weightstones and oils come from their warcraft.wiki.gg item
pages. All of them are Classic Era ids that nobody has confirmed on Forever. `/ras debug bags` prints the real ids of
what the player carries.

### Learning the item on a weapon

`GetWeaponEnchantInfo` gives an enchant id, not an item. When the player clicks an item in a flyout, the addon
remembers it for 30 seconds; if that weapon's enchant starts, changes or is renewed in that window, it saves
`enchantId -> itemId` (`Domain/WeaponState.lua`, persisted in `RogueAssistantDB.enchants`). An item applied by another
means in that window would be learned wrongly (not guarded).

### Secure buttons (read from Blizzard source, not yet run in game)

Source: the `live` branch of the [Gethe mirror](https://github.com/Gethe/wow-ui-source) (a Mainline snapshot, not the
Forever client): `Blizzard_FrameXML/SecureTemplates.lua` and
`Blizzard_RestrictedAddOnEnvironment/SecureHandlers.lua`.

- **Applying an item.** Each flyout row is a `SecureActionButtonTemplate` with `type="item"`, `item="item:<id>"` and
  `target-slot=<16|17>`, without a button suffix so any mouse button uses them. The template uses the item and, when
  the item starts a spell that targets an item (`SpellCanTargetItem()`), calls `UseInventoryItem(target-slot)`. No
  macro is used.
- **Clicks.** `SecureActionButton_OnClick` treats a click as a "secure mouse press" only when `isSecureAction` is set,
  which addon buttons never get (the template XML says so). Otherwise the action runs on the down click when
  `useOnKeyDown` is true, and that attribute falls back to the `ActionButtonUseKeyDown` CVar (on by default). So each
  row sets `useOnKeyDown = false` and registers only `"AnyUp"`: the action fires on the release whatever the CVar says.
  Registering `"AnyDown"` as well would not work: the down click would hide the flyout before the release arrives.
- **Opening the list.** Each weapon button is a `SecureHandlerClickTemplate` whose `_onclick` snippet reads the frame
  refs `flyout` and `other` (set with `SecureHandlerSetFrameRef`) and shows or hides them. A snippet can show or hide a
  protected frame in combat; the flyout is a `SecureHandlerBaseTemplate` frame for that reason.
- **Closing after a click.** Each row's `OnClick` is wrapped with `SecureHandlerWrapScript(row, "OnClick", flyout,
  preBody)`. `Wrapped_Click` runs the pre-body with the signature `self,button,down`, `self` being the handle of the
  wrapped row; the pre-body hides `self:GetFrameRef("flyout")` and returns nothing, so the click goes on to the action.
- **What waits for the end of combat.** Creating the frames, setting attributes and frame refs, showing or hiding rows,
  resizing and moving. `PLAYER_REGEN_ENABLED` applies whatever was deferred. A drag of the bar in progress is ended on
  `PLAYER_REGEN_DISABLED`, which arrives just before the lockdown, because the bar holds secure frames. Counts and icons (font strings and
  textures) change in combat.

To check in game: click a weapon, then an item; the cast bar must start and the weapon must get the item, also in
combat. If the list does not open, the frame ref binding of the snippets is the first suspect.
