-- BetterGearing: score items against a profile and compare with equipped gear.
local _, BG = ...

local SIMPLE_SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}

local MAIN, OFF = 16, 17

BG.DUAL_WIELD_CLASSES = { HUNTER = true, ROGUE = true, WARRIOR = true }

-- Every slot that holds scored gear (no shirt or tabard).
BG.GEAR_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

local function CanDualWield()
    if type(_G.CanDualWield) == "function" then
        local ok, result = pcall(_G.CanDualWield)
        if ok then
            return result and true or false
        end
    end
    local _, classFile = UnitClass("player")
    return BG.DUAL_WIELD_CLASSES[classFile] or false
end

--[[ "Who": whose gear an item is judged against.
    The logged-in character by default; Preview.lua builds the same shape for other characters.
      class, level, dualWield
      Link(slot)  : link of the item worn in that slot, or nil
      isPlayer    : the logged-in character (red tooltip text then decides usability)
      noGear      : nothing is known about the gear (a spec preview), only raw scores make sense
]]
function BG:PlayerWho()
    local _, classFile = UnitClass("player")
    return {
        isPlayer = true, class = classFile, level = UnitLevel("player") or 1, dualWield = CanDualWield(),
        Link = function(slot) return GetInventoryItemLink("player", slot) end,
    }
end

function BG:Score(info, profile)
    local total = 0
    for stat, value in pairs(info.stats) do
        total = total + value * self:GetWeight(profile, stat)
    end
    return total
end

-- "Wrong stats" rule: true when most of the item's stat budget sits in stats this
-- profile barely values (for example spell power on a hunter). A stat counts as wasted
-- when its weight per budget point is under 10% of the profile's best stat.
function BG:IsMismatch(info, profile)
    local best = 0
    for stat, budget in pairs(self.STAT_BUDGET) do
        local efficiency = self:GetWeight(profile, stat) / budget
        if efficiency > best then
            best = efficiency
        end
    end
    if best <= 0 then
        return false
    end
    -- Spell power counts as both healing and spell damage. Judge that shared part once,
    -- by whichever of the two this profile values more, so a healer's spell power is not
    -- half "wasted" (and neither is a caster's).
    local skipStat, skipValue
    local heal, spdmg = info.stats.heal or 0, info.stats.spdmg or 0
    if heal > 0 and spdmg > 0 then
        local healWorth = self:GetWeight(profile, "heal") / self.STAT_BUDGET.heal
        local dmgWorth = self:GetWeight(profile, "spdmg") / self.STAT_BUDGET.spdmg
        skipStat = healWorth > dmgWorth and "spdmg" or "heal"
        skipValue = math.min(heal, spdmg)
    end

    local useful, wasted = 0, 0
    for stat, value in pairs(info.stats) do
        local budget = self.STAT_BUDGET[stat] or (stat:find("^school:") and 0.7)
        if stat == skipStat then
            value = value - skipValue
        end
        -- Stamina is on almost everything and never makes an item wrong for a spec.
        if budget and stat ~= "sta" and value > 0 then
            local points = value * budget
            if self:GetWeight(profile, stat) / budget < best * 0.1 then
                wasted = wasted + points
            else
                useful = useful + points
            end
        end
    end
    return wasted >= 3 and wasted > useful
end

-- Equipped item info for a slot: info table, false when the slot is empty, nil when not cached yet.
local function Equipped(slot, who)
    local link = who.Link(slot)
    if not link then
        return false
    end
    return BG:GetItem(link)
end

-- Score of everything the character wears, or nil while some of it is not cached yet.
-- Upgrade percentages are measured against this, not against the single item replaced:
-- at low level that item often scores almost nothing and the percentage explodes.
function BG:TotalScore(profile, who)
    who = who or self:PlayerWho()
    local total = 0
    for _, slot in ipairs(self.GEAR_SLOTS) do
        local equipped = Equipped(slot, who)
        if equipped == nil then
            return nil
        end
        if equipped then
            total = total + self:Score(equipped, profile)
        end
    end
    return total
end

-- Item ID plus random suffix ("of the Bear"), ignoring enchants, gems and the per-copy unique ID,
-- so a crafting recipe result or a bag copy matches the same item being worn.
local function ItemKey(link)
    local itemString = link and link:match("item:([%-%d:]+)")
    if not itemString then
        return link
    end
    local fields = { strsplit(":", itemString) }
    return (fields[1] or "") .. ":" .. (fields[7] or "")
end

local function IsWeaponLoc(loc)
    return loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONOFFHAND" or loc == "INVTYPE_WEAPONMAINHAND"
end

-- Which sets of equipped slots could this item replace? Returns options, blockedReason.
local function ReplaceOptions(info, profile, who)
    local loc = info.equipLoc
    local simple = SIMPLE_SLOTS[loc]
    if simple then
        local options = {}
        for _, slot in ipairs(simple) do
            table.insert(options, { slot })
        end
        return options
    end

    local main, off = Equipped(MAIN, who), Equipped(OFF, who)
    if main == nil or off == nil then
        return nil, "pending"
    end
    local mainIsTwoHand = main and main.equipLoc == "INVTYPE_2HWEAPON"

    if loc == "INVTYPE_2HWEAPON" then
        if profile.needShield then
            return nil, "shield"
        end
        return { { MAIN, OFF } }
    elseif loc == "INVTYPE_WEAPONMAINHAND" then
        return { { MAIN } }
    elseif loc == "INVTYPE_WEAPON" then
        local options = { { MAIN } }
        if not profile.needShield and not mainIsTwoHand and who.dualWield
            and (off == false or IsWeaponLoc(off.equipLoc)) then
            table.insert(options, { OFF })
        end
        return options
    elseif loc == "INVTYPE_WEAPONOFFHAND" then
        if profile.needShield then
            return nil, "shield"
        end
        if mainIsTwoHand or not who.dualWield then
            return nil, "offhand"
        end
        return { { OFF } }
    elseif loc == "INVTYPE_SHIELD" or loc == "INVTYPE_HOLDABLE" then
        if mainIsTwoHand and not profile.needShield then
            return nil, "offhand"
        end
        return { { OFF } }
    end
    return nil, "notgear"
end

--[[ BG:Compare(link, profile[, who])
    Returns a result table:
      pending   : true when item data is not loaded yet
      reason    : nil when comparable, else "notgear" | "equipped" | "unusable" | "mismatch" | "shield" | "offhand"
      level     : required level when the character is too low (still compared)
      score, base, delta, diffs = { stat = change }
      upgrade   : true when it should get an arrow for this profile
]]
function BG:Compare(link, profile, who)
    who = who or self:PlayerWho()
    local info = self:GetItem(link)
    if not info then
        return { pending = true }
    end
    if info.notGear then
        return { reason = "notgear" }
    end

    local result = { score = self:Score(info, profile) }
    local usable, needLevel, training
    if who.isPlayer then
        usable, needLevel, training = not info.unusable, info.minLevel, info.needsTraining
    else
        -- Red tooltip text describes the logged-in character, so judge by class rules instead.
        usable, needLevel = self:UsableBy(info, who.class)
    end
    if not usable then
        result.reason = "unusable"
        return result
    end

    local options, blocked = ReplaceOptions(info, profile, who)
    if blocked == "pending" then
        return { pending = true }
    end
    if not options then
        result.reason = blocked
        return result
    end

    -- Swapping an item for another copy of itself is no change, so skip slots already holding it.
    -- When every option is such a slot the item counts as equipped. A second copy of a ring or
    -- one-hander can still be compared against the other ring or weapon slot.
    local key = ItemKey(link)
    local best
    for _, slots in ipairs(options) do
        local base, diffs, same = 0, {}, false
        for stat, value in pairs(info.stats) do
            diffs[stat] = value
        end
        for _, slot in ipairs(slots) do
            local equipped = Equipped(slot, who)
            if equipped == nil then
                return { pending = true }
            end
            if equipped then
                if equipped.link == link then
                    result.reason = "equipped"
                    return result
                end
                if ItemKey(equipped.link) == key then
                    same = true
                end
                base = base + self:Score(equipped, profile)
                for stat, value in pairs(equipped.stats) do
                    diffs[stat] = (diffs[stat] or 0) - value
                end
            end
        end
        local delta = result.score - base
        if not same and (not best or delta > best.delta) then
            best = { delta = delta, base = base, diffs = diffs }
        end
    end
    if not best then
        result.reason = "equipped"
        return result
    end

    result.delta, result.base, result.diffs = best.delta, best.base, best.diffs

    if self:IsMismatch(info, profile) then
        result.reason = "mismatch"
        return result
    end
    if needLevel > who.level then
        result.level = needLevel
    end
    result.better = best.delta > math.max(0.1, best.base * 0.01)
    result.training = training or nil
    result.upgrade = result.better and not result.level and not result.training
    return result
end

-- Short "why" text for a comparison: the stat changes that matter most to the profile.
function BG:DescribeDiffs(result, profile, maxParts)
    if not result.diffs then
        return nil
    end
    local parts = {}
    for stat, change in pairs(result.diffs) do
        local weighted = change * self:GetWeight(profile, stat)
        if math.abs(weighted) > 0.05 then
            table.insert(parts, { stat = stat, change = change, weighted = weighted })
        end
    end
    table.sort(parts, function(a, b) return math.abs(a.weighted) > math.abs(b.weighted) end)
    local texts = {}
    for i = 1, math.min(maxParts or 4, #parts) do
        local part = parts[i]
        local amount = math.abs(part.change)
        local number = (amount == math.floor(amount)) and tostring(amount) or string.format("%.1f", amount)
        local short = self.STAT_SHORT[part.stat] or (part.stat:gsub("^school:(.+)$", "%1 spell dmg"))
        local glue = short:sub(1, 1) == "%" and "" or " "
        local color = part.change > 0 and "|cff40ff40+" or "|cffff4040-"
        table.insert(texts, color .. number .. glue .. short .. "|r")
    end
    return #texts > 0 and table.concat(texts, ", ") or nil
end

-- Is this comparison worth an arrow? Returns counts, soonLevel. With lookahead, an upgrade that only
-- waits on its required level counts too when that level is at most lookahead levels away
-- (soonLevel = that level).
local function ArrowWorthy(result, lookahead, level)
    if result.upgrade then
        return true, nil
    end
    if lookahead and result.better and result.level and not result.training
        and result.level - level <= lookahead then
        return true, result.level
    end
    return false, nil
end

--[[ Arrow state: nil = not known yet, false = no arrow,
    "active" = upgrade for the active profile, "other" = upgrade only for another profile of this spec.
    Second return value: the required level when it is an upgrade only once the character reaches
    that level (only with lookahead, used by the recipe list).
]]
function BG:BagState(link, lookahead)
    return self:ArrowState(link, lookahead)
end

--[[ BG:ArrowState(link, lookahead[, target])
    Same as BagState, for any character. target = { who, profiles, active } (see BG:ArrowTarget);
    defaults to the logged-in character.
]]
function BG:ArrowState(link, lookahead, target)
    local who, profiles, active
    if target then
        who, profiles, active = target.who, target.profiles, target.active
    else
        who, profiles, active = self:PlayerWho(), self:GetProfiles(), self:GetActiveProfile()
    end
    if not active or not link then
        return false
    end
    local result = self:Compare(link, active, who)
    if result.pending then
        return nil
    end
    if result.reason == "notgear" or result.reason == "unusable" or result.reason == "equipped" then
        return false
    end
    local level = who.level or 1
    local counts, soon = ArrowWorthy(result, lookahead, level)
    if counts then
        return "active", soon
    end
    for _, profile in ipairs(profiles) do
        if profile ~= active then
            local other = self:Compare(link, profile, who)
            if other.pending then
                return nil
            end
            counts, soon = ArrowWorthy(other, lookahead, level)
            if counts then
                return "other", soon
            end
        end
    end
    return false
end
