-- Minimal WoW API stubs so addon logic can run under busted outside the client.
-- Extend only with the APIs a spec actually needs.

_G.C_AddOns = {
  GetAddOnMetadata = function()
    return "@project-version@"
  end,
}

_G.CreateFrame = function()
  local frame = { scripts = {}, events = {} }
  function frame:RegisterEvent(event)
    self.events[event] = true
  end
  function frame:UnregisterEvent(event)
    self.events[event] = nil
  end
  function frame:SetScript(name, handler)
    self.scripts[name] = handler
  end
  return frame
end

_G.GetBuildInfo = function()
  return "11.0.0", "00000", "Jan 1 2026", 16001
end

_G.UnitClass = function()
  return "Rogue", "ROGUE", 4
end
