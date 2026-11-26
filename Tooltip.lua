-- BetterGearing: add the upgrade verdict for every profile of the current spec to item tooltips.
local _, BG = ...

local REASONS = {
    unusable = "you can't equip this",
    mismatch = "wrong stats for this spec",
    shield = "needs a one-hander + shield",
    offhand = "can't go with your current weapon",
}

-- Change as a percentage of everything the character wears, or "" when that total is too
-- small to give a meaningful number (fresh characters in starter gear, mostly bare slots).
local MIN_TOTAL_FOR_PERCENT = 5

local function Percent(result, profile, who, sign)
    local total = BG:TotalScore(profile, who)
    if not total or total < MIN_TOTAL_FOR_PERCENT then
        return ""
    end
    return string.format(" (%s%.0f%%)", sign, result.delta / total * 100)
end

local function ProfileLine(link, profile, who, isActive, showName)
    local result = BG:Compare(link, profile, who)
    if result.pending or result.reason == "notgear" then
        return nil
    end
    local name = (showName and profile.short or profile.label) .. (isActive and showName and " (active)" or "")

    if who.noGear and not result.reason then
        -- Spec preview: no gear to compare with, so show the item's own value.
        return name, string.format("|cffaaaaaascore %.1f|r", result.score), BG:DescribeDiffs(result, profile)
    end
    if result.reason == "equipped" then
        return name, string.format("|cffaaaaaaequipped (score %.1f)|r", result.score)
    end
    if result.reason and not result.delta then
        return name, "|cff999999" .. (REASONS[result.reason] or result.reason) .. "|r"
    end
    if result.reason == "mismatch" then
        return name, "|cff999999" .. REASONS.mismatch .. "|r"
    end

    local text
    if result.better then
        text = string.format("|cff40ff40upgrade +%.1f%s|r", result.delta, Percent(result, profile, who, "+"))
        if result.level then
            text = text .. string.format(" |cffffd100at level %d|r", result.level)
        end
        if result.training then
            text = text .. " |cffffd100once trained|r"
        end
    elseif result.delta > -0.1 then
        text = "|cffaaaaaaabout the same|r"
    else
        text = string.format("|cffff4040worse %.1f%s|r", result.delta, Percent(result, profile, who, ""))
    end
    return name, text, BG:DescribeDiffs(result, profile)
end

local function AddToTooltip(tooltip, link)
    if not link or not BetterGearingDB then
        return
    end
    local info = BG:GetItem(link)
    if not info or info.notGear then
        return
    end
    local added = false
    local function AddProfiles(profiles, who, active, heading)
        local several = #profiles > 1
        local headed = false
        for _, profile in ipairs(profiles) do
            local name, text, why = ProfileLine(link, profile, who, profile == active, several)
            if name then
                if not added then
                    tooltip:AddLine(" ")
                    added = true
                end
                if heading and not headed then
                    tooltip:AddLine(heading, 1, 0.82, 0)
                    headed = true
                end
                tooltip:AddDoubleLine("|cff33ff99" .. name .. "|r", text)
                if why then
                    tooltip:AddLine("   " .. why, 1, 1, 1)
                end
            end
        end
    end

    AddProfiles(BG:GetProfiles(), BG:PlayerWho(), BG:GetActiveProfile())
    local preview = BG:GetPreview()
    if preview then
        AddProfiles(preview.profiles, preview.who, nil, "For " .. preview.title .. ":")
    end
    if added then
        tooltip:Show()
    end
end

local function LinkFromTooltip(tooltip)
    if tooltip.GetItem then
        local _, link = tooltip:GetItem()
        if link then
            return link
        end
    end
    if TooltipUtil and TooltipUtil.GetDisplayedItem then
        local _, link = TooltipUtil.GetDisplayedItem(tooltip)
        return link
    end
end

local WATCHED = {
    GameTooltip = true, ItemRefTooltip = true,
    ShoppingTooltip1 = true, ShoppingTooltip2 = true,
}

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
        local name = tooltip.GetName and tooltip:GetName()
        if name and WATCHED[name] then
            local ok, err = pcall(AddToTooltip, tooltip, LinkFromTooltip(tooltip))
            if not ok and BG.debug then
                BG:Print(err)
            end
        end
    end)
else
    for name in pairs(WATCHED) do
        local tooltip = _G[name]
        if tooltip and tooltip.HookScript then
            pcall(tooltip.HookScript, tooltip, "OnTooltipSetItem", function(self)
                pcall(AddToTooltip, self, LinkFromTooltip(self))
            end)
        end
    end
end
