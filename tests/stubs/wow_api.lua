-- luacheck: ignore 212/self
-- Minimal fake of the WoW client so the addon runs under busted. Specs call WowStub.Reset() in before_each and change
-- the client through WowStub.state:
--   inCombat, time, locale, weapon (the 8 values of GetWeaponEnchantInfo), equipment (slot -> item id),
--   items (item id -> { classID, subclassID }), names (item id -> name), bags (bag -> { { itemID, stackCount } })
-- Secure frames refuse protected changes in combat and record them in state.violations. Restricted snippets run as
-- real Lua against handles of the fake frames (WowStub.Click).

local WowStub = {}
local unpackValues = rawget(table, "unpack") or unpack

-- A value issecretvalue() reports as secret.
WowStub.Secret = setmetatable({}, {
  __tostring = function()
    return "<secret>"
  end,
})

local state

local function newState()
  return {
    inCombat = false,
    cvarUseKeyDown = true,
    time = 1000,
    locale = "enUS",
    weapon = { false, 0, 0, 0, false, 0, 0, 0 },
    equipment = { [16] = 1001, [17] = 1002 },
    items = { [1001] = { classID = 2, subclassID = 15 }, [1002] = { classID = 2, subclassID = 15 } },
    names = {},
    bags = {},
    frames = {},
    violations = {},
    actions = {},
    messages = {},
  }
end

-- Textures and font strings: they remember what they were given; any other capitalised method is a no-op.
local function newRegion(kind)
  local region = { kind = kind, shown = true }
  function region:SetText(text)
    self.text = text
  end
  function region:GetText()
    return self.text
  end
  function region:SetTexture(texture)
    self.texture = texture
  end
  function region:GetTexture()
    return self.texture
  end
  function region:SetDesaturated(flag)
    self.desaturated = flag and true or false
  end
  function region:Show()
    self.shown = true
  end
  function region:Hide()
    self.shown = false
  end
  function region:SetShown(shown)
    self.shown = shown and true or false
  end
  function region:IsShown()
    return self.shown
  end
  return setmetatable(region, {
    __index = function(_, name)
      if type(name) == "string" and name:match("^%u") then
        return function() end
      end
      return nil
    end,
  })
end

local Frame = {}

local function protectedChange(frame, method)
  if frame.protected and state.inCombat then
    state.violations[#state.violations + 1] = (frame.name or "?") .. ":" .. method
    return true
  end
  return false
end

function Frame:GetName()
  return self.name
end
function Frame:GetParent()
  return self.parent
end
function Frame:SetAttribute(key, value)
  if not protectedChange(self, "SetAttribute") then
    self.attributes[key] = value
  end
end
function Frame:GetAttribute(key)
  return self.attributes[key]
end
function Frame:SetScript(script, fn)
  self.scripts[script] = fn
end
function Frame:GetScript(script)
  return self.scripts[script]
end
function Frame:Show()
  if not protectedChange(self, "Show") then
    self.shown = true
  end
end
function Frame:Hide()
  if not protectedChange(self, "Hide") then
    self.shown = false
  end
end
function Frame:SetShown(shown)
  if shown then
    self:Show()
  else
    self:Hide()
  end
end
function Frame:IsShown()
  return self.shown
end
function Frame:SetSize(width, height)
  if not protectedChange(self, "SetSize") then
    self.width, self.height = width, height
  end
end
function Frame:GetSize()
  return self.width, self.height
end
function Frame:GetWidth()
  return self.width
end
function Frame:GetCenter()
  if self.center then
    return self.center[1], self.center[2]
  end
  return nil
end
function Frame:SetFrameLevel(level)
  self.level = level
end
function Frame:GetFrameLevel()
  return self.level
end
function Frame:GetEffectiveScale()
  return self.scale or 1
end
function Frame:ClearAllPoints()
  if not protectedChange(self, "ClearAllPoints") then
    self.points = {}
  end
end
function Frame:SetPoint(point, relativeTo, relativePoint, x, y)
  if not protectedChange(self, "SetPoint") then
    self.points[#self.points + 1] = { point, relativeTo, relativePoint, x, y }
  end
end
function Frame:GetPoint()
  local first = self.points[1]
  if not first then
    return nil
  end
  local relativeTo = first[2]
  if type(relativeTo) == "string" then
    relativeTo = nil
  end
  return first[1], relativeTo, first[3], first[4], first[5]
end
function Frame:RegisterEvent(event)
  self.events[event] = true
end
function Frame:UnregisterEvent(event)
  self.events[event] = nil
end
function Frame:CreateTexture()
  local region = newRegion("texture")
  self.regions[#self.regions + 1] = region
  return region
end
function Frame:CreateFontString()
  local region = newRegion("fontstring")
  self.regions[#self.regions + 1] = region
  return region
end
function Frame:StartMoving()
  self.moving = true
end
function Frame:StopMovingOrSizing()
  self.moving = false
end

local function newFrame(frameType, name, parent, template)
  local frame = setmetatable({
    frameType = frameType,
    name = name,
    parent = parent,
    template = template or "",
    protected = (template or ""):find("Secure") ~= nil,
    attributes = {},
    scripts = {},
    wraps = {},
    events = {},
    regions = {},
    points = {},
    shown = true,
    level = type(parent) == "table" and (parent.level or 0) + 1 or 0,
  }, {
    __index = function(_, key)
      if Frame[key] then
        return Frame[key]
      end
      if type(key) == "string" and key:match("^%u") then
        return function() end
      end
      return nil
    end,
  })
  if name then
    _G[name] = frame
  end
  state.frames[#state.frames + 1] = frame
  return frame
end

-- Handles of the restricted environment: only what the addon's snippets use, allowed in combat.
local function handle(frame)
  if not frame then
    return nil
  end
  return {
    GetFrameRef = function(_, label)
      return handle(frame.attributes["frameref-" .. label])
    end,
    IsShown = function()
      return frame.shown
    end,
    Show = function()
      frame.shown = true
    end,
    Hide = function()
      frame.shown = false
    end,
  }
end

-- Runs a restricted snippet with `self` bound to the handle of `frame` and an empty global environment.
function WowStub.RunSnippet(body, frame, button)
  local source = "local self, button, down = ...\n" .. body
  local chunk
  if setfenv then
    chunk = assert(loadstring(source))
    setfenv(chunk, {})
  else
    chunk = assert(load(source, "snippet", "t", {}))
  end
  return chunk(handle(frame), button, false)
end

local function attribute(frame, name, button)
  local suffix = button == "RightButton" and "2" or "1"
  local value = frame.attributes[name .. suffix]
  if value == nil then
    value = frame.attributes[name]
  end
  return value
end

-- A mouse click on `frame`, the way the client dispatches it to the templates the addon uses.
function WowStub.Click(frame, button)
  button = button or "LeftButton"
  local wrap = frame.wraps.OnClick
  if wrap and wrap.pre then
    local result = WowStub.RunSnippet(wrap.pre, frame, button)
    if result == false then
      return
    end
  end
  if frame.template:find("SecureHandlerClickTemplate") then
    WowStub.RunSnippet(frame.attributes._onclick, frame, button)
  end
  -- SecureActionButton_OnClick: an addon mouse click is never a "secure mouse press", so the action runs on the down
  -- click when useOnKeyDown (or the ActionButtonUseKeyDown CVar, on by default) says so. WowStub.Click is a release.
  local useOnKeyDown = frame.attributes.useOnKeyDown
  if useOnKeyDown == nil then
    useOnKeyDown = state.cvarUseKeyDown
  end
  if frame.template:find("SecureActionButtonTemplate") and not useOnKeyDown then
    state.actions[#state.actions + 1] = {
      type = attribute(frame, "type", button),
      item = attribute(frame, "item", button),
      slot = attribute(frame, "target-slot", button),
    }
  end
  if frame.scripts.OnClick then
    frame.scripts.OnClick(frame, button, false)
  end
  if frame.scripts.PostClick then
    frame.scripts.PostClick(frame, button, false)
  end
end

-- Delivers a client event to every frame registered for it.
function WowStub.Fire(event, ...)
  for _, frame in ipairs(state.frames) do
    if frame.events[event] and frame.scripts.OnEvent then
      frame.scripts.OnEvent(frame, event, ...)
    end
  end
end

-- Runs the OnUpdate scripts with `elapsed` seconds.
function WowStub.Update(elapsed)
  for _, frame in ipairs(state.frames) do
    if frame.scripts.OnUpdate then
      frame.scripts.OnUpdate(frame, elapsed)
    end
  end
end

function WowStub.Messages()
  return state.messages
end

function WowStub.Reset()
  if state then
    for _, frame in ipairs(state.frames) do
      if frame.name then
        _G[frame.name] = nil
      end
    end
  end
  state = newState()
  WowStub.state = state

  _G.RogueAssistantDB = nil
  _G.SLASH_RAS1 = nil
  _G.SLASH_RAS2 = nil
  _G.SlashCmdList = {}

  _G.CreateFrame = function(frameType, name, parent, template)
    return newFrame(frameType, name, parent, template)
  end
  _G.UIParent = newFrame("Frame", "UIParent")
  _G.Minimap = newFrame("Frame", "Minimap", _G.UIParent)
  _G.Minimap.width, _G.Minimap.height = 140, 140
  _G.Minimap.center = { 1000, 700 }
  _G.UISpecialFrames = {}
  state.cursor = { 0, 0 }
  _G.GetCursorPosition = function()
    return state.cursor[1], state.cursor[2]
  end
  _G.DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, message)
      state.messages[#state.messages + 1] = message
    end,
  }
  _G.GameTooltip = setmetatable({ lines = {} }, {
    __index = function(tooltip, key)
      if key == "SetInventoryItem" then
        return function(_, _, slot)
          tooltip.inventorySlots = tooltip.inventorySlots or {}
          tooltip.inventorySlots[#tooltip.inventorySlots + 1] = slot
          return state.equipment[slot] ~= nil
        end
      end
      if key == "AddLine" or key == "SetText" then
        return function(_, text)
          tooltip.lines[#tooltip.lines + 1] = text
        end
      end
      if type(key) == "string" and key:match("^%u") then
        return function() end
      end
      return nil
    end,
  })

  _G.SecureHandlerSetFrameRef = function(frame, label, ref)
    if not protectedChange(frame, "SetFrameRef") then
      frame.attributes["frameref-" .. label] = ref
    end
  end
  _G.SecureHandlerWrapScript = function(frame, script, header, pre, post)
    if not protectedChange(frame, "WrapScript") then
      frame.wraps[script] = { header = header, pre = pre, post = post }
    end
  end

  _G.issecretvalue = function(value)
    return rawequal(value, WowStub.Secret)
  end
  _G.InCombatLockdown = function()
    return state.inCombat
  end
  _G.GetTime = function()
    return state.time
  end
  _G.GetLocale = function()
    return state.locale
  end
  _G.GetWeaponEnchantInfo = function()
    return unpackValues(state.weapon, 1, math.max(8, #state.weapon))
  end
  _G.GetInventoryItemID = function(_, slot)
    return state.equipment[slot]
  end
  _G.GetInventoryItemTexture = function(_, slot)
    local itemID = state.equipment[slot]
    return itemID and ("weapon-" .. itemID) or nil
  end
  _G.C_Item = {
    GetItemInfoInstant = function(itemID)
      local info = state.items[itemID]
      if not info then
        return nil
      end
      return itemID, "Weapon", "Dagger", "INVTYPE_WEAPON", "item-icon-" .. itemID, info.classID, info.subclassID
    end,
    GetItemNameByID = function(itemID)
      return state.names[itemID]
    end,
    GetItemIconByID = function(itemID)
      return "icon-" .. itemID
    end,
  }
  state.tooltips = {}
  _G.C_TooltipInfo = {
    GetInventoryItem = function(_, slot)
      local lines = state.tooltips[slot]
      if not lines then
        return nil
      end
      local data = { lines = {} }
      for index, line in ipairs(lines) do
        data.lines[index] = { leftText = line[1], rightText = line[2] }
      end
      return data
    end,
  }
  _G.C_Container = {
    GetContainerNumSlots = function(bag)
      local contents = state.bags[bag]
      return contents and #contents or 0
    end,
    GetContainerItemInfo = function(bag, slot)
      local contents = state.bags[bag]
      local item = contents and contents[slot]
      if not item then
        return nil
      end
      return { itemID = item.itemID, stackCount = item.stackCount }
    end,
  }
end

-- Loads every file of the TOC into a fresh namespace and delivers ADDON_LOADED. Returns the namespace.
function WowStub.LoadAddon(options)
  local Loader = require("tests.support.loader")
  local ns = Loader.Load(Loader.TocFiles())
  if not (options and options.skipLoaded) then
    WowStub.Fire("ADDON_LOADED", "RogueAssistant")
  end
  return ns
end

-- Puts `items` ({ itemID, count } pairs) in the backpack.
function WowStub.SetBag(items)
  local contents = {}
  for _, item in ipairs(items) do
    contents[#contents + 1] = { itemID = item[1], stackCount = item[2] }
  end
  state.bags[0] = contents
end

_G.WowStub = WowStub
WowStub.Reset()
return WowStub
