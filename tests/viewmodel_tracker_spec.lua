local Loader = dofile("tests/support/loader.lua")

describe("ViewModelTracker", function()
  local ns, VM, P

  local function cooldown(id, extra)
    local entry = { spellId = id, kind = "cooldown", source = "t" }
    for key, value in pairs(extra or {}) do
      entry[key] = value
    end
    return entry
  end

  local function aura(kind, id, extra)
    local entry = { spellId = id, kind = kind, source = "t" }
    for key, value in pairs(extra or {}) do
      entry[key] = value
    end
    return entry
  end

  local function player(auras)
    WowStub.state.auras.player = auras
  end

  before_each(function()
    WowStub.Reset()
    ns = Loader.Full({ "Core/Init.lua", "Commands/Slash.lua" })
    VM = ns.ViewModelTracker
    P = ns.Platform
    WowStub.state.knownSpells = {}
  end)

  describe("cooldowns", function()
    it("shows a readable cooldown with its numbers and no ready flag", function()
      WowStub.state.cooldowns[5] = { startTime = 100, duration = 30, isEnabled = true }
      local state = VM.Entry(cooldown(5), { platform = P })
      assert.are.equal(100, state.start)
      assert.are.equal(30, state.duration)
      assert.is_true(state.active)
      assert.is_false(state.ready)
      assert.is_nil(state.durationObject)
      assert.is_falsy(state.hidden)
      assert.are.equal("Spell5", state.name)
      assert.are.equal(100005, state.icon)
    end)

    it("is ready when the readable cooldown is zero or only the global cooldown", function()
      WowStub.state.cooldowns[5] = { startTime = 0, duration = 0, isEnabled = true }
      local state = VM.Entry(cooldown(5), { platform = P })
      assert.is_true(state.ready)
      assert.is_false(state.active)
      assert.is_nil(state.start)
      WowStub.state.cooldowns[5] = { startTime = 99, duration = 1.5, isEnabled = true }
      assert.is_true(VM.Entry(cooldown(5), { platform = P }).ready)
    end)

    it("uses the duration object when the numbers are secret and never claims ready", function()
      local object = WowStub.DurationObject("cd")
      WowStub.state.cooldowns[5] = { startTime = WowStub.Secret, duration = WowStub.Secret, isEnabled = WowStub.Secret }
      WowStub.state.cooldownObjects[5] = object
      local state = VM.Entry(cooldown(5), { platform = P })
      assert.are.equal(object, state.durationObject)
      assert.is_nil(state.start)
      assert.is_false(state.ready)
      assert.is_nil(state.active)
      assert.is_falsy(state.hidden)
    end)

    it("accepts a secret duration object and only tests it for nil", function()
      WowStub.state.cooldowns[5] = { startTime = WowStub.Secret, duration = WowStub.Secret }
      WowStub.state.cooldownObjects[5] = WowStub.Secret
      local state = VM.Entry(cooldown(5), { platform = P })
      assert.are.equal(WowStub.Secret, state.durationObject)
      assert.is_false(state.ready)
    end)

    it("is hidden when the numbers are secret and no duration object exists", function()
      WowStub.state.cooldowns[5] = { startTime = WowStub.Secret, duration = WowStub.Secret }
      WowStub.Remove("C_Spell.GetSpellCooldownDuration")
      local state = VM.Entry(cooldown(5), { platform = P })
      assert.is_true(state.hidden)
      assert.is_false(state.ready)
      assert.is_nil(state.start)
      assert.is_nil(state.durationObject)
    end)

    it("is hidden when the cooldown API is missing altogether", function()
      WowStub.Remove("C_Spell.GetSpellCooldown")
      WowStub.Remove("GetSpellCooldown")
      WowStub.Remove("C_Spell.GetSpellCooldownDuration")
      assert.is_true(VM.Entry(cooldown(5), { platform = P }).hidden)
    end)

    it("shows readable charges as stacks and is ready while one is left", function()
      WowStub.state.cooldowns[5] = { startTime = 100, duration = 30, isEnabled = true }
      WowStub.state.charges[5] = { currentCharges = 1, maxCharges = 2 }
      local state = VM.Entry(cooldown(5), { platform = P })
      assert.are.equal(1, state.stacks)
      assert.are.equal(2, state.maxCharges)
      assert.is_true(state.ready)
      WowStub.state.charges[5] = { currentCharges = 0, maxCharges = 2 }
      state = VM.Entry(cooldown(5), { platform = P })
      assert.are.equal(0, state.stacks)
      assert.is_false(state.ready)
    end)

    it("keeps secret charges unknown", function()
      WowStub.state.cooldowns[5] = { startTime = 100, duration = 30, isEnabled = true }
      WowStub.state.charges[5] = { currentCharges = WowStub.Secret, maxCharges = 2 }
      local state = VM.Entry(cooldown(5), { platform = P })
      assert.is_nil(state.stacks)
      assert.are.equal(2, state.maxCharges)
      assert.is_false(state.ready)
    end)

    it("ignores a single-charge spell", function()
      WowStub.state.charges[5] = { currentCharges = 1, maxCharges = 1 }
      assert.is_nil(VM.Entry(cooldown(5), { platform = P }).maxCharges)
    end)

    it("asks about the highest rank the player knows", function()
      WowStub.state.knownSpells = { [1] = true, [2] = true }
      assert.are.equal(2, VM.ActiveId(cooldown(1, { ids = { 1, 2, 3 } }), P))
      WowStub.state.knownSpells = {}
      assert.are.equal(1, VM.ActiveId(cooldown(1, { ids = { 1, 2, 3 } }), P))
    end)

    it("identifies an entry typed by name", function()
      local state = VM.Entry({ name = "Foo", kind = "cooldown" }, { platform = P })
      assert.are.equal("Foo", state.name)
      assert.are.equal("Foo", state.key)
      assert.are.equal(300000, state.icon)
    end)

    it("defaults to the shared platform", function()
      assert.is_table(VM.Entry(cooldown(5)))
    end)
  end)

  describe("auras", function()
    it("shows an active aura with its readable timer and stacks", function()
      player({
        { spellId = 5, name = "X", duration = 10, expirationTime = 1015, applications = 3, auraInstanceID = 9 },
      })
      local state = VM.Entry(aura("buff", 5, { stacks = true }), { platform = P })
      assert.is_true(state.active)
      assert.are.equal(1005, state.start)
      assert.are.equal(10, state.duration)
      assert.are.equal(3, state.stacks)
      assert.is_nil(state.durationObject)
      assert.is_nil(state.ready)
    end)

    it("leaves out the timer of a permanent aura and the stacks of one application", function()
      player({ { spellId = 5, name = "X", duration = 0, expirationTime = 0, applications = 1 } })
      local state = VM.Entry(aura("buff", 5, { stacks = true }), { platform = P })
      assert.is_true(state.active)
      assert.is_nil(state.start)
      assert.is_nil(state.stacks)
    end)

    it("matches by any rank id and by name", function()
      player({ { spellId = 6774, name = "Slice and Dice" } })
      assert.is_true(VM.Entry(aura("buff", 5171, { ids = { 5171, 6774 } }), { platform = P }).active)
      player({ { spellId = 99, name = "Spell5" } })
      assert.is_true(VM.Entry(aura("buff", 5, { byName = true }), { platform = P }).active)
      assert.is_false(VM.Entry(aura("buff", 5), { platform = P }).active)
    end)

    it("uses the aura duration object and the display count when the fields are secret", function()
      local object = WowStub.DurationObject("aura")
      player({
        {
          spellId = 5,
          name = "X",
          duration = WowStub.Secret,
          expirationTime = WowStub.Secret,
          applications = WowStub.Secret,
          auraInstanceID = 9,
        },
      })
      WowStub.state.auraDurations[9] = object
      WowStub.state.auraCounts[9] = WowStub.Secret
      local state = VM.Entry(aura("buff", 5, { stacks = true }), { platform = P })
      assert.is_true(state.active)
      assert.are.equal(object, state.durationObject)
      assert.are.equal(WowStub.Secret, state.stacksText)
      assert.is_nil(state.start)
      assert.is_nil(state.stacks)
    end)

    it("is active without a timer when nothing safe exists for it", function()
      player({ { spellId = 5, duration = WowStub.Secret, expirationTime = WowStub.Secret } })
      local state = VM.Entry(aura("buff", 5), { platform = P })
      assert.is_true(state.active)
      assert.is_nil(state.durationObject)
      assert.is_nil(state.start)
    end)

    it("is hidden when the auras exist but their identity is secret", function()
      player({ { spellId = WowStub.Secret, name = WowStub.Secret, duration = WowStub.Secret } })
      local state = VM.Entry(aura("buff", 5), { platform = P })
      assert.is_true(state.hidden)
      assert.is_nil(state.active)
    end)

    it("still finds a player buff by id when the walk is unreadable", function()
      WowStub.state.auras.player = { { spellId = WowStub.Secret, name = WowStub.Secret } }
      WowStub.Set("C_UnitAuras.GetPlayerAuraBySpellID", function(id)
        if id == 5 then
          return { spellId = 5, name = "X", duration = 0, expirationTime = 0 }
        end
      end)
      local state = VM.Entry(aura("buff", 5), { platform = P })
      assert.is_true(state.active)
      assert.is_falsy(state.hidden)
    end)

    it("is hidden when the aura API is missing", function()
      WowStub.Remove("C_UnitAuras.GetAuraDataByIndex")
      assert.is_true(VM.Entry(aura("buff", 5), { platform = P }).hidden)
    end)

    it("reads debuffs from the target", function()
      WowStub.state.auras.target = { { spellId = 1943, name = "Rupture", duration = 8, expirationTime = 1008 } }
      local state = VM.Entry(aura("debuff", 1943), { platform = P })
      assert.is_true(state.active)
      assert.are.equal(1000, state.start)
      assert.is_false(VM.Entry(aura("debuff", 1944), { platform = P }).active)
    end)

    it("uses the icon of the aura when the spell has none", function()
      WowStub.Remove("C_Spell.GetSpellInfo")
      WowStub.Remove("GetSpellInfo")
      player({ { spellId = 5, name = "X", icon = 77 } })
      assert.are.equal(77, VM.Entry(aura("buff", 5), { platform = P }).icon)
    end)
  end)

  describe("groups", function()
    local function group(missing)
      return { id = "g", kind = "buff", showWhenMissing = missing, entries = {} }
    end

    it("hides missing auras when the group hides them", function()
      player({ { spellId = 5, name = "X" } })
      local states = VM.Group(group("hide"), { aura("buff", 5), aura("buff", 6) }, { platform = P })
      assert.are.equal(1, #states)
      assert.are.equal(5, states[1].spellId)
    end)

    it("dims missing auras when the group dims them and keeps cooldowns", function()
      player({ { spellId = 5, name = "X" } })
      local states = VM.Group(group("dim"), { aura("buff", 5), aura("buff", 6) }, { platform = P })
      assert.are.equal(2, #states)
      assert.is_falsy(states[1].dim)
      assert.is_true(states[2].dim)
      local cooldowns = VM.Group({ id = "c", kind = "cooldown", entries = {} }, { cooldown(5) }, { platform = P })
      assert.are.equal(1, #cooldowns)
    end)

    it("keeps an unknown (hidden) aura visible whatever the group says", function()
      player({ { spellId = WowStub.Secret, name = WowStub.Secret } })
      local states = VM.Group(group("hide"), { aura("buff", 5) }, { platform = P })
      assert.are.equal(1, #states)
      assert.is_true(states[1].hidden)
    end)
  end)

  describe("timers", function()
    local state = { start = 100, duration = 20 }

    it("computes the remaining time and the fraction from readable numbers", function()
      assert.are.equal(15, VM.Remaining(state, 105))
      assert.are.equal(0.75, VM.Fraction(state, 105))
      assert.are.equal(0, VM.Remaining(state, 130))
      assert.are.equal(20, VM.Remaining(state, 90))
    end)

    it("gives nothing for a state without readable numbers", function()
      assert.is_nil(VM.Remaining({ durationObject = {} }, 1))
      assert.is_nil(VM.Remaining({ start = 1, duration = 2, hidden = true }, 1))
      assert.is_nil(VM.Remaining(state, nil))
      assert.is_nil(VM.Fraction({ durationObject = {} }, 1))
      assert.is_false(VM.CanShowBar({}))
    end)

    it("never divides by a zero duration", function()
      assert.is_nil(VM.Fraction({ start = 1, duration = 0 }, 1))
    end)

    it("formats times", function()
      assert.are.equal("5", VM.TimeText(4.2))
      assert.are.equal("1:05", VM.TimeText(65))
      assert.are.equal("10m", VM.TimeText(600))
      assert.are.equal("2h", VM.TimeText(7000))
    end)
  end)

  describe("layout", function()
    local function layout(growth, columns)
      return { growth = growth, columns = columns, spacing = 2 }
    end

    it("places slots to the right and wraps downward", function()
      local plan = VM.Layout(5, layout("RIGHT", 3), 10, 10)
      assert.are.same({ x = 0, y = 0 }, plan.slots[1])
      assert.are.same({ x = 24, y = 0 }, plan.slots[3])
      assert.are.same({ x = 0, y = -12 }, plan.slots[4])
      assert.are.equal(34, plan.width)
      assert.are.equal(22, plan.height)
    end)

    it("grows to the left", function()
      local plan = VM.Layout(2, layout("LEFT", 3), 10, 10)
      assert.are.same({ x = 12, y = 0 }, plan.slots[1])
      assert.are.same({ x = 0, y = 0 }, plan.slots[2])
      assert.are.equal(22, plan.width)
    end)

    it("grows downward and upward in columns", function()
      local down = VM.Layout(4, layout("DOWN", 3), 10, 10)
      assert.are.same({ x = 0, y = -24 }, down.slots[3])
      assert.are.same({ x = 12, y = 0 }, down.slots[4])
      assert.are.equal(22, down.width)
      assert.are.equal(34, down.height)
      local up = VM.Layout(2, layout("UP", 3), 10, 10)
      assert.are.same({ x = 0, y = -12 }, up.slots[1])
      assert.are.same({ x = 0, y = 0 }, up.slots[2])
    end)

    it("gives one slot size for an empty group", function()
      local plan = VM.Layout(0, layout("RIGHT", 3), 10, 12)
      assert.are.same({}, plan.slots)
      assert.are.equal(10, plan.width)
      assert.are.equal(12, plan.height)
    end)
  end)
end)
