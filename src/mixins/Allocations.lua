---@class TestFlight
local Addon = select(2, ...)
local Util = Addon.Util

---@type ProfessionTransationAllocations?
local AllocationsMixin

---@return ProfessionTransationAllocations
function Addon:CreateAllocations()
    if not AllocationsMixin then
        local recipe = C_TradeSkillUI.GetRecipeSchematic(898, false)
        local transaction = CreateProfessionsRecipeTransaction(recipe)
        AllocationsMixin = Util:TblCreateMixin(transaction:GetAllocations(1))
    end

    return CreateAndInitFromMixin(AllocationsMixin)
end
