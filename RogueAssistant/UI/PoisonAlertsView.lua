local _, ns = ...

-- Shows the poison alerts: one chat line per new alert and a small banner that fades after a few seconds. The banner
-- is a plain (non-secure) frame, and alerts never run in combat, so nothing here touches protected frames. While the
-- layout is unlocked (layout.unlock / layout.lock) the banner stays on screen with a sample text and a drag handle;
-- its position is saved in alerts.position.
local View = {}
View.__index = View

local PREFIX = "|cfffff569Rogue Assistant|r"

-- Game event -> alerts trigger (alerts.triggers.<name>).
local TRIGGER_BY_EVENT = {
  READY_CHECK = "readycheck",
  PLAYER_REGEN_ENABLED = "combatEnd",
}

-- deps: alerts, settings, bus, viewModel, platform, L, say (function(line), defaults to print).
function View.New(deps)
  return setmetatable({
    alerts = deps.alerts,
    settings = deps.settings,
    bus = deps.bus,
    unlocked = false,
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
  banner:SetClampedToScreen(true)
  banner:SetMovable(true)
  banner.text = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  banner.text:SetPoint("CENTER", banner, "CENTER", 0, 0)
  banner:SetScript("OnUpdate", function(_, elapsed)
    self:OnUpdate(elapsed)
  end)
  banner.handle = ns.MoveHandle.Create(banner, {
    label = self.L["layout.name.alerts"],
    place = function(handle, target)
      handle:SetPoint("BOTTOMLEFT", target, "TOPLEFT", 0, 2)
    end,
    onDragStart = function()
      self:OnDragStart()
    end,
    onDragStop = function()
      self:OnDragStop()
    end,
  })
  banner:Hide()
  self:ApplyPosition(banner)
  return banner
end

function View:Banner()
  self.banner = self.banner or self:CreateBanner()
  return self.banner
end

-- Puts the banner where alerts.position says.
function View:ApplyPosition(banner)
  banner = banner or self.banner
  if not banner or self.moving then
    return
  end
  local position = self.settings:Get("alerts.position")
  banner:ClearAllPoints()
  banner:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
end

-- Layout ---------------------------------------------------------------------------------------------------------

function View:SetUnlocked(unlocked)
  self.unlocked = unlocked and true or false
  local banner = self:Banner()
  ns.MoveHandle.SetShown(banner, banner.handle, self.unlocked)
  if self.unlocked then
    banner.text:SetText(self.L["layout.sample.alerts"])
    banner:SetHeight(40)
    banner:Show()
  elseif self.remaining > 0 then
    self:Display()
  else
    banner:Hide()
  end
end

function View:OnDragStart()
  if not self.unlocked or not self.banner then
    return
  end
  self.moving = true
  self.banner:StartMoving()
end

function View:OnDragStop()
  if not self.moving then
    return
  end
  self.moving = false
  self.banner:StopMovingOrSizing()
  local point, _, relativePoint, x, y = self.banner:GetPoint()
  if point then
    self.settings:Set("alerts.position", { point = point, relativePoint = relativePoint, x = x, y = y })
  end
end

-- Banner -----------------------------------------------------------------------------------------------------------

-- Draws the alert texts kept by Show on the banner.
function View:Display()
  local banner = self:Banner()
  banner.text:SetText(table.concat(self.texts, "\n"))
  banner:SetHeight(20 * #self.texts + 20)
  banner:Show()
end

function View:OnUpdate(elapsed)
  if self.unlocked then
    return
  end
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
  self.texts = texts
  self.remaining = ns.Constants.BANNER_SECONDS
  -- Unlocked, the banner keeps its sample text; a still-active alert is drawn when the layout locks.
  if self.unlocked then
    self:Banner()
  else
    self:Display()
  end
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
  if self.bus then
    self.bus:Subscribe("layout.unlock", function()
      self:SetUnlocked(true)
    end)
    self.bus:Subscribe("layout.lock", function()
      self:SetUnlocked(false)
    end)
  end
end

ns.PoisonAlertsView = View

ns.Startup.Register(function()
  if ns.disabled then
    return
  end
  ns.poisonAlertsView = View.New({ alerts = ns.poisonAlerts, settings = ns.settings, bus = ns.bus })
  ns.poisonAlertsView:Start()
end)
