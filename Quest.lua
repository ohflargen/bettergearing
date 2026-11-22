-- BetterGearing: upgrade arrows on quest reward buttons (quest giver window and quest log).
-- Same colors as the bags: green = upgrade for the active profile, orange = for your other profile.
local _, BG = ...

local ARROW_ATLAS = "bags-greenarrow"

local function CollectButtons()
    local list, seen = {}, {}
    local function add(button)
        if button and not seen[button] and button.IsVisible then
            seen[button] = true
            list[#list + 1] = button
        end
    end
    for _, frameName in ipairs({ "QuestInfoRewardsFrame", "MapQuestInfoRewardsFrame" }) do
        local frame = _G[frameName]
        if frame and frame.RewardButtons then
            for _, button in ipairs(frame.RewardButtons) do
                add(button)
            end
        end
    end
    for i = 1, 10 do
        add(_G["QuestInfoItem" .. i])
        add(_G["QuestInfoRewardsFrameQuestInfoItem" .. i])
        add(_G["QuestLogItem" .. i])
        add(_G["QuestRewardItem" .. i])
        add(_G["QuestDetailItem" .. i])
    end
    return list
end

local function IsLogButton(button)
    local name = button.GetName and button:GetName() or ""
    if name:find("^QuestLogItem") or name:find("^MapQuest") then
        return true
    end
    if QuestInfoFrame and QuestInfoFrame.questLog then
        return true
    end
    return not (QuestFrame and QuestFrame:IsShown())
end

local function LinkFor(button)
    local itemType = button.type or button.rewardType
    local index = button.GetID and button:GetID() or 0
    if (itemType ~= "choice" and itemType ~= "reward") or index <= 0 then
        return nil
    end
    if button.objectType and button.objectType ~= "item" then
        return nil
    end
    local first, second = GetQuestItemLink, GetQuestLogItemLink
    if IsLogButton(button) then
        first, second = second, first
    end
    for _, getter in ipairs({ first, second }) do
        if getter then
            local ok, link = pcall(getter, itemType, index)
            if ok and type(link) == "string" and link ~= "" then
                return link
            end
        end
    end
    return nil, true   -- an item reward whose link is not available yet
end

local function ArrowFor(button)
    local arrow = button.BetterGearingArrow
    if not arrow then
        arrow = button:CreateTexture(nil, "OVERLAY", nil, 7)
        arrow:SetSize(18, 18)
        local icon = button.Icon or button.icon or (button.GetName and button:GetName() and _G[button:GetName() .. "IconTexture"])
        arrow:SetPoint("TOPLEFT", icon or button, "TOPLEFT", -3, 3)
        if not (arrow.SetAtlas and pcall(arrow.SetAtlas, arrow, ARROW_ATLAS)) then
            arrow:SetTexture("Interface\\Buttons\\UI-MicroStream-Green")
            arrow:SetTexCoord(0, 1, 1, 0)   -- flip the down arrow to point up
        end
        button.BetterGearingArrow = arrow
    end
    return arrow
end

local retryQueued = false
local Update

local function QueueRetry()
    if retryQueued then
        return
    end
    retryQueued = true
    C_Timer.After(0.5, function()
        retryQueued = false
        Update()
    end)
end

function Update()
    if not BetterGearingDB then
        return
    end
    local pending = false
    for _, button in ipairs(CollectButtons()) do
        local state = false
        if button:IsVisible() then
            local link, notReady = LinkFor(button)
            if link then
                local ok, result = pcall(BG.BagState, BG, link)
                if ok then
                    state = result
                end
            elseif notReady then
                state = nil
            end
        end
        if state == nil then
            pending = true
        end
        if state or button.BetterGearingArrow then
            local arrow = ArrowFor(button)
            arrow:SetShown(state and true or false)
            if state == "other" then
                arrow:SetVertexColor(1, 0.55, 0.1)
            else
                arrow:SetVertexColor(1, 1, 1)
            end
        end
    end
    if pending then
        QueueRetry()
    end
end

-- Run shortly after the quest UI has laid out its buttons; coalesce bursts.
local queued = false
local function Schedule()
    if queued then
        return
    end
    queued = true
    C_Timer.After(0.05, function()
        queued = false
        local ok, err = pcall(Update)
        if not ok and BG.debug then
            BG:Print(err)
        end
    end)
end

BG:OnChanged(Schedule)

local frame = CreateFrame("Frame")
for _, event in ipairs({ "QUEST_DETAIL", "QUEST_COMPLETE", "QUEST_PROGRESS", "QUEST_ITEM_UPDATE", "QUEST_LOG_UPDATE" }) do
    pcall(frame.RegisterEvent, frame, event)
end
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        for _, name in ipairs({ "QuestInfo_Display", "QuestInfo_ShowRewards", "QuestFrameItems_Update",
            "QuestLog_UpdateQuestDetails", "QuestLog_Update", "QuestLog_SetSelection" }) do
            if type(_G[name]) == "function" then
                hooksecurefunc(name, Schedule)
            end
        end
        return
    end
    Schedule()
end)
