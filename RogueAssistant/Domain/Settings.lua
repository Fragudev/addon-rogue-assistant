local _, ns = ...

-- Typed settings of one character profile (profile.settings). Every key has a default, a type and optional bounds;
-- Get/Set/Reset address a key by its dotted path ("alerts.expireMinutes").
local Settings = {}
Settings.__index = Settings

-- { path, default, type, min, max, check }. `check(value)` is an extra validator (tracker.groups is a list of groups).
Settings.SCHEMA = {
  {
    path = "poison.position",
    default = { point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = 200 },
    type = "table",
    check = function(value)
      return Settings.ValidPosition(value)
    end,
  },
  -- Just under the poison button (the button is 40 high and sits at BOTTOM 0, 200): the weapon status lines.
  {
    path = "poison.statusPosition",
    default = { point = "TOP", relativePoint = "BOTTOM", x = 0, y = 198 },
    type = "table",
    check = function(value)
      return Settings.ValidPosition(value)
    end,
  },
  { path = "poison.statusShown", default = true, type = "boolean" },
  {
    path = "poison.flyoutDirection",
    default = "UP",
    type = "string",
    check = function(value)
      return ns.Constants.FLYOUT_DIRECTIONS[value] == true
    end,
  },
  { path = "poison.scale", default = 1, type = "number", min = 0.5, max = 3 },
  { path = "poison.locked", default = true, type = "boolean" },
  {
    path = "alerts.position",
    default = { point = "TOP", relativePoint = "TOP", x = 0, y = -160 },
    type = "table",
    check = function(value)
      return Settings.ValidPosition(value)
    end,
  },
  { path = "alerts.expireMinutes", default = 5, type = "number", min = 0, max = 60 },
  { path = "alerts.charges", default = 20, type = "number", min = 0, max = 999 },
  { path = "alerts.stock", default = 5, type = "number", min = 0, max = 999 },
  { path = "alerts.triggers.instance", default = true, type = "boolean" },
  { path = "alerts.triggers.readycheck", default = true, type = "boolean" },
  { path = "alerts.triggers.combatEnd", default = true, type = "boolean" },
  {
    path = "tracker.groups",
    default = {},
    type = "table",
    check = function(value)
      return Settings.ValidGroups(value)
    end,
  },
}

local function isNumber(value, minimum, maximum)
  return type(value) == "number" and value == value and value >= minimum and value <= maximum
end

local function isId(value)
  return isNumber(value, 1, 2 ^ 31) and value % 1 == 0
end

-- true when `position` is { point, relativePoint, x, y } with anchor names and on-screen offsets.
function Settings.ValidPosition(position)
  return type(position) == "table"
    and type(position.point) == "string"
    and type(position.relativePoint) == "string"
    and isNumber(position.x, -10000, 10000)
    and isNumber(position.y, -10000, 10000)
end

local function validEntry(entry)
  if type(entry) ~= "table" then
    return false
  end
  local hasId, hasName = entry.spellId ~= nil, entry.name ~= nil
  if hasId == hasName then
    return false
  end
  if hasId and not isId(entry.spellId) then
    return false
  end
  if hasName and (type(entry.name) ~= "string" or entry.name == "") then
    return false
  end
  if entry.ids ~= nil then
    if type(entry.ids) ~= "table" then
      return false
    end
    for _, id in ipairs(entry.ids) do
      if not isId(id) then
        return false
      end
    end
  end
  for _, flag in ipairs({ "stacks", "byName", "always", "custom" }) do
    if entry[flag] ~= nil and type(entry[flag]) ~= "boolean" then
      return false
    end
  end
  return entry.source == nil or type(entry.source) == "string"
end

local function validLayout(group)
  local tracker = ns.Constants.TRACKER
  for key, bounds in pairs(tracker.LAYOUT) do
    if group[key] ~= nil and not isNumber(group[key], bounds[1], bounds[2]) then
      return false
    end
  end
  if group.growth ~= nil and not tracker.GROWTH[group.growth] then
    return false
  end
  if group.mode ~= nil and not tracker.MODES[group.mode] then
    return false
  end
  if group.showWhenMissing ~= nil and not tracker.MISSING[group.showWhenMissing] then
    return false
  end
  local position = group.position
  return position == nil or Settings.ValidPosition(position)
end

-- true when `groups` is a well-formed list of tracker groups: unique string ids, a known kind, valid entries and
-- layout options inside their bounds. Missing layout options are allowed (TrackerModel fills them in).
function Settings.ValidGroups(groups)
  local tracker = ns.Constants.TRACKER
  if type(groups) ~= "table" or #groups > tracker.MAX_GROUPS then
    return false
  end
  local seen = {}
  for _, group in ipairs(groups) do
    if type(group) ~= "table" or type(group.id) ~= "string" or group.id == "" or seen[group.id] then
      return false
    end
    seen[group.id] = true
    if not tracker.KINDS[group.kind] or type(group.entries) ~= "table" or #group.entries > tracker.MAX_ENTRIES then
      return false
    end
    if group.title ~= nil and type(group.title) ~= "string" then
      return false
    end
    if group.titleKey ~= nil and type(group.titleKey) ~= "string" then
      return false
    end
    for _, entry in ipairs(group.entries) do
      if not validEntry(entry) then
        return false
      end
    end
    if not validLayout(group) then
      return false
    end
  end
  return true
end

local byPath = {}
for _, entry in ipairs(Settings.SCHEMA) do
  byPath[entry.path] = entry
end

local function copy(value)
  if type(value) ~= "table" then
    return value
  end
  local result = {}
  for key, inner in pairs(value) do
    result[key] = copy(inner)
  end
  return result
end

local function split(path)
  local parts = {}
  for part in path:gmatch("[^.]+") do
    parts[#parts + 1] = part
  end
  return parts
end

-- The table that holds the last segment of `path`, created on the way when `create` is true.
local function parentOf(root, parts, create)
  local node = root
  for index = 1, #parts - 1 do
    local child = node[parts[index]]
    if type(child) ~= "table" then
      if not create then
        return nil
      end
      child = {}
      node[parts[index]] = child
    end
    node = child
  end
  return node, parts[#parts]
end

local function valid(entry, value)
  if type(value) ~= entry.type then
    return false
  end
  if entry.type == "number" then
    if value ~= value or (entry.min and value < entry.min) or (entry.max and value > entry.max) then
      return false
    end
  end
  if entry.check and not entry.check(value) then
    return false
  end
  return true
end

-- Wraps the `settings` table of a profile. Missing or wrongly typed values are replaced by their defaults.
function Settings.New(root)
  local self = setmetatable({ root = root }, Settings)
  for _, entry in ipairs(Settings.SCHEMA) do
    local parts = split(entry.path)
    local parent, key = parentOf(root, parts, true)
    if not valid(entry, parent[key]) then
      parent[key] = copy(entry.default)
    end
  end
  return self
end

-- The current value of a key, or nil for an unknown path.
function Settings:Get(path)
  if not byPath[path] then
    return nil
  end
  local parts = split(path)
  local parent, key = parentOf(self.root, parts, false)
  return parent and parent[key]
end

-- The default of a key (a fresh copy), or nil for an unknown path.
function Settings.Default(path)
  local entry = byPath[path]
  return entry and copy(entry.default)
end

-- Stores a value. Returns true, or false plus "unknown" / "invalid" when the key does not exist or the value has the
-- wrong type or is out of bounds. The stored value is never changed on failure.
function Settings:Set(path, value)
  local entry = byPath[path]
  if not entry then
    return false, "unknown"
  end
  if not valid(entry, value) then
    return false, "invalid"
  end
  local parent, key = parentOf(self.root, split(path), true)
  parent[key] = value
  return true
end

-- Puts one key (or every key when `path` is nil) back to its default. Returns false for an unknown path.
function Settings:Reset(path)
  if path == nil then
    for _, entry in ipairs(Settings.SCHEMA) do
      self:Reset(entry.path)
    end
    return true
  end
  local entry = byPath[path]
  if not entry then
    return false
  end
  local parent, key = parentOf(self.root, split(path), true)
  parent[key] = copy(entry.default)
  return true
end

ns.Settings = Settings
