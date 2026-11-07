local _, ns = ...

-- Translation of the text the player reads. Every locale keeps one table of key -> text; ns.L reads the active
-- locale first, then enUS, then falls back to the key itself, so a missing entry never breaks anything.
--   * Locale files (Locales/*.lua) add their strings with Locale.Register(code, { [key] = text }).
--   * esMX has no table of its own: it uses esES. Any other client locale uses enUS.
--   * The locale is chosen at load from GetLocale() (guarded), and tests can switch it with Locale.Use(code).
local Locale = {}

local DEFAULT = "enUS"
local ALIASES = { esMX = "esES" }

-- Locales that have a table of strings.
Locale.CODES = { "enUS", "esES" }
Locale.DEFAULT = DEFAULT

local tables = {}
local current = DEFAULT

local function isSupported(code)
  for _, supported in ipairs(Locale.CODES) do
    if supported == code then
      return true
    end
  end
  return false
end

-- The locale whose strings serve a client locale code ("esMX" -> "esES", unknown -> "enUS").
function Locale.Resolve(code)
  code = ALIASES[code] or code
  if isSupported(code) then
    return code
  end
  return DEFAULT
end

-- The table of strings of one locale (created empty on first use).
function Locale.Get(code)
  local strings = tables[code]
  if not strings then
    strings = {}
    tables[code] = strings
  end
  return strings
end

function Locale.Register(code, strings)
  local target = Locale.Get(code)
  for key, text in pairs(strings) do
    target[key] = text
  end
end

-- Chooses the active locale from a client locale code and returns the one in use.
function Locale.Use(code)
  current = Locale.Resolve(code)
  return current
end

function Locale.Current()
  return current
end

ns.L = setmetatable({}, {
  __index = function(_, key)
    local text = Locale.Get(current)[key]
    if text == nil then
      text = Locale.Get(DEFAULT)[key]
    end
    if text == nil then
      return key
    end
    return text
  end,
})

local function clientLocale()
  if type(GetLocale) ~= "function" then
    return nil
  end
  local ok, code = pcall(GetLocale)
  if ok then
    return code
  end
  return nil
end

Locale.Use(clientLocale())

ns.Locale = Locale
