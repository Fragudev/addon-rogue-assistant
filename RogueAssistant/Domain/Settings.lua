local _, ns = ...

-- Typed settings of one character profile (profile.settings). Every key has a default, a type and optional bounds;
-- Get/Set/Reset address a key by its dotted path ("alerts.expireMinutes").
local Settings = {}
Settings.__index = Settings

-- { path, default, type, min, max }. Later phases read these keys; tracker.groups is a placeholder for phase 3.
Settings.SCHEMA = {
  {
    path = "poison.position",
    default = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -150 },
    type = "table",
  },
  { path = "poison.scale", default = 1, type = "number", min = 0.5, max = 3 },
  { path = "poison.locked", default = true, type = "boolean" },
  { path = "alerts.expireMinutes", default = 5, type = "number", min = 0, max = 60 },
  { path = "alerts.charges", default = 20, type = "number", min = 0, max = 999 },
  { path = "alerts.stock", default = 5, type = "number", min = 0, max = 999 },
  { path = "alerts.triggers.instance", default = true, type = "boolean" },
  { path = "alerts.triggers.readycheck", default = true, type = "boolean" },
  { path = "alerts.triggers.combatEnd", default = true, type = "boolean" },
  { path = "tracker.groups", default = {}, type = "table" },
}

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
