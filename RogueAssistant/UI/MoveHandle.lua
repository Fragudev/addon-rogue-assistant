local _, ns = ...

-- The drag handle shown while the layout is unlocked: a translucent bar with the name of the element, plus a
-- translucent backdrop over the element itself. Used by the elements that are not tracker groups (the alert banner and
-- the weapon status lines); `target` is the plain frame that moves.
local MoveHandle = {}

local HANDLE_HEIGHT = 16
local HANDLE_WIDTH = 140

-- options: label (text), place(handle, target) (anchors the handle), onDragStart(), onDragStop().
-- Returns the handle (hidden). `target.moveBackground` is the backdrop, shown and hidden with MoveHandle.SetShown.
function MoveHandle.Create(target, options)
  target.moveBackground = target:CreateTexture(nil, "BACKGROUND")
  target.moveBackground:SetAllPoints(target)
  target.moveBackground:SetColorTexture(1, 0.96, 0.41, 0.35)
  target.moveBackground:Hide()
  local handle = CreateFrame("Frame", nil, target)
  handle:SetSize(HANDLE_WIDTH, HANDLE_HEIGHT)
  options.place(handle, target)
  handle.background = handle:CreateTexture(nil, "BACKGROUND")
  handle.background:SetAllPoints(handle)
  handle.background:SetColorTexture(1, 0.96, 0.41, 0.35)
  handle.label = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  handle.label:SetPoint("LEFT", handle, "LEFT", 4, 0)
  handle.label:SetText(options.label)
  handle:EnableMouse(true)
  handle:RegisterForDrag("LeftButton")
  handle:SetScript("OnDragStart", options.onDragStart)
  handle:SetScript("OnDragStop", options.onDragStop)
  handle:Hide()
  return handle
end

-- Shows or hides the handle and the backdrop together.
function MoveHandle.SetShown(target, handle, shown)
  handle:SetShown(shown)
  target.moveBackground:SetShown(shown)
end

ns.MoveHandle = MoveHandle
