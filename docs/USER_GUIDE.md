# Rogue Assistant: user guide

Two buttons, one per weapon, that apply poisons, sharpening stones, weightstones and weapon oils from your bags, in or
out of combat. For **World of Warcraft: Forever**.

> **Beta, not verified in game.** The addon is covered by automated tests, but nothing has been tested on a live
> Forever client yet. The item ids are Classic Era ids (see [API_NOTES.md](API_NOTES.md)); if something in your bags
> is not offered, that is the first suspect: run `/ras debug bags` and report the ids.

## Contents

- [Getting started](#getting-started)
- [The weapon buttons](#the-weapon-buttons)
- [The item list](#the-item-list)
- [In combat](#in-combat)
- [Moving the bar](#moving-the-bar)
- [The minimap button](#the-minimap-button)
- [Slash commands](#slash-commands)
- [When the game hides a value](#when-the-game-hides-a-value)
- [Reporting a problem](#reporting-a-problem)

## Getting started

1. Install it as described in the [README](../README.md#install).
2. Log in. The bar sits below the centre of the screen: **MH** on the left, **OH** on the right.
3. Click a weapon button and click what you want to apply.

**Language:** English, and Spanish on the `esES` and `esMX` clients. Any other client language shows English.

## The weapon buttons

| Part | What it shows |
|---|---|
| Icon | The item on the weapon once the addon knows it, otherwise the weapon itself. Grey when nothing is applied. |
| Above, left | The hand: **MH** (main hand) or **OH** (off hand). |
| Above, right | The charges left, when the game reports any. |
| Below | The time left: `1h`, `25m`, `4:05` or `42s`. |
| Red glow | Nothing is applied (the button reads **Missing**) or less than 5 minutes are left. |

The addon learns which item made an enchant when you apply it from the list, and remembers it. An item applied any other
way shows the weapon icon until you apply it once with the addon.

An empty off hand shows the empty slot and never warns.

Hovering a button shows which hand it is and how to use it, not the weapon's tooltip.

## The item list

- **Click** a weapon button to open its list; click it again to close it. Opening one list closes the other.
- The list shows what you carry that fits the weapon, with how many you have: poisons first (each type with its
  strongest rank first), then sharpening stones, weightstones and weapon oils.
- Sharpening stones are offered only for axes, swords, daggers and polearms; weightstones only for maces and staves.
  For any other weapon type both are offered and the game decides.
- **Click** an item to apply it to that weapon. The list closes and the cast starts.
- Hover an item to see its tooltip.
- When nothing fits, the list says so.

## In combat

- Opening, closing and applying work in combat.
- The game does not allow addons to change the list in combat. If you use up an item, its row stays, greyed out with a
  count of 0, and the list is rebuilt when the fight ends. New items you loot in combat appear then too.
- The bar cannot be moved in combat.

## Moving the bar

1. `/ras unlock` (or **Unlock bar** in the minimap menu): a highlighted area appears over the buttons, and any open
   list closes.
2. Drag the highlighted area. While it is shown, clicking the buttons does not open their lists.
3. `/ras lock` (or **Lock bar**): the area disappears and only the buttons are left. The position is saved.

`/ras reset` puts the bar back in its default position. The bar always starts locked.

## The minimap button

A round button with the addon's logo sits on the edge of the minimap.

- **Click** it to open a small menu: **Unlock bar** (or **Lock bar** when it is unlocked), **Reset position** and
  **Hide minimap button**. Click the button again or press Escape to close the menu.
- **Drag** it to move it around the minimap. Its place is saved.
- Hid it by mistake? `/ras minimap` shows it again.

The menu works in combat, but unlocking and resetting the bar are refused until the fight ends.

## Slash commands

| Command | What it does |
|---|---|
| `/ras` or `/ras help` | Lists the commands. |
| `/ras unlock` / `/ras lock` | Shows or hides the drag area over the bar. |
| `/ras reset` | Default position. |
| `/ras minimap` | Shows or hides the minimap button. |
| `/ras warn <minutes>` | The warning threshold, 0 to 60 minutes (default 5). With 0 it warns only when nothing is applied. |
| `/ras debug bags` | Every item in your bags: id, count, name and, when the addon knows it, its kind. |
| `/ras debug weapon` | What the game reports about both weapon enchants. |

`/rogueassistant` works as well.

## When the game hides a value

In arenas, battlegrounds and some encounters the game can hide a weapon's enchant from addons. The button then shows no
timer and no warning, and its tooltip says the value is hidden. Applying items still works.

## Reporting a problem

Open an issue on [GitHub](https://github.com/Fragudev/addon-rogue-assistant/issues) with what you did, what you
expected and what happened. Add the output of `/ras debug bags` and `/ras debug weapon` when the problem is about an
item or a weapon.
