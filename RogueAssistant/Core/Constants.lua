local addonName, ns = ...

local Constants = {
  ADDON_NAME = addonName,
  -- Version of the saved data layout (RogueAssistantDB.schemaVersion). Bump it with every migration.
  SCHEMA_VERSION = 1,
  -- Only this class token keeps the addon enabled.
  CLASS_TOKEN = "ROGUE",
  -- Inventory slots a poison can be applied to.
  SLOT_MAIN_HAND = 16,
  SLOT_OFF_HAND = 17,
  -- Bounds of the diagnostics kept in RogueAssistantDB.debug.
  DEBUG_MAX_LOG = 50,
  DEBUG_MAX_PROBE_LINES = 200,
  DEBUG_MAX_LINE_LENGTH = 240,
  -- Bags walked by the bag iteration: the backpack (0) and the four bag slots.
  FIRST_BAG = 0,
  LAST_BAG = 4,
  -- Highest aura index read when walking a unit.
  MAX_AURAS = 40,
  -- Slash commands (SLASH_RAS1, SLASH_RAS2).
  SLASH_COMMANDS = { "/ras", "/rogueassistant" },
  -- Icon shown by the poison button when the main hand has no known poison.
  LOGO_TEXTURE = "Interface\\AddOns\\RogueAssistant\\Media\\rogue_assistant_logo",
  -- Seconds between refreshes of the weapon status lines (minutes left tick down without any event).
  STATUS_REFRESH_SECONDS = 5,
  -- Seconds an applied poison waits for the weapon enchant to change before the attempt is forgotten.
  POISON_PENDING_SECONDS = 30,
  -- Seconds the alert banner stays on screen.
  BANNER_SECONDS = 8,
  -- Spell ids used by the probe. The Poised passive is a Forever spell (plan section 2).
  SPELL_POISED = 1328825,
}

ns.Constants = Constants
