---@class Addon
local Addon = select(2, ...)
local Buffs, GUI, Util = Addon.Buffs, Addon.GUI, Addon.Util

---@class GUI.RecipeFormContainer.WithTools: GUI.RecipeFormContainer.RecipeFormContainer
---@field toolGUID? string
---@field form GUI.RecipeForm.WithCrafting
local Self = GUI.RecipeFormContainer.WithTools

---@param toolGUID? string
function Self:SetTool(toolGUID, silent)
    if toolGUID and toolGUID == self:GetCurrentTool() then toolGUID = nil end
    if self.toolGUID == toolGUID then return end

    self.toolGUID = toolGUID

    self:UpdateToolButtons()

    if silent then return end

    self.form.form:UpdateDetailsStats()
end

function Self:HasPendingTool()
    return self.toolGUID and self.toolGUID ~= self:GetCurrentTool() or false
end

---@param frame ItemButton
---@param buttonName "LeftButton" | "RightButton"
function Self:ToolButtonOnClick(frame, buttonName)
    if buttonName == "RightButton" then
        self:SetTool()
    else
        Util:TblGetHooked(frame, "OnClick")(frame, buttonName)
    end
end

function Self:InitToolButtons()
    for i=0,1 do
        local frame = self.frame[("Prof%dToolSlot"):format(i)] --[[@as ItemButton]]

        Util:TblHookScript(frame, "OnClick", Util:FnBind(self.ToolButtonOnClick, self))

        local glow = GUI:InsertElement("Frame", frame, "TestFlightItemButtonPendingTemplate")
        glow:SetAllPoints()
        glow:Hide()
        frame.Glow = glow
    end
end

function Self:UpdateToolButtons()
    local frame = self:GetCurrentToolSlot()
    if not frame then return end

    frame.Glow:SetShown(self:HasPendingTool())
end

---------------------------------------
--             Util
---------------------------------------

function Self:GetToolSlotID()
    local profInfo = C_TradeSkillUI.GetBaseProfessionInfo()
    return Buffs:GetToolSlotID(profInfo.profession)
end

function Self:GetCurrentToolSlot()
    local slotID = self:GetToolSlotID()
    for i=0,1 do
        local frame = self.frame[("Prof%dToolSlot"):format(i)] --[[@as ItemButton]]
        if frame.slotID == slotID then return frame end
    end
end

function Self:GetCurrentTool()
    local profInfo = C_TradeSkillUI.GetBaseProfessionInfo()
    return Buffs:GetCurrentTool(profInfo.profession)
end

function Self:EquipTool()
    if not self.toolGUID then return false end
    local profInfo = C_TradeSkillUI.GetBaseProfessionInfo()
    return Buffs:EquipTool(self.toolGUID, profInfo.profession)
end

---------------------------------------
--             Events
---------------------------------------

---@param skillLineID number
---@param isTool boolean
function Self:OnEquipmentChanged(skillLineID, isTool)
    if not isTool or not self.frame:IsVisible() then return end
    if skillLineID ~= C_TradeSkillUI.GetProfessionChildSkillLineID() then return end

    self:SetTool()
end

function Self:OnAddonLoaded()
    self:InitToolButtons()

    Buffs:RegisterCallback(Buffs.Event.EquipmentChanged, self.OnEquipmentChanged, self)
end