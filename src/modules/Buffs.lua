---@class Addon
local Addon = select(2, ...)
local C, Reagents, Util = Addon.Constants, Addon.Reagents, Addon.Util

---@class Buffs: CallbackRegistryMixin
---@field Event Buffs.Event
local Self = Mixin(Addon.Buffs, CallbackRegistryMixin)

---@type number[]
Self.auraCharges = {}

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
function Self:GetCurrentTool(profession)
    local slot = self:GetToolSlotID(profession)
    if not slot then return end

    local location = ItemLocation:CreateFromEquipmentSlot(slot)
    if not location then return end

    return C_Item.GetItemGUID(location)
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

---------------------------------------
--              Auras
---------------------------------------

---@param profession Enum.Profession
---@param aura number
function Self:GetCurentAura(profession, aura)

end

function Self:ApplyAura(opeation)

end

---------------------------------------
--               Util
---------------------------------------

---@param operationInfo CraftingOperationInfo
---@param expansionID number
---@param stats table<string, number>
---@param mode? 1 | -1
function Self:ApplyStats(operationInfo, expansionID, stats, mode)
    if not mode then mode = 1 end

    for _,line in pairs(operationInfo.bonusStats) do repeat
        for s,stat in pairs(C.STATS) do
            if line.bonusStatName == stat.NAME then
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

---------------------------------------
--              Events
---------------------------------------

---@class Buffs.Event
---@field AuraChanged "AuraChanged"
---@field TraitChanged "TraitChanged"
---@field EquipmentChanged "EquipmentChanged"
---@field BuffChanged "BuffChanged"

Self:GenerateCallbackEvents({ "AuraChanged", "TraitChanged", "EquipmentChanged", "BuffChanged" })
Self:OnLoad()

---@param unit string
---@param info UnitAuraUpdateInfo
function Self:OnUnitAura(unit, info)
    if unit ~= "player" then return end

    local auraCharges

    if info.addedAuras then
        for _,data in pairs(info.addedAuras) do
            if C.BUFFS[data.spellId] then self.auraCharges[data.auraInstanceID], auraCharges = data.charges, true end
        end
    end

    if info.removedAuraInstanceIDs then
        for _,instanceID in pairs(info.removedAuraInstanceIDs) do
            if self.auraCharges[instanceID] then self.auraCharges[instanceID], auraCharges = nil, true end
        end
    end

    if info.updatedAuraInstanceIDs then
        for _,instanceID in pairs(info.updatedAuraInstanceIDs) do repeat
            if not self.auraCharges[instanceID] then break end
            local data = C_UnitAuras.GetAuraDataByAuraInstanceID("player", instanceID) ---@cast data -?
            if self.auraCharges[instanceID] == data.charges then break end
            self.auraCharges[instanceID], auraCharges = data.charges, true
        until true end
    end

    if not auraCharges then return end

    self:TriggerEvent(self.Event.AuraChanged)
    self:TriggerEvent(self.Event.BuffChanged)
end

---@param configID number
function Self:OnTradeConfigUpdated(configID)
    local config = C_Traits.GetConfigInfo(configID)
    if not config or config.type ~= Enum.TraitConfigType.Profession then return end

    self:TriggerEvent(self.Event.TraitChanged, configID)
    self:TriggerEvent(self.Event.BuffChanged)
end

---@param skillLineID number
---@param isTool boolean
function Self:OnProfessionEquipmentChanged(skillLineID, isTool)
    self:TriggerEvent(self.Event.EquipmentChanged, skillLineID, isTool)
    self:TriggerEvent(self.Event.BuffChanged)
end

function Self:OnLoaded()
    AuraUtil.ForEachAura("player", "HELPFUL", nil, function (data) ---@cast data AuraData
        if C.BUFFS[data.spellId] then self.auraCharges[data.auraInstanceID] = data.charges end
    end, true)

    EventRegistry:RegisterFrameEventAndCallback("UNIT_AURA", self.OnUnitAura, self)
    EventRegistry:RegisterCallback("TRAIT_CONFIG_UPDATED", self.OnTradeConfigUpdated, self)
    EventRegistry:RegisterFrameEventAndCallback("PROFESSION_EQUIPMENT_CHANGED", self.OnProfessionEquipmentChanged, self)
end

Addon:RegisterCallback(Addon.Event.Loaded, Self.OnLoaded, Self)