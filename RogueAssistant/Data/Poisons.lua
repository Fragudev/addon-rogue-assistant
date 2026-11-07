local _, ns = ...

-- Rogue poison items, one family per poison with its ranks. Poisons are crafted bag items on Forever.
--
-- Rank numbers and required levels follow https://warcraft.wiki.gg/wiki/Rogue_abilities_(Forever) (the Forever list
-- links these items). The item ids come from the item pages that list links to (for example
-- https://warcraft.wiki.gg/wiki/Instant_Poison_II) and are Classic Era ids: no page confirms that Forever kept them,
-- so every entry says so in `source`. `/ras debug bags` lists the real ids of the poisons you carry; correct an entry
-- here when one differs and replace its source.
--
-- Blinding Powder (the same wiki list, level 34) is a reagent of Blind, not a poison, and is not listed.
local Poisons = {}

local UNVERIFIED = "classic-era, not verified on Forever"

local function entry(rank, itemID, level)
  return { rank = rank, itemID = itemID, level = level, source = UNVERIFIED }
end

-- `key` is the stable identifier, `nameKey` the locale key of the display name. Families keep the order shown in the
-- flyout; ranks run from the lowest to the highest.
Poisons.FAMILIES = {
  {
    key = "instant",
    nameKey = "poison.family.instant",
    ranks = {
      entry(1, 6947, 20),
      entry(2, 6949, 28),
      entry(3, 6950, 36),
      entry(4, 8926, 44),
      entry(5, 8927, 52),
      entry(6, 8928, 60),
    },
  },
  {
    key = "deadly",
    nameKey = "poison.family.deadly",
    ranks = {
      entry(1, 2892, 30),
      entry(2, 2893, 38),
      entry(3, 8984, 46),
      entry(4, 8985, 54),
    },
  },
  {
    key = "crippling",
    nameKey = "poison.family.crippling",
    ranks = {
      entry(1, 3775, 20),
      entry(2, 3776, 50),
    },
  },
  {
    key = "mindnumbing",
    nameKey = "poison.family.mindnumbing",
    ranks = {
      entry(1, 5237, 24),
      entry(2, 6951, 38),
      entry(3, 9186, 52),
    },
  },
  {
    key = "wound",
    nameKey = "poison.family.wound",
    ranks = {
      entry(1, 10918, 32),
      entry(2, 10920, 40),
      entry(3, 10921, 48),
      entry(4, 10922, 56),
    },
  },
}

-- itemID -> { family = <family>, rank = <entry> }, built once.
Poisons.BY_ITEM = {}
for _, family in ipairs(Poisons.FAMILIES) do
  for _, rank in ipairs(family.ranks) do
    Poisons.BY_ITEM[rank.itemID] = { family = family, rank = rank }
  end
end

-- The family key and the rank number of a poison item id, or nil when the id is not a known poison.
function Poisons.Lookup(itemID)
  local found = Poisons.BY_ITEM[itemID]
  if not found then
    return nil
  end
  return found.family.key, found.rank.rank
end

ns.Poisons = Poisons
