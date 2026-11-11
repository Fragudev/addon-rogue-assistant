local _, ns = ...

-- Entry point: loads the saved variables, builds the bar out of combat and routes client events.
local Init = {}

local C = ns.Constants
local Api = ns.Api
local Bar = ns.Bar

local EVENTS = {
  "ADDON_LOADED",
  "PLAYER_ENTERING_WORLD",
  "PLAYER_REGEN_ENABLED",
  "PLAYER_REGEN_DISABLED",
  "BAG_UPDATE_DELAYED",
  "PLAYER_EQUIPMENT_CHANGED",
  "UNIT_INVENTORY_CHANGED",
  "GET_ITEM_INFO_RECEIVED",
}

local frame = CreateFrame("Frame")
local elapsedSinceTick = 0

function Init.OnUpdate(_, elapsed)
  elapsedSinceTick = elapsedSinceTick + elapsed
  if elapsedSinceTick >= C.TICK_SECONDS then
    elapsedSinceTick = 0
    Bar.Tick(Api.Now())
  end
end

-- Builds the bar unless the player is in combat (then PLAYER_REGEN_ENABLED tries again).
function Init.Start()
  if Bar.anchor or Api.InCombat() then
    return
  end
  Bar.Create(ns.db)
  ns.MinimapButton.Create()
  frame:SetScript("OnUpdate", Init.OnUpdate)
end

function Init.OnEvent(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= C.ADDON then
      return
    end
    RogueAssistantDB = ns.Store.Load(RogueAssistantDB)
    ns.db = RogueAssistantDB
    ns.Locale.Use(Api.GetLocale())
    Init.Start()
    Api.Print(ns.L("msg.loaded"))
  elseif event == "PLAYER_REGEN_ENABLED" then
    if Bar.anchor then
      Bar.OnCombatEnded()
    else
      Init.Start()
    end
  elseif event == "PLAYER_REGEN_DISABLED" then
    Bar.OnCombatStarted()
  elseif event == "UNIT_INVENTORY_CHANGED" then
    if ... == "player" then
      Bar.Refresh()
      Bar.Tick(Api.Now())
    end
  else
    Bar.Refresh()
  end
end

for _, event in ipairs(EVENTS) do
  pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", Init.OnEvent)

Init.frame = frame
ns.Init = Init
