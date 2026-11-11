local _, ns = ...

-- Fixed values shared by every module.
local Constants = {
  ADDON = "RogueAssistant",
  DB_VERSION = 2,

  -- Inventory slots of the weapons that take a poison or a stone.
  SLOT_MAIN_HAND = 16,
  SLOT_OFF_HAND = 17,

  -- Layout, in pixels.
  BUTTON_SIZE = 40,
  BUTTON_GAP = 10,
  ROW_SIZE = 32,
  ROW_GAP = 4,
  FLYOUT_PADDING = 4,

  -- Rows created per flyout. They are created once, out of combat, because a secure button cannot be created in combat.
  MAX_ROWS = 16,

  -- How often the weapon timers are read, in seconds.
  TICK_SECONDS = 0.25,

  -- A click on a flyout row teaches "enchant id -> item" when the weapon enchant changes within this many seconds.
  LEARN_WINDOW_SECONDS = 30,

  -- The warning lights up when an enchant has less than this many minutes left (the player can change it).
  DEFAULT_WARN_MINUTES = 5,
  MAX_WARN_MINUTES = 60,

  -- Minimap button: default angle (degrees, 0 = east, counter-clockwise) and distance outside the minimap edge.
  DEFAULT_MINIMAP_ANGLE = 225,
  MINIMAP_BUTTON_OFFSET = 10,
}

Constants.SLOTS = { Constants.SLOT_MAIN_HAND, Constants.SLOT_OFF_HAND }

ns.Constants = Constants
