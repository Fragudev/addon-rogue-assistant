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
- **Poison and stone on one weapon.** On Forever a weapon can carry a poison and a temporary enchant (sharpening stone,
  weightstone) at the same time, each hand on its own (Forever class guides, for example
  [wowfdb](https://wowfdb.com/classes/rogue/utility/) and
  [conquestcapped](https://conquestcapped.com/guides/wow-forever/wow-forever-rogue-overview/), citing Blizzard's
  changes). How the client reports both is **not measured**: `GetWeaponEnchantInfo` has one set of values per hand.
  The second may come as extra return values or only in the weapon tooltip. `/ras debug weapon` prints every raw
  value of `GetWeaponEnchantInfo` and the lines of `C_TooltipInfo.GetInventoryItem` for each hand: run it with a
  poison and a stone on the same weapon to find out.
- **How the rows are built (assumed, `Domain/WeaponEnchants.lua`).** The API enchant gives one row: a poison when the
  addon learned that its enchant id came from a poison, or else when it has charges (stones have none); otherwise a
  stone. The weapon tooltip (`C_TooltipInfo.GetInventoryItem`) is read for lines ending in a time left, matched with the
  client strings `ITEM_ENCHANT_TIME_LEFT_HOURS`, `_MIN` and `_SEC` ("%s (%d min)", "|4singular:plural;" grammar
  allowed; English words as a fallback). With two such lines, the poison is the line whose text is a poison item name
  (`C_Item.GetItemNameByID`), or else the line whose time is closest to the API enchant; the other line is the stone.
  Without the API enchant, each line is a poison when its text is a poison item name and a stone otherwise. Oils count
  as stones. None of this is measured: it assumes the tooltip lists both enchants as "<name> (<n> <unit>)".
- `GetInventoryItemID("player", 17)` returns nil for an empty slot; `Api.GetEquippedItemID` turns that into `false`
  and keeps `nil` for "API missing, failing or secret".
- `C_Item.GetItemInfoInstant` gives the weapon class (2) and subclass without a server query; the subclass decides which
  stone fits (sharpening: axes 0/1, polearm 6, swords 7/8, dagger 15; weightstone: maces 4/5, staff 10; any other
  subclass gets both). Source: [ItemType](https://warcraft.wiki.gg/wiki/ItemType).
- Bags 0 to 5 are walked with `C_Container.GetContainerNumSlots` and `C_Container.GetContainerItemInfo` (`itemID`,
  `stackCount`).

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
