# CurseForge page

## Summary

One button per weapon for WoW: Forever: pick a poison, stone or oil from your bags and apply it, in or out of combat.

## Description

# Rogue Assistant

Two buttons, **main hand** and **off hand**. Click one, pick what to apply, done. Made for **World of Warcraft:
Forever**.

## How it works

- **Click a weapon** to open the list of what you carry that fits it: poisons, sharpening stones, weightstones and
  weapon oils, strongest first, with how many you have.
- **Click an item** to apply it to that weapon.
- **Works in combat.** Opening the list and applying an item work in the middle of a fight.
- Sharpening stones only for edged weapons, weightstones only for blunt ones.

## On the buttons

- **Time left** under each weapon and **charges** above it.
- **Red glow** when a weapon has nothing applied or less than 5 minutes left (adjustable with `/ras warn`).
- Each button shows the weapon's icon.

## Commands

- `/ras unlock` and `/ras lock`: move the bar.
- `/ras reset`: default position.
- `/ras warn <minutes>`: warning threshold.
- `/ras minimap`: show or hide the minimap button. Click the minimap button for a menu to lock, unlock or reset the
  bar.
- `/ras debug bags` and `/ras debug weapon`: what the game reports, for bug reports.

## Beta

Covered by automated tests, not verified on a live Forever client yet. The item ids are Classic Era ids; if something in
your bags is not offered, please report the output of `/ras debug bags`.

## Privacy

Everything stays in your SavedVariables. The addon sends nothing to anyone.
