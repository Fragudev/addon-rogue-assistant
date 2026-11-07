local Loader = dofile("tests/support/loader.lua")

describe("Poison data", function()
  local ns

  before_each(function()
    WowStub.Reset()
    ns = Loader.Full({ "Core/Init.lua", "Commands/Slash.lua" })
  end)

  it("lists the five rogue poison families in flyout order", function()
    local keys = {}
    for _, family in ipairs(ns.Poisons.FAMILIES) do
      keys[#keys + 1] = family.key
    end
    assert.are.same({ "instant", "deadly", "crippling", "mindnumbing", "wound" }, keys)
  end)

  it("has no duplicate item ids and no duplicate ranks in a family", function()
    local seen = {}
    for _, family in ipairs(ns.Poisons.FAMILIES) do
      local ranks = {}
      for _, entry in ipairs(family.ranks) do
        assert.is_nil(seen[entry.itemID], "duplicate item id " .. entry.itemID)
        seen[entry.itemID] = true
        assert.is_nil(ranks[entry.rank], "duplicate rank in " .. family.key)
        ranks[entry.rank] = true
      end
    end
  end)

  it("gives every entry an id, a rank, a level and a source", function()
    for _, family in ipairs(ns.Poisons.FAMILIES) do
      assert.is_true(#family.ranks > 0)
      assert.is_truthy(ns.L[family.nameKey] ~= family.nameKey, family.nameKey)
      local previous = 0
      for _, entry in ipairs(family.ranks) do
        assert.is_number(entry.itemID)
        assert.are.equal(previous + 1, entry.rank)
        previous = entry.rank
        assert.is_true(entry.level >= 1 and entry.level <= 60)
        assert.is_string(entry.source)
        assert.is_true(#entry.source > 0)
      end
    end
  end)

  it("looks a poison up by item id", function()
    assert.are.same({ "deadly", 2 }, { ns.Poisons.Lookup(2893) })
    assert.is_nil(ns.Poisons.Lookup(1))
  end)
end)
