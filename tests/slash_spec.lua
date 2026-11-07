local Loader = dofile("tests/support/loader.lua")

describe("Slash", function()
  local ns, printed, realPrint

  local function text()
    return table.concat(printed, "\n")
  end

  before_each(function()
    WowStub.Reset()
    printed = {}
    realPrint = _G.print
    _G.print = function(line)
      printed[#printed + 1] = line
    end
    ns = Loader.Full({ "Core/Init.lua" })
    ns.store = ns.Store.Open({})
  end)

  after_each(function()
    _G.print = realPrint
    _G.SLASH_RAS1, _G.SLASH_RAS2 = nil, nil
  end)

  it("registers /ras and /rogueassistant", function()
    assert.are.equal("/ras", _G.SLASH_RAS1)
    assert.are.equal("/rogueassistant", _G.SLASH_RAS2)
    assert.are.equal(ns.Slash.Dispatch, _G.SlashCmdList.RAS)
  end)

  it("says later for /ras", function()
    for _, line in ipairs({ "", "  " }) do
      printed = {}
      ns.Slash.Dispatch(line)
      assert.is_truthy(text():find("available in a later version", 1, true), line)
    end
  end)

  describe("unlock and lock", function()
    local events

    before_each(function()
      events = {}
      ns.bus = ns.EventBus.New()
      for _, event in ipairs({ "layout.unlock", "layout.lock" }) do
        ns.bus:Subscribe(event, function()
          events[#events + 1] = event
        end)
      end
    end)

    it("publish the layout events", function()
      ns.Slash.Dispatch("unlock")
      assert.is_truthy(text():find("Frames unlocked", 1, true))
      ns.Slash.Dispatch("LOCK")
      assert.is_truthy(text():find("Frames locked", 1, true))
      assert.are.same({ "layout.unlock", "layout.lock" }, events)
    end)

    it("publish nothing in combat", function()
      WowStub.state.inCombat = true
      ns.Slash.Dispatch("unlock")
      assert.is_truthy(text():find("cannot be changed in combat", 1, true))
      assert.are.same({}, events)
    end)

    it("say so when the addon is not active", function()
      ns.disabled = "not_rogue"
      ns.Slash.Dispatch("lock")
      assert.is_truthy(text():find("not active on this character", 1, true))
      ns.disabled, ns.bus = nil, nil
      printed = {}
      ns.Slash.Dispatch("unlock")
      assert.is_truthy(text():find("not active on this character", 1, true))
      assert.are.same({}, events)
    end)
  end)

  it("prints help and rejects unknown commands", function()
    ns.Slash.Dispatch("help")
    assert.is_truthy(text():find("/ras debug", 1, true))
    printed = {}
    ns.Slash.Dispatch("bogus now")
    assert.is_truthy(text():find("Unknown command 'bogus'.", 1, true))
    assert.is_truthy(text():find("Commands:", 1, true))
  end)

  it("prints the debug help for a missing or unknown subcommand", function()
    ns.Slash.Dispatch("debug")
    assert.is_truthy(text():find("Debug commands:", 1, true))
    assert.is_truthy(text():find("selftest", 1, true))
    printed = {}
    ns.Slash.Dispatch("debug nothing")
    assert.is_truthy(text():find("Debug commands:", 1, true))
  end)

  it("runs debug probe, prints NN key=value lines and saves them bounded", function()
    ns.Slash.Dispatch("debug probe")
    assert.is_truthy(printed[1]:match("^01 class=.*ROGUE"))
    assert.are.equal(#ns.Probe.ITEMS, #ns.store:Debug().lastProbe)
    assert.is_truthy(text():find("probe lines saved", 1, true))
  end)

  it("runs debug probe without a store", function()
    ns.store = nil
    ns.Slash.Dispatch("debug probe")
    assert.is_falsy(text():find("probe lines saved", 1, true))
    assert.is_truthy(printed[1]:match("^01 "))
  end)

  it("runs debug bags, spells, auras and selftest", function()
    WowStub.state.bags = { [0] = { size = 1, [1] = { itemID = 5, stackCount = 2 } } }
    ns.Slash.Dispatch("debug bags")
    assert.is_truthy(text():find("bag=0 slot=1 itemID=5 count=2 name=Item5", 1, true))
    printed = {}
    ns.Slash.Dispatch("debug spells")
    assert.is_truthy(text():find("not readable", 1, true))
    printed = {}
    ns.Slash.Dispatch("debug auras")
    assert.is_truthy(text():find("Player buffs", 1, true))
    printed = {}
    ns.Slash.Dispatch("debug selftest")
    assert.is_truthy(text():find("client APIs", 1, true))
  end)

  it("reports a handler that raises without propagating", function()
    ns.Slash.RegisterDebug("boom", function()
      error("bad")
    end, "cmd.debug.probe")
    assert.has_no.errors(function()
      ns.Slash.Dispatch("debug boom")
    end)
    assert.is_truthy(text():find("Error in /ras boom", 1, true))
  end)

  it("lets later phases register and replace commands", function()
    local calls = {}
    ns.Slash.Register("extra", function(rest)
      calls[#calls + 1] = "first:" .. rest
    end, "cmd.help.lock")
    ns.Slash.Register("extra", function(rest)
      calls[#calls + 1] = "second:" .. rest
    end, "cmd.help.lock")
    ns.Slash.Dispatch("extra  some args ")
    assert.are.same({ "second:some args" }, calls)
  end)
end)
