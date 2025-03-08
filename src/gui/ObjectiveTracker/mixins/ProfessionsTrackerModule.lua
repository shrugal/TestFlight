---@class Addon
local Addon = select(2, ...)
local GUI, Reagents, Util = Addon.GUI, Addon.Reagents, Addon.Util

---@class GUI.ObjectiveTracker.ProfessionsTrackerModule
---@field module ObjectiveTrackerModuleMixin
local Self = GUI.ObjectiveTracker.ProfessionsTrackerModule

---@type FramePool
Self.reagentLineButtonPool = nil

function Self:GetReagentLineButtonPool()
    if not Self.reagentLineButtonPool then
        Self.reagentLineButtonPool = CreateFramePool("Button", nil, nil, function (_, f)
            f:Hide()
            f:SetParent()
            f:ClearAllPoints()
        end)
    end
    return Self.reagentLineButtonPool
end

---@param btn Button
---@param mouseButton string
function Self:LineOnClick(btn, mouseButton)
    local line = btn:GetParent() --[[@as QuestObjectiveAnimLine]]

    CloseDropDownMenus()

    if AuctionHouseFrame and AuctionHouseFrame:IsVisible() then
        if AuctionHouseFrame:SetSearchText(line.itemName) then AuctionHouseFrame.SearchBar:StartSearch() end
    else
        EventRegistry:TriggerEvent("Professions.ReagentClicked", line.itemName)
    end
end

---@param line ObjectiveTrackerLine
---@param itemName string
function Self:SetReagentLineButton(line, itemName, itemID)
    -- Name
    line.itemName = itemName
    line.itemID = itemID

    if line.Button then line.Button:Show() return end

    local pool = Self:GetReagentLineButtonPool()

    -- Button
    local btn = pool:Acquire() --[[@as Button]]
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", Util:FnBind(self.LineOnClick, self))
    btn:SetParent(line)
    btn:SetAllPoints(line)
    btn:Show()
    line.Button = btn

    -- OnFree
    local OnFree = line.OnFree
    function line:OnFree(...)
        pool:Release(self.Button)
        self.itemName, self.itemID, self.Button =  nil, nil, nil
        self.OnFree = OnFree
        if self.OnFree then return self:OnFree(...) end
    end
end

---------------------------------------
--              Events
---------------------------------------

function Self:OnAddonLoaded()
    Reagents:RegisterCallback(Reagents.Event.TrackedUpdated, self.module.MarkDirty, self.module)
end