---@class TestFlight
local Addon = select(2, ...)
local GUI, Reagents, Util = Addon.GUI, Addon.Reagents, Addon.Util

local settings = {
    headerText = PROFESSIONS_COLUMN_HEADER_REAGENTS or "Reagents",
    events = {
        "CURRENCY_DISPLAY_UPDATE",
        "TRACKED_RECIPE_UPDATE",
        "BAG_UPDATE_DELAYED",
        "CRAFTINGORDERS_CLAIMED_ORDER_ADDED",
        "CRAFTINGORDERS_CLAIMED_ORDER_REMOVED",
        "CRAFTINGORDERS_CLAIMED_ORDER_UPDATED",
        "PLAYER_REGEN_DISABLED",
        "PLAYER_REGEN_ENABLED"
    },
    blockTemplate = "ObjectiveTrackerAnimBlockTemplate",
    lineTemplate = "ObjectiveTrackerAnimLineTemplate",
}

---@class ReagentsTrackerMixin: ObjectiveTrackerModuleMixin, DirtiableMixin
---@field GetBlock fun(self: self, id: number | string): ObjectiveTrackerAnimBlock
local Self = CreateFromMixins(ObjectiveTrackerModuleMixin, settings)

---@class ReagentsTracker: ReagentsTrackerMixin, Frame

function Addon:CreateReagentsTracker()
    local frame = Mixin(CreateFrame("Frame", nil, nil, "ObjectiveTrackerModuleTemplate"), Self) --[[@as ReagentsTracker]]

    frame:SetScript("OnLoad", frame.OnLoad)
    frame:SetScript("OnEvent", frame.OnEvent)
    frame:SetScript("OnHide", frame.OnHide)
    frame:OnLoad()

    return frame
end

function Self:InitModule()
    self.dirtyCallback = function () self:Update() end
end

function Self:MarkDirty()
    if self.isDirty then return end
    self.isDirty = true
    if InCombatLockdown() then return end
    C_Timer.After(0, self.dirtyCallback)
end

function Self:Update(availableHeight, dirtyUpdate)
    if not availableHeight then
        local parent = self.parentContainer
        if not parent then return end

        availableHeight = parent:GetAvailableHeight()
        for _,m in pairs(parent.modules) do availableHeight = availableHeight - m:GetContentsHeight() end
    end

    return ObjectiveTrackerModuleMixin.Update(self, availableHeight, dirtyUpdate)
end

function Self:LayoutContents()
    if not Addon.DB.Account.reagents then return end

	if self.continuableContainer then self.continuableContainer:Cancel() end
	self.continuableContainer = ContinuableContainer:Create()

    local reagents, orderReagents = Reagents:GetTracked()
    if not next(reagents) and not next(orderReagents) then return end

    for itemID in pairs(reagents) do
        self.continuableContainer:AddContinuable(Item:CreateFromItemID(itemID))
    end
    for itemID in pairs(orderReagents) do
        self.continuableContainer:AddContinuable(Item:CreateFromItemID(itemID))
    end

    -- On load add blocks if items were loaded already, refresh otherwise
    local wasLoaded = true
	wasLoaded = self.continuableContainer:ContinueOnLoad(function ()
        if not wasLoaded then return self:MarkDirty() end
        self:AddBlocks(reagents, orderReagents)
    end)
end

---@param reagents number[]
---@param orderReagents number[]
function Self:AddBlocks(reagents, orderReagents)
    local GetCraftingReagentCount = Util:TblGetHooked(ItemUtil, "GetCraftingReagentCount")

    local grouped = Util:TblGroupBy(reagents, function (quantityRequired, itemID)
        return GetCraftingReagentCount(itemID) < quantityRequired
    end, true)

    self:AddReagents("missing", ADDON_MISSING, grouped[true])
    self:AddReagents("complete", COMPLETE, grouped[false])
    self:AddReagents("order", "Provided", orderReagents, true)
end

---@param key any
---@param header string
---@param reagents? number[]
---@param provided? boolean
function Self:AddReagents(key, header, reagents, provided)
    if not reagents or not next(reagents) then return end

    local block = self:GetBlock(key)

    block:SetHeader(header)

    local itemIDs = Util(reagents):Keys():Sort()()
    local GetCraftingReagentCount = Util:TblGetHooked(ItemUtil, "GetCraftingReagentCount")

    for _,itemID in pairs(itemIDs) do
        local name = C_Item.GetItemInfo(itemID)
        local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemID)
        local qualityIcon = quality and C_Texture.GetCraftingReagentQualityChatIcon(quality)
        local label = name .. (qualityIcon and " " .. qualityIcon or "")

        local quantityRequired = reagents[itemID]
        local quantity = provided and quantityRequired or GetCraftingReagentCount(itemID)
        local metQuantity = quantity >= quantityRequired

        local count = PROFESSIONS_TRACKER_REAGENT_COUNT_FORMAT:format(quantity, quantityRequired)
        local text = PROFESSIONS_TRACKER_REAGENT_FORMAT:format(count, label)
        local dashStyle = metQuantity and OBJECTIVE_DASH_STYLE_HIDE or OBJECTIVE_DASH_STYLE_SHOW
        local colorStyle = OBJECTIVE_TRACKER_COLOR[metQuantity and "Complete" or "Normal"]

        local line = block:AddObjective(itemID, text, nil, nil, dashStyle, colorStyle)

        -- Icon
        line.Icon:SetShown(metQuantity)
        if metQuantity then
            line.Icon:SetAtlas("ui-questtracker-tracker-check", false)
        end

        -- Button
        GUI:SetReagentLineButton(line, name)
    end

    return self:LayoutBlock(block)
end

---@param self ReagentsTracker
---@param dirtyUpdate? boolean
function Self:UpdatePosition(dirtyUpdate)
    if not Addon.DB.Account.reagents then return end

    if InCombatLockdown() then
        if self:ShouldHideInCombat() then self:RemoveFromParent() end
        if not self:IsShown() then
            if not dirtyUpdate then self.isDirty = true end
            return
        end
    end

    if ProfessionsRecipeTracker:GetContentsHeight() == 0 then return end

    local parent = self.parentContainer
    if not parent then return end

    self.prevModule = nil
    for _,module in ipairs(parent.modules) do
        if module == ProfessionsRecipeTracker then break end
        if module:GetContentsHeight() > 0 then self.prevModule = module end
    end

    local height, isTruncated = self:Update(nil, dirtyUpdate)

    if height == 0 or isTruncated then return end

    self:ClearAllPoints()
    self:SetPoint("LEFT", parent, "LEFT", self.leftMargin, 0)

    if self.prevModule then
        self:SetPoint("TOP", self.prevModule, "BOTTOM", 0, -parent.moduleSpacing)
    else
        self:SetPoint("TOP", 0, -parent.topModulePadding)
    end

    ProfessionsRecipeTracker:ClearAllPoints()
    ProfessionsRecipeTracker:SetPoint("TOP",self, "BOTTOM", 0, -parent.moduleSpacing)
end

function Self:ShouldHideInCombat()
    return WorldQuestObjectiveTracker:GetContentsHeight() > 0
        or BonusObjectiveTracker:GetContentsHeight() > 0
end

---@param self ReagentsTracker
function Self:RemoveFromParent()
    if not self:IsShown() or self:GetContentsHeight() == 0 then return end

    local parent = self.parentContainer
    if not parent then return end

    self:Hide()
    self.isDirty = true

    ProfessionsRecipeTracker:ClearAllPoints()
    ProfessionsRecipeTracker:SetPoint("LEFT", parent, "LEFT", self.leftMargin, 0)

    if self.prevModule then
        ProfessionsRecipeTracker:SetPoint("TOP", self.prevModule, "BOTTOM", 0, -parent.moduleSpacing)
    else
        ProfessionsRecipeTracker:SetPoint("TOP", 0, -parent.topModulePadding)
    end
end

---------------------------------------
--              Events
---------------------------------------

---@param self ReagentsTracker
function Self:OnEvent(event)
    if event == "PLAYER_REGEN_DISABLED" then
        if not self:ShouldHideInCombat() then return end
        self:RemoveFromParent()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if not self.isDirty then return end
        self:UpdatePosition(true)
    else
        self:MarkDirty()
    end
end