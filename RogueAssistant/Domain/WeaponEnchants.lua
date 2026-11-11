local _, ns = ...

-- What is on a weapon, as the rows under its button: a poison and a stone (or weightstone, or oil) can sit on the same
-- weapon on Forever. GetWeaponEnchantInfo reports one enchant per hand; the weapon tooltip lists every temporary
-- enchant with its time left ("Instant Poison VI (30 min)", "Sharpened (+8 Damage) (25 min)"). Both are combined here.
-- How the client reports both enchants is not measured yet (docs/API_NOTES.md).
local WeaponEnchants = {}

local Items = ns.Items

-- Seconds per unit, in the order of the client strings ITEM_ENCHANT_TIME_LEFT_HOURS, _MIN and _SEC.
local MULTIPLIERS = { 3600, 60, 1 }
local FALLBACK_UNITS = { hour = 3600, hours = 3600, hr = 3600, hrs = 3600, min = 60, sec = 1 }

-- unit word -> seconds, from the client's "%s (%d min)" strings (with "|4singular:plural;" grammar). Falls back to the
-- English words when none can be read.
function WeaponEnchants.Units(formats)
  local units, found = {}, false
  for index, multiplier in ipairs(MULTIPLIERS) do
    local format = formats[index]
    local inner = type(format) == "string" and format:match("^%%s %(%%d (.+)%)$")
    if inner then
      local singular, plural = inner:match("^|4(.-):(.-);$")
      for _, word in ipairs(singular and { singular, plural } or { inner }) do
        units[word] = multiplier
        found = true
      end
    end
  end
  if not found then
    for word, seconds in pairs(FALLBACK_UNITS) do
      units[word] = seconds
    end
  end
  return units
end

-- The temporary enchants of a weapon tooltip: { name, seconds } for each line ending in a time left.
function WeaponEnchants.ParseTooltip(lines, units)
  local enchants = {}
  for _, line in ipairs(lines or {}) do
    local name, amount, word = line:match("^(.-) %((%d+) ([^%)]+)%)$")
    if name and units[word] then
      enchants[#enchants + 1] = { name = name, seconds = tonumber(amount) * units[word] }
    end
  end
  return enchants
end

local function other(kind)
  return kind == "poison" and "stone" or "poison"
end

-- The kind of the API enchant: the item the addon learned for it, else a poison when it has charges (stones have none).
local function apiKind(enchant, options)
  local itemID = enchant.enchantID and options.enchants[enchant.enchantID]
  local entry = itemID and Items.BY_ID[itemID]
  if entry then
    return entry.kind == "poison" and "poison" or "stone"
  end
  if enchant.charges and enchant.charges > 0 then
    return "poison"
  end
  return "stone"
end

local function nameKind(name, options)
  return options.poisonNames[name] and "poison" or "stone"
end

-- Of two or more tooltip enchants, the one that is not the API enchant of `kind` and `seconds`.
local function otherLine(tooltip, kind, seconds, options)
  local apiLine
  for _, line in ipairs(tooltip) do
    if nameKind(line.name, options) == "poison" then
      apiLine = kind == "poison" and line or nil
      if kind ~= "poison" then
        return line
      end
    end
  end
  if not apiLine then
    local best
    for _, line in ipairs(tooltip) do
      local distance = math.abs(line.seconds - (seconds or line.seconds))
      if not best or distance < best then
        best, apiLine = distance, line
      end
    end
  end
  for _, line in ipairs(tooltip) do
    if line ~= apiLine then
      return line
    end
  end
  return nil
end

-- The rows of a weapon, poison first: { kind = "poison"|"stone", seconds, charges }.
--   enchant   entry of Api.GetWeaponEnchants, or nil
--   tooltip   result of ParseTooltip
--   options   { enchants = enchantID -> itemID, poisonNames = item name -> true }
function WeaponEnchants.Rows(enchant, tooltip, options)
  tooltip = tooltip or {}
  local byKind = {}
  if enchant and enchant.active then
    local kind = apiKind(enchant, options)
    local seconds = enchant.ms and math.floor(enchant.ms / 1000) or nil
    local row = { kind = kind, seconds = seconds }
    if kind == "poison" and enchant.charges and enchant.charges > 0 then
      row.charges = enchant.charges
    end
    byKind[kind] = row
    if #tooltip >= 2 then
      local line = otherLine(tooltip, kind, seconds, options)
      if line then
        byKind[other(kind)] = { kind = other(kind), seconds = line.seconds }
      end
    end
  else
    for _, line in ipairs(tooltip) do
      local kind = nameKind(line.name, options)
      if byKind[kind] then
        kind = other(kind)
      end
      byKind[kind] = byKind[kind] or { kind = kind, seconds = line.seconds }
    end
  end
  local rows = {}
  for _, kind in ipairs({ "poison", "stone" }) do
    if byKind[kind] then
      rows[#rows + 1] = byKind[kind]
    end
  end
  return rows
end

ns.WeaponEnchants = WeaponEnchants
