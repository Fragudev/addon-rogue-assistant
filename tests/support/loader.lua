-- Loads the addon files listed in the TOC into a fresh namespace, the way the client does.
local Loader = {}

local ADDON = "RogueAssistant"
local ROOT = ADDON .. "/"

-- The Lua files of the TOC, in load order.
function Loader.TocFiles()
  local files = {}
  for line in io.lines(ROOT .. ADDON .. ".toc") do
    local path = line:match("^%s*(%S+%.lua)%s*$")
    if path then
      files[#files + 1] = (path:gsub("\\", "/"))
    end
  end
  return files
end

-- Loads `files` (paths relative to the addon folder) into `ns`. Returns ns.
function Loader.Load(files, ns)
  ns = ns or {}
  for _, path in ipairs(files) do
    assert(loadfile(ROOT .. path))(ADDON, ns)
  end
  return ns
end

-- Loads every file of the TOC except Commands/Slash.lua and Core/Init.lua unless asked; pass the names to keep.
function Loader.Full(except)
  local skip = {}
  for _, path in ipairs(except or {}) do
    skip[path] = true
  end
  local files = {}
  for _, path in ipairs(Loader.TocFiles()) do
    if not skip[path] then
      files[#files + 1] = path
    end
  end
  return Loader.Load(files)
end

return Loader
