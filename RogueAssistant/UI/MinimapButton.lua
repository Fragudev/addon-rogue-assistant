local _, ns = ...

-- A round button on the minimap edge. Click: a small menu with the basic options (unlock or lock the bar, reset its
-- position, hide this button). Drag: moves the button around the minimap. Nothing here is secure, so it all works in
-- combat; the actions themselves refuse what combat forbids.
local MinimapButton = {}

local C = ns.Constants
local L = ns.L
local Bar = ns.Bar
local Actions = ns.Actions

local ICON = "Interface\\AddOns\\RogueAssistant\\Media\\rogue_assistant_logo"
local BUTTON_SIZE = 31
local MENU_WIDTH = 180
local ITEM_HEIGHT = 20
local MENU_PADDING = 8
local MAX_ITEMS = 4

local atan2 = math.atan2 or math.atan -- Lua 5.1 (the client) / 5.3+ (tests)

-- The menu entries, built when the menu opens so the lock entry matches the bar.
local function menuEntries()
  local lockEntry
  if Bar.unlocked then
    lockEntry = {
      text = L("menu.lock"),
      run = function()
        Actions.SetLocked(true)
      end,
    }
  else
    lockEntry = {
      text = L("menu.unlock"),
      run = function()
        Actions.SetLocked(false)
      end,
    }
  end
  return {
    lockEntry,
    { text = L("menu.reset"), run = Actions.ResetPosition },
    {
      text = L("menu.hide"),
      run = function()
        Actions.SetMinimapShown(false)
      end,
    },
  }
end

local function createMenu(button)
  local menu = CreateFrame("Frame", "RogueAssistantMinimapMenu", UIParent)
  menu:SetFrameStrata("DIALOG")
  menu:SetWidth(MENU_WIDTH)
  menu:SetPoint("TOPRIGHT", button, "BOTTOMLEFT", 0, 0)
  menu:EnableMouse(true)
  menu:Hide()

  local background = menu:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints()
  background:SetColorTexture(0.05, 0.05, 0.05, 0.92)

  local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", menu, "TOPLEFT", MENU_PADDING, -MENU_PADDING)
  title:SetText("Rogue Assistant")

  menu.items = {}
  for index = 1, MAX_ITEMS do
    local item = CreateFrame("Button", nil, menu)
    item:SetSize(MENU_WIDTH - 2 * MENU_PADDING, ITEM_HEIGHT)
    item:SetPoint("TOPLEFT", menu, "TOPLEFT", MENU_PADDING, -MENU_PADDING - index * ITEM_HEIGHT)
    item:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    item.label = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    item.label:SetPoint("LEFT", item, "LEFT", 4, 0)
    item:SetScript("OnClick", function(self)
      menu:Hide()
      if self.run then
        self.run()
      end
    end)
    item:Hide()
    menu.items[index] = item
  end

  -- Escape closes it, like the game's own panels.
  table.insert(UISpecialFrames, menu:GetName())
  return menu
end

local function openMenu(menu)
  local entries = menuEntries()
  for index, item in ipairs(menu.items) do
    local entry = entries[index]
    item.run = entry and entry.run
    item.label:SetText(entry and entry.text or "")
    item:SetShown(entry ~= nil)
  end
  menu:SetHeight(2 * MENU_PADDING + (#entries + 1) * ITEM_HEIGHT)
  menu:Show()
end

-- Places the button on the minimap edge at the saved angle.
local function place(button)
  local angle = math.rad(ns.db.minimapAngle)
  local radius = Minimap:GetWidth() / 2 + C.MINIMAP_BUTTON_OFFSET
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

-- The angle of the cursor around the minimap centre, in degrees from 0 to 360.
local function cursorAngle()
  local centerX, centerY = Minimap:GetCenter()
  local cursorX, cursorY = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  local degrees = math.deg(atan2(cursorY / scale - centerY, cursorX / scale - centerX))
  return degrees % 360
end

local function showTooltip(button)
  if type(GameTooltip) ~= "table" then
    return
  end
  GameTooltip:SetOwner(button, "ANCHOR_LEFT")
  GameTooltip:SetText("Rogue Assistant")
  GameTooltip:AddLine(L("minimap.click"), 1, 1, 1)
  GameTooltip:AddLine(L("minimap.drag"), 1, 1, 1)
  GameTooltip:Show()
end

local function hideTooltip()
  if type(GameTooltip) == "table" then
    GameTooltip:Hide()
  end
end

function MinimapButton.Create()
  if MinimapButton.button then
    return MinimapButton.button
  end
  local button = CreateFrame("Button", "RogueAssistantMinimapButton", Minimap)
  button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("AnyUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local icon = button:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", button, "CENTER", 0, 1)
  icon:SetTexture(ICON)
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  local menu = createMenu(button)
  button:SetScript("OnClick", function()
    hideTooltip()
    if menu:IsShown() then
      menu:Hide()
    else
      openMenu(menu)
    end
  end)
  button:SetScript("OnDragStart", function(self)
    self.dragging = true
    menu:Hide()
    self:SetScript("OnUpdate", function(dragged)
      ns.db.minimapAngle = cursorAngle()
      place(dragged)
    end)
  end)
  button:SetScript("OnDragStop", function(self)
    self.dragging = false
    self:SetScript("OnUpdate", nil)
  end)
  button:SetScript("OnEnter", showTooltip)
  button:SetScript("OnLeave", hideTooltip)

  MinimapButton.button = button
  MinimapButton.menu = menu
  MinimapButton.Apply()
  return button
end

-- Applies the saved angle and visibility.
function MinimapButton.Apply()
  local button = MinimapButton.button
  if not button then
    return
  end
  place(button)
  button:SetShown(not ns.db.minimapHidden)
  if ns.db.minimapHidden then
    MinimapButton.menu:Hide()
  end
end

ns.MinimapButton = MinimapButton
