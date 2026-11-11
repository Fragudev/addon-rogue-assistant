describe("Bar", function()
  local ns, state

  local function flyout(slot)
    return _G["RogueAssistantFlyout" .. slot]
  end

  local function weapon(slot)
    return _G["RogueAssistantWeapon" .. slot]
  end

  local function shownRows(slot)
    local items = {}
    for _, row in ipairs(flyout(slot).rows) do
      if row:IsShown() then
        items[#items + 1] = { row.itemID, row.count:GetText(), row:GetAttribute("item"), row.icon.desaturated }
      end
    end
    return items
  end

  before_each(function()
    WowStub.Reset()
    state = WowStub.state
    state.items[2000] = { classID = 2, subclassID = 4 } -- a mace
    WowStub.SetBag({ { 8928, 10 }, { 2871, 3 }, { 3241, 2 }, { 6948, 1 } })
    ns = WowStub.LoadAddon()
  end)

  it("builds both weapon buttons with hidden flyouts and a fresh saved table", function()
    assert.is_table(weapon(16))
    assert.is_table(weapon(17))
    assert.is_false(flyout(16):IsShown())
    assert.is_false(flyout(17):IsShown())
    assert.equal(2, RogueAssistantDB.version)
    assert.same({ "CENTER", UIParent, "CENTER", 0, -180 }, { ns.Bar.anchor:GetPoint() })
  end)

  it("lists the bag items that fit each weapon, strongest poison first", function()
    assert.same({
      { 8928, "10", "item:8928", false },
      { 2871, "3", "item:2871", false },
    }, shownRows(16))
    for _, row in ipairs(flyout(16).rows) do
      assert.equal(16, row:GetAttribute("target-slot"))
      assert.equal("item", row:GetAttribute("type"))
    end
  end)

  it("lists weightstones and not sharpening stones for a mace", function()
    state.equipment[17] = 2000
    WowStub.Fire("PLAYER_EQUIPMENT_CHANGED", 17, false)
    assert.same({
      { 8928, "10", "item:8928", false },
      { 3241, "2", "item:3241", false },
    }, shownRows(17))
  end)

  it("shows the empty text when nothing fits", function()
    state.equipment[17] = nil
    WowStub.Fire("PLAYER_EQUIPMENT_CHANGED", 17, true)
    assert.same({}, shownRows(17))
    assert.is_true(flyout(17).empty:IsShown())
    assert.is_false(flyout(16).empty:IsShown())
  end)

  it("toggles a flyout with a click and closes the other one, also in combat", function()
    state.inCombat = true
    WowStub.Click(weapon(16))
    assert.is_true(flyout(16):IsShown())
    WowStub.Click(weapon(17))
    assert.is_false(flyout(16):IsShown())
    assert.is_true(flyout(17):IsShown())
    WowStub.Click(weapon(17))
    assert.is_false(flyout(17):IsShown())
    assert.same({}, state.violations)
  end)

  it("applies the clicked item to its weapon slot and closes the flyout, also in combat", function()
    WowStub.Click(weapon(17))
    state.inCombat = true
    WowStub.Click(flyout(17).rows[1])
    assert.same({ { type = "item", item = "item:8928", slot = 17 } }, state.actions)
    assert.is_false(flyout(17):IsShown())
    assert.same({}, state.violations)
  end)

  it("applies on the mouse release whatever the key-down setting is", function()
    for _, keyDown in ipairs({ true, false }) do
      state.cvarUseKeyDown = keyDown
      WowStub.Click(flyout(16).rows[1])
    end
    assert.same({
      { type = "item", item = "item:8928", slot = 16 },
      { type = "item", item = "item:8928", slot = 16 },
    }, state.actions)
  end)

  it("stops a drag when combat starts and keeps where the bar was dropped", function()
    ns.Bar.SetUnlocked(true)
    ns.Bar.handle.scripts.OnDragStart()
    ns.Bar.anchor.points = { { "TOP", UIParent, "TOP", 10, -20 } }
    WowStub.Fire("PLAYER_REGEN_DISABLED")
    assert.is_false(ns.Bar.anchor.moving)
    assert.same({ point = "TOP", relativePoint = "TOP", x = 10, y = -20 }, RogueAssistantDB.position)
    state.inCombat = true
    ns.Bar.handle.scripts.OnDragStop()
    assert.same({}, state.violations)
  end)

  it("updates counts in combat and rebuilds the list when the fight ends", function()
    state.inCombat = true
    WowStub.SetBag({ { 2871, 3 } })
    WowStub.Fire("BAG_UPDATE_DELAYED")
    assert.same({
      { 8928, "0", "item:8928", true },
      { 2871, "3", "item:2871", false },
    }, shownRows(16))
    assert.same({}, state.violations)

    state.inCombat = false
    WowStub.Fire("PLAYER_REGEN_ENABLED")
    assert.same({ { 2871, "3", "item:2871", false } }, shownRows(16))
  end)

  it("shows the weapon icon with the time and charges of what is applied", function()
    WowStub.Click(flyout(16).rows[1])
    state.time = 1003
    state.weapon = { true, 1800000, 40, 625, false, 0, 0, 0 }
    WowStub.Update(0.3)
    local button = weapon(16)
    assert.equal("30m", button.rows[1].text:GetText())
    assert.equal("40", button.charges:GetText())
    assert.equal("weapon-1001", button.icon:GetTexture())
    assert.is_false(button.icon.desaturated)
    assert.is_false(button.glow:IsShown())
    assert.equal(8928, RogueAssistantDB.enchants[625])
  end)

  it("shows a poison row and a stone row with their icons and times", function()
    state.weapon = { true, 1800000, 40, 625, false, 0, 0, 0 }
    state.names[8928] = "Instant Poison VI"
    state.tooltips[16] = {
      { "Bloodfang Dagger" },
      { "Sharpened (+8 Damage) (25 min)" },
      { "Instant Poison VI (30 min)" },
    }
    WowStub.Update(0.3)
    local rows = weapon(16).rows
    assert.equal("Interface\\Icons\\Trade_BrewPoison", rows[1].icon:GetTexture())
    assert.equal("30m", rows[1].text:GetText())
    assert.is_true(rows[1].icon:IsShown())
    assert.equal("Interface\\Icons\\INV_Stone_SharpeningStone_01", rows[2].icon:GetTexture())
    assert.equal("25m", rows[2].text:GetText())
    assert.is_true(rows[2].icon:IsShown())
    assert.equal("40", weapon(16).charges:GetText())
  end)

  it("shows the poison and the weightstone measured on Forever", function()
    state.items[1001] = { classID = 2, subclassID = 4 }
    state.weapon = { true, 1669925, 60, 323, true, 1790515, 60, 323, false }
    state.tooltips[16] = {
      { "Rock on Stick" },
      { "One-Hand", "Mace" },
      { "Weighted +6 (30 min)" },
      { "Instant Poison (28 min) (60 Charges)" },
      { "Durability 81 / 90" },
    }
    WowStub.Update(0.3)
    local rows = weapon(16).rows
    assert.equal("Interface\\Icons\\Trade_BrewPoison", rows[1].icon:GetTexture())
    assert.equal("27m", rows[1].text:GetText())
    assert.equal("Interface\\Icons\\INV_Stone_SharpeningStone_01", rows[2].icon:GetTexture())
    assert.equal("30m", rows[2].text:GetText())
    assert.equal("60", weapon(16).charges:GetText())
  end)

  it("counts the seconds of a stone from the moment its tooltip minute drops", function()
    state.weapon = { true, 1669925, 60, 323, false, 0, 0, 0 }
    state.names[8928] = "Instant Poison VI"
    local function stone(minutes)
      state.tooltips[16] = { { "Rock on Stick" }, { "Weighted +6 (" .. minutes .. " min)" } }
    end
    local function stoneText()
      return weapon(16).rows[2].text:GetText()
    end
    stone(5)
    WowStub.Update(0.3)
    assert.equal("5:00", stoneText())
    state.time = state.time + 30
    WowStub.Update(0.3)
    assert.equal("4:30", stoneText())
    state.time = state.time + 50
    WowStub.Update(0.3)
    assert.equal("4:01", stoneText()) -- held until the tooltip says 4 min
    stone(4)
    WowStub.Update(0.3)
    assert.equal("4:00", stoneText())
    state.time = state.time + 12
    WowStub.Update(0.3)
    assert.equal("3:48", stoneText())
    stone(30) -- applied again
    WowStub.Update(0.3)
    assert.equal("30m", stoneText())
  end)

  it("shows a single stone row when only a stone is applied", function()
    state.weapon = { true, 600000, 0, 1643, false, 0, 0, 0 }
    WowStub.Update(0.3)
    local rows = weapon(16).rows
    assert.equal("Interface\\Icons\\INV_Stone_SharpeningStone_01", rows[1].icon:GetTexture())
    assert.equal("10m", rows[1].text:GetText())
    assert.is_false(rows[2].icon:IsShown())
    assert.equal("", rows[2].text:GetText())
  end)

  it("shows the weapon icon while the enchant item is not known", function()
    state.weapon = { true, 1800000, 0, 625, false, 0, 0, 0 }
    WowStub.Update(0.3)
    assert.equal("weapon-1001", weapon(16).icon:GetTexture())
    assert.equal("", weapon(16).charges:GetText())
  end)

  it("warns when a weapon has nothing or little time left", function()
    state.weapon = { true, 120000, 0, 625, false, 0, 0, 0 }
    WowStub.Update(0.3)
    assert.is_true(weapon(16).glow:IsShown())
    assert.is_false(weapon(16).missing:IsShown())
    assert.is_true(weapon(17).glow:IsShown())
    assert.is_true(weapon(17).missing:IsShown())
    assert.equal("", weapon(17).rows[1].text:GetText())
    assert.is_false(weapon(17).rows[1].icon:IsShown())
  end)

  it("does not warn for an empty off hand and shows the empty slot icon", function()
    state.equipment[17] = nil
    WowStub.Update(0.3)
    assert.is_false(weapon(17).glow:IsShown())
    assert.equal("Interface\\PaperDoll\\UI-PaperDoll-Slot-SecondaryHand", weapon(17).icon:GetTexture())
  end)

  it("reads the weapons only every tick", function()
    state.weapon = { true, 1800000, 0, 625, false, 0, 0, 0 }
    WowStub.Update(0.1)
    assert.equal("", weapon(16).rows[1].text:GetText())
    WowStub.Update(0.2)
    assert.equal("30m", weapon(16).rows[1].text:GetText())
  end)

  it("redraws on an inventory change of the player only", function()
    state.weapon = { true, 1800000, 0, 625, false, 0, 0, 0 }
    WowStub.Fire("UNIT_INVENTORY_CHANGED", "target")
    assert.equal("", weapon(16).rows[1].text:GetText())
    WowStub.Fire("UNIT_INVENTORY_CHANGED", "player")
    assert.equal("30m", weapon(16).rows[1].text:GetText())
  end)

  it("ignores ADDON_LOADED of other addons", function()
    _G.RogueAssistantDB = { version = 2, warnMinutes = 7, enchants = {} }
    WowStub.Fire("ADDON_LOADED", "OtherAddon")
    assert.equal(7, RogueAssistantDB.warnMinutes)
  end)

  it("shows no tooltip on hover", function()
    for _, slot in ipairs({ 16, 17 }) do
      assert.is_nil(weapon(slot).scripts.OnEnter)
      assert.is_nil(weapon(slot).scripts.OnLeave)
    end
  end)

  it("covers the buttons with a drag zone only while unlocked", function()
    local zone = ns.Bar.handle
    assert.is_false(zone:IsShown())
    WowStub.Click(weapon(16))
    assert.is_true(ns.Bar.SetUnlocked(true))
    assert.is_true(zone:IsShown())
    assert.is_false(flyout(16):IsShown())
    assert.equal("TOPLEFT", zone.points[1][1])
    assert.equal(ns.Bar.anchor, zone.points[1][2])
    assert.equal("BOTTOMRIGHT", zone.points[2][1])
    assert.equal(ns.Bar.anchor, zone.points[2][2])
    assert.is_true(zone:GetFrameLevel() > weapon(16):GetFrameLevel())
    assert.is_true(zone:GetFrameLevel() > weapon(17):GetFrameLevel())
    assert.is_true(ns.Bar.SetUnlocked(false))
    assert.is_false(zone:IsShown())
  end)

  it("moves, saves and resets its position", function()
    assert.is_true(ns.Bar.SetUnlocked(true))
    assert.is_true(ns.Bar.handle:IsShown())
    ns.Bar.handle.scripts.OnDragStart()
    assert.is_true(ns.Bar.anchor.moving)
    ns.Bar.anchor.points = { { "TOPLEFT", UIParent, "TOPLEFT", 50, -60 } }
    ns.Bar.handle.scripts.OnDragStop()
    assert.same({ point = "TOPLEFT", relativePoint = "TOPLEFT", x = 50, y = -60 }, RogueAssistantDB.position)
    assert.is_true(ns.Bar.ResetPosition())
    assert.is_nil(RogueAssistantDB.position)
    assert.same({ "CENTER", UIParent, "CENTER", 0, -180 }, { ns.Bar.anchor:GetPoint() })
  end)

  it("refuses to move or unlock in combat", function()
    state.inCombat = true
    assert.is_false(ns.Bar.SetUnlocked(true))
    assert.is_false(ns.Bar.ResetPosition())
    ns.Bar.handle.scripts.OnDragStart()
    assert.is_falsy(ns.Bar.anchor.moving)
  end)
end)

describe("Bar loaded in combat", function()
  before_each(function()
    WowStub.Reset()
  end)

  it("waits for the end of combat to build the bar, then restores the saved position", function()
    WowStub.state.inCombat = true
    _G.RogueAssistantDB = {
      version = 2,
      warnMinutes = 5,
      enchants = {},
      position = { point = "TOP", relativePoint = "TOP", x = 0, y = -50 },
    }
    local ns = WowStub.LoadAddon()
    assert.is_nil(_G.RogueAssistantWeapon16)
    WowStub.state.inCombat = false
    WowStub.Fire("PLAYER_REGEN_ENABLED")
    assert.is_table(_G.RogueAssistantWeapon16)
    assert.same({ "TOP", UIParent, "TOP", 0, -50 }, { ns.Bar.anchor:GetPoint() })
    assert.same({}, WowStub.state.violations)
  end)
end)
