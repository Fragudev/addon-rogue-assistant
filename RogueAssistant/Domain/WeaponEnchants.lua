local _, ns = ...

-- What is on a weapon, as the rows under its button: a poison and a stone (or weightstone, or oil) can sit on the same
-- weapon on Forever. Measured: GetWeaponEnchantInfo reports only the poison, and the weapon tooltip lists both with
-- their time left ("Weighted +6 (30 min)", "Instant Poison (28 min) (60 Charges)"). Both are combined here.
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

-- The temporary enchants of a weapon tooltip: { name, seconds, charges } for each line with a time left. Measured on
-- Forever: "Weighted +6 (30 min)" and "Instant Poison (28 min) (60 Charges)"; only poisons show charges.
function WeaponEnchants.ParseTooltip(lines, units)
  local enchants = {}
  for _, line in ipairs(lines or {}) do
    local init = 1
    while true do
      local first, last, amount, word = line:find(" %((%d+) ([^%)]+)%)", init)
      if not first then
        break
      end
      local rest = line:sub(last + 1)
      local charges = rest:match("^ %((%d+) [^%)]+%)$")
      if units[word] and first > 1 and (rest == "" or charges) then
        enchants[#enchants + 1] = {
          name = line:sub(1, first - 1),
          seconds = tonumber(amount) * units[word],
          charges = charges and tonumber(charges) or nil,
        }
        break
      end
      init = last + 1
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

-- The kind of a tooltip line: a poison when it shows charges or its text is a poison item name, a stone otherwise.
local function lineKind(line, options)
  if line.charges or options.poisonNames[line.name] then
    return "poison"
  end
  return "stone"
end

-- The rows of a weapon, poison first: { kind = "poison"|"stone", seconds, charges }.
--   enchant   entry of Api.GetWeaponEnchants, or nil
--   tooltip   result of ParseTooltip
--   options   { enchants = enchantID -> itemID, poisonNames = item name -> true }
-- Each tooltip line gives the row of its kind. The API enchant (on Forever, the poison) replaces the row of its kind
-- with its exact time and charges.
function WeaponEnchants.Rows(enchant, tooltip, options)
  local byKind = {}
  for _, line in ipairs(tooltip or {}) do
    local kind = lineKind(line, options)
    if byKind[kind] then
      kind = other(kind)
    end
    byKind[kind] = byKind[kind] or { kind = kind, seconds = line.seconds, charges = line.charges }
  end
  if enchant and enchant.active then
    local kind = apiKind(enchant, options)
    local row = { kind = kind, seconds = enchant.ms and math.floor(enchant.ms / 1000) or nil }
    if kind == "poison" and enchant.charges and enchant.charges > 0 then
      row.charges = enchant.charges
    end
    byKind[kind] = row
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
