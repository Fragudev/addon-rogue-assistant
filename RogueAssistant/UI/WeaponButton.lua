local _, ns = ...

-- One button per weapon: the weapon's icon, the poison charges above it, and below it one row per enchant (a poison and
-- a stone can sit on the same weapon on Forever): a small poison or stone icon and the time left. A warning glow, no
-- tooltip, and a click that opens its flyout.
--
-- The button is a SecureHandlerClickTemplate: its click runs a restricted snippet that shows or hides the flyout, which
-- the client allows in combat. Opening one flyout closes the other.
local WeaponButton = {}

local C = ns.Constants
local L = ns.L
local WeaponState = ns.WeaponState

local ROW_ICON = {
  poison = "Interface\\Icons\\Trade_BrewPoison",
  stone = "Interface\\Icons\\INV_Stone_SharpeningStone_01",
}
local ROW_ICON_SIZE = 12
local ROW_HEIGHT = 14
local ROWS = 2

local TOGGLE = [[
  local flyout = self:GetFrameRef("flyout")
  if not flyout then
    return
  end
  if flyout:IsShown() then
    flyout:Hide()
    return
  end
  local other = self:GetFrameRef("other")
  if other then
    other:Hide()
  end
  flyout:Show()
]]

local function text(button, point, relativePoint, x, y)
  local fontString = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fontString:SetPoint(point, button, relativePoint, x, y)
  return fontString
end

function WeaponButton.Create(parent, slot)
  local button = CreateFrame("Button", "RogueAssistantWeapon" .. slot, parent, "SecureHandlerClickTemplate")
  button.slot = slot
  button:SetSize(C.BUTTON_SIZE, C.BUTTON_SIZE)
  button:RegisterForClicks("AnyUp")
  button:SetAttribute("_onclick", TOGGLE)

  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetPoint("TOPLEFT", -2, 2)
  background:SetPoint("BOTTOMRIGHT", 2, -2)
  background:SetColorTexture(0, 0, 0, 0.9)

  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetAllPoints()
  button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  button.glow = button:CreateTexture(nil, "OVERLAY")
  button.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  button.glow:SetBlendMode("ADD")
  button.glow:SetVertexColor(1, 0.15, 0.15)
  button.glow:SetSize(C.BUTTON_SIZE * 1.8, C.BUTTON_SIZE * 1.8)
  button.glow:SetPoint("CENTER")
  button.glow:Hide()

  button.label = text(button, "BOTTOMLEFT", "TOPLEFT", 0, 2)
  button.label:SetText(L("slot." .. slot))
  button.charges = text(button, "BOTTOMRIGHT", "TOPRIGHT", 0, 2)
  button.rows = {}
  for index = 1, ROWS do
    local row = {}
    row.text = text(button, "TOP", "BOTTOM", ROW_ICON_SIZE / 2 + 1, -2 - (index - 1) * ROW_HEIGHT)
    row.icon = button:CreateTexture(nil, "OVERLAY")
    row.icon:SetSize(ROW_ICON_SIZE, ROW_ICON_SIZE)
    row.icon:SetPoint("RIGHT", row.text, "LEFT", -2, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon:Hide()
    button.rows[index] = row
  end
  button.missing = text(button, "CENTER", "CENTER", 0, 0)
  button.missing:SetText(L("button.missing"))
  button.missing:SetTextColor(1, 0.25, 0.25)
  button.missing:Hide()

  return button
end

-- Gives the button its flyout and the other weapon's flyout (out of combat only).
function WeaponButton.Link(button, flyout, other)
  SecureHandlerSetFrameRef(button, "flyout", flyout)
  if other then
    SecureHandlerSetFrameRef(button, "other", other)
  end
end

-- Draws a state of WeaponState.Build with `icon`. Only non-protected regions change, so it is safe in combat.
function WeaponButton.Render(button, state, icon)
  button.state = state
  button.icon:SetTexture(icon)
  button.icon:SetDesaturated(state.status ~= "active")
  for index, row in ipairs(button.rows) do
    local enchant = state.rows and state.rows[index]
    if enchant then
      row.icon:SetTexture(ROW_ICON[enchant.kind])
      row.icon:Show()
      row.text:SetText(WeaponState.FormatTime(enchant.seconds))
    else
      row.icon:Hide()
      row.text:SetText("")
    end
  end
  button.charges:SetText(state.charges and tostring(state.charges) or "")
  button.missing:SetShown(state.status == "missing")
  button.glow:SetShown(state.warning)
end

ns.WeaponButton = WeaponButton
