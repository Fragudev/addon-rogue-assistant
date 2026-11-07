local Loader = dofile("tests/support/loader.lua")

describe("Init", function()
  local ns, frame, realCreateFrame, realPrint, printed

  local function fire(event, arg)
    frame.scripts.OnEvent(frame, event, arg)
  end

  before_each(function()
    WowStub.Reset()
    _G.RogueAssistantDB = nil
    printed = {}
    realPrint = _G.print
    _G.print = function(text)
      printed[#printed + 1] = text
    end
    realCreateFrame = _G.CreateFrame
    local counter = 0
    _G.CreateFrame = function(...)
      counter = counter + 1
      local created = realCreateFrame(...)
      if counter == 1 then
        frame = created
      end
      return created
    end
    ns = Loader.Full()
  end)

  after_each(function()
    _G.CreateFrame = realCreateFrame
    _G.print = realPrint
    _G.RogueAssistantDB = nil
  end)

  it("creates the addon namespace and registers its events", function()
    assert.are.equal("RogueAssistant", ns.name)
    assert.is_true(frame.events["ADDON_LOADED"])
    assert.is_true(frame.events["PLAYER_LOGIN"])
  end)

  it("ignores ADDON_LOADED for other addons", function()
    fire("ADDON_LOADED", "SomethingElse")
    assert.is_nil(ns.store)
    assert.is_nil(_G.RogueAssistantDB)
  end)

  it("opens the store on its own ADDON_LOADED", function()
    fire("ADDON_LOADED", "RogueAssistant")
    assert.is_not_nil(ns.store)
    assert.are.equal(ns.Constants.SCHEMA_VERSION, _G.RogueAssistantDB.schemaVersion)
  end)

  it("starts for a rogue: profile, settings and the ready event", function()
    local ready = 0
    fire("ADDON_LOADED", "RogueAssistant")
    ns.bus:Subscribe("addon.ready", function()
      ready = ready + 1
    end)
    fire("PLAYER_LOGIN")
    assert.is_nil(ns.disabled)
    assert.are.equal("Player-1-0000ABCD", ns.guid)
    assert.are.equal("ROGUE", _G.RogueAssistantDB.profiles["Player-1-0000ABCD"].class)
    assert.are.equal(5, ns.settings:Get("alerts.expireMinutes"))
    assert.are.equal(1, ready)
  end)

  it("runs the starters: weapon state, alerts and the poison UI", function()
    fire("ADDON_LOADED", "RogueAssistant")
    fire("PLAYER_LOGIN")
    assert.is_not_nil(ns.weaponState)
    assert.is_not_nil(ns.poisonAlerts)
    assert.are.equal(ns.profile.poison, ns.weaponState.data)
    assert.is_true(ns.poisonButton.built)
    assert.is_not_nil(ns.poisonAlertsView.driver)
    assert.are.same({}, WowStub.state.violations)
    assert.are.equal(0, #ns.store:Debug().log)
  end)

  it("starts nothing on another class", function()
    WowStub.state.class = { "Mage", "MAGE", 8 }
    fire("ADDON_LOADED", "RogueAssistant")
    fire("PLAYER_LOGIN")
    assert.is_nil(ns.weaponState)
    assert.is_nil(ns.poisonButton)
  end)

  it("disables itself quietly on another class", function()
    WowStub.state.class = { "Mage", "MAGE", 8 }
    fire("ADDON_LOADED", "RogueAssistant")
    fire("PLAYER_LOGIN")
    assert.are.equal("not_rogue", ns.disabled)
    assert.is_nil(ns.settings)
    assert.are.equal(0, #printed)
    assert.are.equal(1, #_G.RogueAssistantDB.debug.log)
    assert.is_truthy(_G.RogueAssistantDB.debug.log[1]:find("MAGE", 1, true))
  end)

  it("disables itself when the class is unreadable", function()
    WowStub.Remove("UnitClass")
    fire("ADDON_LOADED", "RogueAssistant")
    fire("PLAYER_LOGIN")
    assert.are.equal("not_rogue", ns.disabled)
  end)

  it("disables itself when the GUID is unreadable", function()
    WowStub.state.guid = nil
    fire("ADDON_LOADED", "RogueAssistant")
    fire("PLAYER_LOGIN")
    assert.are.equal("no_guid", ns.disabled)
  end)

  it("stays disabled and keeps the data when the saved data is newer", function()
    _G.RogueAssistantDB = { schemaVersion = 99, keep = true }
    fire("ADDON_LOADED", "RogueAssistant")
    assert.are.equal("newer_schema", ns.disabled)
    assert.are.equal(1, #printed)
    fire("PLAYER_LOGIN")
    assert.is_true(_G.RogueAssistantDB.keep)
    assert.are.equal(99, _G.RogueAssistantDB.schemaVersion)
    assert.is_nil(ns.guid)
  end)

  it("handles a newer db that is not a table", function()
    _G.RogueAssistantDB = "garbage"
    fire("ADDON_LOADED", "RogueAssistant")
    assert.is_not_nil(ns.store)
  end)

  it("reports schema 0 when newer data has no readable version", function()
    ns.Store.Open = function()
      return nil, "newer_schema"
    end
    _G.RogueAssistantDB = "garbage"
    fire("ADDON_LOADED", "RogueAssistant")
    assert.are.equal("newer_schema", ns.disabled)
  end)

  it("does nothing on login when the store failed to open", function()
    _G.RogueAssistantDB = { schemaVersion = 99 }
    fire("ADDON_LOADED", "RogueAssistant")
    assert.has_no.errors(function()
      fire("PLAYER_LOGIN")
    end)
  end)

  it("uses 0 as the time when the client has no GetTime", function()
    WowStub.Remove("GetTime")
    fire("ADDON_LOADED", "RogueAssistant")
    assert.are.equal(0, ns.store.now())
  end)
end)
