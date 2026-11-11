describe("Slash commands", function()
  local ns, messages

  local function run(input)
    for index = #messages, 1, -1 do
      messages[index] = nil
    end
    SlashCmdList.RAS(input)
    return messages
  end

  local function contains(list, text)
    for _, line in ipairs(list) do
      if line:find(text, 1, true) then
        return true
      end
    end
    return false
  end

  before_each(function()
    WowStub.Reset()
    WowStub.SetBag({ { 8928, 10 }, { 6948, 1 } })
    WowStub.state.names[8928] = "Instant Poison VI"
    ns = WowStub.LoadAddon()
    messages = WowStub.Messages()
  end)

  it("registers /ras and /rogueassistant", function()
    assert.equal("/ras", SLASH_RAS1)
    assert.equal("/rogueassistant", SLASH_RAS2)
  end)

  it("prints help with no command, and for an unknown one", function()
    assert.is_true(contains(run(""), "/ras unlock"))
    local out = run("dance")
    assert.is_true(contains(out, "Unknown command: dance"))
    assert.is_true(contains(out, "/ras warn"))
  end)

  it("unlocks, locks and resets the bar", function()
    assert.is_true(contains(run("unlock"), "Bar unlocked"))
    assert.is_true(ns.Bar.handle:IsShown())
    assert.is_true(contains(run("LOCK"), "Bar locked."))
    assert.is_false(ns.Bar.handle:IsShown())
    assert.is_true(contains(run("reset"), "default position"))
  end)

  it("refuses to unlock or reset in combat", function()
    WowStub.state.inCombat = true
    assert.is_true(contains(run("unlock"), "Not possible in combat"))
    assert.is_true(contains(run("reset"), "Not possible in combat"))
  end)

  it("sets the warning threshold and rejects bad values", function()
    assert.is_true(contains(run("warn 10"), "below 10 minutes"))
    assert.equal(10, RogueAssistantDB.warnMinutes)
    for _, bad in ipairs({ "warn", "warn -1", "warn 61", "warn 2.5", "warn abc" }) do
      assert.is_true(contains(run(bad), "Usage: /ras warn"), bad)
    end
    assert.equal(10, RogueAssistantDB.warnMinutes)
  end)

  it("prints the bag items with their kind", function()
    local out = run("debug bags")
    assert.is_true(contains(out, "8928 x 10, Instant Poison VI, poison"))
    assert.is_true(contains(out, "6948 x 1, ?, -"))
    WowStub.state.bags = {}
    assert.is_true(contains(run("debug bags"), "No items found"))
  end)

  it("prints the weapon enchants", function()
    RogueAssistantDB.enchants[625] = 8928
    WowStub.state.weapon = { true, 60000, 0, 625, WowStub.Secret, 0, 0, 0 }
    local out = run("debug weapon")
    assert.is_true(contains(out, "Main hand: active=true, ms=60000, charges=0, enchantID=625, itemID=8928"))
    assert.is_true(contains(out, "Off hand: active=secret"))
    _G.GetWeaponEnchantInfo = nil
    assert.is_true(contains(run("debug weapon"), "gave nothing"))
  end)

  it("prints every raw enchant value and the weapon tooltip lines, to measure poison plus stone", function()
    WowStub.state.weapon = { true, 60000, 40, 625, false, 0, 0, 0, true, 1800000, 0, WowStub.Secret }
    WowStub.state.tooltips[16] = { { "Bloodfang Dagger" }, { "Instant Poison VI (1 min)", "40 Charges" } }
    local out = run("debug weapon")
    assert.is_true(
      contains(out, "GetWeaponEnchantInfo (12): true, 60000, 40, 625, false, 0, 0, 0, true, 1800000, 0, <secret>")
    )
    assert.is_true(contains(out, "Main hand tooltip: Bloodfang Dagger"))
    assert.is_true(contains(out, "Main hand tooltip: Instant Poison VI (1 min) | 40 Charges"))
    assert.is_true(contains(out, "Off hand tooltip: unavailable"))
  end)

  it("answers in Spanish on a Spanish client", function()
    WowStub.Reset()
    WowStub.state.locale = "esES"
    WowStub.LoadAddon()
    messages = WowStub.Messages()
    assert.is_true(contains(run("lock"), "Barra bloqueada."))
  end)
end)
