local _, ns = ...

-- Turns what the client reports about a weapon into what its button shows, and learns which item made an enchant.
local WeaponState = {}

local C = ns.Constants

-- Display state of one weapon slot.
--   enchant   entry of Api.GetWeaponEnchants (nil when the client gave nothing)
--   options   { equipped = true|false|nil, warnSeconds = number, enchants = enchantID -> itemID }
-- Returns { status, seconds, charges, itemID, warning } where status is "empty", "unknown", "missing" or "active".
function WeaponState.Build(enchant, options)
  if options.equipped == false then
    return { status = "empty", warning = false }
  end
  if enchant == nil or enchant.unknown then
    return { status = "unknown", warning = false }
  end
  if not enchant.active then
    return { status = "missing", warning = true }
  end
  local seconds
  if enchant.ms then
    seconds = math.floor(enchant.ms / 1000)
  end
  local charges
  if enchant.charges and enchant.charges > 0 then
    charges = enchant.charges
  end
  local itemID
  if enchant.enchantID then
    itemID = options.enchants[enchant.enchantID]
  end
  return {
    status = "active",
    seconds = seconds,
    charges = charges,
    itemID = itemID,
    warning = seconds ~= nil and seconds < options.warnSeconds,
  }
end

-- "1h", "25m", "4:05" or "42s".
function WeaponState.FormatTime(seconds)
  if seconds == nil then
    return ""
  end
  if seconds < 0 then
    seconds = 0
  end
  if seconds >= 3600 then
    return string.format("%dh", math.floor(seconds / 3600))
  end
  if seconds >= 600 then
    return string.format("%dm", math.floor(seconds / 60))
  end
  if seconds >= 60 then
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
  end
  return string.format("%ds", seconds)
end

-- Learning "enchant id -> item id". The client reports an enchant id, not the item that made it, so the addon
-- remembers the item the player clicked in a flyout and waits for that weapon's enchant to start or be renewed.
local Learner = {}
Learner.__index = Learner

function WeaponState.NewLearner(enchants)
  return setmetatable({ enchants = enchants, pending = {}, last = {} }, Learner)
end

function Learner:NoteApply(slot, itemID, now)
  self.pending[slot] = { itemID = itemID, at = now }
end

-- Feeds the current enchant of `slot`; returns true when a new mapping was learned.
function Learner:Observe(slot, enchant, now)
  local previous = self.last[slot]
  self.last[slot] = enchant
  local pending = self.pending[slot]
  if not pending then
    return false
  end
  if now - pending.at > C.LEARN_WINDOW_SECONDS then
    self.pending[slot] = nil
    return false
  end
  if not (enchant and enchant.active and enchant.enchantID) then
    return false
  end
  local started = not (previous and previous.active) or previous.enchantID ~= enchant.enchantID
  local renewed = previous and previous.ms and enchant.ms and enchant.ms > previous.ms + 1000
  if started or renewed then
    self.enchants[enchant.enchantID] = pending.itemID
    self.pending[slot] = nil
    return true
  end
  return false
end

ns.WeaponState = WeaponState
