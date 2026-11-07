-- luacheck: ignore 212/self
local _, ns = ...

-- The poison button: a movable main button with the main hand poison icon and two status lines, and a flyout with one
-- secure button per poison rank in the bags.
--
-- Secure structure (see docs/API_NOTES.md):
--   header   SecureHandlerBaseTemplate frame, the "control" of the snippets below. It holds the frame ref "flyout".
--   button   SecureActionButtonTemplate. Its OnClick is wrapped by a header snippet: a click without Shift toggles the
--            flyout (Show/Hide of a protected frame from a snippet works in combat) and is swallowed; a Shift click
--            passes through to the secure action set in the shift-* attributes (reapply the last poison).
--   flyout   SecureHandlerBaseTemplate frame (protected, so a snippet can show it), child of the button.
--   rows     SecureActionButtonTemplate, children of the flyout. Left click: type1=item on slot 16; right
--            click: type2=item on slot 17. Their OnClick is wrapped to hide the flyout after the action.
-- No attribute, anchor or size of a protected frame changes in combat: Rebuild marks itself dirty and runs again on
-- PLAYER_REGEN_ENABLED.
local PoisonButton = {}
PoisonButton.__index = PoisonButton

local BUTTON_SIZE = 40
local ROW_HEIGHT = 28
local ROW_WIDTH = 190

local TOGGLE_SNIPPET = [[
  if IsShiftKeyDown() then
    return
  end
  local flyout = control:GetFrameRef("flyout")
  if flyout:IsShown() then
    flyout:Hide()
  else
    flyout:Show()
  end
  return false
]]

local ROW_PRE_SNIPPET = [[
  return nil, "hide"
]]

local ROW_POST_SNIPPET = [[
  control:GetFrameRef("flyout"):Hide()
]]

local SLOT_BY_MOUSE = { LeftButton = "mh", RightButton = "oh" }

-- deps: settings, profileData (the persisted poison table), bus, platform, weaponState, catalog, viewModel, L.
function PoisonButton.New(deps)
  return setmetatable({
    settings = deps.settings,
    data = deps.data,
    bus = deps.bus,
    platform = deps.platform or ns.Platform,
    weaponState = deps.weaponState,
    catalog = deps.catalog or ns.PoisonCatalog,
    viewModel = deps.viewModel or ns.ViewModelPoisons,
    L = deps.L or ns.L,
    rows = {},
    dirty = false,
    built = false,
    elapsed = 0,
  }, PoisonButton)
end

function PoisonButton:InCombat()
  return self.platform.InCombatLockdown() == true
end

function PoisonButton:IconFor(itemID)
  local _, icon = self.platform.GetItemInfo(itemID)
  return icon
end

function PoisonButton:ViewDeps()
  return {
    L = self.L,
    iconFor = function(itemID)
      return self:IconFor(itemID)
    end,
  }
end

function PoisonButton:LastPoisons()
  if type(self.data.last) ~= "table" then
    self.data.last = {}
  end
  return self.data.last
end

-- Frames ---------------------------------------------------------------------------------------------------------

function PoisonButton:CreateButton()
  local button = CreateFrame("Button", "RogueAssistantPoisonButton", UIParent, "SecureActionButtonTemplate")
  button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
  button:SetFrameStrata("MEDIUM")
  button:SetClampedToScreen(true)
  button:RegisterForClicks("AnyUp")
  button:RegisterForDrag("LeftButton")
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetAllPoints(button)
  button.moveOverlay = button:CreateTexture(nil, "OVERLAY")
  button.moveOverlay:SetAllPoints(button)
  button.moveOverlay:SetColorTexture(1, 0.96, 0.41, 0.35)
  button.moveOverlay:Hide()
  button.mhLine = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  button.mhLine:SetPoint("TOP", button, "BOTTOM", 0, -2)
  button.ohLine = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  button.ohLine:SetPoint("TOP", button.mhLine, "BOTTOM", 0, -1)
  return button
end

function PoisonButton:CreateFlyout(button)
  local flyout = CreateFrame("Frame", "RogueAssistantPoisonFlyout", button, "SecureHandlerBaseTemplate")
  flyout:SetFrameStrata("DIALOG")
  flyout:SetSize(ROW_WIDTH, ROW_HEIGHT)
  flyout:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, 4)
  flyout.empty = flyout:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  flyout.empty:SetPoint("BOTTOMLEFT", flyout, "BOTTOMLEFT", 4, 4)
  flyout.empty:SetText(self.L["poison.empty"])
  flyout:Hide()
  return flyout
end

function PoisonButton:CreateRow(index)
  local row = CreateFrame("Button", "RogueAssistantPoisonRow" .. index, self.flyout, "SecureActionButtonTemplate")
  row:SetSize(ROW_WIDTH, ROW_HEIGHT)
  row:RegisterForClicks("AnyUp")
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(ROW_HEIGHT - 4, ROW_HEIGHT - 4)
  row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
  row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
  row.highlight:SetAllPoints(row)
  row.highlight:SetColorTexture(1, 1, 1, 0.15)
  self.header:WrapScript(row, "OnClick", ROW_PRE_SNIPPET, ROW_POST_SNIPPET)
  row:HookScript("PostClick", function(_, mouseButton)
    self:OnRowClicked(row, mouseButton)
  end)
  row:HookScript("OnEnter", function()
    self:ShowTooltip(row, self.L["poison.flyout.tip"])
  end)
  row:HookScript("OnLeave", function()
    self:HideTooltip()
  end)
  return row
end

-- Builds every frame. Out of combat only: it returns false (and marks the button dirty) in combat.
function PoisonButton:Build()
  if self.built then
    return true
  end
  if self:InCombat() then
    self.dirty = true
    return false
  end
  self.header = CreateFrame("Frame", "RogueAssistantPoisonHeader", UIParent, "SecureHandlerBaseTemplate")
  self.button = self:CreateButton()
  self.flyout = self:CreateFlyout(self.button)
  self.header:SetFrameRef("flyout", self.flyout)
  self.header:WrapScript(self.button, "OnClick", TOGGLE_SNIPPET)

  local button = self.button
  button:HookScript("PostClick", function(_, mouseButton)
    self:OnMainClicked(mouseButton)
  end)
  button:SetScript("OnDragStart", function()
    self:OnDragStart()
  end)
  button:SetScript("OnDragStop", function()
    self:OnDragStop()
  end)
  button:HookScript("OnEnter", function()
    self:ShowTooltip(button, self:MainTooltip())
  end)
  button:HookScript("OnLeave", function()
    self:HideTooltip()
  end)

  self:ApplyPosition()
  self.button:SetScale(self.settings:Get("poison.scale"))
  self:ApplyLock()
  self.built = true
  return true
end

-- Position and lock ----------------------------------------------------------------------------------------------

function PoisonButton:ApplyPosition()
  local position = self.settings:Get("poison.position")
  self.button:ClearAllPoints()
  self.button:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
end

function PoisonButton:ApplyLock()
  local locked = self.settings:Get("poison.locked")
  self.button:SetMovable(not locked)
  self.button.moveOverlay:SetShown(not locked)
end

-- Locks or unlocks the button. Not in combat (a protected frame cannot be configured then): returns false.
function PoisonButton:SetLocked(locked)
  if not self.built or self:InCombat() then
    return false
  end
  self.settings:Set("poison.locked", locked)
  self:ApplyLock()
  return true
end

-- Applies position, scale and lock from the settings (the options panel calls it after a change). A protected frame
-- cannot be configured in combat, so it only notes the change and PLAYER_REGEN_ENABLED applies it. Returns true when
-- the frame was updated now.
function PoisonButton:ApplySettings()
  if not self.built then
    return false
  end
  if self:InCombat() then
    self.settingsDirty = true
    return false
  end
  self:ApplyPosition()
  self.button:SetScale(self.settings:Get("poison.scale"))
  self:ApplyLock()
  self.settingsDirty = false
  return true
end

function PoisonButton:OnDragStart()
  if self.settings:Get("poison.locked") or self:InCombat() then
    return
  end
  self.button:StartMoving()
  self.moving = true
end

function PoisonButton:OnDragStop()
  if not self.moving then
    return
  end
  self.moving = false
  self.button:StopMovingOrSizing()
  local point, _, relativePoint, x, y = self.button:GetPoint()
  if point then
    self.settings:Set("poison.position", { point = point, relativePoint = relativePoint, x = x, y = y })
  end
end

-- Tooltips -------------------------------------------------------------------------------------------------------

function PoisonButton:MainTooltip()
  local lines = { self.L["poison.tip.title"], self.L["poison.tip.click"], self.L["poison.tip.shift"] }
  if not self.settings:Get("poison.locked") then
    lines[#lines + 1] = self.L["poison.tip.drag"]
  end
  return table.concat(lines, "\n")
end

function PoisonButton:ShowTooltip(owner, text)
  if not GameTooltip then
    return
  end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetText(text)
  GameTooltip:Show()
end

function PoisonButton:HideTooltip()
  if GameTooltip then
    GameTooltip:Hide()
  end
end

-- Flyout ---------------------------------------------------------------------------------------------------------

-- Sets (or, with itemID nil, clears) the secure use-item-on-weapon attributes of `frame`.
-- `prefix` is "" for the flyout rows and "shift-" for the main button; `suffix` is the mouse button number.
local function setItemAction(frame, prefix, suffix, itemID, slotNumber)
  frame:SetAttribute(prefix .. "type" .. suffix, itemID and "item" or nil)
  frame:SetAttribute(prefix .. "item" .. suffix, itemID and ("item:" .. itemID) or nil)
  frame:SetAttribute(prefix .. "target-slot" .. suffix, itemID and slotNumber or nil)
end

function PoisonButton:ConfigureRow(index, entry)
  local row = self.rows[index]
  if not row then
    row = self:CreateRow(index)
    self.rows[index] = row
  end
  local constants = ns.Constants
  setItemAction(row, "", "1", entry.itemID, constants.SLOT_MAIN_HAND)
  setItemAction(row, "", "2", entry.itemID, constants.SLOT_OFF_HAND)
  row.itemID = entry.itemID
  row.label:SetText(entry.text)
  row.icon:SetTexture(entry.icon or ns.Constants.LOGO_TEXTURE)
  row:ClearAllPoints()
  row:SetPoint("BOTTOMLEFT", self.flyout, "BOTTOMLEFT", 0, (index - 1) * ROW_HEIGHT)
  row:Show()
end

function PoisonButton:ClearRow(row)
  setItemAction(row, "", "1", nil)
  setItemAction(row, "", "2", nil)
  row.itemID = nil
  row:Hide()
end

-- The shift-* attributes of the main button: reapply the last poison of each hand while it is still in the bags.
function PoisonButton:ApplyLast(catalog)
  local last = self:LastPoisons()
  local constants = ns.Constants
  local function apply(slotName, suffix, slotNumber)
    local itemID = last[slotName]
    if itemID and not catalog.byItem[itemID] then
      itemID = nil
    end
    setItemAction(self.button, "shift-", suffix, itemID, slotNumber)
  end
  apply("mh", "1", constants.SLOT_MAIN_HAND)
  apply("oh", "2", constants.SLOT_OFF_HAND)
end

-- Rebuilds the flyout and the shift attributes from the bags. In combat it only marks the button dirty.
function PoisonButton:Rebuild()
  if not self:Build() then
    return false
  end
  if self:InCombat() then
    self.dirty = true
    return false
  end
  local catalog = self.catalog.Build(self.platform.GetBagItems())
  local entries = self.viewModel.Flyout(catalog, self:ViewDeps())
  for index, entry in ipairs(entries) do
    self:ConfigureRow(index, entry)
  end
  for index = #entries + 1, #self.rows do
    self:ClearRow(self.rows[index])
  end
  self.flyout:SetSize(ROW_WIDTH, math.max(#entries, 1) * ROW_HEIGHT)
  self.flyout.empty:SetShown(#entries == 0)
  self:ApplyLast(catalog)
  self.dirty = false
  self.rowCount = #entries
  return true
end

-- Click handlers (non-secure, run after the secure action) ---------------------------------------------------------

function PoisonButton:Applied(slotName, itemID)
  if slotName and itemID then
    self.weaponState:NoteApplied(slotName, itemID)
  end
end

function PoisonButton:OnRowClicked(row, mouseButton)
  local slotName = SLOT_BY_MOUSE[mouseButton]
  if not slotName or not row.itemID then
    return
  end
  self:LastPoisons()[slotName] = row.itemID
  -- The shift attributes cannot change in combat: they follow on the next rebuild.
  self.dirty = true
  self:Applied(slotName, row.itemID)
  if not self:InCombat() then
    self:Rebuild()
  end
end

function PoisonButton:OnMainClicked(mouseButton)
  if self.platform.IsShiftKeyDown() ~= true then
    return
  end
  local slotName = SLOT_BY_MOUSE[mouseButton]
  if slotName then
    self:Applied(slotName, self:LastPoisons()[slotName])
  end
end

-- Status ---------------------------------------------------------------------------------------------------------

-- Updates the icon and the two lines. Plain regions of a protected frame may change in combat.
function PoisonButton:RefreshStatus()
  if not self.built then
    return
  end
  local state = self.weaponState:Read()
  local deps = self:ViewDeps()
  local status = self.viewModel.Status(state, deps)
  self.button.mhLine:SetText(status.mh.text)
  self.button.ohLine:SetText(status.oh.text)
  self.button.icon:SetTexture(self.viewModel.MainIcon(state, deps))
end

-- Events ---------------------------------------------------------------------------------------------------------

function PoisonButton:OnUpdate(elapsed)
  self.elapsed = self.elapsed + elapsed
  if self.elapsed >= ns.Constants.STATUS_REFRESH_SECONDS then
    self.elapsed = 0
    self:RefreshStatus()
  end
end

function PoisonButton:OnEvent(event, unit)
  if event == "BAG_UPDATE_DELAYED" then
    self:Rebuild()
    self:RefreshStatus()
  elseif event == "PLAYER_REGEN_ENABLED" then
    if self.settingsDirty then
      self:ApplySettings()
    end
    if self.dirty then
      self:Rebuild()
    end
    self:RefreshStatus()
  elseif event == "UNIT_INVENTORY_CHANGED" and unit == "player" then
    self:RefreshStatus()
  end
end

-- The event frame is plain, so it can exist before the secure frames: it is what wakes the button after combat.
function PoisonButton:CreateDriver()
  self.driver = CreateFrame("Frame")
  self.driver:SetScript("OnEvent", function(_, event, ...)
    self:OnEvent(event, ...)
  end)
  self.driver:SetScript("OnUpdate", function(_, elapsed)
    self:OnUpdate(elapsed)
  end)
  for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_REGEN_ENABLED", "UNIT_INVENTORY_CHANGED" }) do
    self.platform.TryRegisterEvent(self.driver, event)
  end
end

function PoisonButton:Start()
  self:CreateDriver()
  self:Rebuild()
  self:RefreshStatus()
  if self.bus then
    self.bus:Subscribe("layout.unlock", function()
      self:SetLocked(false)
    end)
    self.bus:Subscribe("layout.lock", function()
      self:SetLocked(true)
    end)
  end
end

ns.PoisonButton = PoisonButton

ns.Startup.Register(function()
  if ns.disabled then
    return
  end
  ns.poisonButton = PoisonButton.New({
    settings = ns.settings,
    data = ns.profile.poison,
    bus = ns.bus,
    weaponState = ns.weaponState,
  })
  ns.poisonButton:Start()
end)
