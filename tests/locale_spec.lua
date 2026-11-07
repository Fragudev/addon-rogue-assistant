local Loader = dofile("tests/support/loader.lua")

describe("Locale", function()
  local ns

  before_each(function()
    WowStub.Reset()
    ns = Loader.Full({ "Core/Init.lua", "Commands/Slash.lua" })
  end)

  it("uses enUS by default", function()
    assert.are.equal("enUS", ns.Locale.Current())
    assert.are.equal("Unknown command '%s'.", ns.L["cmd.unknown"])
  end)

  it("resolves esMX to esES and unknown locales to enUS", function()
    assert.are.equal("esES", ns.Locale.Resolve("esMX"))
    assert.are.equal("esES", ns.Locale.Resolve("esES"))
    assert.are.equal("enUS", ns.Locale.Resolve("deDE"))
    assert.are.equal("enUS", ns.Locale.Resolve(nil))
  end)

  it("switches the active locale", function()
    assert.are.equal("esES", ns.Locale.Use("esMX"))
    assert.are.equal("Comando desconocido '%s'.", ns.L["cmd.unknown"])
  end)

  it("falls back to enUS, then to the key", function()
    ns.Locale.Register("enUS", { ["only.english"] = "English only" })
    ns.Locale.Use("esES")
    assert.are.equal("English only", ns.L["only.english"])
    assert.are.equal("no.such.key", ns.L["no.such.key"])
  end)

  it("reads the client locale at load, guarded", function()
    WowStub.Set("GetLocale", function()
      return "esMX"
    end)
    local loaded = Loader.Load({ "Core/Constants.lua", "Core/Locale.lua" })
    assert.are.equal("esES", loaded.Locale.Current())
    WowStub.Fail("GetLocale")
    loaded = Loader.Load({ "Core/Constants.lua", "Core/Locale.lua" })
    assert.are.equal("enUS", loaded.Locale.Current())
    WowStub.Remove("GetLocale")
    loaded = Loader.Load({ "Core/Constants.lua", "Core/Locale.lua" })
    assert.are.equal("enUS", loaded.Locale.Current())
  end)

  describe("parity", function()
    local function placeholders(text)
      local found = {}
      for spec in text:gmatch("%%[%a%d]") do
        found[#found + 1] = spec
      end
      return table.concat(found, ",")
    end

    it("has every enUS key in esES, non-empty, with the same placeholders", function()
      local en, es = ns.Locale.Get("enUS"), ns.Locale.Get("esES")
      local count = 0
      for key, text in pairs(en) do
        count = count + 1
        assert.is_true(type(text) == "string" and text ~= "", "empty enUS text for " .. key)
        assert.is_true(type(es[key]) == "string" and es[key] ~= "", "esES is missing " .. key)
        assert.are.equal(placeholders(text), placeholders(es[key]), "placeholders differ for " .. key)
      end
      assert.is_true(count > 20)
    end)

    it("has no esES key without an enUS one", function()
      local en = ns.Locale.Get("enUS")
      for key in pairs(ns.Locale.Get("esES")) do
        assert.is_not_nil(en[key], "enUS is missing " .. key)
      end
    end)
  end)
end)
