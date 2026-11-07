local Loader = dofile("tests/support/loader.lua")

describe("Spell data", function()
  local ns

  before_each(function()
    WowStub.Reset()
    ns = Loader.Full({ "Core/Init.lua", "Commands/Slash.lua" })
  end)

  it("ships the three default groups in order", function()
    local ids = {}
    for _, group in ipairs(ns.Spells.GROUPS) do
      ids[#ids + 1] = group.id
      assert.is_true(ns.Constants.TRACKER.KINDS[group.kind])
      assert.is_truthy(ns.L[group.titleKey] ~= group.titleKey, group.titleKey)
    end
    assert.are.same({ "essentials", "buffs", "target" }, ids)
  end)

  it("gives every entry an id, a kind that matches its group and a source", function()
    for _, group in ipairs(ns.Spells.GROUPS) do
      assert.is_true(#group.entries > 0)
      for _, entry in ipairs(group.entries) do
        assert.is_number(entry.spellId)
        assert.are.equal(group.kind, entry.kind)
        assert.is_string(entry.source)
        assert.is_true(#entry.source > 0)
      end
    end
  end)

  it("has no duplicate spell id inside a group and no duplicate rank id inside an entry", function()
    for _, group in ipairs(ns.Spells.GROUPS) do
      local seen = {}
      for _, entry in ipairs(group.entries) do
        assert.is_nil(seen[entry.spellId], group.id .. " repeats " .. entry.spellId)
        seen[entry.spellId] = true
        local ranks = {}
        for _, id in ipairs(entry.ids or {}) do
          assert.is_nil(ranks[id], "rank id repeated: " .. id)
          ranks[id] = true
        end
        if entry.ids then
          assert.is_true(ranks[entry.spellId], "the primary id is one of the ranks")
        end
      end
    end
  end)

  it("marks only well-known source texts", function()
    local allowed = {
      [ns.Spells.FOREVER] = true,
      [ns.Spells.UNVERIFIED] = true,
      [ns.Spells.NAME_ONLY] = true,
    }
    for _, group in ipairs(ns.Spells.GROUPS) do
      for _, entry in ipairs(group.entries) do
        if not allowed[entry.source] then
          assert.is_truthy(entry.source:find("Poised", 1, true), entry.source)
        end
      end
    end
  end)

  it("matches Poised by name until its buff id is measured", function()
    local poised
    for _, entry in ipairs(ns.Spells.GROUPS[2].entries) do
      if entry.spellId == ns.Constants.SPELL_POISED then
        poised = entry
      end
    end
    assert.is_truthy(poised)
    assert.is_true(poised.byName)
  end)

  it("produces groups that Settings accepts", function()
    local groups = {}
    for index, group in ipairs(ns.Spells.GROUPS) do
      groups[index] = group
    end
    assert.is_true(ns.Settings.ValidGroups(groups))
  end)
end)
