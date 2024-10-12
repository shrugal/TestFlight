---@class Addon
local Addon = select(2, ...)
local GUI, Orders, Reagents, Recipes, Util = Addon.GUI, Addon.Orders, Addon.Reagents, Addon.Recipes, Addon.Util

---@class GUI.RecipeForm.RecipeForm
---@field form RecipeForm
---@field experimentBox CheckButton
---@field GetTrackCheckbox fun(self: self): CheckButton
local Self = GUI.RecipeForm.RecipeForm

-- Experiment checkbox

---@param frame CheckButton
function Self:ExperimentBoxOnClick(frame)
    if frame:GetChecked() ~= Addon.enabled then Addon:Toggle() end
end

---@param frame CheckButton
function Self:ExperimentBoxOnEnter(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip_AddNormalLine(GameTooltip, "Experiment with crafting recipes without reagent and spec limits.")
    GameTooltip:Show()
end

---@param parent Frame
function Self:InsertExperimentBox(parent, ...)
    local input = GUI:InsertCheckbox(parent, Util:FnBind(self.ExperimentBoxOnEnter, self), Util:FnBind(self.ExperimentBoxOnClick, self), ...)

    input.text:SetText(LIGHTGRAY_FONT_COLOR:WrapTextInColorCode("Experiment"))
    input:SetChecked(Addon.enabled)

    self.experimentBox = input

    return input
end

---------------------------------------
--               Util
---------------------------------------

function Self:GetRecipe()
    if not self.form.transaction then return end
    return self.form.transaction:GetRecipeSchematic()
end

---@return CraftingOrderInfo?
function Self:GetOrder() end

---@return number?
function Self:GetQuality() end

function Self:GetAllocation()
    return self.form.transaction.allocationTbls
end

-- Set allocation

---@param slotIndex number
---@param allocations ProfessionTransationAllocations
function Self:SetReagentSlotAllocation(slotIndex, allocations, silent)
    ---@type ReagentSlot
    local slot
    for s in self.form.reagentSlotPool:EnumerateActive() do if s:GetSlotIndex() == slotIndex then slot = s break end end

    if not slot or slot:IsUnallocatable() then return end

    if not Addon.enabled then
        for _,reagent in allocations:Enumerate() do
            if reagent.quantity > Reagents:GetQuantity(reagent) then Addon:Enable() break end
        end
    end

    self.form.transaction:OverwriteAllocations(slotIndex, allocations)
    self.form.transaction:SetManuallyAllocated(true)

    if silent then return end

    slot:Update()

    self.form:TriggerEvent(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified)
end

---@param allocation RecipeAllocation
function Self:SetReagentAllocation(allocation)
    for slotIndex,allocations in pairs(allocation) do
        self:SetReagentSlotAllocation(slotIndex, allocations, true)
    end

    for slot in self.form.reagentSlotPool:EnumerateActive() do slot:Update() end

    self.form:TriggerEvent(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified)
end

-- Clear slots

function Self:ClearExperimentalReagentSlots()
    if not self.form.reagentSlots then return end

    for _,slots in pairs(self.form.reagentSlots) do
        for _, slot in pairs(slots) do
            if not slot:IsUnallocatable() then
                local slotIndex = slot:GetReagentSlotSchematic().slotIndex

                for _,allocation in self.form.transaction:EnumerateAllocations(slotIndex) do
                    local q = Reagents:GetQuantity(allocation.reagent)
                    if allocation.quantity > q then
                        self:ResetReagentSlot(slot)
                        break
                    end
                end
            end
        end
    end
end

---@param slot ReagentSlot
function Self:ResetReagentSlot(slot)
    if slot:GetOriginalItem() then
        self:RestoreOriginalSlotItem(slot)
    elseif self.form.transaction:HasAnyAllocations(slot:GetReagentSlotSchematic().slotIndex) then
        self:ClearReagentSlot(slot)
    end
end

---@param slot ReagentSlot
function Self:ClearReagentSlot(slot)
    self.form.transaction:ClearAllocations(slot:GetReagentSlotSchematic().slotIndex)
    slot:ClearItem()
    self.form:TriggerEvent(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified)
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

function Self:OnEnabled() end

function Self:OnDisabled()
    if not self.form then return end
    self:ClearExperimentalReagentSlots()
end

function Self:OnRefresh()
    if not self.form then return end
    self.experimentBox:SetChecked(Addon.enabled)
end

function Self:OnAllocationModified()
    Recipes:SetTrackedByForm(self)
end

---@param recipeID number
---@param tracked boolean
function Self:OnTrackedRecipeUpdated(recipeID, tracked)
    if not tracked or not self.form:IsShown() then return end

    local recipe = self:GetRecipe()
    if not recipe or recipe.recipeID ~= recipeID then return end

    Recipes:SetTrackedByForm(self)

    local order = self:GetOrder()
    if not order then return end

    Orders:SetTracked(order)
end

function Self:OnAddonLoaded()
    Recipes:RegisterCallback(Recipes.Event.TrackedUpdated, self.OnTrackedRecipeUpdated, self)

    Addon:RegisterCallback(Addon.Event.Enabled, self.OnEnabled, self)
    Addon:RegisterCallback(Addon.Event.Disabled, self.OnDisabled, self)
    GUI:RegisterCallback(GUI.Event.Refresh, self.OnRefresh, self)
end