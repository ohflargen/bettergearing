-- BetterGearing: tuning window (/bgear). Edit the stat weights of each profile of your spec.
local _, BG = ...

local window
local shownProfile   -- profile being edited
local rows = {}

local function FormatWeight(value)
    local text = string.format("%.3f", value):gsub("0+$", ""):gsub("%.$", "")
    return text
end

local function RefreshRows()
    if not window or not shownProfile then
        return
    end
    window.profileButton:SetText(shownProfile.label)
    local active = BG:GetActiveProfile()
    window.status:SetText(shownProfile == active and "|cff40ff40Active profile|r" or "|cffaaaaaaNot active right now|r")
    for _, row in ipairs(rows) do
        local value = BG:GetWeight(shownProfile, row.stat)
        row.box:SetText(FormatWeight(value))
        row.box:SetCursorPosition(0)
        if BG:IsOverridden(shownProfile, row.stat) then
            row.label:SetTextColor(1, 0.82, 0)      -- changed from default
        elseif value == 0 then
            row.label:SetTextColor(0.5, 0.5, 0.5)   -- ignored stat
        else
            row.label:SetTextColor(1, 1, 1)
        end
    end
end

local function Commit(row)
    local value = tonumber(row.box:GetText())
    if value and shownProfile then
        BG:SetWeight(shownProfile.key, row.stat, value)
    end
    RefreshRows()
end

local function Build()
    window = CreateFrame("Frame", "BetterGearingTuneFrame", UIParent, "BasicFrameTemplateWithInset")
    window:SetSize(470, 470)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    tinsert(UISpecialFrames, "BetterGearingTuneFrame")

    local title = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
    title:SetText("BetterGearing - stat weights")

    local profileButton = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    profileButton:SetSize(240, 24)
    profileButton:SetPoint("TOPLEFT", 16, -34)
    profileButton:SetScript("OnClick", function()
        -- Cycle through the profiles of the current spec.
        local profiles = BG:GetProfiles()
        for index, profile in ipairs(profiles) do
            if profile == shownProfile then
                shownProfile = profiles[index % #profiles + 1]
                break
            end
        end
        RefreshRows()
    end)
    window.profileButton = profileButton

    local status = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("LEFT", profileButton, "RIGHT", 10, 0)
    window.status = status

    local hint = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 18, -62)
    hint:SetWidth(430)
    hint:SetJustifyH("LEFT")
    hint:SetText("Value of one point of each stat (percent stats: per 1%). 0 = ignored. Press Enter to apply. Gold = changed from default.")

    local perColumn = math.ceil(#BG.STAT_ORDER / 2)
    for index, stat in ipairs(BG.STAT_ORDER) do
        local column = index > perColumn and 1 or 0
        local line = (index - 1) % perColumn
        local row = { stat = stat }

        row.label = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.label:SetPoint("TOPLEFT", 22 + column * 222, -96 - line * 25)
        row.label:SetText(BG.STAT_LABELS[stat])

        row.box = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
        row.box:SetSize(52, 20)
        row.box:SetPoint("TOPLEFT", 158 + column * 222, -92 - line * 25)
        row.box:SetAutoFocus(false)
        row.box:SetMaxLetters(7)
        row.box:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            Commit(row)
        end)
        row.box:SetScript("OnEscapePressed", function(self)
            RefreshRows()   -- restore the saved value first so losing focus doesn't commit the edit
            self:ClearFocus()
        end)
        row.box:SetScript("OnEditFocusLost", function()
            Commit(row)
        end)
        rows[#rows + 1] = row
    end

    local reset = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    reset:SetSize(150, 24)
    reset:SetPoint("BOTTOMLEFT", 16, 14)
    reset:SetText("Reset this profile")
    reset:SetScript("OnClick", function()
        if shownProfile then
            BG:ResetWeights(shownProfile.key)
            RefreshRows()
        end
    end)

    window:SetScript("OnShow", RefreshRows)
end

function BG:ToggleTuneWindow()
    local profiles = self:GetProfiles()
    if #profiles == 0 then
        local specId = self:GetSpec()
        self:Print("no profile for your spec yet (" .. tostring(specId) .. "). Available: " .. self:ListSpecs()
            .. ". Use /bgear spec <name> to force one.")
        return
    end
    if not window then
        Build()
        window:Hide()
    end
    if window:IsShown() then
        window:Hide()
        return
    end
    -- Start on the active profile; keep the previous choice if it still belongs to this spec.
    local keep = false
    for _, profile in ipairs(profiles) do
        if profile == shownProfile then
            keep = true
        end
    end
    if not keep then
        shownProfile = self:GetActiveProfile()
    end
    window:Show()
end
