---@type string
local Name = ...
---@class Addon
local Addon = select(2, ...)
local Orders, Recipes, Reagents = Addon.Orders, Addon.Recipes, Addon.Reagents


---@class Prices
local Self = Addon.Prices

-- Sell location cuts
Self.CUT_AUCTION_HOUSE = 0.05

---------------------------------------
--              Source
---------------------------------------

---@type table<string, PriceSource>
Self.SOURCES = {}
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

---@param item string | number
function Self:GetItemPrice(item)
    if not self:IsSourceAvailable() then return 0 end
    return self:GetSource():GetItemPrice(item) or 0
end

function Self:GetFullScanTime()
    if not self:IsSourceAvailable() then return end
    local source = self:GetSource()
    return source.GetFullScanTime and source:GetFullScanTime() or 0
end

---@param item string | number
function Self:GetItemScanTime(item)
    if not self:IsSourceAvailable() then return end
    local source = self:GetSource()
    return source.GetItemScanTime and source:GetItemScanTime(item) or self:GetFullScanTime()
end

---@param recipe CraftingRecipeSchematic
---@param result? string | number
---@param order? CraftingOrderInfo
---@param recraftMods? CraftingItemSlotModification
function Self:GetRecipeScanTime(recipe, result, order, recraftMods)
    if not self:IsSourceAvailable() then return end
    if not self:GetSource().GetItemScanTime then return self:GetFullScanTime() end

    local time = result and self:GetItemScanTime(result) or 0

    for _,reagent in pairs(recipe.reagentSlotSchematics) do
        if not Reagents:IsProvided(reagent, order, recraftMods) then
            for _,item in pairs(reagent.reagents) do
                time = max(time, self:GetItemScanTime(item.itemID) or 0)
            end
        end
    end

    return time
end

---------------------------------------
--              Crafts
---------------------------------------

---@param recipe CraftingRecipeSchematic
---@param operationInfo CraftingOperationInfo
---@param allocation RecipeAllocation | ItemMixin
---@param order? CraftingOrderInfo
---@param recraftMods? CraftingItemSlotModification[]
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
function Self:GetRecipePrices(recipe, operationInfo, allocation, order, recraftMods, optionalReagents, qualityID)
    local reagentPrice = self:GetRecipeAllocationPrice(recipe, allocation, order, recraftMods)
    local resultPrice = self:GetRecipeResultPrice(recipe, operationInfo, optionalReagents, qualityID or order and order.minQuality)

    if resultPrice == 0 and not order then
        return reagentPrice, resultPrice
    end

    return reagentPrice, resultPrice, self:GetRecipeProfit(recipe, operationInfo, allocation, reagentPrice, resultPrice, order, optionalReagents)
end

---@param recipe CraftingRecipeSchematic
---@param allocation? RecipeAllocation | ItemMixin
---@param order? CraftingOrderInfo
---@param recraftMods? CraftingItemSlotModification[]
---@return number
function Self:GetRecipeAllocationPrice(recipe, allocation, order, recraftMods)
    if recipe.recipeType == Enum.TradeskillRecipeType.Salvage then ---@cast allocation ItemMixin
        return recipe.quantityMin * self:GetReagentPrice(allocation:GetItemID())
    end  ---@cast allocation RecipeAllocation

    local price = 0

    for slotIndex,reagent in pairs(recipe.reagentSlotSchematics) do repeat
        local missing = reagent.required and reagent.quantityRequired or 0

        -- Reagents provided by crafter
        if Orders:IsCreatingProvided(order, slotIndex) then break end

        local allocations = allocation and allocation[reagent.slotIndex]
        if allocations then
            missing = max(0, missing - allocations:Accumulate())

            local provided = Reagents:GetProvided(reagent, order, recraftMods)

            for _,alloc in allocations:Enumerate() do
                local quantity = alloc.quantity

                for _,reagent in pairs(provided) do
                    if reagent.itemID == alloc.reagent.itemID then
                        quantity = max(0, quantity - (reagent.quantity or 1))
                    end
                end

                price = price + quantity * self:GetReagentPrice(alloc)
            end
        elseif missing > 0 and order and not Orders:IsCreating(order) then
            for _,reagent in pairs(order.reagents) do
                if reagent.slotIndex == slotIndex then
                    missing = max(0, missing - reagent.reagent.quantity)
                end
            end
        end

        if missing > 0 then
            price = price + missing * math.min(self:GetReagentPrices(reagent))
        end
    until true end

    return price
end

---@param recipe CraftingRecipeSchematic
---@param operationInfo CraftingOperationInfo
---@param optionalReagents? CraftingReagentInfo[]
---@param qualityID? number
---@return number
function Self:GetRecipeResultPrice(recipe, operationInfo, optionalReagents, qualityID)
    if recipe.isRecraft then return 0 end

    local item = Recipes:GetResult(recipe, operationInfo, optionalReagents, qualityID)
    if not item then return 0 end

    local price = self:GetItemPrice(item)
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
    local multicraft = order and 0 or self:GetMulticraftValue(recipe, operationInfo, resultPrice, optionalReagents)
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
---@param reagentPrice number
---@param order? CraftingOrderInfo
---@param optionalReagents? CraftingReagentInfo[]
---@return number value
function Self:GetResourcefulnessValue(recipe, operationInfo, allocation, reagentPrice, order, optionalReagents)
    local factor = Recipes:GetResourcefulnessFactor(recipe, operationInfo, optionalReagents)
    if factor == 0 then return 0 end

    if order and order.reagentState ~= Enum.CraftingOrderReagentsType.None then
        -- Not passing order here on purpose
        reagentPrice = self:GetRecipeAllocationPrice(recipe, allocation)
    end

    return reagentPrice * factor
end

---@param recipe CraftingRecipeSchematic
---@param operationInfo CraftingOperationInfo
---@param resultPrice number
---@param optionalReagents? CraftingReagentInfo[]
function Self:GetMulticraftValue(recipe, operationInfo, resultPrice, optionalReagents)
    local factor = Recipes:GetMulticraftFactor(recipe, operationInfo, optionalReagents)
    if factor == 0 then return 0 end

    local itemPrice = resultPrice * 2 / (recipe.quantityMax + recipe.quantityMin)

    return (1 - self.CUT_AUCTION_HOUSE) * itemPrice * factor
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

---@param reagent number | CraftingReagent | CraftingReagentInfo | CraftingReagentSlotSchematic | ProfessionTransactionAllocation
function Self:HasReagentPrice(reagent)
    return self:GetReagentPrice(reagent) > 0
end

---@param reagent CraftingReagentSlotSchematic
---@return number, number?, number?
function Self:GetReagentPrices(reagent)
    if #reagent.reagents == 1 then return self:GetReagentPrice(reagent) end

    local r1, r2, r3 = unpack(reagent.reagents)
    return self:GetReagentPrice(r1), self:GetReagentPrice(r2), self:GetReagentPrice(r3)
end

---@param reagents CraftingReagentInfo[]
---@return number
function Self:GetReagentsPrice(reagents)
    local price = 0

    for _,reagent in pairs(reagents) do
        price = price + self:GetReagentPrice(reagent) * reagent.quantity
    end

    return price
end

---------------------------------------
--              Sources
---------------------------------------

---@class PriceSource
---@field IsAvailable fun(self: self): boolean
---@field GetItemPrice fun(self: self, item: string | number): number?
---@field GetFullScanTime? fun(self: self): number?
---@field GetItemScanTime? fun(self: self, item: string | number): number?

-- TradeSkillMaster

---@class TradeSkillMasterPriceSource
Self.SOURCES.TradeSkillMaster = {}

function Self.SOURCES.TradeSkillMaster:IsAvailable()
    return TSM_API ~= nil
end
function Self.SOURCES.TradeSkillMaster:GetItemPrice(item)
    local itemStr = type(item) == "number" and "i:" .. item or TSM_API.ToItemString(item --[[@as string]])
    return TSM_API.GetCustomPriceValue("first(VendorBuy, DBRecent, DBMinbuyout)", itemStr)
end

-- Auctionator

---@class AuctionatorPriceSource
Self.SOURCES.Auctionator = {}

function Self.SOURCES.Auctionator:IsAvailable()
    return Auctionator ~= nil
end
function Self.SOURCES.Auctionator:GetItemPrice(item)
    if type(item) == "number" then
        return Auctionator.API.v1.GetVendorPriceByItemID(Name, item) or Auctionator.API.v1.GetAuctionPriceByItemID(Name, item)
    else
        return Auctionator.API.v1.GetVendorPriceByItemLink(Name, item) or Auctionator.API.v1.GetAuctionPriceByItemLink(Name, item)
    end
end
function Self.SOURCES.Auctionator:GetFullScanTime()
    return Auctionator.SavedState.TimeOfLastGetAllScan
end

-- RECrystallize

---@class RECrystallizePriceSource
Self.SOURCES.RECrystallize = {}

function Self.SOURCES.RECrystallize:IsAvailable()
    return RECrystallize_PriceCheckItemID ~= nil
end
function Self.SOURCES.RECrystallize:GetItemPrice(item)
    if type(item) == "number" then
        return RECrystallize_PriceCheckItemID(item)
    else
        return RECrystallize_PriceCheck(item)
    end
end
function Self.SOURCES.RECrystallize:GetFullScanTime()
    return RECrystallize.Config.LastScan
end

-- OribosExchange

---@class OribosExchangePriceSource
Self.SOURCES.OribosExchange = { result = {} }

function Self.SOURCES.OribosExchange:IsAvailable()
    return OEMarketInfo ~= nil
end
function Self.SOURCES.OribosExchange:GetItemPrice(item)
    local res = OEMarketInfo(item, self.result)
    return res and ((res.market or 0) > 0 and res.market or (res.region or 0) > 0 and res.region) or nil
end

-- Auctioneer

---@class AuctioneerPriceSource
Self.SOURCES.Auctioneer = {}

function Self.SOURCES.Auctioneer:IsAvailable()
    return Auctioneer ~= nil
end
function Self.SOURCES.Auctioneer:GetItemStats(item)
    local itemKey = C_AuctionHouse.MakeItemKey(C_Item.GetItemInfoInstant(item), C_Item.GetDetailedItemLevelInfo(item), 0, 0)
    local stats = Auctioneer:Statistics(itemKey)
    return stats["Stats:OverTime"]
end
function Self.SOURCES.Auctioneer:GetItemPrice(item)
    local stats = self:GetItemStats(item)
    if not stats then return end
    return stats:Best()
end
function Self.SOURCES.Auctioneer:GetItemScanTime(item)
    local stats = self:GetItemStats(item)
    if not stats then return end

    local val = 0
    for _,point in ipairs(stats.points) do
        val = max(val, point.timeslice)
    end
    return val * 3600
end