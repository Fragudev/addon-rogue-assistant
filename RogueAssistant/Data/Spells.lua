local _, ns = ...

-- Default tracker groups (plan section 6.1). An entry is a spell the tracker follows:
--   spellId   the primary id; its name and icon are shown.
--   ids       every rank id when the spell has ranks (the entry matches an aura or a known spell by any of them).
--   kind      "cooldown" (ability cooldown), "buff" (aura on the player) or "debuff" (aura on the target).
--   stacks    true when the aura stack count is shown.
--   byName    true when the aura is matched by the name of `spellId` instead of by id (the aura id differs from the
--             spell id or is not measured yet).
--   always    true when the entry is shown even if the player does not know the spell (poisons are items).
--   source    where the id comes from, so each id can be checked against the client with /ras debug spells and
--             /ras debug auras.
--
-- Ids come from the spell pages of https://warcraft.wiki.gg (the "External links" of each page; the Forever list is
-- https://warcraft.wiki.gg/wiki/Rogue_abilities_(Forever)). Where that page links the id for Forever the source says
-- so. Otherwise the id is the Classic Era one and no page confirms that Forever kept it.
--
-- Left out because no Forever spell id or authoritative name could be confirmed: Thousand Cuts (the wiki page is the
-- retail Trickster talent) and Cutthroat (a Season of Discovery rune).
local Spells = {}

Spells.FOREVER = "warcraft.wiki.gg spell page, Forever link"
Spells.UNVERIFIED = "classic-era, not verified on Forever"
Spells.NAME_ONLY = "forever talent id; the buff id is not measured yet, matched by name"

local function make(kind, spellId, source, extra)
  local entry = { spellId = spellId, kind = kind, source = source }
  for key, value in pairs(extra or {}) do
    entry[key] = value
  end
  return entry
end

local function cooldown(spellId, source, extra)
  return make("cooldown", spellId, source, extra)
end

local function buff(spellId, source, extra)
  return make("buff", spellId, source, extra)
end

local function debuff(spellId, source, extra)
  return make("debuff", spellId, source, extra)
end

local FOREVER, UNVERIFIED = Spells.FOREVER, Spells.UNVERIFIED

-- Group order is the order they are created in. `titleKey` is a locale key.
Spells.GROUPS = {
  {
    id = "essentials",
    titleKey = "tracker.group.essentials",
    kind = "cooldown",
    entries = {
      cooldown(1856, UNVERIFIED, { ids = { 1856, 1857 } }), -- Vanish
      cooldown(5277, UNVERIFIED, { ids = { 5277, 26669 } }), -- Evasion
      cooldown(2983, UNVERIFIED, { ids = { 2983, 11305 } }), -- Sprint
      cooldown(1766, UNVERIFIED, { ids = { 1766, 1769 } }), -- Kick
      cooldown(2094, FOREVER), -- Blind
      cooldown(408, UNVERIFIED, { ids = { 408, 8643 } }), -- Kidney Shot
      cooldown(1776, UNVERIFIED), -- Gouge
      cooldown(14177, FOREVER), -- Cold Blood
      cooldown(13750, UNVERIFIED), -- Adrenaline Rush
      cooldown(13877, FOREVER), -- Blade Flurry
      cooldown(14185, UNVERIFIED), -- Preparation
      cooldown(1316709, FOREVER), -- Death Mark
      cooldown(14278, FOREVER), -- Ghostly Strike
      cooldown(14183, FOREVER), -- Premeditation
    },
  },
  {
    id = "buffs",
    titleKey = "tracker.group.buffs",
    kind = "buff",
    entries = {
      buff(1784, UNVERIFIED), -- Stealth
      -- Poised: 1328825 is the passive. The buff id is not measured, so the aura is matched by the passive's name.
      buff(1328825, "warcraft.wiki.gg Poised (rogue ability) page; the buff id is not measured, matched by name", {
        byName = true,
      }),
      buff(5171, UNVERIFIED, { ids = { 5171, 6774 } }), -- Slice and Dice
      buff(1310703, Spells.NAME_ONLY, { byName = true }), -- Venom
      buff(14177, FOREVER), -- Cold Blood
      buff(13750, UNVERIFIED), -- Adrenaline Rush
      buff(13877, FOREVER), -- Blade Flurry
      buff(5277, UNVERIFIED, { ids = { 5277, 26669 } }), -- Evasion
      buff(2983, UNVERIFIED, { ids = { 2983, 11305 } }), -- Sprint
    },
  },
  {
    id = "target",
    titleKey = "tracker.group.target",
    kind = "debuff",
    entries = {
      debuff(1943, UNVERIFIED, { ids = { 1943, 11275 } }), -- Rupture
      debuff(703, UNVERIFIED, { ids = { 703, 11290 } }), -- Garrote
      debuff(8647, UNVERIFIED, { ids = { 8647, 11198 } }), -- Expose Armor
      -- Poisons: the debuff id is not the id of the poison spell, so they match by name and are always listed.
      debuff(2823, UNVERIFIED, { byName = true, always = true, stacks = true }), -- Deadly Poison
      debuff(3408, UNVERIFIED, { byName = true, always = true }), -- Crippling Poison
      debuff(8679, UNVERIFIED, { byName = true, always = true }), -- Wound Poison
      debuff(408, UNVERIFIED, { ids = { 408, 8643 } }), -- Kidney Shot
      debuff(1833, UNVERIFIED), -- Cheap Shot
    },
  },
}

ns.Spells = Spells
