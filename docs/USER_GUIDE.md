# Rogue Assistant: user guide

A rogue-only addon for **World of Warcraft: Forever**: a cooldown and aura tracker in the style of Blizzard's Cooldown
Manager, and one button that holds every poison in your bags.

> **Beta, not verified in game.** The addon is covered by automated tests, but nothing has been tested on a live
> Forever client yet. Spell and item ids that are not confirmed for Forever are Classic Era ids (see
> [API_NOTES.md](API_NOTES.md)); if an icon is missing or a poison is not recognised, that is the first suspect.

## Contents

- [Getting started](#getting-started)
- [The poison button](#the-poison-button)
- [Poison reminders](#poison-reminders)
- [The tracker](#the-tracker)
- [The options panel](#the-options-panel)
- [Moving things](#moving-things)
- [Slash commands](#slash-commands)
- [When the game hides a value](#when-the-game-hides-a-value)
- [Reporting a problem](#reporting-a-problem)

## Getting started

1. Install it as described in the [README](../README.md#install).
2. Log in with a rogue. On any other class the addon turns itself off and prints nothing.
3. Type `/ras` to open the options. The poison button sits near the bottom centre of the screen and the three tracker
   groups sit around the centre; `/ras unlock` lets you drag them where you want.

**Language:** the interface is in English, and in Spanish on the `esES` and `esMX` clients. Any other client language
shows English.

## The poison button

- **Click** the button to open the list of poisons in your bags. The top rank of each type comes first, then the
  other ranks, each with the number you carry.
- **Left click** a poison to apply it to your **main hand**. **Right click** to apply it to your **off hand**. The
  list closes after the click.
- **Shift + left click** or **Shift + right click** on the button itself reapplies the last poison you used on that
  hand, as long as it is still in your bags.
- Under the button you see one line per weapon (`MH`, `OH`): the minutes left and, when the game reports them, the
  charges. A dash means no poison.
- The button and the list work in combat. The list is rebuilt out of combat, so a poison you pick up during a fight
  shows up when the fight ends.

The button icon shows your main hand poison once the addon has learned which weapon enchant belongs to which poison.
It learns that when you apply a poison with the button; until then the icon is the addon logo.

## Poison reminders

Out of combat, the addon prints one chat line and shows a short banner at the top of the screen when:

- a weapon has **no poison**;
- a poison has **fewer minutes left** than your threshold;
- a poison has **fewer charges** than your threshold;
- the **stock in your bags** of the equipped poison type is below your threshold.

It checks when you **enter an instance**, on a **ready check** and when **combat ends**; each trigger has its own
switch. A reminder is shown once until the problem is fixed. A threshold of `0` turns that rule off.

## The tracker

Three groups, each a row (or column) of icons:

| Group | What it follows |
|---|---|
| Essentials | Your cooldowns: Vanish, Evasion, Sprint, Kick, Blind, Kidney Shot, Gouge, Cold Blood, Adrenaline Rush, Blade Flurry, Preparation, Death Mark, Ghostly Strike, Premeditation. |
| Buffs | Stealth, Poised, Slice and Dice, Venom, Cold Blood, Adrenaline Rush, Blade Flurry, Evasion, Sprint. |
| Target | Your debuffs on the target: Rupture, Garrote, Expose Armor, Deadly, Crippling and Wound Poison, Kidney Shot, Cheap Shot. |

- Only spells your character knows are shown, so talents you have not taken stay out. Spells you add yourself are
  always shown.
- An icon has the cooldown sweep and countdown, a stack count when there is one, and a glow when a cooldown is ready
  or an aura is up.
- An aura that is missing is hidden or dimmed, as you choose per group.
- **Thousand Cuts and Cutthroat are not tracked by default**: no Forever spell id has been confirmed for them. Add them
  by name in the options (see below).

## The options panel

`/ras` opens it in the game's Settings window (under AddOns). If the client has no Settings window the same panel
opens in a small movable window of its own. Changes apply at once.

**Poison button**

- *Lock the poison button in place*: while unlocked you can drag it.
- *Button scale*.
- *Reset position*: back to the bottom centre.

Changes to the button made during combat are saved and applied when combat ends; the panel says so.

**Poison alerts**

- Minutes left, charges and stock thresholds (`0` = off).
- A switch for each trigger: entering an instance, a ready check, the end of combat.

**Tracker**

Pick a group with the group button, then:

- *Icon size*, *spacing*, *icons per line*, *scale* and *opacity out of combat*.
- *Growth*: right, left, up or down.
- *Display*: icons or bars. Bars need readable timers; a hidden value stays an icon.
- *When an aura is missing*: hide it or dim it.
- *Add a spell by id or name*: type it and press Enter or *Add*. If it cannot be added, the reason is shown (not
  valid, already in the group, group full). Names are matched against the aura name for buffs and debuffs and against
  the spell for cooldowns.
- The list of tracked spells, with *Up*, *Down* and *Remove* on each row.
- *Reset this group* restores its spells, layout and position. *Reset all groups* asks for a second click first.

## Moving things

`/ras unlock` shows a handle above every tracker group and lets you drag the poison button. Drag them where you want,
then `/ras lock`. Nothing moves in combat; the command tells you if it cannot run.

## Slash commands

| Command | What it does |
|---|---|
| `/ras` | Opens the options. |
| `/ras help` | Lists the commands. |
| `/ras unlock` / `/ras lock` | Unlocks or locks the poison button and the tracker groups. |
| `/ras debug probe` | Checks every game API the addon may use and saves the result to the saved variables. |
| `/ras debug bags` | Lists the items in your bags with their ids (use it to find poison item ids). |
| `/ras debug spells` | Lists your spellbook with spell ids. |
| `/ras debug auras` | Lists your buffs and the debuffs you put on your target. |
| `/ras debug selftest` | Checks that the game APIs the addon relies on exist. |

## When the game hides a value

In arenas, battlegrounds and some encounters the game hides cooldown and aura data from addons. Rogue Assistant does not
guess: the icon shows a `?` and its tooltip says "The game hides this value right now". Hidden cooldown timers still
count down when the game lets its own widget draw them. The addon never reads the combat log.

## Reporting a problem

Open an [issue](https://github.com/Fragudev/addon-rogue-assistant/issues) with what you did, what you expected and the
output of `/ras debug selftest`. For a missing icon or a poison that is not recognised, add the output of
`/ras debug spells`, `/ras debug bags` or `/ras debug auras`. See [PRIVACY.md](PRIVACY.md) before attaching the saved
variables file.
