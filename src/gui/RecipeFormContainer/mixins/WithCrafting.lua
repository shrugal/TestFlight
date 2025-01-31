---@class Addon
local Addon = select(2, ...)
local Buffs, GUI, Util = Addon.Buffs, Addon.GUI, Addon.Util
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
    elseif self.form:GetMissingAura() then
        local action, recipe, item = self.form:GetAuraAction() ---@cast action -?
        GUI:ShowInfoTooltip(frame, Buffs:GetAuraActionTooltip(action, recipe, item))
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
    if buttonName == "LeftButton" then
        if self:HasPendingTool() then
            return self:EquipTool()
        elseif self.form:GetMissingAura() then
            return self.form:CastNextAura()
        elseif Addon.enabled then
            return
        end
    end

    Util:TblGetHooked(frame, "OnClick")(frame, buttonName)
end

function Self:InitCreateButton()
    local btn = self.frame.CreateButton

    Util:TblHookScript(btn, "OnClick", self.CreateButtonOnClick, self)

    self.secureCreateBtn = Buffs:CreateAuraSecureButton(btn)
end

function Self:UpdateCreateButton()
    self.secureCreateBtn:SetShown(false)

    if self:HasPendingTool() then
        self.frame.CreateButton:SetEnabled(true)
        self.frame.CreateButton:SetText("Equip")
    elseif self.form:GetMissingAura() then
        local action, _, item = self.form:GetAuraAction() ---@cast action -?
        self.frame.CreateButton:SetText(Buffs:GetAuraActionLabel(action))

        if Util:OneOf(action, Buffs.AuraAction.BuyItem, Buffs.AuraAction.BuyMats) then
            self.frame.CreateButton:SetEnabled(false)
        else
            self.frame.CreateButton:SetEnabled(true)

            if action == Buffs.AuraAction.UseItem and item then
                self.secureCreateBtn:SetShown(true)
                self.secureCreateBtn:SetAttribute("item", (select(2, C_Item.GetItemInfo(item))))
            end
        end
    elseif Addon.enabled then
        self.frame.CreateButton:SetEnabled(false)
    else
        return true
    end
end

---------------------------------------
--              Events
---------------------------------------

function Self:OnAuraChanged()
    if not self.frame:IsVisible() then return end
    self:UpdateCreateButton()
end

function Self:OnAddonLoaded()
    Parent.OnAddonLoaded(self)

    self:InitCreateButton()

    Buffs:RegisterCallback(Buffs.Event.AuraChanged, self.OnAuraChanged, self)
end

