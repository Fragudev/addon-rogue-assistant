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
  -- Tracker (plan section 6). Layout bounds are { min, max, default }; Settings validates saved groups against them.
  TRACKER = {
    MAX_GROUPS = 12,
    MAX_ENTRIES = 40,
    KINDS = { cooldown = true, buff = true, debuff = true },
    GROWTH = { RIGHT = true, LEFT = true, UP = true, DOWN = true },
    MODES = { icons = true, bars = true },
    MISSING = { hide = true, dim = true },
    LAYOUT = {
      iconSize = { 16, 96, 36 },
      spacing = { 0, 32, 4 },
      columns = { 1, 20, 8 },
      scale = { 0.5, 3, 1 },
      alphaOutOfCombat = { 0, 1, 1 },
    },
    -- Where each shipped group starts (offsets from the screen centre): essentials above the centre, buffs above that,
    -- the target debuffs to the right. Only defaults: a saved position always wins.
    DEFAULT_POSITIONS = {
      essentials = { x = 0, y = 140 },
      buffs = { x = 0, y = 220 },
      target = { x = 300, y = 60 },
    },
    DEFAULT_GROWTH = "RIGHT",
    DEFAULT_MODE = "icons",
    DEFAULT_MISSING = "hide",
    -- Where the aura of a group kind is read: the unit and the aura filter.
    AURA_SOURCE = {
      buff = { unit = "player", filter = "HELPFUL" },
      debuff = { unit = "target", filter = "HARMFUL|PLAYER" },
    },
    -- A bar slot is this many icon sizes wide.
    BAR_WIDTH_FACTOR = 4,
    -- Cooldowns up to this many seconds are the global cooldown, not an ability cooldown.
    GCD_SECONDS = 1.5,
    -- Seconds between redraws of the bar fill and the remaining-time text.
    BAR_REFRESH_SECONDS = 0.1,
  },
}

ns.Constants = Constants
