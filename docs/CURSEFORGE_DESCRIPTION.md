# CurseForge page

## Summary

Rogue-only helper for WoW: Forever. Cooldown and aura tracker, plus one button for all your poisons.

## Description

# Rogue Assistant

A helper made **only for rogues** on **World of Warcraft: Forever**. It brings two tools together: a cooldown and
aura tracker in the style of Blizzard's Cooldown Manager, and a single button that holds every poison in your bags.

> The addon turns itself off on characters that are not rogues.

## Poison button

One button, every poison.

- **Click** the button to open the list of poisons you carry, grouped by type, with the highest rank first and how
  many you have left.
- **Left click** a poison to apply it to your **main hand**. **Right click** to apply it to your **off hand**.
- Under the button you see what each weapon has right now: which poison, how many minutes are left and how many
  charges.
- **Reminders** out of combat when a weapon has no poison, when a poison is about to expire, when charges run low or
  when your stock in the bags is getting short. You get them when you enter an instance, on a ready check and when
  combat ends.

The list works in combat too. It is rebuilt out of combat, so a poison you craft during a fight shows up when the
fight ends.

## Tracker

Your cooldowns, your buffs and your debuffs on the target, at a glance.

- **Essentials:** Vanish, Evasion, Sprint, Kick, Blind, Kidney Shot, Cold Blood, Adrenaline Rush, Blade Flurry,
  Preparation and more.
- **Buffs:** Stealth, **Poised**, Slice and Dice, Venom, Thousand Cuts stacks, Cutthroat, and your other short buffs.
- **Target:** Rupture, Garrote, Expose Armor, Deadly Poison stacks, Crippling and Wound Poison, stuns.
- Only what your character knows is shown: talents you have not taken stay out.
- Cooldown sweep, countdown, stacks and a glow when something is ready.
- Move each group with `/ras unlock`, change size, spacing, layout and opacity, and add or remove any spell or aura.

## Honest by design

Forever hides some combat data from addons in arenas, battlegrounds and enclosed encounters. Rogue Assistant never
guesses: when the game hides a value, the icon says it is hidden instead of showing a wrong number. Nothing reads the
combat log and nothing acts on its own. Every click does exactly one thing.

## Commands

- `/ras` opens the options.
- `/ras unlock` and `/ras lock` move the tracker groups and the poison button.
- `/ras debug probe` prints what the game client lets the addon read, to help with bug reports.

## Languages

English and Spanish.

## Privacy

Everything stays on your computer. The addon sends nothing to other players or to any server.

## Feedback

This is a beta. If something looks wrong, run `/ras debug probe`, and include its output when you report it.
