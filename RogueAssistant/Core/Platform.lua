local _, ns = ...

-- Single seam over the WoW client API. Everything else asks Platform, so specs can substitute a fake and API
-- changes between Mainline and Forever stay in one file.
--
-- Every wrapper follows one contract: it gives nil when the API is missing on this client, raises, or returns a secret
-- value (a secret cannot be compared, stored or measured). The caller then treats the data as unavailable. Nothing
-- here raises. Platform.Has(path) tells "missing" from "empty".
local Platform = {}

-- Stands in for a secret value in the packed results of Platform.Invoke. Wrappers turn it into nil.
Platform.SECRET = setmetatable({}, {
  __tostring = function()
    return "<secret>"
  end,
})
local SECRET = Platform.SECRET

-- Events the addon must never register: the client blocks the whole addon for them.
local FORBIDDEN_EVENTS = { COMBAT_LOG_EVENT_UNFILTERED = true }

-- true when `value` is a secret value. Uses issecretvalue when the client has it; otherwise relies on the fact that a
-- secret raises when it is compared or measured.
function Platform.IsSecret(value)
  if issecretvalue then
    local ok, secret = pcall(issecretvalue, value)
    if ok and secret then
      return true
    end
  end
  local kind = type(value)
  if kind == "number" then
    return not pcall(function()
      return value >= 0
    end)
  elseif kind == "string" then
    return not pcall(function()
      return #value
    end)
  end
  return false
end

local function walk(path)
  local target = _G
  for part in path:gmatch("[^.]+") do
    if type(target) ~= "table" then
      return nil
    end
    target = target[part]
  end
  return target
end

-- The function at a dotted global path ("C_Spell.GetSpellCooldown"), or nil when any step is missing.
function Platform.Resolve(path)
  local target = walk(path)
  if type(target) == "function" then
    return target
  end
  return nil
end

-- true when the function at `path` exists on this client.
function Platform.Has(path)
  return Platform.Resolve(path) ~= nil
end

-- true when anything (a table such as C_Secrets, a function) exists at `path`.
function Platform.HasGlobal(path)
  return walk(path) ~= nil
end

local function pack(...)
  return { n = select("#", ...), ... }
end

local function safeText(value)
  local ok, text = pcall(tostring, value)
  if ok and type(text) == "string" then
    return text
  end
  return "<secret>"
end

-- Calls the API at `path` through pcall. Gives "missing", "error" with the message, or "ok" with the packed results
-- ({ n = count, ... }, each secret value replaced by Platform.SECRET).
function Platform.Invoke(path, ...)
  local fn = Platform.Resolve(path)
  if not fn then
    return "missing"
  end
  local packed = pack(pcall(fn, ...))
  if not packed[1] then
    return "error", safeText(packed[2])
  end
  local count = packed.n - 1
  local out = { n = count }
  for index = 1, count do
    local value = packed[index + 1]
    if Platform.IsSecret(value) then
      value = SECRET
    end
    out[index] = value
  end
  return "ok", out
end

local function results(path, ...)
  local status, packed = Platform.Invoke(path, ...)
  if status == "ok" then
    return packed
  end
  return nil
end

-- A value of the expected Lua type, or nil (a secret never matches).
local function typedValue(value, kind)
  if value ~= SECRET and type(value) == kind then
    return value
  end
  return nil
end

local function first(kind, path, ...)
  local packed = results(path, ...)
  if not packed then
    return nil
  end
  return typedValue(packed[1], kind)
end

-- The first results of the call, each kept only when it has the expected type: kinds = { "string", "number" }.
local function several(kinds, path, ...)
  local packed = results(path, ...)
  if not packed then
    return nil
  end
  local values = {}
  for index = 1, #kinds do
    values[index] = typedValue(packed[index], kinds[index])
  end
  return unpack(values, 1, #kinds)
end

-- Player ---------------------------------------------------------------------------------------------------------

-- Class token ("ROGUE"), or nil.
function Platform.GetPlayerClassToken()
  local _, token = several({ "string", "string", "number" }, "UnitClass", "player")
  return token
end

-- The identity of a character is its GUID: UnitName gives only the first word of a multi-word name on Forever.
function Platform.GetPlayerGUID()
  return first("string", "UnitGUID", "player")
end

-- true or false, nil when the client cannot say.
function Platform.IsPlayerSpell(spellId)
  return first("boolean", "IsPlayerSpell", spellId)
end

-- Spells ---------------------------------------------------------------------------------------------------------

-- Spell name and icon (file id or path). Prefers C_Spell.GetSpellInfo and falls back to the legacy GetSpellInfo.
function Platform.GetSpellInfo(spellId)
  local info = first("table", "C_Spell.GetSpellInfo", spellId)
  if info then
    local name, icon = typedValue(info.name, "string"), info.iconID
    if icon == SECRET or Platform.IsSecret(icon) then
      icon = nil
    end
    if name then
      return name, icon
    end
  end
  local name, _, icon = several({ "string", "string", "number" }, "GetSpellInfo", spellId)
  return name, icon
end

-- Spell cooldown: start (number), duration (number), enabled (boolean). Each is nil when unavailable or secret.
function Platform.GetSpellCooldown(spellId)
  local info = first("table", "C_Spell.GetSpellCooldown", spellId)
  if info then
    local enabled = info.isEnabled
    if enabled ~= nil and typedValue(enabled, "boolean") == nil then
      if typedValue(enabled, "number") then
        enabled = enabled ~= 0
      else
        enabled = nil
      end
    end
    return typedValue(info.startTime, "number"), typedValue(info.duration, "number"), enabled
  end
  local start, duration, enabled = several({ "number", "number", "number" }, "GetSpellCooldown", spellId)
  if enabled ~= nil then
    enabled = enabled ~= 0
  end
  return start, duration, enabled
end

-- The raw duration object of the cooldown (C_Spell.GetSpellCooldownDuration), returned untouched: it may be secret
-- inside restricted content and is only meant to be handed to a widget, never compared. nil when the API is missing
-- or raises.
function Platform.GetSpellCooldownDurationObject(spellId)
  local fn = Platform.Resolve("C_Spell.GetSpellCooldownDuration")
  if not fn then
    return nil
  end
  local ok, object = pcall(fn, spellId)
  if ok then
    return object
  end
  return nil
end

-- Auras ----------------------------------------------------------------------------------------------------------

-- Reduces an AuraData table to the fields the addon reads. Each field is nil when it is secret or of another type.
local function normalizeAura(data)
  return {
    name = typedValue(data.name, "string"),
    spellId = typedValue(data.spellId, "number"),
    icon = typedValue(data.icon, "number") or typedValue(data.icon, "string"),
    applications = typedValue(data.applications, "number"),
    duration = typedValue(data.duration, "number"),
    expirationTime = typedValue(data.expirationTime, "number"),
    auraInstanceID = typedValue(data.auraInstanceID, "number"),
  }
end

-- Aura of the player by spell id, or nil when the player does not have it (or the API is unavailable).
function Platform.GetPlayerAura(spellId)
  local data = first("table", "C_UnitAuras.GetPlayerAuraBySpellID", spellId)
  if not data then
    return nil
  end
  return normalizeAura(data)
end

-- Aura at an index of a unit for a filter ("HELPFUL", "HARMFUL|PLAYER"), or nil past the last aura.
function Platform.GetAuraByIndex(unit, index, filter)
  local data = first("table", "C_UnitAuras.GetAuraDataByIndex", unit, index, filter)
  if not data then
    return nil
  end
  return normalizeAura(data)
end

-- Array of every aura of the unit for the filter (up to Constants.MAX_AURAS), empty when none or unavailable.
function Platform.GetAuras(unit, filter)
  local list = {}
  for index = 1, ns.Constants.MAX_AURAS do
    local aura = Platform.GetAuraByIndex(unit, index, filter)
    if not aura then
      break
    end
    list[#list + 1] = aura
  end
  return list
end

-- Weapon enchants ------------------------------------------------------------------------------------------------

-- { hasMH, mhMs, mhCharges, mhEnchantId, hasOH, ohMs, ohCharges, ohEnchantId } (GetWeaponEnchantInfo), each field nil
-- when unavailable or secret. nil when the API is missing, raises or says nothing readable.
function Platform.GetWeaponEnchantInfo()
  local packed = results("GetWeaponEnchantInfo")
  if not packed then
    return nil
  end
  local info = {
    hasMH = typedValue(packed[1], "boolean"),
    mhMs = typedValue(packed[2], "number"),
    mhCharges = typedValue(packed[3], "number"),
    mhEnchantId = typedValue(packed[4], "number"),
    hasOH = typedValue(packed[5], "boolean"),
    ohMs = typedValue(packed[6], "number"),
    ohCharges = typedValue(packed[7], "number"),
    ohEnchantId = typedValue(packed[8], "number"),
  }
  if info.hasMH == nil and info.hasOH == nil then
    return nil
  end
  return info
end

-- Bags and items ------------------------------------------------------------------------------------------------

function Platform.GetContainerNumSlots(bag)
  return first("number", "C_Container.GetContainerNumSlots", bag)
end

-- { itemID, stackCount, icon, link } of a bag slot, or nil for an empty slot or unavailable API.
function Platform.GetContainerItem(bag, slot)
  local info = first("table", "C_Container.GetContainerItemInfo", bag, slot)
  if not info then
    return nil
  end
  local itemId = typedValue(info.itemID, "number")
  if not itemId then
    return nil
  end
  return {
    itemID = itemId,
    stackCount = typedValue(info.stackCount, "number") or 1,
    icon = typedValue(info.iconFileID, "number"),
    link = typedValue(info.hyperlink, "string"),
  }
end

-- Array of { bag, slot, itemID, stackCount, icon, link } for every occupied slot of bags 0..4.
function Platform.GetBagItems()
  local list = {}
  local constants = ns.Constants
  for bag = constants.FIRST_BAG, constants.LAST_BAG do
    local slots = Platform.GetContainerNumSlots(bag) or 0
    for slot = 1, slots do
      local item = Platform.GetContainerItem(bag, slot)
      if item then
        item.bag, item.slot = bag, slot
        list[#list + 1] = item
      end
    end
  end
  return list
end

-- How many of an item the player carries (bags only unless includeBank).
function Platform.GetItemCount(item, includeBank)
  return first("number", "C_Item.GetItemCount", item, includeBank)
end

-- Item name and icon by id. Prefers the C_Item accessors and falls back to GetItemInfo.
function Platform.GetItemInfo(itemId)
  local name = first("string", "C_Item.GetItemNameByID", itemId)
  local icon = first("number", "C_Item.GetItemIconByID", itemId)
  if name and icon then
    return name, icon
  end
  local legacyName, _, _, _, _, _, _, _, _, legacyIcon = several(
    { "string", "string", "number", "number", "number", "string", "string", "number", "string", "number" },
    "GetItemInfo",
    itemId
  )
  return name or legacyName, icon or legacyIcon
end

-- Spellbook -----------------------------------------------------------------------------------------------------

-- Array of { spellId, name } for the player spellbook (Mainline C_SpellBook), empty when unavailable.
function Platform.GetSpellBookEntries()
  local list = {}
  local lines = first("number", "C_SpellBook.GetNumSpellBookSkillLines")
  if not lines then
    return list
  end
  local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
  for lineIndex = 1, lines do
    local line = first("table", "C_SpellBook.GetSpellBookSkillLineInfo", lineIndex)
    local offset = line and typedValue(line.itemIndexOffset, "number")
    local count = line and typedValue(line.numSpellBookItems, "number")
    if offset and count then
      for index = offset + 1, offset + count do
        local item = first("table", "C_SpellBook.GetSpellBookItemInfo", index, bank)
        local spellId = item and typedValue(item.spellID, "number")
        if spellId then
          list[#list + 1] = { spellId = spellId, name = typedValue(item.name, "string") }
        end
      end
    end
  end
  return list
end

-- Client state --------------------------------------------------------------------------------------------------

-- true while the client locks the UI for combat (secure attributes cannot change), false when not, nil when unknown.
function Platform.InCombatLockdown()
  return first("boolean", "InCombatLockdown")
end

-- inInstance (boolean), instanceType ("none", "party", "raid", "pvp", "arena", ...), or nil.
function Platform.IsInInstance()
  return several({ "boolean", "string" }, "IsInInstance")
end

-- Seconds since the client started, with millisecond precision, or nil.
function Platform.GetTime()
  return first("number", "GetTime")
end

-- true when a frame can be created from the secure template `template` ("SecureActionButtonTemplate").
function Platform.CanCreateSecureTemplate(template)
  if type(CreateFrame) ~= "function" then
    return false
  end
  local ok, frame = pcall(CreateFrame, "Button", nil, UIParent, template)
  return ok and type(frame) == "table"
end

-- Registers `event` on `frame`; false when the client refuses it. The combat log event is never registered.
function Platform.TryRegisterEvent(frame, event)
  if FORBIDDEN_EVENTS[event] then
    return false
  end
  return (pcall(frame.RegisterEvent, frame, event))
end

-- Every client API the addon relies on. Each entry is a group of alternatives: the group is satisfied when any member
-- exists. /ras debug selftest walks this list.
Platform.REQUIRED_APIS = {
  { "UnitClass" },
  { "UnitGUID" },
  { "IsPlayerSpell" },
  { "C_Spell.GetSpellInfo", "GetSpellInfo" },
  { "C_Spell.GetSpellCooldown", "GetSpellCooldown" },
  { "C_UnitAuras.GetPlayerAuraBySpellID" },
  { "C_UnitAuras.GetAuraDataByIndex" },
  { "GetWeaponEnchantInfo" },
  { "C_Container.GetContainerNumSlots" },
  { "C_Container.GetContainerItemInfo" },
  { "C_Item.GetItemCount" },
  { "C_Item.GetItemNameByID", "GetItemInfo" },
  { "C_SpellBook.GetNumSpellBookSkillLines" },
  { "C_SpellBook.GetSpellBookItemInfo" },
  { "InCombatLockdown" },
  { "IsInInstance" },
  { "GetTime" },
}

ns.Platform = Platform
