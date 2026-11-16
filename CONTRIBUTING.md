# Contributing to Rogue Assistant

Thanks for helping. Bug reports and ideas are welcome from everyone as
[issues](https://github.com/Fragudev/addon-rogue-assistant/issues). Code changes come from maintainers.

## Reporting a bug

Search the open and closed issues first; if the bug is already there, add what you saw to it. Otherwise open a **Bug
report** and include:

- the addon version (shown in the AddOns list and in the name of the zip you installed);
- what you did, what you expected and what happened instead;
- the output of `/ras debug bags` and `/ras debug weapon` when the problem is about an item or a weapon;
- the game client language, when the problem is about a text.

## Suggesting an idea

Open an **Idea**. Start with the problem you want solved, not the solution: it is easier to find a design that fits
the rest of the addon.

## Pull requests

Pull requests are open to maintainers only; GitHub does not let other accounts open them. If you want to help with
code, open an issue first and say so.

## For maintainers

- Work on `develop`, directly or through a short-lived branch merged into it. Never force-push.
- `main` only takes pull requests from `develop`, and each one needs the owner's approval.
- Commit messages and pull request titles follow [Conventional Commits](https://www.conventionalcommits.org/); CI
  checks the titles.
- Run the checks in [Building from source](README.md#building-from-source) before pushing.
- Releases follow [Releasing](README.md#releasing): betas are tagged on `develop` and releases on `main`. Only the
  owner pushes version tags.

## Licence

Rogue Assistant is proprietary; see [LICENSE](LICENSE). By submitting a contribution you agree that the copyright
holder may use, modify and distribute it as part of the project.
