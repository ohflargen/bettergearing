-- BetterGearing: core namespace, saved variables, events, slash commands.
local ADDON, BG = ...
_G.BetterGearing = BG

BG.callbacks = {}

-- Anything that changes what counts as an upgrade (spec, profile, weights,
-- equipped gear) calls BG:Changed() so bags and caches refresh.
function BG:OnChanged(fn)
    table.insert(self.callbacks, fn)
end

function BG:Changed()
    for _, fn in ipairs(self.callbacks) do
        pcall(fn)
    end
end

function BG:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BetterGearing|r: " .. tostring(msg))
end

local function InitDB()
    BetterGearingDB = BetterGearingDB or {}
    BetterGearingDB.weights = BetterGearingDB.weights or {}   -- [profileKey][stat] = override
    BetterGearingDB.chars = BetterGearingDB.chars or {}       -- ["Name-Realm"] = snapshot (Preview.lua)
    BetterGearingCharDB = BetterGearingCharDB or {}
    -- BetterGearingCharDB.spec        : manual spec override (nil = detect from talents)
    -- BetterGearingCharDB.profileMode : "auto" or a profile id such as "tank" / "solo"
    -- BetterGearingCharDB.preview     : nil, { char = "Name-Realm" } or { class = "MAGE", spec = "arcane" }
    BetterGearingCharDB.profileMode = BetterGearingCharDB.profileMode or "auto"
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("CHARACTER_POINTS_CHANGED")
pcall(frame.RegisterEvent, frame, "PLAYER_TALENT_UPDATE")
pcall(frame.RegisterEvent, frame, "ACTIVE_TALENT_GROUP_CHANGED")

local lastProfileKey
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then
            InitDB()
        end
        return
    end
    if not BetterGearingDB then
        return
    end
    if event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_LEVEL_UP" then
        BG:Changed()
        return
    end
    -- Spec / group / zone events: only refresh when the active profile really changed.
    local profile = BG:GetActiveProfile()
    local key = profile and profile.key or "none"
    if key ~= lastProfileKey then
        if lastProfileKey and profile and event ~= "PLAYER_ENTERING_WORLD" then
            BG:Print("now scoring gear for " .. profile.label .. ".")
        end
        lastProfileKey = key
        BG:Changed()
    end
end)

SLASH_BETTERGEARING1 = "/bgear"
SLASH_BETTERGEARING2 = "/bettergearing"
SlashCmdList["BETTERGEARING"] = function(input)
    local cmd, rest = strtrim(input or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    rest = (rest or ""):lower()

    if cmd == "" or cmd == "tune" then
        BG:ToggleTuneWindow()
    elseif cmd == "status" then
        local specId, how = BG:GetSpec()
        local profile = BG:GetActiveProfile()
        BG:Print("spec: " .. tostring(specId) .. " (" .. how .. "); profile mode: " .. BetterGearingCharDB.profileMode
            .. "; active profile: " .. (profile and profile.label or "none - no profile for this spec yet"))
        local preview = BG:GetPreview()
        if preview then
            BG:Print("previewing items for " .. preview.title .. " (/bgear view off to stop)")
        end
        local hooked, seen, arrows = BG:BagStatus()
        BG:Print("Bagnon hook: " .. (hooked and "installed" or "|cffff4040NOT installed|r") .. "; item buttons seen: " .. seen .. "; arrows showing: " .. arrows)
    elseif cmd == "spec" then
        if rest == "" or rest == "auto" then
            BetterGearingCharDB.spec = nil
            BG:Print("spec is detected from talents again.")
        elseif BG:SpecExists(rest) then
            BetterGearingCharDB.spec = rest
            BG:Print("spec forced to " .. rest .. ".")
        else
            BG:Print("unknown spec. Available for your class: " .. BG:ListSpecs())
        end
        BG:Changed()
    elseif cmd == "profile" then
        if rest == "" or rest == "auto" then
            BetterGearingCharDB.profileMode = "auto"
        else
            BetterGearingCharDB.profileMode = rest
        end
        local profile = BG:GetActiveProfile()
        BG:Print("profile mode " .. BetterGearingCharDB.profileMode .. "; active: " .. (profile and profile.label or "none"))
        BG:Changed()
    elseif cmd == "view" then
        BG:PreviewCommand(rest)
    elseif cmd == "set" then
        -- /bgear set <stat> <value>   (applies to the active profile)
        local stat, value = rest:match("^(%S+)%s+(%-?[%d%.]+)$")
        local profile = BG:GetActiveProfile()
        if not profile then
            BG:Print("no active profile.")
        elseif not stat or not BG.STAT_LABELS[stat] then
            BG:Print("usage: /bgear set <stat> <value>. Stats: " .. BG:ListStats())
        else
            BG:SetWeight(profile.key, stat, tonumber(value))
            BG:Print(profile.label .. ": " .. BG.STAT_LABELS[stat] .. " = " .. value)
        end
    elseif cmd == "reset" then
        local profile = BG:GetActiveProfile()
        if profile then
            BG:ResetWeights(profile.key)
            BG:Print(profile.label .. " weights reset to defaults.")
        end
    elseif cmd == "debug" then
        -- /bgear debug [item link]  : dump the parsed stats of an item
        local link = input:match("(|c.-|h|r)")
        if not link then
            BG:Print("usage: /bgear debug [shift-click an item link]")
            return
        end
        local info = BG:GetItem(link)
        if not info then
            BG:Print("item not cached yet, try again.")
            return
        end
        BG:Print(link .. " slot=" .. tostring(info.equipLoc) .. " usable=" .. tostring(not info.unusable))
        for stat, value in pairs(info.stats) do
            BG:Print("  " .. (BG.STAT_LABELS[stat] or stat) .. " = " .. value)
        end
        for _, line in ipairs(info.unparsed) do
            BG:Print("  |cffff8800not understood:|r " .. line)
        end
    else
        BG:Print("commands: /bgear (tuning window), status, spec <name|auto>, profile <id|auto>, view <character|class spec|off>, set <stat> <value>, reset, debug [link]")
    end
end
