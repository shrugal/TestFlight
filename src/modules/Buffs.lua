---@class Addon
local Addon = select(2, ...)
local C, Cache, GUI, Optimization, Prices, Reagents, Recipes, Util = Addon.Constants, Addon.Cache, Addon.GUI, Addon.Optimization, Addon.Prices, Addon.Reagents, Addon.Recipes, Addon.Util

---@class Buffs: CallbackRegistryMixin
---@field Event Buffs.Event
local Self = Mixin(Addon.Buffs, CallbackRegistryMixin)

---@enum Buffs.ToolAction
Self.ToolAction = {
    Equip = 1,
    Unequip = 2,
    Swap = 3,
}

---@enum Buffs.AuraSlot
Self.AuraSlot = {
    Profession = "PROFESSION",
    Phial = "PHIAL"
}

---@enum Buffs.AuraAction
Self.AuraAction = {
    UseItem = "UseItem",
    BuyItem = "BuyItem",
    LearnRecipe = "LearnRecipe",
    BuyMats = "BuyMats",
    EquipTool = "EquipTool",
    CraftRecipe = "CraftRecipe",
}

---@type number[]
Self.auraCharges = {}

---@type Cache<string, fun(self: self, profession: Enum.Profession): string>
Self.currentTools = Cache:PerFrame()
---@type Cache<string, fun(self: self, skillLineID: number): string>
Self.currentAuras = Cache:PerFrame()

---------------------------------------
--            Extra skill
---------------------------------------

function Self:ApplyExtraSkill(operation)
    local op = operation.operationInfo

    op.baseSkill = op.baseSkill + operation.extraSkill

    if op.isQualityCraft then
        local recipeInfo = operation:GetRecipeInfo()
        local maxQuality = recipeInfo.maxQuality ---@cast maxQuality -?

        local skill = op.baseSkill + op.bonusSkill
        local difficulty = op.baseDifficulty + op.bonusDifficulty
        local p = skill / difficulty

        local quality = maxQuality
        local breakpoints = C.QUALITY_BREAKPOINTS[maxQuality]

        for i, v in ipairs(breakpoints) do
            if v > p then quality = i - 1 break end
        end

        -- Skill, quality
        local lower, upper = breakpoints[quality], breakpoints[quality + 1] or 1
        local qualityProgress = upper == lower and 0 or (p - lower) / (upper - lower)
        local qualityID = recipeInfo.qualityIDs[quality]
        local qualityChanged = op.craftingQuality ~= quality

        op.quality = quality + qualityProgress
        op.craftingQuality = quality
        op.craftingQualityID = qualityID
        op.lowerSkillThreshold = difficulty * lower
        op.upperSkillTreshold = difficulty * upper

        -- Concentration cost
        if (op.concentrationCost or 0) > 0 then
            if quality == #breakpoints then
                op.concentrationCost = 0
            else
                local weight = operation:GetWeight() + operation.extraSkill * operation:GetWeightPerSkill()
                local base = operation:WithExtraSkill()

                if qualityChanged then
                    local isLowerBound = qualityProgress < 0.5
                    local weightReagents = Reagents:GetCraftingInfoForWeight(operation.recipe, weight, isLowerBound)
                    base = base:WithWeightReagents(weightReagents)
                end

                if base:GetQuality() ~= op.craftingQuality then
                    op.concentrationCost = 0/0
                else
                    op.concentrationCost = base:GetConcentrationCost(weight)
                end

                if Util:NumIsNaN(op.concentrationCost) then
                    op.concentrationCost = -1
                end
            end
        end
    end
end

---------------------------------------
--              Tools
---------------------------------------

---@param profession Enum.Profession
function Self:GetToolSlotID(profession)
    local slots = C_TradeSkillUI.GetProfessionSlots(profession)
    return slots and slots[1]
end

---@param profession Enum.Profession
---@return string?
function Self:GetCurrentTool(profession)
    local cache = self.currentTools
    local key = cache:Key(profession)

    if not cache:Has(key) then
        local slot = self:GetToolSlotID(profession)
        if not slot then return end

        local location = ItemLocation:CreateFromEquipmentSlot(slot)
        if not location or not location:IsValid() then return end

        cache:Set(key, C_Item.GetItemGUID(location))
    end

    return cache:Get(key)
end

---@param profession Enum.Profession
function Self:GetAvailableTools(profession)
    ---@type string[]
    local items = {}

    local slot = self:GetToolSlotID(profession)
    if not slot then return items end

    GetInventoryItemsForSlot(slot, items)

    for loc in pairs(items) do
        local player, _, bags, _, slot, bag = EquipmentManager_UnpackLocation(loc)
        if player and bags then
            items[loc] = C_Item.GetItemGUID(ItemLocation:CreateFromBagAndSlot(bag, slot))
        else
            items[loc] = nil
        end
    end

    items[ITEM_INVENTORY_LOCATION_PLAYER + slot] = self:GetCurrentTool(profession)

    return items
end

---@param toolGUID string
---@return number? skill
---@return table<string, number>? stats
function Self:GetToolBonus(toolGUID)
    local info = C_TooltipInfo.GetItemByGUID(toolGUID)
    if not info then return end

    ---@type table<string, number>
    local stats = Util(C.STATS):Copy():SetAll(0)()
    local skill = 0

    for _,line in ipairs(info.lines) do repeat
        if not line.leftText or not Util:OneOf(line.type, Enum.TooltipDataLineType.None, Enum.TooltipDataLineType.ItemEnchantmentPermanent) then break end

        local n = tonumber(line.leftText:match("%+(%d+) "))
        if not n then break end

        if line.leftText:find(SKILL) then
            skill = skill + n
        else
            for s,stat in pairs(C.STATS) do
                if line.leftText:find(stat.NAME) then
                    stats[s] = stats[s] + n break
                end
            end
        end
    until true end

    return skill, stats
end

---@param operationInfo CraftingOperationInfo
---@param toolGUID? string
---@param mode? 1 | -1
function Self:ApplyTool(operationInfo, toolGUID, mode)
    if not toolGUID then return end

    local expansionID = select(15, C_Item.GetItemInfo(toolGUID))
    if not expansionID then return end

    local _, stats = self:GetToolBonus(toolGUID)
    if not stats then return end

    self:ApplyStats(operationInfo, expansionID, stats, mode)
end

---@param toolGUID string
---@param profession Enum.Profession
function Self:EquipTool(toolGUID, profession)
    local location = C_Item.GetItemLocation(toolGUID) ---@cast location ItemLocationMixin
    if not location:IsBagAndSlot() then return false end

    local bag, slot = location:GetBagAndSlot()
    local type = self:GetCurrentTool(profession) and self.ToolAction.Swap or self.ToolAction.Equip
    local invSlot = self:GetToolSlotID(profession)

    local action = { type = type, invSlot = invSlot, bags = true, bag = bag, slot = slot }

    return EquipmentManager_RunAction(action)
end

---------------------------------------
--              Auras
---------------------------------------

---@param aura number | Buffs.AuraSlot
---@param level? number
function Self:SetAuraLevel(aura, level)
    local slot, auraID = aura, nil
    if type(aura) == "number" then
        slot, auraID = C.AURAS[aura].SLOT, aura
    end ---@cast slot Buffs.AuraSlot

    if level == nil and auraID then level = 1 end
    if level == 0 then level = nil end

    local changed = false

    for id in self:EnumerateAuras(nil, slot) do
        local level = id == auraID and level or nil

        changed = changed or Addon.DB.Account.auras[id] ~= level

        Addon.DB.Account.auras[id] = level
    end

    if not changed then return end

    self:TriggerEvent(self.Event.AuraUpdated, aura, level)
    self:TriggerEvent(self.Event.BuffChanged, self.Event.AuraUpdated, slot, auraID, level)
end

---@param aura number | Buffs.AuraSlot
---@param auras? string
function Self:GetAuraLevel(aura, auras)
    if type(aura) == "string" then
        for id in self:EnumerateAuras(nil, aura) do
            local level = self:GetAuraLevel(id, auras)
            if level > 0 then return level end
        end
        return 0
    elseif auras then
        return tonumber(auras:match(("%d:(%%d+)"):format(aura))) or 0
    else
        return Addon.DB.Account.auras[aura] or 0
    end
end

---@param recipe CraftingRecipeSchematic
---@return string
function Self:GetEnabledAuras(recipe)
    return self:BuildAuras(recipe, self.GetAuraLevel, self)
end

---@param recipe? CraftingRecipeSchematic
---@return string
function Self:GetCurrentAuras(recipe)
    local cache = self.currentAuras
    local key = cache:Key(self:GetSkillLineID(recipe))

    if not cache:Has(key) then
        local auras = self:BuildAuras(recipe, function (auraID)
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(auraID)
            if not aura then return end

            local info = C.AURAS[auraID]
            if info.STATS and aura.points then
                local _, num = Util:TblFindMax(aura.points)
                for quality,stats in ipairs(info.STATS) do
                    if select(2, next(stats)) == num then return quality end
                end
            end

            return aura.charges or 1
        end)

        cache:Set(key, auras)
    end

    return cache:Get(key)
end

---@param recipe CraftingRecipeSchematic
---@param slot Buffs.AuraSlot
function Self:GetCurrentAura(recipe, slot)
    local auras = self:GetCurrentAuras(recipe)
    return Util:TblFind(self:EnumerateAuras(auras, slot))
end

---@param recipe CraftingRecipeSchematic
function Self:GetCurrentAndEnabledAuras(recipe)
    return self:MergeAuras(self:GetCurrentAuras(recipe), self:GetEnabledAuras(recipe))
end

---@param auraID number
---@param level? number
---@return table<string, number>?
function Self:GetAuraStats(auraID, level)
    level = level or 1

    local info = C.AURAS[auraID]

    if info.STATS then
        return info.STATS[level]
    elseif info.SKILL then
        local configID = C_ProfSpecs.GetConfigIDForSkillLine(info.SKILL)
        local stats = {}

        for perkID,STATS in pairs(info.PERKS) do repeat
            if C_ProfSpecs.GetStateForPerk(perkID, configID) ~= Enum.ProfessionsSpecPerkState.Earned then break end
            for stat,val in pairs(STATS) do
                stat = stat:upper()
                stats[stat] = (stats[stat] or 0) + val * level
            end
        until true end

        return stats
    end
end

---@param operationInfo CraftingOperationInfo
---@param auras? string
---@param mode? 1 | -1
function Self:ApplyAuras(operationInfo, auras, mode)
    if not auras then return end

    for auraID, level, info in self:EnumerateAuras(auras) do
        local stats = self:GetAuraStats(auraID, level)
        if not stats then return end

        self:ApplyStats(operationInfo, info.EXPANSION, stats, mode)
    end
end

---@param auraID number
---@param quality? number
function Self:GetAuraItem(auraID, quality)
    local info = C.AURAS[auraID]
    if not info then return end

    if info.ITEM == true then
        local recipe = C_TradeSkillUI.GetRecipeSchematic(info.RECIPE, false)
        return Recipes:GetResult(recipe, nil, nil, quality)
    else
        return info.ITEM --[[@as number?]]
    end
end

---@param auraID number
---@param level? number
---@return Buffs.AuraAction? action
---@return CraftingRecipeSchematic? recipe
---@return (number|string)? item
function Self:GetAuraAction(auraID, level)
    local info = C.AURAS[auraID]
    if not info then return end

    local recipe = info.RECIPE and C_TradeSkillUI.GetRecipeSchematic(info.RECIPE, false)
    local item = self:GetAuraItem(auraID, level)

    local action
    if item and C_Item.GetItemCount(item) > 0 then
        action = self.AuraAction.UseItem
    elseif not recipe then
        action = self.AuraAction.BuyItem
    elseif not C_TradeSkillUI.GetRecipeInfo(recipe.recipeID).learned then
        action = item and Prices:HasItemPrice(item) and self.AuraAction.BuyItem or self.AuraAction.LearnRecipe
    elseif recipe.recipeType == Enum.TradeskillRecipeType.Salvage then
        ---@todo Make operations work with salvage recipes

        local itemIDs = C_TradeSkillUI.GetSalvagableItemIDs(recipe.recipeID)
        local items = C_TradeSkillUI.GetCraftingTargetItems(itemIDs)
        local minPrice, reagent = math.huge, nil

        for _,item in pairs(items) do repeat
            local price = Prices:GetItemPrice(item.hyperlink or item.itemID)
            if price == 0 or price >= minPrice then break end
            minPrice, reagent = price, item
        until true end

        if reagent and reagent.quantity >= recipe.quantityMax then
            action = self.AuraAction.CraftRecipe
        else
            action = self.AuraAction.BuyMats
        end
    else
        local operation = Optimization:GetRecipeAllocation(recipe, Optimization.Method.Cost)
        if not operation then return end

        if not operation:IsCraftable() then
            action = self.AuraAction.BuyMats
        elseif not operation:IsToolEquipped() then
            action = self.AuraAction.EquipTool
        else
            action = self.AuraAction.CraftRecipe
        end
    end

    return action, recipe, item
end

---@param action Buffs.AuraAction
function Self:GetAuraActionLabel(action)
    if action == self.AuraAction.UseItem then
        return "Use Buff"
    elseif action == self.AuraAction.BuyItem then
        return "Buy Buff"
    elseif action == self.AuraAction.LearnRecipe then
        return "Learn Buff"
    elseif action == self.AuraAction.BuyMats then
        return "Buy Mats"
    elseif action == self.AuraAction.EquipTool then
        return "Equip"
    elseif action == self.AuraAction.CraftRecipe then
        return "Cast Buff"
    end
end

---@param action Buffs.AuraAction
---@param recipe? CraftingRecipeSchematic
---@param item? string | number
function Self:GetAuraActionTooltip(action, recipe, item)
    if action == self.AuraAction.UseItem then ---@cast item - ?
        return ("Use buff item: %s"):format(Recipes:GetResultName(item))
    elseif action == self.AuraAction.BuyItem then ---@cast item - ?
        return ("Buy buff item: %s"):format(Recipes:GetResultName(item))
    elseif action == self.AuraAction.LearnRecipe then ---@cast recipe -?
        return ("Learn buff recipe: %s"):format(recipe.name)
    elseif action == self.AuraAction.BuyMats then ---@cast recipe -?
        return ("Buy mats for buff recipe: %s"):format(recipe.name)
    elseif action == self.AuraAction.EquipTool then ---@cast recipe -?
        return ("Equip tool for buff recipe: %s"):format(recipe.name)
    elseif action == self.AuraAction.CraftRecipe then ---@cast recipe -?
        return ("Cast buff recipe: %s"):format(recipe.name)
    end
end

---@param auraID number
---@param level number?
function Self:GetAuraName(auraID, level)
    local info = C.AURAS[auraID]

    local name = C_TradeSkillUI.GetRecipeSchematic(info.RECIPE, false).name
    if not level then return name end

    return ("%s %s"):format(name, info.ITEM and C_Texture.GetCraftingReagentQualityChatIcon(level) or level)
end

---@param auraID number
---@param level? number
function Self:CastAura(auraID, level)
    level = level or 1

    local action, recipe, item = self:GetAuraAction(auraID, level)
    if not action or Util:OneOf(action, self.AuraAction.BuyItem, self.AuraAction.LearnRecipe, self.AuraAction.BuyMats) then return end

    if action == self.AuraAction.UseItem then ---@cast item -?
        -- This is actually handled by a secure action button
        C_Item.UseItemByName(item)
    elseif not recipe then
        return
    elseif recipe.recipeType == Enum.TradeskillRecipeType.Salvage then
        ---@todo Make operations work with salvage recipes

        local itemIDs = C_TradeSkillUI.GetSalvagableItemIDs(recipe.recipeID)
        local items = C_TradeSkillUI.GetCraftingTargetItems(itemIDs)
        local minPrice, reagent = math.huge, nil

        for _,item in pairs(items) do repeat
            local price = Prices:GetItemPrice(item.hyperlink or item.itemID)
            if price == 0 or price >= minPrice then break end
            minPrice, reagent = price, item
        until true end

        local location = C_Item.GetItemLocation(reagent.itemGUID)
        if not location then return end

        C_TradeSkillUI.CraftSalvage(recipe.recipeID, 1, location)
    else
        local operation = Optimization:GetRecipeAllocation(recipe, Optimization.Method.Cost)
        if not operation then return end

        if action == self.AuraAction.EquipTool then
            operation:EquipTool()
        elseif action == self.AuraAction.CraftRecipe then
            operation:Craft()
        end
    end
end

---@param menuDescription BaseMenuDescriptionMixin | SharedMenuDescriptionProxy
function Self:AddAuraFilters(menuDescription)
    if self:GetSkillLineID() == 0 then return end

    local IsAuraSelected = function (data)
        local aura, level = unpack(data)
        local curr = self:GetAuraLevel(aura)
        if level then return curr == level else return curr > 0 end
    end

    local SetAuraSelected = function (data)
        local aura, level = unpack(data)
        local curr = IsAuraSelected(data)
        self:SetAuraLevel(aura, not curr and level or 0)
    end

    for _,slot in pairs(self.AuraSlot) do
        local enumerate = self:EnumerateAuraLevels(slot)
        local n = Util:TblCount(enumerate)

        if n == 1 then
            ---@type number, number, BuffAuraInfo
            local auraID, level, info = enumerate() --[[@as any]]
            local name = C_TradeSkillUI.GetRecipeSchematic(info.RECIPE, false).name
            menuDescription:CreateCheckbox(name, IsAuraSelected, SetAuraSelected, { auraID, level })
        elseif n > 0 then
            local name = Util:StrUcFirst(slot:lower())
            local slotSubmenu = menuDescription:CreateCheckbox(name, IsAuraSelected, SetAuraSelected, { slot })

            for auraID, level in enumerate do
                slotSubmenu:CreateRadio(self:GetAuraName(auraID, level), IsAuraSelected, SetAuraSelected, { auraID, level })
            end
        end
    end
end

---@param auraID number
---@param level? number
function Self:GetAuraContinuable(auraID, level)
    local info = C.AURAS[auraID]
    local learned = Addon.enabled or not info.RECIPE or C_TradeSkillUI.GetRecipeInfo(info.RECIPE).learned

    local continuable

    if info.ITEM then
        local itemInfo = self:GetAuraItem(auraID, level) ---@cast itemInfo -?
        if not itemInfo then return end

        if type(itemInfo) == "string" then
            continuable = Item:CreateFromItemLink(itemInfo)
        else
            continuable = Item:CreateFromItemID(itemInfo)
        end

        continuable.enabled = learned or Prices:HasItemPrice(itemInfo)
    else
        continuable = Spell:CreateFromSpellID(info.RECIPE)

        continuable.enabled = learned
    end

    continuable.auraID = auraID
    continuable.level = level

    return continuable
end

---@param slot Buffs.AuraSlot
---@param filterAvailable? boolean
function Self:GetAuraContinuables(slot, filterAvailable)
    local items = {}
    for auraID, _, info in self:EnumerateAuras(nil, slot) do
        if info.ITEM then
            for quality=1,5 do repeat
                local itemInfo = self:GetAuraItem(auraID, quality) ---@cast itemInfo -?
                if not itemInfo then break end

                if filterAvailable and C_Item.GetItemCount(itemInfo) == 0 then break end

                tinsert(items, self:GetAuraContinuable(auraID, quality))
            until true end
        else
            tinsert(items, self:GetAuraContinuable(auraID))
        end
    end
    return items
end

---@param parent Frame
function Self:CreateAuraSecureButton(parent)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate, SecureActionButtonTemplate") --[[@as Button]]
    btn:SetAttribute("type", "item")
    btn:SetAllPoints()
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:Hide()

    local action = self.AuraAction.UseItem

    btn:SetText(self:GetAuraActionLabel(action))
    btn:SetScript("OnLeave", GameTooltip_Hide)
    btn:SetScript("OnEnter", function (frame) ---@cast frame Button
        GUI:ShowInfoTooltip(frame, self:GetAuraActionTooltip(action, nil, frame:GetAttribute("item")))
    end)

    return btn
end

---------------------------------------
--               Util
---------------------------------------

---@param recipeOrID? CraftingRecipeSchematic | number
function Self:GetSkillLineID(recipeOrID)
    if type(recipeOrID) == "number" then
        return recipeOrID
    elseif recipeOrID then
        return (C_TradeSkillUI.GetTradeSkillLineForRecipe(recipeOrID.recipeID))
    else
        return C_TradeSkillUI.GetProfessionChildSkillLineID()
    end
end

---@param operationInfo CraftingOperationInfo
---@param expansionID number
---@param stats table<string, number>
---@param mode? 1 | -1
function Self:ApplyStats(operationInfo, expansionID, stats, mode)
    if not mode then mode = 1 end

    for _,line in pairs(operationInfo.bonusStats) do repeat
        for s,stat in pairs(C.STATS) do
            if line.bonusStatName == stat.NAME then
                if not stats[s] then break end

                local diff = stats[s] * mode
                local diffPct = diff * stat.FACTORS[expansionID] * 100
                local ratingPct = max(0, line.ratingPct + diffPct)
                local ratingPctStr = string.format("%.1f%%%%", ratingPct)

                line.bonusStatValue = max(0, line.bonusStatValue + diff)
                line.bonusRatingPct = max(0, line.bonusRatingPct + diffPct)
                line.ratingPct = ratingPct
                line.ratingDescription = line.ratingDescription:gsub("[%d.,]+%%", ratingPctStr, 1)

                break
            end
        end
    until true end
end

---@param source? true |string | number | CraftingRecipeSchematic
---@param fn SearchFn<number, number?, any>
---@param s? table
function Self:BuildAuras(source, fn, s, ...)
    local auras = ""
    for auraID in self:EnumerateAuras(source) do
        local level = Util:FnCall(fn, auraID, nil, s, ...)
        if (level or 0) > 0 then auras = auras .. (";%d:%d"):format(auraID, level) end
    end
    return auras:sub(2)
end

---@param ... string
function Self:MergeAuras(...)
    local auras, n = "", select("#", ...)

    for _,slot in pairs(self.AuraSlot) do
        local auraID, level
        for i=1,n do
            local iAuraID, iLevel = Util:TblFind(self:EnumerateAuras(select(i, ...), slot))

            if iAuraID ~= auraID then
                auraID, level = iAuraID or auraID, iLevel or level
            elseif iAuraID and iLevel and auraID and level then
                auraID, level = iAuraID, max(iLevel, level)
            end
        end

        if auraID then auras = auras .. (";%d:%d"):format(auraID, level) end
    end

    return auras:sub(2)
end

---@param aura number | Buffs.AuraSlot
---@param level number?
---@param auras? string
function Self:HasAura(aura, level, auras)
    return self:GetAuraLevel(aura, auras) >= (level or 1)
end

---@param check? string | number | CraftingRecipeSchematic Auras or skillLineID or recipe
---@param auras? string
function Self:GetMissingAura(check, auras)
    if (check or "") == "" then return end
    if not auras then auras = self:GetCurrentAuras() end

    for auraID, level, info in self:EnumerateAuras(check) do
        if not self:HasAura(auraID, level, auras) then return auraID, level, info end
    end
end

---@param auras string
---@param aura number | Buffs.AuraSlot
function Self:SubAura(auras, aura)
    if type(aura) == "number" then
        auras = auras:gsub((";?%d:%%d+"):format(aura), "", 1):gsub("^;", "", 1)
    else
        for auraID in self:EnumerateAuras(true, aura) do
            auras = self:SubAura(auras, auraID)
        end
    end
    return auras
end

---@param auras string
---@param auraID number
---@param level? number
---@return string
function Self:SetAura(auras, auraID, level)
    local pattern = ("%d:%%d+"):format(auraID)
    local value = ("%d:%d"):format(auraID, level or 1)
    local match = auras:match(pattern)

    if level == 0 then
        return self:SubAura(auras, match and auraID or C.AURAS[auraID].SLOT)
    elseif match then
        return (auras:gsub(pattern, value, 1))
    else
        return self:MergeAuras(auras, value)
    end
end

---@param auras string
---@param auraID number
---@param level? number
function Self:AddAura(auras, auraID, level)
    local curr = self:GetAuraLevel(auraID, auras)
    if curr >= (level or 1) then return auras end
    return self:SetAura(auras, auraID, level)
end

---@param source? true | string | number | CraftingRecipeSchematic All or auras or skillLineID or recipe
---@param slot? Buffs.AuraSlot
---@return fun(): number?, number?, BuffAuraInfo?
function Self:EnumerateAuras(source, slot)
    local auraID, skillLineID, info

    if type(source) == "string" then
        local fn, level = source:gmatch("(%d+):(%d+)"), nil

        return function()
            repeat while true do
                local a, b = fn()
                if not a then return end
                auraID, level = tonumber(a), tonumber(b)
                info = C.AURAS[auraID]
                if slot and slot ~= info.SLOT then break end
                if skillLineID and info.SKILL and info.SKILL ~= skillLineID then break end
                return auraID, level, info
            end until false
        end
    else
        if source ~= true then skillLineID = self:GetSkillLineID(source) end

        local s
        if not slot then s, slot = next(self.AuraSlot) end

        return function()
            repeat while true do
                auraID, info = next(C.AURAS, auraID)
                if not auraID then
                    if s then s, slot = next(self.AuraSlot, s) break else return end
                end
                if slot ~= info.SLOT then break end
                if skillLineID and info.SKILL and info.SKILL ~= skillLineID then break end
                return auraID, 1, info
            end until false
        end
    end
end

---@param aura? number | Buffs.AuraSlot
---@return fun(): number?, number?, BuffAuraInfo?
function Self:EnumerateAuraLevels(aura)
    local source = type(aura) == "number" and ("%d:1"):format(aura) or nil
    local slot = type(aura) == "string" and aura or nil
    local fn = self:EnumerateAuras(source, slot)

    local auraID, level, info
    return function ()
        repeat while true do
            if not auraID then auraID, level, info = fn() else level = level + 1 end
            if not auraID or not info then return end
            if level > (info.STATS and #info.STATS or 1) then auraID = nil break end
            return auraID, level, info
        end until false
    end
end

---------------------------------------
--              Events
---------------------------------------

---@class Buffs.Event
---@field AuraChanged "AuraChanged"
---@field TraitChanged "TraitChanged"
---@field EquipmentChanged "EquipmentChanged"
---@field BuffChanged "BuffChanged"
---@field AuraUpdated "AuraUpdated"

Self:GenerateCallbackEvents({ "AuraChanged", "TraitChanged", "EquipmentChanged", "BuffChanged", "AuraUpdated" })
Self:OnLoad()

---@param unit string
---@param info UnitAuraUpdateInfo
function Self:OnUnitAura(unit, info)
    if unit ~= "player" then return end

    local changed

    if info.addedAuras then
        for _,data in pairs(info.addedAuras) do
            if C.AURAS[data.spellId] then self.auraCharges[data.auraInstanceID], changed = data.charges or 1, true end
        end
    end

    if info.removedAuraInstanceIDs then
        for _,instanceID in pairs(info.removedAuraInstanceIDs) do
            if self.auraCharges[instanceID] then self.auraCharges[instanceID], changed = nil, true end
        end
    end

    if info.updatedAuraInstanceIDs then
        for _,instanceID in pairs(info.updatedAuraInstanceIDs) do repeat
            if not self.auraCharges[instanceID] then break end
            local data = C_UnitAuras.GetAuraDataByAuraInstanceID("player", instanceID) ---@cast data -?
            if self.auraCharges[instanceID] == (data.charges or 1) then break end
            self.auraCharges[instanceID], changed = data.charges or 1, true
        until true end
    end

    if not changed then return end

    self:TriggerEvent(self.Event.AuraChanged)
    self:TriggerEvent(self.Event.BuffChanged, self.Event.AuraChanged)
end

---@param configID number
function Self:OnTradeConfigUpdated(configID)
    local config = C_Traits.GetConfigInfo(configID)
    if not config or config.type ~= Enum.TraitConfigType.Profession then return end

    self:TriggerEvent(self.Event.TraitChanged, configID)
    self:TriggerEvent(self.Event.BuffChanged, self.Event.TraitChanged, configID)
end

---@param skillLineID number
---@param isTool boolean
function Self:OnProfessionEquipmentChanged(skillLineID, isTool)
    self:TriggerEvent(self.Event.EquipmentChanged, skillLineID, isTool)
    self:TriggerEvent(self.Event.BuffChanged, self.Event.EquipmentChanged, skillLineID, isTool)
end

function Self:OnLoaded()
    AuraUtil.ForEachAura("player", "HELPFUL", nil, function (data) ---@cast data AuraData
        if C.AURAS[data.spellId] then self.auraCharges[data.auraInstanceID] = data.charges or 1 end
    end, true)

    EventRegistry:RegisterFrameEventAndCallback("UNIT_AURA", self.OnUnitAura, self)
    EventRegistry:RegisterCallback("TRAIT_CONFIG_UPDATED", self.OnTradeConfigUpdated, self)
    EventRegistry:RegisterFrameEventAndCallback("PROFESSION_EQUIPMENT_CHANGED", self.OnProfessionEquipmentChanged, self)
end

Addon:RegisterCallback(Addon.Event.Loaded, Self.OnLoaded, Self)