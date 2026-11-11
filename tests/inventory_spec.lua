local Loader = require("tests.support.loader")

describe("Inventory", function()
  local ns, Inventory

  before_each(function()
    WowStub.Reset()
    ns = Loader.Load({ "Core/Constants.lua", "Core/Api.lua", "Data/Items.lua", "Domain/Inventory.lua" })
    Inventory = ns.Inventory
  end)

  it("adds up the stacks of catalog items across bags and ignores other items", function()
    WowStub.SetBag({ { 8928, 10 }, { 6948, 1 }, { 8928, 5 } })
    WowStub.state.bags[1] = { { itemID = 2871, stackCount = 3 } }
    assert.same({ [8928] = 15, [2871] = 3 }, Inventory.Counts(ns.Api))
  end)

  it("describes an empty slot, an unknown item and a weapon", function()
    WowStub.state.equipment[17] = nil
    assert.same({ empty = true }, Inventory.DescribeWeapon(ns.Api, 17))
    WowStub.state.equipment[16] = 5555
    assert.is_nil(Inventory.DescribeWeapon(ns.Api, 16))
    WowStub.state.equipment[16] = 1001
    assert.same({ classID = 2, subclassID = 15 }, Inventory.DescribeWeapon(ns.Api, 16))
  end)

  it("gives nil when the client cannot tell what is equipped", function()
    WowStub.state.equipment[16] = WowStub.Secret
    assert.is_nil(Inventory.DescribeWeapon(ns.Api, 16))
  end)

  it("lists what fits the weapon, in catalog order, with counts", function()
    local counts = { [3239] = 2, [2871] = 4, [6947] = 1, [8928] = 7, [20749] = 1 }
    local list = Inventory.Applicable(counts, { classID = 2, subclassID = 15 })
    assert.same({
      { itemID = 8928, count = 7, kind = "poison" },
      { itemID = 6947, count = 1, kind = "poison" },
      { itemID = 2871, count = 4, kind = "sharpening" },
      { itemID = 20749, count = 1, kind = "oil" },
    }, list)
  end)

  it("lists nothing for an empty slot", function()
    assert.same({}, Inventory.Applicable({ [8928] = 7 }, { empty = true }))
  end)
end)
