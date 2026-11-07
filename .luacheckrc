std = "lua51"
max_line_length = 120

-- Addon entry files receive (addonName, ns) via varargs and write SavedVariables.
globals = {
  "RogueAssistantDB",
  "SLASH_RAS1",
  "SlashCmdList",
}

-- WoW client API used by the addon. Extend as new APIs are adopted.
read_globals = {
  "C_AddOns",
  "GetLocale",
  "GetBuildInfo",
  "CreateFrame",
  "CreateVector2D",
  "hooksecurefunc",
  "issecretvalue",
  "UnitClass",
  -- UI kit.
  "UIParent",
  "UISpecialFrames",
  "CreateFont",
  "STANDARD_TEXT_FONT",
  "GameTooltip",
  "GetPhysicalScreenSize",
  "date",
  "Minimap",
  "GetCursorPosition",
  "IsShiftKeyDown",
}

files["tests/"] = {
  std = "+busted",
  globals = { "_G" },
}
