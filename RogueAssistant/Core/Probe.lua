local _, ns = ...

-- API probe (plan section 7): finds out which client APIs Forever really gives us. One `NN key=value` line per
-- question, copyable into docs/API_NOTES.md. Nothing here raises: every call goes through Platform (pcall) and nothing
-- is compared or measured when it may be secret.
--   /ras debug probe      Probe.Run
--   /ras debug bags       Probe.BagLines
--   /ras debug spells     Probe.SpellLines
--   /ras debug auras      Probe.AuraLines
--   /ras debug selftest   Probe.SelfTest
local Platform = ns.Platform
local Probe = {}

-- Spell id used where the probe needs any spell. Not verified for Forever: it only tells whether the API answers.
local SAMPLE_SPELL_ID = 2983
local SAMPLE_ITEM_ID = 6948

local HIDDEN = "<hidden>"

-- A short readable text for any value; "<secret>" for a value that cannot be read. Never raises.
local function describeScalar(value)
  if value == Platform.SECRET or Platform.IsSecret(value) then
    return "<secret>"
  end
  local kind = type(value)
  if kind == "table" or kind == "userdata" then
    return kind
  end
  local text = tostring(value)
  if #text > 80 then
    text = text:sub(1, 77) .. "..."
  end
  return text
end

local function describeTable(value)
  local keys = {}
  for key in pairs(value) do
    keys[#keys + 1] = key
  end
  if #keys == 0 then
    return "table empty"
  end
  table.sort(keys, function(left, right)
    return tostring(left) < tostring(right)
  end)
  local parts = {}
  for index = 1, math.min(#keys, 8) do
    parts[index] = tostring(keys[index]) .. "=" .. describeScalar(value[keys[index]])
  end
  local more = #keys > 8 and (" +" .. (#keys - 8) .. " more") or ""
  return "table {" .. table.concat(parts, " ") .. "}" .. more
end

local function describe(value)
  local ok, text = pcall(function()
    if type(value) == "table" and value ~= Platform.SECRET then
      return describeTable(value)
    end
    return describeScalar(value)
  end)
  return ok and text or "<secret>"
end

local function describeResults(packed)
  if packed.n == 0 then
    return "(no values)"
  end
  local parts = {}
  for index = 1, packed.n do
    parts[index] = describe(packed[index])
  end
  return table.concat(parts, ", ")
end

-- Calls `path` and returns "missing", "error: <message>" or the described results.
local function call(path, ...)
  local status, packed = Platform.Invoke(path, ...)
  if status == "missing" then
    return "missing"
  elseif status == "error" then
    return "error: " .. packed
  end
  return describeResults(packed)
end

local function presence(path)
  return Platform.HasGlobal(path) and "present" or "missing"
end

-- Probe items: { key, text = function() -> string }. The line number is the position in the list.
Probe.ITEMS = {
  {
    key = "class",
    text = function()
      return call("UnitClass", "player")
    end,
  },
  {
    key = "player_guid",
    text = function()
      return Platform.GetPlayerGUID() and "present" or "unavailable"
    end,
  },
  {
    key = "IsPlayerSpell_poised",
    text = function()
      return call("IsPlayerSpell", ns.Constants.SPELL_POISED)
    end,
  },
  {
    key = "GetWeaponEnchantInfo",
    text = function()
      return call("GetWeaponEnchantInfo")
    end,
  },
  {
    key = "C_Container.GetContainerNumSlots",
    text = function()
      return call("C_Container.GetContainerNumSlots", 0)
    end,
  },
  {
    key = "C_Container.GetContainerItemInfo",
    text = function()
      return call("C_Container.GetContainerItemInfo", 0, 1)
    end,
  },
  {
    key = "C_Item.GetItemCount",
    text = function()
      return call("C_Item.GetItemCount", SAMPLE_ITEM_ID)
    end,
  },
  {
    key = "C_Spell.GetSpellCooldown",
    text = function()
      return call("C_Spell.GetSpellCooldown", SAMPLE_SPELL_ID)
    end,
  },
  {
    key = "C_Spell.GetSpellCooldownDuration",
    text = function()
      return call("C_Spell.GetSpellCooldownDuration", SAMPLE_SPELL_ID)
    end,
  },
  {
    key = "C_UnitAuras.GetPlayerAuraBySpellID",
    text = function()
      return call("C_UnitAuras.GetPlayerAuraBySpellID", ns.Constants.SPELL_POISED)
    end,
  },
  {
    key = "C_UnitAuras.GetAuraDataByIndex",
    text = function()
      return call("C_UnitAuras.GetAuraDataByIndex", "player", 1, "HELPFUL")
    end,
  },
  {
    key = "C_Secrets",
    text = function()
      return presence("C_Secrets")
    end,
  },
  {
    key = "C_Secrets.GetSpellCooldownSecrecy",
    text = function()
      return call("C_Secrets.GetSpellCooldownSecrecy", SAMPLE_SPELL_ID)
    end,
  },
  {
    key = "C_CooldownViewer",
    text = function()
      return presence("C_CooldownViewer")
    end,
  },
  {
    key = "InCombatLockdown",
    text = function()
      return call("InCombatLockdown")
    end,
  },
  {
    key = "IsInInstance",
    text = function()
      return call("IsInInstance")
    end,
  },
  {
    key = "issecretvalue",
    text = function()
      return presence("issecretvalue")
    end,
  },
  {
    key = "SecureActionButtonTemplate",
    text = function()
      return Platform.CanCreateSecureTemplate("SecureActionButtonTemplate") and "creatable" or "not creatable"
    end,
  },
  {
    key = "SecureHandlerClickTemplate",
    text = function()
      return Platform.CanCreateSecureTemplate("SecureHandlerClickTemplate") and "creatable" or "not creatable"
    end,
  },
}

-- Runs the probe. Returns the lines, each `NN key=value`.
function Probe.Run()
  local lines = {}
  for index, item in ipairs(Probe.ITEMS) do
    local ok, text = pcall(item.text)
    lines[index] = ("%02d %s=%s"):format(index, item.key, ok and text or ("error: " .. tostring(text)))
  end
  return lines
end

local function itemName(item)
  local name = Platform.GetItemInfo(item.itemID)
  if name then
    return name
  end
  return item.link and item.link:match("%[(.-)%]") or HIDDEN
end

-- Lines for /ras debug bags: header, then one line per occupied slot.
function Probe.BagLines()
  local L = ns.L
  local items = Platform.GetBagItems()
  if #items == 0 then
    return { L["debug.bags.empty"] }
  end
  local lines = { L["debug.bags.header"]:format(#items) }
  for _, item in ipairs(items) do
    lines[#lines + 1] = ("bag=%d slot=%d itemID=%d count=%d name=%s"):format(
      item.bag,
      item.slot,
      item.itemID,
      item.stackCount,
      itemName(item)
    )
  end
  return lines
end

-- Lines for /ras debug spells: header, then one line per spellbook entry.
function Probe.SpellLines()
  local L = ns.L
  local entries = Platform.GetSpellBookEntries()
  if #entries == 0 then
    return { L["debug.spells.empty"] }
  end
  local lines = { L["debug.spells.header"]:format(#entries) }
  for _, entry in ipairs(entries) do
    lines[#lines + 1] = ("spellId=%d name=%s"):format(entry.spellId, entry.name or HIDDEN)
  end
  return lines
end

-- Seconds left on an aura, or nil when it has no expiration or the data is hidden. No division anywhere.
local function remaining(aura, now)
  if not aura.expirationTime or not now or aura.expirationTime <= 0 then
    return nil
  end
  return math.max(0, aura.expirationTime - now)
end

local function auraLine(aura, now)
  local name = aura.name
  if not name and aura.spellId then
    name = Platform.GetSpellInfo(aura.spellId)
  end
  local left = remaining(aura, now)
  return ("spellId=%s name=%s stacks=%s remaining=%s"):format(
    aura.spellId and tostring(aura.spellId) or HIDDEN,
    name or HIDDEN,
    aura.applications and tostring(aura.applications) or HIDDEN,
    left and ("%.1f"):format(left) or "none"
  )
end

local function auraSection(lines, header, auras, now)
  lines[#lines + 1] = header:format(#auras)
  for _, aura in ipairs(auras) do
    lines[#lines + 1] = auraLine(aura, now)
  end
end

-- Lines for /ras debug auras: the player's HELPFUL auras and the target's HARMFUL|PLAYER auras.
function Probe.AuraLines()
  local L = ns.L
  local now = Platform.GetTime()
  local lines = {}
  auraSection(lines, L["debug.auras.player"], Platform.GetAuras("player", "HELPFUL"), now)
  auraSection(lines, L["debug.auras.target"], Platform.GetAuras("target", "HARMFUL|PLAYER"), now)
  if #lines == 2 then
    lines[#lines + 1] = L["debug.auras.none"]
  end
  return lines
end

-- Lines for /ras debug selftest: which of Platform.REQUIRED_APIS are missing.
function Probe.SelfTest()
  local L = ns.L
  local missing = {}
  for _, group in ipairs(Platform.REQUIRED_APIS) do
    local found = false
    for _, path in ipairs(group) do
      found = found or Platform.Has(path)
    end
    if not found then
      missing[#missing + 1] = table.concat(group, " | ")
    end
  end
  if #missing == 0 then
    return { L["debug.selftest.ok"]:format(#Platform.REQUIRED_APIS) }
  end
  return { L["debug.selftest.missing"]:format(table.concat(missing, ", ")) }
end

ns.Probe = Probe
