-- BetterGearing: read an item's stats by parsing its tooltip (enUS client text).
-- Forever shows hit/crit/etc. as green "Equip:" percentages that GetItemStats does not
-- return, so the tooltip is the single source of truth here.
local _, BG = ...

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

local cache = {}   -- [link] = info

BG:OnChanged(function()
    -- Usability (red text) depends on level and trained skills, so drop the cache on changes.
    wipe(cache)
end)

--[[ Reading tooltip lines ]]--

local scanTip
local function ScanTip()
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "BetterGearingScanTip", nil, "GameTooltipTemplate")
        scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    return scanTip
end

local function IsRed(r, g, b)
    return r and r > 0.9 and g < 0.25 and b < 0.25
end

local function IsGreen(r, g, b)
    return r and r < 0.25 and g > 0.9 and b < 0.25
end

-- Tooltip line type the client gives to enchant lines, when it exposes one.
local ENCHANT_LINE = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemEnchantmentPermanent

-- Returns a list of { text, red, green, enchant, rightText, rightRed } or nil when not available yet.
local function ReadLines(link)
    local lines = {}
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local data = C_TooltipInfo.GetHyperlink(link)
        if not data or not data.lines then
            return nil
        end
        if TooltipUtil and TooltipUtil.SurfaceArgs then
            pcall(TooltipUtil.SurfaceArgs, data)
        end
        for _, line in ipairs(data.lines) do
            if TooltipUtil and TooltipUtil.SurfaceArgs then
                pcall(TooltipUtil.SurfaceArgs, line)
            end
            local lc, rc = line.leftColor, line.rightColor
            table.insert(lines, {
                enchant = ENCHANT_LINE ~= nil and line.type == ENCHANT_LINE,
                text = line.leftText or "",
                red = lc and IsRed(lc.r, lc.g, lc.b) or false,
                green = lc and IsGreen(lc.r, lc.g, lc.b) or false,
                rightText = line.rightText,
                rightRed = rc and IsRed(rc.r, rc.g, rc.b) or false,
            })
        end
        return lines
    end

    local tip = ScanTip()
    tip:SetOwner(WorldFrame, "ANCHOR_NONE")
    tip:ClearLines()
    tip:SetHyperlink(link)
    local count = tip:NumLines()
    if count == 0 then
        return nil
    end
    for i = 1, count do
        local left = _G["BetterGearingScanTipTextLeft" .. i]
        local right = _G["BetterGearingScanTipTextRight" .. i]
        if left then
            local r, g, b = left:GetTextColor()
            local rightText = right and right:IsShown() and right:GetText() or nil
            local rr, rg, rb
            if rightText then
                rr, rg, rb = right:GetTextColor()
            end
            table.insert(lines, {
                text = left:GetText() or "",
                red = IsRed(r, g, b) or false,
                green = IsGreen(r, g, b) or false,
                rightText = rightText,
                rightRed = rightText and IsRed(rr, rg, rb) or false,
            })
        end
    end
    return lines
end

--[[ Line patterns (matched against lowercased text) ]]--

local N = "([%d%.]+)"

-- White stat lines.
local PLAIN = {
    { "^%+?" .. N .. " strength$", "str" },
    { "^%+?" .. N .. " agility$", "agi" },
    { "^%+?" .. N .. " stamina$", "sta" },
    { "^%+?" .. N .. " intellect$", "int" },
    { "^%+?" .. N .. " spirit$", "spi" },
    { "^" .. N .. " armor$", "armor" },
    { "^" .. N .. " block$", "blockvalue" },
    { "^%(" .. N .. " damage per second%)$", "weapondps" },
}

-- "Equip:" lines, prefix already removed. Each entry: pattern, stat(s) in capture order.
local EQUIP = {
    { "^improves your chance to hit with all spells and attacks by " .. N .. "%%%.?$", { { "hit", "spellhit" } } },
    { "^improves your chance to hit with spells by " .. N .. "%%%.?$", { "spellhit" } },
    { "^improves your chance to hit by " .. N .. "%%%.?$", { "hit" } },
    { "^improves your chance to get a critical strike with all spells and attacks by " .. N .. "%%%.?$", { { "crit", "spellcrit" } } },
    { "^improves your chance to get a critical strike with spells by " .. N .. "%%%.?$", { "spellcrit" } },
    { "^improves your chance to get a critical strike by " .. N .. "%%%.?$", { "crit" } },
    { "^reduces chance to be dodged or parried by " .. N .. "%%%.?$", { "expertise" } },
    { "^reduces the chance for your attacks to be dodged or parried by " .. N .. "%%%.?$", { "expertise" } },
    { "^%+" .. N .. " ranged attack power%.?$", { "rap" } },
    { "^increases ranged attack power by " .. N .. "%.?$", { "rap" } },
    { "^%+" .. N .. " attack power%.?$", { "ap" } },
    { "^increases attack power by " .. N .. "%.?$", { "ap" } },
    { "^increases healing done by up to " .. N .. " and damage done by up to " .. N .. " for all magical spells and effects%.?$", { "heal", "spdmg" } },
    { "^increases damage and healing done by magical spells and effects by up to " .. N .. "%.?$", { { "heal", "spdmg" } } },
    { "^increases spell power by " .. N .. "%.?$", { { "heal", "spdmg" } } },
    { "^increases healing done by spells and effects by up to " .. N .. "%.?$", { "heal" } },
    { "^increases healing done by magical spells and effects by up to " .. N .. "%.?$", { "heal" } },
    { "^increases damage done by magical spells and effects by up to " .. N .. "%.?$", { "spdmg" } },
    { "^restores " .. N .. " mana per 5 sec%.?$", { "mp5" } },
    { "^restores " .. N .. " health per 5 sec%.?$", { "hp5" } },
    { "^restores " .. N .. " health every 5 sec%.?$", { "hp5" } },
    { "^increased defense %+" .. N .. "%.?$", { "defense" } },
    { "^increases your chance to dodge an attack by " .. N .. "%%%.?$", { "dodge" } },
    { "^increases your chance to parry an attack by " .. N .. "%%%.?$", { "parry" } },
    { "^increases your chance to block attacks with a shield by " .. N .. "%%%.?$", { "block" } },
    { "^increases the block value of your shield by " .. N .. "%.?$", { "blockvalue" } },
    { "^increases your attack speed and casting speed by " .. N .. "%%%.?$", { { "haste", "spellhaste" } } },
    { "^increases your attack speed by " .. N .. "%%%.?$", { "haste" } },
    { "^increases your casting speed by " .. N .. "%%%.?$", { "spellhaste" } },
}

-- Green "+N Stat" lines that are part of the item itself. Forever prints these bonus stats
-- in green; green primary stats (strength, stamina...) are enchants and are not listed here.
local GREEN = {
    { "^%+" .. N .. " spell power$", { "heal", "spdmg" } },
    { "^%+" .. N .. " healing power$", { "heal" } },
    { "^%+" .. N .. " spell damage$", { "spdmg" } },
    { "^%+" .. N .. " ranged attack power$", { "rap" } },
    { "^%+" .. N .. " attack power$", { "ap" } },
    { "^%+" .. N .. " defense$", { "defense" } },
    { "^%+" .. N .. " block value$", { "blockvalue" } },
    { "^%+" .. N .. " mana per 5 sec%.?$", { "mp5" } },
    { "^%+" .. N .. " health per 5 sec%.?$", { "hp5" } },
}

local function Add(stats, stat, value)
    stats[stat] = (stats[stat] or 0) + value
end

local function ParseLine(text, stats)
    for _, entry in ipairs(PLAIN) do
        local value = text:match(entry[1])
        if value then
            Add(stats, entry[2], tonumber(value))
            return true
        end
    end
    return false
end

local function ParseGreen(text, stats)
    for _, entry in ipairs(GREEN) do
        local value = tonumber((text:match(entry[1])))
        if value then
            for _, stat in ipairs(entry[2]) do
                Add(stats, stat, value)
            end
            return true
        end
    end
    return false
end

local function ParseEquip(text, stats)
    for _, entry in ipairs(EQUIP) do
        local a, b = text:match(entry[1])
        if a then
            local captures = { a, b }
            for i, target in ipairs(entry[2]) do
                local value = tonumber(captures[i])
                if value then
                    if type(target) == "table" then
                        for _, stat in ipairs(target) do
                            Add(stats, stat, value)
                        end
                    else
                        Add(stats, target, value)
                    end
                end
            end
            return true
        end
    end
    return false
end

-- Weapon skills each class can learn (item subclass id -> classes). Era rules plus Forever's
-- additions (rogue one-handed axes, shaman two-handed axes and maces), as listed by WhatsTraining.
local function Classes(list)
    local set = {}
    for classFile in list:gmatch("%u+") do
        set[classFile] = true
    end
    return set
end
local TRAINABLE_WEAPONS = {
    [0] = Classes("WARRIOR PALADIN HUNTER SHAMAN ROGUE"),                           -- one-handed axes
    [1] = Classes("WARRIOR PALADIN HUNTER SHAMAN"),                                 -- two-handed axes
    [2] = Classes("WARRIOR HUNTER ROGUE"),                                          -- bows
    [3] = Classes("WARRIOR HUNTER ROGUE"),                                          -- guns
    [4] = Classes("WARRIOR PALADIN ROGUE PRIEST SHAMAN DRUID"),                     -- one-handed maces
    [5] = Classes("WARRIOR PALADIN SHAMAN DRUID"),                                  -- two-handed maces
    [6] = Classes("WARRIOR PALADIN HUNTER DRUID"),                                  -- polearms
    [7] = Classes("WARRIOR PALADIN HUNTER ROGUE MAGE WARLOCK"),                     -- one-handed swords
    [8] = Classes("WARRIOR PALADIN HUNTER"),                                        -- two-handed swords
    [10] = Classes("WARRIOR HUNTER PRIEST SHAMAN DRUID WARLOCK MAGE"),              -- staves
    [13] = Classes("WARRIOR HUNTER ROGUE SHAMAN DRUID"),                            -- fist weapons
    [15] = Classes("WARRIOR HUNTER ROGUE PRIEST SHAMAN DRUID WARLOCK MAGE"),        -- daggers
    [16] = Classes("WARRIOR HUNTER ROGUE"),                                         -- thrown
    [18] = Classes("WARRIOR HUNTER ROGUE"),                                         -- crossbows
}
-- Armor type learned at level 40 (armor subclass id: 3 = mail, 4 = plate).
local ARMOR_AT_40 = { HUNTER = 3, SHAMAN = 3, WARRIOR = 4, PALADIN = 4 }

local RANGED_LOC = {
    INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true,
}

--[[ Public: BG:GetItem(link)
    Returns nil while the item is not cached by the client yet, otherwise:
    { link, name, equipLoc, minLevel, stats = {..}, unusable = bool, unparsed = {..} }
]]
function BG:GetItem(link)
    if not link then
        return nil
    end
    local cached = cache[link]
    if cached then
        return cached
    end

    local name, _, _, _, minLevel, _, _, _, equipLoc, _, _, classID, subclassID = GetItemInfo(link)
    if not name then
        return nil
    end
    local info = { link = link, name = name, equipLoc = equipLoc, minLevel = minLevel or 0, stats = {}, unparsed = {} }
    if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_BAG" or equipLoc == "INVTYPE_AMMO"
        or equipLoc == "INVTYPE_QUIVER" or equipLoc == "INVTYPE_BODY" or equipLoc == "INVTYPE_TABARD"
        or equipLoc == "INVTYPE_NON_EQUIP_IGNORE" then
        info.notGear = true
        cache[link] = info
        return info
    end

    local lines = ReadLines(link)
    if not lines then
        return nil
    end

    local stats = info.stats
    local hardRed, typeRed = false, false
    for index, line in ipairs(lines) do
        local text = (line.text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub(",", "")
        local lower = strtrim(text):lower()

        -- Red text = the character cannot use this (class, proficiency, profession...).
        -- Level and durability are handled separately.
        if index > 1 and not lower:find("^requires level") and not lower:find("^durability") then
            if line.rightRed then
                -- Weapon or armor type the character is not proficient with. The slot name
                -- on the left ("Two-Hand") turns red with it, so check this side first.
                typeRed = true
            elseif line.red then
                hardRed = true      -- class restriction, profession, reputation...
            end
        end

        if lower:find("^equip: ") then
            local body = lower:gsub("^equip: ", "")
            if not ParseEquip(body, stats) then
                -- Spell damage for a single school ("Arcane spells and effects").
                local school, value = body:match("^increases damage done by (%a+) spells and effects by up to ([%d%.]+)%.?$")
                if school and tonumber(value) then
                    Add(stats, "school:" .. school, tonumber(value))
                else
                    table.insert(info.unparsed, text)
                end
            end
        elseif lower:find("^set: ") or lower:find("^use: ") or lower:find("^chance on hit: ") or lower:find("^%(%d+%) set") then
            -- not scored
        elseif line.enchant then
            -- Enchants are skipped so an enchanted equipped item is compared fairly
            -- against an unenchanted drop.
        elseif line.green and lower:find("^%+") then
            -- Green "+N Stat" is either one of the item's own bonus stats (spell power...)
            -- or an enchant; anything not recognised as the former is skipped.
            ParseGreen(lower, stats)
        elseif not ParseLine(lower, stats) then
            -- Random-suffix items: "+12 Arcane Spell Damage".
            local value, school = lower:match("^%+?([%d%.]+) (%a+) spell damage$")
            if school and tonumber(value) then
                Add(stats, "school:" .. school, tonumber(value))
            end
        end
    end

    if hardRed then
        info.unusable = true
    elseif typeRed then
        local _, classFile = UnitClass("player")
        local level = UnitLevel("player") or 1
        if classID == 2 and TRAINABLE_WEAPONS[subclassID] and TRAINABLE_WEAPONS[subclassID][classFile] then
            info.needsTraining = true           -- a weapon master can teach this
        elseif classID == 4 and ARMOR_AT_40[classFile] == subclassID then
            if level < 40 then
                info.minLevel = math.max(info.minLevel, 40)
            else
                info.needsTraining = true       -- class trainer teaches it at 40
            end
        else
            info.unusable = true
        end
    end

    -- Weapon damage per second goes to the melee or ranged stat depending on the slot.
    if stats.weapondps then
        if RANGED_LOC[equipLoc] then
            stats.rdps = stats.weapondps
        else
            stats.dps = stats.weapondps
        end
        stats.weapondps = nil
    end

    cache[link] = info
    return info
end
