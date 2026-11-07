local Loader = dofile("tests/support/loader.lua")

describe("Platform", function()
  local ns, P

  before_each(function()
    WowStub.Reset()
    ns = Loader.Load({ "Core/Constants.lua", "Core/Platform.lua" })
    P = ns.Platform
  end)

  describe("core helpers", function()
    it("tells missing from present", function()
      assert.is_true(P.Has("UnitGUID"))
      assert.is_false(P.Has("Nope.Nothing"))
      assert.is_false(P.Has("C_Spell"))
      assert.is_true(P.HasGlobal("C_Spell"))
      assert.is_false(P.HasGlobal("C_Nope"))
    end)

    it("invokes once and reports missing, error and ok", function()
      local calls = 0
      WowStub.Set("StubOnce", function()
        calls = calls + 1
        return 1, nil, 3
      end)
      local status, packed = P.Invoke("StubOnce")
      assert.are.equal("ok", status)
      assert.are.equal(3, packed.n)
      assert.are.equal(1, calls)
      assert.are.equal("missing", (P.Invoke("Nope")))
      WowStub.Fail("StubOnce")
      local failed, message = P.Invoke("StubOnce")
      assert.are.equal("error", failed)
      assert.is_truthy(message:find("stub failure", 1, true))
    end)

    it("replaces secret results", function()
      WowStub.Set("StubSecret", function()
        return WowStub.Secret
      end)
      local _, packed = P.Invoke("StubSecret")
      assert.are.equal(P.SECRET, packed[1])
      assert.are.equal("<secret>", tostring(P.SECRET))
    end)

    it("detects secrets without issecretvalue by their failing comparison", function()
      WowStub.Remove("issecretvalue")
      assert.is_false(P.IsSecret(5))
      assert.is_false(P.IsSecret("text"))
      assert.is_false(P.IsSecret({}))
      local secretNumber = setmetatable({}, {
        __le = function()
          error("secret")
        end,
        __lt = function()
          error("secret")
        end,
      })
      assert.is_false(P.IsSecret(secretNumber))
    end)

    it("survives an issecretvalue that raises", function()
      WowStub.Fail("issecretvalue")
      assert.is_false(P.IsSecret(1))
    end)

    it("forbids the combat log event", function()
      local frame = CreateFrame("Frame")
      assert.is_false(P.TryRegisterEvent(frame, "COMBAT_LOG_EVENT_UNFILTERED"))
      assert.is_nil(frame.events.COMBAT_LOG_EVENT_UNFILTERED)
      assert.is_true(P.TryRegisterEvent(frame, "PLAYER_LOGIN"))
      frame.RegisterEvent = function()
        error("unknown event")
      end
      assert.is_false(P.TryRegisterEvent(frame, "BOGUS"))
    end)

    it("tells if a text probe is a secret string", function()
      WowStub.Remove("issecretvalue")
      assert.is_false(P.IsSecret("abc"))
    end)
  end)

  describe("player", function()
    it("gives the class token and GUID", function()
      assert.are.equal("ROGUE", P.GetPlayerClassToken())
      assert.are.equal("Player-1-0000ABCD", P.GetPlayerGUID())
    end)

    it("gives nil when missing, failing or secret", function()
      WowStub.Remove("UnitGUID")
      assert.is_nil(P.GetPlayerGUID())
      WowStub.Fail("UnitClass")
      assert.is_nil(P.GetPlayerClassToken())
      WowStub.Set("UnitClass", function()
        return WowStub.Secret, WowStub.Secret, 4
      end)
      assert.is_nil(P.GetPlayerClassToken())
    end)

    it("reads IsPlayerSpell as a boolean or nil", function()
      WowStub.state.knownSpells = { [1328825] = true }
      assert.is_true(P.IsPlayerSpell(1328825))
      assert.is_false(P.IsPlayerSpell(1))
      WowStub.Remove("IsPlayerSpell")
      assert.is_nil(P.IsPlayerSpell(1328825))
      WowStub.Set("IsPlayerSpell", function()
        return 1
      end)
      assert.is_nil(P.IsPlayerSpell(1))
    end)
  end)

  describe("spells", function()
    it("gives name and icon from C_Spell", function()
      local name, icon = P.GetSpellInfo(5)
      assert.are.equal("Spell5", name)
      assert.are.equal(100005, icon)
    end)

    it("falls back to the legacy GetSpellInfo", function()
      WowStub.Remove("C_Spell.GetSpellInfo")
      WowStub.Set("GetSpellInfo", function()
        return "Old", "x", 77
      end)
      local name, icon = P.GetSpellInfo(5)
      assert.are.equal("Old", name)
      assert.are.equal(77, icon)
    end)

    it("hides a secret icon and gives nil when nothing answers", function()
      WowStub.Set("C_Spell.GetSpellInfo", function()
        return { name = "Named", iconID = WowStub.Secret }
      end)
      local name, icon = P.GetSpellInfo(5)
      assert.are.equal("Named", name)
      assert.is_nil(icon)
      WowStub.Remove("C_Spell.GetSpellInfo")
      assert.is_nil(P.GetSpellInfo(5))
    end)

    it("gives the cooldown triple", function()
      local start, duration, enabled = P.GetSpellCooldown(5)
      assert.are.equal(10, start)
      assert.are.equal(20, duration)
      assert.is_true(enabled)
    end)

    it("converts a numeric isEnabled and leaves a missing one nil", function()
      WowStub.Set("C_Spell.GetSpellCooldown", function()
        return { startTime = 1, duration = 2, isEnabled = 0 }
      end)
      assert.is_false(select(3, P.GetSpellCooldown(1)))
      WowStub.Set("C_Spell.GetSpellCooldown", function()
        return { startTime = 1, duration = 2 }
      end)
      assert.is_nil(select(3, P.GetSpellCooldown(1)))
    end)

    it("falls back to the legacy GetSpellCooldown", function()
      WowStub.Remove("C_Spell.GetSpellCooldown")
      WowStub.Set("GetSpellCooldown", function()
        return 3, 4, 1
      end)
      local start, duration, enabled = P.GetSpellCooldown(1)
      assert.are.equal(3, start)
      assert.are.equal(4, duration)
      assert.is_true(enabled)
      WowStub.Set("GetSpellCooldown", function()
        return 3, 4, 0
      end)
      assert.is_false(select(3, P.GetSpellCooldown(1)))
    end)

    it("gives nil cooldown fields when secret, missing or failing", function()
      WowStub.Set("C_Spell.GetSpellCooldown", function()
        return { startTime = WowStub.Secret, duration = WowStub.Secret, isEnabled = WowStub.Secret }
      end)
      local start, duration, enabled = P.GetSpellCooldown(1)
      assert.is_nil(start)
      assert.is_nil(duration)
      assert.is_nil(enabled)
      WowStub.Remove("C_Spell.GetSpellCooldown")
      assert.is_nil(P.GetSpellCooldown(1))
    end)

    it("returns the cooldown duration object untouched", function()
      local object = P.GetSpellCooldownDurationObject(9)
      assert.are.equal(9, object.durationObject)
      WowStub.Set("C_Spell.GetSpellCooldownDuration", function()
        return WowStub.Secret
      end)
      assert.are.equal(WowStub.Secret, P.GetSpellCooldownDurationObject(9))
    end)

    it("gives nil for the duration object when missing or failing", function()
      WowStub.Fail("C_Spell.GetSpellCooldownDuration")
      assert.is_nil(P.GetSpellCooldownDurationObject(9))
      WowStub.Remove("C_Spell.GetSpellCooldownDuration")
      assert.is_nil(P.GetSpellCooldownDurationObject(9))
    end)
  end)

  describe("tracker wrappers", function()
    it("reads the charges of a spell and drops secret current charges", function()
      WowStub.state.charges[5] = { currentCharges = 2, maxCharges = 3 }
      local current, maximum = P.GetSpellCharges(5)
      assert.are.equal(2, current)
      assert.are.equal(3, maximum)
      WowStub.state.charges[5] = { currentCharges = WowStub.Secret, maxCharges = 3 }
      current, maximum = P.GetSpellCharges(5)
      assert.is_nil(current)
      assert.are.equal(3, maximum)
    end)

    it("gives nil charges for a spell without charges, a missing API or a failing one", function()
      assert.is_nil(P.GetSpellCharges(5))
      WowStub.state.charges[5] = { currentCharges = 1 }
      assert.is_nil(P.GetSpellCharges(5))
      WowStub.Fail("C_Spell.GetSpellCharges")
      assert.is_nil(P.GetSpellCharges(5))
      WowStub.Remove("C_Spell.GetSpellCharges")
      assert.is_nil(P.GetSpellCharges(5))
    end)

    it("returns the aura duration object and display count untouched", function()
      local object = WowStub.DurationObject("aura")
      WowStub.state.auraDurations[7] = object
      WowStub.state.auraCounts[7] = WowStub.Secret
      assert.are.equal(object, P.GetAuraDurationObject("target", 7))
      assert.are.equal(WowStub.Secret, P.GetAuraApplicationDisplayCount("target", 7, 2))
    end)

    it("gives nil for the aura objects when the APIs are missing or failing", function()
      WowStub.Fail("C_UnitAuras.GetAuraDuration")
      WowStub.Fail("C_UnitAuras.GetAuraApplicationDisplayCount")
      assert.is_nil(P.GetAuraDurationObject("target", 7))
      assert.is_nil(P.GetAuraApplicationDisplayCount("target", 7))
      WowStub.Remove("C_UnitAuras.GetAuraDuration")
      WowStub.Remove("C_UnitAuras.GetAuraApplicationDisplayCount")
      assert.is_nil(P.GetAuraDurationObject("target", 7))
      assert.is_nil(P.GetAuraApplicationDisplayCount("target", 7))
    end)

    it("hands a duration object to a cooldown widget and reports refusal", function()
      local widget = CreateFrame("Cooldown", nil, UIParent, "CooldownFrameTemplate")
      local object = WowStub.Secret
      assert.is_true(P.SetCooldownFromDurationObject(widget, object))
      assert.are.equal(object, widget.durationObject)
      WowStub.state.cooldownObjectFails = true
      assert.is_false(P.SetCooldownFromDurationObject(widget, object))
      assert.is_false(P.SetCooldownFromDurationObject({}, object))
      assert.is_false(P.SetCooldownFromDurationObject(nil, object))
    end)

    it("sets text that may be secret through pcall", function()
      local text = CreateFrame("Frame"):CreateFontString()
      assert.is_true(P.SetText(text, WowStub.Secret))
      assert.are.equal(WowStub.Secret, text:GetText())
      assert.is_false(P.SetText({
        SetText = function()
          error("no")
        end,
      }, "x"))
    end)
  end)

  describe("auras", function()
    local aura = {
      name = "Stealth",
      spellId = 1784,
      icon = 132320,
      applications = 2,
      duration = 10,
      expirationTime = 1010,
      auraInstanceID = 7,
    }

    it("reads a player aura by spell id", function()
      WowStub.state.auras.player = { aura }
      local found = P.GetPlayerAura(1784)
      assert.are.equal("Stealth", found.name)
      assert.are.equal(2, found.applications)
      assert.are.equal(7, found.auraInstanceID)
      assert.is_nil(P.GetPlayerAura(1))
    end)

    it("hides secret aura fields but keeps the rest", function()
      WowStub.state.auras.player = {
        { name = WowStub.Secret, spellId = WowStub.Secret, icon = "path", applications = 1, auraInstanceID = 9 },
      }
      local found = P.GetAuraByIndex("player", 1, "HELPFUL")
      assert.is_nil(found.name)
      assert.is_nil(found.spellId)
      assert.are.equal("path", found.icon)
      assert.are.equal(9, found.auraInstanceID)
    end)

    it("iterates until the first empty index", function()
      WowStub.state.auras.target = { aura, aura }
      assert.are.equal(2, #P.GetAuras("target", "HARMFUL|PLAYER"))
      assert.are.equal(0, #P.GetAuras("player", "HELPFUL"))
    end)

    it("is bounded by MAX_AURAS", function()
      WowStub.Set("C_UnitAuras.GetAuraDataByIndex", function()
        return aura
      end)
      assert.are.equal(ns.Constants.MAX_AURAS, #P.GetAuras("player", "HELPFUL"))
    end)

    it("gives nil or empty when the API is missing or failing", function()
      WowStub.Remove("C_UnitAuras.GetPlayerAuraBySpellID")
      assert.is_nil(P.GetPlayerAura(1))
      WowStub.Fail("C_UnitAuras.GetAuraDataByIndex")
      assert.is_nil(P.GetAuraByIndex("player", 1, "HELPFUL"))
      assert.are.same({}, P.GetAuras("player", "HELPFUL"))
    end)
  end)

  describe("weapon enchants", function()
    it("reads the eight values", function()
      WowStub.state.weapon = { true, 600000, 80, 7, false, 0, 0, 0 }
      local info = P.GetWeaponEnchantInfo()
      assert.is_true(info.hasMH)
      assert.are.equal(600000, info.mhMs)
      assert.are.equal(80, info.mhCharges)
      assert.are.equal(7, info.mhEnchantId)
      assert.is_false(info.hasOH)
    end)

    it("gives nil when missing, failing or entirely secret", function()
      WowStub.Set("GetWeaponEnchantInfo", function()
        return WowStub.Secret, WowStub.Secret, WowStub.Secret, WowStub.Secret, WowStub.Secret
      end)
      assert.is_nil(P.GetWeaponEnchantInfo())
      WowStub.Fail("GetWeaponEnchantInfo")
      assert.is_nil(P.GetWeaponEnchantInfo())
      WowStub.Remove("GetWeaponEnchantInfo")
      assert.is_nil(P.GetWeaponEnchantInfo())
    end)
  end)

  describe("equipped items", function()
    it("gives the item id, false for an empty slot and nil when unavailable", function()
      assert.are.equal(1001, P.GetInventoryItemID("player", 16))
      WowStub.state.equipment[17] = nil
      assert.is_false(P.GetInventoryItemID("player", 17))
      WowStub.Fail("GetInventoryItemID")
      assert.is_nil(P.GetInventoryItemID("player", 16))
      WowStub.Remove("GetInventoryItemID")
      assert.is_nil(P.GetInventoryItemID("player", 16))
      WowStub.Set("GetInventoryItemID", function()
        return WowStub.Secret
      end)
      assert.is_nil(P.GetInventoryItemID("player", 16))
    end)

    it("reads the Shift key as a boolean or nil", function()
      assert.is_false(P.IsShiftKeyDown())
      WowStub.state.shift = true
      assert.is_true(P.IsShiftKeyDown())
      WowStub.Remove("IsShiftKeyDown")
      assert.is_nil(P.IsShiftKeyDown())
    end)
  end)

  describe("bags and items", function()
    local function bag(size, items)
      items.size = size
      return items
    end

    it("iterates occupied slots of bags 0..4", function()
      WowStub.state.bags = {
        [0] = bag(3, { [2] = { itemID = 11, stackCount = 4, iconFileID = 5, hyperlink = "|h[Poison]|h" } }),
        [4] = bag(1, { [1] = { itemID = 12 } }),
        [5] = bag(1, { [1] = { itemID = 99 } }),
      }
      local items = P.GetBagItems()
      assert.are.equal(2, #items)
      assert.are.equal(0, items[1].bag)
      assert.are.equal(2, items[1].slot)
      assert.are.equal(4, items[1].stackCount)
      assert.are.equal("|h[Poison]|h", items[1].link)
      assert.are.equal(1, items[2].stackCount)
    end)

    it("skips slots without a readable item id", function()
      WowStub.state.bags = { [0] = bag(2, { [1] = { itemID = WowStub.Secret }, [2] = { stackCount = 3 } }) }
      assert.are.same({}, P.GetBagItems())
    end)

    it("gives nothing when the container API is missing or failing", function()
      WowStub.Remove("C_Container.GetContainerNumSlots")
      assert.is_nil(P.GetContainerNumSlots(0))
      assert.are.same({}, P.GetBagItems())
      WowStub.Fail("C_Container.GetContainerItemInfo")
      assert.is_nil(P.GetContainerItem(0, 1))
    end)

    it("counts items", function()
      assert.are.equal(3, P.GetItemCount(5))
      WowStub.Remove("C_Item.GetItemCount")
      assert.is_nil(P.GetItemCount(5))
    end)

    it("gives item name and icon", function()
      local name, icon = P.GetItemInfo(7)
      assert.are.equal("Item7", name)
      assert.are.equal(200007, icon)
    end)

    it("falls back to GetItemInfo", function()
      WowStub.Remove("C_Item.GetItemNameByID")
      WowStub.Remove("C_Item.GetItemIconByID")
      WowStub.Set("GetItemInfo", function()
        return "Old", "link", 1, 1, 1, "type", "sub", 1, "loc", 555
      end)
      local name, icon = P.GetItemInfo(7)
      assert.are.equal("Old", name)
      assert.are.equal(555, icon)
      WowStub.Remove("GetItemInfo")
      assert.is_nil(P.GetItemInfo(7))
    end)
  end)

  describe("spellbook", function()
    it("lists entries across skill lines", function()
      WowStub.state.spellbook = {
        { itemIndexOffset = 0, numSpellBookItems = 2 },
        { itemIndexOffset = 2, numSpellBookItems = 1 },
      }
      WowStub.state.spellItems = {
        { spellID = 1, name = "One" },
        { spellID = 2 },
        { spellID = WowStub.Secret },
      }
      local entries = P.GetSpellBookEntries()
      assert.are.equal(2, #entries)
      assert.are.equal("One", entries[1].name)
      assert.is_nil(entries[2].name)
    end)

    it("uses Enum.SpellBookSpellBank.Player when present", function()
      local bankSeen
      _G.Enum = { SpellBookSpellBank = { Player = 0 } }
      WowStub.state.spellbook = { { itemIndexOffset = 0, numSpellBookItems = 1 } }
      WowStub.Set("C_SpellBook.GetSpellBookItemInfo", function(_, bank)
        bankSeen = bank
        return { spellID = 3, name = "Three" }
      end)
      assert.are.equal(1, #P.GetSpellBookEntries())
      assert.are.equal(0, bankSeen)
      _G.Enum = nil
    end)

    it("is empty when the API is missing or the skill line is unreadable", function()
      WowStub.state.spellbook = { { itemIndexOffset = WowStub.Secret, numSpellBookItems = 1 } }
      assert.are.same({}, P.GetSpellBookEntries())
      WowStub.Remove("C_SpellBook.GetNumSpellBookSkillLines")
      assert.are.same({}, P.GetSpellBookEntries())
    end)
  end)

  describe("client state", function()
    it("reads combat, instance and time", function()
      WowStub.state.inCombat = true
      WowStub.state.instance = { true, "party" }
      assert.is_true(P.InCombatLockdown())
      local inInstance, kind = P.IsInInstance()
      assert.is_true(inInstance)
      assert.are.equal("party", kind)
      assert.are.equal(1000, P.GetTime())
    end)

    it("gives nil when missing or failing", function()
      WowStub.Remove("InCombatLockdown")
      WowStub.Fail("IsInInstance")
      WowStub.Set("GetTime", function()
        return WowStub.Secret
      end)
      assert.is_nil(P.InCombatLockdown())
      assert.is_nil(P.IsInInstance())
      assert.is_nil(P.GetTime())
    end)

    it("probes secure templates", function()
      assert.is_true(P.CanCreateSecureTemplate("SecureActionButtonTemplate"))
      WowStub.state.missingTemplates.SecureHandlerClickTemplate = true
      assert.is_false(P.CanCreateSecureTemplate("SecureHandlerClickTemplate"))
      WowStub.Remove("CreateFrame")
      assert.is_false(P.CanCreateSecureTemplate("SecureActionButtonTemplate"))
    end)
  end)
end)
