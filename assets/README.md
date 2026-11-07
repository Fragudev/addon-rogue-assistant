# Artwork

Source images. They are **not** shipped in the addon zip (only `RogueAssistant/` is).

| File | What | Used for |
|---|---|---|
| `rogue_assistant_logo.svg` | Rogue Assistant logo: two crossed daggers and a poison drop on a dark green square | source of the PNG |
| `rogue_assistant_logo.png` | the logo rendered at 1024x1024 | CurseForge project avatar; source of `RogueAssistant/Media/rogue_assistant_logo.tga` |

## Regenerating the game texture

WoW does not load PNG. It loads TGA or BLP with power-of-two sides. `tools/make_tga.swift` (macOS) writes a 32-bit
uncompressed TGA with straight alpha:

```bash
swift tools/make_tga.swift assets/rogue_assistant_logo.png RogueAssistant/Media/rogue_assistant_logo.tga 128 0
```
