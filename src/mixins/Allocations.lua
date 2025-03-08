---@class Addon
local Addon = select(2, ...)
local Util = Addon.Util

---@class Allocations.Static
---@field Mixin ProfessionTransationAllocations
local Self = Addon.Allocations

---@return ProfessionTransationAllocations
function Self:Create()
    if not Self.Mixin then
        local recipe = C_TradeSkillUI.GetRecipeSchematic(898, false)
        local transaction = CreateProfessionsRecipeTransaction(recipe)
        Self.Mixin = Util:TblCreateMixin(transaction:GetAllocations(1))
    end

    local allocs = Mixin({}, Self.Mixin)
    self:WithoutOnChanged(allocs, "Init")

    return allocs
end

---@param allocs ProfessionTransationAllocations
---@param fn function | string
---@param ... any[]
function Self:WithoutOnChanged(allocs, fn, ...)
    local origOnChanged = allocs.OnChanged
    allocs.OnChanged = Util.FnNoop

    local res
    if type(fn) == "function" then
        res = fn(...)
    else
        res = allocs[fn](allocs, ...)
    end

    allocs.OnChanged = origOnChanged

    return res
end