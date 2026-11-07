local _, ns = ...

-- What each weapon carries. GetWeaponEnchantInfo gives an enchant id, not an item: the addon learns which poison item
-- makes which enchant id by watching its own applications, and keeps the pairs in the profile.
--
--   Read() -> nil when the client cannot say (unknown), otherwise { mh = slot, oh = slot } with
--     slot = { has, weapon, minutes, charges, enchantId, itemID }
--       has        true / false, nil when unknown
--       weapon     true when a weapon is equipped, false when the slot is empty, nil when unknown
--       minutes    time left in minutes (number, may be fractional), nil when unknown
--       charges    charges left, nil when the enchant has none or it is unknown
--       enchantId  the enchant id on the weapon, nil when none
--       itemID     the poison item that makes the enchant, only when the pair has been learned
local WeaponState = {}
WeaponState.__index = WeaponState

local SLOT_NUMBER = { mh = 16, oh = 17 }

-- `deps.data` is the persisted table ({ enchants = { [enchantId] = itemID } } is created in it), `deps.platform` and
-- `deps.now` default to ns.Platform and its clock.
function WeaponState.New(deps)
  deps = deps or {}
  local data = deps.data or {}
  if type(data.enchants) ~= "table" then
    data.enchants = {}
  end
  local platform = deps.platform or ns.Platform
  return setmetatable({
    data = data,
    platform = platform,
    now = deps.now or function()
      return platform.GetTime() or 0
    end,
    pending = {},
  }, WeaponState)
end

local function slotFrom(info, prefix)
  local has = info["has" .. prefix]
  local slot = { has = has }
  if has then
    local ms = info[prefix:lower() .. "Ms"]
    slot.minutes = ms and ms / 60000 or nil
    slot.charges = info[prefix:lower() .. "Charges"]
    if slot.charges == 0 then
      slot.charges = nil
    end
    slot.enchantId = info[prefix:lower() .. "EnchantId"]
  end
  return slot
end

function WeaponState:ItemFor(enchantId)
  return enchantId and self.data.enchants[enchantId] or nil
end

-- Learns from the applications waiting for their enchant to appear.
function WeaponState:Settle(slots)
  local now = self.now()
  for name, pending in pairs(self.pending) do
    local slot = slots[name]
    if now - pending.at > ns.Constants.POISON_PENDING_SECONDS then
      self.pending[name] = nil
    elseif slot.enchantId and slot.enchantId ~= pending.previous then
      self.data.enchants[slot.enchantId] = pending.itemID
      self.pending[name] = nil
    end
  end
end

function WeaponState:Snapshot()
  local info = self.platform.GetWeaponEnchantInfo()
  if not info then
    return nil
  end
  local slots = { mh = slotFrom(info, "MH"), oh = slotFrom(info, "OH") }
  for name, number in pairs(SLOT_NUMBER) do
    slots[name].weapon = self.platform.GetInventoryItemID("player", number)
    if slots[name].weapon ~= nil then
      slots[name].weapon = slots[name].weapon ~= false
    end
  end
  return slots
end

function WeaponState:Read()
  local slots = self:Snapshot()
  if not slots then
    return nil
  end
  self:Settle(slots)
  for _, slot in pairs(slots) do
    slot.itemID = self:ItemFor(slot.enchantId)
  end
  return slots
end

-- Tells the state the addon just used poison `itemID` on `name` ("mh" or "oh"). When the enchant on that weapon
-- changes within POISON_PENDING_SECONDS, the new enchant id is stored as made by that item. Returns false when the
-- slot name is unknown.
function WeaponState:NoteApplied(name, itemID)
  if not SLOT_NUMBER[name] then
    return false
  end
  local slots = self:Snapshot()
  local previous = slots and slots[name].enchantId or nil
  self.pending[name] = { itemID = itemID, previous = previous, at = self.now() }
  return true
end

WeaponState.SLOT_NUMBER = SLOT_NUMBER

ns.WeaponState = WeaponState

ns.Startup.Register(function()
  if type(ns.profile.poison) ~= "table" then
    ns.profile.poison = {}
  end
  ns.weaponState = WeaponState.New({ data = ns.profile.poison })
end)
