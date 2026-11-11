# CurseForge page

## Summary

One button per weapon for WoW: Forever: apply poisons, stones and oils from your bags and track both timers, in or out of combat.

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

- **The weapon's icon**, with no tooltip in the way.
- **Poison and stone timers.** On Forever a weapon can carry a poison and a stone at once: under each button, a small
  poison icon with the poison's time left and a small stone icon with the stone's.
- **Poison charges** above the button.
- **Red glow** when a weapon has nothing applied or less than 5 minutes left on either (adjustable with `/ras warn`).

## Minimap button

- **Click** it for a menu: unlock or lock the bar, reset its position, hide the button.
- **Drag** it around the minimap.
- `/ras minimap` shows it again.

## Moving the bar

Unlock it from the minimap menu or with `/ras unlock`: a highlighted area covers the buttons, drag it where you want.
Lock it again and only the buttons are left.

## Commands

- `/ras unlock` and `/ras lock`: move the bar.
- `/ras reset`: default position.
- `/ras warn <minutes>`: warning threshold.
- `/ras minimap`: show or hide the minimap button.
- `/ras debug bags` and `/ras debug weapon`: what the game reports, for bug reports.

## Beta

Covered by automated tests. The poison and weightstone timers were checked against real Forever data; the rest has not
been verified on a live client yet. If something in your bags is not offered or a timer looks wrong, please report the
output of `/ras debug bags` and `/ras debug weapon`.

## Privacy

Everything stays in your SavedVariables. The addon sends nothing to anyone.
