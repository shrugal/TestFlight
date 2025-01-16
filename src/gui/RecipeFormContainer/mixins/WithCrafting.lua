---@class Addon
local Addon = select(2, ...)
local GUI, Util = Addon.GUI, Addon.Util
local NS = GUI.RecipeFormContainer

local Parent = Util:TblCombineMixins(NS.WithTools)

---@class GUI.RecipeFormContainer.WithCrafting: GUI.RecipeFormContainer.RecipeFormContainer, GUI.RecipeFormContainer.WithTools
---@field form GUI.RecipeForm.WithCrafting
local Self = Mixin(GUI.RecipeFormContainer.WithCrafting, Parent)

---------------------------------------
--            CreateButton
---------------------------------------

---@param frame Button
function Self:CreateButtonOnEnter(frame)
    if self:HasPendingTool() then
        GUI:ShowInfoTooltip(frame, "Equip pending crafting tool.")
    elseif Addon.enabled then
        GUI:ShowErrorTooltip(frame, "Experimentation mode is enabled.")
    else
        local orig = Util:TblGetHooked(frame, "OnEnter")
        if orig then orig(frame) end
    end
end

---@param frame Button
---@param buttonName "LeftButton" | "RightButton"
function Self:CreateButtonOnClick(frame, buttonName)
    if buttonName == "LeftButton" and self:HasPendingTool() then
        self:EquipTool()
    elseif Addon.enabled then
        return
    else
        Util:TblGetHooked(frame, "OnClick")(frame, buttonName)
    end
end

function Self:InitCreateButton()
    Util:TblHookScript(self.frame.CreateButton, "OnClick", self.CreateButtonOnClick, self)
end

function Self:UpdateCreateButton()
    if self:HasPendingTool() then
        self.frame.CreateButton:SetText("Equip")
    elseif Addon.enabled then
        self.frame.CreateButton:SetEnabled(false)
    else
        return true
    end
end

---------------------------------------
--              Events
---------------------------------------

function Self:OnAddonLoaded()
    Parent.OnAddonLoaded(self)

    self:InitCreateButton()
end

