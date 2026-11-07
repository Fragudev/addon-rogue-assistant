local _, ns = ...

-- Shows the poison alerts: one chat line per new alert and a small banner that fades after a few seconds. The banner
-- is a plain (non-secure) frame, and alerts never run in combat, so nothing here touches protected frames.
local View = {}
View.__index = View

local PREFIX = "|cfffff569Rogue Assistant|r"

-- Game event -> alerts trigger (alerts.triggers.<name>).
local TRIGGER_BY_EVENT = {
  READY_CHECK = "readycheck",
  PLAYER_REGEN_ENABLED = "combatEnd",
}

-- deps: alerts, viewModel, platform, L, say (function(line), defaults to print).
function View.New(deps)
  return setmetatable({
    alerts = deps.alerts,
    viewModel = deps.viewModel or ns.ViewModelPoisons,
    platform = deps.platform or ns.Platform,
    L = deps.L or ns.L,
    say = deps.say or print,
    remaining = 0,
  }, View)
end

function View:CreateBanner()
  local banner = CreateFrame("Frame", "RogueAssistantAlertBanner", UIParent)
  banner:SetSize(360, 40)
  banner:SetFrameStrata("HIGH")
  banner:SetPoint("TOP", UIParent, "TOP", 0, -160)
  banner.text = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  banner.text:SetPoint("CENTER", banner, "CENTER", 0, 0)
  banner:SetScript("OnUpdate", function(_, elapsed)
    self:OnUpdate(elapsed)
  end)
  banner:Hide()
  return banner
end

function View:OnUpdate(elapsed)
  self.remaining = self.remaining - elapsed
  if self.remaining <= 0 and self.banner then
    self.banner:Hide()
  end
end

-- Prints and shows `alerts` (a list from PoisonAlerts). Returns the texts.
function View:Show(alerts)
  local texts = {}
  for _, alert in ipairs(alerts) do
    texts[#texts + 1] = self.viewModel.AlertText(alert, { L = self.L })
  end
  if #texts == 0 then
    return texts
  end
  for _, text in ipairs(texts) do
    self.say(PREFIX .. " " .. text)
  end
  self.banner = self.banner or self:CreateBanner()
  self.banner.text:SetText(table.concat(texts, "\n"))
  self.banner:SetHeight(20 * #texts + 20)
  self.remaining = ns.Constants.BANNER_SECONDS
  self.banner:Show()
  return texts
end

function View:Check(trigger)
  return self:Show(self.alerts:Check(trigger))
end

function View:OnEvent(event)
  if event == "PLAYER_ENTERING_WORLD" then
    if self.platform.IsInInstance() == true then
      self:Check("instance")
    end
    return
  end
  local trigger = TRIGGER_BY_EVENT[event]
  if trigger then
    self:Check(trigger)
  end
end

function View:Start()
  self.driver = CreateFrame("Frame")
  self.driver:SetScript("OnEvent", function(_, event)
    self:OnEvent(event)
  end)
  for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "READY_CHECK", "PLAYER_REGEN_ENABLED" }) do
    self.platform.TryRegisterEvent(self.driver, event)
  end
end

ns.PoisonAlertsView = View

ns.Startup.Register(function()
  if ns.disabled then
    return
  end
  ns.poisonAlertsView = View.New({ alerts = ns.poisonAlerts })
  ns.poisonAlertsView:Start()
end)
