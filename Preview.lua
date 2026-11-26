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

local function Set(preview, message)
    BetterGearingCharDB.preview = preview
    BG:Print(message)
    BG:Changed()
end

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
        self:Print("usage: /bgear view <character> | <class> [spec] | off. Saved characters: " .. ListCharacters())
        return
    end
    if rest == "off" then
        Set(nil, "preview off.")
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

    local className, specId = rest:match("^(%a+)%s*(%a*)$")
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
