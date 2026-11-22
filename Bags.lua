-- BetterGearing: drive Bagnon's upgrade arrow.
-- Green arrow  = upgrade for the active profile.
-- Orange arrow = upgrade only for your other profile (e.g. a tanking piece while solo).
local _, BG = ...

local buttons = setmetatable({}, { __mode = "k" })   -- item buttons we have seen

local function UpdateButton(button)
    local icon = button.UpgradeIcon
    if not icon then
        return
    end
    local link = button.info and button.info.hyperlink
    local state = false
    if link and BetterGearingDB then
        local ok, result = pcall(BG.BagState, BG, link)
        state = ok and result
        if not ok then
            state = false
        end
    end
    icon:SetShown(state and true or false)
    if state == "other" then
        icon:SetVertexColor(1, 0.55, 0.1)
    else
        icon:SetVertexColor(1, 1, 1)
    end
    return state
end

local function Hook()
    local Item
    for _, name in ipairs({ "BagBrother", "Bagnon", "Bagnonium" }) do
        local bagAddon = _G[name]
        if type(bagAddon) == "table" and type(bagAddon.Item) == "table" then
            Item = bagAddon.Item
            break
        end
    end
    if not Item or Item.BetterGearingHooked then
        return Item ~= nil
    end
    Item.BetterGearingHooked = true
    BG.bagHooked = true

    function Item:UpdateUpgradeIcon()
        buttons[self] = true
        if UpdateButton(self) == nil and self.Delay then
            self:Delay(0.5, "UpdateUpgradeIcon")   -- item data not loaded yet, retry
        end
    end
    return true
end

-- For /bgear status: is the hook in place, how many bag buttons were seen, how many show an arrow.
function BG:BagStatus()
    local seen, arrows = 0, 0
    for button in pairs(buttons) do
        seen = seen + 1
        if button.UpgradeIcon and button.UpgradeIcon:IsShown() then
            arrows = arrows + 1
        end
    end
    return self.bagHooked and true or false, seen, arrows
end

local function RefreshAll()
    for button in pairs(buttons) do
        if button:IsVisible() then
            if button.UpdateUpgradeIcon then
                button:UpdateUpgradeIcon()
            else
                UpdateButton(button)
            end
        end
    end
end

-- Coalesce bursts of change events into one refresh.
local queued = false
BG:OnChanged(function()
    if queued then
        return
    end
    queued = true
    C_Timer.After(0.2, function()
        queued = false
        RefreshAll()
    end)
end)

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self)
    if Hook() then
        self:UnregisterAllEvents()
    end
end)
