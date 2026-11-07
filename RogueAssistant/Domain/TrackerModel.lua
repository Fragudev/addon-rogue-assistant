local _, ns = ...

-- The tracker groups and what they follow, persisted in settings ("tracker.groups", validated by Settings). Pure: the
-- only client question it asks is Platform.IsPlayerSpell, for visibility.
--
-- Group: { id, titleKey | title, kind, entries = { entry... }, iconSize, spacing, columns, growth, mode, scale,
--          alphaOutOfCombat, showWhenMissing, position }. Entry: see Data/Spells.lua. Layout fields that are absent
-- fall back to their defaults (TrackerModel.Layout), so a group saved by an older version keeps working.
--
-- Visibility rule: an entry is shown when the player knows any of its ids (Platform.IsPlayerSpell). Exceptions:
--   * entries the user added (custom) are always shown, the user asked for them;
--   * debuff entries marked `always` (poisons are items, not spells) are always shown;
--   * when the client cannot say (IsPlayerSpell is nil for every id) the entry is shown rather than hidden.
-- Whether an aura entry that is shown is also drawn while the aura is missing is up to the group (showWhenMissing).
local TrackerModel = {}
TrackerModel.__index = TrackerModel

local PATH = "tracker.groups"

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

-- The ids an entry matches: its rank list, or its primary id. Empty for an entry that only has a name.
function TrackerModel.EntryIds(entry)
  if entry.ids and #entry.ids > 0 then
    return entry.ids
  end
  if entry.spellId then
    return { entry.spellId }
  end
  return {}
end

-- What the spell API takes to name the entry: its id, or its name.
function TrackerModel.Identifier(entry)
  return entry.spellId or entry.name
end

-- The group's layout with every missing option replaced by its default.
function TrackerModel.Layout(group)
  local tracker = ns.Constants.TRACKER
  local layout = {}
  for key, bounds in pairs(tracker.LAYOUT) do
    layout[key] = group[key] ~= nil and group[key] or bounds[3]
  end
  layout.growth = group.growth or tracker.DEFAULT_GROWTH
  layout.mode = group.mode or tracker.DEFAULT_MODE
  layout.showWhenMissing = group.showWhenMissing or tracker.DEFAULT_MISSING
  return layout
end

-- The title to show: the user's own title, else the translated default.
function TrackerModel.Title(group, L)
  if group.title and group.title ~= "" then
    return group.title
  end
  if group.titleKey then
    return (L or ns.L)[group.titleKey]
  end
  return group.id
end

local function defaultGroups()
  local groups = {}
  for index, definition in ipairs(ns.Spells.GROUPS) do
    local group = copy(definition)
    local spot = ns.Constants.TRACKER.DEFAULT_POSITIONS[group.id] or { x = 0, y = 60 * (index - 1) }
    group.position = { point = "CENTER", relativePoint = "CENTER", x = spot.x, y = spot.y }
    groups[index] = group
  end
  return groups
end

-- deps: platform (default ns.Platform). `settings` is a Settings object of the profile. An empty or invalid saved list
-- is replaced by the default groups.
function TrackerModel.New(settings, deps)
  deps = deps or {}
  local self = setmetatable({
    settings = settings,
    platform = deps.platform or ns.Platform,
  }, TrackerModel)
  local groups = settings:Get(PATH)
  if type(groups) ~= "table" or #groups == 0 then
    settings:Set(PATH, defaultGroups())
  end
  return self
end

function TrackerModel:Groups()
  return self.settings:Get(PATH)
end

-- The group with that id, and its index.
function TrackerModel:Group(id)
  for index, group in ipairs(self:Groups()) do
    if group.id == id then
      return group, index
    end
  end
  return nil
end

-- Saves the current list through Settings (so it is validated). Returns false when it would be rejected.
function TrackerModel:Save()
  return (self.settings:Set(PATH, self:Groups()))
end

-- Visibility ----------------------------------------------------------------------------------------------------

function TrackerModel:IsVisible(entry, group)
  if entry.custom then
    return true
  end
  if group.kind == "debuff" and entry.always then
    return true
  end
  local ids = TrackerModel.EntryIds(entry)
  if #ids == 0 then
    return true
  end
  local answered = false
  for _, id in ipairs(ids) do
    local known = self.platform.IsPlayerSpell(id)
    if known == true then
      return true
    end
    if known ~= nil then
      answered = true
    end
  end
  return not answered
end

-- The entries of a group the player gets to see, in order.
function TrackerModel:VisibleEntries(groupId)
  local group = self:Group(groupId)
  local list = {}
  if not group then
    return list
  end
  for _, entry in ipairs(group.entries) do
    if self:IsVisible(entry, group) then
      list[#list + 1] = entry
    end
  end
  return list
end

-- Editing -------------------------------------------------------------------------------------------------------

local function sameEntry(entry, other)
  if entry.spellId and other.spellId then
    return entry.spellId == other.spellId
  end
  if entry.name and other.name then
    return entry.name:lower() == other.name:lower()
  end
  return false
end

-- Builds the entry for something the user typed: a spell id (number or digits) or a spell name. nil when it is neither.
local function entryFor(group, value)
  if type(value) == "string" then
    value = value:match("^%s*(.-)%s*$")
    value = tonumber(value) or value
  end
  local entry = { kind = group.kind, source = "user", custom = true }
  if type(value) == "number" then
    if value < 1 or value % 1 ~= 0 or value > 2 ^ 31 then
      return nil
    end
    entry.spellId = value
  elseif type(value) == "string" and value ~= "" then
    entry.name = value
    entry.byName = group.kind ~= "cooldown" or nil
  else
    return nil
  end
  return entry
end

-- Adds a spell by id or by name at the end of a group. Returns true and the entry, or false and a reason:
-- "unknown_group", "invalid", "duplicate" or "full".
function TrackerModel:AddEntry(groupId, value)
  local group = self:Group(groupId)
  if not group then
    return false, "unknown_group"
  end
  local entry = entryFor(group, value)
  if not entry then
    return false, "invalid"
  end
  for _, existing in ipairs(group.entries) do
    if sameEntry(existing, entry) then
      return false, "duplicate"
    end
  end
  if #group.entries >= ns.Constants.TRACKER.MAX_ENTRIES then
    return false, "full"
  end
  group.entries[#group.entries + 1] = entry
  self:Save()
  return true, entry
end

-- Removes the entry at `index`. Returns true, or false and "unknown_group" / "invalid".
function TrackerModel:RemoveAt(groupId, index)
  local group = self:Group(groupId)
  if not group then
    return false, "unknown_group"
  end
  if type(index) ~= "number" or not group.entries[index] then
    return false, "invalid"
  end
  table.remove(group.entries, index)
  self:Save()
  return true
end

-- Removes the entry for a spell id (number or digits) or name. Returns true, or false and a reason ("not_found").
function TrackerModel:Remove(groupId, value)
  local group = self:Group(groupId)
  if not group then
    return false, "unknown_group"
  end
  local probe = entryFor(group, value)
  if not probe then
    return false, "invalid"
  end
  for index, entry in ipairs(group.entries) do
    -- Also remove an entry that lists the id as one of its ranks.
    local matches = sameEntry(entry, probe)
    for _, id in ipairs(probe.spellId and entry.ids or {}) do
      matches = matches or id == probe.spellId
    end
    if matches then
      table.remove(group.entries, index)
      self:Save()
      return true
    end
  end
  return false, "not_found"
end

-- Moves the entry at `from` to position `to`. Returns true, or false and a reason.
function TrackerModel:Move(groupId, from, to)
  local group = self:Group(groupId)
  if not group then
    return false, "unknown_group"
  end
  local count = #group.entries
  if type(from) ~= "number" or type(to) ~= "number" or from < 1 or from > count or to < 1 or to > count then
    return false, "invalid"
  end
  if from ~= to then
    table.insert(group.entries, to, table.remove(group.entries, from))
    self:Save()
  end
  return true
end

local function layoutValid(key, value)
  local tracker = ns.Constants.TRACKER
  local bounds = tracker.LAYOUT[key]
  if bounds then
    return type(value) == "number" and value == value and value >= bounds[1] and value <= bounds[2]
  end
  if key == "growth" then
    return tracker.GROWTH[value] == true
  elseif key == "mode" then
    return tracker.MODES[value] == true
  elseif key == "showWhenMissing" then
    return tracker.MISSING[value] == true
  end
  return nil
end

-- Sets one layout option (iconSize, spacing, columns, growth, mode, scale, alphaOutOfCombat, showWhenMissing).
-- Returns true, or false and "unknown_group" / "unknown_option" / "invalid".
function TrackerModel:SetLayout(groupId, key, value)
  local group = self:Group(groupId)
  if not group then
    return false, "unknown_group"
  end
  local valid = layoutValid(key, value)
  if valid == nil then
    return false, "unknown_option"
  end
  if not valid then
    return false, "invalid"
  end
  group[key] = value
  self:Save()
  return true
end

-- Stores where the group sits: { point, relativePoint, x, y }.
function TrackerModel:SetPosition(groupId, position)
  local group = self:Group(groupId)
  if not group then
    return false, "unknown_group"
  end
  if
    type(position) ~= "table"
    or type(position.point) ~= "string"
    or type(position.relativePoint) ~= "string"
    or type(position.x) ~= "number"
    or type(position.y) ~= "number"
  then
    return false, "invalid"
  end
  group.position = {
    point = position.point,
    relativePoint = position.relativePoint,
    x = position.x,
    y = position.y,
  }
  self:Save()
  return true
end

-- Renames a group. An empty title goes back to the translated default.
function TrackerModel:SetTitle(groupId, title)
  local group = self:Group(groupId)
  if not group then
    return false, "unknown_group"
  end
  if type(title) ~= "string" then
    return false, "invalid"
  end
  group.title = title ~= "" and title or nil
  self:Save()
  return true
end

-- Restores one group (its entries, layout and position) to the defaults. Returns true, or false and "unknown_group".
function TrackerModel:ResetGroup(groupId)
  local _, index = self:Group(groupId)
  if not index then
    return false, "unknown_group"
  end
  for _, fresh in ipairs(defaultGroups()) do
    if fresh.id == groupId then
      self:Groups()[index] = fresh
      self:Save()
      return true
    end
  end
  -- A group the addon does not ship has no defaults to return to.
  return false, "no_default"
end

-- Restores every group to the defaults.
function TrackerModel:ResetAll()
  self.settings:Set(PATH, defaultGroups())
  return true
end

ns.TrackerModel = TrackerModel
