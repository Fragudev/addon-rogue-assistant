-- Minimal WoW API stubs so addon logic can run under busted outside the client.
-- Specs call WowStub.Reset() in before_each, then change the client with:
--   WowStub.state.<field>      data the default fakes read (class, guid, bags, auras, ...)
--   WowStub.Remove(path)       the API is missing
--   WowStub.Fail(path)         the API raises
--   WowStub.Set(path, fn)      the API is `fn`
--   WowStub.Secret             a value issecretvalue() reports as secret

local WowStub = {}
WowStub.Secret = setmetatable({}, {
  __tostring = function()
    return "<secret>"
  end,
})

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
  }
end

local function frameFactory()
  local frame = { scripts = {}, events = {} }
  function frame:RegisterEvent(event)
    self.events[event] = true
  end
  function frame:UnregisterEvent(event)
    self.events[event] = nil
  end
  function frame:SetScript(name, handler)
    self.scripts[name] = handler
  end
  return frame
end

local function defaults()
  local state = WowStub.state
  return {
    ["C_AddOns.GetAddOnMetadata"] = function()
      return "@project-version@"
    end,
    ["CreateFrame"] = function(_, _, _, template)
      if template and state.missingTemplates[template] then
        error("Couldn't find inherited node " .. template)
      end
      return frameFactory()
    end,
    ["GetBuildInfo"] = function()
      return "11.0.0", "00000", "Jan 1 2026", 16001
    end,
    ["GetLocale"] = function()
      return "enUS"
    end,
    ["issecretvalue"] = function(value)
      return value == WowStub.Secret
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
      return { name = "Spell" .. spellId, iconID = 100000 + spellId }
    end,
    ["C_Spell.GetSpellCooldown"] = function()
      return { startTime = 10, duration = 20, isEnabled = true, modRate = 1 }
    end,
    ["C_Spell.GetSpellCooldownDuration"] = function(spellId)
      return { durationObject = spellId }
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
  _G.C_Secrets, _G.C_CooldownViewer = nil, nil
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
