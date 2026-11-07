local Loader = dofile("tests/support/loader.lua")

describe("ViewModelPoisons", function()
  local ns, VM, deps

  local function catalogOf(items)
    return ns.PoisonCatalog.Build(items)
  end

  before_each(function()
    WowStub.Reset()
    ns = Loader.Full({ "Core/Init.lua", "Commands/Slash.lua" })
    VM = ns.ViewModelPoisons
    deps = {
      L = ns.L,
      iconFor = function(itemID)
        return 5000 + itemID
      end,
    }
  end)

  describe("Flyout", function()
    it("is empty without poisons", function()
      assert.are.same({}, VM.Flyout(catalogOf({}), deps))
    end)

    it("lists the top rank of every family first, then the other ranks", function()
      local rows = VM.Flyout(
        catalogOf({
          { itemID = 6947, stackCount = 10 },
          { itemID = 8926, stackCount = 5 },
          { itemID = 2893, stackCount = 3 },
          { itemID = 2892, stackCount = 1 },
        }),
        deps
      )
      local order = {}
      for _, row in ipairs(rows) do
        order[#order + 1] = row.itemID
      end
      assert.are.same({ 8926, 2893, 6947, 2892 }, order)
      assert.is_true(rows[1].isTop)
      assert.is_true(rows[2].isTop)
      assert.is_false(rows[3].isTop)
      assert.are.equal("instant", rows[1].family)
      assert.are.equal("IV", rows[1].rankText)
      assert.are.equal(5, rows[1].count)
      assert.are.equal(13926, rows[1].icon)
      assert.are.equal("Instant Poison IV  (5)", rows[1].text)
    end)

    it("works without an icon source and with the default texts", function()
      local rows = VM.Flyout(catalogOf({ { itemID = 6947, stackCount = 2 } }))
      assert.is_nil(rows[1].icon)
      assert.are.equal("Instant Poison I  (2)", rows[1].text)
    end)
  end)

  describe("Status", function()
    it("shows minutes and charges", function()
      local status = VM.Status({
        mh = { has = true, weapon = true, minutes = 12.2, charges = 80 },
        oh = { has = true, weapon = true, minutes = 3 },
      }, deps)
      assert.are.equal("MH 13 min · 80", status.mh.text)
      assert.are.equal(13, status.mh.minutes)
      assert.are.equal("OH 3 min", status.oh.text)
      assert.is_true(status.mh.known)
    end)

    it("shows a dash without poison, without weapon and when unknown", function()
      local status = VM.Status({ mh = { has = false, weapon = true }, oh = { has = false, weapon = false } }, deps)
      assert.are.equal("MH —", status.mh.text)
      assert.are.equal("OH —", status.oh.text)
      assert.is_true(status.mh.known)
      local unknown = VM.Status(nil, deps)
      assert.are.equal("MH —", unknown.mh.text)
      assert.is_false(unknown.mh.known)
      local partial = VM.Status({ mh = { has = nil }, oh = { has = true } }, deps)
      assert.is_false(partial.mh.known)
      assert.are.equal("OH —", partial.oh.text)
    end)

    it("uses the Spanish labels", function()
      ns.Locale.Use("esES")
      assert.are.equal("MP —", VM.Status(nil).mh.text)
      assert.are.equal("MS —", VM.Status(nil).oh.text)
    end)
  end)

  describe("MainIcon", function()
    it("uses the icon of the main hand poison", function()
      assert.are.equal(11947, VM.MainIcon({ mh = { has = true, itemID = 6947 } }, deps))
    end)

    it("falls back to the logo", function()
      local logo = ns.Constants.LOGO_TEXTURE
      assert.are.equal(logo, VM.MainIcon(nil, deps))
      assert.are.equal(logo, VM.MainIcon({ mh = { has = false } }, deps))
      assert.are.equal(logo, VM.MainIcon({ mh = { has = true } }, deps))
      assert.are.equal(logo, VM.MainIcon({ mh = { has = true, itemID = 6947 } }, {}))
      assert.are.equal(logo, VM.MainIcon({ mh = { has = true, itemID = 6947 } }))
    end)
  end)

  describe("AlertText", function()
    it("describes every alert kind", function()
      assert.are.equal("The main hand has no poison.", VM.AlertText({ kind = "none", slot = "mh" }, deps))
      assert.are.equal(
        "The off hand poison expires in 4 min.",
        VM.AlertText({ kind = "expiring", slot = "oh", minutes = 4 }, deps)
      )
      assert.are.equal(
        "The main hand poison is low on charges: 7 left.",
        VM.AlertText({ kind = "charges", slot = "mh", charges = 7 }, deps)
      )
      assert.are.equal(
        "Low stock of Deadly Poison: 2 left.",
        VM.AlertText({ kind = "stock", family = "deadly", stock = 2 }, deps)
      )
      assert.are.equal(
        "Low stock of mystery: 2 left.",
        VM.AlertText({ kind = "stock", family = "mystery", stock = 2 }, deps)
      )
    end)

    it("speaks Spanish", function()
      ns.Locale.Use("esES")
      assert.are.equal("Falta el veneno en la mano principal.", VM.AlertText({ kind = "none", slot = "mh" }))
    end)
  end)

  it("names ranks past the Roman table with their number", function()
    assert.are.equal("12", VM.RankText(12))
    assert.are.equal("III", VM.RankText(3))
  end)
end)
