local Loader = dofile("tests/support/loader.lua")

describe("Probe", function()
  local ns

  before_each(function()
    WowStub.Reset()
    ns = Loader.Full({ "Core/Init.lua", "Commands/Slash.lua" })
  end)

  local function lineFor(lines, key)
    for _, line in ipairs(lines) do
      if line:find(" " .. key .. "=", 1, true) then
        return line
      end
    end
  end

  it("prints one NN key=value line per question", function()
    local lines = ns.Probe.Run()
    assert.are.equal(#ns.Probe.ITEMS, #lines)
    for index, line in ipairs(lines) do
      assert.is_truthy(line:match("^%d%d [%w_%.]+=.+"), line)
      assert.are.equal(("%02d"):format(index), line:sub(1, 2))
    end
    assert.is_truthy(lineFor(lines, "class"):find("ROGUE", 1, true))
  end)

  it("covers every API of plan section 7", function()
    local lines = ns.Probe.Run()
    for _, key in ipairs({
      "class",
      "IsPlayerSpell_poised",
      "GetWeaponEnchantInfo",
      "C_Container.GetContainerItemInfo",
      "C_Item.GetItemCount",
      "C_Spell.GetSpellCooldown",
      "C_Spell.GetSpellCooldownDuration",
      "C_UnitAuras.GetPlayerAuraBySpellID",
      "C_UnitAuras.GetAuraDataByIndex",
      "C_Secrets",
      "C_Secrets.GetSpellCooldownSecrecy",
      "C_CooldownViewer",
      "InCombatLockdown",
      "IsInInstance",
      "issecretvalue",
      "SecureActionButtonTemplate",
      "SecureHandlerClickTemplate",
    }) do
      assert.is_not_nil(lineFor(lines, key), key)
    end
  end)

  it("marks missing, erroring and secret answers", function()
    WowStub.Remove("GetWeaponEnchantInfo")
    WowStub.Fail("InCombatLockdown")
    WowStub.Set("IsPlayerSpell", function()
      return WowStub.Secret
    end)
    local lines = ns.Probe.Run()
    assert.is_truthy(lineFor(lines, "GetWeaponEnchantInfo"):find("=missing", 1, true))
    assert.is_truthy(lineFor(lines, "InCombatLockdown"):find("=error: ", 1, true))
    assert.is_truthy(lineFor(lines, "IsPlayerSpell_poised"):find("=<secret>", 1, true))
  end)

  it("reports presence of optional tables and the secure templates", function()
    local before = ns.Probe.Run()
    assert.is_truthy(lineFor(before, "C_Secrets"):find("=missing", 1, true))
    assert.is_truthy(lineFor(before, "SecureHandlerClickTemplate"):find("=creatable", 1, true))
    WowStub.Set("C_Secrets.GetSpellCooldownSecrecy", function()
      return 1
    end)
    WowStub.Set("C_CooldownViewer.GetCooldownViewerCategorySet", function() end)
    WowStub.state.missingTemplates.SecureHandlerClickTemplate = true
    local after = ns.Probe.Run()
    assert.is_truthy(lineFor(after, "C_Secrets"):find("=present", 1, true))
    assert.is_truthy(lineFor(after, "C_CooldownViewer"):find("=present", 1, true))
    assert.is_truthy(lineFor(after, "SecureHandlerClickTemplate"):find("=not creatable", 1, true))
  end)

  it("describes tables, empty results and long values", function()
    WowStub.Set("GetWeaponEnchantInfo", function() end)
    WowStub.Set("C_Container.GetContainerItemInfo", function()
      local info = {}
      for index = 1, 10 do
        info["k" .. index] = index
      end
      return info
    end)
    WowStub.Set("UnitClass", function()
      return ("x"):rep(200)
    end)
    WowStub.Set("C_Item.GetItemCount", function()
      return {}
    end)
    local lines = ns.Probe.Run()
    assert.is_truthy(lineFor(lines, "GetWeaponEnchantInfo"):find("(no values)", 1, true))
    assert.is_truthy(lineFor(lines, "C_Container.GetContainerItemInfo"):find("+2 more", 1, true))
    assert.is_truthy(lineFor(lines, "class"):find("...", 1, true))
    assert.is_truthy(lineFor(lines, "C_Item.GetItemCount"):find("table empty", 1, true))
  end)

  it("never raises when an item function does", function()
    ns.Probe.ITEMS[#ns.Probe.ITEMS + 1] = {
      key = "broken",
      text = function()
        error("bad")
      end,
    }
    local lines = ns.Probe.Run()
    assert.is_truthy(lines[#lines]:find("=error: ", 1, true))
    ns.Probe.ITEMS[#ns.Probe.ITEMS] = nil
  end)

  describe("bag lines", function()
    it("lists bag, slot, item id, count and name", function()
      WowStub.state.bags = { [1] = { size = 2, [2] = { itemID = 8, stackCount = 5 } } }
      local lines = ns.Probe.BagLines()
      assert.are.equal("Bag items: 1", lines[1])
      assert.are.equal("bag=1 slot=2 itemID=8 count=5 name=Item8", lines[2])
    end)

    it("falls back to the link name and then to hidden", function()
      WowStub.Remove("C_Item.GetItemNameByID")
      WowStub.state.bags = {
        [0] = { size = 2, [1] = { itemID = 8, hyperlink = "|cff|Hitem:8|h[Link Name]|h|r" }, [2] = { itemID = 9 } },
      }
      local lines = ns.Probe.BagLines()
      assert.is_truthy(lines[2]:find("name=Link Name", 1, true))
      assert.is_truthy(lines[3]:find("name=<hidden>", 1, true))
    end)

    it("says so when nothing is readable", function()
      assert.are.same({ "No readable items in the bags." }, ns.Probe.BagLines())
    end)
  end)

  describe("spell lines", function()
    it("lists spell id and name", function()
      WowStub.state.spellbook = { { itemIndexOffset = 0, numSpellBookItems = 2 } }
      WowStub.state.spellItems = { { spellID = 1, name = "One" }, { spellID = 2 } }
      local lines = ns.Probe.SpellLines()
      assert.are.equal("Spellbook entries: 2", lines[1])
      assert.are.equal("spellId=1 name=One", lines[2])
      assert.are.equal("spellId=2 name=<hidden>", lines[3])
    end)

    it("says so when the spellbook is unreadable", function()
      assert.are.same({ "The spellbook is not readable." }, ns.Probe.SpellLines())
    end)
  end)

  describe("aura lines", function()
    it("lists player buffs and target debuffs with stacks and remaining time", function()
      WowStub.state.auras.player = {
        { name = "Stealth", spellId = 1, applications = 0, expirationTime = 1012.5 },
        { spellId = 2, applications = 3, expirationTime = 0 },
      }
      WowStub.state.auras.target = { { name = "Rupture", spellId = 3, applications = 1, expirationTime = 900 } }
      local lines = ns.Probe.AuraLines()
      assert.are.equal("Player buffs (HELPFUL): 2", lines[1])
      assert.are.equal("spellId=1 name=Stealth stacks=0 remaining=12.5", lines[2])
      assert.are.equal("spellId=2 name=Spell2 stacks=3 remaining=none", lines[3])
      assert.are.equal("Target debuffs from you (HARMFUL|PLAYER): 1", lines[4])
      assert.are.equal("spellId=3 name=Rupture stacks=1 remaining=0.0", lines[5])
    end)

    it("shows hidden fields and handles a missing clock", function()
      WowStub.state.auras.player = { { auraInstanceID = 4, expirationTime = 5 } }
      WowStub.Remove("GetTime")
      local lines = ns.Probe.AuraLines()
      assert.are.equal("spellId=<hidden> name=<hidden> stacks=<hidden> remaining=none", lines[2])
    end)

    it("says so when there are no auras", function()
      local lines = ns.Probe.AuraLines()
      assert.are.equal("No readable auras.", lines[#lines])
    end)
  end)

  describe("selftest", function()
    it("passes when every API exists", function()
      WowStub.Set("GetSpellInfo", function() end)
      local lines = ns.Probe.SelfTest()
      assert.is_truthy(lines[1]:find("required client APIs are available", 1, true))
    end)

    it("lists the missing APIs and accepts alternatives", function()
      WowStub.Remove("C_Spell.GetSpellInfo")
      WowStub.Remove("GetTime")
      local lines = ns.Probe.SelfTest()
      assert.is_truthy(lines[1]:find("GetTime", 1, true))
      assert.is_truthy(lines[1]:find("C_Spell.GetSpellInfo | GetSpellInfo", 1, true))
      WowStub.Set("GetSpellInfo", function() end)
      assert.is_falsy(ns.Probe.SelfTest()[1]:find("GetSpellInfo", 1, true))
    end)
  end)
end)
