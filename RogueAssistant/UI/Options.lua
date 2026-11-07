-- luacheck: ignore 212/self
local _, ns = ...

-- The options panel: a canvas registered in the game's Settings window. When the client has no Settings API (or
-- refuses to open it) the same panel is shown in a small movable window of its own. The panel only draws: every value
-- is read and written through ViewModelOptions, and `Refresh` rereads all of them.
local Options = {}
Options.__index = Options

local CONTENT_WIDTH = 560
local ROW_HEIGHT = 24
local WINDOW_WIDTH, WINDOW_HEIGHT = 620, 540

-- deps: viewModel (ViewModelOptions), platform, bus, L.
function Options.New(deps)
  return setmetatable({
    vm = deps.viewModel,
    platform = deps.platform or ns.Platform,
    L = deps.L or ns.L,
    refreshers = {},
    entryRows = {},
    y = -8,
    built = false,
    confirmReset = false,
  }, Options)
end

-- Widgets --------------------------------------------------------------------------------------------------------

-- Places `widget` at the current line and returns it; `advance` moves the line down by that many pixels.
function Options:Place(widget, x, advance)
  widget:ClearAllPoints()
  widget:SetPoint("TOPLEFT", self.content, "TOPLEFT", x or 8, self.y)
  if advance then
    self.y = self.y - advance
  end
  return widget
end

function Options:Text(text, template, x, advance)
  local label = self.content:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
  label:SetJustifyH("LEFT")
  label:SetText(text)
  return self:Place(label, x, advance), label
end

function Options:Heading(text)
  self.y = self.y - 10
  self:Text(text, "GameFontNormalLarge", 8, 28)
end

function Options:Button(text, width, onClick, x, advance)
  local button = CreateFrame("Button", nil, self.content, "UIPanelButtonTemplate")
  button:SetSize(width, 22)
  button:SetText(text)
  button:SetScript("OnClick", onClick)
  return self:Place(button, x, advance)
end

-- A check box bound to a setting path.
function Options:Check(label, path)
  local check = CreateFrame("CheckButton", nil, self.content, "UICheckButtonTemplate")
  check:SetSize(24, 24)
  self:Place(check, 8)
  local _, text = self:Text(label, "GameFontHighlight", 36)
  text:ClearAllPoints()
  text:SetPoint("LEFT", check, "RIGHT", 4, 0)
  self.y = self.y - 26
  check:SetScript("OnClick", function(box)
    self:Report(self.vm:Set(path, box:GetChecked() and true or false))
    self:Refresh()
  end)
  self.refreshers[#self.refreshers + 1] = function()
    check:SetChecked(self.vm:Get(path) == true)
  end
end

-- A slider. `read()` gives the current value, `write(value)` stores it and returns ok, message.
function Options:Slider(label, minimum, maximum, step, read, write)
  local caption = self:Text("", "GameFontHighlight", 8, 20)
  local slider = CreateFrame("Slider", nil, self.content, "OptionsSliderTemplate")
  slider:SetSize(260, 16)
  slider:SetMinMaxValues(minimum, maximum)
  slider:SetValueStep(step)
  slider:SetObeyStepOnDrag(true)
  for _, part in ipairs({ "Low", "High", "Text" }) do
    local region = slider[part]
    if type(region) == "table" then
      region:SetText("")
    end
  end
  self:Place(slider, 12, 30)
  local function show(value)
    caption:SetText(("%s: %s"):format(label, tostring(value)))
  end
  slider:SetScript("OnValueChanged", function(_, value)
    if self.refreshing then
      return
    end
    self:Report(write(value))
    show(read())
  end)
  self.refreshers[#self.refreshers + 1] = function()
    local value = read()
    slider:SetValue(value)
    show(value)
  end
end

-- Reports the outcome of a change next to the panel title.
function Options:Report(ok, message)
  if self.status then
    self.status:SetText(message or "")
    if ok == false then
      self.status:SetTextColor(1, 0.4, 0.3)
    else
      self.status:SetTextColor(0.6, 1, 0.6)
    end
  end
end

-- Sections -------------------------------------------------------------------------------------------------------

-- The unlock / lock toggle and the reset of every position, at the top of the panel.
function Options:BuildLayout()
  local L, vm = self.L, self.vm
  local toggle = self:Button("", 220, function()
    self:Report(vm:ToggleLayout())
    self:Refresh()
  end, 8)
  self:Button(L["options.layout.reset"], 200, function()
    self:Report(vm:ResetAllPositions())
    self:Refresh()
  end, 236, 32)
  self.refreshers[#self.refreshers + 1] = function()
    toggle:SetText(L[vm:IsUnlocked() and "options.layout.lock" or "options.layout.unlock"])
  end
end

function Options:BuildPoison()
  local L, vm = self.L, self.vm
  self:Heading(L["options.section.poison"])
  self:Check(L["options.poison.locked"], "poison.locked")
  self:Check(L["options.poison.statusShown"], "poison.statusShown")
  local flyout = self:Button("", 300, function()
    self:Report(vm:CycleFlyout())
    self:Refresh()
  end, 8, 30)
  self.refreshers[#self.refreshers + 1] = function()
    flyout:SetText(L["options.poison.flyout"]:format(L["options.flyout." .. vm:Get("poison.flyoutDirection")]))
  end
  local minimum, maximum = vm.Bounds("poison.scale")
  self:Slider(L["options.poison.scale"], minimum, maximum, vm.Step("poison.scale"), function()
    return vm:Get("poison.scale")
  end, function(value)
    return vm:Set("poison.scale", value)
  end)
  self:Button(L["options.poison.reset"], 160, function()
    self:Report(vm:ResetPoisonPosition())
  end, 8, 30)
end

function Options:BuildAlerts()
  local L, vm = self.L, self.vm
  self:Heading(L["options.section.alerts"])
  for _, path in ipairs(vm.ALERT_NUMBERS) do
    local minimum, maximum = vm.Bounds(path)
    self:Slider(L["options." .. path], minimum, maximum, vm.Step(path), function()
      return vm:Get(path)
    end, function(value)
      return vm:Set(path, value)
    end)
  end
  for _, path in ipairs(vm.ALERT_TRIGGERS) do
    self:Check(L["options." .. path], path)
  end
end

-- The group the tracker section is editing.
function Options:CurrentGroup()
  local groups = self.vm:Groups()
  for _, group in ipairs(groups) do
    if group.id == self.groupId then
      return group
    end
  end
  self.groupId = groups[1] and groups[1].id
  return groups[1]
end

function Options:NextGroup()
  local groups = self.vm:Groups()
  local current = self:CurrentGroup()
  for index, group in ipairs(groups) do
    if current and group.id == current.id then
      self.groupId = groups[index % #groups + 1].id
      return
    end
  end
end

-- A button that cycles a choice option of the current group.
function Options:Choice(key, captionKey, valueKey)
  local L, vm = self.L, self.vm
  local button = self:Button("", 300, function()
    self:Report(vm:Cycle(self.groupId, key))
    self:Refresh()
  end, 8, 28)
  self.refreshers[#self.refreshers + 1] = function()
    local layout = vm:Layout(self.groupId)
    if layout then
      button:SetText(L[captionKey]:format(L[valueKey .. layout[key]]))
    end
  end
end

function Options:BuildTrackerLayout()
  local L, vm = self.L, self.vm
  local groupButton = self:Button("", 300, function()
    self:NextGroup()
    self:Refresh()
  end, 8, 32)
  self.refreshers[#self.refreshers + 1] = function()
    local group = self:CurrentGroup()
    groupButton:SetText(L["options.tracker.group"]:format(group and group.title or "-"))
  end
  for _, key in ipairs(vm.LAYOUT_NUMBERS) do
    local minimum, maximum = vm.Bounds(key)
    local step = (key == "iconSize" or key == "spacing" or key == "columns") and 1 or 0.05
    self:Slider(L["options.tracker." .. key], minimum, maximum, step, function()
      local layout = vm:Layout(self.groupId)
      return layout and layout[key] or minimum
    end, function(value)
      return vm:SetLayout(self.groupId, key, value)
    end)
  end
  self:Choice("growth", "options.tracker.growth", "options.growth.")
  self:Choice("mode", "options.tracker.mode", "options.mode.")
  self:Choice("showWhenMissing", "options.tracker.missing", "options.missing.")
end

function Options:BuildTrackerEntries()
  local L, vm = self.L, self.vm
  self:Text(L["options.tracker.add"], "GameFontHighlight", 8, 20)
  local box = CreateFrame("EditBox", nil, self.content, "InputBoxTemplate")
  box:SetSize(220, 22)
  box:SetAutoFocus(false)
  box:SetMaxLetters(60)
  self:Place(box, 14)
  local function add()
    local ok, message = vm:AddEntry(self.groupId, box:GetText())
    self:Report(ok, message)
    if ok then
      box:SetText("")
    end
    self:Refresh()
  end
  box:SetScript("OnEnterPressed", function(edit)
    add()
    edit:ClearFocus()
  end)
  box:SetScript("OnEscapePressed", function(edit)
    edit:ClearFocus()
  end)
  self:Button(L["options.tracker.addButton"], 80, add, 244, 32)
  self.addBox = box

  self:Button(L["options.tracker.resetGroup"], 160, function()
    self:Report(vm:ResetGroup(self.groupId))
    self:Refresh()
  end, 8)
  self.resetAll = self:Button("", 220, function()
    if self.confirmReset then
      self.confirmReset = false
      self:Report(vm:ResetAll())
    else
      self.confirmReset = true
    end
    self:Refresh()
  end, 176, 32)
  self.refreshers[#self.refreshers + 1] = function()
    self.resetAll:SetText(L[self.confirmReset and "options.tracker.resetAllConfirm" or "options.tracker.resetAll"])
  end
  self:Text(L["options.tracker.entries"], "GameFontNormal", 8, 22)
  self.listTop = self.y
end

-- Entry list ------------------------------------------------------------------------------------------------------

function Options:EntryRow(index)
  local row = self.entryRows[index]
  if row then
    return row
  end
  local L, vm = self.L, self.vm
  row = CreateFrame("Frame", nil, self.content)
  row:SetSize(CONTENT_WIDTH - 16, ROW_HEIGHT)
  row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
  row.text:SetJustifyH("LEFT")
  local function act(name, label, width, offset, handler)
    local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    button:SetSize(width, 20)
    button:SetText(label)
    button:SetPoint("RIGHT", row, "RIGHT", offset, 0)
    button:SetScript("OnClick", handler)
    row[name] = button
  end
  act("remove", L["options.entry.remove"], 70, -4, function()
    self:Report(vm:RemoveEntry(self.groupId, row.index))
    self:Refresh()
  end)
  act("down", L["options.entry.down"], 50, -78, function()
    self:Report(vm:MoveEntry(self.groupId, row.index, 1))
    self:Refresh()
  end)
  act("up", L["options.entry.up"], 50, -132, function()
    self:Report(vm:MoveEntry(self.groupId, row.index, -1))
    self:Refresh()
  end)
  row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, self.listTop - (index - 1) * ROW_HEIGHT)
  self.entryRows[index] = row
  return row
end

function Options:RefreshEntries()
  local rows = self.vm:Entries(self.groupId)
  for index, data in ipairs(rows) do
    local row = self:EntryRow(index)
    row.index = data.index
    row.text:SetText(data.text)
    row.up:SetShown(data.canUp)
    row.down:SetShown(data.canDown)
    row:Show()
  end
  for index = #rows + 1, #self.entryRows do
    self.entryRows[index]:Hide()
  end
  self.empty:SetShown(#rows == 0)
  self.content:SetHeight(-self.listTop + math.max(#rows, 1) * ROW_HEIGHT + 24)
end

-- Panel ----------------------------------------------------------------------------------------------------------

function Options:BuildContent()
  local L = self.L
  local scroll = CreateFrame("ScrollFrame", "RogueAssistantOptionsScroll", self.panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", self.panel, "TOPLEFT", 4, -4)
  scroll:SetPoint("BOTTOMRIGHT", self.panel, "BOTTOMRIGHT", -28, 4)
  self.content = CreateFrame("Frame", nil, scroll)
  self.content:SetSize(CONTENT_WIDTH, 800)
  scroll:SetScrollChild(self.content)

  local _, title = self:Text(L["app.name"], "GameFontNormalLarge", 8, 30)
  title:SetTextColor(1, 0.96, 0.41)
  self.status = self:Text("", "GameFontHighlight", 8, 20)
  self:BuildLayout()
  self:BuildPoison()
  self:BuildAlerts()
  self:Heading(L["options.section.tracker"])
  self:BuildTrackerLayout()
  self:BuildTrackerEntries()
  self.empty = self:Text(L["options.tracker.empty"], "GameFontDisable", 12)
  self.empty:ClearAllPoints()
  self.empty:SetPoint("TOPLEFT", self.content, "TOPLEFT", 12, self.listTop - 4)
end

function Options:Refresh()
  if not self.built then
    return
  end
  self:CurrentGroup()
  self.refreshing = true
  for _, refresh in ipairs(self.refreshers) do
    refresh()
  end
  self:RefreshEntries()
  self.refreshing = false
end

-- Builds the controls the first time the panel is shown, so a character that never opens it pays nothing.
function Options:OnShow()
  if not self.built then
    self.built = true
    self:BuildContent()
  end
  self.confirmReset = false
  self:Refresh()
end

-- A small window of our own, used when there is no Settings window to live in.
function Options:EnsureWindow()
  if self.window then
    return self.window
  end
  local window = CreateFrame("Frame", "RogueAssistantOptionsWindow", UIParent)
  window:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
  window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  window:SetFrameStrata("DIALOG")
  window:SetClampedToScreen(true)
  window:SetMovable(true)
  window:EnableMouse(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", function(frame)
    frame:StartMoving()
  end)
  window:SetScript("OnDragStop", function(frame)
    frame:StopMovingOrSizing()
  end)
  window.background = window:CreateTexture(nil, "BACKGROUND")
  window.background:SetAllPoints(window)
  window.background:SetColorTexture(0, 0, 0, 0.85)
  local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -2, -2)
  self.panel:SetParent(window)
  self.panel:ClearAllPoints()
  self.panel:SetPoint("TOPLEFT", window, "TOPLEFT", 8, -32)
  self.panel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -8, 8)
  window:Hide()
  if UISpecialFrames then
    table.insert(UISpecialFrames, "RogueAssistantOptionsWindow")
  end
  self.window = window
  return window
end

function Options:Create()
  self.panel = CreateFrame("Frame", "RogueAssistantOptionsPanel", UIParent)
  self.panel.name = self.L["app.name"]
  self.panel:SetScript("OnShow", function()
    self:OnShow()
  end)
  self.category = self.platform.RegisterSettingsCanvas(self.panel, self.L["app.name"])
  if not self.category then
    self:EnsureWindow()
  else
    self.panel:Hide()
  end
end

-- Opens the options: in the Settings window when it exists, else in our own window. Toggles our own window.
function Options:Open()
  if not self.panel then
    return false
  end
  if self.category and self.platform.OpenSettingsCategory(self.category) then
    return true
  end
  local window = self:EnsureWindow()
  window:SetShown(not window:IsShown())
  self.panel:Show()
  return true
end

ns.Options = Options

ns.Startup.Register(function()
  if ns.disabled then
    return
  end
  local viewModel = ns.ViewModelOptions.New({
    settings = ns.settings,
    model = ns.trackerModel,
    bus = ns.bus,
    refreshTracker = function()
      if ns.trackerFrames then
        ns.trackerFrames:Refresh()
      end
    end,
    refreshAlerts = function()
      if ns.poisonAlertsView then
        ns.poisonAlertsView:ApplyPosition()
      end
    end,
    refreshPoison = function()
      if ns.poisonButton then
        ns.poisonButton:ApplySettings()
      end
    end,
  })
  ns.options = Options.New({ viewModel = viewModel })
  ns.options:Create()
end)
