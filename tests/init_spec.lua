local ROOT = "RogueAssistant/"
local ADDON = "RogueAssistant"

describe("Init", function()
  local ns, frame, realCreateFrame

  before_each(function()
    ns = {}
    realCreateFrame = _G.CreateFrame
    _G.CreateFrame = function(...)
      frame = realCreateFrame(...)
      return frame
    end
    assert(loadfile(ROOT .. "Core/Init.lua"))(ADDON, ns)
  end)

  after_each(function()
    _G.CreateFrame = realCreateFrame
  end)

  it("creates the addon namespace", function()
    assert.are.equal(ADDON, ns.name)
  end)

  it("registers ADDON_LOADED", function()
    assert.is_true(frame.events["ADDON_LOADED"])
  end)

  it("accepts ADDON_LOADED for its own addon", function()
    assert.has_no.errors(function()
      frame.scripts.OnEvent(frame, "ADDON_LOADED", ADDON)
    end)
  end)

  it("ignores ADDON_LOADED for other addons", function()
    assert.has_no.errors(function()
      frame.scripts.OnEvent(frame, "ADDON_LOADED", "SomethingElse")
    end)
  end)
end)
