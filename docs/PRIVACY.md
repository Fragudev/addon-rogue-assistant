# Privacy and data

What Rogue Assistant stores, and what it does not do.

## The short version

- **Everything stays on your computer**, in the game's `SavedVariables` file (`RogueAssistantDB`). It is a normal file
  on your disk, not a secret store.
- The addon **sends nothing**: no addon messages to other players, no network calls, no telemetry. It has no server and
  no website.
- Other players cannot see your settings or your poisons through this addon.

This can be checked in the source: the addon never calls `SendAddonMessage`, `C_ChatInfo.SendAddonMessage`,
`SendChatMessage` or any HTTP function, and it never registers the combat log.

## What is stored

| Data | Where it comes from |
|---|---|
| For each rogue you log in with: its GUID (the key of its settings), class and when it was last seen. The character name is not stored | read from the game |
| Your settings: the position, scale and lock of the poison button, the alert thresholds and triggers, and the tracker groups (their spells, layout and positions) | you |
| The last poison used on each hand, and which weapon enchant belongs to which poison item | learned by the addon when you apply a poison with it |
| Diagnostics, bounded (see below) | the `/ras debug` commands and internal start-up errors |

The spells, poisons and their ids are shipped inside the addon; nothing is downloaded.

### Diagnostic logs

Stored in the same file, under `RogueAssistantDB.debug`:

- `log`: the last **50** internal messages (for example "disabled: class token WARRIOR"), each at most 240 characters.
- `lastProbe`: the lines of the last `/ras debug probe`, at most **200** lines.

The probe lists which game APIs exist and what they return, which can include item and spell names from your bags,
spellbook and auras. It holds no chat, no character names and no other players' names.

## Where the file is

```text
World of Warcraft/<forever client folder>/WTF/Account/<account>/SavedVariables/RogueAssistant.lua
```

The game writes it on `/reload` and on logout. It contains your **character GUIDs** (not names), so think before
attaching it to a public issue; the output of `/ras debug selftest` is usually enough.

## Taking data back

- **Settings:** the options panel resets the poison button position and each tracker group. Deleting the file resets
  everything.
- **Everything:** disable or remove the addon and delete `RogueAssistant.lua` (and `RogueAssistant.lua.bak`) from the
  `SavedVariables` folder while the game is closed.

## Retention

There is no automatic expiry: data stays until you delete the file. The only things that are trimmed are the bounded
diagnostic logs above.
