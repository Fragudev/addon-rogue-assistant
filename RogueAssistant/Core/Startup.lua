local _, ns = ...

-- Modules register a starter while their file loads; Init runs them once, on a rogue, after the profile and the
-- settings exist (ns.profile, ns.settings, ns.bus). A starter that raises never stops the others: the error goes to
-- the debug log.
local Startup = { starters = {} }

function Startup.Register(starter)
  if type(starter) ~= "function" then
    error("Startup.Register expects a function", 2)
  end
  Startup.starters[#Startup.starters + 1] = starter
end

-- Runs every starter in registration order. Returns how many ran without error.
function Startup.Run()
  local started = 0
  for _, starter in ipairs(Startup.starters) do
    local ok, err = pcall(starter)
    if ok then
      started = started + 1
    elseif ns.store then
      ns.store:Log("startup failed: " .. tostring(err))
    end
  end
  return started
end

ns.Startup = Startup
