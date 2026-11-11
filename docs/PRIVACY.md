# Privacy and data

What Rogue Assistant stores, and what it does not do.

## The short version

- **Everything stays on your computer**, in the game's `SavedVariables` file (`RogueAssistantDB`). It is a normal file
  on your disk, not a secret store.
- The addon **sends nothing**: no addon messages to other players, no network calls, no telemetry. It has no server and
  no website.
- Other players cannot see your settings or your items through this addon.

This can be checked in the source: the addon never calls `SendAddonMessage`, `C_ChatInfo.SendAddonMessage`,
`SendChatMessage` or any HTTP function, and it never registers the combat log.

## What is stored

| Data | Where it comes from |
|---|---|
| The position of the bar, the warning threshold, and the place and visibility of the minimap button | you |
| Which weapon enchant id belongs to which item id | learned when you apply an item with the addon |

No character names, GUIDs, chat or other players' data are stored. The item ids are shipped inside the addon; nothing
is downloaded. The `/ras debug` commands only print to your chat window.

## Where the file is

```text
World of Warcraft/<forever client folder>/WTF/Account/<account>/SavedVariables/RogueAssistant.lua
```

The game writes it on `/reload` and on logout.

## Taking data back

Disable or remove the addon and delete `RogueAssistant.lua` (and `RogueAssistant.lua.bak`) from the `SavedVariables`
folder while the game is closed. `/ras reset` resets only the position.

## Retention

There is no automatic expiry: data stays until you delete the file.
