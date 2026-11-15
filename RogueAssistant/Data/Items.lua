local _, ns = ...

-- Items a rogue can apply to a weapon: poisons, sharpening stones, weightstones and weapon oils.
--
-- Poison ranks follow https://warcraft.wiki.gg/wiki/Rogue_abilities_(Forever); the item ids come from the item pages
-- it links to (for example https://warcraft.wiki.gg/wiki/Instant_Poison_II). Stones and oils come from their
-- warcraft.wiki.gg item pages. All of them are Classic Era ids that nobody has confirmed on Forever yet:
-- `/ras debug bags` prints the real ids of what you carry, so an entry can be corrected.
--
-- Order matters: the flyout lists kinds in KIND_ORDER and, inside a kind, items in the order written here (strongest
-- first).
local Items = {}

Items.KIND_ORDER = { "poison", "sharpening", "weightstone", "oil" }

-- Weapon item class and the subclasses that decide which stone fits.
-- https://warcraft.wiki.gg/wiki/ItemType (Enum.ItemClass.Weapon, Enum.ItemWeaponSubclass)
Items.WEAPON_CLASS = 2
-- Axes, polearm, swords, dagger.
local SHARP = { [0] = true, [1] = true, [6] = true, [7] = true, [8] = true, [15] = true }
local BLUNT = { [4] = true, [5] = true, [10] = true } -- maces, staff

local LIST = {
  -- Poisons, by family, highest rank first.
  { itemID = 8928, kind = "poison" }, -- Instant Poison VI
  { itemID = 8927, kind = "poison" }, -- Instant Poison V
  { itemID = 8926, kind = "poison" }, -- Instant Poison IV
  { itemID = 6950, kind = "poison" }, -- Instant Poison III
  { itemID = 6949, kind = "poison" }, -- Instant Poison II
  { itemID = 6947, kind = "poison" }, -- Instant Poison
  { itemID = 8985, kind = "poison" }, -- Deadly Poison IV
  { itemID = 8984, kind = "poison" }, -- Deadly Poison III
  { itemID = 2893, kind = "poison" }, -- Deadly Poison II
  { itemID = 2892, kind = "poison" }, -- Deadly Poison
  -- Crippling Poison has no charges: the API reports 0 for it while it is active.
  { itemID = 3776, kind = "poison", noCharges = true }, -- Crippling Poison II
  { itemID = 3775, kind = "poison", noCharges = true }, -- Crippling Poison
  { itemID = 9186, kind = "poison" }, -- Mind-numbing Poison III
  { itemID = 6951, kind = "poison" }, -- Mind-numbing Poison II
  { itemID = 5237, kind = "poison" }, -- Mind-numbing Poison
  { itemID = 10922, kind = "poison" }, -- Wound Poison IV
  { itemID = 10921, kind = "poison" }, -- Wound Poison III
  { itemID = 10920, kind = "poison" }, -- Wound Poison II
  { itemID = 10918, kind = "poison" }, -- Wound Poison

  -- Sharpening stones (edged weapons).
  { itemID = 23122, kind = "sharpening" }, -- Consecrated Sharpening Stone
  { itemID = 18262, kind = "sharpening" }, -- Elemental Sharpening Stone
  { itemID = 12404, kind = "sharpening" }, -- Dense Sharpening Stone
  { itemID = 7964, kind = "sharpening" }, -- Solid Sharpening Stone
  { itemID = 2871, kind = "sharpening" }, -- Heavy Sharpening Stone
  { itemID = 2863, kind = "sharpening" }, -- Coarse Sharpening Stone
  { itemID = 2862, kind = "sharpening" }, -- Rough Sharpening Stone

  -- Weightstones (blunt weapons).
  { itemID = 12643, kind = "weightstone" }, -- Dense Weightstone
  { itemID = 7965, kind = "weightstone" }, -- Solid Weightstone
  { itemID = 3241, kind = "weightstone" }, -- Heavy Weightstone
  { itemID = 3240, kind = "weightstone" }, -- Coarse Weightstone
  { itemID = 3239, kind = "weightstone" }, -- Rough Weightstone

  -- Weapon oils (any weapon).
  { itemID = 23123, kind = "oil" }, -- Blessed Wizard Oil
  { itemID = 20749, kind = "oil" }, -- Brilliant Wizard Oil
  { itemID = 20748, kind = "oil" }, -- Brilliant Mana Oil
  { itemID = 20750, kind = "oil" }, -- Wizard Oil
  { itemID = 20747, kind = "oil" }, -- Lesser Mana Oil
  { itemID = 20746, kind = "oil" }, -- Lesser Wizard Oil
  { itemID = 20745, kind = "oil" }, -- Minor Mana Oil
  { itemID = 20744, kind = "oil" }, -- Minor Wizard Oil
  { itemID = 3829, kind = "oil" }, -- Frost Oil
  { itemID = 3824, kind = "oil" }, -- Shadow Oil
}

local KIND_RANK = {}
for index, kind in ipairs(Items.KIND_ORDER) do
  KIND_RANK[kind] = index
end

-- Stable sort: by kind, then by position in LIST.
for index, entry in ipairs(LIST) do
  entry.position = index
end
table.sort(LIST, function(a, b)
  if KIND_RANK[a.kind] ~= KIND_RANK[b.kind] then
    return KIND_RANK[a.kind] < KIND_RANK[b.kind]
  end
  return a.position < b.position
end)

Items.LIST = LIST
Items.BY_ID = {}
for _, entry in ipairs(LIST) do
  Items.BY_ID[entry.itemID] = entry
end

-- Whether `entry` can go on `weapon`. `weapon` is nil when unknown (everything is offered and the game decides),
-- { empty = true } for an empty slot, or { classID, subclassID }.
function Items.Fits(entry, weapon)
  if weapon == nil then
    return true
  end
  if weapon.empty or weapon.classID ~= Items.WEAPON_CLASS then
    return false
  end
  local subclass = weapon.subclassID
  if entry.kind == "sharpening" then
    return not BLUNT[subclass]
  end
  if entry.kind == "weightstone" then
    return not SHARP[subclass]
  end
  return true
end

ns.Items = Items
