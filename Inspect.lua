-- BetterGearing: an icon button on the inspect window that makes the inspected player the preview,
-- so tooltips and the recipe list judge items for them.
local _, BG = ...

local button

local function InspectedUnit()
    return InspectFrame and InspectFrame.unit or "target"
end

local ICON = "Interface\\AddOns\\BetterGearing\\Icon"

-- The window's border art and title bar sit on their own high frame levels; stay above them
-- (re-checked on every show, since the window's levels change when it is raised).
local function Lift()
    local level = InspectFrame:GetFrameLevel()
    for _, part in ipairs({ InspectFrame.CloseButton or _G.InspectFrameCloseButton, InspectFrame.NineSlice,
        InspectFrame.TitleContainer, InspectFrame.PortraitContainer }) do
        if part and part.GetFrameLevel then
            level = math.max(level, part:GetFrameLevel())
        end
    end
    button:SetFrameStrata(InspectFrame:GetFrameStrata())
    button:SetFrameLevel(level + 2)
end

-- Gray while off, full color while this player is the preview.
local function UpdateButton()
    if not button then
        return
    end
    Lift()
    local on = BG:IsInspectPreview(InspectedUnit())
    button.icon:SetDesaturated(not on)
    button.icon:SetAlpha(on and 1 or 0.75)
    button.glow:SetShown(on)
end

local function Build()
    if button or not InspectFrame then
        return button ~= nil
    end
    -- A small square in the title bar, just left of the close button.
    button = CreateFrame("Button", nil, InspectFrame)
    button:SetSize(18, 18)
    local close = InspectFrame.CloseButton or _G.InspectFrameCloseButton
    if close then
        button:SetPoint("RIGHT", close, "LEFT", -2, 0)
    else
        button:SetPoint("TOPRIGHT", InspectFrame, "TOPRIGHT", -28, -3)
    end
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexture(ICON)
    button.glow = button:CreateTexture(nil, "OVERLAY")
    button.glow:SetPoint("TOPLEFT", -3, 3)
    button.glow:SetPoint("BOTTOMRIGHT", 3, -3)
    button.glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    button.glow:SetBlendMode("ADD")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnClick", function()
        local unit = InspectedUnit()
        if BG:IsInspectPreview(unit) then
            BG:PreviewCommand("off")
        else
            BG:InspectPreview(unit)
        end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local on = BG:IsInspectPreview(InspectedUnit())
        GameTooltip:AddLine("BetterGearing gear preview" .. (on and " |cff40ff40(on)|r" or ""))
        GameTooltip:AddLine("Judge items for this player against the gear they wear now: "
            .. "tooltips and your profession recipe list show their upgrades.", 1, 1, 1, true)
        GameTooltip:AddLine(on and "Click to stop." or "Click to start.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    InspectFrame:HookScript("OnShow", UpdateButton)
    UpdateButton()
    return true
end

BG:OnChanged(UpdateButton)

-- Blizzard_InspectUI loads on demand, the first time you inspect someone.
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self)
    local ok, built = pcall(Build)
    if ok and built then
        self:UnregisterAllEvents()
    end
end)
