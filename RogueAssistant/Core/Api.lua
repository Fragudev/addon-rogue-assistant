local _, ns = ...

-- The only module that talks to the game client. Every call is guarded: an API that is missing or raises gives nil
-- (unknown), and a value the client keeps secret (arenas, battlegrounds, encounters) is never compared or stored.
local Api = {}

local MAX_BAG_INDEX = 5 -- backpack (0), four bags and the reagent bag

local function isSecret(value)
  if type(issecretvalue) ~= "function" then
    return false
  end
  local ok, secret = pcall(issecretvalue, value)
  return ok and secret and true or false
end
Api.IsSecret = isSecret

-- `value` when the client lets the addon read it, nil otherwise.
local function readable(value)
  if isSecret(value) then
    return nil
  end
  return value
end

local function namespace(name)
  local space = _G[name]
  if type(space) == "table" then
    return space
  end
  return nil
end

-- pcall(fn, ...) when fn is a function; false otherwise.
local function try(fn, ...)
  if type(fn) ~= "function" then
    return false
  end
  return pcall(fn, ...)
end

-- True in combat lockdown. When the client cannot tell, the addon assumes combat so it never touches a secure frame.
function Api.InCombat()
  local ok, locked = try(InCombatLockdown)
  if not ok or isSecret(locked) then
    return true
  end
  return locked and true or false
end

function Api.Now()
  local ok, now = try(GetTime)
  if ok and type(readable(now)) == "number" then
    return now
  end
  return 0
end

function Api.GetLocale()
  local ok, code = try(GetLocale)
  if ok and type(code) == "string" then
    return code
  end
  return "enUS"
end

local function enchantEntry(active, ms, charges, enchantID)
  if isSecret(active) then
    return { unknown = true }
  end
  ms = readable(ms)
  charges = readable(charges)
  enchantID = readable(enchantID)
  return {
    active = active and true or false,
    ms = type(ms) == "number" and ms or nil,
    charges = type(charges) == "number" and charges or nil,
    enchantID = type(enchantID) == "number" and enchantID ~= 0 and enchantID or nil,
  }
end

-- { [16] = entry, [17] = entry }, or nil when the client gives nothing. An entry is { unknown = true } when the client
-- hides it, otherwise { active, ms, charges, enchantID } with nil for any field it hides.
function Api.GetWeaponEnchants()
  local ok, hasMain, mainMs, mainCharges, mainID, hasOff, offMs, offCharges, offID = try(GetWeaponEnchantInfo)
  if not ok then
    return nil
  end
  return {
    [16] = enchantEntry(hasMain, mainMs, mainCharges, mainID),
    [17] = enchantEntry(hasOff, offMs, offCharges, offID),
  }
end

-- The item id equipped in `slot`, false when the slot is empty, nil when the client cannot tell.
function Api.GetEquippedItemID(slot)
  local ok, itemID = try(GetInventoryItemID, "player", slot)
  if not ok or isSecret(itemID) then
    return nil
  end
  if itemID == nil then
    return false
  end
  return itemID
end

function Api.GetEquippedTexture(slot)
  local ok, texture = try(GetInventoryItemTexture, "player", slot)
  if ok then
    return readable(texture)
  end
  return nil
end

-- { classID, subclassID, icon } of an item, from data the client has without a server query; nil when unknown.
function Api.GetItemInstant(itemID)
  local items = namespace("C_Item")
  local ok, _, _, _, _, icon, classID, subclassID = try(items and items.GetItemInfoInstant, itemID)
  if not ok or type(readable(classID)) ~= "number" then
    return nil
  end
  return { classID = classID, subclassID = readable(subclassID), icon = readable(icon) }
end

function Api.GetItemName(itemID)
  local items = namespace("C_Item")
  local ok, name = try(items and items.GetItemNameByID, itemID)
  if ok and type(readable(name)) == "string" then
    return name
  end
  return nil
end

function Api.GetItemIcon(itemID)
  local items = namespace("C_Item")
  local ok, icon = try(items and items.GetItemIconByID, itemID)
  if ok then
    return readable(icon)
  end
  return nil
end

-- Calls fn(itemID, count) for every item stack in the bags.
function Api.ForEachBagItem(fn)
  local container = namespace("C_Container")
  if not container then
    return
  end
  for bag = 0, MAX_BAG_INDEX do
    local ok, slots = try(container.GetContainerNumSlots, bag)
    slots = ok and readable(slots) or 0
    if type(slots) ~= "number" then
      slots = 0
    end
    for slot = 1, slots do
      local infoOk, info = try(container.GetContainerItemInfo, bag, slot)
      if infoOk and type(info) == "table" then
        local itemID = readable(info.itemID)
        local count = readable(info.stackCount)
        if type(itemID) == "number" then
          fn(itemID, type(count) == "number" and count or 1)
        end
      end
    end
  end
end

function Api.Print(message)
  local frame = _G.DEFAULT_CHAT_FRAME
  if type(frame) == "table" and type(frame.AddMessage) == "function" then
    frame:AddMessage("|cffffd100Rogue Assistant|r: " .. tostring(message))
  end
end

ns.Api = Api
