-- BetterGearing: upgrade arrow or "equipped" after recipe names in the profession window's recipe list.
-- Same colors as the bags: green = upgrade for the active profile, orange = for your other profile.
-- The list is a ScrollBox that recycles row frames, so rows are decorated each time one is bound to a recipe.
local _, BG = ...

local ARROW_ATLAS = "bags-greenarrow"
-- Dimmed arrow plus the level: an upgrade once you reach its required level, at most this many levels away.
local LOOKAHEAD_LEVELS = 5
local SOON_ALPHA = 0.4
local scrollBox
local owner = {}       -- callback owner for the ScrollBox registry

local function OutputLink(recipeID)
    if not (C_TradeSkillUI and recipeID) then
        return nil
    end
    if C_TradeSkillUI.GetRecipeOutputItemData then
        local ok, output = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID)
        if ok and output and output.hyperlink then
            return output.hyperlink
        end
    end
    if C_TradeSkillUI.GetRecipeItemLink then
        local ok, link = pcall(C_TradeSkillUI.GetRecipeItemLink, recipeID)
        if ok and type(link) == "string" and link:find("item:") then
            return link
        end
    end
end

local function Widgets(row)
    local widgets = row.BetterGearing
    if not widgets then
        widgets = {}
        widgets.arrow = row:CreateTexture(nil, "OVERLAY", nil, 7)
        widgets.arrow:SetSize(14, 14)
        if not (widgets.arrow.SetAtlas and pcall(widgets.arrow.SetAtlas, widgets.arrow, ARROW_ATLAS)) then
            widgets.arrow:SetTexture("Interface\\Buttons\\UI-MicroStream-Green")
            widgets.arrow:SetTexCoord(0, 1, 1, 0)   -- flip the down arrow to point up
        end
        widgets.level = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        widgets.level:SetTextColor(1, 0.82, 0)
        widgets.level:SetPoint("LEFT", widgets.arrow, "RIGHT", 1, 0)
        widgets.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        widgets.text:SetTextColor(1, 0.82, 0)
        widgets.text:SetText("equipped")
        row.BetterGearing = widgets
    end
    return widgets
end

-- Left edge for our marker: just past the recipe name, or past the "[3]" craftable count that
-- follows it, so neither is covered.
local function Place(region, row)
    local after = row.Label
    if row.Count and row.Count:IsShown() and (row.Count:GetText() or "") ~= "" then
        after = row.Count
    end
    local width = math.min(after:GetStringWidth() or 0, after:GetWidth() or 0)
    region:ClearAllPoints()
    region:SetPoint("LEFT", after, "LEFT", width + 3, 0)
end

local retryQueued = false
local Refresh

-- Returns false when the item data is not loaded yet.
local function Decorate(row, node)
    local widgets = row.BetterGearing
    local data = node and node.GetData and node:GetData()
    local recipeInfo = type(data) == "table" and data.recipeInfo
    if not (recipeInfo and row.Label and BetterGearingDB and BG:GetActiveProfile()) then
        if widgets then
            widgets.arrow:Hide()
            widgets.level:Hide()
            widgets.text:Hide()
        end
        return true
    end

    local link = OutputLink(recipeInfo.recipeID)
    local state, soonLevel, equipped = false, nil, false
    if link then
        local ok, result = pcall(BG.Compare, BG, link, BG:GetActiveProfile())
        if ok and result.pending then
            state = nil
        elseif ok and result.reason == "equipped" then
            equipped = true
        else
            local okState, bagState, bagSoon = pcall(BG.BagState, BG, link, LOOKAHEAD_LEVELS)
            if okState then
                state, soonLevel = bagState, bagSoon
            end
        end
    end

    if not (state or equipped or widgets) then
        return state ~= nil
    end
    widgets = Widgets(row)
    widgets.arrow:SetShown(state and true or false)
    widgets.level:SetShown(state and soonLevel and true or false)
    widgets.text:SetShown(equipped)
    if state then
        widgets.arrow:SetVertexColor(1, state == "other" and 0.55 or 1, state == "other" and 0.1 or 1)
        widgets.arrow:SetAlpha(soonLevel and SOON_ALPHA or 1)
        if soonLevel then
            widgets.level:SetText(soonLevel)
        end
        Place(widgets.arrow, row)
    elseif equipped then
        Place(widgets.text, row)
    end
    return state ~= nil
end

local function QueueRetry()
    if retryQueued then
        return
    end
    retryQueued = true
    C_Timer.After(0.5, function()
        retryQueued = false
        Refresh()
    end)
end

function Refresh()
    if not (scrollBox and scrollBox:IsVisible() and scrollBox.ForEachFrame) then
        return
    end
    local pending = false
    scrollBox:ForEachFrame(function(row, node)
        local ok, ready = pcall(Decorate, row, node or (row.GetElementData and row:GetElementData()))
        if ok and not ready then
            pending = true
        elseif not ok and BG.debug then
            BG:Print(ready)
        end
    end)
    if pending then
        QueueRetry()
    end
end

local function Hook()
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    local box = page and page.RecipeList and page.RecipeList.ScrollBox
    if not (box and box.RegisterCallback and ScrollBoxListMixin and ScrollBoxListMixin.Event) then
        return false
    end
    scrollBox = box
    box:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, function(_, row, node)
        local ok, ready = pcall(Decorate, row, node)
        if ok and not ready then
            QueueRetry()
        end
    end, owner)
    Refresh()
    return true
end

-- Coalesce bursts of change events (gear swaps, weight edits) into one refresh.
local queued = false
BG:OnChanged(function()
    if queued then
        return
    end
    queued = true
    C_Timer.After(0.2, function()
        queued = false
        Refresh()
    end)
end)

-- The client loads Blizzard_Professions on demand, the first time the window opens.
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self)
    local ok, hooked = pcall(Hook)
    if ok and hooked then
        self:UnregisterAllEvents()
    end
end)
