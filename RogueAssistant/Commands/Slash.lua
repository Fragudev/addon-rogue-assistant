local _, ns = ...

-- /ras and /rogueassistant. Later phases add their own with Slash.Register (/ras <name>) and Slash.RegisterDebug
-- (/ras debug <name>); a handler receives the rest of the line after the name.
local Slash = { commands = {}, debugCommands = {} }

local PREFIX = "|cfffff569Rogue Assistant|r"

local function say(text)
  print(PREFIX .. " " .. text)
end

local function printLines(lines)
  for _, line in ipairs(lines) do
    print(line)
  end
end

local function register(list, name, handler, helpKey)
  for _, entry in ipairs(list) do
    if entry.name == name then
      entry.handler, entry.helpKey = handler, helpKey
      return
    end
  end
  list[#list + 1] = { name = name, handler = handler, helpKey = helpKey }
end

local function find(list, name)
  for _, entry in ipairs(list) do
    if entry.name == name then
      return entry
    end
  end
  return nil
end

-- Adds or replaces /ras <name>. `helpKey` is the locale key of its help line.
function Slash.Register(name, handler, helpKey)
  register(Slash.commands, name, handler, helpKey)
end

-- Adds or replaces /ras debug <name>.
function Slash.RegisterDebug(name, handler, helpKey)
  register(Slash.debugCommands, name, handler, helpKey)
end

local function splitFirst(text)
  local word, rest = (text or ""):match("^%s*(%S*)%s*(.-)%s*$")
  return word:lower(), rest
end

local function printHelp()
  local L = ns.L
  say(L["cmd.help.header"])
  print("  " .. L["cmd.help.root"])
  print("  " .. L["cmd.help.help"])
  for _, entry in ipairs(Slash.commands) do
    print("  " .. L[entry.helpKey])
  end
end

local function printDebugHelp()
  local L = ns.L
  say(L["cmd.debug.header"])
  for _, entry in ipairs(Slash.debugCommands) do
    print("  " .. L[entry.helpKey])
  end
end

local function runEntry(entry, rest)
  local ok, err = pcall(entry.handler, rest)
  if not ok then
    say(ns.L["cmd.error"]:format(entry.name, tostring(err)))
  end
end

-- Handles one line typed after /ras.
function Slash.Dispatch(message)
  local name, rest = splitFirst(message)
  if name == "help" then
    printHelp()
    return
  end
  if name == "" then
    say(ns.L["cmd.later"])
    return
  end
  local entry = find(Slash.commands, name)
  if entry then
    runEntry(entry, rest)
  else
    say(ns.L["cmd.unknown"]:format(name))
    printHelp()
  end
end

local function later()
  say(ns.L["cmd.later"])
end

Slash.Register("unlock", later, "cmd.help.unlock")
Slash.Register("lock", later, "cmd.help.lock")

Slash.Register("debug", function(rest)
  local name, args = splitFirst(rest)
  local entry = find(Slash.debugCommands, name)
  if entry then
    runEntry(entry, args)
  else
    printDebugHelp()
  end
end, "cmd.help.debug")

Slash.RegisterDebug("probe", function()
  local lines = ns.Probe.Run()
  printLines(lines)
  if ns.store then
    ns.store:SetLastProbe(lines)
    say(ns.L["debug.probe.saved"]:format(#lines))
  end
end, "cmd.debug.probe")

Slash.RegisterDebug("bags", function()
  printLines(ns.Probe.BagLines())
end, "cmd.debug.bags")

Slash.RegisterDebug("spells", function()
  printLines(ns.Probe.SpellLines())
end, "cmd.debug.spells")

Slash.RegisterDebug("auras", function()
  printLines(ns.Probe.AuraLines())
end, "cmd.debug.auras")

Slash.RegisterDebug("selftest", function()
  printLines(ns.Probe.SelfTest())
end, "cmd.debug.selftest")

for index, command in ipairs(ns.Constants.SLASH_COMMANDS) do
  _G["SLASH_RAS" .. index] = command
end
SlashCmdList["RAS"] = Slash.Dispatch

ns.Slash = Slash
