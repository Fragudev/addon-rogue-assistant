local Loader = dofile("tests/support/loader.lua")

describe("PoisonCatalog", function()
  local ns, Catalog

  before_each(function()
    WowStub.Reset()
    ns = Loader.Full({ "Core/Init.lua", "Commands/Slash.lua" })
    Catalog = ns.PoisonCatalog
  end)

  it("is empty without items", function()
    local catalog = Catalog.Build({})
    assert.are.same({}, catalog.families)
    assert.are.equal(0, catalog.total)
    assert.are.equal(0, Catalog.Stock(catalog, "instant"))
    assert.are.equal(0, #Catalog.Build(nil).families)
  end)

  it("groups poisons by family, highest rank first, with totals", function()
    local catalog = Catalog.Build({
      { itemID = 6947, stackCount = 10 }, -- Instant I
      { itemID = 8926, stackCount = 5 }, -- Instant IV
      { itemID = 6947, stackCount = 4 }, -- a second stack of Instant I
      { itemID = 2893, stackCount = 20 }, -- Deadly II
      { itemID = 4540, stackCount = 99 }, -- not a poison
      { itemID = 3775 }, -- Crippling I without a stack count
    })
    assert.are.equal(3, #catalog.families)
    local instant = catalog.families[1]
    assert.are.equal("instant", instant.key)
    assert.are.equal(19, instant.total)
    assert.are.same({ 4, 1 }, { instant.ranks[1].rank, instant.ranks[2].rank })
    assert.are.same({ 8926, 6947 }, { instant.ranks[1].itemID, instant.ranks[2].itemID })
    assert.are.equal(14, instant.ranks[2].count)
    assert.are.equal("deadly", catalog.families[2].key)
    assert.are.equal("crippling", catalog.families[3].key)
    assert.are.equal(1, catalog.families[3].total)
    assert.are.equal(40, catalog.total)
    assert.are.equal(19, Catalog.Stock(catalog, "instant"))
    assert.are.equal(20, catalog.byItem[2893].count)
    assert.is_nil(catalog.byItem[4540])
  end)

  it("ignores empty stacks", function()
    local catalog = Catalog.Build({ { itemID = 6947, stackCount = 0 } })
    assert.are.equal(0, #catalog.families)
  end)

  it("works with another family list", function()
    local catalog = Catalog.Build({ { itemID = 7, stackCount = 2 } }, {
      { key = "x", nameKey = "x", ranks = { { itemID = 7, rank = 1, level = 1 } } },
    })
    assert.are.equal("x", catalog.families[1].key)
  end)
end)
