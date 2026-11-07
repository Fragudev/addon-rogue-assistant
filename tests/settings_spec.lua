local Loader = dofile("tests/support/loader.lua")

describe("Settings", function()
  local Settings, root, settings

  before_each(function()
    Settings = Loader.Load({ "Core/Constants.lua", "Domain/Settings.lua" }).Settings
    root = {}
    settings = Settings.New(root)
  end)

  it("fills the defaults", function()
    assert.are.equal(5, settings:Get("alerts.expireMinutes"))
    assert.are.equal(20, settings:Get("alerts.charges"))
    assert.are.equal(5, settings:Get("alerts.stock"))
    assert.is_true(settings:Get("alerts.triggers.instance"))
    assert.is_true(settings:Get("alerts.triggers.readycheck"))
    assert.is_true(settings:Get("alerts.triggers.combatEnd"))
    assert.are.equal(1, settings:Get("poison.scale"))
    assert.is_true(settings:Get("poison.locked"))
    assert.are.equal("CENTER", settings:Get("poison.position").point)
    assert.are.same({}, settings:Get("tracker.groups"))
  end)

  it("keeps valid saved values and replaces invalid ones", function()
    local saved = { alerts = { stock = 9, charges = "many" }, poison = { scale = 99 } }
    local loaded = Settings.New(saved)
    assert.are.equal(9, loaded:Get("alerts.stock"))
    assert.are.equal(20, loaded:Get("alerts.charges"))
    assert.are.equal(1, loaded:Get("poison.scale"))
  end)

  it("replaces a non-table parent", function()
    local loaded = Settings.New({ alerts = 5 })
    assert.are.equal(5, loaded:Get("alerts.expireMinutes"))
  end)

  it("sets typed values within bounds", function()
    assert.is_true(settings:Set("alerts.stock", 12))
    assert.are.equal(12, settings:Get("alerts.stock"))
    assert.is_true(settings:Set("poison.locked", false))
    assert.is_true(settings:Set("poison.scale", 1.5))
    assert.is_true(settings:Set("poison.position", { point = "TOP", relativePoint = "TOP", x = 1, y = 2 }))
    assert.are.equal(12, root.alerts.stock)
  end)

  it("rejects unknown keys, wrong types and out-of-bounds values", function()
    local ok, reason = settings:Set("nope", 1)
    assert.is_false(ok)
    assert.are.equal("unknown", reason)
    ok, reason = settings:Set("alerts.stock", "3")
    assert.is_false(ok)
    assert.are.equal("invalid", reason)
    assert.is_false((settings:Set("poison.scale", 0.1)))
    assert.is_false((settings:Set("poison.scale", 10)))
    assert.is_false((settings:Set("poison.scale", 0 / 0)))
    assert.are.equal(5, settings:Get("alerts.stock"))
  end)

  it("gives nil for an unknown key and a missing parent", function()
    assert.is_nil(settings:Get("nope"))
    root.alerts = nil
    assert.is_nil(settings:Get("alerts.stock"))
  end)

  it("resets one key or all keys", function()
    settings:Set("alerts.stock", 50)
    settings:Set("poison.scale", 2)
    assert.is_true(settings:Reset("alerts.stock"))
    assert.are.equal(5, settings:Get("alerts.stock"))
    assert.are.equal(2, settings:Get("poison.scale"))
    assert.is_true(settings:Reset())
    assert.are.equal(1, settings:Get("poison.scale"))
    assert.is_false(settings:Reset("nope"))
  end)

  it("gives independent copies of table defaults", function()
    local position = Settings.Default("poison.position")
    position.x = 999
    assert.are.equal(0, Settings.Default("poison.position").x)
    settings:Reset("poison.position")
    settings:Get("poison.position").x = 5
    settings:Reset("poison.position")
    assert.are.equal(0, settings:Get("poison.position").x)
    assert.is_nil(Settings.Default("nope"))
  end)
end)
