local Loader = dofile("tests/support/loader.lua")

describe("EventBus", function()
  local bus, EventBus

  before_each(function()
    EventBus = Loader.Load({ "Core/EventBus.lua" }).EventBus
    bus = EventBus.New()
  end)

  it("delivers arguments to every subscriber and counts them", function()
    local seen = {}
    bus:Subscribe("x", function(a, b)
      seen[#seen + 1] = a .. b
    end)
    bus:Subscribe("x", function(a)
      seen[#seen + 1] = a
    end)
    assert.are.equal(2, bus:Publish("x", "p", "q"))
    assert.are.same({ "pq", "p" }, seen)
  end)

  it("returns 0 for an event nobody listens to", function()
    assert.are.equal(0, bus:Publish("nothing"))
  end)

  it("rejects a handler that is not a function", function()
    assert.has_error(function()
      bus:Subscribe("x", "nope")
    end)
  end)

  it("unsubscribes", function()
    local calls = 0
    local handler = bus:Subscribe("x", function()
      calls = calls + 1
    end)
    assert.is_true(bus:Unsubscribe("x", handler))
    assert.is_false(bus:Unsubscribe("x", handler))
    assert.is_false(bus:Unsubscribe("never", handler))
    bus:Publish("x")
    assert.are.equal(0, calls)
  end)

  it("keeps going when a handler raises and records the error", function()
    local ran = false
    bus:Subscribe("x", function()
      error("boom")
    end)
    bus:Subscribe("x", function()
      ran = true
    end)
    assert.are.equal(1, bus:Publish("x"))
    assert.is_true(ran)
    assert.are.equal(1, #bus:Errors())
    assert.are.equal("x", bus:Errors()[1].event)
    bus:ClearErrors()
    assert.are.equal(0, #bus:Errors())
  end)

  it("tolerates a handler that unsubscribes while running", function()
    local handler
    handler = bus:Subscribe("x", function()
      bus:Unsubscribe("x", handler)
    end)
    assert.are.equal(1, bus:Publish("x"))
    assert.are.equal(0, bus:Publish("x"))
  end)

  it("bounds the stored errors", function()
    bus:Subscribe("x", function()
      error("boom")
    end)
    for _ = 1, EventBus.MAX_ERRORS + 5 do
      bus:Publish("x")
    end
    assert.are.equal(EventBus.MAX_ERRORS, #bus:Errors())
  end)
end)
