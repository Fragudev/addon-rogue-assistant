<h1 align="center">Rogue Assistant</h1>

<p align="center">
  A cooldown and aura tracker and a one-button poison menu for rogues in <b>World of Warcraft: Forever</b>.
</p>

<p align="center">
  <a href="docs/USER_GUIDE.md"><b>User guide</b></a> ·
  <a href="docs/PRIVACY.md"><b>Privacy</b></a> ·
  <a href="docs/API_NOTES.md"><b>Client API notes</b></a> ·
  <a href="https://github.com/Fragudev/addon-rogue-assistant/releases"><b>Releases</b></a>
</p>

> [!NOTE]
> **Beta.** Everything described here is implemented and covered by automated tests, but it has **not been verified on
> the game client yet**. Several spell and item ids are Classic Era ids that nobody has confirmed on Forever, and the
> secure poison button is untested in game. See [docs/API_NOTES.md](docs/API_NOTES.md) for what is assumed.

## What it does

- **Poison button.** One button holds every poison in your bags. Click it to open the list, left click a poison to
  apply it to your main hand, right click to apply it to your off hand. Shift + left / right click reapplies the last
  poison used on that hand. Under the button you see how many minutes (and charges) each weapon's poison has left.
- **Poison reminders.** A chat line and a short on-screen banner, out of combat, when a weapon has no poison, a poison
  is about to expire, its charges run low or the stock in your bags is getting short. Each trigger (entering an
  instance, a ready check, the end of combat) has its own switch.
- **Tracker.** Three groups of icons in the style of Blizzard's Cooldown Manager: your **essential cooldowns**, your
  **buffs** and your **debuffs on the target**. Only what your character knows is shown. Each group can show icons or
  bars, and you can add or remove any spell by id or name.
- **Options.** `/ras` opens a panel in the game's Settings window for everything above.
- **Rogues only.** On any other class the addon turns itself off.

## Install

1. Download `RogueAssistant-<version>.zip` from the newest release on the
   [Releases page](https://github.com/Fragudev/addon-rogue-assistant/releases), under *Assets*, or install it with the
   CurseForge app.
2. Unzip it into the game's AddOns folder, so that the result is
   `World of Warcraft/<forever client folder>/Interface/AddOns/RogueAssistant/`.
3. Restart the game and make sure **Rogue Assistant** is enabled in the AddOns list.
4. Log in with a rogue and type `/ras`.

Updating: delete the old `RogueAssistant` folder and unzip the new one. Your settings live in the `RogueAssistantDB`
saved variable, not in the addon folder.

## Commands

| Command | What it does |
|---|---|
| `/ras` | Opens the options. |
| `/ras help` | Lists the commands. |
| `/ras unlock` | Unlocks the poison button and the tracker groups so you can drag them. |
| `/ras lock` | Locks them again. |
| `/ras debug` | Lists the diagnostic commands (`probe`, `bags`, `spells`, `auras`, `selftest`). |

`/rogueassistant` works as well. The layout cannot be changed in combat.

## Secret values

In arenas, battlegrounds and some encounters the game hides combat data from addons ("secret values"). Rogue Assistant
never guesses and never tries to read around the restriction:

- Every game call goes through one wrapper that returns nothing when the value is hidden or the call is missing.
- When a cooldown or aura is hidden, the icon says so (a `?` and a tooltip) instead of showing a wrong number or a
  wrong "ready". Hidden timers are handed only to the game's own cooldown widget, which can draw them without the
  addon ever reading them.
- Bars need readable numbers; a hidden entry stays an icon.
- The addon never registers the combat log, and it never acts on its own: every click does exactly one thing.

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
