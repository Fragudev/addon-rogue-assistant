local Loader = dofile("tests/support/loader.lua")

describe("Store", function()
  local ns, Store

  before_each(function()
    WowStub.Reset()
    ns = Loader.Load({ "Core/Constants.lua", "Core/Store.lua" })
    Store = ns.Store
  end)

  it("creates the first layout from nothing", function()
    local store = Store.Open(nil)
    local db = store:Db()
    assert.are.equal(ns.Constants.SCHEMA_VERSION, db.schemaVersion)
    assert.are.same({}, db.profiles)
    assert.are.same({}, db.debug.log)
    assert.are.same({}, db.debug.lastProbe)
  end)

  it("repairs wrongly typed containers and keeps valid data", function()
    local db = { schemaVersion = "x", profiles = "bad", debug = { log = 3 } }
    local store = Store.Open(db)
    assert.are.same({}, store:Db().profiles)
    assert.are.same({}, store:Db().debug.log)
    local kept = Store.Open({ schemaVersion = 1, profiles = { a = { name = "Keep" } } })
    assert.are.equal("Keep", kept:FindProfile("a").name)
  end)

  it("repairs wrongly typed containers even when the version is current", function()
    local store = Store.Open({ schemaVersion = 1, profiles = 5, debug = "x" })
    local db = store:Db()
    assert.are.same({}, db.profiles)
    assert.are.same({}, db.debug.log)
    assert.are.same({}, db.debug.lastProbe)
    store = Store.Open({ schemaVersion = 1, profiles = {}, debug = { log = "x", lastProbe = 7 } })
    assert.are.same({}, store:Db().debug.log)
    assert.are.same({}, store:Db().debug.lastProbe)
    store:Log("still works")
    assert.are.equal(1, #store:Db().debug.log)
  end)

  it("ignores and replaces a profile that is not a table", function()
    local store = Store.Open({ schemaVersion = 1, profiles = { g = "bad" } })
    assert.is_nil(store:FindProfile("g"))
    assert.is_table(store:Profile("g", { class = "ROGUE" }))
    assert.are.equal("ROGUE", store:FindProfile("g").class)
  end)

  it("refuses data from a newer schema and leaves it untouched", function()
    local db = { schemaVersion = 5, extra = true }
    local store, reason = Store.Open(db)
    assert.is_nil(store)
    assert.are.equal("newer_schema", reason)
    assert.are.equal(5, db.schemaVersion)
    assert.is_nil(db.profiles)
  end)

  it("chains migrations in order and records the version", function()
    local order = {}
    Store.MIGRATIONS[2] = function(db)
      order[#order + 1] = 2
      db.two = true
    end
    Store.MIGRATIONS[3] = function(db)
      order[#order + 1] = 3
      db.three = db.two
    end
    local store = Store.Open(
      { schemaVersion = 1, profiles = {}, debug = { log = {}, lastProbe = {} } },
      { version = 3 }
    )
    assert.are.same({ 2, 3 }, order)
    assert.is_true(store:Db().three)
    assert.are.equal(3, store:Db().schemaVersion)
    Store.MIGRATIONS[2], Store.MIGRATIONS[3] = nil, nil
  end)

  describe("profiles", function()
    local store

    before_each(function()
      local clock = 0
      store = Store.Open({}, {
        now = function()
          clock = clock + 1
          return clock
        end,
      })
    end)

    it("keys profiles by GUID and refreshes display info", function()
      local profile = store:Profile("Player-1-A", { name = "Sly", class = "ROGUE" })
      assert.are.equal("Sly", profile.name)
      assert.are.same({}, profile.settings)
      local first = profile.lastSeen
      local again = store:Profile("Player-1-A", { name = "Sly Two" })
      assert.are.equal(profile, again)
      assert.are.equal("Sly Two", again.name)
      assert.are.equal("ROGUE", again.class)
      assert.is_true(again.lastSeen > first)
    end)

    it("keeps two characters with the same name apart", function()
      store:Profile("Player-1-A", { name = "Same" })
      store:Profile("Player-1-B", { name = "Same" })
      assert.are_not.equal(store:FindProfile("Player-1-A"), store:FindProfile("Player-1-B"))
    end)

    it("rejects a missing or empty GUID", function()
      assert.is_nil(store:Profile(nil))
      assert.is_nil(store:Profile(""))
      assert.is_nil(store:Profile(42))
    end)

    it("forgets a profile", function()
      store:Profile("Player-1-A")
      assert.is_true(store:Forget("Player-1-A"))
      assert.is_false(store:Forget("Player-1-A"))
      assert.is_nil(store:FindProfile("Player-1-A"))
    end)

    it("repairs a profile whose settings table is gone", function()
      store:Profile("Player-1-A").settings = nil
      assert.are.same({}, store:Profile("Player-1-A").settings)
    end)
  end)

  describe("debug", function()
    local store

    before_each(function()
      store = Store.Open({})
    end)

    it("bounds the log and clips long lines", function()
      for index = 1, ns.Constants.DEBUG_MAX_LOG + 10 do
        store:Log("line " .. index)
      end
      local log = store:Debug().log
      assert.are.equal(ns.Constants.DEBUG_MAX_LOG, #log)
      assert.is_truthy(log[#log]:find("line 60", 1, true))
      store:Log(("x"):rep(1000))
      local last = store:Debug().log[#store:Debug().log]
      assert.is_true(#last <= ns.Constants.DEBUG_MAX_LINE_LENGTH + 20)
    end)

    it("keeps only the last probe lines", function()
      local lines = {}
      for index = 1, ns.Constants.DEBUG_MAX_PROBE_LINES + 25 do
        lines[index] = "line " .. index
      end
      store:SetLastProbe(lines)
      local saved = store:Debug().lastProbe
      assert.are.equal(ns.Constants.DEBUG_MAX_PROBE_LINES, #saved)
      assert.are.equal("line 26", saved[1])
      store:SetLastProbe({ "a" })
      assert.are.same({ "a" }, store:Debug().lastProbe)
    end)
  end)
end)
