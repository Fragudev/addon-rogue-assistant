local _, ns = ...

-- /ras and /rogueassistant.
local Slash = {}

local C = ns.Constants
local Api = ns.Api
local L = ns.L
local Items = ns.Items
local Bar = ns.Bar
local Actions = ns.Actions

local HELP = { "help.title", "help.unlock", "help.lock", "help.reset", "help.warn", "help.minimap", "help.debug" }

local function printHelp()
  for _, key in ipairs(HELP) do
    Api.Print(L(key))
  end
end

local function setWarning(argument)
  local minutes = tonumber(argument)
  if not minutes or minutes ~= math.floor(minutes) or minutes < 0 or minutes > C.MAX_WARN_MINUTES or not ns.db then
    Api.Print(L("msg.warn.usage", C.MAX_WARN_MINUTES))
    return
  end
  ns.db.warnMinutes = minutes
  Api.Print(L("msg.warn", minutes))
  Bar.Tick(Api.Now())
end

local function debugBags()
  local found = false
  Api.Print(L("debug.bags.header"))
  Api.ForEachBagItem(function(itemID, count)
    found = true
    local entry = Items.BY_ID[itemID]
    local kind = entry and L("kind." .. entry.kind) or "-"
    Api.Print(string.format("%d x %d, %s, %s", itemID, count, Api.GetItemName(itemID) or "?", kind))
  end)
  if not found then
    Api.Print(L("debug.bags.none"))
  end
end

local function debugTooltips()
  for _, slot in ipairs(C.SLOTS) do
    local hand = L("slot." .. slot .. ".long")
    local lines = Api.GetInventoryTooltip(slot)
    if not lines then
      Api.Print(L("debug.tooltip.none", hand))
    else
      for _, line in ipairs(lines) do
        local text = line.hidden and "<secret>" or (line.left or "")
        if line.right then
          text = text .. " | " .. line.right
        end
        Api.Print(L("debug.tooltip.line", hand, text))
      end
    end
  end
end

local function debugWeapon()
  local raw = Api.GetWeaponEnchantRaw()
  if raw then
    Api.Print(string.format("GetWeaponEnchantInfo (%d): %s", #raw, table.concat(raw, ", ")))
  end
  debugTooltips()
  local enchants = Api.GetWeaponEnchants()
  if not enchants then
    Api.Print(L("debug.weapon.none"))
    return
  end
  for _, slot in ipairs(C.SLOTS) do
    local enchant = enchants[slot]
    local itemID = enchant.enchantID and ns.db and ns.db.enchants[enchant.enchantID]
    Api.Print(
      L(
        "debug.weapon.line",
        L("slot." .. slot .. ".long"),
        enchant.unknown and "secret" or tostring(enchant.active),
        tostring(enchant.ms),
        tostring(enchant.charges),
        tostring(enchant.enchantID),
        tostring(itemID)
      )
    )
  end
end

function Slash.Handle(input)
  local command, argument = string.match(string.lower(input or ""), "^%s*(%S*)%s*(.-)%s*$")
  if command == "" or command == "help" then
    printHelp()
  elseif command == "unlock" then
    Actions.SetLocked(false)
  elseif command == "lock" then
    Actions.SetLocked(true)
  elseif command == "reset" then
    Actions.ResetPosition()
  elseif command == "minimap" then
    Actions.ToggleMinimap()
  elseif command == "warn" then
    setWarning(argument)
  elseif command == "debug" and argument == "bags" then
    debugBags()
  elseif command == "debug" and argument == "weapon" then
    debugWeapon()
  else
    Api.Print(L("msg.unknown", command))
    printHelp()
  end
end

SLASH_RAS1 = "/ras"
SLASH_RAS2 = "/rogueassistant"
SlashCmdList.RAS = Slash.Handle

ns.Slash = Slash
