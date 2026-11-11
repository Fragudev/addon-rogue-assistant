local Loader = require("tests.support.loader")

describe("WeaponState", function()
  local WeaponState
  local options

  before_each(function()
    WowStub.Reset()
    WeaponState = Loader.Load({ "Core/Constants.lua", "Domain/WeaponState.lua" }).WeaponState
    options = { equipped = true, warnSeconds = 300, enchants = { [323] = 6947 } }
  end)

  describe("Build", function()
    it("shows an empty slot without a warning", function()
      options.equipped = false
      assert.same({ status = "empty", warning = false }, WeaponState.Build({ active = false }, options))
    end)

    it("does not warn when the client gives nothing or hides the enchant", function()
      assert.same({ status = "unknown", warning = false }, WeaponState.Build(nil, options))
      assert.same({ status = "unknown", warning = false }, WeaponState.Build({ unknown = true }, options))
    end)

    it("warns when nothing is applied", function()
      assert.same({ status = "missing", warning = true }, WeaponState.Build({ active = false }, options))
    end)

    it("gives time, charges and the learned item of an active enchant", function()
      local state = WeaponState.Build({ active = true, ms = 1799500, charges = 40, enchantID = 323 }, options)
      assert.same({ status = "active", seconds = 1799, charges = 40, itemID = 6947, warning = false }, state)
    end)

    it("warns below the threshold and not at it", function()
      assert.is_true(WeaponState.Build({ active = true, ms = 299999 }, options).warning)
      assert.is_false(WeaponState.Build({ active = true, ms = 300000 }, options).warning)
    end)

    it("never warns about time with a zero threshold", function()
      options.warnSeconds = 0
      assert.is_false(WeaponState.Build({ active = true, ms = 1000 }, options).warning)
    end)

    it("hides zero charges and unknown time", function()
      local state = WeaponState.Build({ active = true, charges = 0 }, options)
      assert.is_nil(state.charges)
      assert.is_nil(state.seconds)
      assert.is_false(state.warning)
    end)
  end)

  it("formats time left", function()
    assert.equal("", WeaponState.FormatTime(nil))
    assert.equal("0s", WeaponState.FormatTime(-3))
    assert.equal("42s", WeaponState.FormatTime(42))
    assert.equal("4:05", WeaponState.FormatTime(245))
    assert.equal("10m", WeaponState.FormatTime(600))
    assert.equal("59m", WeaponState.FormatTime(3599))
    assert.equal("1h", WeaponState.FormatTime(3600))
  end)

  describe("Learner", function()
    local enchants, learner

    before_each(function()
      enchants = {}
      learner = WeaponState.NewLearner(enchants)
    end)

    it("learns the item when the enchant starts after a click", function()
      learner:Observe(16, { active = false }, 100)
      learner:NoteApply(16, 8928, 100)
      assert.is_false(learner:Observe(16, { active = false }, 101))
      assert.is_true(learner:Observe(16, { active = true, ms = 3600000, enchantID = 625 }, 103))
      assert.same({ [625] = 8928 }, enchants)
    end)

    it("learns when the same enchant is renewed", function()
      learner:Observe(16, { active = true, ms = 60000, enchantID = 625 }, 100)
      learner:NoteApply(16, 8928, 100)
      assert.is_false(learner:Observe(16, { active = true, ms = 59000, enchantID = 625 }, 101))
      assert.is_true(learner:Observe(16, { active = true, ms = 3600000, enchantID = 625 }, 103))
      assert.same({ [625] = 8928 }, enchants)
    end)

    it("learns when the enchant changes to another one", function()
      learner:Observe(17, { active = true, ms = 60000, enchantID = 7 }, 100)
      learner:NoteApply(17, 2892, 100)
      assert.is_true(learner:Observe(17, { active = true, ms = 3600000, enchantID = 8 }, 103))
      assert.same({ [8] = 2892 }, enchants)
    end)

    it("forgets a click after the learning window", function()
      learner:Observe(16, { active = false }, 100)
      learner:NoteApply(16, 8928, 100)
      assert.is_false(learner:Observe(16, { active = false }, 131))
      assert.is_false(learner:Observe(16, { active = true, ms = 3600000, enchantID = 625 }, 132))
      assert.same({}, enchants)
    end)

    it("learns nothing without a click", function()
      learner:Observe(16, { active = false }, 100)
      assert.is_false(learner:Observe(16, { active = true, ms = 3600000, enchantID = 625 }, 101))
      assert.same({}, enchants)
    end)

    it("learns nothing from an enchant without an id", function()
      learner:NoteApply(16, 8928, 100)
      assert.is_false(learner:Observe(16, { active = true, ms = 3600000 }, 101))
      assert.same({}, enchants)
    end)
  end)
end)
