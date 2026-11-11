local _, ns = ...

-- What the player can ask for from a slash command or the minimap menu. Each action does the work and tells the
-- player what happened, so both entry points behave the same.
local Actions = {}

local Api = ns.Api
local L = ns.L
local Bar = ns.Bar

-- Unlocks (false: shows the drag zone over the buttons) or locks (true: only the buttons) the bar.
function Actions.SetLocked(locked)
  if Bar.SetUnlocked(not locked) then
    Api.Print(L(locked and "msg.locked" or "msg.unlocked"))
    return true
  end
  Api.Print(L("msg.combat"))
  return false
end

function Actions.ResetPosition()
  if Bar.ResetPosition() then
    Api.Print(L("msg.reset"))
    return true
  end
  Api.Print(L("msg.combat"))
  return false
end

-- Shows or hides the minimap button and remembers it.
function Actions.SetMinimapShown(shown)
  if not ns.db then
    return false
  end
  ns.db.minimapHidden = not shown
  if ns.MinimapButton then
    ns.MinimapButton.Apply()
  end
  Api.Print(L(shown and "msg.minimap.shown" or "msg.minimap.hidden"))
  return true
end

function Actions.ToggleMinimap()
  return Actions.SetMinimapShown(ns.db ~= nil and ns.db.minimapHidden)
end

ns.Actions = Actions
