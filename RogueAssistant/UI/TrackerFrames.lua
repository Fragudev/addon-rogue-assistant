-- luacheck: ignore 212/self
local _, ns = ...

-- The tracker on screen: one plain (non-secure) container per group, with one slot per icon state from
-- ViewModelTracker. A slot is an icon with a Cooldown widget (Blizzard's own countdown numbers stay on, so a duration
-- object keeps counting down without the addon ever reading it), a stack text, an own glow and, in bar mode, a
-- StatusBar. Secret values only travel through Platform wrappers into widget methods; nothing here compares them.
--
-- Updates are coalesced: events only mark the tracker dirty and the next OnUpdate (once per frame) redraws everything.
local TrackerFrames = {}
TrackerFrames.__index = TrackerFrames

local HANDLE_HEIGHT = 16
local HANDLE_WIDTH = 140
local DIM_ALPHA = 0.4
local HIDDEN_ALPHA = 0.6
local BAR_TEXTURE = "Interface\\Buttons\\WHITE8X8"

local EVENTS = {
  "SPELL_UPDATE_COOLDOWN",
  "SPELL_UPDATE_CHARGES",
  "UNIT_AURA",
  "PLAYER_TARGET_CHANGED",
  "SPELLS_CHANGED",
  "PLAYER_REGEN_ENABLED",
  "PLAYER_REGEN_DISABLED",
}

local AURA_UNITS = { player = true, target = true }

-- deps: model (TrackerModel), bus, platform, viewModel, L.
function TrackerFrames.New(deps)
  return setmetatable({
    model = deps.model,
    bus = deps.bus,
    platform = deps.platform or ns.Platform,
    viewModel = deps.viewModel or ns.ViewModelTracker,
    L = deps.L or ns.L,
    groups = {},
    dirty = false,
    unlocked = false,
    inCombat = false,
    elapsed = 0,
    refreshes = 0,
  }, TrackerFrames)
end

-- Frames ---------------------------------------------------------------------------------------------------------

function TrackerFrames:CreateSlot(parent)
  local slot = CreateFrame("Frame", nil, parent)
  slot.icon = slot:CreateTexture(nil, "ARTWORK")
  slot.icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 0, 0)
  slot.glow = slot:CreateTexture(nil, "BACKGROUND")
  slot.glow:SetColorTexture(1, 0.96, 0.41, 0.6)
  slot.glow:Hide()
  slot.cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
  slot.cooldown:SetHideCountdownNumbers(false)
  slot.count = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  slot.count:SetPoint("BOTTOMRIGHT", slot.icon, "BOTTOMRIGHT", -2, 2)
  slot.hiddenMark = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  slot.hiddenMark:SetPoint("CENTER", slot.icon, "CENTER", 0, 0)
  slot.hiddenMark:SetText(self.L["tracker.hidden.mark"])
  slot.hiddenMark:Hide()
  slot.bar = CreateFrame("StatusBar", nil, slot)
  slot.bar:SetMinMaxValues(0, 1)
  slot.bar:Hide()
  slot.bar:SetStatusBarTexture(BAR_TEXTURE)
  slot.bar:SetStatusBarColor(0.9, 0.8, 0.2, 0.9)
  slot.barText = slot.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  slot.barText:SetPoint("RIGHT", slot.bar, "RIGHT", -2, 0)
  slot:EnableMouse(self.unlocked)
  slot:SetScript("OnEnter", function()
    self:ShowTooltip(slot)
  end)
  slot:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  return slot
end

function TrackerFrames:ShowTooltip(slot)
  local state = slot.state
  if not state or not GameTooltip then
    return
  end
  GameTooltip:SetOwner(slot, "ANCHOR_RIGHT")
  GameTooltip:SetText(state.name or state.key)
  if state.hidden then
    GameTooltip:AddLine(self.L["tracker.hidden.tip"], 1, 1, 1, true)
  end
  GameTooltip:Show()
end

function TrackerFrames:CreateHandle(container, group)
  local handle = CreateFrame("Frame", nil, container)
  handle:SetSize(HANDLE_WIDTH, HANDLE_HEIGHT)
  handle:SetPoint("BOTTOMLEFT", container, "TOPLEFT", 0, 2)
  handle.background = handle:CreateTexture(nil, "BACKGROUND")
  handle.background:SetAllPoints(handle)
  handle.background:SetColorTexture(1, 0.96, 0.41, 0.35)
  handle.label = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  handle.label:SetPoint("LEFT", handle, "LEFT", 4, 0)
  handle:EnableMouse(true)
  handle:RegisterForDrag("LeftButton")
  handle:SetScript("OnDragStart", function()
    self:OnDragStart(group.id)
  end)
  handle:SetScript("OnDragStop", function()
    self:OnDragStop(group.id)
  end)
  handle:Hide()
  return handle
end

-- Creates the container (and its drag handle) of a group once.
function TrackerFrames:Container(group)
  local record = self.groups[group.id]
  if record then
    return record
  end
  local container = CreateFrame("Frame", "RogueAssistantTracker_" .. group.id, UIParent)
  container:SetFrameStrata("MEDIUM")
  container:SetClampedToScreen(true)
  container:SetMovable(true)
  record = { id = group.id, container = container, slots = {}, handle = self:CreateHandle(container, group) }
  self.groups[group.id] = record
  return record
end

-- Layout ---------------------------------------------------------------------------------------------------------

function TrackerFrames:ApplyPosition(record, group)
  local position = group.position
  if not position or record.moving then
    return
  end
  record.container:ClearAllPoints()
  record.container:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
end

function TrackerFrames:Slot(record, index)
  local slot = record.slots[index]
  if not slot then
    slot = self:CreateSlot(record.container)
    record.slots[index] = slot
  end
  return slot
end

local function bool(value)
  return value == true
end

-- Draws one state into one slot.
function TrackerFrames:Paint(slot, state, layout)
  local platform = self.platform
  slot.state = state
  slot.icon:SetTexture(state.icon or ns.Constants.LOGO_TEXTURE)
  local alpha = 1
  if state.dim then
    alpha = DIM_ALPHA
  elseif state.hidden then
    alpha = HIDDEN_ALPHA
  end
  slot:SetAlpha(alpha)

  local hidden = bool(state.hidden)
  if state.start and state.duration then
    slot.cooldown:SetCooldown(state.start, state.duration)
  elseif state.durationObject ~= nil then
    -- Opaque (maybe secret): only the widget touches it. A widget that refuses it means there is nothing safe.
    if not platform.SetCooldownFromDurationObject(slot.cooldown, state.durationObject) then
      slot.cooldown:Clear()
      hidden = true
    end
  else
    slot.cooldown:Clear()
  end

  if state.stacksText ~= nil then
    platform.SetText(slot.count, state.stacksText)
  elseif state.stacks and (state.stacks > 1 or state.maxCharges) then
    slot.count:SetText(tostring(state.stacks))
  else
    slot.count:SetText("")
  end

  slot.glow:SetShown(state.ready == true or (state.kind ~= "cooldown" and state.active == true))
  slot.hiddenMark:SetShown(hidden)

  -- A bar needs readable numbers; anything else stays an icon.
  local bar = layout.mode == "bars" and self.viewModel.CanShowBar(state)
  slot.bar:SetShown(bar and true or false)
  slot.barActive = bar and true or false
end

-- Sets the bar fill and text of the slots that show one. Only readable numbers are used.
function TrackerFrames:UpdateBars()
  local now = self.platform.GetTime()
  for _, record in pairs(self.groups) do
    for _, slot in ipairs(record.slots) do
      if slot.barActive and slot.state then
        local remaining = self.viewModel.Remaining(slot.state, now)
        if remaining then
          slot.bar:SetMinMaxValues(0, slot.state.duration)
          slot.bar:SetValue(remaining)
          slot.barText:SetText(self.viewModel.TimeText(remaining))
        else
          slot.bar:Hide()
          slot.barActive = false
        end
      end
    end
  end
end

function TrackerFrames:ApplyGroup(group)
  local record = self:Container(group)
  local layout = ns.TrackerModel.Layout(group)
  local entries = self.model:VisibleEntries(group.id)
  local states = self.viewModel.Group(group, entries, { platform = self.platform, auraCache = self.auraCache })

  local size = layout.iconSize
  local barMode = layout.mode == "bars"
  local width = barMode and size * ns.Constants.TRACKER.BAR_WIDTH_FACTOR or size
  local plan = self.viewModel.Layout(#states, layout, width, size)

  record.container:SetScale(layout.scale)
  record.container:SetSize(math.max(plan.width, size), math.max(plan.height, size))
  for index, state in ipairs(states) do
    local slot = self:Slot(record, index)
    slot:SetSize(width, size)
    slot.icon:SetSize(size, size)
    slot.glow:SetPoint("TOPLEFT", slot.icon, "TOPLEFT", -2, 2)
    slot.glow:SetPoint("BOTTOMRIGHT", slot.icon, "BOTTOMRIGHT", 2, -2)
    slot.cooldown:SetAllPoints(slot.icon)
    slot.bar:SetPoint("TOPLEFT", slot, "TOPLEFT", size + 2, 0)
    slot.bar:SetSize(width - size - 2, size)
    slot:ClearAllPoints()
    slot:SetPoint("TOPLEFT", record.container, "TOPLEFT", plan.slots[index].x, plan.slots[index].y)
    self:Paint(slot, state, layout)
    slot:Show()
  end
  for index = #states + 1, #record.slots do
    record.slots[index]:Hide()
    record.slots[index].state = nil
    record.slots[index].barActive = false
  end
  record.count = #states
  record.handle.label:SetText(ns.TrackerModel.Title(group, self.L))
  self:ApplyPosition(record, group)
  self:ApplyAlpha(record, layout)
  -- An empty group has nothing to draw, except while it is unlocked and must stay grabbable.
  record.container:SetShown(#states > 0 or self.unlocked)
end

function TrackerFrames:ApplyAlpha(record, layout)
  if self.unlocked or self.inCombat then
    record.container:SetAlpha(1)
  else
    record.container:SetAlpha(layout.alphaOutOfCombat)
  end
end

-- Redraws every group now.
function TrackerFrames:Refresh()
  self.refreshes = self.refreshes + 1
  self.dirty = false
  -- One aura scan per (unit, filter) for the whole redraw, shared by every group.
  self.auraCache = {}
  for _, group in ipairs(self.model:Groups()) do
    self:ApplyGroup(group)
  end
  self:UpdateBars()
end

-- Marks the tracker for a redraw on the next frame. Any number of calls before it cost one redraw.
function TrackerFrames:Invalidate()
  self.dirty = true
end

-- Unlock and move -------------------------------------------------------------------------------------------------

function TrackerFrames:SetUnlocked(unlocked)
  self.unlocked = unlocked and true or false
  for _, record in pairs(self.groups) do
    record.handle:SetShown(self.unlocked)
    -- Icons only take the mouse while unlocked, so they never swallow clicks meant for the world.
    for _, slot in ipairs(record.slots) do
      slot:EnableMouse(self.unlocked)
    end
  end
  self:Refresh()
end

function TrackerFrames:OnDragStart(groupId)
  local record = self.groups[groupId]
  if not record or not self.unlocked then
    return
  end
  record.moving = true
  record.container:StartMoving()
end

function TrackerFrames:OnDragStop(groupId)
  local record = self.groups[groupId]
  if not record or not record.moving then
    return
  end
  record.moving = false
  record.container:StopMovingOrSizing()
  local point, _, relativePoint, x, y = record.container:GetPoint()
  if point then
    self.model:SetPosition(groupId, { point = point, relativePoint = relativePoint, x = x, y = y })
  end
end

-- Events ---------------------------------------------------------------------------------------------------------

function TrackerFrames:OnEvent(event, unit)
  if event == "UNIT_AURA" and not AURA_UNITS[unit] then
    return
  end
  if event == "PLAYER_REGEN_DISABLED" then
    self.inCombat = true
  elseif event == "PLAYER_REGEN_ENABLED" then
    self.inCombat = false
  end
  self:Invalidate()
end

function TrackerFrames:OnUpdate(elapsed)
  if self.dirty then
    self:Refresh()
    self.elapsed = 0
    return
  end
  self.elapsed = self.elapsed + elapsed
  if self.elapsed >= ns.Constants.TRACKER.BAR_REFRESH_SECONDS then
    self.elapsed = 0
    self:UpdateBars()
  end
end

-- UNIT_AURA only for the units the tracker reads. Falls back to the plain event (OnEvent filters the unit) when the
-- client has no RegisterUnitEvent or refuses it.
function TrackerFrames:RegisterAuraEvent()
  local driver = self.driver
  if
    type(driver.RegisterUnitEvent) == "function"
    and pcall(driver.RegisterUnitEvent, driver, "UNIT_AURA", "player", "target")
  then
    return
  end
  self.platform.TryRegisterEvent(driver, "UNIT_AURA")
end

function TrackerFrames:CreateDriver()
  self.driver = CreateFrame("Frame")
  self.driver:SetScript("OnEvent", function(_, event, ...)
    self:OnEvent(event, ...)
  end)
  self.driver:SetScript("OnUpdate", function(_, elapsed)
    self:OnUpdate(elapsed)
  end)
  for _, event in ipairs(EVENTS) do
    if event == "UNIT_AURA" then
      self:RegisterAuraEvent()
    else
      self.platform.TryRegisterEvent(self.driver, event)
    end
  end
end

function TrackerFrames:Start()
  self.inCombat = self.platform.InCombatLockdown() == true
  self:CreateDriver()
  self:Refresh()
  if self.bus then
    self.bus:Subscribe("layout.unlock", function()
      self:SetUnlocked(true)
    end)
    self.bus:Subscribe("layout.lock", function()
      self:SetUnlocked(false)
    end)
  end
end

ns.TrackerFrames = TrackerFrames

ns.Startup.Register(function()
  if ns.disabled then
    return
  end
  ns.trackerModel = ns.TrackerModel.New(ns.settings)
  ns.trackerFrames = TrackerFrames.New({ model = ns.trackerModel, bus = ns.bus })
  ns.trackerFrames:Start()
end)
