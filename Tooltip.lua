-- BetterGearing: add the upgrade verdict for every profile of the current spec to item tooltips.
local _, BG = ...

local REASONS = {
    unusable = "you can't equip this",
    mismatch = "wrong stats for this spec",
    shield = "needs a one-hander + shield",
    offhand = "can't go with your current weapon",
}

local function ProfileLine(link, profile, isActive, showName)
    local result = BG:Compare(link, profile)
    if result.pending or result.reason == "notgear" then
        return nil
    end
    local name = (showName and profile.short or profile.label) .. (isActive and showName and " (active)" or "")

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
        -- A percentage against a near-worthless equipped item (score ~0) is meaningless, so hide it.
        local pct = (result.pct and result.base >= 1 and result.pct <= 300) and string.format(" (+%.0f%%)", result.pct) or ""
        text = string.format("|cff40ff40upgrade +%.1f%s|r", result.delta, pct)
        if result.level then
            text = text .. string.format(" |cffffd100at level %d|r", result.level)
        end
        if result.training then
            text = text .. " |cffffd100once trained|r"
        end
    elseif result.delta > -0.1 then
        text = "|cffaaaaaaabout the same|r"
    else
        local pct = (result.pct and result.base >= 1) and string.format(" (%.0f%%)", result.pct) or ""
        text = string.format("|cffff4040worse %.1f%s|r", result.delta, pct)
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
    local profiles = BG:GetProfiles()
    if #profiles == 0 then
        return
    end
    local active = BG:GetActiveProfile()
    local several = #profiles > 1

    local added = false
    for _, profile in ipairs(profiles) do
        local name, text, why = ProfileLine(link, profile, profile == active, several)
        if name then
            if not added then
                tooltip:AddLine(" ")
                added = true
            end
            tooltip:AddDoubleLine("|cff33ff99" .. name .. "|r", text)
            if why then
                tooltip:AddLine("   " .. why, 1, 1, 1)
            end
        end
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
