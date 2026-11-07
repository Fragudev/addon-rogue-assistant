local Loader = dofile("tests/support/loader.lua")

describe("Startup", function()
  local ns

  before_each(function()
    WowStub.Reset()
    ns = Loader.Load({ "Core/Constants.lua", "Core/Startup.lua" })
  end)

  it("runs the starters in registration order", function()
    local order = {}
    ns.Startup.Register(function()
      order[#order + 1] = "a"
    end)
    ns.Startup.Register(function()
      order[#order + 1] = "b"
    end)
    assert.are.equal(2, ns.Startup.Run())
    assert.are.same({ "a", "b" }, order)
  end)

  it("keeps going and logs when a starter raises", function()
    ns.store = { Log = spy.new(function() end) }
    local ran = false
    ns.Startup.Register(function()
      error("boom")
    end)
    ns.Startup.Register(function()
      ran = true
    end)
    assert.are.equal(1, ns.Startup.Run())
    assert.is_true(ran)
    assert.spy(ns.store.Log).was.called(1)
  end)

  it("survives a failing starter without a store", function()
    ns.Startup.Register(function()
      error("boom")
    end)
    assert.are.equal(0, ns.Startup.Run())
  end)

  it("refuses something that is not a function", function()
    assert.has_error(function()
      ns.Startup.Register("nope")
    end)
  end)
end)
