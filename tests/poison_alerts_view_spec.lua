local Loader = dofile("tests/support/loader.lua")

describe("PoisonAlertsView", function()
  local ns, view, settings, said, bus

  local function weapons(...)
    WowStub.state.weapon = { ... }
  end

  before_each(function()
    WowStub.Reset()
    ns = Loader.Full({ "Core/Init.lua", "Commands/Slash.lua" })
    local store = ns.Store.Open({})
    settings = ns.Settings.New(store:Profile("Player-1").settings)
    local alerts = ns.PoisonAlerts.New({
      settings = settings,
      weaponState = ns.WeaponState.New({ data = {} }),
    })
    said = {}
    bus = ns.EventBus.New()
    view = ns.PoisonAlertsView.New({
      alerts = alerts,
      settings = settings,
      bus = bus,
      say = function(line)
        said[#said + 1] = line
      end,
    })
    weapons(false, 0, 0, 0, true, 3600000, 80, 603)
    WowStub.state.bags = {}
  end)

  it("registers the three trigger events", function()
    view:Start()
    assert.is_true(view.driver.events.PLAYER_ENTERING_WORLD)
    assert.is_true(view.driver.events.READY_CHECK)
    assert.is_true(view.driver.events.PLAYER_REGEN_ENABLED)
  end)

  it("prints one chat line per alert and shows a banner", function()
    weapons(false, 0, 0, 0, false, 0, 0, 0)
    WowStub.state.equipment[17] = 1002
    local texts = view:Check("combatEnd")
    assert.are.equal(2, #texts)
    assert.are.equal(2, #said)
    assert.is_truthy(said[1]:find("The main hand has no poison.", 1, true))
    assert.is_truthy(said[2]:find("The off hand has no poison.", 1, true))
    assert.is_true(view.banner.shown)
    assert.are.equal("The main hand has no poison.\nThe off hand has no poison.", view.banner.text:GetText())
  end)

  it("shows nothing when there is nothing to say", function()
    weapons(true, 3600000, 80, 603, true, 3600000, 80, 603)
    assert.are.same({}, view:Check("combatEnd"))
    assert.are.same({}, said)
    assert.is_nil(view.banner)
  end)

  it("does not repeat an alert", function()
    view:Check("combatEnd")
    view:Check("combatEnd")
    assert.are.equal(1, #said)
  end)

  it("hides the banner after a few seconds", function()
    view:Check("combatEnd")
    view.banner.scripts.OnUpdate(view.banner, ns.Constants.BANNER_SECONDS - 1)
    assert.is_true(view.banner.shown)
    view.banner.scripts.OnUpdate(view.banner, 2)
    assert.is_false(view.banner.shown)
  end)

  it("ignores the timer when no banner was ever made", function()
    assert.has_no.errors(function()
      view:OnUpdate(100)
    end)
  end)

  describe("layout", function()
    local function alertNow()
      weapons(false, 0, 0, 0, false, 0, 0, 0)
      return view:Check("combatEnd")
    end

    before_each(function()
      view:Start()
    end)

    it("anchors the banner at the saved position", function()
      settings:Set("alerts.position", { point = "LEFT", relativePoint = "LEFT", x = 30, y = 40 })
      alertNow()
      assert.are.same({ "LEFT", UIParent, "LEFT", 30, 40 }, view.banner.points[1])
    end)

    it("uses the old place by default", function()
      alertNow()
      assert.are.same({ "TOP", UIParent, "TOP", 0, -160 }, view.banner.points[1])
    end)

    it("shows the banner with a sample text and a labelled handle while unlocked", function()
      bus:Publish("layout.unlock")
      local banner = view.banner
      assert.is_true(banner.shown)
      assert.are.equal("Sample alert: drag the banner to place it", banner.text:GetText())
      assert.is_true(banner.handle.shown)
      assert.are.equal("Alert banner", banner.handle.label:GetText())
      assert.is_true(banner.moveBackground.shown)
      banner.scripts.OnUpdate(banner, 100)
      assert.is_true(banner.shown)
    end)

    it("hides the banner again on lock when no alert is active", function()
      bus:Publish("layout.unlock")
      bus:Publish("layout.lock")
      assert.is_false(view.banner.shown)
      assert.is_false(view.banner.handle.shown)
      assert.is_false(view.banner.moveBackground.shown)
    end)

    it("shows an alert that arrived while unlocked once the layout locks", function()
      bus:Publish("layout.unlock")
      alertNow()
      assert.are.equal(2, #said)
      assert.are.equal("Sample alert: drag the banner to place it", view.banner.text:GetText())
      bus:Publish("layout.lock")
      assert.is_true(view.banner.shown)
      assert.are.equal("The main hand has no poison.\nThe off hand has no poison.", view.banner.text:GetText())
      view.banner.scripts.OnUpdate(view.banner, ns.Constants.BANNER_SECONDS + 1)
      assert.is_false(view.banner.shown)
    end)

    it("keeps a banner that is still showing an alert when the layout locks", function()
      alertNow()
      bus:Publish("layout.unlock")
      assert.are.equal("Sample alert: drag the banner to place it", view.banner.text:GetText())
      bus:Publish("layout.lock")
      assert.is_true(view.banner.shown)
      assert.are.equal("The main hand has no poison.\nThe off hand has no poison.", view.banner.text:GetText())
    end)

    it("saves the position after a drag", function()
      bus:Publish("layout.unlock")
      local banner = view.banner
      banner.handle.scripts.OnDragStart()
      assert.is_true(banner.moving)
      banner.points = { { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 50, 60 } }
      banner.handle.scripts.OnDragStop()
      assert.is_false(banner.moving)
      assert.are.same(
        { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = 50, y = 60 },
        settings:Get("alerts.position")
      )
    end)

    it("does not move while locked, and ignores stray drag events", function()
      view:OnDragStart()
      view:OnDragStop()
      bus:Publish("layout.unlock")
      bus:Publish("layout.lock")
      view.banner.handle.scripts.OnDragStart()
      assert.is_falsy(view.banner.moving)
      assert.are.equal(-160, settings:Get("alerts.position").y)
    end)

    it("keeps the position when the banner has no anchor after a drag", function()
      bus:Publish("layout.unlock")
      view.banner.handle.scripts.OnDragStart()
      view.banner.points = {}
      view.banner.handle.scripts.OnDragStop()
      assert.are.equal(-160, settings:Get("alerts.position").y)
    end)

    it("does not fight a drag in progress when the position is applied", function()
      bus:Publish("layout.unlock")
      view.banner.handle.scripts.OnDragStart()
      view.banner.points = { { "TOP", UIParent, "TOP", 1, 2 } }
      view:ApplyPosition()
      assert.are.same({ "TOP", UIParent, "TOP", 1, 2 }, view.banner.points[1])
    end)

    it("moves the banner when the position is reset", function()
      alertNow()
      settings:Set("alerts.position", { point = "LEFT", relativePoint = "LEFT", x = 1, y = 2 })
      view:ApplyPosition()
      assert.are.same({ "LEFT", UIParent, "LEFT", 1, 2 }, view.banner.points[1])
    end)

    it("ignores the position before the banner exists", function()
      assert.has_no.errors(function()
        view:ApplyPosition()
      end)
    end)
  end)

  describe("events", function()
    before_each(function()
      view:Start()
    end)

    it("alerts when entering an instance", function()
      WowStub.state.instance = { true, "party" }
      WowStub.Fire(view.driver, "PLAYER_ENTERING_WORLD")
      assert.are.equal(1, #said)
    end)

    it("stays quiet when entering the open world", function()
      WowStub.Fire(view.driver, "PLAYER_ENTERING_WORLD")
      assert.are.equal(0, #said)
    end)

    it("alerts on a ready check", function()
      WowStub.Fire(view.driver, "READY_CHECK")
      assert.are.equal(1, #said)
    end)

    it("alerts when combat ends, never during combat", function()
      WowStub.state.inCombat = true
      WowStub.Fire(view.driver, "PLAYER_REGEN_ENABLED")
      assert.are.equal(0, #said)
      WowStub.state.inCombat = false
      WowStub.Fire(view.driver, "PLAYER_REGEN_ENABLED")
      assert.are.equal(1, #said)
    end)

    it("ignores other events", function()
      WowStub.Fire(view.driver, "SOMETHING_ELSE")
      assert.are.equal(0, #said)
    end)

    it("honours a disabled trigger", function()
      settings:Set("alerts.triggers.readycheck", false)
      WowStub.Fire(view.driver, "READY_CHECK")
      assert.are.equal(0, #said)
    end)
  end)

  it("prints to the chat by default", function()
    local plain = ns.PoisonAlertsView.New({ alerts = {
      Check = function()
        return {}
      end,
    } })
    assert.are.equal(print, plain.say)
  end)
end)
