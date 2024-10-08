---@class TestFlight
local Addon = select(2, ...)
local GUI, Reagents, Recipes, Util = Addon.GUI, Addon.Reagents, Addon.Recipes, Addon.Util

local Parent = GUI.ObjectiveTracker.ProfessionsTrackerModule

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

---@class GUI.ObjectiveTracker.ReagentsTracker: GUI.ObjectiveTracker.ProfessionsTrackerModule, ObjectiveTrackerModuleMixin, DirtiableMixin
---@field GetBlock fun(self: self, id: number | string): ObjectiveTrackerAnimBlock
local Self = Mixin(GUI.ObjectiveTracker.ReagentsTracker, ObjectiveTrackerModuleMixin, Parent, settings)

---@class ReagentsTrackerFrame: GUI.ObjectiveTracker.ReagentsTracker, Frame

function Self:Create()
    local frame = Mixin(CreateFrame("Frame", nil, nil, "ObjectiveTrackerModuleTemplate"), self) --[[@as ReagentsTrackerFrame]]

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
    local craftingResults = Recipes:GetTrackedResultItems()

    local reagentsOwned, reagentsCrafting, reagentsMissing = {}, {}, {}
    for itemID,required in pairs(reagents) do
        local owned = GetCraftingReagentCount(itemID)
        if owned > 0 then
            reagentsOwned[itemID], required = owned, max(0, required - owned)
        end
        local crafting = min(required, craftingResults[itemID] or 0)
        if crafting > 0 then
            reagentsCrafting[itemID], required = crafting, required - crafting
        end
        if required > 0 then
            reagentsMissing[itemID] = required
        end
    end

    local addedMissing = self:AddReagents("missing", ADDON_MISSING, reagentsMissing)
    if not addedMissing and next(reagentsMissing) then return end

    self:AddReagents("crafting", "Crafting", reagentsCrafting)
    self:AddReagents("owned", "Owned", reagentsOwned, reagents)
    self:AddReagents("provided", "Provided", orderReagents, true)
end

---@param key any
---@param header string
---@param reagents? number[]
---@param providedOrTotal? number[] | true
function Self:AddReagents(key, header, reagents, providedOrTotal)
    if not reagents or not next(reagents) then return end

    local block = self:GetBlock(key)

    block:SetHeader(header)

    local itemIDs = Util(reagents):Keys():Sort()()

    for _,itemID in pairs(itemIDs) do
        local name = C_Item.GetItemInfo(itemID)
        local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemID)
        local qualityIcon = quality and C_Texture.GetCraftingReagentQualityChatIcon(quality)
        local label = name .. (qualityIcon and " " .. qualityIcon or "")

        local quantity = reagents[itemID]

        local count, complete = quantity, false
        if providedOrTotal then
            local quantityTotal = providedOrTotal == true and quantity or providedOrTotal[itemID]
            count = PROFESSIONS_TRACKER_REAGENT_COUNT_FORMAT:format(quantity, quantityTotal)
            complete = quantity >= quantityTotal
        end

        local text = PROFESSIONS_TRACKER_REAGENT_FORMAT:format(count, label)
        local dashStyle = complete and OBJECTIVE_DASH_STYLE_HIDE or OBJECTIVE_DASH_STYLE_SHOW
        local colorStyle = OBJECTIVE_TRACKER_COLOR[complete and "Complete" or "Normal"]

        local line = block:AddObjective(itemID, text, nil, nil, dashStyle, colorStyle)

        -- Icon
        line.Icon:SetShown(complete)
        if complete then
            line.Icon:SetAtlas("ui-questtracker-tracker-check", false)
        end

        -- Button
        self:SetReagentLineButton(line, name, key == "crafting" and itemID or nil)
    end

    return self:LayoutBlock(block)
end

---@param btn Button
---@param mouseButton string
function Self:LineOnClick(btn, mouseButton)
    local line = btn:GetParent() --[[@as ObjectiveTrackerLine]]

    if line.itemID and mouseButton ~= "RightButton" then
        for _,recipeID in pairs(C_TradeSkillUI.GetRecipesTracked(false)) do
            local output = C_TradeSkillUI.GetRecipeOutputItemData(recipeID, nil, nil, Recipes:GetTrackedQuality(recipeID))

            if output and output.itemID == line.itemID then
                if not ProfessionsFrame then ProfessionsFrame_LoadUI() end

                if IsModifiedClick("RECIPEWATCHTOGGLE") then
                    C_TradeSkillUI.SetRecipeTracked(recipeID, false, false)
                elseif C_TradeSkillUI.IsRecipeProfessionLearned(recipeID) then
					C_TradeSkillUI.OpenRecipe(recipeID)
				else
					Professions.InspectRecipe(recipeID);
				end

                return
            end
        end
    end

    return Parent.LineOnClick(self, btn, mouseButton)
end

function Self:ShouldHideInCombat()
    return WorldQuestObjectiveTracker:GetContentsHeight() > 0
        or BonusObjectiveTracker:GetContentsHeight() > 0
end

---@param self ReagentsTrackerFrame
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

    local height = self:Update(nil, dirtyUpdate)

    if height == 0 then return end

    self:ClearAllPoints()
    self:SetPoint("LEFT", parent, "LEFT", self.leftMargin, 0)

    if self.prevModule then
        self:SetPoint("TOP", self.prevModule, "BOTTOM", 0, -parent.moduleSpacing)
    else
        self:SetPoint("TOP", 0, -parent.topModulePadding)
    end

    ProfessionsRecipeTracker:ClearAllPoints()
    ProfessionsRecipeTracker:SetPoint("TOP", self, "BOTTOM", 0, -parent.moduleSpacing)

    GUI.ObjectiveTracker.WorldQuestTracker:RefreshTrackerAnchor()
end

---@param self ReagentsTrackerFrame
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

    GUI.ObjectiveTracker.WorldQuestTracker:RefreshTrackerAnchor()
end

---------------------------------------
--              Events
---------------------------------------

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if not Util:IsAddonLoadingOrLoaded("Blizzard_ObjectiveTracker", addonName) then return end

    self.module = self:Create()
    self.module:SetContainer(ObjectiveTrackerFrame)

    hooksecurefunc(ObjectiveTrackerFrame, "Update", function (_, dirtyUpdate) self.module:UpdatePosition(dirtyUpdate) end)
end

---@param self ReagentsTrackerFrame
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