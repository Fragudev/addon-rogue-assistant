local Loader = require("tests.support.loader")

describe("Items", function()
  local Items

  before_each(function()
    WowStub.Reset()
    Items = Loader.Load({ "Core/Constants.lua", "Data/Items.lua" }).Items
  end)

  it("lists kinds in order: poisons, sharpening stones, weightstones, oils", function()
    local seen, order = {}, {}
    for _, entry in ipairs(Items.LIST) do
      if not seen[entry.kind] then
        seen[entry.kind] = true
        order[#order + 1] = entry.kind
      end
    end
    assert.same({ "poison", "sharpening", "weightstone", "oil" }, order)
  end)

  it("keeps the strongest rank first inside a family", function()
    local instant6, instant1
    for index, entry in ipairs(Items.LIST) do
      if entry.itemID == 8928 then
        instant6 = index
      elseif entry.itemID == 6947 then
        instant1 = index
      end
    end
    assert.is_true(instant6 < instant1)
  end)

  it("indexes every entry by item id without duplicates", function()
    local count = 0
    for itemID, entry in pairs(Items.BY_ID) do
      assert.equal(itemID, entry.itemID)
      count = count + 1
    end
    assert.equal(#Items.LIST, count)
  end)

  describe("Fits", function()
    local poison = { kind = "poison" }
    local sharpening = { kind = "sharpening" }
    local weightstone = { kind = "weightstone" }
    local oil = { kind = "oil" }
    local dagger = { classID = 2, subclassID = 15 }
    local mace = { classID = 2, subclassID = 4 }
    local fist = { classID = 2, subclassID = 13 }

    it("offers everything when the weapon is unknown", function()
      for _, entry in ipairs({ poison, sharpening, weightstone, oil }) do
        assert.is_true(Items.Fits(entry, nil))
      end
    end)

    it("offers nothing for an empty slot or an item that is not a weapon", function()
      assert.is_false(Items.Fits(poison, { empty = true }))
      assert.is_false(Items.Fits(poison, { classID = 4, subclassID = 6 }))
    end)

    it("puts sharpening stones on edged weapons and weightstones on blunt ones", function()
      assert.is_true(Items.Fits(sharpening, dagger))
      assert.is_false(Items.Fits(weightstone, dagger))
      assert.is_true(Items.Fits(weightstone, mace))
      assert.is_false(Items.Fits(sharpening, mace))
    end)

    it("offers both stones for a weapon type it does not classify (fist weapons)", function()
      assert.is_true(Items.Fits(sharpening, fist))
      assert.is_true(Items.Fits(weightstone, fist))
    end)

    it("offers poisons and oils on any weapon", function()
      assert.is_true(Items.Fits(poison, mace))
      assert.is_true(Items.Fits(oil, dagger))
    end)
  end)
end)
