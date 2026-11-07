local _, ns = ...

-- Owner of RogueAssistantDB:
--   { schemaVersion,
--     profiles = { [guid] = { name, class, lastSeen, settings = {} } },
--     debug = { log = { lines }, lastProbe = { lines } } }
-- The character identity is the GUID; the name is only for display. Migrations are chained by `schemaVersion`.
local Store = {}
Store.__index = Store

local PROFILE_INFO = { "name", "class" }

local function ensureTable(parent, key)
  if type(parent[key]) ~= "table" then
    parent[key] = {}
  end
  return parent[key]
end

-- Each entry upgrades a db to that version; all of them must be idempotent. Exposed so tests can chain extras.
Store.MIGRATIONS = {
  -- v1: first layout (a missing or empty db is version 0).
  [1] = function(db)
    ensureTable(db, "profiles")
    local debug = ensureTable(db, "debug")
    ensureTable(debug, "log")
    ensureTable(debug, "lastProbe")
  end,
}

local function versionOf(db)
  local version = db.schemaVersion
  if type(version) == "number" and version >= 0 and version % 1 == 0 then
    return version
  end
  return 0
end

-- Opens (and migrates) the saved variable. `deps.now` returns the current time; `deps.version` overrides the target
-- schema (tests). Returns the store, or nil plus "newer_schema" when the data comes from a newer addon; the raw
-- table is then left untouched so the data survives a downgrade.
function Store.Open(db, deps)
  deps = deps or {}
  local target = deps.version or ns.Constants.SCHEMA_VERSION
  db = type(db) == "table" and db or {}

  local version = versionOf(db)
  if version > target then
    return nil, "newer_schema"
  end
  for step = version + 1, target do
    Store.MIGRATIONS[step](db)
  end
  db.schemaVersion = target

  return setmetatable({
    db = db,
    now = deps.now or function()
      return 0
    end,
  }, Store)
end

-- The raw saved table (assign it back to the saved variable if Open had to create it).
function Store:Db()
  return self.db
end

function Store:FindProfile(guid)
  return self.db.profiles[guid]
end

-- Returns the profile of a character, created on first use. `info` ({ name, class }) refreshes the display fields and
-- `lastSeen`. A missing or empty guid returns nil.
function Store:Profile(guid, info)
  if type(guid) ~= "string" or guid == "" then
    return nil
  end
  local profiles = self.db.profiles
  local profile = profiles[guid]
  if not profile then
    profile = {}
    profiles[guid] = profile
  end
  ensureTable(profile, "settings")
  if info then
    for _, field in ipairs(PROFILE_INFO) do
      if info[field] ~= nil then
        profile[field] = info[field]
      end
    end
  end
  profile.lastSeen = self.now()
  return profile
end

-- Removes a profile. Returns true when it existed.
function Store:Forget(guid)
  if self.db.profiles[guid] == nil then
    return false
  end
  self.db.profiles[guid] = nil
  return true
end

function Store:Debug()
  return self.db.debug
end

local function clip(text)
  text = tostring(text)
  local limit = ns.Constants.DEBUG_MAX_LINE_LENGTH
  if #text > limit then
    return text:sub(1, limit - 3) .. "..."
  end
  return text
end

-- Appends one line to the bounded debug log (the oldest lines are dropped).
function Store:Log(text)
  local log = self.db.debug.log
  log[#log + 1] = ("[%s] %s"):format(tostring(self.now()), clip(text))
  while #log > ns.Constants.DEBUG_MAX_LOG do
    table.remove(log, 1)
  end
end

-- Replaces the saved probe output with the last lines of `lines` (bounded).
function Store:SetLastProbe(lines)
  local saved = {}
  local first = math.max(1, #lines - ns.Constants.DEBUG_MAX_PROBE_LINES + 1)
  for index = first, #lines do
    saved[#saved + 1] = clip(lines[index])
  end
  self.db.debug.lastProbe = saved
end

ns.Store = Store
