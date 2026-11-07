local Loader = dofile("tests/support/loader.lua")

describe("PoisonAlerts", function()
  local ns, alerts, settings, data

  local function weapons(...)
    WowStub.state.weapon = { ... }
  end

  local function keys(list)
    local out = {}
    for _, alert in ipairs(list) do
      out[#out + 1] = alert.key
    end
    return out
  end

  -- Both hands poisoned with plenty of time and charges; enchant 603 is Instant Poison (6947).
  local function healthy()
    weapons(true, 3600000, 80, 603, true, 3600000, 80, 603)
    WowStub.state.bags = { [0] = { size = 2, [1] = { itemID = 6947, stackCount = 20 } } }
  end

  before_each(function()
    WowStub.Reset()
    ns = Loader.Full({ "Core/Init.lua", "Commands/Slash.lua" })
    local store = ns.Store.Open({})
    local profile = store:Profile("Player-1")
    settings = ns.Settings.New(profile.settings)
    data = { enchants = { [603] = 6947 } }
    alerts = ns.PoisonAlerts.New({
      settings = settings,
      weaponState = ns.WeaponState.New({ data = data }),
    })
    healthy()
  end)

  it("raises nothing when everything is fine", function()
    assert.are.same({}, alerts:Evaluate())
    assert.are.same({}, alerts:Check("combatEnd"))
  end)

  it("alerts a weapon without poison", function()
    weapons(false, 0, 0, 0, true, 3600000, 80, 603)
    local found = alerts:Evaluate()
    assert.are.same({ "mh:none" }, keys(found))
    assert.are.equal("none", found[1].kind)
    assert.are.equal("mh", found[1].slot)
  end)

  it("does not alert an empty off hand", function()
    WowStub.state.equipment[17] = nil
    weapons(true, 3600000, 80, 603, false, 0, 0, 0)
    assert.are.same({}, alerts:Evaluate())
  end)

  it("does not alert a hand the client cannot describe", function()
    WowStub.Set("GetWeaponEnchantInfo", function()
      return true, 3600000, 80, 603
    end)
    assert.are.same({}, alerts:Evaluate())
  end)

  it("is silent when the weapons are unreadable", function()
    WowStub.Remove("GetWeaponEnchantInfo")
    assert.is_nil(alerts:Evaluate())
    assert.are.same({}, alerts:Check("instance"))
  end)

  it("alerts a poison that expires soon", function()
    weapons(true, 4 * 60000 + 1, 80, 603, true, 3600000, 80, 603)
    local found = alerts:Evaluate()
    assert.are.same({ "mh:expiring" }, keys(found))
    assert.are.equal(5, found[1].minutes)
    weapons(true, 5 * 60000, 80, 603, true, 3600000, 80, 603)
    assert.are.same({}, alerts:Evaluate())
  end)

  it("alerts low charges", function()
    weapons(true, 3600000, 19, 603, true, 3600000, 20, 603)
    local found = alerts:Evaluate()
    assert.are.same({ "mh:charges" }, keys(found))
    assert.are.equal(19, found[1].charges)
  end)

  it("alerts low stock of the equipped family", function()
    WowStub.state.bags =
      { [0] = { size = 2, [1] = { itemID = 6947, stackCount = 2 }, [2] = { itemID = 8926, stackCount = 2 } } }
    local found = alerts:Evaluate()
    assert.are.same({ "stock:instant" }, keys(found))
    assert.are.equal(4, found[1].stock)
    -- One alert for a family worn on both hands, none for other families.
    WowStub.state.bags = { [0] = { size = 1, [1] = { itemID = 2892, stackCount = 1 } } }
    assert.are.same({ "stock:instant" }, keys(alerts:Evaluate()))
  end)

  it("skips the stock rule when the equipped poison is not known", function()
    data.enchants = {}
    WowStub.state.bags = {}
    assert.are.same({}, alerts:Evaluate())
  end)

  it("lets a threshold of 0 turn a rule off", function()
    weapons(true, 60000, 1, 603, true, 3600000, 80, 603)
    WowStub.state.bags = {}
    settings:Set("alerts.expireMinutes", 0)
    settings:Set("alerts.charges", 0)
    settings:Set("alerts.stock", 0)
    assert.are.same({}, alerts:Evaluate())
  end)

  describe("Check", function()
    it("reports an alert once until its state changes", function()
      weapons(false, 0, 0, 0, true, 3600000, 80, 603)
      assert.are.same({ "mh:none" }, keys(alerts:Check("instance")))
      assert.are.same({}, alerts:Check("readycheck"))
      assert.are.same({}, alerts:Check("combatEnd"))
      healthy()
      assert.are.same({}, alerts:Check("combatEnd"))
      weapons(false, 0, 0, 0, true, 3600000, 80, 603)
      assert.are.same({ "mh:none" }, keys(alerts:Check("combatEnd")))
    end)

    it("reports only what is new when another alert joins", function()
      weapons(true, 60000, 80, 603, true, 3600000, 80, 603)
      assert.are.same({ "mh:expiring" }, keys(alerts:Check("instance")))
      weapons(true, 60000, 5, 603, true, 3600000, 80, 603)
      assert.are.same({ "mh:charges" }, keys(alerts:Check("instance")))
    end)

    it("reports nothing in combat and keeps the state", function()
      weapons(false, 0, 0, 0, true, 3600000, 80, 603)
      WowStub.state.inCombat = true
      assert.are.same({}, alerts:Check("combatEnd"))
      WowStub.state.inCombat = false
      assert.are.same({ "mh:none" }, keys(alerts:Check("combatEnd")))
    end)

    it("honours the trigger settings", function()
      weapons(false, 0, 0, 0, true, 3600000, 80, 603)
      settings:Set("alerts.triggers.readycheck", false)
      assert.are.same({}, alerts:Check("readycheck"))
      assert.are.same({}, alerts:Check("unknown"))
      assert.are.same({ "mh:none" }, keys(alerts:Check("instance")))
    end)

    it("reports again after a reset", function()
      weapons(false, 0, 0, 0, true, 3600000, 80, 603)
      alerts:Check("instance")
      alerts:Reset()
      assert.are.same({ "mh:none" }, keys(alerts:Check("instance")))
    end)

    it("checks when the combat state is unknown", function()
      WowStub.Remove("InCombatLockdown")
      weapons(false, 0, 0, 0, true, 3600000, 80, 603)
      assert.are.same({ "mh:none" }, keys(alerts:Check("instance")))
    end)
  end)
end)
