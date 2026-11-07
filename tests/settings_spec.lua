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
    assert.are.equal("BOTTOM", settings:Get("poison.position").point)
    assert.are.same({}, settings:Get("tracker.groups"))
  end)

  it("fills the defaults of the movable elements", function()
    assert.are.same({ point = "TOP", relativePoint = "TOP", x = 0, y = -160 }, settings:Get("alerts.position"))
    assert.are.same({ point = "TOP", relativePoint = "BOTTOM", x = 0, y = 198 }, settings:Get("poison.statusPosition"))
    assert.is_true(settings:Get("poison.statusShown"))
    assert.are.equal("UP", settings:Get("poison.flyoutDirection"))
  end)

  it("validates and round-trips the alert banner and status positions", function()
    local bad = { { point = "TOP" }, { point = "TOP", relativePoint = "TOP", x = "1", y = 0 }, "TOP" }
    for _, path in ipairs({ "alerts.position", "poison.statusPosition" }) do
      local default = Settings.Default(path)
      for _, position in ipairs(bad) do
        assert.are.same({ false, "invalid" }, { settings:Set(path, position) })
        local parts = {}
        for part in path:gmatch("[^.]+") do
          parts[#parts + 1] = part
        end
        assert.are.same(default, Settings.New({ [parts[1]] = { [parts[2]] = position } }):Get(path))
      end
      local good = { point = "LEFT", relativePoint = "LEFT", x = 12, y = -3 }
      assert.is_true(settings:Set(path, good))
      assert.are.same(good, settings:Get(path))
      settings:Reset(path)
      assert.are.same(default, settings:Get(path))
    end
  end)

  it("validates the status switch and the flyout direction", function()
    assert.is_true(settings:Set("poison.statusShown", false))
    assert.is_false(settings:Get("poison.statusShown"))
    assert.is_false((settings:Set("poison.statusShown", "no")))
    for _, direction in ipairs({ "UP", "DOWN", "LEFT", "RIGHT" }) do
      assert.is_true(settings:Set("poison.flyoutDirection", direction))
      assert.are.equal(direction, settings:Get("poison.flyoutDirection"))
    end
    assert.are.same({ false, "invalid" }, { settings:Set("poison.flyoutDirection", "SIDEWAYS") })
    assert.are.same({ false, "invalid" }, { settings:Set("poison.flyoutDirection", 1) })
    assert.are.equal("RIGHT", settings:Get("poison.flyoutDirection"))
    assert.are.equal("UP", Settings.New({ poison = { flyoutDirection = "up" } }):Get("poison.flyoutDirection"))
    assert.is_true(Settings.New({ poison = { statusShown = false } }):Get("poison.statusShown") == false)
  end)

  it("replaces an invalid poison position with the default", function()
    local bad = {
      { point = "TOP" },
      { point = 1, relativePoint = "TOP", x = 0, y = 0 },
      { point = "TOP", relativePoint = {}, x = 0, y = 0 },
      { point = "TOP", relativePoint = "TOP", x = "1", y = 0 },
      { point = "TOP", relativePoint = "TOP", x = 0, y = 0 / 0 },
      { point = "TOP", relativePoint = "TOP", x = 99999, y = 0 },
    }
    for _, position in ipairs(bad) do
      local loaded = Settings.New({ poison = { position = position } })
      assert.are.same({ point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = 200 }, loaded:Get("poison.position"))
      assert.are.same({ false, "invalid" }, { settings:Set("poison.position", position) })
    end
    local good = { point = "TOP", relativePoint = "TOP", x = 3, y = -4 }
    assert.are.same(good, Settings.New({ poison = { position = good } }):Get("poison.position"))
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

describe("Settings tracker groups", function()
  local ns, base

  local function group(overrides)
    local g = { id = "g", kind = "buff", entries = { { spellId = 1784 } } }
    for key, value in pairs(overrides or {}) do
      g[key] = value
    end
    return g
  end

  before_each(function()
    WowStub.Reset()
    ns = dofile("tests/support/loader.lua").Load({ "Core/Constants.lua", "Domain/Settings.lua" })
    base = ns.Settings.New({})
  end)

  it("accepts a well-formed list", function()
    local full = group({
      title = "T",
      titleKey = "k",
      iconSize = 40,
      growth = "UP",
      mode = "bars",
      showWhenMissing = "dim",
      position = { point = "CENTER", relativePoint = "CENTER", x = 1, y = 2 },
      entries = {
        { spellId = 1, ids = { 1, 2 }, stacks = true, byName = true, always = true, custom = true, source = "s" },
        { name = "Foo" },
      },
    })
    assert.is_true(base:Set("tracker.groups", { full, group({ id = "h" }) }))
  end)

  local bad = {
    ["duplicate ids"] = function()
      return { group(), group() }
    end,
    ["empty id"] = function()
      return { group({ id = "" }) }
    end,
    ["non-table group"] = function()
      return { "x" }
    end,
    ["unknown kind"] = function()
      return { group({ kind = "nope" }) }
    end,
    ["entries not a table"] = function()
      return { group({ entries = 1 }) }
    end,
    ["too many entries"] = function()
      local entries = {}
      for index = 1, 41 do
        entries[index] = { spellId = index }
      end
      return { group({ entries = entries }) }
    end,
    ["non-string title"] = function()
      return { group({ title = 1 }) }
    end,
    ["non-string titleKey"] = function()
      return { group({ titleKey = 1 }) }
    end,
    ["entry without id or name"] = function()
      return { group({ entries = { {} } }) }
    end,
    ["entry with both id and name"] = function()
      return { group({ entries = { { spellId = 1, name = "a" } } }) }
    end,
    ["entry not a table"] = function()
      return { group({ entries = { 5 } }) }
    end,
    ["fractional spell id"] = function()
      return { group({ entries = { { spellId = 1.5 } } }) }
    end,
    ["empty name"] = function()
      return { group({ entries = { { name = "" } } }) }
    end,
    ["ids not a table"] = function()
      return { group({ entries = { { spellId = 1, ids = 1 } } }) }
    end,
    ["bad rank id"] = function()
      return { group({ entries = { { spellId = 1, ids = { "x" } } } }) }
    end,
    ["non-boolean flag"] = function()
      return { group({ entries = { { spellId = 1, stacks = "yes" } } }) }
    end,
    ["non-string source"] = function()
      return { group({ entries = { { spellId = 1, source = 1 } } }) }
    end,
    ["icon size out of range"] = function()
      return { group({ iconSize = 1 }) }
    end,
    ["unknown growth"] = function()
      return { group({ growth = "X" }) }
    end,
    ["unknown mode"] = function()
      return { group({ mode = "X" }) }
    end,
    ["unknown missing mode"] = function()
      return { group({ showWhenMissing = "X" }) }
    end,
    ["position not a table"] = function()
      return { group({ position = 1 }) }
    end,
    ["position without point"] = function()
      return { group({ position = { relativePoint = "A", x = 1, y = 1 } }) }
    end,
    ["position out of range"] = function()
      return { group({ position = { point = "A", relativePoint = "A", x = 1e9, y = 1 } }) }
    end,
    ["too many groups"] = function()
      local groups = {}
      for index = 1, 13 do
        groups[index] = group({ id = "g" .. index })
      end
      return groups
    end,
  }

  for name, build in pairs(bad) do
    it("rejects " .. name, function()
      assert.are.same({ false, "invalid" }, { base:Set("tracker.groups", build()) })
      assert.are.same({}, base:Get("tracker.groups"))
    end)
  end

  it("replaces an invalid saved list when the settings load", function()
    local root = { tracker = { groups = { group({ kind = "nope" }) } } }
    local loaded = ns.Settings.New(root)
    assert.are.same({}, loaded:Get("tracker.groups"))
  end)
end)
