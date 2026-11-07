-- luacheck: ignore 212/self
-- Minimal WoW API stubs so addon logic can run under busted outside the client.
-- Specs call WowStub.Reset() in before_each, then change the client with:
--   WowStub.state.<field>      data the default fakes read (class, guid, bags, auras, ...)
--   WowStub.Remove(path)       the API is missing
--   WowStub.Fail(path)         the API raises
--   WowStub.Set(path, fn)      the API is `fn`
--   WowStub.Secret             a value issecretvalue() reports as secret; it may sit in any field of a returned table

local WowStub = {}
-- A secret raises on everything the client forbids: arithmetic, ordering comparisons, length, indexing and calls.
-- type() stays legal. Equality is forbidden too (__eq raises) so a spec can detect code that compares a client value
-- before checking it: Lua only runs __eq between two tables sharing the metamethod, so a spec that wants the strict
-- check gives the compared sentinel this metatable (WowStub.MakeStrict).
local function forbidden()
  error("attempt to use a secret value", 2)
end
WowStub.Secret = setmetatable({}, {
  __tostring = function()
    return "<secret>"
  end,
  __add = forbidden,
  __sub = forbidden,
  __mul = forbidden,
  __div = forbidden,
  __mod = forbidden,
  __pow = forbidden,
  __unm = forbidden,
  __lt = forbidden,
  __le = forbidden,
  __eq = forbidden,
  __len = forbidden,
  __call = forbidden,
  __index = forbidden,
  __newindex = forbidden,
})

-- Gives `sentinel` (a table) the secret metatable: every == against another secret-like table now raises.
function WowStub.MakeStrict(sentinel)
  return setmetatable(sentinel, getmetatable(WowStub.Secret))
end

-- Stands in for a DurationObject: an opaque table that only widgets may consume.
function WowStub.DurationObject(label)
  return setmetatable({ label = label }, {
    __lt = forbidden,
    __le = forbidden,
    __add = forbidden,
    __sub = forbidden,
  })
end

local function newState()
  return {
    class = { "Rogue", "ROGUE", 4 },
    guid = "Player-1-0000ABCD",
    bags = {},
    auras = { player = {}, target = {} },
    spellbook = {},
    inCombat = false,
    instance = { false, "none" },
    time = 1000,
    weapon = { false, 0, 0, 0, false, 0, 0, 0 },
    missingTemplates = {},
    frames = {},
    violations = {},
    shift = false,
    equipment = { [16] = 1001, [17] = 1002 },
    -- Tracker fakes: per spell id cooldown tables, duration objects and charge tables; per aura instance id
    -- duration objects and display counts.
    cooldowns = {},
    cooldownObjects = {},
    charges = {},
    auraDurations = {},
    auraCounts = {},
    cooldownObjectFails = false,
    -- Settings UI: categories registered with Settings.RegisterCanvasLayoutCategory, and the ids opened.
    categories = {},
    opened = {},
  }
end

-- Regions (textures and font strings) remember what they were given. Any other method is a no-op.
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
  function region:SetAlpha(alpha)
    self.alpha = alpha
  end
  function region:SetVertexColor(...)
    self.vertex = { ... }
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

-- Frames record what the addon did to them. A frame made from a Secure* template is protected: changing its
-- attributes, visibility, anchors or size while state.inCombat is true is refused and recorded in state.violations
-- (the client blocks those calls the same way). Helpers for specs:
--   frame.attributes / frame.refs / frame.wraps / frame.hooks / frame.scripts / frame.events / frame.clicks
--   WowStub.Fire(frame, event, ...)     run the OnEvent script
--   WowStub.Click(frame, button)        run the PostClick hooks (the secure action itself cannot be simulated)
local function newFrame(frameType, name, parent, template)
  local state = WowStub.state
  local frame = {
    frameType = frameType,
    name = name,
    parent = parent,
    template = template,
    scripts = {},
    hooks = {},
    events = {},
    attributes = {},
    refs = {},
    wraps = {},
    points = {},
    shown = true,
    protected = template ~= nil and template:find("Secure", 1, true) ~= nil,
  }
  state.frames[#state.frames + 1] = frame

  local function guarded(op, apply)
    return function(self, ...)
      if self.protected and state.inCombat then
        state.violations[#state.violations + 1] = { frame = self.name, op = op, args = { ... } }
        return
      end
      return apply(self, ...)
    end
  end

  function frame:RegisterEvent(event)
    self.events[event] = true
  end
  function frame:RegisterUnitEvent(event, ...)
    self.events[event] = true
    self.unitEvents = self.unitEvents or {}
    self.unitEvents[event] = { ... }
  end
  function frame:SetStatusBarTexture(texture)
    self.statusBarTexture = texture
  end
  function frame:UnregisterEvent(event)
    self.events[event] = nil
  end
  function frame:SetScript(script, handler)
    self.scripts[script] = handler
  end
  function frame:GetScript(script)
    return self.scripts[script]
  end
  function frame:HookScript(script, handler)
    self.hooks[script] = self.hooks[script] or {}
    table.insert(self.hooks[script], handler)
  end
  function frame:RegisterForClicks(...)
    self.clicks = { ... }
  end
  function frame:IsProtected()
    return self.protected, self.protected
  end
  function frame:GetAttribute(attribute)
    return self.attributes[attribute]
  end
  function frame:CreateTexture()
    return newRegion("texture")
  end
  function frame:CreateFontString()
    return newRegion("fontstring")
  end
  function frame:GetPoint()
    local point = self.points[1]
    if point then
      return point[1], point[2], point[3], point[4], point[5]
    end
    return nil
  end
  function frame:IsShown()
    return self.shown
  end
  function frame:StartMoving()
    self.moving = true
  end
  function frame:StopMovingOrSizing()
    self.moving = false
  end
  function frame:SetParent(newParent)
    self.parent = newParent
  end
  function frame:SetChecked(checked)
    self.checked = checked and true or false
  end
  function frame:GetChecked()
    return self.checked
  end
  function frame:SetText(text)
    self.text = text
  end
  function frame:GetText()
    return self.text or ""
  end
  function frame:GetParent()
    return self.parent
  end
  -- Tracker widgets: Cooldown, StatusBar, alpha and mouse.
  function frame:SetAlpha(alpha)
    self.alpha = alpha
  end
  function frame:GetAlpha()
    return self.alpha or 1
  end
  function frame:EnableMouse(enabled)
    self.mouseEnabled = enabled
  end
  function frame:SetCooldown(start, duration)
    self.cooldown = { start = start, duration = duration }
    self.durationObject = nil
  end
  function frame:SetCooldownFromDurationObject(object)
    if state.cooldownObjectFails then
      error("stub failure: SetCooldownFromDurationObject")
    end
    self.durationObject = object
    self.cooldown = nil
  end
  function frame:Clear()
    self.cooldown, self.durationObject = nil, nil
  end
  function frame:SetMinMaxValues(minimum, maximum)
    self.minValue, self.maxValue = minimum, maximum
  end
  function frame:SetValue(value)
    self.value = value
  end
  function frame:SetHideCountdownNumbers(hide)
    self.hideNumbers = hide
  end

  -- Secure handler methods (SecureHandlerBaseTemplate).
  function frame:SetFrameRef(label, target)
    self.refs[label] = target
  end
  function frame:WrapScript(target, script, preBody, postBody)
    target.wraps[script] = { header = self, pre = preBody, post = postBody }
  end

  frame.SetAttribute = guarded("SetAttribute", function(self, attribute, value)
    self.attributes[attribute] = value
    self.attributeWrites = (self.attributeWrites or 0) + 1
  end)
  frame.Show = guarded("Show", function(self)
    self.shown = true
  end)
  frame.Hide = guarded("Hide", function(self)
    self.shown = false
  end)
  frame.SetShown = guarded("SetShown", function(self, shown)
    self.shown = shown and true or false
  end)
  frame.SetPoint = guarded("SetPoint", function(self, ...)
    table.insert(self.points, { ... })
  end)
  frame.ClearAllPoints = guarded("ClearAllPoints", function(self)
    self.points = {}
  end)
  frame.SetSize = guarded("SetSize", function(self, width, height)
    self.width, self.height = width, height
  end)
  frame.SetWidth = guarded("SetWidth", function(self, width)
    self.width = width
  end)
  frame.SetHeight = guarded("SetHeight", function(self, height)
    self.height = height
  end)
  frame.SetScale = guarded("SetScale", function(self, scale)
    self.scale = scale
  end)
  frame.SetMovable = guarded("SetMovable", function(self, movable)
    self.movable = movable
  end)

  return setmetatable(frame, {
    __index = function(_, key)
      if type(key) == "string" and key:match("^%u") then
        return function() end
      end
      return nil
    end,
  })
end

function WowStub.Fire(frame, event, ...)
  return frame.scripts.OnEvent(frame, event, ...)
end

function WowStub.Click(frame, button)
  for _, hook in ipairs(frame.hooks.PostClick or {}) do
    hook(frame, button, false)
  end
end

local function defaults()
  local state = WowStub.state
  return {
    ["C_AddOns.GetAddOnMetadata"] = function()
      return "@project-version@"
    end,
    ["CreateFrame"] = function(frameType, name, parent, template)
      if template and state.missingTemplates[template] then
        error("Couldn't find inherited node " .. template)
      end
      return newFrame(frameType, name, parent, template)
    end,
    ["GetInventoryItemID"] = function(_, slot)
      return state.equipment[slot]
    end,
    ["IsShiftKeyDown"] = function()
      return state.shift
    end,
    ["GetBuildInfo"] = function()
      return "11.0.0", "00000", "Jan 1 2026", 16001
    end,
    ["GetLocale"] = function()
      return "enUS"
    end,
    ["issecretvalue"] = function(value)
      return rawequal(value, WowStub.Secret)
    end,
    ["UnitClass"] = function()
      return unpack(state.class)
    end,
    ["UnitGUID"] = function()
      return state.guid
    end,
    ["IsPlayerSpell"] = function(spellId)
      return state.knownSpells ~= nil and state.knownSpells[spellId] == true
    end,
    ["C_Spell.GetSpellInfo"] = function(spellId)
      if type(spellId) == "string" then
        return { name = spellId, iconID = 300000 }
      end
      return { name = "Spell" .. spellId, iconID = 100000 + spellId }
    end,
    ["C_Spell.GetSpellCooldown"] = function(spellId)
      return state.cooldowns[spellId] or { startTime = 10, duration = 20, isEnabled = true, modRate = 1 }
    end,
    ["C_Spell.GetSpellCooldownDuration"] = function(spellId)
      local object = state.cooldownObjects[spellId]
      if object ~= nil then
        return object
      end
      return { durationObject = spellId }
    end,
    ["C_Spell.GetSpellCharges"] = function(spellId)
      return state.charges[spellId]
    end,
    ["C_UnitAuras.GetAuraDuration"] = function(_, auraInstanceID)
      return state.auraDurations[auraInstanceID]
    end,
    ["C_UnitAuras.GetAuraApplicationDisplayCount"] = function(_, auraInstanceID)
      return state.auraCounts[auraInstanceID]
    end,
    ["C_UnitAuras.GetPlayerAuraBySpellID"] = function(spellId)
      for _, aura in ipairs(state.auras.player) do
        if aura.spellId == spellId then
          return aura
        end
      end
      return nil
    end,
    ["C_UnitAuras.GetAuraDataByIndex"] = function(unit, index)
      return (state.auras[unit] or {})[index]
    end,
    ["GetWeaponEnchantInfo"] = function()
      return unpack(state.weapon, 1, 8)
    end,
    ["C_Container.GetContainerNumSlots"] = function(bag)
      return state.bags[bag] and state.bags[bag].size or 0
    end,
    ["C_Container.GetContainerItemInfo"] = function(bag, slot)
      return state.bags[bag] and state.bags[bag][slot] or nil
    end,
    ["C_Item.GetItemCount"] = function()
      return 3
    end,
    ["C_Item.GetItemNameByID"] = function(itemId)
      return "Item" .. itemId
    end,
    ["C_Item.GetItemIconByID"] = function(itemId)
      return 200000 + itemId
    end,
    ["C_SpellBook.GetNumSpellBookSkillLines"] = function()
      return #state.spellbook
    end,
    ["C_SpellBook.GetSpellBookSkillLineInfo"] = function(index)
      return state.spellbook[index]
    end,
    ["C_SpellBook.GetSpellBookItemInfo"] = function(index)
      return state.spellItems and state.spellItems[index] or nil
    end,
    ["InCombatLockdown"] = function()
      return state.inCombat
    end,
    ["IsInInstance"] = function()
      return unpack(state.instance)
    end,
    ["GetTime"] = function()
      return state.time
    end,
    ["Settings.RegisterCanvasLayoutCategory"] = function(frame, name)
      local category = { frame = frame, name = name, id = #state.categories + 1 }
      function category:GetID()
        return self.id
      end
      state.categories[#state.categories + 1] = category
      return category
    end,
    ["Settings.RegisterAddOnCategory"] = function(category)
      category.registered = true
    end,
    ["Settings.OpenToCategory"] = function(id)
      state.opened[#state.opened + 1] = id
    end,
  }
end

local function setPath(path, value)
  local parts = {}
  for part in path:gmatch("[^.]+") do
    parts[#parts + 1] = part
  end
  local target = _G
  for index = 1, #parts - 1 do
    if type(target[parts[index]]) ~= "table" then
      target[parts[index]] = {}
    end
    target = target[parts[index]]
  end
  target[parts[#parts]] = value
end

local installed = {}

function WowStub.Set(path, value)
  installed[path] = true
  setPath(path, value)
end

function WowStub.Remove(path)
  setPath(path, nil)
end

function WowStub.Fail(path)
  WowStub.Set(path, function()
    error("stub failure: " .. path)
  end)
end

-- Removes every stubbed global and installs the default fakes again with a fresh state.
function WowStub.Reset()
  for path in pairs(installed) do
    setPath(path, nil)
  end
  _G.C_Spell, _G.C_UnitAuras, _G.C_Container, _G.C_Item, _G.C_SpellBook, _G.C_AddOns = nil, nil, nil, nil, nil, nil
  _G.C_Secrets, _G.C_CooldownViewer, _G.Settings = nil, nil, nil
  installed = {}
  WowStub.state = newState()
  for path, fn in pairs(defaults()) do
    WowStub.Set(path, fn)
  end
  _G.UIParent = {}
  _G.SlashCmdList = {}
end

WowStub.Reset()
_G.WowStub = WowStub
