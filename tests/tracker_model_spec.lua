local Loader = dofile("tests/support/loader.lua")

describe("TrackerModel", function()
  local ns, settings, model, root

  local function newModel()
    return ns.TrackerModel.New(settings)
  end

  local function ids(groupId)
    local list = {}
    for _, entry in ipairs(model:Group(groupId).entries) do
      list[#list + 1] = entry.spellId or entry.name
    end
    return list
  end

  local function know(...)
    WowStub.state.knownSpells = {}
    for _, id in ipairs({ ... }) do
      WowStub.state.knownSpells[id] = true
    end
  end

  before_each(function()
    WowStub.Reset()
    ns = Loader.Full({ "Core/Init.lua", "Commands/Slash.lua" })
    root = {}
    settings = ns.Settings.New(root)
    model = newModel()
  end)

  describe("defaults and persistence", function()
    it("seeds the default groups into the settings on first use", function()
      assert.are.equal(3, #settings:Get("tracker.groups"))
      assert.are.equal("essentials", model:Groups()[1].id)
      assert.are.equal("RIGHT", ns.TrackerModel.Layout(model:Group("essentials")).growth)
    end)

    it("does not share tables with the shipped data", function()
      model:AddEntry("essentials", 999)
      assert.are_not.equal(#ns.Spells.GROUPS[1].entries, #model:Group("essentials").entries)
    end)

    it("keeps a saved list and survives a new model over the same settings", function()
      model:AddEntry("essentials", 999)
      local again = newModel()
      assert.are.same(
        ids("essentials"),
        (function()
          local list = {}
          for _, entry in ipairs(again:Group("essentials").entries) do
            list[#list + 1] = entry.spellId
          end
          return list
        end)()
      )
    end)

    it("replaces an invalid saved list by the defaults", function()
      root.tracker.groups = { { id = "x", kind = "nonsense", entries = {} } }
      local rebuilt = ns.Settings.New(root)
      local again = ns.TrackerModel.New(rebuilt)
      assert.are.equal(3, #again:Groups())
    end)

    it("fills missing layout options with defaults", function()
      local layout = ns.TrackerModel.Layout({ id = "x", kind = "buff", entries = {}, iconSize = 50 })
      assert.are.equal(50, layout.iconSize)
      assert.are.equal(4, layout.spacing)
      assert.are.equal(8, layout.columns)
      assert.are.equal("icons", layout.mode)
      assert.are.equal("hide", layout.showWhenMissing)
      assert.are.equal(1, layout.scale)
    end)

    it("titles a group by its own title or by the translated default", function()
      local group = model:Group("buffs")
      assert.are.equal("Buffs", ns.TrackerModel.Title(group, ns.L))
      assert.is_true(model:SetTitle("buffs", "My buffs"))
      assert.are.equal("My buffs", ns.TrackerModel.Title(group, ns.L))
      assert.is_true(model:SetTitle("buffs", ""))
      assert.are.equal("Buffs", ns.TrackerModel.Title(group, ns.L))
      assert.are.equal("zzz", ns.TrackerModel.Title({ id = "zzz" }, ns.L))
      assert.are.equal("Essentials", ns.TrackerModel.Title({ id = "e", titleKey = "tracker.group.essentials" }))
      assert.is_false(model:SetTitle("buffs", 5))
      assert.is_false(model:SetTitle("nope", "x"))
    end)
  end)

  describe("visibility", function()
    it("shows an entry only when the player knows one of its ids", function()
      know(2983) -- Sprint
      local list = model:VisibleEntries("essentials")
      assert.are.equal(1, #list)
      assert.are.equal(2983, list[1].spellId)
    end)

    it("accepts any rank id", function()
      know(8643) -- Kidney Shot rank 2
      local list = model:VisibleEntries("essentials")
      assert.are.equal(408, list[1].spellId)
    end)

    it("shows everything when the client cannot say what is known", function()
      WowStub.Remove("IsPlayerSpell")
      assert.are.equal(#model:Group("essentials").entries, #model:VisibleEntries("essentials"))
    end)

    it("always shows poison debuffs and the entries the user added", function()
      know()
      local target = model:VisibleEntries("target")
      assert.are.equal(3, #target)
      model:AddEntry("essentials", 777)
      assert.are.equal(777, model:VisibleEntries("essentials")[1].spellId)
    end)

    it("shows nothing for an unknown group", function()
      assert.are.same({}, model:VisibleEntries("nope"))
    end)

    it("shows a name-only entry that has no ids", function()
      know()
      local group = model:Group("buffs")
      assert.is_true(model:IsVisible({ name = "Foo", kind = "buff" }, group))
    end)
  end)

  describe("editing", function()
    it("adds by id, by digits and by name", function()
      local ok, entry = model:AddEntry("essentials", 12345)
      assert.is_true(ok)
      assert.are.equal("user", entry.source)
      assert.is_true(model:AddEntry("essentials", " 22222 "))
      assert.is_true(model:AddEntry("buffs", "Some Buff"))
      assert.is_true(model:AddEntry("essentials", "Some Spell"))
      local added = model:Group("buffs").entries
      assert.are.equal("Some Buff", added[#added].name)
      assert.is_true(added[#added].byName)
      local cooldowns = model:Group("essentials").entries
      assert.is_nil(cooldowns[#cooldowns].byName)
      assert.is_true(root.tracker.groups[1].entries[#cooldowns].custom)
    end)

    it("refuses duplicates, invalid input, unknown groups and full groups", function()
      assert.are.same({ false, "duplicate" }, { model:AddEntry("essentials", 2983) })
      assert.are.same({ false, "invalid" }, { model:AddEntry("essentials", 0) })
      assert.are.same({ false, "invalid" }, { model:AddEntry("essentials", 1.5) })
      assert.are.same({ false, "invalid" }, { model:AddEntry("essentials", "") })
      assert.are.same({ false, "invalid" }, { model:AddEntry("essentials", {}) })
      assert.are.same({ false, "unknown_group" }, { model:AddEntry("nope", 1) })
      assert.is_true(model:AddEntry("buffs", "Foo"))
      assert.are.same({ false, "duplicate" }, { model:AddEntry("buffs", "foo") })
      for index = 1, 60 do
        model:AddEntry("essentials", 500000 + index)
      end
      assert.are.equal(ns.Constants.TRACKER.MAX_ENTRIES, #model:Group("essentials").entries)
      assert.are.same({ false, "full" }, { model:AddEntry("essentials", 999999) })
    end)

    it("removes by index, by id (including a rank id) and by name", function()
      local before = #model:Group("essentials").entries
      assert.is_true(model:RemoveAt("essentials", 1))
      assert.are.equal(before - 1, #model:Group("essentials").entries)
      assert.are.same({ false, "invalid" }, { model:RemoveAt("essentials", 99) })
      assert.are.same({ false, "invalid" }, { model:RemoveAt("essentials", "x") })
      assert.are.same({ false, "unknown_group" }, { model:RemoveAt("nope", 1) })

      assert.is_true(model:Remove("essentials", 2983))
      assert.is_true(model:Remove("essentials", "11305") == false)
      assert.is_true(model:Remove("essentials", 8643))
      model:AddEntry("buffs", "Foo")
      assert.is_true(model:Remove("buffs", "FOO"))
      assert.are.same({ false, "not_found" }, { model:Remove("buffs", "Foo") })
      assert.are.same({ false, "invalid" }, { model:Remove("buffs", 0) })
      assert.are.same({ false, "unknown_group" }, { model:Remove("nope", 1) })
    end)

    it("reorders entries", function()
      local first = ids("essentials")
      assert.is_true(model:Move("essentials", 1, 3))
      local moved = ids("essentials")
      assert.are.equal(first[1], moved[3])
      assert.are.equal(first[2], moved[1])
      assert.is_true(model:Move("essentials", 2, 2))
      assert.are.same({ false, "invalid" }, { model:Move("essentials", 0, 2) })
      assert.are.same({ false, "invalid" }, { model:Move("essentials", 1, 99) })
      assert.are.same({ false, "invalid" }, { model:Move("essentials", "a", 1) })
      assert.are.same({ false, "unknown_group" }, { model:Move("nope", 1, 2) })
    end)

    it("sets validated layout options and saves them", function()
      assert.is_true(model:SetLayout("buffs", "iconSize", 48))
      assert.is_true(model:SetLayout("buffs", "growth", "DOWN"))
      assert.is_true(model:SetLayout("buffs", "mode", "bars"))
      assert.is_true(model:SetLayout("buffs", "showWhenMissing", "dim"))
      assert.is_true(model:SetLayout("buffs", "alphaOutOfCombat", 0.5))
      assert.are.equal(48, root.tracker.groups[2].iconSize)
      assert.are.same({ false, "invalid" }, { model:SetLayout("buffs", "iconSize", 5) })
      assert.are.same({ false, "invalid" }, { model:SetLayout("buffs", "iconSize", "big") })
      assert.are.same({ false, "invalid" }, { model:SetLayout("buffs", "growth", "SIDEWAYS") })
      assert.are.same({ false, "invalid" }, { model:SetLayout("buffs", "mode", "x") })
      assert.are.same({ false, "invalid" }, { model:SetLayout("buffs", "showWhenMissing", "x") })
      assert.are.same({ false, "unknown_option" }, { model:SetLayout("buffs", "colour", 1) })
      assert.are.same({ false, "unknown_group" }, { model:SetLayout("nope", "iconSize", 40) })
      assert.are.equal(48, model:Group("buffs").iconSize)
    end)

    it("spreads the default groups instead of stacking them", function()
      local function spot(id)
        local position = model:Group(id).position
        return position.x, position.y
      end
      assert.are.same({ 0, 140 }, { spot("essentials") })
      assert.are.same({ 0, 220 }, { spot("buffs") })
      assert.are.same({ 300, 60 }, { spot("target") })
    end)

    it("stores a position and refuses a malformed one", function()
      assert.is_true(model:SetPosition("buffs", { point = "TOP", relativePoint = "TOP", x = 1, y = -2, junk = 1 }))
      assert.are.same({ point = "TOP", relativePoint = "TOP", x = 1, y = -2 }, root.tracker.groups[2].position)
      assert.are.same({ false, "invalid" }, { model:SetPosition("buffs", { point = "TOP" }) })
      assert.are.same({ false, "invalid" }, { model:SetPosition("buffs", "x") })
      assert.are.same({ false, "unknown_group" }, { model:SetPosition("nope", {}) })
    end)

    it("resets one group or all of them", function()
      model:AddEntry("buffs", "Foo")
      model:SetLayout("buffs", "iconSize", 60)
      model:AddEntry("essentials", 424242)
      assert.is_true(model:ResetGroup("buffs"))
      assert.is_nil(model:Group("buffs").iconSize)
      assert.is_nil(model:Group("buffs").entries[#model:Group("buffs").entries].name)
      assert.are.equal(424242, model:Group("essentials").entries[#model:Group("essentials").entries].spellId)
      assert.are.same({ false, "unknown_group" }, { model:ResetGroup("nope") })
      assert.is_true(model:ResetAll())
      assert.are.equal(#ns.Spells.GROUPS[1].entries, #model:Group("essentials").entries)
    end)

    it("refuses to reset a group the addon does not ship", function()
      local groups = model:Groups()
      groups[#groups + 1] = { id = "mine", kind = "buff", entries = {} }
      assert.are.same({ false, "no_default" }, { model:ResetGroup("mine") })
    end)
  end)

  describe("identifiers", function()
    it("names entries by id or by name", function()
      assert.are.equal(5, ns.TrackerModel.Identifier({ spellId = 5 }))
      assert.are.equal("Foo", ns.TrackerModel.Identifier({ name = "Foo" }))
      assert.are.same({ 5 }, ns.TrackerModel.EntryIds({ spellId = 5 }))
      assert.are.same({ 5, 6 }, ns.TrackerModel.EntryIds({ spellId = 5, ids = { 5, 6 } }))
      assert.are.same({}, ns.TrackerModel.EntryIds({ name = "Foo" }))
    end)
  end)
end)
