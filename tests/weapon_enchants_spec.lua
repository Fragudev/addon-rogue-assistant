local Loader = require("tests.support.loader")

describe("WeaponEnchants", function()
  local WeaponEnchants, units, options

  before_each(function()
    WowStub.Reset()
    WeaponEnchants = Loader.Load({ "Core/Constants.lua", "Data/Items.lua", "Domain/WeaponEnchants.lua" }).WeaponEnchants
    units = WeaponEnchants.Units({ "%s (%d |4hour:hours;)", "%s (%d min)", "%s (%d sec)" })
    options = { enchants = {}, poisonNames = { ["Instant Poison VI"] = 8928 } }
  end)

  describe("Units", function()
    it("reads the time words of the client strings, grammar alternatives included", function()
      assert.same({ hour = 3600, hours = 3600, min = 60, sec = 1 }, units)
    end)

    it("falls back to English words when the client strings are missing or odd", function()
      assert.same(
        { hour = 3600, hours = 3600, hr = 3600, hrs = 3600, min = 60, sec = 1 },
        WeaponEnchants.Units({ nil, "unexpected", 42 })
      )
    end)
  end)

  describe("ParseTooltip", function()
    it("keeps the lines with a time left and drops the rest", function()
      local lines = {
        "Bloodfang Dagger",
        "Instant Poison VI (30 min)",
        "Sharpened (+8 Damage) (1 hour)",
        "Durability 65 / 65",
        "Weird (3 fortnights)",
        "Almost gone (45 sec)",
      }
      assert.same({
        { name = "Instant Poison VI", seconds = 1800, step = 60 },
        { name = "Sharpened (+8 Damage)", seconds = 3600, step = 3600 },
        { name = "Almost gone", seconds = 45, step = 1 },
      }, WeaponEnchants.ParseTooltip(lines, units))
    end)

    it("reads the measured Forever lines, charges included", function()
      local lines = {
        "Rock on Stick",
        "One-Hand | Mace",
        "Chance on hit: Bash the target in the face, causing 7 Physical damage every 2 sec for 20 sec.",
        "Weighted +6 (30 min)",
        "Instant Poison (28 min) (60 Charges)",
        "Durability 81 / 90",
      }
      assert.same({
        { name = "Weighted +6", seconds = 1800, step = 60 },
        { name = "Instant Poison", seconds = 1680, step = 60, charges = 60 },
      }, WeaponEnchants.ParseTooltip(lines, units))
    end)

    it("gives nothing without lines", function()
      assert.same({}, WeaponEnchants.ParseTooltip(nil, units))
    end)
  end)

  describe("Rows", function()
    local poison = { active = true, ms = 1790000, charges = 40, enchantID = 625 }

    it("gives nothing without data", function()
      assert.same({}, WeaponEnchants.Rows(nil, {}, options))
      assert.same({}, WeaponEnchants.Rows({ active = false }, {}, options))
    end)

    it("takes the API enchant as a poison when it has charges", function()
      assert.same({ { kind = "poison", seconds = 1790, charges = 40 } }, WeaponEnchants.Rows(poison, {}, options))
    end)

    it("takes the API enchant as a stone without charges", function()
      local stone = { active = true, ms = 600000, charges = 0, enchantID = 1643 }
      assert.same({ { kind = "stone", seconds = 600 } }, WeaponEnchants.Rows(stone, {}, options))
    end)

    it("trusts the item the addon learned for that enchant", function()
      options.enchants[1643] = 2871 -- Heavy Sharpening Stone
      options.enchants[625] = 8928 -- Instant Poison VI
      local stone = { active = true, ms = 600000, charges = 5, enchantID = 1643 }
      assert.same({ { kind = "stone", seconds = 600 } }, WeaponEnchants.Rows(stone, {}, options))
      local learnedPoison = { active = true, ms = 600000, charges = 5, enchantID = 625 }
      assert.same({ { kind = "poison", seconds = 600, charges = 5 } }, WeaponEnchants.Rows(learnedPoison, {}, options))
    end)

    it("drops a learned poison whose charges ran out, keeping the stone of the tooltip", function()
      options.enchants[625] = 8928 -- Instant Poison VI
      local spent = { active = true, ms = 600000, charges = 0, enchantID = 625 }
      local tooltip = { { name = "Weighted +6", seconds = 1800 }, { name = "Instant Poison VI", seconds = 600 } }
      assert.same({}, WeaponEnchants.Rows(spent, {}, options))
      assert.same({ { kind = "stone", seconds = 1800 } }, WeaponEnchants.Rows(spent, tooltip, options))
    end)

    it("drops a poison the tooltip lists when the API reports no charges left", function()
      local spent = { active = true, ms = 600000, charges = 0, enchantID = 625 }
      local tooltip = { { name = "Instant Poison VI", seconds = 600 }, { name = "Weighted +6", seconds = 1800 } }
      assert.same({ { kind = "stone", seconds = 1800 } }, WeaponEnchants.Rows(spent, tooltip, options))
    end)

    it("drops a tooltip poison line that shows 0 charges", function()
      local tooltip =
        { { name = "Instant Poison VI", seconds = 600, charges = 0 }, { name = "Weighted +6", seconds = 1800 } }
      assert.same({ { kind = "stone", seconds = 1800 } }, WeaponEnchants.Rows(nil, tooltip, options))
    end)

    it("adds the stone of the tooltip to the poison the API reports (measured on Forever)", function()
      local measured = { active = true, ms = 1669925, charges = 60, enchantID = 323 }
      local tooltip = {
        { name = "Weighted +6", seconds = 1800 },
        { name = "Instant Poison", seconds = 1680, charges = 60 },
      }
      assert.same({
        { kind = "poison", seconds = 1669, charges = 60 },
        { kind = "stone", seconds = 1800 },
      }, WeaponEnchants.Rows(measured, tooltip, options))
    end)

    it("keeps a stone line whose time is close to the poison's", function()
      local tooltip = { { name = "Weighted +6", seconds = 1800 } }
      assert.same({
        { kind = "poison", seconds = 1790, charges = 40 },
        { kind = "stone", seconds = 1800 },
      }, WeaponEnchants.Rows(poison, tooltip, options))
    end)

    it("does not repeat the poison the API reports when the tooltip lists it too", function()
      local tooltip = { { name = "Instant Poison VI", seconds = 1800 } }
      assert.same({ { kind = "poison", seconds = 1790, charges = 40 } }, WeaponEnchants.Rows(poison, tooltip, options))
    end)

    it("knows a poison line by its charges even when its name is unknown", function()
      options.poisonNames = {}
      local tooltip = { { name = "Mystery", seconds = 600, charges = 12 }, { name = "Sharpened +8", seconds = 900 } }
      assert.same({
        { kind = "poison", seconds = 600, charges = 12 },
        { kind = "stone", seconds = 900 },
      }, WeaponEnchants.Rows(nil, tooltip, options))
    end)

    it("reads the tooltip alone when the API gives nothing", function()
      local tooltip =
        { { name = "Instant Poison VI", seconds = 1800 }, { name = "Weighted (+8 Damage)", seconds = 600 } }
      assert.same({
        { kind = "poison", seconds = 1800 },
        { kind = "stone", seconds = 600 },
      }, WeaponEnchants.Rows({ unknown = true }, tooltip, options))
      assert.same(
        { { kind = "stone", seconds = 600 } },
        WeaponEnchants.Rows(nil, { { name = "Weighted (+8 Damage)", seconds = 600 } }, options)
      )
    end)

    describe("Crippling Poison, which has no charges", function()
      -- The API reports 0 charges for it from the moment it is applied.
      local crippling = { active = true, ms = 1790000, charges = 0, enchantID = 22 }

      it("keeps a learned Crippling Poison with 0 charges as an active poison", function()
        options.enchants[22] = 3775 -- Crippling Poison
        assert.same({ { kind = "poison", seconds = 1790 } }, WeaponEnchants.Rows(crippling, {}, options))
      end)

      it("keeps Crippling Poison II the same way", function()
        options.enchants[22] = 3776 -- Crippling Poison II
        assert.same({ { kind = "poison", seconds = 1790 } }, WeaponEnchants.Rows(crippling, {}, options))
      end)

      it("knows an unlearned Crippling Poison by its tooltip name, next to a stone", function()
        options.poisonNames["Crippling Poison"] = 3775
        local tooltip = { { name = "Crippling Poison", seconds = 1800 }, { name = "Weighted +6", seconds = 1800 } }
        assert.same({
          { kind = "poison", seconds = 1790 },
          { kind = "stone", seconds = 1800 },
        }, WeaponEnchants.Rows(crippling, tooltip, options))
      end)

      it("still drops a charged poison whose charges ran out", function()
        options.enchants[22] = 8928 -- Instant Poison VI
        assert.same({}, WeaponEnchants.Rows(crippling, {}, options))
      end)
    end)
  end)
end)
