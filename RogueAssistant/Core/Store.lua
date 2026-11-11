local _, ns = ...

-- Saved variables. The shape is versioned: data of any other version (including the previous addon) is replaced.
--   warnMinutes  number   the warning lights up below this many minutes left (0 = only when nothing is applied)
--   position     table?   { point, relativePoint, x, y } of the bar; nil = default position
--   enchants     table    enchant id -> item id, learned when the addon applies an item
--   minimapAngle number   degrees of the minimap button around the minimap (0 = east, 90 = north)
--   minimapHidden boolean the minimap button is hidden (/ras minimap shows it again)
local Store = {}

local C = ns.Constants

local function validPosition(position)
  return type(position) == "table"
    and type(position.point) == "string"
    and type(position.relativePoint) == "string"
    and type(position.x) == "number"
    and type(position.y) == "number"
end

-- Returns the saved table to use, repaired in place when possible.
function Store.Load(saved)
  if type(saved) ~= "table" or saved.version ~= C.DB_VERSION then
    saved = { version = C.DB_VERSION }
  end
  local warn = saved.warnMinutes
  if type(warn) ~= "number" or warn < 0 or warn > C.MAX_WARN_MINUTES then
    saved.warnMinutes = C.DEFAULT_WARN_MINUTES
  end
  if not validPosition(saved.position) then
    saved.position = nil
  end
  if type(saved.enchants) ~= "table" then
    saved.enchants = {}
  end
  local angle = saved.minimapAngle
  if type(angle) ~= "number" or not (angle >= 0 and angle < 360) then
    saved.minimapAngle = C.DEFAULT_MINIMAP_ANGLE
  end
  if type(saved.minimapHidden) ~= "boolean" then
    saved.minimapHidden = false
  end
  return saved
end

ns.Store = Store
