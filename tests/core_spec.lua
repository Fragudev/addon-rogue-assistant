local Loader = require("tests.support.loader")

describe("Core", function()
  local ns

  before_each(function()
    WowStub.Reset()
    ns = Loader.Load({
      "Core/Constants.lua",
      "Core/Locale.lua",
      "Locales/enUS.lua",
      "Locales/esES.lua",
      "Core/Api.lua",
      "Core/Store.lua",
    })
  end)

  describe("Locale", function()
    it("uses esES for esMX and enUS for an unknown locale", function()
      assert.equal("esES", ns.Locale.Use("esMX"))
      assert.equal("MP", ns.L("slot.16"))
      assert.equal("enUS", ns.Locale.Use("frFR"))
      assert.equal("MH", ns.L("slot.16"))
    end)

    it("falls back to enUS, then to the key, and formats arguments", function()
      ns.Locale.Register("esES", { ["only.english"] = nil })
      ns.Locale.Register("enUS", { ["only.english"] = "english %d" })
      ns.Locale.Use("esES")
      assert.equal("english 3", ns.L("only.english", 3))
      assert.equal("no.such.key", ns.L("no.such.key"))
    end)

    it("has the same keys in every locale", function()
      local fresh = Loader.Load({ "Core/Constants.lua", "Core/Locale.lua" })
      local registered = {}
      local register = fresh.Locale.Register
      fresh.Locale.Register = function(code, strings)
        registered[code] = strings
        register(code, strings)
      end
      Loader.Load({ "Locales/enUS.lua", "Locales/esES.lua" }, fresh)
      for key in pairs(registered.enUS) do
        assert.is_string(registered.esES[key], key)
      end
      for key in pairs(registered.esES) do
        assert.is_string(registered.enUS[key], key)
      end
    end)
  end)

  describe("Store", function()
    it("starts fresh from nothing or from another version", function()
      local fresh = ns.Store.Load(nil)
      assert.same({ version = 2, warnMinutes = 5, enchants = {}, minimapAngle = 225, minimapHidden = false }, fresh)
      assert.same(fresh, ns.Store.Load({ profile = { poison = {} } }))
    end)

    it("repairs bad fields and keeps good ones", function()
      local saved = ns.Store.Load({
        version = 2,
        warnMinutes = 999,
        position = { point = "TOP" },
        enchants = { [625] = 8928 },
        minimapAngle = "north",
        minimapHidden = "yes",
      })
      assert.same({
        version = 2,
        warnMinutes = 5,
        enchants = { [625] = 8928 },
        minimapAngle = 225,
        minimapHidden = false,
      }, saved)
      local position = { point = "TOP", relativePoint = "TOP", x = 1, y = -2 }
      assert.same(
        position,
        ns.Store.Load({ version = 2, warnMinutes = 0, position = position, enchants = {} }).position
      )
    end)
  end)

  describe("Api", function()
    local Api

    before_each(function()
      Api = ns.Api
    end)

    it("reads both weapon enchants", function()
      WowStub.state.weapon = { true, 60000, 12, 625, false, 0, 0, 0 }
      assert.same({
        [16] = { active = true, ms = 60000, charges = 12, enchantID = 625 },
        [17] = { active = false, ms = 0, charges = 0 },
      }, Api.GetWeaponEnchants())
    end)

    it("marks a hidden enchant unknown and drops hidden fields", function()
      WowStub.state.weapon = { WowStub.Secret, 1, 2, 3, true, WowStub.Secret, WowStub.Secret, WowStub.Secret }
      assert.same({ [16] = { unknown = true }, [17] = { active = true } }, Api.GetWeaponEnchants())
    end)

    it("gives nil when the enchant API is missing or raises", function()
      _G.GetWeaponEnchantInfo = nil
      assert.is_nil(Api.GetWeaponEnchants())
      _G.GetWeaponEnchantInfo = function()
        error("boom")
      end
      assert.is_nil(Api.GetWeaponEnchants())
    end)

    it("assumes combat when the lockdown state cannot be read", function()
      assert.is_false(Api.InCombat())
      WowStub.state.inCombat = true
      assert.is_true(Api.InCombat())
      WowStub.state.inCombat = WowStub.Secret
      assert.is_true(Api.InCombat())
      _G.InCombatLockdown = nil
      assert.is_true(Api.InCombat())
    end)

    it("tells an empty slot from an unknown one", function()
      WowStub.state.equipment[17] = nil
      assert.is_false(Api.GetEquippedItemID(17))
      assert.equal(1001, Api.GetEquippedItemID(16))
      _G.GetInventoryItemID = nil
      assert.is_nil(Api.GetEquippedItemID(16))
    end)

    it("walks every bag and skips hidden or empty slots", function()
      WowStub.state.bags[0] = { { itemID = 8928, stackCount = 5 }, false, { itemID = WowStub.Secret } }
      WowStub.state.bags[5] = { { itemID = 2871 } }
      local seen = {}
      Api.ForEachBagItem(function(itemID, count)
        seen[#seen + 1] = { itemID, count }
      end)
      assert.same({ { 8928, 5 }, { 2871, 1 } }, seen)
    end)

    it("does nothing without the container API", function()
      _G.C_Container = nil
      local calls = 0
      Api.ForEachBagItem(function()
        calls = calls + 1
      end)
      assert.equal(0, calls)
    end)

    it("reads item data and guards missing APIs", function()
      WowStub.state.names[8928] = "Instant Poison VI"
      assert.equal("Instant Poison VI", Api.GetItemName(8928))
      assert.equal("icon-8928", Api.GetItemIcon(8928))
      assert.same({ classID = 2, subclassID = 15, icon = "item-icon-1001" }, Api.GetItemInstant(1001))
      assert.is_nil(Api.GetItemInstant(4242))
      _G.C_Item = nil
      assert.is_nil(Api.GetItemName(8928))
      assert.is_nil(Api.GetItemIcon(8928))
    end)

    it("falls back for time and locale", function()
      assert.equal(1000, Api.Now())
      assert.equal("enUS", Api.GetLocale())
      _G.GetTime = nil
      _G.GetLocale = nil
      assert.equal(0, Api.Now())
      assert.equal("enUS", Api.GetLocale())
    end)

    it("prints to the chat frame", function()
      Api.Print("hello")
      assert.equal("|cffffd100Rogue Assistant|r: hello", WowStub.Messages()[1])
    end)
  end)
end)
