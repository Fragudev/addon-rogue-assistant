local _, ns = ...

-- Rules that tell the player a poison needs attention. Settings: alerts.expireMinutes, alerts.charges, alerts.stock
-- (0 turns a rule off) and alerts.triggers.<instance|readycheck|combatEnd>.
--
--   alert = { key, kind = "none" | "expiring" | "charges" | "stock", slot = "mh" | "oh" (not for stock),
--             minutes, charges, family, stock }
--
-- Check(trigger) returns only the alerts that were not already active at the previous check, and nothing in combat.
local Alerts = {}
Alerts.__index = Alerts

local SLOTS = { "mh", "oh" }

-- `deps.settings`, `deps.weaponState`; `deps.platform` and `deps.catalog` default to ns.Platform and
-- ns.PoisonCatalog.
function Alerts.New(deps)
  return setmetatable({
    settings = deps.settings,
    weaponState = deps.weaponState,
    platform = deps.platform or ns.Platform,
    catalog = deps.catalog or ns.PoisonCatalog,
    active = {},
  }, Alerts)
end

local function slotAlerts(slotName, slot, expireMinutes, chargeLimit, found)
  if slot.weapon == false or slot.has == nil then
    return
  end
  if not slot.has then
    found[#found + 1] = { key = slotName .. ":none", kind = "none", slot = slotName }
    return
  end
  if expireMinutes > 0 and slot.minutes and slot.minutes < expireMinutes then
    found[#found + 1] = {
      key = slotName .. ":expiring",
      kind = "expiring",
      slot = slotName,
      minutes = math.ceil(slot.minutes),
    }
  end
  if chargeLimit > 0 and slot.charges and slot.charges < chargeLimit then
    found[#found + 1] = {
      key = slotName .. ":charges",
      kind = "charges",
      slot = slotName,
      charges = slot.charges,
    }
  end
end

-- Every alert that applies right now (no deduplication, no combat check). nil when the weapons cannot be read.
function Alerts:Evaluate()
  local state = self.weaponState:Read()
  if not state then
    return nil
  end
  local settings = self.settings
  local expireMinutes = settings:Get("alerts.expireMinutes")
  local chargeLimit = settings:Get("alerts.charges")
  local stockLimit = settings:Get("alerts.stock")

  local found = {}
  for _, name in ipairs(SLOTS) do
    slotAlerts(name, state[name], expireMinutes, chargeLimit, found)
  end

  if stockLimit > 0 then
    local catalog = self.catalog.Build(self.platform.GetBagItems())
    local seen = {}
    for _, name in ipairs(SLOTS) do
      local itemID = state[name].has and state[name].itemID
      local familyKey = itemID and ns.Poisons.Lookup(itemID)
      if familyKey and not seen[familyKey] then
        seen[familyKey] = true
        local stock = self.catalog.Stock(catalog, familyKey)
        if stock < stockLimit then
          found[#found + 1] = { key = "stock:" .. familyKey, kind = "stock", family = familyKey, stock = stock }
        end
      end
    end
  end
  return found
end

-- Alerts for a trigger ("instance", "readycheck" or "combatEnd"): the ones that were not active at the previous check.
-- Returns {} in combat, for a disabled trigger and when the weapons cannot be read; those cases leave the
-- deduplication state untouched.
function Alerts:Check(trigger)
  if self.platform.InCombatLockdown() == true then
    return {}
  end
  if self.settings:Get("alerts.triggers." .. tostring(trigger)) ~= true then
    return {}
  end
  local found = self:Evaluate()
  if not found then
    return {}
  end
  local fresh, current = {}, {}
  for _, alert in ipairs(found) do
    current[alert.key] = true
    if not self.active[alert.key] then
      fresh[#fresh + 1] = alert
    end
  end
  self.active = current
  return fresh
end

-- Forgets what was already reported: the next check reports everything that applies.
function Alerts:Reset()
  self.active = {}
end

ns.PoisonAlerts = Alerts

ns.Startup.Register(function()
  ns.poisonAlerts = Alerts.New({ settings = ns.settings, weaponState = ns.weaponState })
end)
