local _, ns = ...

-- Text the player reads. Locale files register their strings; a lookup reads the active locale, then enUS, then the
-- key itself, so a missing string never breaks anything. esMX uses esES; any other client locale uses enUS.
local Locale = {}

local DEFAULT = "enUS"
local ALIASES = { esMX = "esES" }

local tables = {}
local current = DEFAULT

function Locale.Register(code, strings)
  local target = tables[code] or {}
  tables[code] = target
  for key, text in pairs(strings) do
    target[key] = text
  end
end

-- Chooses the active locale from a client locale code and returns the one in use.
function Locale.Use(code)
  code = ALIASES[code] or code
  if tables[code] then
    current = code
  else
    current = DEFAULT
  end
  return current
end

function Locale.Current()
  return current
end

-- The text of `key`, formatted with the extra arguments when there are any.
function Locale.Text(key, ...)
  local active = tables[current]
  local fallback = tables[DEFAULT]
  local text = (active and active[key]) or (fallback and fallback[key]) or key
  if select("#", ...) > 0 then
    return string.format(text, ...)
  end
  return text
end

ns.Locale = Locale
ns.L = Locale.Text
