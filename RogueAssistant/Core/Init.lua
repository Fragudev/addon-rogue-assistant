local ADDON_NAME, ns = ...

ns.name = ADDON_NAME

local PREFIX = "|cfffff569Rogue Assistant|r"

local function say(message)
  print(PREFIX .. " " .. message)
end

local function now()
  return ns.Platform.GetTime() or 0
end

-- Opens the saved variable. A db written by a newer addon is left untouched and the addon stays disabled.
local function initDatabase()
  local store, reason = ns.Store.Open(RogueAssistantDB, { now = now })
  if not store then
    ns.disabled = reason
    local schema = type(RogueAssistantDB) == "table" and RogueAssistantDB.schemaVersion or 0
    say(ns.L["app.schema_newer"]:format(schema))
    return
  end
  RogueAssistantDB = store:Db()
  ns.store = store
  ns.bus = ns.EventBus.New()
end

-- Turns the addon off on any class but the rogue: one line in the debug log, nothing printed.
local function startForPlayer()
  if ns.disabled or not ns.store then
    return
  end
  local token = ns.Platform.GetPlayerClassToken()
  if token ~= ns.Constants.CLASS_TOKEN then
    ns.disabled = "not_rogue"
    ns.store:Log("disabled: class token " .. tostring(token))
    return
  end
  local guid = ns.Platform.GetPlayerGUID()
  local profile = ns.store:Profile(guid, { class = token })
  if not profile then
    ns.disabled = "no_guid"
    ns.store:Log("disabled: player GUID unavailable")
    return
  end
  ns.guid = guid
  ns.profile = profile
  ns.settings = ns.Settings.New(profile.settings)
  ns.bus:Publish("addon.ready")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, loadedAddon)
  if event == "ADDON_LOADED" then
    if loadedAddon == ADDON_NAME then
      initDatabase()
    end
  elseif event == "PLAYER_LOGIN" then
    startForPlayer()
  end
end)
