---@type string
local Name = ...
---@class TestFlight
local Addon = select(2, ...)
local Reagents, Util = Addon.Reagents, Addon.Util


---@class Prices
local Self = Addon.Prices

-- Profession stat base multipliers
Self.STAT_BASE_RESOURCEFULNESS = 0.3
Self.STAT_BASE_MULTICRAFT = 2.5

-- Sell location cuts
Self.CUT_AUCTION_HOUSE = 0.05

---------------------------------------
--              Sources
---------------------------------------

---@class PriceSource
---@field IsAvailable fun(self: self): boolean
---@field GetItemPrice fun(self, item: string | number): number?

---@type table<string, PriceSource>
Self.SOURCES = {
    TradeSkillMaster = {
        IsAvailable = function () return TSM_API ~= nil end,
        GetItemPrice = function (_, item)
            local itemStr = type(item) == "number" and "i:" .. item or TSM_API.ToItemString(item --[[@as string]])
            return TSM_API.GetCustomPriceValue("first(VendorBuy, DBRecent, DBMinbuyout)", itemStr)
        end
    },
    Auctionator = {
        IsAvailable = function () return Auctionator ~= nil end,
        GetItemPrice = function (_, item)
            if type(item) == "number" then
                return Auctionator.API.v1.GetVendorPriceByItemID(Name, item) or Auctionator.API.v1.GetAuctionPriceByItemID(Name, item)
            else
                return Auctionator.API.v1.GetVendorPriceByItemLink(Name, item) or Auctionator.API.v1.GetAuctionPriceByItemLink(Name, item)
            end
        end
    },
    RECrystallize = {
        IsAvailable = function () return RECrystallize_PriceCheckItemID ~= nil end,
        GetItemPrice = function (_, item)
            if type(item) == "number" then
                return RECrystallize_PriceCheckItemID(item)
            else
                return RECrystallize_PriceCheck(item)
            end
        end
    },
    OribosExchange = {
        result = {},
        IsAvailable = function () return OEMarketInfo ~= nil end,
        GetItemPrice = function (self, item)
            local res = OEMarketInfo(item, self.result)
            return res and ((res.market or 0) > 0 and res.market or (res.region or 0) > 0 and res.region) or nil
        end
    },
    Auctioneer = {
        IsAvailable = function () return Auctioneer ~= nil end,
        GetItemPrice = function (_, item)
            local itemKey = C_AuctionHouse.MakeItemKey(C_Item.GetItemInfoInstant(item), C_Item.GetDetailedItemLevelInfo(item), 0, 0)
            local stats = Auctioneer:Statistics(itemKey)
            return stats["Stats:OverTime"] and stats["Stats:OverTime"]:Best() or nil
        end
    },
}

---@type PriceSource?
Self.SOURCE = nil

function Self:GetSource()
    if self.SOURCE then return self.SOURCE end

    -- Use preferred or fist installed source
    local pref = Addon.DB.Account.priceSource
    if pref and C_AddOns.IsAddOnLoaded(pref) then
        self.SOURCE = self.SOURCES[pref]
    else
        for name,source in pairs(self.SOURCES) do
            if C_AddOns.IsAddOnLoaded(name) then self.SOURCE = source break end
        end
    end

    return self.SOURCE
end

function Self:IsSourceInstalled()
    return self:GetSource() ~= nil
end

function Self:IsSourceAvailable()
    local source = self:GetSource()
    return source and source:IsAvailable() or false
end

---@param itemLinkOrID string | number
function Self:GetItemPrice(itemLinkOrID)
    if not self:IsSourceAvailable() then return 0 end
    return self:GetSource():GetItemPrice(itemLinkOrID) or 0
end

---------------------------------------
--              Crafts
---------------------------------------

---@param recipe CraftingRecipeSchematic
---@param operationInfo CraftingOperationInfo
---@param allocation RecipeAllocation | ItemMixin
---@param order? CraftingOrderInfo
---@param optionalReagents? CraftingReagentInfo[]
---@param qualityID? number
---@return number reagentPrice
---@return number resultPrice
---@return number? profit
---@return number? revenue
---@return number? resourcefulness
---@return number? multicraft
---@return number? rewards
---@return number? traderCut
function Self:GetRecipePrices(recipe, operationInfo, allocation, order, optionalReagents, qualityID)
    local reagentPrice = self:GetRecipeAllocationPrice(recipe, allocation, order, optionalReagents)
    local resultPrice = self:GetRecipeResultPrice(recipe, operationInfo, optionalReagents, qualityID or order and order.minQuality)

    if resultPrice == 0 and not order then
        return reagentPrice, resultPrice
    end

    return reagentPrice, resultPrice, self:GetRecipeProfit(recipe, operationInfo, allocation, reagentPrice, resultPrice, order, optionalReagents)
end

---@param recipe CraftingRecipeSchematic
---@param allocation? RecipeAllocation | ItemMixin
---@param order? CraftingOrderInfo
---@param optionalReagents? CraftingReagentInfo[]
---@return number
function Self:GetRecipeAllocationPrice(recipe, allocation, order, optionalReagents)
    if recipe.recipeType == Enum.TradeskillRecipeType.Salvage then ---@cast allocation ItemMixin
        return recipe.quantityMin * self:GetReagentPrice(allocation:GetItemID())
    end  ---@cast allocation RecipeAllocation

    local price = 0

    -- Add allocation reagents
    if allocation then
        for slotIndex,reagent in pairs(allocation) do
            for _,item in reagent:Enumerate() do
                local quantity = item.quantity

                local orderReagent = order and Util:TblWhere(order.reagents, "slotIndex", slotIndex, "reagent.itemID", item.reagent.itemID)
                if orderReagent then
                    quantity = quantity - orderReagent.reagent.quantity
                end

                price = price + quantity * self:GetReagentPrice(item)
            end
        end
    end

    for slotIndex,reagent in pairs(recipe.reagentSlotSchematics) do
        if reagent.required then
            -- Add missing required
            local missing = reagent.quantityRequired

            local reagentAllocation = allocation and allocation[reagent.slotIndex]
            if reagentAllocation then missing = missing - reagentAllocation:Accumulate() end

            if missing > 0 then
                price = price + missing * math.min(self:GetReagentPrices(reagent))
            end
        elseif optionalReagents and not (allocation and allocation[reagent.slotIndex]) then
            -- Add optional
            local optionalReagent = Util:TblWhere(optionalReagents, "dataSlotIndex", reagent.dataSlotIndex, "itemID", reagent.reagents[1])

            if optionalReagent then
                local quantity = optionalReagent.quantity

                local orderReagent = order and Util:TblWhere(order.reagents, "slotIndex", slotIndex, "reagent.itemID", optionalReagent.itemID)
                if orderReagent then
                    quantity = quantity - orderReagent.reagent.quantity
                end

                price = price + quantity * self:GetReagentPrice(optionalReagent)
            end
        end
    end

    return price
end

---@param recipe CraftingRecipeSchematic
---@param operationInfo CraftingOperationInfo
---@param optionalReagents? CraftingReagentInfo[]
---@param qualityID? number
---@return number
function Self:GetRecipeResultPrice(recipe, operationInfo, optionalReagents, qualityID)
    if not qualityID then qualityID = operationInfo.craftingQualityID end
    if recipe.isRecraft then return 0 end

    ---@type string | number | nil
    local itemLinkOrID

    if Addon.ENCHANTS[operationInfo.craftingDataID] then
        itemLinkOrID = Addon.ENCHANTS[operationInfo.craftingDataID][qualityID]
    else
        local data = C_TradeSkillUI.GetRecipeOutputItemData(recipe.recipeID, optionalReagents, nil, qualityID)
        local id, link = data.itemID, data.hyperlink

        if link and select(14, C_Item.GetItemInfo(link)) == Enum.ItemBind.OnAcquire then return 0 end

        itemLinkOrID = link or id
    end

    if not itemLinkOrID then return 0 end

    local price = self:GetItemPrice(itemLinkOrID)
    local quantity = (recipe.quantityMin + recipe.quantityMax) / 2 -- TODO

    return price * quantity
end

---@param recipe CraftingRecipeSchematic
---@param operationInfo CraftingOperationInfo
---@param allocation RecipeAllocation | ItemMixin
---@param reagentPrice number
---@param resultPrice number
---@param order? CraftingOrderInfo
---@param optionalReagents? CraftingReagentInfo[]
---@return number profit
---@return number revenue
---@return number resourcefulness
---@return number multicraft
---@return number rewards
---@return number traderCut
function Self:GetRecipeProfit(recipe, operationInfo, allocation, reagentPrice, resultPrice, order, optionalReagents)
    local revenue = order and order.tipAmount or resultPrice
    local resourcefulness = self:GetResourcefulnessValue(recipe, operationInfo, allocation, reagentPrice, order, optionalReagents)
    local multicraft = order and 0 or self:GetMulticraftValue(recipe, operationInfo, resultPrice)
    local traderCut = order and order.consortiumCut or self.CUT_AUCTION_HOUSE * resultPrice

    local rewards = 0
    if order and order.npcOrderRewards then
        for _,reward in pairs(order.npcOrderRewards) do
            rewards = rewards + reward.count * self:GetItemPrice(reward.itemLink)
        end
    end

    local profit = revenue + resourcefulness + multicraft + rewards - reagentPrice - traderCut

    return profit, revenue, resourcefulness, multicraft, rewards, traderCut
end

---------------------------------------
--              Stats
---------------------------------------

---@param recipe CraftingRecipeSchematic
---@param operationInfo CraftingOperationInfo
---@param allocation RecipeAllocation | ItemMixin
---@param optionalReagents? CraftingReagentInfo[]
---@param isApplyingConcentration? boolean
---@return number? noConProfit
---@return number? conProfit
---@return number? concentration
function Self:GetConcentrationValue(recipe, operationInfo, allocation, optionalReagents, isApplyingConcentration)
    local quality = operationInfo.craftingQualityID
    if isApplyingConcentration then quality = quality - 1 end

    local noConProfit = select(3, self:GetRecipePrices(recipe, operationInfo, allocation, nil, optionalReagents, quality))
    local conProfit = select(3, self:GetRecipePrices(recipe, operationInfo, allocation, nil, optionalReagents, quality + 1))

    return noConProfit, conProfit, operationInfo.concentrationCost
end

---@param recipe CraftingRecipeSchematic
---@param operationInfo CraftingOperationInfo
---@param allocations RecipeAllocation[]
---@param optionalReagents? CraftingReagentInfo[]
---@param order CraftingOrderInfo
---@return number? noConProfit
---@return number? conProfit
---@return number? concentration
function Self:GetConcentrationValueForOrder(recipe, operationInfo, allocations, optionalReagents, order)
    local noConAllocation, conAllocation = allocations[order.minQuality], allocations[order.minQuality - 1]

    if not conAllocation then return end

    local conInfos = Reagents:CreateCraftingInfosFromAllocation(recipe, conAllocation, optionalReagents)
    local conOp = C_TradeSkillUI.GetCraftingOperationInfoForOrder(recipe.recipeID, conInfos, order.orderID, false)

    if not conOp then return end

    local noConProfit = noConAllocation and select(3, self:GetRecipePrices(recipe, operationInfo, noConAllocation, order, optionalReagents))
    local conProfit = select(3, self:GetRecipePrices(recipe, operationInfo, conAllocation, order, optionalReagents))
    local concentration = conOp.concentrationCost

    return noConProfit, conProfit, concentration
end

---@param recipe CraftingRecipeSchematic
---@param operationInfo CraftingOperationInfo
---@param allocation RecipeAllocation | ItemMixin
---@param reagentPrice number
---@param order? CraftingOrderInfo
---@param optionalReagents? CraftingReagentInfo[]
---@return number
function Self:GetResourcefulnessValue(recipe, operationInfo, allocation, reagentPrice, order, optionalReagents)
    local stat = Util:TblWhere(operationInfo.bonusStats, "bonusStatName", ITEM_MOD_RESOURCEFULNESS_SHORT)
    if not stat then return 0 end

    local chance = stat.ratingPct / 100
    local yield = self.STAT_BASE_RESOURCEFULNESS + self:GetRecipePerkStats(recipe, "rf")

    if order and order.reagentState ~= Enum.CraftingOrderReagentsType.None then
        reagentPrice = self:GetRecipeAllocationPrice(recipe, allocation, nil, optionalReagents)
    end

    return reagentPrice * chance * yield
end

---@param recipe CraftingRecipeSchematic
---@param operationInfo CraftingOperationInfo
---@param resultPrice number
function Self:GetMulticraftValue(recipe, operationInfo, resultPrice)
    local stat = Util:TblWhere(operationInfo.bonusStats, "bonusStatName", ITEM_MOD_MULTICRAFT_SHORT)
    if not stat then return 0 end

    local itemPrice = resultPrice * 2 / (recipe.quantityMax + recipe.quantityMin)
    local chance = stat.ratingPct / 100
    local yield = (1 + self.STAT_BASE_MULTICRAFT * recipe.quantityMax * (1 + self:GetRecipePerkStats(recipe, "mc"))) / 2

    return (1 - self.CUT_AUCTION_HOUSE) * itemPrice * chance * yield
end

---@param recipe CraftingRecipeSchematic
---@param stat "mc" | "rf"
function Self:GetRecipePerkStats(recipe, stat)
    local val = 0

    local perks = Addon.PERKS.recipes[recipe.recipeID]
    if perks then
        local professionInfo = C_TradeSkillUI.GetProfessionInfoByRecipeID(recipe.recipeID)
        local configID = C_ProfSpecs.GetConfigIDForSkillLine(professionInfo.professionID)

        for _,perkID in pairs(perks) do
            local perk = Addon.PERKS.nodes[perkID]
            if perk[stat] and C_ProfSpecs.GetStateForPerk(perkID, configID) == Enum.ProfessionsSpecPerkState.Earned then
                val = val + perk[stat] / 100
            end
        end
    end

    return val
end

---------------------------------------
--             Reagents
---------------------------------------

---@param reagent number | CraftingReagent | CraftingReagentInfo | CraftingReagentSlotSchematic | ProfessionTransactionAllocation
function Self:GetReagentPrice(reagent)
    if not self:IsSourceAvailable() then return 0 end

    if type(reagent) == "table" then
        if reagent.reagents then reagent = reagent.reagents[1] end ---@cast reagent -CraftingReagentSlotSchematic
        if reagent.reagent then reagent = reagent.reagent end ---@cast reagent -ProfessionTransactionAllocation
        do reagent = reagent.itemID end
    end ---@cast reagent -CraftingReagent | CraftingReagentInfo | CraftingReagentSlotSchematic | ProfessionTransactionAllocation

    if not reagent then return 0 end

    return self:GetItemPrice(reagent)
end

---@param reagent CraftingReagentSlotSchematic
---@return number, number?, number?
function Self:GetReagentPrices(reagent)
    if #reagent.reagents == 1 then return self:GetReagentPrice(reagent) end

    local r1, r2, r3 = unpack(reagent.reagents)
    return self:GetReagentPrice(r1), self:GetReagentPrice(r2), self:GetReagentPrice(r3)
end
