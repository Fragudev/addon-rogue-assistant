local _, ns = ...

-- The list that opens above a weapon button: one secure row per item in the bags that fits the weapon.
--
-- A row is a SecureActionButtonTemplate with type "item", item "item:<id>" and target-slot <16|17>: the template uses
-- the item and, because the item starts a spell that targets an item, applies it to that inventory slot. That works in
-- combat. What does not work in combat is changing the rows (attributes, show, hide, size), so the list is rebuilt
-- out of combat only; in combat just the counts change.
local Flyout = {}

local C = ns.Constants
local Api = ns.Api
local L = ns.L

local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local EMPTY_WIDTH = 170
local EMPTY_HEIGHT = 40

-- Runs in the restricted environment before a row's click: closes the flyout (allowed in combat).
local HIDE_ON_CLICK = [[
  local flyout = self:GetFrameRef("flyout")
  if flyout then
    flyout:Hide()
  end
]]

local function showTooltip(row)
  if not row.itemID or type(GameTooltip) ~= "table" then
    return
  end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:SetItemByID(row.itemID)
  GameTooltip:Show()
end

local function hideTooltip()
  if type(GameTooltip) == "table" then
    GameTooltip:Hide()
  end
end

local function createRow(flyout, index, onApply)
  local row = CreateFrame("Button", flyout:GetName() .. "Row" .. index, flyout, "SecureActionButtonTemplate")
  row:SetSize(C.ROW_SIZE, C.ROW_SIZE)
  row:SetPoint("BOTTOM", flyout, "BOTTOM", 0, C.FLYOUT_PADDING + (index - 1) * (C.ROW_SIZE + C.ROW_GAP))
  -- The template runs the action on the down or the up click depending on useOnKeyDown, which falls back to the
  -- ActionButtonUseKeyDown CVar (on by default). Fixing it to false makes the release fire whatever the CVar says.
  row:RegisterForClicks("AnyUp")
  row:SetAttribute("useOnKeyDown", false)
  row:SetAttribute("type", "item")
  row:SetAttribute("target-slot", flyout.slot)

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetAllPoints()
  row.count = row:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  row.count:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 2)
  row:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

  SecureHandlerSetFrameRef(row, "flyout", flyout)
  SecureHandlerWrapScript(row, "OnClick", flyout, HIDE_ON_CLICK)
  row:SetScript("PostClick", function(self)
    if self.itemID then
      onApply(flyout.slot, self.itemID)
    end
  end)
  row:SetScript("OnEnter", showTooltip)
  row:SetScript("OnLeave", hideTooltip)
  row:Hide()
  return row
end

-- Sizes the flyout for `shown` rows (0 shows the "nothing fits" text).
local function layout(flyout, shown)
  if shown == 0 then
    flyout:SetSize(EMPTY_WIDTH, EMPTY_HEIGHT)
    return
  end
  flyout:SetSize(C.ROW_SIZE + 2 * C.FLYOUT_PADDING, 2 * C.FLYOUT_PADDING + shown * C.ROW_SIZE + (shown - 1) * C.ROW_GAP)
end

-- Creates the hidden flyout of `slot`. onApply(slot, itemID) runs after a row is clicked.
function Flyout.Create(parent, slot, onApply)
  local flyout = CreateFrame("Frame", "RogueAssistantFlyout" .. slot, parent, "SecureHandlerBaseTemplate")
  flyout.slot = slot
  flyout:SetFrameStrata("DIALOG")
  flyout:Hide()

  local background = flyout:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints()
  background:SetColorTexture(0, 0, 0, 0.85)

  flyout.empty = flyout:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  flyout.empty:SetPoint("CENTER")
  flyout.empty:SetWidth(EMPTY_WIDTH - 2 * C.FLYOUT_PADDING)
  flyout.empty:SetText(L("flyout.empty"))

  flyout.rows = {}
  for index = 1, C.MAX_ROWS do
    flyout.rows[index] = createRow(flyout, index, onApply)
  end
  layout(flyout, 0)
  return flyout
end

-- Fills the rows with `list` ({ itemID, count } in order). Returns false, changing nothing, in combat.
function Flyout.SetItems(flyout, list)
  if Api.InCombat() then
    return false
  end
  local shown = 0
  for index, row in ipairs(flyout.rows) do
    local entry = list[index]
    if entry then
      shown = index
      row.itemID = entry.itemID
      row:SetAttribute("item", "item:" .. entry.itemID)
      row.icon:SetTexture(Api.GetItemIcon(entry.itemID) or UNKNOWN_ICON)
      row.icon:SetDesaturated(false)
      row.count:SetText(tostring(entry.count))
      row:Show()
    else
      row.itemID = nil
      row:SetAttribute("item", nil)
      row:Hide()
    end
  end
  flyout.empty:SetShown(shown == 0)
  layout(flyout, shown)
  return true
end

-- Updates the counts of the rows already shown (safe in combat). A spent item stays listed, greyed out, until the
-- list can be rebuilt.
function Flyout.UpdateCounts(flyout, counts)
  for _, row in ipairs(flyout.rows) do
    if row.itemID then
      local count = counts[row.itemID] or 0
      row.count:SetText(tostring(count))
      row.icon:SetDesaturated(count == 0)
    end
  end
end

ns.Flyout = Flyout
