local _, ns = ...

-- The poisons the player carries, grouped by family. Pure: it reads a list of bag items and the poison data, nothing
-- else.
local Catalog = {}

-- `items` is Platform.GetBagItems(): { itemID, stackCount, ... }. Returns
--   { families = { { key, nameKey, total, ranks = { { itemID, rank, level, count } } } },  -- highest rank first
--     byFamily = { [key] = family }, byItem = { [itemID] = rank entry }, total }
-- Only families with at least one unit appear, in the order of the poison data. `families` can be replaced in tests.
function Catalog.Build(items, families)
  families = families or ns.Poisons.FAMILIES
  local counts = {}
  for _, item in ipairs(items or {}) do
    counts[item.itemID] = (counts[item.itemID] or 0) + (item.stackCount or 1)
  end

  local catalog = { families = {}, byFamily = {}, byItem = {}, total = 0 }
  for _, definition in ipairs(families) do
    local family = { key = definition.key, nameKey = definition.nameKey, total = 0, ranks = {} }
    for _, rank in ipairs(definition.ranks) do
      local count = counts[rank.itemID]
      if count and count > 0 then
        local row = { itemID = rank.itemID, rank = rank.rank, level = rank.level, count = count, family = family.key }
        family.ranks[#family.ranks + 1] = row
        family.total = family.total + count
        catalog.byItem[rank.itemID] = row
      end
    end
    if #family.ranks > 0 then
      table.sort(family.ranks, function(a, b)
        return a.rank > b.rank
      end)
      catalog.families[#catalog.families + 1] = family
      catalog.byFamily[family.key] = family
      catalog.total = catalog.total + family.total
    end
  end
  return catalog
end

-- Units of a family in the bags (0 when none).
function Catalog.Stock(catalog, familyKey)
  local family = catalog.byFamily[familyKey]
  return family and family.total or 0
end

ns.PoisonCatalog = Catalog
