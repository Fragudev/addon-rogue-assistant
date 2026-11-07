local _, ns = ...

-- Flat icon states for the tracker. No frames: the platform seam comes in through `deps.platform`.
--
-- State of one icon: { key, spellId, name, icon, kind, start, duration, durationObject, stacks, stacksText,
--   maxCharges, active, ready, hidden, dim }.
--   start, duration  numbers the client let us read (an ability cooldown or an aura timer); never secret.
--   durationObject   the raw duration object of the cooldown or aura, only for a Cooldown widget. It is never
--                    inspected here (it may be secret): the code only tests it for nil.
--   stacks           readable stack or charge count; stacksText is the client's formatted count, only for SetText.
--   active           cooldown: on cooldown; aura: present. nil when unknown (secret).
--   ready            cooldown only: true when readable and not on cooldown. Never true on a guess.
--   hidden           nothing safe to show exists: the icon is drawn with a "hidden" overlay and no number.
--   dim              the aura is missing and the group dims instead of hiding.
local ViewModel = {}

-- The id used to ask the client about an entry: the highest rank the player knows, else the primary id.
function ViewModel.ActiveId(entry, platform)
  local ids = ns.TrackerModel.EntryIds(entry)
  for index = #ids, 1, -1 do
    if platform.IsPlayerSpell(ids[index]) == true then
      return ids[index]
    end
  end
  return entry.spellId
end

local function newState(entry, platform)
  local identifier = ViewModel.ActiveId(entry, platform) or ns.TrackerModel.Identifier(entry)
  local name, icon = platform.GetSpellInfo(identifier)
  return {
    key = tostring(ns.TrackerModel.Identifier(entry)),
    spellId = entry.spellId,
    name = name or entry.name,
    icon = icon,
    kind = entry.kind,
  },
    identifier
end

-- Cooldown ------------------------------------------------------------------------------------------------------

local function cooldownState(entry, platform)
  local state, id = newState(entry, platform)
  local start, duration = platform.GetSpellCooldown(id)
  if start and duration then
    -- Readable: the numbers drive the widget and `ready` is a fact.
    local onCooldown = start > 0 and duration > ns.Constants.TRACKER.GCD_SECONDS
    state.active = onCooldown
    state.ready = not onCooldown
    if onCooldown then
      state.start, state.duration = start, duration
    end
  else
    -- Secret or unavailable: only a duration object can still drive the widget.
    local object = platform.GetSpellCooldownDurationObject(id)
    if object ~= nil then
      state.durationObject = object
      state.ready = false
    else
      state.hidden = true
      state.ready = false
    end
  end
  local current, maxCharges = platform.GetSpellCharges(id)
  if maxCharges and maxCharges > 1 then
    state.maxCharges = maxCharges
    if current then
      state.stacks = current
      if current > 0 then
        state.ready, state.active = true, false
      end
    end
  end
  return state
end

-- Auras ---------------------------------------------------------------------------------------------------------

local function unreadable(aura)
  return aura.spellId == nil and aura.name == nil
end

local function idSet(entry)
  local set = {}
  for _, id in ipairs(ns.TrackerModel.EntryIds(entry)) do
    set[id] = true
  end
  return set
end

local function matches(aura, ids, name)
  if aura.spellId and ids[aura.spellId] then
    return true
  end
  return name ~= nil and aura.name == name
end

-- Fills the timer and the stacks of a state from the matched aura.
local function applyAura(state, entry, aura, unit, platform)
  state.active = true
  state.icon = state.icon or aura.icon
  if aura.duration and aura.expirationTime then
    if aura.duration > 0 then
      state.start, state.duration = aura.expirationTime - aura.duration, aura.duration
    end
  elseif aura.auraInstanceID then
    state.durationObject = platform.GetAuraDurationObject(unit, aura.auraInstanceID)
  end
  if entry.stacks then
    if aura.applications and aura.applications > 1 then
      state.stacks = aura.applications
    elseif aura.applications == nil and aura.auraInstanceID then
      state.stacksText = platform.GetAuraApplicationDisplayCount(unit, aura.auraInstanceID, 2)
    end
  end
end

-- Every aura of a (unit, filter) pair, scanned once per refresh: `cache` is the per-refresh table.
local function scan(platform, unit, filter, cache)
  local key = unit .. "|" .. filter
  local list = cache[key]
  if not list then
    list = platform.GetAuras(unit, filter)
    cache[key] = list
  end
  return list
end

local function auraState(entry, platform, cache)
  local state = newState(entry, platform)
  local source = ns.Constants.TRACKER.AURA_SOURCE[entry.kind]
  local ids = idSet(entry)
  -- Entries matched by name use the name of the spell (or the typed name).
  local name = entry.byName and (state.name or entry.name) or nil
  local found, blind = nil, false
  for _, aura in ipairs(scan(platform, source.unit, source.filter, cache)) do
    if matches(aura, ids, name) then
      found = aura
      break
    end
    blind = blind or unreadable(aura)
  end
  if not found and entry.kind == "buff" then
    for id in pairs(ids) do
      found = found or platform.GetPlayerAura(id)
    end
  end
  if found then
    applyAura(state, entry, found, source.unit, platform)
  elseif blind or not platform.Has("C_UnitAuras.GetAuraDataByIndex") then
    -- The auras exist but their identity is secret (or the API is missing): never guess.
    state.hidden = true
  else
    state.active = false
  end
  return state
end

-- Group ---------------------------------------------------------------------------------------------------------

-- The state of one entry. deps: platform, auraCache (a table shared by every entry of one refresh; a private one is
-- used when absent).
function ViewModel.Entry(entry, deps)
  local platform = deps and deps.platform or ns.Platform
  if entry.kind == "cooldown" then
    return cooldownState(entry, platform)
  end
  return auraState(entry, platform, deps and deps.auraCache or {})
end

-- The icons of a group, in order: `entries` are the visible ones (TrackerModel:VisibleEntries). An aura that is
-- missing is left out when the group hides missing auras, and marked `dim` when it dims them.
function ViewModel.Group(group, entries, deps)
  local layout = ns.TrackerModel.Layout(group)
  local states = {}
  deps = { platform = deps and deps.platform, auraCache = deps and deps.auraCache or {} }
  for _, entry in ipairs(entries) do
    local state = ViewModel.Entry(entry, deps)
    if state.active == false and state.kind ~= "cooldown" then
      if layout.showWhenMissing == "hide" then
        state = nil
      else
        state.dim = true
      end
    end
    if state then
      states[#states + 1] = state
    end
  end
  return states
end

-- true when the state carries numbers a bar can be filled from (a secret or object-driven state cannot).
function ViewModel.CanShowBar(state)
  return state.start ~= nil and state.duration ~= nil and state.durationObject == nil and not state.hidden
end

-- Seconds left of a readable timer, clamped to its duration; nil when the state has no readable timer.
function ViewModel.Remaining(state, now)
  if not ViewModel.CanShowBar(state) or type(now) ~= "number" then
    return nil
  end
  local left = state.start + state.duration - now
  if left < 0 then
    return 0
  end
  if left > state.duration then
    return state.duration
  end
  return left
end

-- Fraction of the timer left (0..1), nil when unreadable. Guards the division.
function ViewModel.Fraction(state, now)
  local left = ViewModel.Remaining(state, now)
  if not left or state.duration <= 0 then
    return nil
  end
  return left / state.duration
end

-- Short text of a number of seconds: "45", "1:05", "12m".
function ViewModel.TimeText(seconds)
  if seconds >= 3600 then
    return ("%dh"):format(math.ceil(seconds / 3600))
  elseif seconds >= 600 then
    return ("%dm"):format(math.ceil(seconds / 60))
  elseif seconds >= 60 then
    return ("%d:%02d"):format(math.floor(seconds / 60), math.floor(seconds % 60))
  end
  return ("%d"):format(math.ceil(seconds))
end

-- Position of every slot inside a group box. `layout` is TrackerModel.Layout; item sizes are in pixels. Returns
-- { slots = { { x, y }... }, width, height } with (x, y) the offset of the slot TOPLEFT from the box TOPLEFT
-- (y grows upward, so it is zero or negative). `columns` is how many slots fit on a line along the growth direction.
function ViewModel.Layout(count, layout, itemWidth, itemHeight)
  if count < 1 then
    return { slots = {}, width = itemWidth, height = itemHeight }
  end
  local perLine = math.min(layout.columns, count)
  local lines = math.ceil(count / layout.columns)
  local stepX, stepY = itemWidth + layout.spacing, itemHeight + layout.spacing
  local growth = layout.growth
  local horizontal = growth == "RIGHT" or growth == "LEFT"
  local slots = {}
  for index = 1, count do
    local line = math.floor((index - 1) / layout.columns)
    local column = (index - 1) % layout.columns
    if growth == "LEFT" or growth == "UP" then
      column = perLine - 1 - column
    end
    if horizontal then
      slots[index] = { x = column * stepX, y = -line * stepY }
    else
      slots[index] = { x = line * stepX, y = -column * stepY }
    end
  end
  local across, along = perLine, lines
  if not horizontal then
    across, along = lines, perLine
  end
  return {
    slots = slots,
    width = across * stepX - layout.spacing,
    height = along * stepY - layout.spacing,
  }
end

ns.ViewModelTracker = ViewModel
