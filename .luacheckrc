std = "lua51"
max_line_length = 120

-- Saved variables and slash command globals the addon writes.
globals = {
  "RogueAssistantDB",
  "SLASH_RAS1",
  "SLASH_RAS2",
  "SlashCmdList",
}

-- WoW client API used by the addon. Extend as new APIs are adopted.
read_globals = {
  "CreateFrame",
  "GameTooltip",
  "GetInventoryItemID",
  "GetInventoryItemTexture",
  "GetLocale",
  "GetTime",
  "GetWeaponEnchantInfo",
  "InCombatLockdown",
  "SecureHandlerSetFrameRef",
  "SecureHandlerWrapScript",
  "UIParent",
  "issecretvalue",
}

files["tests/"] = {
  std = "+busted",
  globals = { "_G", "WowStub" },
}
