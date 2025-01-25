---@class Addon
local Addon = select(2, ...)
local Buffs, GUI, Optimization, Util = Addon.Buffs, Addon.GUI, Addon.Optimization, Addon.Util
local NS = GUI.RecipeForm

local Parent = ButtonStateBehaviorMixin

---@class GUI.RecipeForm.OptimizationMethodDropdownMixin: DropdownButtonMixin, ButtonStateBehaviorMixin
---@field Texture Texture
---@field form GUI.RecipeForm.WithOptimization
local Self = Mixin(GUI.RecipeForm.OptimizationMethodDropdown, Parent)

---@class GUI.RecipeForm.OptimizationMethodDropdown: DropdownButton, GUI.RecipeForm.OptimizationMethodDropdownMixin

function Self:OnLoad()
    Parent.OnLoad(self)

    self:SetupMenu(function(dropdown, rootDescription)
        rootDescription:SetTag("MENU_PROFESSIONS_RANK_BAR")

        local title = rootDescription:CreateTitle("Optimization target")
        title:AddInitializer(function(frame, description, menu)
            local fontString = frame.fontString
            fontString:SetPoint("RIGHT")
            fontString:SetPoint("LEFT")
            fontString:SetFontObject("GameFontNormal")
            fontString:SetJustifyH("CENTER")
        end)

        local IsSelected = Util:FnBind(self.IsSelected, self)
        local SetSelected = Util:FnBind(self.SetSelected, self)

        for name,method in pairs(Optimization.Method) do
            if method == Optimization.Method.CostPerConcentration then
                name = "Cost per Concentration"
            elseif method == Optimization.Method.ProfitPerConcentration then
                name = "Profit per Concentration"
            end

            local radio = rootDescription:CreateRadio(name, IsSelected, SetSelected, method)
            radio:AddInitializer(function(frame) frame.fontString:SetFontObject("GameFontHighlightOutline") end)
        end

        rootDescription:Insert(MenuUtil.CreateSpacer())
        Buffs:AddAuraFilters(rootDescription)

        rootDescription:SetMinimumWidth(200)
    end)
end

function Self:GetAtlas()
    return GetWowStyle1ArrowButtonState(self)
end

function Self:OnButtonStateChanged()
    self.Texture:SetAtlas(self:GetAtlas(), TextureKitConstants.UseAtlasSize)
end

---@param method Optimization.Method
function Self:IsSelected(method)
    if not self.form then return method == NS.WithCrafting.optimizationMethod end

    return method == self.form.optimizationMethod
end

---@param method Optimization.Method
function Self:SetSelected(method)
    self.form:SetOptimizationMethod(method)
end

TestFlightOptimizationMethodDropdownButtonMixin = Self