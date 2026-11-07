local Loader = dofile("tests/support/loader.lua")

describe("ViewModelOptions", function()
  local ns, vm, settings, model, root, tracker, poison, alerts, bus

  before_each(function()
    WowStub.Reset()
    ns = Loader.Full({ "Core/Init.lua", "Commands/Slash.lua" })
    root = {}
    settings = ns.Settings.New(root)
    model = ns.TrackerModel.New(settings)
    tracker, poison, alerts = 0, 0, 0
    bus = ns.EventBus.New()
    vm = ns.ViewModelOptions.New({
      settings = settings,
      model = model,
      bus = bus,
      refreshAlerts = function()
        alerts = alerts + 1
      end,
      refreshTracker = function()
        tracker = tracker + 1
      end,
      refreshPoison = function()
        poison = poison + 1
      end,
    })
  end)

  describe("poison and alert settings", function()
    it("round-trips every setting and refreshes the poison button for its own", function()
      for _, path in ipairs(ns.ViewModelOptions.POISON_FLAGS) do
        assert.is_true(vm:Set(path, false))
        assert.is_false(vm:Get(path))
      end
      assert.is_true(vm:Set("poison.scale", 1.5))
      assert.are.equal(1.5, vm:Get("poison.scale"))
      assert.are.equal(3, poison)
      for _, path in ipairs(ns.ViewModelOptions.ALERT_NUMBERS) do
        assert.is_true(vm:Set(path, 7))
        assert.are.equal(7, settings:Get(path))
      end
      for _, path in ipairs(ns.ViewModelOptions.ALERT_TRIGGERS) do
        assert.is_true(vm:Set(path, false))
        assert.is_false(settings:Get(path))
      end
      assert.are.equal(3, poison)
    end)

    it("cycles the flyout direction and applies it to the button", function()
      local seen = {}
      for _ = 1, 5 do
        assert.is_true(vm:CycleFlyout())
        seen[#seen + 1] = vm:Get("poison.flyoutDirection")
      end
      assert.are.same({ "DOWN", "LEFT", "RIGHT", "UP", "DOWN" }, seen)
      assert.are.equal(5, poison)
    end)

    it("says a flyout direction change in combat is applied after combat", function()
      WowStub.state.inCombat = true
      assert.are.same({ true, ns.L["options.deferred"] }, { vm:CycleFlyout() })
      assert.are.equal("DOWN", vm:Get("poison.flyoutDirection"))
    end)

    it("snaps numbers to their step", function()
      vm:Set("poison.scale", 1.2345)
      assert.are.equal(1.25, vm:Get("poison.scale"))
      vm:Set("alerts.charges", 12.6)
      assert.are.equal(13, vm:Get("alerts.charges"))
      vm:Set("poison.scale", 0.7)
      assert.are.equal(0.7, vm:Get("poison.scale"))
    end)

    it("shows the reason when a value is refused and keeps the old one", function()
      local ok, message = vm:Set("poison.scale", 99)
      assert.is_false(ok)
      assert.are.equal(ns.L["options.error.invalid"], message)
      assert.are.equal(1, vm:Get("poison.scale"))
      assert.are.equal(0, poison)
      local ok2, message2 = vm:Set("alerts.nope", 1)
      assert.is_false(ok2)
      assert.are.equal(ns.L["options.error.invalid"], message2)
      assert.is_false((vm:Set("poison.locked", "yes")))
    end)

    it("says a poison button change in combat is applied after combat", function()
      WowStub.state.inCombat = true
      local ok, message = vm:Set("poison.locked", false)
      assert.is_true(ok)
      assert.are.equal(ns.L["options.deferred"], message)
      assert.is_false(settings:Get("poison.locked"))
      assert.are.equal(1, poison)
      local _, reset = vm:ResetPoisonPosition()
      assert.are.equal(ns.L["options.deferred"], reset)
      -- Alerts are plain data: nothing to defer.
      assert.are.same({ true }, { vm:Set("alerts.stock", 3) })
    end)

    it("resets the poison button position", function()
      settings:Set("poison.position", { point = "TOP", relativePoint = "TOP", x = 1, y = 2 })
      assert.is_true(vm:ResetPoisonPosition())
      assert.are.equal("BOTTOM", settings:Get("poison.position").point)
      assert.are.equal(1, poison)
    end)

    it("reports bounds and steps", function()
      assert.are.same({ 0.5, 3 }, { vm.Bounds("poison.scale") })
      assert.are.same({ 16, 96 }, { vm.Bounds("iconSize") })
      assert.is_nil(vm.Bounds("nope"))
      assert.are.equal(1, vm.Step("alerts.stock"))
      assert.are.equal(1, vm.Step("columns"))
      assert.are.equal(0.05, vm.Step("poison.scale"))
    end)
  end)

  describe("layout", function()
    it("unlocks and locks every element through the bus", function()
      local events = {}
      bus:Subscribe("layout.unlock", function()
        events[#events + 1] = "unlock"
      end)
      bus:Subscribe("layout.lock", function()
        events[#events + 1] = "lock"
      end)
      assert.is_false(vm:IsUnlocked())
      assert.are.same({ true, ns.L["layout.unlocked"] }, { vm:ToggleLayout() })
      settings:Set("poison.locked", false)
      assert.is_true(vm:IsUnlocked())
      assert.are.same({ true, ns.L["layout.locked"] }, { vm:ToggleLayout() })
      assert.are.same({ "unlock", "lock" }, events)
    end)

    it("refuses to change the layout in combat or without a bus", function()
      local published = 0
      bus:Subscribe("layout.unlock", function()
        published = published + 1
      end)
      WowStub.state.inCombat = true
      assert.are.same({ false, ns.L["layout.combat"] }, { vm:ToggleLayout() })
      assert.are.equal(0, published)
      WowStub.state.inCombat = false
      local bare = ns.ViewModelOptions.New({ settings = settings, model = model })
      assert.are.same({ false, ns.L["layout.unavailable"] }, { bare:ToggleLayout() })
    end)

    it("puts every position back at its default and refreshes every element", function()
      local spot = { point = "LEFT", relativePoint = "LEFT", x = 4, y = 5 }
      model:SetPosition("buffs", spot)
      settings:Set("poison.position", spot)
      settings:Set("poison.statusPosition", spot)
      settings:Set("alerts.position", spot)
      settings:Set("poison.scale", 2)
      assert.is_true(vm:ResetAllPositions())
      assert.are.same({ point = "CENTER", relativePoint = "CENTER", x = 0, y = 220 }, model:Group("buffs").position)
      assert.are.same(ns.Settings.Default("poison.position"), settings:Get("poison.position"))
      assert.are.same(ns.Settings.Default("poison.statusPosition"), settings:Get("poison.statusPosition"))
      assert.are.same(ns.Settings.Default("alerts.position"), settings:Get("alerts.position"))
      assert.are.equal(2, settings:Get("poison.scale"))
      assert.are.same({ 1, 1, 1 }, { tracker, alerts, poison })
    end)

    it("says the protected parts follow after combat", function()
      WowStub.state.inCombat = true
      assert.are.same({ true, ns.L["options.deferred"] }, { vm:ResetAllPositions() })
      assert.are.equal(1, poison)
    end)
  end)

  describe("tracker layout", function()
    it("lists the groups with their titles", function()
      local groups = vm:Groups()
      assert.are.same({ "essentials", "buffs", "target" }, { groups[1].id, groups[2].id, groups[3].id })
      assert.are.equal("Essentials", groups[1].title)
    end)

    it("round-trips every layout number and redraws", function()
      for index, key in ipairs(ns.ViewModelOptions.LAYOUT_NUMBERS) do
        local low, high = vm.Bounds(key)
        assert.is_true(vm:SetLayout("buffs", key, high))
        assert.are.equal(high, vm:Layout("buffs")[key])
        assert.are.equal(index * 2 - 1, tracker)
        assert.is_true(vm:SetLayout("buffs", key, low))
      end
      assert.is_true(vm:SetLayout("buffs", "iconSize", 40.4))
      assert.are.equal(40, vm:Layout("buffs").iconSize)
    end)

    it("cycles the choice options through every value", function()
      local seen = {}
      for _, key in ipairs({ "growth", "mode", "showWhenMissing" }) do
        seen[key] = {}
        for _ = 1, 5 do
          assert.is_true(vm:Cycle("buffs", key))
          seen[key][vm:Layout("buffs")[key]] = true
        end
      end
      assert.are.same({ LEFT = true, UP = true, DOWN = true, RIGHT = true }, seen.growth)
      assert.are.same({ icons = true, bars = true }, seen.mode)
      assert.are.same({ hide = true, dim = true }, seen.showWhenMissing)
      assert.are.equal(15, tracker)
    end)

    it("shows the model's reason for a refused change", function()
      local ok, message = vm:SetLayout("buffs", "iconSize", 5)
      assert.is_false(ok)
      assert.are.equal(ns.L["options.error.invalid"], message)
      assert.are.same({ false, ns.L["options.error.unknown_group"] }, { vm:SetLayout("nope", "iconSize", 40) })
      assert.are.same({ false, ns.L["options.error.unknown_group"] }, { vm:Cycle("nope", "growth") })
      assert.are.same({ false, ns.L["options.error.unknown_option"] }, { vm:Cycle("buffs", "colour") })
      assert.are.equal(0, tracker)
    end)

    it("wraps around a choice list and starts over on an unknown value", function()
      assert.are.equal("icons", vm.Next({ "icons", "bars" }, "bars"))
      assert.are.equal("icons", vm.Next({ "icons", "bars" }, "other"))
    end)
  end)

  describe("tracker entries", function()
    it("lists rows with names, ids and move limits", function()
      WowStub.Set("C_Spell.GetSpellInfo", function(id)
        return { name = "Spell " .. id, iconID = 1 }
      end)
      local rows = vm:Entries("essentials")
      assert.are.equal(#model:Group("essentials").entries, #rows)
      assert.is_false(rows[1].canUp)
      assert.is_true(rows[1].canDown)
      assert.is_false(rows[#rows].canDown)
      assert.is_truthy(rows[1].text:find("(1856)", 1, true))
      assert.are.same({}, vm:Entries("nope"))
    end)

    it("adds by id and by name, delegating to the model", function()
      local ok, message = vm:AddEntry("essentials", "12345")
      assert.is_true(ok)
      assert.is_truthy(message:find("12345", 1, true))
      assert.is_true(vm:AddEntry("essentials", "Thousand Cuts"))
      local rows = vm:Entries("essentials")
      assert.are.equal("Thousand Cuts", rows[#rows].text)
      assert.is_true(rows[#rows].custom)
      assert.are.equal("Thousand Cuts", model:Group("essentials").entries[#rows].name)
      assert.are.equal(2, tracker)
    end)

    it("shows the model's reason when adding fails", function()
      assert.are.same({ false, ns.L["options.error.invalid"] }, { vm:AddEntry("essentials", "   ") })
      vm:AddEntry("essentials", "4242")
      assert.are.same({ false, ns.L["options.error.duplicate"] }, { vm:AddEntry("essentials", "4242") })
      assert.are.same({ false, ns.L["options.error.unknown_group"] }, { vm:AddEntry("nope", "1") })
      while #model:Group("essentials").entries < ns.Constants.TRACKER.MAX_ENTRIES do
        model:AddEntry("essentials", #model:Group("essentials").entries + 100000)
      end
      assert.are.same({ false, ns.L["options.error.full"] }, { vm:AddEntry("essentials", "99999999") })
    end)

    it("removes and moves entries through the model", function()
      local first = model:Group("buffs").entries[1]
      local second = model:Group("buffs").entries[2]
      assert.is_true(vm:MoveEntry("buffs", 1, 1))
      assert.are.equal(second, model:Group("buffs").entries[1])
      assert.are.equal(first, model:Group("buffs").entries[2])
      assert.is_true(vm:MoveEntry("buffs", 2, -1))
      assert.are.equal(first, model:Group("buffs").entries[1])
      local count = #model:Group("buffs").entries
      assert.is_true(vm:RemoveEntry("buffs", 1))
      assert.are.equal(count - 1, #model:Group("buffs").entries)
      assert.are.equal(3, tracker)
    end)

    it("shows the model's reason when moving or removing fails", function()
      assert.are.same({ false, ns.L["options.error.invalid"] }, { vm:MoveEntry("buffs", 1, -1) })
      assert.are.same({ false, ns.L["options.error.invalid"] }, { vm:RemoveEntry("buffs", 99) })
      assert.are.same({ false, ns.L["options.error.unknown_group"] }, { vm:RemoveEntry("nope", 1) })
      assert.are.equal(0, tracker)
    end)

    it("names an entry the client cannot name", function()
      WowStub.Remove("C_Spell.GetSpellInfo")
      WowStub.Remove("GetSpellInfo")
      assert.are.equal("Unknown spell (77)", vm:EntryText({ spellId = 77 }))
    end)

    it("resets one group or all of them", function()
      vm:AddEntry("buffs", "4242")
      vm:SetLayout("buffs", "iconSize", 60)
      assert.is_true(vm:ResetGroup("buffs"))
      assert.are.equal(36, vm:Layout("buffs").iconSize)
      assert.is_nil(vm:Layout("nope"))
      assert.are.same({ false, ns.L["options.error.unknown_group"] }, { vm:ResetGroup("nope") })
      vm:SetLayout("target", "columns", 3)
      assert.is_true(vm:ResetAll())
      assert.are.equal(8, vm:Layout("target").columns)
      assert.are.equal(5, tracker)
    end)

    it("falls back to the generic sentence for an unknown reason", function()
      assert.are.equal(ns.L["options.error.invalid"], vm:Reason("something_else"))
    end)
  end)

  it("works without refresh callbacks", function()
    local bare = ns.ViewModelOptions.New({ settings = settings, model = model })
    assert.is_true(bare:Set("poison.locked", false))
    assert.is_true(bare:SetLayout("buffs", "columns", 4))
  end)
end)
