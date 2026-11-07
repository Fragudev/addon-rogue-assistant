local _, ns = ...

-- Logic of the options panel, free of frames: every control reads and writes through here. Changes go to Settings (or
-- the TrackerModel) and then to a refresh callback, so the panel never owns state. Methods that can fail return
-- `ok, message`: the message is already translated and meant to be shown next to the control.
local ViewModel = {}
ViewModel.__index = ViewModel

-- The settings the panel edits, in the order they are shown.
ViewModel.POISON_NUMBERS = { "poison.scale" }
ViewModel.POISON_FLAGS = { "poison.locked" }
ViewModel.ALERT_NUMBERS = { "alerts.expireMinutes", "alerts.charges", "alerts.stock" }
ViewModel.ALERT_TRIGGERS = { "alerts.triggers.instance", "alerts.triggers.readycheck", "alerts.triggers.combatEnd" }

-- The cycle values of the choice options.
ViewModel.GROWTH = { "RIGHT", "LEFT", "UP", "DOWN" }
ViewModel.MODES = { "icons", "bars" }
ViewModel.MISSING = { "hide", "dim" }

-- Layout options edited with a slider, and the ones whose value is a whole number.
ViewModel.LAYOUT_NUMBERS = { "iconSize", "spacing", "columns", "scale", "alphaOutOfCombat" }
local WHOLE = { iconSize = true, spacing = true, columns = true }

local ALERT_WHOLE = { ["alerts.expireMinutes"] = true, ["alerts.charges"] = true, ["alerts.stock"] = true }

-- deps: settings, model (TrackerModel), platform, L, refreshTracker(), refreshPoison().
function ViewModel.New(deps)
  return setmetatable({
    settings = deps.settings,
    model = deps.model,
    platform = deps.platform or ns.Platform,
    L = deps.L or ns.L,
    refreshTracker = deps.refreshTracker or function() end,
    refreshPoison = deps.refreshPoison or function() end,
  }, ViewModel)
end

local REASONS = {
  invalid = "options.error.invalid",
  duplicate = "options.error.duplicate",
  full = "options.error.full",
  unknown_group = "options.error.unknown_group",
  unknown_option = "options.error.unknown_option",
  not_found = "options.error.not_found",
  no_default = "options.error.no_default",
}

-- The translated sentence for a failure reason of Settings or TrackerModel.
function ViewModel:Reason(reason)
  return self.L[REASONS[reason] or "options.error.invalid"]
end

-- Bounds and defaults -------------------------------------------------------------------------------------------

-- minimum, maximum of a setting path ("poison.scale") or, for a tracker layout key ("iconSize"), of that option.
function ViewModel.Bounds(key)
  local bounds = ns.Constants.TRACKER.LAYOUT[key]
  if bounds then
    return bounds[1], bounds[2]
  end
  for _, entry in ipairs(ns.Settings.SCHEMA) do
    if entry.path == key then
      return entry.min, entry.max
    end
  end
  return nil
end

-- Slider step of a number option.
function ViewModel.Step(key)
  if WHOLE[key] or ALERT_WHOLE[key] then
    return 1
  end
  return 0.05
end

-- Snaps a slider value to its step; fractions keep two decimals so 0.7 stays 0.7.
local function round(value, step)
  local snapped = math.floor(value / step + 0.5) * step
  return tonumber(("%.2f"):format(snapped))
end

-- Settings ------------------------------------------------------------------------------------------------------

function ViewModel:Get(path)
  return self.settings:Get(path)
end

-- Stores one poison or alert setting. Numbers are snapped to the slider step first. Returns true, or false plus the
-- reason sentence. A poison button change made in combat is stored, then applied by the button after combat; the
-- second result says so.
function ViewModel:Set(path, value)
  if type(value) == "number" then
    value = round(value, ViewModel.Step(path))
  end
  local ok, reason = self.settings:Set(path, value)
  if not ok then
    return false, self:Reason(reason)
  end
  if path:sub(1, 7) == "poison." then
    self.refreshPoison()
    if self.platform.InCombatLockdown() == true then
      return true, self.L["options.deferred"]
    end
  end
  return true
end

-- Puts the poison button back at its default position.
function ViewModel:ResetPoisonPosition()
  self.settings:Reset("poison.position")
  self.refreshPoison()
  if self.platform.InCombatLockdown() == true then
    return true, self.L["options.deferred"]
  end
  return true
end

-- Tracker -------------------------------------------------------------------------------------------------------

-- { { id, title }... } in display order.
function ViewModel:Groups()
  local list = {}
  for _, group in ipairs(self.model:Groups()) do
    list[#list + 1] = { id = group.id, title = ns.TrackerModel.Title(group, self.L) }
  end
  return list
end

-- The effective layout of a group (defaults filled in), or nil for an unknown group.
function ViewModel:Layout(groupId)
  local group = self.model:Group(groupId)
  return group and ns.TrackerModel.Layout(group)
end

-- Sets one layout option and redraws the tracker. Returns true, or false plus the reason sentence.
function ViewModel:SetLayout(groupId, key, value)
  if type(value) == "number" then
    value = round(value, WHOLE[key] and 1 or 0.05)
  end
  local ok, reason = self.model:SetLayout(groupId, key, value)
  if not ok then
    return false, self:Reason(reason)
  end
  self.refreshTracker()
  return true
end

-- The value after `current` in `list`, wrapping around.
function ViewModel.Next(list, current)
  for index, value in ipairs(list) do
    if value == current then
      return list[index % #list + 1]
    end
  end
  return list[1]
end

-- Moves a choice option (growth, mode, showWhenMissing) to its next value.
function ViewModel:Cycle(groupId, key)
  local lists = { growth = ViewModel.GROWTH, mode = ViewModel.MODES, showWhenMissing = ViewModel.MISSING }
  local layout = self:Layout(groupId)
  if not layout or not lists[key] then
    return false, self:Reason(layout and "unknown_option" or "unknown_group")
  end
  return self:SetLayout(groupId, key, ViewModel.Next(lists[key], layout[key]))
end

-- The text of one entry: its name (or the client's name for its id) and its id.
function ViewModel:EntryText(entry)
  local name = entry.name
  if not name and entry.spellId then
    name = self.platform.GetSpellInfo(entry.spellId) or self.L["options.entry.unknown"]
  end
  if entry.spellId then
    return ("%s (%d)"):format(name, entry.spellId)
  end
  return name
end

-- The rows of the entry list of a group: { index, text, custom, canUp, canDown }.
function ViewModel:Entries(groupId)
  local group = self.model:Group(groupId)
  local rows = {}
  if not group then
    return rows
  end
  local count = #group.entries
  for index, entry in ipairs(group.entries) do
    rows[index] = {
      index = index,
      text = self:EntryText(entry),
      custom = entry.custom == true,
      canUp = index > 1,
      canDown = index < count,
    }
  end
  return rows
end

-- Adds the spell the user typed (an id or a name). Returns true plus a confirmation, or false plus the reason.
function ViewModel:AddEntry(groupId, text)
  local ok, result = self.model:AddEntry(groupId, text)
  if not ok then
    return false, self:Reason(result)
  end
  self.refreshTracker()
  return true, self.L["options.added"]:format(self:EntryText(result))
end

function ViewModel:RemoveEntry(groupId, index)
  local ok, reason = self.model:RemoveAt(groupId, index)
  if not ok then
    return false, self:Reason(reason)
  end
  self.refreshTracker()
  return true
end

-- Moves an entry up (delta -1) or down (delta 1) within its group.
function ViewModel:MoveEntry(groupId, index, delta)
  local ok, reason = self.model:Move(groupId, index, index + delta)
  if not ok then
    return false, self:Reason(reason)
  end
  self.refreshTracker()
  return true
end

function ViewModel:ResetGroup(groupId)
  local ok, reason = self.model:ResetGroup(groupId)
  if not ok then
    return false, self:Reason(reason)
  end
  self.refreshTracker()
  return true
end

function ViewModel:ResetAll()
  self.model:ResetAll()
  self.refreshTracker()
  return true
end

ns.ViewModelOptions = ViewModel
