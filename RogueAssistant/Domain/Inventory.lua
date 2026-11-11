local _, ns = ...

-- What the bags hold that can go on a weapon. `api` is ns.Api (or a fake with the same functions).
local Inventory = {}

local Items = ns.Items

-- itemID -> total count of every catalog item in the bags.
function Inventory.Counts(api)
  local counts = {}
  api.ForEachBagItem(function(itemID, count)
    if Items.BY_ID[itemID] then
      counts[itemID] = (counts[itemID] or 0) + count
    end
  end)
  return counts
end

-- The weapon in `slot`: nil when unknown, { empty = true } when the slot is empty, or { classID, subclassID }.
function Inventory.DescribeWeapon(api, slot)
  local itemID = api.GetEquippedItemID(slot)
  if itemID == false then
    return { empty = true }
  end
  if itemID == nil then
    return nil
  end
  local info = api.GetItemInstant(itemID)
  if not info then
    return nil
  end
  return { classID = info.classID, subclassID = info.subclassID }
end

-- The ordered list of { itemID, count, kind } in the bags that fit `weapon`.
function Inventory.Applicable(counts, weapon)
  local list = {}
  for _, entry in ipairs(Items.LIST) do
    local count = counts[entry.itemID]
    if count and count > 0 and Items.Fits(entry, weapon) then
      list[#list + 1] = { itemID = entry.itemID, count = count, kind = entry.kind }
    end
  end
  return list
end

ns.Inventory = Inventory
