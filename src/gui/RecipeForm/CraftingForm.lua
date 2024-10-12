---@class Addon
local Addon = select(2, ...)
local GUI, Util = Addon.GUI, Addon.Util
local NS = GUI.RecipeForm

local Parent = Util:TblCombineMixins(NS.RecipeCraftingForm, NS.AmountForm)

---@class GUI.RecipeForm.CraftingForm: GUI.RecipeForm.RecipeCraftingForm, GUI.RecipeForm.AmountForm
---@field recraftRecipeID number?
---@field recraftItemLink string?
local Self = Mixin(NS.CraftingForm, Parent)

-- Recraft slots

---@param frame ReagentSlot
function Self:RecraftInputSlotOnEnter(frame)
    local form = frame:GetParent():GetParent() --[[@as RecipeCraftingForm]]

    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")

    local itemGUID = form.transaction:GetRecraftAllocation()
    if itemGUID then
        GameTooltip:SetItemByGUID(itemGUID)
    elseif self.recraftRecipeID then
        local link = self.recraftItemLink or C_TradeSkillUI.GetRecipeItemLink(self.recraftRecipeID)
        GameTooltip:SetHyperlink(link)
    end

    if itemGUID or self.recraftRecipeID then
        GameTooltip_AddBlankLineToTooltip(GameTooltip)
        GameTooltip_AddInstructionLine(GameTooltip, RECRAFT_REAGENT_TOOLTIP_CLICK_TO_REPLACE)
    else
        GameTooltip_AddInstructionLine(GameTooltip, RECRAFT_REAGENT_TOOLTIP_CLICK_TO_ADD)
    end

    GameTooltip:Show()
end

---@param frame OutputSlot
function Self:RecraftOutputSlotOnClick(frame)
    local form = frame:GetParent():GetParent() --[[@as RecipeCraftingForm]]

    local itemGUID = form.transaction:GetRecraftAllocation()
    local reagents = form.transaction:CreateCraftingReagentInfoTbl()
    local op = form:GetRecipeOperationInfo()

    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")

    local outputItemInfo = C_TradeSkillUI.GetRecipeOutputItemData(
        form.recipeSchematic.recipeID,
        reagents,
        itemGUID,
        op and op.craftingQualityID
    )

    if outputItemInfo and outputItemInfo.hyperlink then
        HandleModifiedItemClick(outputItemInfo.hyperlink)
    end
end

---@param recipe CraftingRecipeSchematic
function Self:Init(_, recipe)
    Parent.Init(self, _, recipe)

    if not recipe then return end

    self.form.recraftSlot.InputSlot:SetScript("OnEnter", Util:FnBind(self.RecraftInputSlotOnEnter, self))
    self.form.recraftSlot.OutputSlot:SetScript("OnClick", Util:FnBind(self.RecraftOutputSlotOnClick, self))

    if self.recraftRecipeID then
        local same = self.recraftRecipeID == recipe.recipeID
        self:SetRecraftRecipe(same and self.recraftRecipeID or nil, same and self.recraftItemLink or nil)
    end
end

function Self:Refresh()
    Parent.Refresh(self)

    self:UpdateAmountSpinner()
end

---------------------------------------
--              Util
---------------------------------------

function Self:SetRecraftRecipe(recipeId, link, transition)
    if recipeId and not link then
        link = C_TradeSkillUI.GetRecipeItemLink(recipeId)
        if not link then recipeId = nil end
    end

    self.recraftRecipeID = recipeId
    self.recraftItemLink = link

    if not self.form or not recipeId then return end

    if transition then
        Professions.SetRecraftingTransitionData({ isRecraft = true, itemLink = link })
        C_TradeSkillUI.OpenRecipe(recipeId)
    end

    self.form.recraftSlot:Init(nil, Util.FnTrue, Util.FnNoop, link)
end

---------------------------------------
--              Events
---------------------------------------

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if not Util:IsAddonLoadingOrLoaded("Blizzard_Professions", addonName) then return end

    local craftingPage = ProfessionsFrame.CraftingPage
    self.form = craftingPage.SchematicForm

    Parent.OnAddonLoaded(self)

    -- Elements

    -- Insert experiment checkbox
    self:InsertExperimentBox(
        self.form,
        "LEFT", self.form.AllocateBestQualityCheckbox.text, "RIGHT", 20, 0
    )

    -- Insert tracked amount spinner
    self:InsertAmountSpinner(
        "RIGHT", self.form.TrackRecipeCheckbox, "LEFT", -30, 1
    )

    -- Insert skill points spinner
    self:InsertSkillSpinner(
        self.form.Details.StatLines.SkillStatLine,
        "RIGHT", -50, 1
    )

    -- Insert optimization buttons
    self:InsertOptimizationButtons(
        craftingPage,
        "BOTTOMLEFT", craftingPage.RecipeList, "BOTTOMRIGHT", 2, 2
    )

    -- Hooks

    hooksecurefunc(self.form, "Init", Util:FnBind(self.Init, self))
    hooksecurefunc(self.form, "Refresh", Util:FnBind(self.Refresh, self))
    hooksecurefunc(self.form, "UpdateDetailsStats", Util:FnBind(self.UpdateDetailsStats, self))

    hooksecurefunc(self.form.Details, "SetStats", Util:FnBind(self.DetailsSetStats, self))
end

Addon:RegisterCallback(Addon.Event.AddonLoaded, Self.OnAddonLoaded, Self)