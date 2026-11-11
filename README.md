<h1 align="center">Rogue Assistant</h1>

<p align="center">
  One button per weapon: pick a poison, a sharpening stone or an oil from your bags and apply it, in or out of combat.
  For <b>World of Warcraft: Forever</b>.
</p>

<p align="center">
  <a href="docs/USER_GUIDE.md"><b>User guide</b></a> ·
  <a href="docs/PRIVACY.md"><b>Privacy</b></a> ·
  <a href="docs/API_NOTES.md"><b>Client API notes</b></a> ·
  <a href="https://github.com/Fragudev/addon-rogue-assistant/releases"><b>Releases</b></a>
</p>

> [!NOTE]
> **Beta.** Everything described here is implemented and covered by automated tests, but it has **not been verified on
> the game client yet**. The item ids are Classic Era ids that nobody has confirmed on Forever, and the secure buttons
> are untested in game. See [docs/API_NOTES.md](docs/API_NOTES.md) for what is assumed.

## What it does

- **Two weapon buttons**, main hand (MH) and off hand (OH). Each shows what the weapon carries.
- **Click a weapon** to open the list of what you can put on it: the poisons, sharpening stones, weightstones and
  weapon oils in your bags, strongest first, with how many you have. Sharpening stones are offered only for edged
  weapons and weightstones only for blunt ones.
- **Click an item** in the list to apply it to that weapon. The list closes.
- **In combat too.** Opening the list and applying an item work in combat. The game does not let addons change the list
  in combat, so it is rebuilt when the fight ends; meanwhile the counts still update and a spent item is greyed out.
- **Timer and charges.** Under each button, the time left on the weapon; above it, the charges when the game reports
  them.
- **Warning.** A red glow when a weapon has nothing applied ("Missing") or less than 5 minutes left (`/ras warn`).
- **Movable.** `/ras unlock` highlights an area over the buttons to drag the bar; `/ras lock` hides it and only the
  buttons are left. The bar always starts locked.
- **Minimap button.** Click it for a menu to unlock or lock the bar, reset its position or hide the button; drag it
  around the minimap. `/ras minimap` shows it again.

## Install

1. Download `RogueAssistant-<version>.zip` from the newest release on the
   [Releases page](https://github.com/Fragudev/addon-rogue-assistant/releases), under *Assets*, or install it with the
   CurseForge app.
2. Unzip it into the game's AddOns folder, so that the result is
   `World of Warcraft/<forever client folder>/Interface/AddOns/RogueAssistant/`.
3. Restart the game and make sure **Rogue Assistant** is enabled in the AddOns list.

Updating: delete the old `RogueAssistant` folder and unzip the new one. Your settings live in the `RogueAssistantDB`
saved variable, not in the addon folder. Settings of versions before this redesign are discarded once.

## Commands

| Command | What it does |
|---|---|
| `/ras` | Lists the commands. |
| `/ras unlock` | Shows a highlighted area over the bar to drag it. |
| `/ras lock` | Hides that area; only the buttons are left. |
| `/ras reset` | Moves the bar back to its default position. |
| `/ras minimap` | Shows or hides the minimap button. |
| `/ras warn <minutes>` | The warning lights up below this many minutes left (0 to 60; 0 warns only when nothing is applied). |
| `/ras debug bags` | Prints the id, count and name of every item in your bags. |
| `/ras debug weapon` | Prints what the game reports about both weapon enchants. |

`/rogueassistant` works as well. The bar cannot be moved in combat.

## Secret values

In arenas, battlegrounds and some encounters the game hides some values from addons ("secret values"). Rogue Assistant
never guesses: every game call goes through one wrapper that returns nothing when the value is hidden or the call is
missing. A hidden weapon enchant shows no timer and no warning instead of a wrong one. Applying an item does not depend
on any of those values.

## Documentation

| Document | For |
|---|---|
| [User guide](docs/USER_GUIDE.md) | players |
| [Privacy and data](docs/PRIVACY.md) | what is stored, and what is not sent |
| [Client API notes](docs/API_NOTES.md) | what the Forever client does and does not expose |

## Building from source

Lua 5.1 with [luacheck](https://github.com/lunarmodules/luacheck), [busted](https://lunarmodules.github.io/busted/),
[luacov](https://lunarmodules.github.io/luacov/) and [StyLua](https://github.com/JohnnyMorganz/StyLua).

```bash
luacheck RogueAssistant tests
busted --coverage && luacov && tools/check_coverage.sh 80
stylua --check RogueAssistant tests
tools/package.sh dev
```

Every pull request runs lint, the tests with a minimum of 80% line coverage, a format check and a package build.
Pull request titles follow [Conventional Commits](https://www.conventionalcommits.org/).

## Licence

Proprietary, see [LICENSE](LICENSE). World of Warcraft is a trademark of Blizzard Entertainment, Inc.; this project is
not affiliated with or endorsed by Blizzard Entertainment.
