-- BetterGearing: judge items for another character ("preview"), for example while crafting
-- or shopping for an alt. Every character saves a snapshot of its class, spec, level and worn
-- gear account-wide, so any of your characters can compare items against another one's gear.
local _, BG = ...

local function CharKey()
    return UnitName("player") .. "-" .. (GetRealmName() or "")
end

local function SpecLabel(classFile, specId)
    local classData = BG.SPECS[classFile]
    local spec = classData and classData.specs[specId]
    local className = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile] or classFile
    return (spec and spec.label or tostring(specId)) .. " " .. className
end

function BG:SaveSnapshot()
    if not BetterGearingDB then
        return
    end
    local who = self:PlayerWho()
    local gear = {}
    for _, slot in ipairs(self.GEAR_SLOTS) do
        gear[slot] = who.Link(slot)
    end
    BetterGearingDB.chars[CharKey()] = {
        name = UnitName("player"), class = who.class, spec = (self:GetSpec()),
        level = who.level, dualWield = who.dualWield, gear = gear,
    }
end

-- Spec, level, gear and profile changes all go through BG:Changed().
BG:OnChanged(function()
    BG:SaveSnapshot()
end)

--[[ BG:GetPreview() -> nil, or { who, profiles, title }
    who is shaped like BG:PlayerWho() (see Score.lua).
]]
function BG:GetPreview()
    local preview = BetterGearingCharDB and BetterGearingCharDB.preview
    if not preview then
        return nil
    end
    if preview.char then
        local snap = BetterGearingDB.chars[preview.char]
        if not snap or preview.char == CharKey() then
            return nil
        end
        local profiles = self:ProfilesFor(snap.class, snap.spec)
        if #profiles == 0 then
            return nil
        end
        local gear = snap.gear or {}
        return {
            who = {
                class = snap.class, level = snap.level or 1, dualWield = snap.dualWield,
                Link = function(slot) return gear[slot] end,
            },
            profiles = profiles,
            title = string.format("%s (%d %s)", snap.name, snap.level or 1, SpecLabel(snap.class, snap.spec)),
        }
    end
    if preview.inspect then
        -- Another player, as they were when you inspected them.
        local snap = preview.inspect
        local profiles = self:ProfilesFor(snap.class, snap.spec)
        if #profiles == 0 then
            return nil
        end
        local gear = snap.gear or {}
        return {
            who = {
                class = snap.class, level = snap.level or 1, dualWield = snap.dualWield,
                Link = function(slot) return gear[slot] end,
            },
            profiles = profiles,
            title = string.format("%s (%d %s, inspected)", snap.name, snap.level or 1, SpecLabel(snap.class, snap.spec)),
        }
    end
    local profiles = self:ProfilesFor(preview.class, preview.spec)
    if #profiles == 0 then
        return nil
    end
    return {
        who = {
            class = preview.class, level = 999, noGear = true,
            dualWield = self.DUAL_WIELD_CLASSES[preview.class] or false,
            Link = function() return nil end,
        },
        profiles = profiles,
        title = SpecLabel(preview.class, preview.spec),
    }
end

-- Whose upgrades the recipe list marks: the previewed character when there is gear to compare
-- with, otherwise nil (the logged-in character). Returns { who, profiles, active, title }.
function BG:ArrowTarget()
    local preview = self:GetPreview()
    if not preview or preview.who.noGear then
        return nil
    end
    return { who = preview.who, profiles = preview.profiles, active = preview.profiles[1], title = preview.title }
end

local function Set(preview, message)
    BetterGearingCharDB.preview = preview
    BG:Print(message)
    BG:Changed()
end

--[[ Inspecting another player.
    NotifyInspect asks the server for their gear and talents; INSPECT_READY says it arrived.
    Item links can trail the event slightly, so missing slots that show an icon are read again.
]]
local pending      -- { guid, unit, spec (chosen by you, or nil), tries }

local function SpecList(classFile)
    local specs = {}
    for id in pairs(BG.SPECS[classFile] and BG.SPECS[classFile].specs or {}) do
        table.insert(specs, id)
    end
    table.sort(specs)
    return table.concat(specs, ", ")
end

local function ReadInspect()
    local job = pending
    if not job then
        return
    end
    local unit = job.unit
    if UnitGUID(unit) ~= job.guid then
        pending = nil
        BG:Print("lost the inspected player (target changed). Try again.")
        return
    end
    local gear, missing = {}, false
    for _, slot in ipairs(BG.GEAR_SLOTS) do
        gear[slot] = GetInventoryItemLink(unit, slot)
        if not gear[slot] and GetInventoryItemTexture and GetInventoryItemTexture(unit, slot) then
            missing = true
        end
    end
    if missing and job.tries < 6 then
        job.tries = job.tries + 1
        C_Timer.After(0.5, function()
            if pending == job then
                ReadInspect()
            end
        end)
        return
    end
    pending = nil

    local name = UnitName(unit)
    local _, classFile = UnitClass(unit)
    local spec, how = job.spec, "chosen"
    if not spec then
        spec, how = BG:SpecFromTalents(classFile, true)
    end
    if not spec or #BG:ProfilesFor(classFile, spec) == 0 then
        BG:Print(name .. "'s class has no profiles yet.")
        return
    end
    local snap = {
        guid = job.guid, name = name, class = classFile, spec = spec, specHow = how,
        level = UnitLevel(unit) or 1, dualWield = BG.DUAL_WIELD_CLASSES[classFile] or false, gear = gear,
    }
    local message = "previewing items for " .. name .. " (" .. SpecLabel(classFile, spec) .. "), compared with their gear right now."
    if how == "default" then
        message = message .. " |cffffd100Couldn't read their talents, so the spec is a guess.|r Pick theirs with /bgear view target <spec>: "
            .. SpecList(classFile) .. "."
    end
    Set({ inspect = snap }, message)
end

-- Inspect a player and make them the preview. spec: optional spec id you choose for them.
function BG:InspectPreview(unit, spec)
    unit = unit or "target"
    if not UnitExists(unit) or not UnitIsPlayer(unit) then
        self:Print("target a player first.")
        return
    end
    if UnitIsUnit(unit, "player") then
        self:Print("that is you.")
        return
    end
    local _, classFile = UnitClass(unit)
    if spec and not (self.SPECS[classFile] and self.SPECS[classFile].specs[spec]) then
        self:Print("unknown spec for " .. UnitName(unit) .. ". Specs: " .. SpecList(classFile))
        return
    end

    -- Changing the spec of the player already being previewed needs no new inspect.
    local current = BetterGearingCharDB.preview and BetterGearingCharDB.preview.inspect
    if spec and current and current.guid == UnitGUID(unit) then
        current.spec, current.specHow = spec, "chosen"
        Set(BetterGearingCharDB.preview, "previewing " .. current.name .. " as " .. SpecLabel(classFile, spec) .. ".")
        return
    end

    if not (CanInspect and CanInspect(unit)) then
        self:Print("can't inspect " .. UnitName(unit) .. " from here. Get closer and try again.")
        return
    end
    local job = { guid = UnitGUID(unit), unit = unit, spec = spec, tries = 0 }
    pending = job
    NotifyInspect(unit)
    C_Timer.After(4, function()
        if pending == job and job.tries == 0 then
            pending = nil
            self:Print("no inspect answer for " .. (UnitName(unit) or "that player") .. ". Get closer and try again.")
        end
    end)
end

-- Is this unit the player being previewed?
function BG:IsInspectPreview(unit)
    local current = BetterGearingCharDB and BetterGearingCharDB.preview and BetterGearingCharDB.preview.inspect
    return current ~= nil and unit ~= nil and UnitGUID(unit) == current.guid
end

local inspectEvents = CreateFrame("Frame")
inspectEvents:RegisterEvent("INSPECT_READY")
inspectEvents:SetScript("OnEvent", function(_, _, guid)
    if pending and guid == pending.guid then
        ReadInspect()
    end
end)

local function ListCharacters()
    local here = CharKey()
    local names = {}
    for key, snap in pairs(BetterGearingDB.chars) do
        if key ~= here then
            table.insert(names, string.format("%s (%d %s)", snap.name, snap.level or 1, SpecLabel(snap.class, snap.spec)))
        end
    end
    table.sort(names)
    return #names > 0 and table.concat(names, ", ") or "none yet - log in on each character once to save it"
end

-- /bgear view [character | class [spec] | off]   (input already lowercased)
function BG:PreviewCommand(rest)
    if rest == "" then
        local preview = self:GetPreview()
        self:Print("previewing: " .. (preview and preview.title or "nobody") .. ".")
        self:Print("usage: /bgear view <character> | target [spec] | <class> [spec] | off. Saved characters: " .. ListCharacters())
        return
    end
    if rest == "off" then
        Set(nil, "preview off.")
        return
    end
    local targetSpec = rest:match("^target%s*([%a_]*)$")
    if targetSpec then
        self:InspectPreview("target", targetSpec ~= "" and targetSpec or nil)
        return
    end

    for key, snap in pairs(BetterGearingDB.chars) do
        if key:lower() == rest or (snap.name or ""):lower() == rest then
            if key == CharKey() then
                self:Print("that is the character you are playing.")
                return
            end
            if #self:ProfilesFor(snap.class, snap.spec) == 0 then
                self:Print(snap.name .. " has no spec with a profile yet.")
                return
            end
            Set({ char = key }, "previewing items for " .. snap.name .. " (" .. SpecLabel(snap.class, snap.spec)
                .. "), compared with their gear as of their last login.")
            return
        end
    end

    local className, specId = rest:match("^(%a+)%s*([%a_]*)$")
    local classFile = className and className:upper()
    local classData = classFile and self.SPECS[classFile]
    if classData then
        specId = (specId ~= "" and specId) or classData.default
        if classData.specs[specId] then
            Set({ class = classFile, spec = specId }, "previewing items for " .. SpecLabel(classFile, specId)
                .. " (scores only - no gear to compare with).")
        else
            local specs = {}
            for id in pairs(classData.specs) do
                table.insert(specs, id)
            end
            table.sort(specs)
            self:Print("unknown spec. " .. className .. " specs: " .. table.concat(specs, ", "))
        end
        return
    end
    self:Print("no saved character or class called '" .. rest .. "'. Saved characters: " .. ListCharacters())
end
