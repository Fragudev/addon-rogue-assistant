std = "lua51"
max_line_length = 120

-- Addon entry files receive (addonName, ns) via varargs and write SavedVariables.
globals = {
  "RogueAssistantDB",
  "SLASH_RAS1",
  "SLASH_RAS2",
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
  "UnitGUID",
  "IsPlayerSpell",
  "GetSpellInfo",
  "GetSpellCooldown",
  "GetWeaponEnchantInfo",
  "GetItemInfo",
  "InCombatLockdown",
  "IsInInstance",
  "GetTime",
  "Enum",
  "C_Spell",
  "C_UnitAuras",
  "C_Container",
  "C_Item",
  "C_SpellBook",
  "C_Secrets",
  "C_CooldownViewer",
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
  globals = { "_G", "WowStub" },
}
