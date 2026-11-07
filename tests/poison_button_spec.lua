-- luacheck: ignore 212/self
local Loader = dofile("tests/support/loader.lua")

describe("PoisonButton", function()
  local ns, settings, data, weaponState, poison, bus

  local function bags(...)
    local slots = { size = 20 }
    for index, item in ipairs({ ... }) do
      slots[index] = { itemID = item[1], stackCount = item[2] }
    end
    WowStub.state.bags = { [0] = slots }
  end

  local function weapons(...)
    WowStub.state.weapon = { ... }
  end

  local function fire(event, ...)
    WowStub.Fire(poison.driver, event, ...)
  end

  local function row(index)
    return poison.rows[index]
  end

  before_each(function()
    WowStub.Reset()
    ns = Loader.Full({ "Core/Init.lua", "Commands/Slash.lua" })
    local store = ns.Store.Open({})
    local profile = store:Profile("Player-1")
    settings = ns.Settings.New(profile.settings)
    data = {}
    bus = ns.EventBus.New()
    weaponState = ns.WeaponState.New({ data = data })
    poison = ns.PoisonButton.New({ settings = settings, data = data, bus = bus, weaponState = weaponState })
    bags({ 6947, 10 }, { 8926, 5 }, { 2893, 3 })
    weapons(false, 0, 0, 0, false, 0, 0, 0)
  end)

  describe("structure", function()
    before_each(function()
      poison:Start()
    end)

    it("builds a secure header, button, flyout and rows", function()
      assert.are.equal("SecureHandlerBaseTemplate", poison.header.template)
      assert.are.equal("SecureActionButtonTemplate", poison.button.template)
      assert.are.equal("SecureHandlerBaseTemplate", poison.flyout.template)
      assert.are.same({ "AnyUp" }, poison.button.clicks)
      assert.are.equal(poison.flyout, poison.header.refs.flyout)
      assert.is_false(poison.flyout.shown)
      assert.are.equal(3, #poison.rows)
    end)

    it("toggles the flyout from a wrapped secure snippet that lets Shift clicks through", function()
      local wrap = poison.button.wraps.OnClick
      assert.are.equal(poison.header, wrap.header)
      assert.is_nil(wrap.post)
      assert.is_truthy(wrap.pre:find("IsShiftKeyDown()", 1, true))
      assert.is_truthy(wrap.pre:find('control:GetFrameRef("flyout")', 1, true))
      assert.is_truthy(wrap.pre:find("flyout:Show()", 1, true))
      assert.is_truthy(wrap.pre:find("flyout:Hide()", 1, true))
      assert.is_truthy(wrap.pre:find("return false", 1, true))
    end)

    it("hides the flyout after a poison is clicked", function()
      local wrap = row(1).wraps.OnClick
      assert.are.equal(poison.header, wrap.header)
      assert.is_truthy(wrap.post:find('GetFrameRef("flyout"):Hide()', 1, true))
    end)

    it("applies a poison to the main hand with left click and to the off hand with right click", function()
      local first = row(1)
      assert.are.same({ "AnyUp" }, first.clicks)
      assert.are.equal("item", first.attributes.type1)
      assert.are.equal("item:8926", first.attributes.item1)
      assert.are.equal(16, first.attributes["target-slot1"])
      assert.are.equal("item", first.attributes.type2)
      assert.are.equal("item:8926", first.attributes.item2)
      assert.are.equal(17, first.attributes["target-slot2"])
    end)

    it("lists the top rank of every family first with its count", function()
      assert.are.equal("item:8926", row(1).attributes.item1)
      assert.are.equal("item:2893", row(2).attributes.item1)
      assert.are.equal("item:6947", row(3).attributes.item1)
      assert.are.equal("Instant Poison IV  (5)", row(1).label:GetText())
      assert.is_false(poison.flyout.empty.shown)
    end)

    it("shows the empty note and clears surplus rows when the bags empty", function()
      bags()
      fire("BAG_UPDATE_DELAYED")
      assert.is_true(poison.flyout.empty.shown)
      for index = 1, 3 do
        assert.is_nil(row(index).attributes.type1)
        assert.is_nil(row(index).attributes.item2)
        assert.is_nil(row(index).attributes["target-slot1"])
        assert.is_false(row(index).shown)
      end
      bags({ 2892, 1 })
      fire("BAG_UPDATE_DELAYED")
      assert.is_true(row(1).shown)
      assert.are.equal("item:2892", row(1).attributes.item1)
      assert.is_false(row(2).shown)
    end)

    it("does not touch a protected frame in combat", function()
      WowStub.state.inCombat = true
      bags({ 2892, 1 })
      fire("BAG_UPDATE_DELAYED")
      assert.is_true(poison.dirty)
      assert.are.equal("item:8926", row(1).attributes.item1)
      assert.are.same({}, WowStub.state.violations)
    end)

    it("rebuilds after combat when something changed meanwhile", function()
      WowStub.state.inCombat = true
      bags({ 2892, 1 })
      fire("BAG_UPDATE_DELAYED")
      WowStub.state.inCombat = false
      fire("PLAYER_REGEN_ENABLED")
      assert.is_false(poison.dirty)
      assert.are.equal("item:2892", row(1).attributes.item1)
      assert.are.same({}, WowStub.state.violations)
    end)

    it("does not rebuild after combat when nothing changed", function()
      local before = row(1).attributeWrites
      fire("PLAYER_REGEN_ENABLED")
      assert.are.equal(before, row(1).attributeWrites)
    end)
  end)

  describe("last poison", function()
    before_each(function()
      poison:Start()
    end)

    it("starts without shift attributes", function()
      assert.is_nil(poison.button.attributes["shift-type1"])
      assert.is_nil(poison.button.attributes["shift-type2"])
    end)

    it("remembers the last main hand poison and sets the shift attributes", function()
      WowStub.Click(row(2), "LeftButton")
      assert.are.equal(2893, data.last.mh)
      local button = poison.button.attributes
      assert.are.equal("item", button["shift-type1"])
      assert.are.equal("item:2893", button["shift-item1"])
      assert.are.equal(16, button["shift-target-slot1"])
      assert.is_nil(button["shift-type2"])
    end)

    it("remembers the last off hand poison separately", function()
      WowStub.Click(row(1), "LeftButton")
      WowStub.Click(row(3), "RightButton")
      local button = poison.button.attributes
      assert.are.equal("item:8926", button["shift-item1"])
      assert.are.equal("item", button["shift-type2"])
      assert.are.equal("item:6947", button["shift-item2"])
      assert.are.equal(17, button["shift-target-slot2"])
    end)

    it("drops the shift attributes when the poison left the bags", function()
      WowStub.Click(row(1), "LeftButton")
      bags({ 6947, 10 })
      fire("BAG_UPDATE_DELAYED")
      assert.is_nil(poison.button.attributes["shift-type1"])
      assert.is_nil(poison.button.attributes["shift-item1"])
      assert.are.equal(8926, data.last.mh)
    end)

    it("ignores other mouse buttons", function()
      WowStub.Click(row(1), "MiddleButton")
      assert.is_nil(data.last.mh)
    end)

    it("waits for the end of combat to change the shift attributes", function()
      WowStub.state.inCombat = true
      WowStub.Click(row(1), "LeftButton")
      assert.are.equal(8926, data.last.mh)
      assert.is_true(poison.dirty)
      assert.is_nil(poison.button.attributes["shift-type1"])
      assert.are.same({}, WowStub.state.violations)
      WowStub.state.inCombat = false
      fire("PLAYER_REGEN_ENABLED")
      assert.are.equal("item:8926", poison.button.attributes["shift-item1"])
      assert.are.same({}, WowStub.state.violations)
    end)

    it("tells the weapon state what the Shift click reapplies", function()
      local noted = {}
      weaponState.NoteApplied = function(_, name, itemID)
        noted[#noted + 1] = name .. ":" .. itemID
      end
      WowStub.Click(row(1), "LeftButton")
      WowStub.Click(row(2), "RightButton")
      noted = {}
      WowStub.Click(poison.button, "LeftButton")
      assert.are.same({}, noted)
      WowStub.state.shift = true
      WowStub.Click(poison.button, "LeftButton")
      WowStub.Click(poison.button, "RightButton")
      WowStub.Click(poison.button, "MiddleButton")
      assert.are.same({ "mh:8926", "oh:2893" }, noted)
    end)

    it("learns the enchant of an applied poison", function()
      WowStub.Click(row(1), "LeftButton")
      weapons(true, 3600000, 80, 603, false, 0, 0, 0)
      weaponState:Read()
      assert.are.equal(8926, data.enchants[603])
      poison:RefreshStatus()
      assert.are.equal(200000 + 8926, poison.button.icon:GetTexture())
    end)
  end)

  describe("start", function()
    it("waits for the end of combat to build anything", function()
      WowStub.state.inCombat = true
      poison:Start()
      assert.is_false(poison.built)
      assert.is_true(poison.dirty)
      assert.is_nil(poison.button)
      WowStub.state.inCombat = false
      fire("PLAYER_REGEN_ENABLED")
      assert.is_true(poison.built)
      assert.is_false(poison.dirty)
      assert.are.equal(3, #poison.rows)
      assert.are.same({}, WowStub.state.violations)
    end)

    it("registers its events and skips the combat log", function()
      poison:Start()
      assert.is_true(poison.driver.events.BAG_UPDATE_DELAYED)
      assert.is_true(poison.driver.events.PLAYER_REGEN_ENABLED)
      assert.is_true(poison.driver.events.UNIT_INVENTORY_CHANGED)
      assert.is_nil(poison.driver.events.COMBAT_LOG_EVENT_UNFILTERED)
    end)

    it("builds once", function()
      poison:Start()
      local header = poison.header
      assert.is_true(poison:Build())
      assert.are.equal(header, poison.header)
    end)

    it("works without a bus", function()
      local alone = ns.PoisonButton.New({ settings = settings, data = data, weaponState = weaponState })
      assert.has_no.errors(function()
        alone:Start()
      end)
    end)
  end)

  describe("status", function()
    before_each(function()
      poison:Start()
    end)

    it("shows the logo and dashes without poisons", function()
      assert.are.equal(ns.Constants.LOGO_TEXTURE, poison.button.icon:GetTexture())
      assert.are.equal("MH —", poison.button.mhLine:GetText())
      assert.are.equal("OH —", poison.button.ohLine:GetText())
    end)

    it("shows minutes and charges and the poison icon", function()
      data.enchants = { [603] = 8926 }
      weapons(true, 600000, 80, 603, true, 120000, 40, 603)
      fire("UNIT_INVENTORY_CHANGED", "player")
      assert.are.equal("MH 10 min · 80", poison.button.mhLine:GetText())
      assert.are.equal("OH 2 min · 40", poison.button.ohLine:GetText())
      assert.are.equal(200000 + 8926, poison.button.icon:GetTexture())
    end)

    it("ignores the inventory of other units", function()
      weapons(true, 600000, 80, 603, false, 0, 0, 0)
      fire("UNIT_INVENTORY_CHANGED", "target")
      assert.are.equal("MH —", poison.button.mhLine:GetText())
    end)

    it("refreshes on a timer and also in combat", function()
      weapons(true, 600000, 80, 603, false, 0, 0, 0)
      WowStub.state.inCombat = true
      poison.driver.scripts.OnUpdate(poison.driver, 1)
      assert.are.equal("MH —", poison.button.mhLine:GetText())
      poison.driver.scripts.OnUpdate(poison.driver, ns.Constants.STATUS_REFRESH_SECONDS)
      assert.are.equal("MH 10 min · 80", poison.button.mhLine:GetText())
      assert.are.same({}, WowStub.state.violations)
    end)

    it("shows dashes when the weapons are unknown", function()
      WowStub.Remove("GetWeaponEnchantInfo")
      poison:RefreshStatus()
      assert.are.equal("MH —", poison.button.mhLine:GetText())
    end)

    it("does nothing before the frames exist", function()
      local early = ns.PoisonButton.New({ settings = settings, data = data, weaponState = weaponState })
      assert.has_no.errors(function()
        early:RefreshStatus()
      end)
    end)
  end)

  describe("layout", function()
    before_each(function()
      poison:Start()
    end)

    it("applies changed settings out of combat", function()
      settings:Set("poison.scale", 2)
      settings:Set("poison.locked", false)
      settings:Set("poison.position", { point = "TOP", relativePoint = "TOP", x = 5, y = -6 })
      assert.is_true(poison:ApplySettings())
      assert.are.equal(2, poison.button.scale)
      assert.is_true(poison.button.movable)
      assert.are.same({ "TOP", UIParent, "TOP", 5, -6 }, poison.button.points[1])
    end)

    it("defers changed settings in combat until PLAYER_REGEN_ENABLED", function()
      WowStub.state.inCombat = true
      settings:Set("poison.scale", 2)
      assert.is_false(poison:ApplySettings())
      assert.are.equal(1, poison.button.scale)
      assert.are.same({}, WowStub.state.violations)
      WowStub.state.inCombat = false
      fire("PLAYER_REGEN_ENABLED")
      assert.are.equal(2, poison.button.scale)
      assert.is_false(poison.settingsDirty)
    end)

    it("ignores settings before the frames exist", function()
      local fresh = ns.PoisonButton.New({ settings = settings, data = data, bus = bus, weaponState = weaponState })
      assert.is_false(fresh:ApplySettings())
    end)

    it("restores the saved position and scale, locked by default", function()
      local point = poison.button.points[1]
      assert.are.same({ "BOTTOM", UIParent, "BOTTOM", 0, 200 }, point)
      assert.are.equal(1, poison.button.scale)
      assert.is_false(poison.button.movable)
      assert.is_false(poison.button.moveOverlay.shown)
    end)

    it("unlocks and locks through the bus", function()
      bus:Publish("layout.unlock")
      assert.is_false(settings:Get("poison.locked"))
      assert.is_true(poison.button.movable)
      assert.is_true(poison.button.moveOverlay.shown)
      bus:Publish("layout.lock")
      assert.is_true(settings:Get("poison.locked"))
      assert.is_false(poison.button.movable)
    end)

    it("refuses to change the lock in combat", function()
      WowStub.state.inCombat = true
      assert.is_false(poison:SetLocked(false))
      assert.is_true(settings:Get("poison.locked"))
      assert.are.same({}, WowStub.state.violations)
    end)

    it("refuses to change the lock before the frames exist", function()
      local early = ns.PoisonButton.New({ settings = settings, data = data, weaponState = weaponState })
      assert.is_false(early:SetLocked(false))
    end)

    it("saves the position after a drag", function()
      bus:Publish("layout.unlock")
      poison.button.scripts.OnDragStart(poison.button)
      assert.is_true(poison.button.moving)
      poison.button.points = { { "TOPLEFT", UIParent, "BOTTOMLEFT", 120, 340 } }
      poison.button.scripts.OnDragStop(poison.button)
      assert.is_false(poison.button.moving)
      assert.are.same(
        { point = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = 120, y = 340 },
        settings:Get("poison.position")
      )
    end)

    it("does not drag while locked or in combat", function()
      poison.button.scripts.OnDragStart(poison.button)
      assert.is_falsy(poison.button.moving)
      bus:Publish("layout.unlock")
      WowStub.state.inCombat = true
      poison.button.scripts.OnDragStart(poison.button)
      assert.is_falsy(poison.button.moving)
      poison.button.scripts.OnDragStop(poison.button)
      assert.are.equal(200, settings:Get("poison.position").y)
    end)

    it("keeps the position when the frame has no anchor after a drag", function()
      bus:Publish("layout.unlock")
      poison.button.scripts.OnDragStart(poison.button)
      poison.button.points = {}
      poison.button.scripts.OnDragStop(poison.button)
      assert.are.equal(200, settings:Get("poison.position").y)
    end)
  end)

  describe("tooltips", function()
    local tooltip

    before_each(function()
      tooltip = { text = nil, shown = false }
      function tooltip:SetOwner() end
      function tooltip:SetText(text)
        self.text = text
      end
      function tooltip:Show()
        self.shown = true
      end
      function tooltip:Hide()
        self.shown = false
      end
      _G.GameTooltip = tooltip
      poison:Start()
    end)

    after_each(function()
      _G.GameTooltip = nil
    end)

    it("explains the clicks of the button and of the rows", function()
      poison.button.hooks.OnEnter[1](poison.button)
      assert.is_truthy(tooltip.text:find("Shift", 1, true))
      assert.is_nil(tooltip.text:find("drag", 1, true))
      assert.is_true(tooltip.shown)
      poison.button.hooks.OnLeave[1](poison.button)
      assert.is_false(tooltip.shown)
      bus:Publish("layout.unlock")
      poison.button.hooks.OnEnter[1](poison.button)
      assert.is_truthy(tooltip.text:find("drag", 1, true))
      row(1).hooks.OnEnter[1](row(1))
      assert.is_truthy(tooltip.text:find("Right click: off hand", 1, true))
      row(1).hooks.OnLeave[1](row(1))
      assert.is_false(tooltip.shown)
    end)

    it("copes with a client that has no tooltip", function()
      _G.GameTooltip = nil
      assert.has_no.errors(function()
        poison.button.hooks.OnEnter[1](poison.button)
        poison.button.hooks.OnLeave[1](poison.button)
      end)
    end)
  end)
end)
