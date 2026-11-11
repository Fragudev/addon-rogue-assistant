local _, ns = ...

-- The bar: both weapon buttons, their flyouts and the move handle. It reads the client through ns.Api and keeps every
-- change of a secure frame out of combat, deferring it to the end of the fight.
local Bar = {}

local C = ns.Constants
local Api = ns.Api
local L = ns.L
local Inventory = ns.Inventory
local WeaponState = ns.WeaponState
local Flyout = ns.Flyout
local WeaponButton = ns.WeaponButton

Bar.DEFAULT_POSITION = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -180 }

local EMPTY_SLOT_ICON = {
  [C.SLOT_MAIN_HAND] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand",
  [C.SLOT_OFF_HAND] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-SecondaryHand",
}

local function createHandle(anchor)
  local handle = CreateFrame("Button", nil, anchor)
  handle:SetSize(120, 20)
  handle:SetPoint("TOP", anchor, "BOTTOM", 0, -22)
  handle:EnableMouse(true)
  handle:RegisterForDrag("LeftButton")

  local background = handle:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints()
  background:SetColorTexture(0.1, 0.1, 0.1, 0.85)
  local label = handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("CENTER")
  label:SetText(L("handle.text"))

  handle:SetScript("OnDragStart", function()
    if not Api.InCombat() then
      Bar.dragging = true
      anchor:StartMoving()
    end
  end)
  handle:SetScript("OnDragStop", Bar.StopDragging)
  handle:Hide()
  return handle
end

-- Builds the bar (out of combat only: secure frames cannot be created in combat).
function Bar.Create(db)
  if Bar.anchor then
    return Bar.anchor
  end
  Bar.db = db
  Bar.learner = WeaponState.NewLearner(db.enchants)
  Bar.unlocked = false

  local anchor = CreateFrame("Frame", "RogueAssistantBar", UIParent)
  anchor:SetSize(2 * C.BUTTON_SIZE + C.BUTTON_GAP, C.BUTTON_SIZE)
  anchor:SetMovable(true)
  anchor:SetClampedToScreen(true)
  Bar.anchor = anchor

  Bar.buttons = {}
  Bar.flyouts = {}
  for index, slot in ipairs(C.SLOTS) do
    local button = WeaponButton.Create(anchor, slot)
    button:SetPoint("LEFT", anchor, "LEFT", (index - 1) * (C.BUTTON_SIZE + C.BUTTON_GAP), 0)
    local flyout = Flyout.Create(anchor, slot, Bar.OnApply)
    flyout:SetPoint("BOTTOM", button, "TOP", 0, 18)
    Bar.buttons[slot] = button
    Bar.flyouts[slot] = flyout
  end
  local main, off = C.SLOT_MAIN_HAND, C.SLOT_OFF_HAND
  WeaponButton.Link(Bar.buttons[main], Bar.flyouts[main], Bar.flyouts[off])
  WeaponButton.Link(Bar.buttons[off], Bar.flyouts[off], Bar.flyouts[main])

  Bar.handle = createHandle(anchor)
  Bar.ApplyPosition()
  Bar.Refresh()
  Bar.Tick(Api.Now())
  return anchor
end

-- Rebuilds both flyouts from the bags. In combat only the counts change and the rebuild waits for the fight to end.
function Bar.Refresh()
  if not Bar.anchor then
    return
  end
  local counts = Inventory.Counts(Api)
  if Api.InCombat() then
    Bar.refreshPending = true
    for _, slot in ipairs(C.SLOTS) do
      Flyout.UpdateCounts(Bar.flyouts[slot], counts)
    end
    return
  end
  Bar.refreshPending = false
  for _, slot in ipairs(C.SLOTS) do
    local weapon = Inventory.DescribeWeapon(Api, slot)
    Flyout.SetItems(Bar.flyouts[slot], Inventory.Applicable(counts, weapon))
  end
end

-- Ends a drag and saves the position. The anchor holds secure frames, so it is only touched out of combat.
function Bar.StopDragging()
  if not Bar.dragging or Api.InCombat() then
    return
  end
  Bar.dragging = false
  Bar.anchor:StopMovingOrSizing()
  Bar.SavePosition()
end

-- PLAYER_REGEN_DISABLED arrives just before the combat lockdown: a drag in progress ends there.
function Bar.OnCombatStarted()
  Bar.StopDragging()
end

function Bar.OnCombatEnded()
  if Bar.positionPending then
    Bar.ApplyPosition()
  end
  if Bar.refreshPending then
    Bar.Refresh()
  end
end

-- The icon of a weapon button: the item that made the enchant when known, else the weapon, else the empty slot.
function Bar.IconFor(slot, state)
  if state.itemID then
    local icon = Api.GetItemIcon(state.itemID)
    if icon then
      return icon
    end
  end
  return Api.GetEquippedTexture(slot) or EMPTY_SLOT_ICON[slot]
end

-- Reads the weapon enchants and redraws both buttons.
function Bar.Tick(now)
  if not Bar.anchor then
    return
  end
  local enchants = Api.GetWeaponEnchants()
  for _, slot in ipairs(C.SLOTS) do
    local enchant = enchants and enchants[slot]
    Bar.learner:Observe(slot, enchant, now)
    local equipped = Api.GetEquippedItemID(slot)
    if equipped then
      equipped = true
    end
    local state = WeaponState.Build(enchant, {
      equipped = equipped,
      warnSeconds = Bar.db.warnMinutes * 60,
      enchants = Bar.db.enchants,
    })
    WeaponButton.Render(Bar.buttons[slot], state, Bar.IconFor(slot, state))
  end
end

function Bar.OnApply(slot, itemID)
  Bar.learner:NoteApply(slot, itemID, Api.Now())
end

-- Shows or hides the move handle. Returns false in combat or before the bar exists.
function Bar.SetUnlocked(unlocked)
  if not Bar.anchor or Api.InCombat() then
    return false
  end
  Bar.unlocked = unlocked and true or false
  Bar.handle:SetShown(Bar.unlocked)
  return true
end

function Bar.SavePosition()
  local point, _, relativePoint, x, y = Bar.anchor:GetPoint()
  if point then
    Bar.db.position = { point = point, relativePoint = relativePoint, x = x, y = y }
  end
end

-- Places the bar at the saved position (deferred in combat). Returns false when deferred.
function Bar.ApplyPosition()
  if Api.InCombat() then
    Bar.positionPending = true
    return false
  end
  Bar.positionPending = false
  local position = Bar.db.position or Bar.DEFAULT_POSITION
  Bar.anchor:ClearAllPoints()
  Bar.anchor:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
  return true
end

-- Moves the bar back to the default position. Returns false in combat or before the bar exists.
function Bar.ResetPosition()
  if not Bar.anchor or Api.InCombat() then
    return false
  end
  Bar.db.position = nil
  return Bar.ApplyPosition()
end

ns.Bar = Bar
