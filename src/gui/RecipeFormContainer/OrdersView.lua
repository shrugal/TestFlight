---@class Addon
local Addon = select(2, ...)
local GUI, Util = Addon.GUI, Addon.Util
local NS = GUI.RecipeFormContainer

---@type GUI.RecipeFormContainer.RecipeFormContainer | GUI.RecipeFormContainer.WithCrafting
local Parent = Util:TblCombineMixins(NS.RecipeFormContainer, NS.WithCrafting)

---@class GUI.RecipeFormContainer.OrdersView: GUI.RecipeFormContainer.RecipeFormContainer, GUI.RecipeFormContainer.WithCrafting
---@field frame OrdersView
local Self = Mixin(GUI.RecipeFormContainer.OrdersView, Parent)

---------------------------------------
--            Hooks
---------------------------------------

function Self:OnShow()
    if ProfessionsUtil.IsCraftingMinimized() then
        self.frame:HideInventorySlots()
    else
        self.frame:ConfigureInventorySlots(C_TradeSkillUI.GetChildProfessionInfo())
    end
end

---------------------------------------
--            Tools
---------------------------------------

function Self:InsertToolButtons()
    ---@type ItemButton[]
    self.frame.InventorySlots = {}

    self.frame.flyoutSettings = {
		onClickFunc = PaperDollFrameItemFlyoutButton_OnClick,
		getItemsFunc = PaperDollFrameItemFlyout_GetItems,
		postGetItemsFunc = PaperDollFrameItemFlyout_PostGetItems,
		hasPopouts = true,
		parent = self.frame:GetParent(),
		anchorX = 6,
		anchorY = -3,
	}

    for i=0,1 do
        local frame
        frame = GUI:InsertItemButton(("Prof%dToolSlot"):format(i), 20 + 3*i, self.frame, "TOPRIGHT", -26, -31)
        frame = GUI:InsertItemButton(("Prof%dGear0Slot"):format(i), 21 + 3*i, self.frame, "RIGHT", frame, "LEFT", -21, 0)
        frame = GUI:InsertItemButton(("Prof%dGear1Slot"):format(i), 22 + 3*i, self.frame, "RIGHT", frame, "LEFT", -5, 0)
    end

	PaperDollItemSlotButton_SetAutoEquipSlotIDs(self.frame.Prof0ToolSlot, self.frame.Prof0Gear0Slot, self.frame.Prof0Gear1Slot)
	PaperDollItemSlotButton_SetAutoEquipSlotIDs(self.frame.Prof1ToolSlot, self.frame.Prof1Gear0Slot, self.frame.Prof1Gear1Slot)

    self.frame.GearSlotDivider = GUI:InsertElement(
        "Frame", self.frame, "TestFlightGearSlotDividerTemplate", nil,
        "RIGHT", self.frame.Prof0ToolSlot, "LEFT", -8, 0
    )

    self.frame.ConfigureInventorySlots = ProfessionsCraftingPageMixin.ConfigureInventorySlots
    self.frame.HideInventorySlots = ProfessionsCraftingPageMixin.HideInventorySlots
end

---------------------------------------
--            CreateButton
---------------------------------------

---@param frame Button
---@param buttonName "LeftButton" | "RightButton"
function Self:CreateButtonOnClick(frame, buttonName)
    local dialog = self:GetConfirmationDialog()
    if dialog then
        StaticPopup_OnClick(dialog, 1)
        self.frame:UpdateCreateButton()
    else
        Parent.CreateButtonOnClick(self, frame, buttonName)

        dialog = self:GetConfirmationDialog()
        if not dialog then return end

        self.frame.CreateButton:SetText(RPE_CONFIRM)
        dialog.data.cancelCallback = Util:FnBind(self.frame.UpdateCreateButton, self.frame)
    end
end

function Self:UpdateCreateButton()
    Parent.UpdateCreateButton(self)

    Util:TblHookScript(self.frame.CreateButton, "OnEnter", self.CreateButtonOnEnter, self)
end

---------------------------------------
--               Util
---------------------------------------

function Self:GetConfirmationDialog()
    local _, dialog = StaticPopup_Visible("GENERIC_CONFIRMATION")
    if dialog and dialog.data.text == CRAFTING_ORDERS_OWN_REAGENTS_CONFIRMATION then
        return dialog
    end
end

---------------------------------------
--              Events
---------------------------------------

---@param addonName string
function Self:OnAddonLoaded(addonName)
    if not Util:IsAddonLoadingOrLoaded("Blizzard_Professions", addonName) then return end

    self.frame = ProfessionsFrame.OrdersPage.OrderView
    self.form = GUI.RecipeForm.OrdersForm

    self:InsertToolButtons()

    Parent.OnAddonLoaded(self)

    self.frame:HookScript("OnShow", Util:FnBind(self.OnShow, self))

    Util:TblHookScript(self.frame.CreateButton, "OnClick", self.CreateButtonOnClick, self)

    hooksecurefunc(self.frame, "UpdateCreateButton", Util:FnBind(self.UpdateCreateButton, self))

    -- This is just a visual fix
    self.frame.CompleteOrderButton:SetPoint("BOTTOMRIGHT", -20, 7)
end

Addon:RegisterCallback(Addon.Event.AddonLoaded, Self.OnAddonLoaded, Self)