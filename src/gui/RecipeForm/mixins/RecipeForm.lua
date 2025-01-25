---@class Addon
local Addon = select(2, ...)
local Buffs, Cache, GUI, Operation, Optimization, Orders, Reagents, Recipes, Util = Addon.Buffs, Addon.Cache, Addon.GUI, Addon.Operation, Addon.Optimization, Addon.Orders, Addon.Reagents, Addon.Recipes, Addon.Util

---@class GUI.RecipeForm.RecipeForm
---@field form RecipeForm
---@field GetTrackRecipeCheckbox fun(self: self): CheckButton
local Self = GUI.RecipeForm.RecipeForm

---@type Cache<Operation, fun(cache: Cache, self: GUI.RecipeForm.RecipeForm): string>
Self.operationCache = Cache:Create(
    ---@param self GUI.RecipeForm.RecipeForm
    function (_, self)
        local tx = self.form.transaction
        local recipe = tx:GetRecipeSchematic()
        local order = self:GetOrder()
        local orderOrRecraftGUID = order or tx:GetRecraftAllocation()
        local applyConcentration = tx:IsApplyingConcentration()

        return ("%d;%s"):format(
            order and order.orderState or 0,
            Operation:GetKey(recipe, tx.allocationTbls, orderOrRecraftGUID, applyConcentration, Addon.enabled, self:GetTool(), self:GetAuras())
        )
    end,
    nil,
    10,
    true
)

---------------------------------------
--             Tracking
---------------------------------------

---@return Recipes | Orders
---@return (CraftingRecipeSchematic | CraftingOrderInfo)?
function Self:GetTracking()
    return Recipes, self:GetRecipe()
end

function Self:UpdateTracking()
    local recipe = self:GetRecipe()
    if not recipe then return end

    local quality, operation
    if Recipes:IsTracked(recipe) then
        quality, operation = self:GetQuality(), self:GetOperation()
    end

    Recipes:SetTrackedQuality(recipe, quality)
    Recipes:SetTrackedAllocation(recipe, operation)
end

---------------------------------------
--               Util
---------------------------------------

function Self:GetRecipe()
    if not self.form.transaction then return end
    return self.form.transaction:GetRecipeSchematic()
end

---@return string? toolGUID
function Self:GetTool() end

---@return string? auras
function Self:GetAuras() end

---@param minimized? boolean
---@param nonLocal? boolean
function Self:ShouldShowElement(minimized, nonLocal)
    local recipe = self:GetRecipe()
    if not recipe then return false end

    local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipe.recipeID)
    if not recipeInfo then return false end

    return not recipeInfo.isGatheringRecipe and not recipeInfo.isDummyRecipe
        and not C_TradeSkillUI.IsRuneforging()
        and (minimized or not ProfessionsUtil.IsCraftingMinimized())
        and (nonLocal or Professions.InLocalCraftingMode())
        or false
end

---@return CraftingOrderInfo?
function Self:GetOrder() end

---@return number?
function Self:GetQuality() end

function Self:GetOperation(refresh)
    local recipe = self:GetRecipe()
    if not recipe then return end

    if Util:OneOf(recipe.recipeType, Enum.TradeskillRecipeType.Salvage, Enum.TradeskillRecipeType.Gathering) then return end

    local cache = self.operationCache
    local key = cache:Key(self)

    if not refresh and cache:Has(key) then return cache:Get(key) end

    local tx = self.form.transaction
    local order = self:GetOrder()

    local op
    if order and Orders:IsClaimable(order) then ---@cast order -?
        op = Optimization:GetOrderAllocation(order, tx, Addon.enabled)
    else
        op = Operation:FromTransaction(tx, order, Addon.enabled, self:GetTool(), self:GetAuras())
    end

    cache:Set(key, op)

    return op
end

---@param operation Operation
function Self:SetOperation(operation)
    self:AllocateBasicReagents()

    for slot in self.form.reagentSlotPool:EnumerateActive() do
        local allocs = operation.allocation[slot:GetSlotIndex()]
        if allocs then
            self:AllocateReagent(slot, allocs, true)
        end
    end

    self.form.transaction:SetApplyConcentration(operation.applyConcentration)

    self.form:TriggerEvent(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified)
end

-- Set allocation

---@param slot ReagentSlot
---@param allocations ProfessionTransationAllocations
---@param silent? boolean
function Self:AllocateReagent(slot, allocations, silent)
    if slot:IsUnallocatable() then return end

    if not Addon.enabled then
        for _,reagent in allocations:Enumerate() do
            if reagent.quantity > Reagents:GetQuantity(reagent) then
                Addon:Enable() break
            end
        end
    end

    self.form.transaction:OverwriteAllocations(slot:GetSlotIndex(), allocations)
    self.form.transaction:SetManuallyAllocated(true)

    if Reagents:IsFinishing(slot:GetReagentSlotSchematic()) then
        local alloc = allocations:SelectFirst()
        if alloc and alloc.quantity > 0 then
            slot:SetItem(Item:CreateFromItemID(alloc.reagent.itemID))
        else
            slot:ClearItem()
        end
    else
        slot:Update()
    end

    if silent then return end

    self.form:TriggerEvent(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified)
end

-- Restore slots

function Self:AllocateBasicReagents()
    local recipe = self:GetRecipe()
    if not recipe then return end

    for slot in self.form.reagentSlotPool:EnumerateActive() do
        if Reagents:IsBasic(slot:GetReagentSlotSchematic()) then
            self:AllocateBasicReagent(slot)
        end
    end
end

function Self:ResetReagentSlots()
    if not self.form.reagentSlots then return end

    local characterInventoryOnly = self.form.transaction:ShouldUseCharacterInventoryOnly()

    for slot in self.form.reagentSlotPool:EnumerateActive() do
        if not slot:IsUnallocatable() then
            for _,allocation in self.form.transaction:EnumerateAllocations(slot:GetSlotIndex()) do
                local q = Reagents:GetQuantity(allocation.reagent, characterInventoryOnly)
                if allocation.quantity > q then self:ResetReagentSlot(slot) break end
            end
        end
    end
end

---@param slot ReagentSlot
function Self:ResetReagentSlot(slot)
    if slot:IsUnallocatable() then return end

    if slot:GetOriginalItem() then
        self:RestoreOriginalSlotItem(slot)
    elseif slot:GetReagentSlotSchematic().reagentType == Enum.CraftingReagentType.Basic then
        self:AllocateBasicReagent(slot)
    elseif self.form.transaction:HasAnyAllocations(slot:GetSlotIndex()) then
        self:ClearReagentSlot(slot)
    end
end

---@param slot ReagentSlot
function Self:ClearReagentSlot(slot)
    self.form.transaction:ClearAllocations(slot:GetSlotIndex())
    slot:ClearItem()
    self.form:TriggerEvent(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified)
end

---@param slot ReagentSlot
function Self:AllocateBasicReagent(slot)
    if slot:IsUnallocatable() then return end

    local isManuallyAllocated = self.form.transaction:IsManuallyAllocated()
    local useBestQuality = self.form.AllocateBestQualityCheckbox:GetChecked()

    Professions.AllocateBasicReagents(self.form.transaction, slot:GetSlotIndex(), useBestQuality)

    self.form.transaction:SetManuallyAllocated(isManuallyAllocated)
end

---@param slot ReagentSlot
function Self:RestoreOriginalSlotItem(slot)
    if slot:IsOriginalItemSet() then return end

    local schematic = slot:GetReagentSlotSchematic()
    local modification = self.form.transaction:GetModification(schematic.dataSlotIndex)

    if modification and modification.itemID > 0 then
        local reagent = Professions.CreateCraftingReagentByItemID(modification.itemID)
        self.form.transaction:OverwriteAllocation(schematic.slotIndex, reagent, schematic.quantityRequired)
    end

    slot:RestoreOriginalItem()

    self.form:TriggerEvent(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified)
end

---------------------------------------
--             Events
---------------------------------------

function Self:OnRefresh()
    if self.form:IsVisible() then return end

    if not Addon.enabled then
        self:ResetReagentSlots()
    elseif self.form.AllocateBestQualityCheckbox:GetChecked() then
        Professions.AllocateAllBasicReagents(self.form.transaction, true)
    end
end

---@param recipeID number
---@param tracked boolean
function Self:OnTrackedRecipeUpdated(recipeID, tracked)
    if not tracked or not self.form:IsVisible() then return end

    local recipe = self:GetRecipe()
    if not recipe or recipe.recipeID ~= recipeID then return end

    self:UpdateTracking()
end

function Self:OnTraitChanged()
    self.operationCache:Clear()
end

function Self:OnAddonLoaded()
    Recipes:RegisterCallback(Recipes.Event.TrackedUpdated, self.OnTrackedRecipeUpdated, self)

    GUI:RegisterCallback(GUI.Event.Refresh, self.OnRefresh, self)

    Buffs:RegisterCallback(Buffs.Event.TraitChanged, Self.OnTraitChanged, Self)
end
