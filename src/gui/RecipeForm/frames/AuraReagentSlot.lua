---@class Addon
local Addon = select(2, ...)
local Buffs, GUI, Util = Addon.Buffs, Addon.GUI, Addon.Util
local NS = GUI.RecipeForm

---------------------------------------
--          AuraFlyoutButton
---------------------------------------

---@class GUI.RecipeForm.AuraFlyoutButtonMixin: ItemButtonMixin, ProfessionsItemFlyoutButtonMixin
local Self = {}

---@class GUI.RecipeForm.AuraFlyoutButton: Frame, GUI.RecipeForm.AuraFlyoutButtonMixin

---@param self GUI.RecipeForm.AuraFlyoutButton 
---@param elementData FlyoutElementData
function Self:Init(elementData)
	local item = elementData.item

    if item.GetSpellID then ---@cast item SpellMixin
        self:SetSpell(item:GetSpellID())
    elseif item.GetItemID and item:GetItemID() ~= 1 then ---@cast item ItemMixin
        self:SetItem(item:GetItemID())
        self:SetItemButtonCount(C_Item.GetItemCount(item:GetItemID()))
    end

    SetItemButtonTextureVertexColor(self, 1, 1, 1)
    SetItemButtonNormalTextureVertexColor(self, 1, 1, 1)

    local enabled = Addon.enabled or item.enabled or false

	self.enabled = enabled
	self:DesaturateHierarchy(enabled and 0 or 1)
end

function Self:Reset()
    self.spell = nil
    ItemButtonMixin.Reset(self)
end

function Self:SetItemInternal(...)
    self.spell = nil
    ItemButtonMixin.SetItemInternal(self, ...)
end

function Self:SetSpell(spellID)
    self:Reset()

	self.spell = spellID

    local spell = spellID and C_Spell.GetSpellInfo(spellID)
    if spell then
		self:SetItemButtonTexture(spell.iconID)
		self:SetItemButtonQuality()
    end

	return true
end

TestFlightAuraFlyoutButtonMixin = Self

---------------------------------------
--         AuraFlyoutBehavior
---------------------------------------

---@class GUI.RecipeForm.AuraFlyoutBehaviorMixin
local Self = {}

function Self:Init(slot)
    self.slot = slot
end

function Self:GetUnownedFlags()
    return false, false
end

function Self:CanModifyFilter()
    return true
end

function Self:IsElementValid(elementData)
	return true;
end

function Self:IsElementEnabled(elementData, count)
	return true;
end

function Self:GetUndoElement()
    return nil
end

function Self:GetElements(hideUnavailable)
    local items = Buffs:GetAuraContinuables(self.slot, hideUnavailable)
    return { items = items, forceAccumulateInventory = true }
end

---@param dataProvider DataProviderMixin
---@param elements { items: AuraContinuable[] }
function Self:PopulateDataProvider(dataProvider, elements)
	for _,item in ipairs(elements.items) do dataProvider:Insert({ item = item }) end
end

local TestFlightAuraFlyoutBehaviorMixin = Self

---------------------------------------
--             AuraFlyout
---------------------------------------

local MaxColumns = 3
local HideUnavailableCvar = "professionsFlyoutHideUnowned"

---@class GUI.RecipeForm.AuraFlyoutMixin
local Self = {}

---@class GUI.RecipeForm.AuraFlyout: Frame, GUI.RecipeForm.AuraFlyoutMixin, ProfessionsFlyoutMixin

---@param self GUI.RecipeForm.AuraFlyout
function Self:OnLoad()
	CallbackRegistryMixin.OnLoad(self)

	self.Text:SetText(PROFESSIONS_PICKER_NO_AVAILABLE_REAGENTS)

	self.HideUnownedCheckbox.text:SetText(PROFESSIONS_HIDE_UNOWNED_REAGENTS)
	self.HideUnownedCheckbox:SetScript("OnClick", function(button, buttonName, down)
		local checked = button:GetChecked()
		SetCVar(HideUnavailableCvar, checked)
		self:InitializeContents()
		PlaySound(SOUNDKIT.UI_PROFESSION_HIDE_UNOWNED_REAGENTS_CHECKBOX)
	end)

	local view = CreateScrollBoxListGridView(MaxColumns)
	local padding = 3
	local spacing = 3

	view:SetPadding(padding, padding, padding, padding, spacing, spacing)
	view:SetElementInitializer("TestFlightAuraFlyoutButtonTemplate", function(button, elementData)
		button:Init(elementData)

        local item = elementData.item

		button:SetScript("OnEnter", function(button)
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            if item.GetSpellID then ---@cast item SpellMixin
                GameTooltip:SetSpellByID(item:GetSpellID())
            elseif item.GetItemID and item:GetItemID() ~= 1 then ---@cast item ItemMixin
                GameTooltip:SetItemByID(item:GetItemID())
            end
			GameTooltip:Show()
		end)

		button:SetScript("OnClick", function()
			if IsShiftKeyDown() then
				self:TriggerEvent(self.Event.ShiftClicked, self, elementData)
			else
				if button.enabled then
					self:TriggerEvent(self.Event.ItemSelected, self, elementData)
					NS.CloseAuraFlyout()
				end
			end
		end)
	end)

	ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, view)
end

---@param self GUI.RecipeForm.AuraFlyout
function Self:OnEvent(event, buttonName)
	if event ~= "GLOBAL_MOUSE_DOWN" then return end
    local isRightButton = buttonName == "RightButton"

    local mouseFoci = GetMouseFoci()
    if not isRightButton and DoesAncestryIncludeAny(self.owner, mouseFoci) then
        return
    end

    if isRightButton or (not DoesAncestryIncludeAny(self, mouseFoci) and not self:IsMouseMotionFocus()) then
        NS.CloseAuraFlyout()
    end
end

TestFlightAuraFlyoutMixin = Self

function NS.CloseAuraFlyout()
    if not NS.flyout then return end
	NS.flyout:ClearAllPoints()
	NS.flyout:Hide()
end

---@param owner Frame
---@param parent Frame
---@param slot Buffs.AuraSlot
function NS.OpenAuraFlyout(owner, parent, slot)
    if not NS.flyout then
        NS.flyout = CreateFrame("Frame", nil, nil, "TestFlightAuraFlyoutTemplate")
    end

    local behavior = CreateFromMixins(TestFlightAuraFlyoutBehaviorMixin)
    behavior:Init(slot)

	NS.flyout:SetParent(parent)
	NS.flyout:SetPoint("TOPLEFT", owner, "TOPRIGHT", 5, 0)
	NS.flyout:SetFrameStrata("HIGH")

	NS.flyout:Init(owner, behavior)
    NS.flyout:Show()

    return NS.flyout
end

---@param owner Frame
---@param parent Frame
---@param slot Buffs.AuraSlot
function NS.ToggleAuraFlyout(owner, parent, slot)
	if NS.flyout and NS.flyout:IsShown() then
		NS.CloseAuraFlyout()
    else
        return NS.OpenAuraFlyout(owner, parent, slot)
    end
end

---------------------------------------
--           AuraSlotButton
---------------------------------------

local Parent = ProfessionsReagentSlotButtonMixin

---@class GUI.RecipeForm.AuraSlotButtonMixin: ProfessionsReagentSlotButtonMixin
local Self = CreateFromMixins(Parent)

---@class GUI.RecipeForm.AuraSlotButton: ItemButton, GUI.RecipeForm.AuraSlotButtonMixin

---@param self GUI.RecipeForm.AuraSlotButton
function Self:SetSpell(spellID)
    self:Clear()

    self.spellID = spellID
    local spell = C_Spell.GetSpellInfo(spellID)
    if spell then
		self.Icon:SetTexture(spell.iconID)
		self.Icon:Show()
		self:SetSlotQuality()
    end

	self:UpdateOverlay()
end

function Self:GetSpellID()
    return self.spellID
end

function Self:Clear()
    self.spellID = nil

    Parent.Clear(self)
end

---@param self GUI.RecipeForm.AuraSlotButton
function Self:UpdateOverlay()
    self.InputOverlay.LockedIcon:Hide()
    self.InputOverlay.AddIcon:SetShown(not self:GetItemID() and not self:GetSpellID())
end

---@param self GUI.RecipeForm.AuraSlotButton
function Self:OnEnter()
    if self:GetSpellID() then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(self:GetSpellID())
        GameTooltip:Show()
    elseif self:GetItemID() then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self:GetItemID())
        GameTooltip:Show()
    end
end

TestFlightAuraSlotButtonMixin = Self

---------------------------------------
--           AuraReagentSlot
---------------------------------------

---@class GUI.RecipeForm.AuraReagentSlotMixin
---@field slot Buffs.AuraSlot
---@field Button GUI.RecipeForm.AuraSlotButton
local Self = {}

---@class GUI.RecipeForm.AuraReagentSlot: Frame, GUI.RecipeForm.AuraReagentSlotMixin

---@param self GUI.RecipeForm.AuraReagentSlot
---@param form GUI.RecipeForm.WithAuras
---@param slotType Buffs.AuraSlot
function Self:Init(form, slotType)
    self.form = form
    self.slot = slotType

    local auraID, level = form:GetAura(slotType)
    local recipe = form:GetRecipe()

    if not auraID and recipe then
        auraID, level = Buffs:GetCurrentAura(recipe, self.slot)
    end

    self:SetAura(auraID, level)
end

---@param auraID? number
---@param level? number
function Self:SetAura(auraID, level)
    self.auraID = auraID
    self.level = level

    self.Button:Reset()

    if not auraID then return end

    local item = Buffs:GetAuraContinuable(auraID, level) ---@cast item -?

    if item.GetSpellID then ---@cast item SpellMixin
        self.Button:SetSpell(item:GetSpellID())
    else ---@cast item ItemMixin
        self.Button:SetItem(item:GetItemID())
    end
end

---@param flyout Flyout
---@param elementData FlyoutElementData
function Self:FlyoutOnItemSelected(flyout, elementData)
    local item = elementData.item
    self.form:SetAura(item.auraID, item.level)
end

---@param self GUI.RecipeForm.AuraReagentSlot
function Self:OnLoad()
    self.Button:SetScript("OnMouseDown", function(button, buttonName)
        if buttonName == "LeftButton" then
            local flyout = NS.ToggleAuraFlyout(self.Button, self, self.slot)
            if not flyout then return end

            flyout:RegisterCallback(ProfessionsFlyoutMixin.Event.ItemSelected, self.FlyoutOnItemSelected, self)
        else
            NS.CloseAuraFlyout()
            local auraID = self.form:GetAura(self.slot)
            if auraID then self.form:SetAura(auraID, 0) end
        end
    end)
end

---@class GUI.RecipeForm.AuraReagentSlot: Frame, GUI.RecipeForm.AuraReagentSlotMixin

TestFlightAuraSlotMixin = Self