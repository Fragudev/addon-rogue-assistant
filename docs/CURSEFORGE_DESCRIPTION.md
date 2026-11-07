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

- **Click** the button to open the list of poisons you carry: the top rank of each type first, then the other ranks,
  with how many you have.
- **Left click** a poison to apply it to your **main hand**. **Right click** to apply it to your **off hand**.
- **Shift + left / right click** on the button reapplies the last poison you used on that hand.
- Under the button you see the minutes left (and the charges, when the game reports them) of each weapon's poison.
- **Reminders** out of combat, as a chat line and a short banner: a weapon has no poison, a poison is about to expire,
  charges run low or your stock in the bags is getting short. You get them when you enter an instance, on a ready
  check and when combat ends, and each one has its own switch and threshold.

The list works in combat too. It is rebuilt out of combat, so a poison you pick up during a fight shows up when the
fight ends.

## Tracker

Your cooldowns, your buffs and your debuffs on the target, at a glance.

- **Essentials:** Vanish, Evasion, Sprint, Kick, Blind, Kidney Shot, Gouge, Cold Blood, Adrenaline Rush, Blade Flurry,
  Preparation, Death Mark, Ghostly Strike and Premeditation.
- **Buffs:** Stealth, **Poised**, Slice and Dice, Venom, Cold Blood, Adrenaline Rush, Blade Flurry, Evasion and Sprint.
- **Target:** Rupture, Garrote, Expose Armor, Deadly, Crippling and Wound Poison, Kidney Shot and Cheap Shot.
- Only what your character knows is shown: talents you have not taken stay out.
- Thousand Cuts and Cutthroat are **not** tracked by default (no confirmed Forever spell id); you can add them, or any
  other spell or aura, by name or id in the options.
- Cooldown sweep, countdown, stacks and a glow when something is ready. Icons or bars.
- Move each group with `/ras unlock`. In the options (`/ras`) you set size, spacing, icons per line, growth, scale,
  opacity out of combat, what to do when an aura is missing (hide or dim), and you reorder, add and remove spells.

## Honest by design

Forever hides some combat data from addons in arenas, battlegrounds and enclosed encounters. Rogue Assistant never
guesses: when the game hides a value, the icon shows a `?` and says it is hidden instead of showing a wrong number. Nothing reads the
combat log and nothing acts on its own. Every click does exactly one thing.

## Commands

- `/ras` opens the options.
- `/ras help` lists the commands.
- `/ras unlock` and `/ras lock` move the tracker groups and the poison button.
- `/ras debug probe` prints what the game client lets the addon read, to help with bug reports.

## Languages

English and Spanish.

## Privacy

Everything stays on your computer. The addon sends nothing to other players or to any server.

## Feedback

This is a **beta** and has not been verified on the game client yet: some spell and item ids are Classic Era ids that
are not confirmed for Forever. If something looks wrong, run `/ras debug probe`, and include its output when you report it.
