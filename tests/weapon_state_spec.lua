local Loader = dofile("tests/support/loader.lua")

describe("WeaponState", function()
  local ns, state, data, now

  -- hasMH, mhMs, mhCharges, mhEnchantId, hasOH, ohMs, ohCharges, ohEnchantId
  local function weapons(...)
    WowStub.state.weapon = { ... }
  end

  before_each(function()
    WowStub.Reset()
    ns = Loader.Full({ "Core/Init.lua", "Commands/Slash.lua" })
    data = {}
    now = 100
    state = ns.WeaponState.New({
      data = data,
      now = function()
        return now
      end,
    })
  end)

  it("is unknown when the client cannot say", function()
    WowStub.Remove("GetWeaponEnchantInfo")
    assert.is_nil(state:Read())
  end)

  it("reads minutes, charges and enchant of both hands", function()
    weapons(true, 600000, 40, 7, true, 120000, 0, 9)
    local read = state:Read()
    assert.is_true(read.mh.has)
    assert.are.equal(10, read.mh.minutes)
    assert.are.equal(40, read.mh.charges)
    assert.are.equal(7, read.mh.enchantId)
    assert.is_true(read.mh.weapon)
    assert.is_true(read.oh.has)
    assert.are.equal(2, read.oh.minutes)
    assert.is_nil(read.oh.charges)
    assert.is_nil(read.mh.itemID)
  end)

  it("reports a weapon without enchant", function()
    weapons(false, 0, 0, 0, false, 0, 0, 0)
    local read = state:Read()
    assert.is_false(read.mh.has)
    assert.is_nil(read.mh.minutes)
    assert.is_nil(read.mh.enchantId)
  end)

  it("tells an empty off hand from a missing poison", function()
    WowStub.state.equipment[17] = nil
    weapons(true, 60000, 10, 7, false, 0, 0, 0)
    local read = state:Read()
    assert.is_false(read.oh.weapon)
    assert.is_false(read.oh.has)
    assert.is_true(read.mh.weapon)
  end)

  it("leaves the weapon unknown when the equipment cannot be read", function()
    WowStub.Remove("GetInventoryItemID")
    weapons(true, 60000, 10, 7, false, 0, 0, 0)
    assert.is_nil(state:Read().oh.weapon)
  end)

  it("treats a hand the client does not describe as unknown", function()
    WowStub.Set("GetWeaponEnchantInfo", function()
      return true, 60000, 10, 7
    end)
    local read = state:Read()
    assert.is_true(read.mh.has)
    assert.is_nil(read.oh.has)
  end)

  describe("learning", function()
    it("stores the enchant id when the enchant of the slot changes after an application", function()
      weapons(false, 0, 0, 0, false, 0, 0, 0)
      assert.is_true(state:NoteApplied("mh", 6947))
      now = 104
      weapons(true, 3600000, 80, 603, false, 0, 0, 0)
      local read = state:Read()
      assert.are.equal(6947, read.mh.itemID)
      assert.are.equal(6947, data.enchants[603])
      -- Learned for good: it survives a new instance on the same data.
      local again = ns.WeaponState.New({ data = data })
      weapons(true, 3600000, 80, 603, false, 0, 0, 0)
      assert.are.equal(6947, again:Read().mh.itemID)
    end)

    it("learns when a different poison replaces the current one", function()
      weapons(true, 100000, 5, 603, false, 0, 0, 0)
      state:NoteApplied("mh", 2892)
      weapons(true, 3600000, 80, 21, false, 0, 0, 0)
      assert.are.equal(2892, state:Read().mh.itemID)
    end)

    it("learns the off hand on its own", function()
      state:NoteApplied("oh", 3775)
      weapons(false, 0, 0, 0, true, 3600000, 80, 44)
      local read = state:Read()
      assert.are.equal(3775, read.oh.itemID)
      assert.is_nil(read.mh.itemID)
    end)

    it("learns nothing while the enchant has not changed", function()
      weapons(true, 100000, 5, 603, false, 0, 0, 0)
      state:NoteApplied("mh", 2892)
      state:Read()
      assert.are.same({}, data.enchants)
    end)

    it("forgets an application that never changed the weapon", function()
      weapons(true, 100000, 5, 603, false, 0, 0, 0)
      state:NoteApplied("mh", 2892)
      now = 100 + ns.Constants.POISON_PENDING_SECONDS + 1
      state:Read()
      weapons(true, 100000, 5, 21, false, 0, 0, 0)
      state:Read()
      assert.are.same({}, data.enchants)
    end)

    it("notes an application while the weapons are unreadable", function()
      WowStub.Remove("GetWeaponEnchantInfo")
      assert.is_true(state:NoteApplied("mh", 6947))
      weapons(true, 100000, 5, 77, false, 0, 0, 0)
      WowStub.Set("GetWeaponEnchantInfo", function()
        return unpack(WowStub.state.weapon, 1, 8)
      end)
      state:Read()
      assert.are.equal(6947, data.enchants[77])
    end)

    it("refuses an unknown slot", function()
      assert.is_false(state:NoteApplied("ranged", 1))
    end)
  end)

  it("creates its own persisted table and uses the platform clock by default", function()
    local plain = ns.WeaponState.New()
    assert.is_table(plain.data.enchants)
    assert.are.equal(1000, plain.now())
    local kept = { enchants = "garbage" }
    ns.WeaponState.New({ data = kept })
    assert.is_table(kept.enchants)
    WowStub.Remove("GetTime")
    assert.are.equal(0, ns.WeaponState.New().now())
  end)
end)
