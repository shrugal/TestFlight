---@class Addon
local Addon = select(2, ...)
local GUI, Recipes, Util = Addon.GUI, Addon.Recipes, Addon.Util
local NS = GUI.ObjectiveTracker

local Parent = NS.ProfessionsTrackerModule

---@class GUI.ObjectiveTracker.RecipeTracker: GUI.ObjectiveTracker.ProfessionsTrackerModule
---@field module ObjectiveTrackerModuleMixin
local Self = Mixin(NS.RecipeTracker, Parent)

---@param btn Button
---@param mouseButton string
function Self:LineOnClick(btn, mouseButton)
    local line = btn:GetParent() --[[@as QuestObjectiveAnimLine]]

    if mouseButton == "RightButton"
        or IsModifiedClick("RECIPEWATCHTOGGLE")
        or IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow()
    then
        local block = line:GetParent()
        return self.module:OnBlockHeaderClick(block, mouseButton)
    end

    return GUI.ObjectiveTracker.LineOnClick(self, btn, mouseButton)
end

---@param _ ObjectiveTrackerModuleMixin
---@param recipeID number
---@param isRecraft boolean
function Self:AddRecipe(_, recipeID, isRecraft)
    local recipe = C_TradeSkillUI.GetRecipeSchematic(recipeID, isRecraft)
    local amount = Recipes:GetTrackedAmount(recipe) or 1
    local quality = Recipes:GetTrackedQuality(recipe)

    local block = self.module:GetExistingBlock(NegateIf(recipeID, isRecraft))

    -- Set header
    local blockName = recipe.name
    if isRecraft then
        blockName = PROFESSIONS_CRAFTING_FORM_RECRAFTING_HEADER:format(blockName)
    end
    if amount ~= 1 then
        blockName = ("%d %s"):format(amount, blockName)
    end
    if quality then
        blockName = ("%s %s"):format(blockName, C_Texture.GetCraftingReagentQualityChatIcon(quality))
    end

    block:SetHeader(blockName);

    -- Set reagents
    local slots = {};
    for j, schematic in ipairs(recipe.reagentSlotSchematics) do
        if ProfessionsUtil.IsReagentSlotRequired(schematic) then
            if ProfessionsUtil.IsReagentSlotModifyingRequired(schematic) then
                table.insert(slots, 1, j);
            else
                table.insert(slots, j);
            end
        end
    end

    for _, j in ipairs(slots) do
        local schematic = recipe.reagentSlotSchematics[j]

        local reagent = schematic.reagents[1]
        local quantity = ProfessionsUtil.AccumulateReagentsInPossession(schematic.reagents)
        local quantityRequired = schematic.quantityRequired * Recipes:GetTrackedAmount(recipe)
        local metQuantity = quantity >= quantityRequired
        local name = nil

        if ProfessionsUtil.IsReagentSlotBasicRequired(schematic) then
            if reagent.itemID then
                name = Item:CreateFromItemID(reagent.itemID):GetItemName();
            elseif reagent.currencyID then
                local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(reagent.currencyID)
                if currencyInfo then name = currencyInfo.name end
            end
        elseif ProfessionsUtil.IsReagentSlotModifyingRequired(schematic) and schematic.slotInfo then
            name = schematic.slotInfo.slotText
        end

        if name then
            local count = PROFESSIONS_TRACKER_REAGENT_COUNT_FORMAT:format(quantity, quantityRequired)
            local text = PROFESSIONS_TRACKER_REAGENT_FORMAT:format(count, name)
            local dashStyle = metQuantity and OBJECTIVE_DASH_STYLE_HIDE or OBJECTIVE_DASH_STYLE_SHOW
            local colorStyle = OBJECTIVE_TRACKER_COLOR[metQuantity and "Complete" or "Normal"]

            local line = block:GetExistingLine(j)

            -- Dash style
            if line.dashStyle ~= dashStyle then
                line.Dash[metQuantity and "Hide" or "Show"](line.Dash)
                line.Dash:SetText(QUEST_DASH);
                line.dashStyle = dashStyle
            end

            -- Text
            local oldHeight = line:GetHeight()
            local newHeight = block:SetStringText(line.Text, text, false, colorStyle, block.isHighlighted)
            line:SetHeight(newHeight)
            block.height = block.height - oldHeight + newHeight

            -- Icon
            line.Icon:SetShown(metQuantity)

            -- Button
            self:SetReagentLineButton(line, name)
        end
    end
end

function Self:BeginLayout()
    if not Addon.enabled then return end
    Util:TblUnhook(ProfessionsUtil, "GetReagentQuantityInPossession")
    Util:TblUnhook(ItemUtil, "GetCraftingReagentCount")
end

function Self:EndLayout()
    if not Addon.enabled then return end
    Util:TblHook(ProfessionsUtil, "GetReagentQuantityInPossession", Util.FnInfinite)
    Util:TblHook(ItemUtil, "GetCraftingReagentCount", Util.FnInfinite)
end

---------------------------------------
--              Events
---------------------------------------

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if not Util:IsAddonLoadingOrLoaded("Blizzard_ObjectiveTracker", addonName) then return end

    self.module = ProfessionsRecipeTracker

    hooksecurefunc(self.module, "AddRecipe", Util:FnBind(self.AddRecipe, self))
    hooksecurefunc(self.module, "BeginLayout", Util:FnBind(self.BeginLayout, self))
    hooksecurefunc(self.module, "EndLayout", Util:FnBind(self.EndLayout, self))

    Parent.OnAddonLoaded(self)
end

Addon:RegisterCallback(Addon.Event.AddonLoaded, Self.OnAddonLoaded, Self)
