local _, ns = ...

-- One button per weapon: the weapon's icon with the time left and the charges GetWeaponEnchantInfo reports, a warning,
-- and a click that opens its flyout. It has no tooltip. On Forever a weapon can carry a poison and a stone at once;
-- how the client reports both is not measured yet (docs/API_NOTES.md), so the button shows the one enchant it reports.
--
-- The button is a SecureHandlerClickTemplate: its click runs a restricted snippet that shows or hides the flyout, which
-- the client allows in combat. Opening one flyout closes the other.
local WeaponButton = {}

local C = ns.Constants
local L = ns.L
local WeaponState = ns.WeaponState

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
  button.timer = text(button, "TOP", "BOTTOM", 0, -2)
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
  if state.status == "active" then
    button.timer:SetText(WeaponState.FormatTime(state.seconds))
  else
    button.timer:SetText("")
  end
  button.charges:SetText(state.charges and tostring(state.charges) or "")
  button.missing:SetShown(state.status == "missing")
  button.glow:SetShown(state.warning)
end

ns.WeaponButton = WeaponButton
