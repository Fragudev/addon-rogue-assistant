local Loader = dofile("tests/support/loader.lua")

describe("TrackerFrames", function()
  local ns, settings, model, bus, frames, root

  local function slotOf(groupId, index)
    return frames.groups[groupId].slots[index or 1]
  end

  local function know(...)
    WowStub.state.knownSpells = {}
    for _, id in ipairs({ ... }) do
      WowStub.state.knownSpells[id] = true
    end
  end

  local function frame()
    frames:OnUpdate(0.016)
  end

  before_each(function()
    WowStub.Reset()
    ns = Loader.Full({ "Core/Init.lua", "Commands/Slash.lua" })
    root = {}
    settings = ns.Settings.New(root)
    model = ns.TrackerModel.New(settings)
    bus = ns.EventBus.New()
    know(2983, 13750)
    frames = ns.TrackerFrames.New({ model = model, bus = bus })
  end)

  describe("startup", function()
    it("builds one plain container per group and a driver for the events", function()
      frames:Start()
      assert.are.equal(3, #(function()
        local list = {}
        for _, record in pairs(frames.groups) do
          list[#list + 1] = record
        end
        return list
      end)())
      local container = frames.groups.essentials.container
      assert.are.equal("RogueAssistantTracker_essentials", container.name)
      assert.is_false(container.protected)
      for _, event in ipairs({
        "SPELL_UPDATE_COOLDOWN",
        "SPELL_UPDATE_CHARGES",
        "UNIT_AURA",
        "PLAYER_TARGET_CHANGED",
        "SPELLS_CHANGED",
        "PLAYER_REGEN_ENABLED",
        "PLAYER_REGEN_DISABLED",
      }) do
        assert.is_true(frames.driver.events[event], event)
      end
      assert.is_nil(frames.driver.events.COMBAT_LOG_EVENT_UNFILTERED)
    end)

    it("listens to UNIT_AURA for the player and the target only", function()
      frames:Start()
      assert.are.same({ "player", "target" }, frames.driver.unitEvents.UNIT_AURA)
    end)

    it("falls back to the plain UNIT_AURA event when the unit event is refused", function()
      local create = CreateFrame
      WowStub.Set("CreateFrame", function(...)
        local created = create(...)
        function created:RegisterUnitEvent()
          error("refused")
        end
        return created
      end)
      frames:Start()
      assert.is_true(frames.driver.events.UNIT_AURA)
      assert.is_nil(frames.driver.unitEvents)
      WowStub.Fire(frames.driver, "UNIT_AURA", "focus")
    end)

    it("registers through the startup list and respects ns.disabled", function()
      ns.settings, ns.bus = settings, bus
      ns.disabled = "not_rogue"
      ns.Startup.Run()
      assert.is_nil(ns.trackerFrames)
      ns.disabled = nil
      ns.Startup.Run()
      assert.is_table(ns.trackerFrames)
      assert.is_table(ns.trackerModel)
      assert.is_table(ns.trackerFrames.driver)
    end)

    it("starts in combat when the client says so", function()
      WowStub.state.inCombat = true
      frames:Start()
      assert.is_true(frames.inCombat)
    end)
  end)

  describe("aura scans", function()
    it("scans each unit and filter once per refresh across all groups", function()
      frames:Start()
      local counts = {}
      local real = frames.platform
      frames.platform = setmetatable({
        GetAuras = function(unit, filter)
          local key = unit .. "|" .. filter
          counts[key] = (counts[key] or 0) + 1
          return real.GetAuras(unit, filter)
        end,
      }, { __index = real })
      frames:Refresh()
      for key, count in pairs(counts) do
        assert.are.equal(1, count, key)
      end
    end)
  end)

  describe("mouse", function()
    it("lets clicks through the icons while locked and takes them while unlocked", function()
      frames:Start()
      local slot = slotOf("essentials")
      assert.is_false(slot.mouseEnabled)
      frames:SetUnlocked(true)
      assert.is_true(slot.mouseEnabled)
      frames:SetUnlocked(false)
      assert.is_false(slot.mouseEnabled)
    end)

    it("uses a managed status bar texture", function()
      frames:Start()
      local slot = slotOf("essentials")
      assert.is_string(slot.bar.statusBarTexture)
      assert.is_nil(slot.barFill)
    end)
  end)

  describe("updates", function()
    before_each(function()
      frames:Start()
    end)

    it("coalesces any number of events into one redraw on the next frame", function()
      local before = frames.refreshes
      WowStub.Fire(frames.driver, "SPELL_UPDATE_COOLDOWN")
      WowStub.Fire(frames.driver, "SPELL_UPDATE_CHARGES")
      WowStub.Fire(frames.driver, "UNIT_AURA", "player")
      WowStub.Fire(frames.driver, "UNIT_AURA", "target")
      WowStub.Fire(frames.driver, "PLAYER_TARGET_CHANGED")
      WowStub.Fire(frames.driver, "SPELLS_CHANGED")
      assert.are.equal(before, frames.refreshes)
      frame()
      assert.are.equal(before + 1, frames.refreshes)
      frame()
      assert.are.equal(before + 1, frames.refreshes)
    end)

    it("ignores the auras of other units", function()
      local before = frames.refreshes
      WowStub.Fire(frames.driver, "UNIT_AURA", "focus")
      WowStub.Fire(frames.driver, "UNIT_AURA", "party1")
      frame()
      assert.are.equal(before, frames.refreshes)
    end)

    it("follows the combat state and changes the out-of-combat alpha", function()
      model:SetLayout("essentials", "alphaOutOfCombat", 0.3)
      frames:Refresh()
      local container = frames.groups.essentials.container
      assert.are.equal(0.3, container.alpha)
      WowStub.Fire(frames.driver, "PLAYER_REGEN_DISABLED")
      frame()
      assert.is_true(frames.inCombat)
      assert.are.equal(1, container.alpha)
      WowStub.Fire(frames.driver, "PLAYER_REGEN_ENABLED")
      frame()
      assert.are.equal(0.3, container.alpha)
    end)

    it("redraws the bars on a timer without a full redraw", function()
      model:SetLayout("essentials", "mode", "bars")
      WowStub.state.cooldowns[2983] = { startTime = 990, duration = 30, isEnabled = true }
      frames:Refresh()
      local refreshes = frames.refreshes
      WowStub.state.time = 1005
      frames:OnUpdate(0.05)
      assert.are.equal(refreshes, frames.refreshes)
      frames:OnUpdate(0.06)
      local slot = slotOf("essentials")
      assert.are.equal(15, slot.bar.value)
      assert.are.equal(30, slot.bar.maxValue)
      assert.are.equal("15", slot.barText.text)
    end)
  end)

  describe("painting", function()
    before_each(function()
      frames:Start()
    end)

    it("draws the visible entries of each group", function()
      assert.are.equal(2, frames.groups.essentials.count)
      assert.are.equal(100000 + 2983, slotOf("essentials", 1).icon.texture)
      assert.is_true(slotOf("essentials", 1).shown)
      assert.is_nil(frames.groups.essentials.slots[3])
    end)

    it("sets a readable cooldown on the widget and glows when ready", function()
      WowStub.state.cooldowns[2983] = { startTime = 990, duration = 30, isEnabled = true }
      WowStub.state.cooldowns[13750] = { startTime = 0, duration = 0, isEnabled = true }
      frames:Refresh()
      local sprint, rush = slotOf("essentials", 1), slotOf("essentials", 2)
      assert.are.same({ start = 990, duration = 30 }, sprint.cooldown.cooldown)
      assert.is_false(sprint.glow.shown)
      assert.is_nil(rush.cooldown.cooldown)
      assert.is_true(rush.glow.shown)
      assert.is_false(sprint.hiddenMark.shown)
      assert.is_false(sprint.cooldown.hideNumbers)
    end)

    it("hands a secret cooldown to the widget as a duration object without touching it", function()
      WowStub.state.cooldowns[2983] = { startTime = WowStub.Secret, duration = WowStub.Secret }
      WowStub.state.cooldownObjects[2983] = WowStub.Secret
      frames:Refresh()
      local slot = slotOf("essentials", 1)
      assert.are.equal(WowStub.Secret, slot.cooldown.durationObject)
      assert.is_false(slot.glow.shown)
      assert.is_false(slot.hiddenMark.shown)
      assert.are.equal(WowStub.Secret, slot.state.durationObject)
      assert.is_nil(slot.state.start)
    end)

    it("shows the hidden mark when there is nothing safe to show", function()
      WowStub.state.cooldowns[2983] = { startTime = WowStub.Secret, duration = WowStub.Secret }
      WowStub.Remove("C_Spell.GetSpellCooldownDuration")
      frames:Refresh()
      local slot = slotOf("essentials", 1)
      assert.is_true(slot.hiddenMark.shown)
      assert.are.equal(0.6, slot.alpha)
      assert.are.equal("?", slot.hiddenMark.text)
      assert.is_nil(slot.cooldown.cooldown)
      assert.is_nil(slot.cooldown.durationObject)
    end)

    it("shows the hidden mark when the widget refuses the duration object", function()
      WowStub.state.cooldowns[2983] = { startTime = WowStub.Secret, duration = WowStub.Secret }
      WowStub.state.cooldownObjectFails = true
      frames:Refresh()
      assert.is_true(slotOf("essentials", 1).hiddenMark.shown)
    end)

    it("shows charges and clears the text otherwise", function()
      WowStub.state.charges[2983] = { currentCharges = 2, maxCharges = 3 }
      frames:Refresh()
      assert.are.equal("2", slotOf("essentials", 1).count.text)
      assert.are.equal("", slotOf("essentials", 2).count.text)
    end)

    it("shows aura stacks, a secret stack text and a glow while an aura is active", function()
      know(1784, 5171)
      WowStub.state.auras.player = {
        { spellId = 1784, name = "Stealth", duration = 0, expirationTime = 0 },
      }
      model:AddEntry("buffs", 777)
      model:Group("buffs").entries[#model:Group("buffs").entries].stacks = true
      WowStub.state.auras.player[2] = {
        spellId = 777,
        name = "X",
        duration = WowStub.Secret,
        expirationTime = WowStub.Secret,
        applications = WowStub.Secret,
        auraInstanceID = 4,
      }
      WowStub.state.auraDurations[4] = WowStub.DurationObject("aura")
      WowStub.state.auraCounts[4] = WowStub.Secret
      frames:Refresh()
      local stealth, custom = slotOf("buffs", 1), slotOf("buffs", 2)
      assert.is_true(stealth.glow.shown)
      assert.are.equal(WowStub.Secret, custom.count.text)
      assert.are.equal(WowStub.state.auraDurations[4], custom.cooldown.durationObject)
    end)

    it("dims a missing aura when the group dims", function()
      know(1784)
      model:SetLayout("buffs", "showWhenMissing", "dim")
      frames:Refresh()
      local slot = slotOf("buffs", 1)
      assert.are.equal(0.4, slot.alpha)
      assert.is_true(slot.shown)
      model:SetLayout("buffs", "showWhenMissing", "hide")
      frames:Refresh()
      assert.is_false(frames.groups.buffs.container.shown)
    end)

    it("falls back to an icon for a bar entry that has no readable numbers", function()
      model:SetLayout("essentials", "mode", "bars")
      WowStub.state.cooldowns[2983] = { startTime = 990, duration = 30, isEnabled = true }
      WowStub.state.cooldowns[13750] = { startTime = WowStub.Secret, duration = WowStub.Secret }
      WowStub.state.cooldownObjects[13750] = WowStub.Secret
      frames:Refresh()
      assert.is_true(slotOf("essentials", 1).bar.shown)
      assert.is_false(slotOf("essentials", 2).bar.shown)
      assert.are.equal(36 * 4, slotOf("essentials", 1).width)
    end)

    it("hides a bar whose timer stops being readable", function()
      model:SetLayout("essentials", "mode", "bars")
      WowStub.state.cooldowns[2983] = { startTime = 990, duration = 30, isEnabled = true }
      frames:Refresh()
      local slot = slotOf("essentials", 1)
      slot.state = { durationObject = {} }
      frames:UpdateBars()
      assert.is_false(slot.bar.shown)
      assert.is_false(slot.barActive)
    end)

    it("applies scale, size and the growth direction", function()
      model:SetLayout("essentials", "iconSize", 40)
      model:SetLayout("essentials", "scale", 1.5)
      model:SetLayout("essentials", "growth", "DOWN")
      model:SetLayout("essentials", "spacing", 0)
      frames:Refresh()
      local container = frames.groups.essentials.container
      assert.are.equal(1.5, container.scale)
      assert.are.equal(40, container.width)
      assert.are.equal(80, container.height)
      assert.are.same({ "TOPLEFT", container, "TOPLEFT", 0, -40 }, slotOf("essentials", 2).points[1])
    end)

    it("hides spare slots when entries disappear and an empty group while locked", function()
      know(2983)
      frames:Refresh()
      assert.is_false(slotOf("essentials", 2).shown)
      know()
      model:Group("essentials").entries = {}
      frames:Refresh()
      assert.is_false(frames.groups.essentials.container.shown)
      frames:SetUnlocked(true)
      assert.is_true(frames.groups.essentials.container.shown)
    end)

    it("shows and hides the tooltip", function()
      WowStub.Set("GameTooltip", {
        SetOwner = spy.new(function() end),
        SetText = spy.new(function() end),
        AddLine = spy.new(function() end),
        Show = spy.new(function() end),
        Hide = spy.new(function() end),
      })
      local slot = slotOf("essentials", 1)
      slot.scripts.OnEnter()
      assert.spy(GameTooltip.SetText).was.called_with(GameTooltip, "Spell2983")
      assert.spy(GameTooltip.AddLine).was_not.called()
      slot.state.hidden = true
      slot.scripts.OnEnter()
      assert.spy(GameTooltip.AddLine).was.called(1)
      slot.scripts.OnLeave()
      assert.spy(GameTooltip.Hide).was.called(1)
      slot.state = nil
      slot.scripts.OnEnter()
      assert.spy(GameTooltip.SetOwner).was.called(2)
    end)
  end)

  describe("unlock and move", function()
    before_each(function()
      frames:Start()
    end)

    it("shows a labelled drag handle per group while unlocked", function()
      local handle = frames.groups.essentials.handle
      assert.is_false(handle.shown)
      assert.are.equal("Essentials", handle.label.text)
      bus:Publish("layout.unlock")
      assert.is_true(frames.unlocked)
      for _, record in pairs(frames.groups) do
        assert.is_true(record.handle.shown)
        assert.are.equal(1, record.container.alpha)
      end
      bus:Publish("layout.lock")
      assert.is_false(frames.unlocked)
      assert.is_false(handle.shown)
    end)

    it("saves the position of a group after a drag", function()
      bus:Publish("layout.unlock")
      local record = frames.groups.buffs
      record.handle.scripts.OnDragStart()
      assert.is_true(record.container.moving)
      record.container:ClearAllPoints()
      record.container:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 100, 200)
      record.handle.scripts.OnDragStop()
      assert.is_false(record.container.moving)
      assert.are.same(
        { point = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = 100, y = 200 },
        model:Group("buffs").position
      )
      assert.are.same(
        { point = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = 100, y = 200 },
        root.tracker.groups[2].position
      )
      -- Another group is untouched.
      assert.are_not.equal(100, model:Group("essentials").position.x)
    end)

    it("does not let the layout fight a drag in progress", function()
      bus:Publish("layout.unlock")
      local record = frames.groups.buffs
      record.handle.scripts.OnDragStart()
      record.container:ClearAllPoints()
      record.container:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 5, 6)
      frames:Refresh()
      assert.are.equal(5, record.container.points[1][4])
    end)

    it("ignores drags while locked and stray drag events", function()
      local record = frames.groups.buffs
      record.handle.scripts.OnDragStart()
      assert.is_falsy(record.container.moving)
      record.handle.scripts.OnDragStop()
      frames:OnDragStart("nope")
      frames:OnDragStop("nope")
      bus:Publish("layout.unlock")
      record.handle.scripts.OnDragStart()
      record.container.points = {}
      record.handle.scripts.OnDragStop()
      assert.are.equal("CENTER", model:Group("buffs").position.point)
    end)

    it("restores the saved positions on the next start", function()
      model:SetPosition("buffs", { point = "TOP", relativePoint = "TOP", x = 7, y = -8 })
      local again = ns.TrackerFrames.New({ model = model, bus = ns.EventBus.New() })
      again:Start()
      assert.are.same({ "TOP", UIParent, "TOP", 7, -8 }, again.groups.buffs.container.points[1])
    end)
  end)
end)
