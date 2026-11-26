-- BetterGearing: stat list, per-spec profiles (default weights), spec detection.
local _, BG = ...

-- Every stat the addon understands, in display order.
-- Percent stats (hit, crit, ...) are weighted per 1%.
BG.STAT_ORDER = {
    "rdps", "dps",
    "str", "agi", "sta", "int", "spi",
    "ap", "rap", "feralap", "hit", "crit", "expertise", "haste",
    "heal", "spdmg", "spellhit", "spellcrit", "spellhaste", "mp5",
    "armor", "defense", "dodge", "parry", "block", "blockvalue", "hp5",
}

BG.STAT_LABELS = {
    rdps = "Ranged weapon DPS", dps = "Melee weapon DPS",
    str = "Strength", agi = "Agility", sta = "Stamina", int = "Intellect", spi = "Spirit",
    ap = "Attack Power", rap = "Ranged Attack Power", feralap = "AP in feral forms",
    hit = "Hit %", crit = "Crit %", expertise = "Expertise %", haste = "Attack speed %",
    heal = "Healing", spdmg = "Spell damage", spellhit = "Spell hit %", spellcrit = "Spell crit %",
    spellhaste = "Cast speed %", mp5 = "Mana per 5",
    armor = "Armor", defense = "Defense", dodge = "Dodge %", parry = "Parry %",
    block = "Block %", blockvalue = "Block value", hp5 = "Health per 5",
}

BG.STAT_SHORT = {
    rdps = "ranged DPS", dps = "DPS", str = "Str", agi = "Agi", sta = "Sta", int = "Int", spi = "Spi",
    ap = "AP", rap = "RAP", feralap = "feral AP", hit = "% hit", crit = "% crit", expertise = "% expertise", haste = "% haste",
    heal = "healing", spdmg = "spell dmg", spellhit = "% spell hit", spellcrit = "% spell crit",
    spellhaste = "% cast speed", mp5 = "mp5", armor = "armor", defense = "defense", dodge = "% dodge",
    parry = "% parry", block = "% block", blockvalue = "block value", hp5 = "hp5",
}

-- Rough item-budget cost of one point of each stat. Only used to decide whether
-- an item's stats are mostly wasted on a profile ("wrong stats" rule), never for scoring.
BG.STAT_BUDGET = {
    str = 1, agi = 1, sta = 1, int = 1, spi = 1,
    ap = 0.5, rap = 0.4, feralap = 0.5, hit = 10, crit = 14, expertise = 10, haste = 10,
    heal = 0.45, spdmg = 0.86, spellhit = 8, spellcrit = 14, spellhaste = 10, mp5 = 2.5,
    defense = 1.5, dodge = 12, parry = 20, block = 5, blockvalue = 0.65, hp5 = 2,
}

--[[ Profiles
    Sources: Icy Veins "WoW Forever" leveling stat priorities, cross-checked against
    GearQuestForever's and Pawn's Forever weights. All are starting points - tune them
    in game with /bgear.

    when = "group"  : auto-selected while in a dungeon/raid or in a group
    when = "solo"   : auto-selected otherwise
    needShield      : two-handers are rejected, one-handers only compete for the main hand
    school          : spell school whose school-only spell damage counts as spell damage
    schools         : instead of school, { school = fraction of the spell damage weight }
                      for specs that cast from more than one school
]]
BG.SPECS = {
    HUNTER = {
        tabs = { "beast_mastery", "marksmanship", "survival" },
        default = "beast_mastery",
        specs = {
            beast_mastery = {
                label = "Beast Mastery",
                profiles = {
                    {
                        id = "ranged", label = "BM Hunter",
                        -- ranged weapon damage > hit > crit > agility > attack power
                        weights = {
                            rdps = 8, dps = 0.1,
                            agi = 1, sta = 0.4, int = 0.15, spi = 0.05, str = 0.05,
                            ap = 0.45, rap = 0.45, hit = 12, crit = 10, haste = 5,
                            mp5 = 0.3, hp5 = 0.2, armor = 0.01,
                        },
                    },
                },
            },
            marksmanship = {
                label = "Marksmanship",
                profiles = {
                    {
                        id = "ranged", label = "MM Hunter",
                        -- ranged weapon damage > hit > crit > agility > ranged attack power
                        weights = {
                            rdps = 8, dps = 0.1,
                            agi = 1, sta = 0.35, int = 0.15, spi = 0.05, str = 0.05,
                            ap = 0.4, rap = 0.5, hit = 13, crit = 11, haste = 5,
                            mp5 = 0.3, hp5 = 0.2, armor = 0.01,
                        },
                    },
                },
            },
            survival = {
                label = "Survival",
                profiles = {
                    {
                        id = "ranged", label = "Survival Hunter",
                        -- agility > hit > crit > ranged weapon damage > attack power
                        weights = {
                            rdps = 7, dps = 0.3,
                            agi = 1.2, sta = 0.4, int = 0.15, spi = 0.05, str = 0.05,
                            ap = 0.45, rap = 0.45, hit = 12, crit = 11, haste = 5,
                            mp5 = 0.3, hp5 = 0.2, armor = 0.01,
                        },
                    },
                },
            },
        },
    },
    WARRIOR = {
        tabs = { "arms", "fury", "protection" },
        default = "protection",
        specs = {
            arms = {
                label = "Arms",
                profiles = {
                    {
                        id = "dps", label = "Arms Warrior",
                        -- two-hand weapon damage > hit > crit > expertise > strength
                        weights = {
                            dps = 6, hit = 10, crit = 10, expertise = 8, str = 1, agi = 0.6,
                            ap = 0.45, haste = 5, sta = 0.45, armor = 0.02, hp5 = 0.3,
                        },
                    },
                },
            },
            fury = {
                label = "Fury",
                profiles = {
                    {
                        id = "dps", label = "Fury Warrior",
                        -- weapon damage > hit > expertise > crit > strength
                        weights = {
                            dps = 5, hit = 10, expertise = 9, crit = 9, str = 1, agi = 0.6,
                            ap = 0.45, haste = 6, sta = 0.45, armor = 0.02, hp5 = 0.3,
                        },
                    },
                },
            },
            protection = {
                label = "Protection",
                profiles = {
                    {
                        id = "tank", label = "Prot Warrior - Tanking", short = "Tanking",
                        when = "group", needShield = true,
                        -- stamina > armor > agility > avoidance > defense
                        weights = {
                            sta = 1, armor = 0.06, agi = 0.6, str = 0.4,
                            dodge = 12, parry = 12, block = 5, blockvalue = 0.3, defense = 0.8,
                            expertise = 8, hit = 6, crit = 3, ap = 0.15, dps = 2, hp5 = 0.5,
                        },
                    },
                    {
                        id = "solo", label = "Prot Warrior - Solo", short = "Solo",
                        when = "solo",
                        -- weapon > expertise > hit > agility > strength > stamina
                        weights = {
                            dps = 5, expertise = 10, hit = 10, agi = 1, str = 0.9, sta = 0.6,
                            crit = 8, ap = 0.45, haste = 5, armor = 0.02,
                            defense = 0.2, dodge = 4, parry = 4, block = 2, blockvalue = 0.2, hp5 = 0.5,
                        },
                    },
                },
            },
        },
    },
    PALADIN = {
        tabs = { "holy", "protection", "retribution" },
        default = "retribution",
        specs = {
            holy = {
                label = "Holy",
                profiles = {
                    {
                        id = "heal", label = "Holy Paladin",
                        -- healing power > intellect > spell crit > mp5 > stamina
                        weights = {
                            heal = 1, spdmg = 0.05, int = 1, mp5 = 2, spellcrit = 8, spi = 0.3,
                            spellhaste = 4, sta = 0.3, armor = 0.005, dps = 0.05,
                        },
                    },
                },
            },
            retribution = {
                label = "Retribution",
                profiles = {
                    {
                        id = "dps", label = "Ret Paladin",
                        -- weapon damage > hit > expertise > strength > spell power
                        weights = {
                            dps = 5, hit = 10, expertise = 9, str = 1, crit = 8, ap = 0.45,
                            spdmg = 0.3, agi = 0.5, sta = 0.5, int = 0.15, haste = 5,
                            spellcrit = 1, mp5 = 0.3, armor = 0.02, hp5 = 0.3,
                        },
                    },
                },
            },
            protection = {
                label = "Protection",
                profiles = {
                    {
                        id = "tank", label = "Prot Paladin", needShield = true,
                        -- stamina > defense > spell power > intellect > strength
                        weights = {
                            sta = 1, defense = 0.9, spdmg = 0.6, int = 0.4, str = 0.35,
                            armor = 0.06, agi = 0.3, dodge = 10, parry = 10, block = 5, blockvalue = 0.35,
                            hit = 5, expertise = 5, spellhit = 3, crit = 2, dps = 1, mp5 = 0.6, hp5 = 0.5,
                        },
                    },
                },
            },
        },
    },
    MAGE = {
        tabs = { "arcane", "fire", "frost" },
        default = "arcane",
        specs = {
            arcane = {
                label = "Arcane",
                profiles = {
                    {
                        id = "dps", label = "Arcane Mage", school = "arcane",
                        -- spell hit = spell power > crit > intellect > spirit > mp5
                        weights = {
                            spdmg = 1, spellhit = 10, spellcrit = 8, int = 0.5, spi = 0.3, mp5 = 1,
                            spellhaste = 6, sta = 0.3, armor = 0.005, rdps = 0.1,
                        },
                    },
                },
            },
            fire = {
                label = "Fire",
                profiles = {
                    {
                        id = "dps", label = "Fire Mage", school = "fire",
                        -- spell hit = spell power > crit > intellect > mp5 > spirit
                        weights = {
                            spdmg = 1, spellhit = 10, spellcrit = 9, int = 0.45, spi = 0.25, mp5 = 0.9,
                            spellhaste = 6, sta = 0.3, armor = 0.005, rdps = 0.1,
                        },
                    },
                },
            },
            frost = {
                label = "Frost",
                profiles = {
                    {
                        id = "dps", label = "Frost Mage", school = "frost",
                        -- spell power > spell hit > intellect > crit > mp5 > stamina
                        weights = {
                            spdmg = 1, spellhit = 10, spellcrit = 6, int = 0.5, spi = 0.3, mp5 = 1,
                            spellhaste = 5, sta = 0.35, armor = 0.005, rdps = 0.1,
                        },
                    },
                },
            },
        },
    },
    PRIEST = {
        tabs = { "discipline", "holy", "shadow" },
        default = "holy",
        specs = {
            discipline = {
                label = "Discipline",
                profiles = {
                    {
                        id = "heal", label = "Disc Priest",
                        -- healing power > mp5 > intellect > spirit > some spell damage for soloing
                        weights = {
                            heal = 1, spdmg = 0.3, mp5 = 2.2, int = 0.9, spi = 0.7,
                            spellcrit = 5, spellhaste = 4, spellhit = 2, sta = 0.3, armor = 0.005, rdps = 0.05,
                        },
                    },
                },
            },
            shadow = {
                label = "Shadow",
                profiles = {
                    {
                        id = "dps", label = "Shadow Priest", school = "shadow",
                        -- shadow spell power > spell hit > spirit > stamina > intellect
                        weights = {
                            spdmg = 1, spellhit = 10, spellcrit = 3, spi = 0.5, sta = 0.4, int = 0.3,
                            mp5 = 0.8, spellhaste = 5, armor = 0.005, rdps = 0.1,
                        },
                    },
                },
            },
            holy = {
                label = "Holy",
                profiles = {
                    {
                        id = "heal", label = "Holy Priest - Healing",
                        -- healing power > mp5 > spirit = intellect > crit
                        weights = {
                            heal = 1.2, spdmg = 0.1, mp5 = 2.5, spi = 0.8, int = 0.8,
                            spellcrit = 5, spellhaste = 4, sta = 0.25, armor = 0.005, rdps = 0.05,
                        },
                    },
                },
            },
        },
    },
    ROGUE = {
        tabs = { "assassination", "combat", "subtlety" },
        default = "combat",
        specs = {
            assassination = {
                label = "Assassination",
                profiles = {
                    {
                        id = "dps", label = "Assassination Rogue",
                        -- weapon damage > hit > crit > expertise > agility
                        weights = {
                            dps = 5, hit = 10, crit = 10, expertise = 9, agi = 1, str = 0.5,
                            ap = 0.45, haste = 6, sta = 0.4, armor = 0.02, hp5 = 0.3, rdps = 0.3,
                        },
                    },
                },
            },
            combat = {
                label = "Combat",
                profiles = {
                    {
                        id = "dps", label = "Combat Rogue",
                        -- weapon damage > hit > expertise > crit > agility
                        weights = {
                            dps = 5.5, hit = 10, expertise = 10, crit = 9, agi = 1, str = 0.5,
                            ap = 0.45, haste = 7, sta = 0.4, armor = 0.02, hp5 = 0.3, rdps = 0.3,
                        },
                    },
                },
            },
            subtlety = {
                label = "Subtlety",
                profiles = {
                    {
                        id = "dps", label = "Subtlety Rogue",
                        -- agility > weapon damage > hit > crit > expertise
                        weights = {
                            dps = 5, hit = 10, crit = 9, expertise = 8, agi = 1.1, str = 0.5,
                            ap = 0.45, haste = 6, sta = 0.4, armor = 0.02, hp5 = 0.3, rdps = 0.3,
                        },
                    },
                },
            },
        },
    },
    SHAMAN = {
        tabs = { "elemental", "enhancement", "restoration" },
        default = "enhancement",
        specs = {
            elemental = {
                label = "Elemental",
                profiles = {
                    {
                        id = "dps", label = "Elemental Shaman", school = "nature",
                        -- spell power > spell hit > crit > intellect > mp5
                        weights = {
                            spdmg = 1, spellhit = 10, spellcrit = 8, int = 0.5, mp5 = 1.2, spi = 0.2,
                            spellhaste = 5, heal = 0.05, sta = 0.35, armor = 0.005, dps = 0.1,
                        },
                    },
                },
            },
            enhancement = {
                label = "Enhancement",
                profiles = {
                    {
                        id = "dps", label = "Enhancement Shaman",
                        -- weapon damage > hit > expertise > crit > strength > agility
                        weights = {
                            dps = 5.5, hit = 10, expertise = 9, crit = 9, str = 1, agi = 0.7,
                            ap = 0.45, haste = 6, int = 0.25, mp5 = 0.4, spdmg = 0.15,
                            sta = 0.45, armor = 0.02, hp5 = 0.3,
                        },
                    },
                },
            },
            restoration = {
                label = "Restoration",
                profiles = {
                    {
                        id = "heal", label = "Resto Shaman",
                        -- healing power > mp5 > intellect > spell crit > spirit
                        weights = {
                            heal = 1, spdmg = 0.05, mp5 = 2.5, int = 0.9, spellcrit = 6, spi = 0.4,
                            spellhaste = 4, sta = 0.3, armor = 0.005, dps = 0.05,
                        },
                    },
                },
            },
        },
    },
    WARLOCK = {
        tabs = { "affliction", "demonology", "destruction" },
        default = "affliction",
        specs = {
            affliction = {
                label = "Affliction",
                profiles = {
                    {
                        id = "dps", label = "Affliction Warlock", school = "shadow",
                        -- shadow spell power > spell hit > stamina > spirit > intellect
                        weights = {
                            spdmg = 1, spellhit = 10, spellcrit = 3, sta = 0.6, spi = 0.4, int = 0.35,
                            spellhaste = 5, mp5 = 0.6, armor = 0.005, rdps = 0.1,
                        },
                    },
                },
            },
            demonology = {
                label = "Demonology",
                profiles = {
                    {
                        id = "dps", label = "Demo Warlock", schools = { shadow = 1, fire = 0.5 },
                        -- stamina > spell power > spell hit > intellect > crit
                        weights = {
                            spdmg = 1, spellhit = 10, spellcrit = 5, sta = 0.8, int = 0.35, spi = 0.3,
                            spellhaste = 5, mp5 = 0.6, armor = 0.005, rdps = 0.1,
                        },
                    },
                },
            },
            destruction = {
                label = "Destruction",
                profiles = {
                    {
                        id = "dps", label = "Destro Warlock", schools = { shadow = 1, fire = 0.6 },
                        -- spell power > spell hit > crit > stamina > intellect
                        weights = {
                            spdmg = 1, spellhit = 10, spellcrit = 9, sta = 0.5, int = 0.4, spi = 0.25,
                            spellhaste = 6, mp5 = 0.6, armor = 0.005, rdps = 0.1,
                        },
                    },
                },
            },
        },
    },
    DRUID = {
        tabs = { "balance", "feral", "restoration" },
        default = "feral",
        specs = {
            balance = {
                label = "Balance",
                profiles = {
                    {
                        id = "dps", label = "Balance Druid", schools = { arcane = 0.6, nature = 0.6 },
                        -- spell power > spell hit > crit > intellect > mp5 > spirit
                        weights = {
                            spdmg = 1, spellhit = 10, spellcrit = 8, int = 0.5, spi = 0.3, mp5 = 1,
                            spellhaste = 5, heal = 0.05, sta = 0.35, armor = 0.01,
                        },
                    },
                },
            },
            feral = {
                label = "Feral",
                -- Forms ignore weapon damage, so weapons are judged on their stats only.
                -- Cat is the default; use "/bgear profile bear" while tanking.
                profiles = {
                    {
                        id = "cat", label = "Feral Druid - Cat", short = "Cat",
                        -- agility > strength > hit > crit > expertise > attack power
                        weights = {
                            agi = 1, str = 0.9, ap = 0.45, feralap = 0.45, hit = 10, crit = 9,
                            expertise = 9, haste = 4, sta = 0.45, armor = 0.02, hp5 = 0.3,
                            int = 0.05,
                        },
                    },
                    {
                        id = "bear", label = "Feral Druid - Bear", short = "Bear",
                        -- armor > stamina > agility > dodge > defense
                        weights = {
                            sta = 1, armor = 0.12, agi = 0.9, dodge = 12, defense = 0.8,
                            hit = 6, expertise = 8, str = 0.4, ap = 0.15, feralap = 0.15,
                            crit = 3, hp5 = 0.5,
                        },
                    },
                },
            },
            restoration = {
                label = "Restoration",
                profiles = {
                    {
                        id = "heal", label = "Resto Druid",
                        -- healing power > mp5 > spirit > intellect > spell crit
                        weights = {
                            heal = 1, spdmg = 0.05, mp5 = 2.2, spi = 0.8, int = 0.8,
                            spellcrit = 4, spellhaste = 4, sta = 0.3, armor = 0.005,
                        },
                    },
                },
            },
        },
    },
}

for classFile, classData in pairs(BG.SPECS) do
    for specId, spec in pairs(classData.specs) do
        for _, profile in ipairs(spec.profiles) do
            profile.key = classFile .. ":" .. specId .. ":" .. profile.id
            profile.short = profile.short or profile.label
            if profile.school and not profile.schools then
                profile.schools = { [profile.school] = 1 }
            end
        end
    end
end

local function PlayerClass()
    local _, classFile = UnitClass("player")
    return classFile
end

function BG:SpecExists(specId)
    local classData = self.SPECS[PlayerClass()]
    return classData and classData.specs[specId] ~= nil
end

function BG:ListSpecs()
    local classData = self.SPECS[PlayerClass()]
    local names = {}
    for specId in pairs(classData and classData.specs or {}) do
        table.insert(names, specId)
    end
    return #names > 0 and table.concat(names, ", ") or "(none yet)"
end

function BG:ListStats()
    return table.concat(self.STAT_ORDER, ", ")
end

-- Points spent in a talent tab. GetTalentInfo's 5th return is the rank on Classic-style clients.
local function TabPoints(tab)
    if not GetNumTalents or not GetTalentInfo then
        return 0
    end
    local total = 0
    for index = 1, (GetNumTalents(tab) or 0) do
        local ok, _, _, _, _, rank = pcall(GetTalentInfo, tab, index)
        rank = ok and tonumber(rank)
        if rank and rank > 0 and rank <= 10 then
            total = total + rank
        end
    end
    if total == 0 and GetTalentTabInfo then
        -- Fallback: points spent is the 3rd return on Classic Era, the 5th on later clients.
        local ok, _, _, third, _, fifth = pcall(GetTalentTabInfo, tab)
        if ok then
            local points = (type(third) == "number" and third) or (type(fifth) == "number" and fifth) or 0
            if points > 0 and points <= 71 then
                total = points
            end
        end
    end
    return total
end

-- Returns specId, how ("forced" | "talents" | "default")
function BG:GetSpec()
    local classData = self.SPECS[PlayerClass()]
    if not classData then
        return nil, "unsupported class"
    end
    local forced = BetterGearingCharDB and BetterGearingCharDB.spec
    if forced then
        return forced, "forced"
    end
    local bestTab, bestPoints = nil, 0
    for tab = 1, #classData.tabs do
        local points = TabPoints(tab)
        if points > bestPoints then
            bestTab, bestPoints = tab, points
        end
    end
    if bestTab then
        return classData.tabs[bestTab], "talents"
    end
    return classData.default, "default"
end

-- All profiles for the current spec (empty table when the spec has none yet).
function BG:GetProfiles()
    return self:ProfilesFor(PlayerClass(), (self:GetSpec()))
end

-- Profiles of any class and spec (empty table when unknown).
function BG:ProfilesFor(classFile, specId)
    local classData = self.SPECS[classFile]
    local spec = classData and specId and classData.specs[specId]
    return spec and spec.profiles or {}
end

local function InGroupContent()
    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "party" or instanceType == "raid") then
        return true
    end
    return IsInGroup and IsInGroup() or false
end

function BG:GetActiveProfile()
    local profiles = self:GetProfiles()
    if #profiles == 0 then
        return nil
    end
    local mode = BetterGearingCharDB and BetterGearingCharDB.profileMode or "auto"
    if mode ~= "auto" then
        for _, profile in ipairs(profiles) do
            if profile.id == mode then
                return profile
            end
        end
    end
    local want = InGroupContent() and "group" or "solo"
    for _, profile in ipairs(profiles) do
        if profile.when == want then
            return profile
        end
    end
    return profiles[1]
end

--[[ Weights (defaults + saved overrides) ]]--

function BG:GetWeight(profile, stat)
    -- "school:arcane" etc: spell damage for one school only. Worth the profile's spell
    -- damage weight times that school's share for the profile, nothing for other schools.
    local school = stat:match("^school:(.+)$")
    if school then
        local share = profile.schools and profile.schools[school]
        if not share then
            return 0
        end
        return share * self:GetWeight(profile, "spdmg")
    end
    local overrides = BetterGearingDB and BetterGearingDB.weights[profile.key]
    local value = overrides and overrides[stat]
    if value ~= nil then
        return value
    end
    return profile.weights[stat] or 0
end

function BG:IsOverridden(profile, stat)
    local overrides = BetterGearingDB and BetterGearingDB.weights[profile.key]
    return overrides ~= nil and overrides[stat] ~= nil
end

function BG:FindProfile(key)
    for _, classData in pairs(self.SPECS) do
        for _, spec in pairs(classData.specs) do
            for _, profile in ipairs(spec.profiles) do
                if profile.key == key then
                    return profile
                end
            end
        end
    end
end

function BG:SetWeight(profileKey, stat, value)
    local profile = self:FindProfile(profileKey)
    if not profile or not value then
        return
    end
    local weights = BetterGearingDB.weights
    weights[profileKey] = weights[profileKey] or {}
    if value == (profile.weights[stat] or 0) then
        weights[profileKey][stat] = nil   -- back to default, drop the override
    else
        weights[profileKey][stat] = value
    end
    self:Changed()
end

function BG:ResetWeights(profileKey)
    BetterGearingDB.weights[profileKey] = nil
    self:Changed()
end
