local Loader = dofile("tests/support/loader.lua")

describe("PoisonAlertsView", function()
  local ns, view, settings, said

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
    view = ns.PoisonAlertsView.New({
      alerts = alerts,
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
