local _, ns = ...

-- Flat tables for the poison UI. No frames, no client calls: `deps.L` (texts) and `deps.iconFor(itemID)` (item icon)
-- are passed in, so everything here is testable.
local ViewModel = {}

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }

function ViewModel.RankText(rank)
  return ROMAN[rank] or tostring(rank)
end

local function textsOf(deps)
  return deps and deps.L or ns.L
end

-- Rows of the flyout, flat: the highest rank of every family first (family order), then the remaining ranks, family by
-- family, highest first. Each row: { itemID, family, rank, rankText, count, isTop, icon, text }.
function ViewModel.Flyout(catalog, deps)
  local L = textsOf(deps)
  local iconFor = deps and deps.iconFor
  local rows = {}
  local function add(family, rank, isTop)
    rows[#rows + 1] = {
      itemID = rank.itemID,
      family = family.key,
      rank = rank.rank,
      rankText = ViewModel.RankText(rank.rank),
      count = rank.count,
      isTop = isTop,
      icon = iconFor and iconFor(rank.itemID) or nil,
      text = L["poison.row"]:format(L[family.nameKey], ViewModel.RankText(rank.rank), rank.count),
    }
  end
  for _, family in ipairs(catalog.families) do
    add(family, family.ranks[1], true)
  end
  for _, family in ipairs(catalog.families) do
    for index = 2, #family.ranks do
      add(family, family.ranks[index], false)
    end
  end
  return rows
end

local function statusLine(L, slotName, slot)
  local label = L["poison.slot." .. slotName]
  if not slot or slot.weapon == false or not slot.has then
    return { label = label, known = slot ~= nil and slot.has ~= nil, text = L["poison.status.none"]:format(label) }
  end
  local minutes = slot.minutes and math.ceil(slot.minutes) or nil
  local text
  if minutes and slot.charges then
    text = L["poison.status.full"]:format(label, minutes, slot.charges)
  elseif minutes then
    text = L["poison.status.minutes"]:format(label, minutes)
  else
    text = L["poison.status.none"]:format(label)
  end
  return { label = label, known = true, minutes = minutes, charges = slot.charges, text = text }
end

-- The two status lines under the button: { mh = { label, known, minutes, charges, text }, oh = ... }.
-- `state` is WeaponState:Read() (nil = unknown).
function ViewModel.Status(state, deps)
  local L = textsOf(deps)
  return {
    mh = statusLine(L, "mh", state and state.mh),
    oh = statusLine(L, "oh", state and state.oh),
  }
end

-- Icon of the main button: the main hand poison when it is known, otherwise the addon logo.
function ViewModel.MainIcon(state, deps)
  local itemID = state and state.mh and state.mh.has and state.mh.itemID
  local icon = itemID and deps and deps.iconFor and deps.iconFor(itemID)
  return icon or ns.Constants.LOGO_TEXTURE
end

-- Text of one alert from PoisonAlerts.
function ViewModel.AlertText(alert, deps)
  local L = textsOf(deps)
  if alert.kind == "stock" then
    local family
    for _, definition in ipairs(ns.Poisons.FAMILIES) do
      if definition.key == alert.family then
        family = L[definition.nameKey]
      end
    end
    return L["alert.stock"]:format(family or tostring(alert.family), alert.stock)
  end
  local slot = L["poison.slot." .. alert.slot .. ".long"]
  if alert.kind == "none" then
    return L["alert.none"]:format(slot)
  elseif alert.kind == "expiring" then
    return L["alert.expiring"]:format(slot, alert.minutes)
  end
  return L["alert.charges"]:format(slot, alert.charges)
end

ns.ViewModelPoisons = ViewModel
