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

local DUAL_WIELD_CLASSES = { HUNTER = true, ROGUE = true, WARRIOR = true }

local function CanDualWield()
    if type(_G.CanDualWield) == "function" then
        local ok, result = pcall(_G.CanDualWield)
        if ok then
            return result and true or false
        end
    end
    local _, classFile = UnitClass("player")
    return DUAL_WIELD_CLASSES[classFile] or false
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
local function Equipped(slot)
    local link = GetInventoryItemLink("player", slot)
    if not link then
        return false
    end
    return BG:GetItem(link)
end

local function IsWeaponLoc(loc)
    return loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONOFFHAND" or loc == "INVTYPE_WEAPONMAINHAND"
end

-- Which sets of equipped slots could this item replace? Returns options, blockedReason.
local function ReplaceOptions(info, profile)
    local loc = info.equipLoc
    local simple = SIMPLE_SLOTS[loc]
    if simple then
        local options = {}
        for _, slot in ipairs(simple) do
            table.insert(options, { slot })
        end
        return options
    end

    local main, off = Equipped(MAIN), Equipped(OFF)
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
        if not profile.needShield and not mainIsTwoHand and CanDualWield()
            and (off == false or IsWeaponLoc(off.equipLoc)) then
            table.insert(options, { OFF })
        end
        return options
    elseif loc == "INVTYPE_WEAPONOFFHAND" then
        if profile.needShield then
            return nil, "shield"
        end
        if mainIsTwoHand or not CanDualWield() then
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

--[[ BG:Compare(link, profile)
    Returns a result table:
      pending   : true when item data is not loaded yet
      reason    : nil when comparable, else "notgear" | "equipped" | "unusable" | "mismatch" | "shield" | "offhand"
      level     : required level when the character is too low (still compared)
      score, base, delta, pct, diffs = { stat = change }
      upgrade   : true when it should get an arrow for this profile
]]
function BG:Compare(link, profile)
    local info = self:GetItem(link)
    if not info then
        return { pending = true }
    end
    if info.notGear then
        return { reason = "notgear" }
    end

    local result = { score = self:Score(info, profile) }
    if info.unusable then
        result.reason = "unusable"
        return result
    end

    local options, blocked = ReplaceOptions(info, profile)
    if blocked == "pending" then
        return { pending = true }
    end
    if not options then
        result.reason = blocked
        return result
    end

    local best
    for _, slots in ipairs(options) do
        local base, diffs = 0, {}
        for stat, value in pairs(info.stats) do
            diffs[stat] = value
        end
        for _, slot in ipairs(slots) do
            local equipped = Equipped(slot)
            if equipped == nil then
                return { pending = true }
            end
            if equipped then
                if equipped.link == link then
                    result.reason = "equipped"
                    return result
                end
                base = base + self:Score(equipped, profile)
                for stat, value in pairs(equipped.stats) do
                    diffs[stat] = (diffs[stat] or 0) - value
                end
            end
        end
        local delta = result.score - base
        if not best or delta > best.delta then
            best = { delta = delta, base = base, diffs = diffs }
        end
    end

    result.delta, result.base, result.diffs = best.delta, best.base, best.diffs
    result.pct = best.base > 0 and (best.delta / best.base * 100) or nil

    if self:IsMismatch(info, profile) then
        result.reason = "mismatch"
        return result
    end
    local level = UnitLevel("player") or 1
    if info.minLevel > level then
        result.level = info.minLevel
    end
    result.better = best.delta > math.max(0.1, best.base * 0.01)
    result.training = info.needsTraining or nil
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

-- Bag arrow state: nil = not known yet, false = no arrow,
-- "active" = upgrade for the active profile, "other" = upgrade only for another profile of this spec.
function BG:BagState(link)
    local active = self:GetActiveProfile()
    if not active or not link then
        return false
    end
    local result = self:Compare(link, active)
    if result.pending then
        return nil
    end
    if result.reason == "notgear" or result.reason == "unusable" or result.reason == "equipped" then
        return false
    end
    if result.upgrade then
        return "active"
    end
    for _, profile in ipairs(self:GetProfiles()) do
        if profile ~= active then
            local other = self:Compare(link, profile)
            if other.pending then
                return nil
            end
            if other.upgrade then
                return "other"
            end
        end
    end
    return false
end
