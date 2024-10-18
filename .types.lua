---@diagnostic disable: duplicate-set-field
---@meta

---
-- This class contains EmmyLua annotations to help
-- IDEs work with some external classes and types
---


-----------------------------------------------------
---                    Types                       --
-----------------------------------------------------

---@alias Enumerator<T, K> fun(tbl?: table<K, T>, index?: K): K, T

---@alias RecipeAllocation ProfessionTransationAllocations[]

-----------------------------------------------------
---                   Globals                      --
-----------------------------------------------------

ipairs_reverse = ipairs

---@class DevTool
---@field AddData fun(self: DevTool, data: any, name?: string)
DevTool = nil

---@class TSMAPI
---@field GetCustomPriceValue fun(customPriceStr: string, itemStr: string)
---@field ToItemString fun(item: string): string
TSM_API = nil

---@class Auctionator
---@field API { v1: AuctionatorAPIV1 }
Auctionator = nil

---@class AuctionatorAPIV1
---@field GetVendorPriceByItemID fun(callerID: string, itemID: number): number?
---@field GetAuctionPriceByItemID fun(callerID: string, itemID: number): number?
---@field GetVendorPriceByItemLink fun(callerID: string, itemLink: string): number?
---@field GetAuctionPriceByItemLink fun(callerID: string, itemLink: string): number?

---@type fun(itemID: number): number?
RECrystallize_PriceCheckItemID = nil
---@type fun(itemLink: string): number?
RECrystallize_PriceCheck = nil

---@type fun(itemLinkOrID: string | number, result: table): { market?: number, region?: number }?
OEMarketInfo = nil

---@class Auctioneer
---@field Statistics fun(self: self, itemKey: ItemKey): { ["Stats:OverTime"]?: { Best: fun(self: self): number, unknown} }
Auctioneer = nil

---@class WorldQuestTracker
---@field TrackerHeight number
---@field RefreshTrackerAnchor fun(self: self)
---@field db { profile: { tracker_attach_to_questlog: boolean } }
WorldQuestTrackerAddon = nil

---@type Frame
WorldQuestTrackerScreenPanel = nil

-----------------------------------------------------
---                 WoW frames                    --
-----------------------------------------------------

---@class ButtonFitToText: Button
---@field tooltipText? string
---@field SetTextToFit fun(self: self, text?: string)
---@field FitToText fun(self: self)

---@class DropdownButton: Button, DropdownButtonMixin

---@class FramePool
---@field Acquire fun(self: self): Frame
---@field Release fun(self: self, widget: Frame)
---@field IsActive fun(self: self, widget: Frame): boolean
---@field EnumerateActive fun(self:self): Enumerator<true, Frame>, Frame[]

---@class ReagentSlotFramePool
---@field EnumerateActive fun(self:self): Enumerator<true, ReagentSlot>, ReagentSlot[]

---@class RecipeForm: Frame
---@field transaction ProfessionTransaction
---@field reagentSlots table<Enum.CraftingReagentType, ReagentSlot[]>
---@field reagentSlotPool ReagentSlotFramePool
---@field AllocateBestQualityCheckbox CheckButton
---@field GetRecipeInfo fun(self: self): TradeSkillRecipeInfo
---@field TriggerEvent fun(self: self, event: string)

---@class ProfessionTransaction
---@field allocationTbls ProfessionTransationAllocations[]
---@field GetRecraftAllocation fun(self: self): string
---@field GetRecipeSchematic fun(self: self): CraftingRecipeSchematic
---@field CreateCraftingReagentInfoTblIf fun(self: self, predicate: function): CraftingReagentInfo[]
---@field CreateCraftingReagentInfoTbl fun(self: self): CraftingReagentInfo[]
---@field CreateRegularReagentInfoTbl fun(self: self): CraftingReagentInfo[]
---@field CreateOptionalCraftingReagentInfoTbl fun(self: self): CraftingReagentInfo[]
---@field CreateOptionalOrFinishingCraftingReagentInfoTbl fun(self: self): CraftingReagentInfo[]
---@field GetAllocationItemGUID fun(self: self): string
---@field GetSalvageAllocation fun(self: self): ItemMixin?
---@field ClearAllocations fun(self: self, slotIndex: number)
---@field GetModification fun(self: self, dataSlotIndex: number): CraftingItemSlotModification
---@field OverwriteAllocations fun(self: self, slotIndex: number, allocations: { allocs: ProfessionTransationAllocations[] })
---@field OverwriteAllocation fun(self: self, slotIndex: number, reagent: CraftingReagent | CraftingReagentInfo, quantity: number)
---@field HasAnyAllocations fun(self: self, slotIndex: number): boolean
---@field IsManuallyAllocated fun(self: self): boolean
---@field SetManuallyAllocated fun(self: self, manuallyAllocated: boolean)
---@field GetAllocations fun(self: self, slotIndex: number): ProfessionTransationAllocations
---@field Enumerate fun(self: self): Enumerator<ProfessionTransationReagent, number>, ProfessionTransationReagent[], number
---@field EnumerateAllocations fun(self: self, slotIndex: number): Enumerator<ProfessionTransactionAllocation, number>, ProfessionTransactionAllocation[], number
---@field IsApplyingConcentration fun(self: self): boolean
---@field ShouldUseCharacterInventoryOnly fun(self: self): boolean

---@alias ProfessionTransationReagent { reagentSlotSchematic: CraftingReagentSlotSchematic, allocations: ProfessionTransationAllocations}

---@class ProfessionTransationAllocations
---@field allocs ProfessionTransactionAllocation[]
---@field Clear fun(self: self)
---@field SelectFirst fun(self: self): ProfessionTransactionAllocation
---@field FindAllocationByPredicate fun(self: self, predicate: fun(v: ProfessionTransactionAllocation): boolean): ProfessionTransactionAllocation
---@field FindAllocationByReagent fun(self: self, reagent: CraftingReagent | CraftingReagentInfo): ProfessionTransactionAllocation
---@field GetQuantityAllocated fun(self: self, reagent: CraftingReagent | CraftingReagentInfo): number
---@field Accumulate fun(self: self): number
---@field HasAnyAllocations fun(self: self): boolean
---@field HasAllAllocations fun(quantityRequired: number): boolean
---@field Allocate fun(self: self, reagent: CraftingReagent, quality: number)
---@field Overwrite fun(self: self, allocations: ProfessionTransationAllocations[])
---@field OnChanged fun(self: self)
---@field Enumerate fun(self: self): Enumerator<ProfessionTransactionAllocation, number>, ProfessionTransactionAllocation[], number

---@class ProfessionTransactionAllocation
---@field reagent CraftingReagent
---@field quantity number
---@field GetQuantity fun(self: self): number
---@field SetQuantity fun(self: self, quantity: number)
---@field GetReagent fun(self: self): CraftingReagent
---@field SetReagent fun(self: self, reagent: CraftingReagent)
---@field MatchesReagent fun(self: self, reagent: CraftingReagent): boolean

---@class ProfessionAllocations

---@class ProfessionsFrame: Frame
---@field CraftingPage CraftingPage
---@field OrdersPage OrdersPage
ProfessionsFrame = nil

---@class CraftingPage: Frame
---@field SchematicForm CraftingForm
---@field RecipeList Frame
---@field CreateButton Button
---@field CreateAllButton Button
---@field CreateMultipleInputBox NumericInputSpinner
---@field ValidateControls fun(self: self)
---@field SetCreateButtonTooltipText fun(self: self, text: string)

---@class OrdersPage: Frame
---@field RecipeList Frame
---@field OrderView OrdersView

---@class OrdersView: Frame
---@field order CraftingOrderInfo
---@field OrderDetails OrdersDetails
---@field CreateButton Button

---@class OrdersDetails: Frame
---@field SchematicForm OrdersForm

---@class RecipeCraftingForm: RecipeForm, CallbackRegistryMixin
---@field recipeSchematic CraftingRecipeSchematic
---@field Details RecipeFormDetails
---@field TrackRecipeCheckbox CheckButton
---@field OutputIcon OutputSlot
---@field GetRecipeOperationInfo fun(self: self): CraftingOperationInfo
---@field Init fun(self: self, recipe: CraftingRecipeSchematic)
---@field Refresh fun(self: self)
---@field UpdateDetailsStats fun(self: self)
---@field currentRecipeInfo TradeSkillRecipeInfo
---@field recraftSlot RecraftSlot
---@field UpdateRecraftSlot fun(self: self)
---@field GetCurrentRecipeLevel fun(self: self): number
---@field GetTransaction fun(self: self): ProfessionTransaction

---@class CraftingForm: RecipeCraftingForm

---@class OrdersForm: RecipeCraftingForm

---@class RecipeFormDetails: Frame
---@field recipeInfo TradeSkillRecipeInfo
---@field operationInfo CraftingOperationInfo
---@field transaction ProfessionTransaction
---@field craftingQuality number
---@field statLinePool FramePool
---@field StatLines RecipeStatLines
---@field ApplyLayout fun()
---@field Layout fun(self: self)

---@class RecipeStatLines: Frame
---@field SkillStatLine RecipeStatLine
---@field ConcentrationStatLine RecipeStatLine
---@field Layout fun(self: self)

---@class RecipeStatLine: Frame
---@field statLineType string
---@field professionType string
---@field layoutIndex number
---@field baseValue number
---@field bonusValue number
---@field displayAsPct boolean
---@field RightLabel FontString
---@field SetLabel fun(self: self, text: string)
---@field GetStatFormat fun(self: self): string

---@class Flyout: Frame
---@field OnElementEnabledImplementation fun(): boolean
---@field GetElementValidImplementation function

---@class ReagentSlot: Frame
---@field reagentSlotSchematic CraftingReagentSlotSchematic
---@field Checkbox CheckButton
---@field Update fun(self: self)
---@field GetSlotIndex fun(self: self): number
---@field GetReagentSlotSchematic fun(self: self): CraftingReagentSlotSchematic
---@field IsUnallocatable fun(self: self): boolean
---@field SetUnallocatable fun(self: self, val: boolean)
---@field GetOriginalItem fun(self: self): ItemMixin?
---@field IsOriginalItemSet fun(self: self): boolean
---@field RestoreOriginalItem fun(self: self)
---@field SetItem fun(self: self, item?: ItemMixin)
---@field ClearItem fun(self: self)
---@field SetCheckboxCallback fun(self: self, cb: fun(checked: boolean))

---@class OutputSlot: Frame

---@class RecraftSlot: Frame
---@field InputSlot ReagentSlot
---@field OutputSlot OutputSlot
---@field Init fun(self: self, a: unknown, b: function, c: function, link: string)

---@class CustomerOrderFrame: Frame
---@field Form CustomerOrderForm
ProfessionsCustomerOrdersFrame = nil

---@class CustomerOrderForm: RecipeForm
---@field committed boolean
---@field order CraftingOrderInfo
---@field PaymentContainer OrdersFormPayments
---@field ReagentContainer OrdersFormReagents
---@field TrackRecipeCheckbox OrdersFormTrackRecipeCheckbox
---@field InitSchematic fun(self: self)

---@class OrdersFormPayments: Frame
---@field ListOrderButton Button

---@class OrdersFormReagents: Frame

---@class OrdersFormTrackRecipeCheckbox
---@field Checkbox CheckButton

---@type ObjectiveTrackerModuleMixin
WorldQuestObjectiveTracker = nil
---@type ObjectiveTrackerModuleMixin
BonusObjectiveTracker = nil

-----------------------------------------------------
---                 WoW methods                    --
-----------------------------------------------------

---@type fun(reagent: ProfessionTransationReagent, quality: number): ProfessionTransactionAllocation
function CreateAllocation() end

---@param frameType string
---@param parent? Frame
---@param template? string
---@param resetFunc? fun(self: FramePool, frame: Frame, new: boolean)
---@param forbidden? boolean
---@param frameInitializer? fun(frame: Frame)
---@param capacity? number
---@return FramePool
function CreateFramePool(frameType, parent, template, resetFunc, forbidden, frameInitializer, capacity) end

---@class C_TradeSkillUI
---@field GetRecipeItemLink fun(recipeID: number): string
C_TradeSkillUI = {}

---@class GameTooltip
---@field SetRecipeResultItem fun(self: self, recipeSpellID: number, reagents?: CraftingReagentInfo[], allocationItemGUID?: string, overrideLevel?: number, overrideQualityID?: number)
---@field SetItemByGUID fun(self: self, itemGUID: string)

---@class CheckButton
---@field text FontString

---@class NumericInputSpinner: EditBox
---@field min number
---@field max number
---@field IncrementButton Button
---@field DecrementButton Button
---@field SetMinMaxValues fun(self: self, min: number, max: number)
---@field SetValue fun(self: self, value: number)
---@field SetOnValueChangedCallback fun(self: self, callback: fun(self: self, value: number))

---@class QuestObjectiveAnimLine: Frame
---@field itemName string
---@field Button Button
---@field Text FontString
---@field Icon Texture
---@field Dash FontString
---@field dashStyle number

---@class Professions
---@field CreateCraftingReagentByItemID fun(itemID: number): CraftingReagent
---@field SetRecraftingTransitionData fun(data: { isRecraft: boolean, itemLink: string })
---@field GetIconForQuality fun(qualityID: number): string
---@field CreateCraftingReagentInfo fun(itemID: number, dataSlotIndex: number, quantity: number): CraftingReagentInfo
---@field GetReagentInputMode fun(reagent: CraftingReagentSlotSchematic): Professions.ReagentInputMode
---@field InspectRecipe fun(recipeID: number)
---@field AllocateBasicReagents fun(transaction: ProfessionTransaction, slotIndex: number, useBestQuality?: boolean)
---@field AllocateAllBasicReagents fun(transaction: ProfessionTransaction, useBestQuality?: boolean)
Professions = {}

---@class ProfessionsUtil
---@field GetReagentQuantityInPossession fun(reagent: { itemID: number } | { currencyID: number }, characterInventoryOnly?: boolean): number
---@field IsCraftingMinimized fun(): boolean
---@field IsReagentSlotRequired fun(reagent: CraftingReagentSlotSchematic): boolean
---@field IsReagentSlotBasicRequired fun(reagent: CraftingReagentSlotSchematic): boolean
---@field IsReagentSlotModifyingRequired fun(reagent: CraftingReagentSlotSchematic): boolean
---@field AccumulateReagentsInPossession fun(reagents: CraftingReagent[]): number
ProfessionsUtil = {}

-----------------------------------------------------
---                  WoW Enums                     --
-----------------------------------------------------

---@enum Professions.ReagentInputMode
Professions.ReagentInputMode = { Fixed = 1, Quality = 2, Any = 3 }

---@enum ObjectiveTrackerSlidingState
ObjectiveTrackerSlidingState = { None = 1, SlideIn = 2, SlideOut = 3 }

---@enum ObjectiveTrackerModuleState
ObjectiveTrackerModuleState = { Skipped = 1, NoObjectives = 2, NotShown = 3, ShownPartially = 4, ShownFully = 5 }

ProfessionsRecipeSchematicFormMixin = {
    ---@enum ProfessionsRecipeSchematicFormEvent
    Event = { UseBestQualityModified = "UseBestQualityModified", AllocationsModified = "AllocationsModified" }
}

-----------------------------------------------------
---            WoW Templates & Mixins              --
-----------------------------------------------------

---@class MenuMixin
---@field Init fun(self: self, ...: unknown): unknown
---@field GetLevel fun(self: self, ...: unknown): unknown
---@field SetClosedCallback fun(self: self, ...: unknown): unknown
---@field SetMenuDescription fun(self: self, ...: unknown): unknown
---@field Open fun(self: self, ...: unknown): unknown
---@field MeasureFrameExtents fun(self: self, ...: unknown): unknown
---@field PerformLayout fun(self: self, ...: unknown): unknown
---@field FlipPositionIfOffscreen fun(self: self, ...: unknown): unknown
---@field ReinitializeAll fun(self: self, ...: unknown): unknown
---@field DiscardChildFrames fun(self: self, ...: unknown): unknown
---@field Close fun(self: self, ...: unknown): unknown
---@field SendResponse fun(self: self, ...: unknown): unknown
---@field ForceOpenSubmenu fun(self: self, ...: unknown): unknown

---@class BaseMenuDescriptionMixin
---@field Init fun(self: self, ...: unknown): unknown
---@field GetMenuMixin fun(self: self, ...: unknown): unknown
---@field SetScrollMode fun(self: self, ...: unknown): unknown
---@field SetGridMode fun(self: self, ...: unknown): unknown
---@field HasGridLayout fun(self: self, ...: unknown): unknown
---@field IsScrollable fun(self: self, ...: unknown): unknown
---@field GetMaxScrollExtent fun(self: self, ...: unknown): unknown
---@field GetGridDirection fun(self: self, ...: unknown): unknown
---@field GetGridColumns fun(self: self, ...: unknown): unknown
---@field GetGridPadding fun(self: self, ...: unknown): unknown
---@field GetCompactionMargin fun(self: self, ...: unknown): unknown
---@field GetPadding fun(self: self, ...: unknown): unknown
---@field GetMinimumWidth fun(self: self, ...: unknown): unknown
---@field SetMinimumWidth fun(self: self, ...: unknown): unknown
---@field GetMaximumWidth fun(self: self, ...: unknown): unknown
---@field SetMaximumWidth fun(self: self, ...: unknown): unknown
---@field IsSubmenuDeactivated fun(self: self, ...: unknown): unknown
---@field DeactivateSubmenu fun(self: self, ...: unknown): unknown
---@field SetSharedMenuProperties fun(self: self, ...: unknown): unknown
---@field GetSharedMenuProperties fun(self: self, ...: unknown): unknown
---@field GetMenuResponseCallbacks fun(self: self, ...: unknown): unknown
---@field GetMenuChangedCallbacks fun(self: self, ...: unknown): unknown
---@field GetMenuAcquiredCallbacks fun(self: self, ...: unknown): unknown
---@field GetMenuReleasedCallbacks fun(self: self, ...: unknown): unknown
---@field IsCompositorEnabled fun(self: self, ...: unknown): unknown
---@field DisableCompositor fun(self: self, ...: unknown): unknown
---@field CanReacquireFrames fun(self: self, ...: unknown): unknown
---@field DisableReacquireFrames fun(self: self, ...: unknown): unknown
---@field HasElements fun(self: self, ...: unknown): unknown
---@field CanOpenSubmenu fun(self: self, ...: unknown): unknown
---@field EnumerateElementDescriptions fun(self: self, ...: unknown): unknown
---@field Insert fun(self: self, ...: unknown): unknown
---@field GetInitializers fun(self: self, ...: unknown): unknown
---@field AddInitializer fun(self: self, ...: unknown): unknown
---@field SetFinalInitializer fun(self: self, ...: unknown): unknown
---@field GetFinalInitializer fun(self: self, ...: unknown): unknown
---@field CreateFrame fun(self: self, ...: unknown): MenuElementDescriptionMixin
---@field CreateTemplate fun(self: self, ...: unknown): MenuElementDescriptionMixin
---@field CreateButton fun(self: self, ...: unknown): MenuElementDescriptionMixin
---@field CreateTitle fun(self: self, text: string, color?: ColorMixin): MenuElementDescriptionMixin
---@field CreateCheckbox fun(self: self, ...: unknown): MenuElementDescriptionMixin
---@field CreateRadio fun(self: self, text: string, isSelected: function, setSelected: function, contextData?: any): MenuElementDescriptionMixin
---@field CreateDivider fun(self: self, ...: unknown): MenuElementDescriptionMixin
---@field CreateSpacer fun(self: self, ...: unknown): MenuElementDescriptionMixin
---@field CreateColorSwatch fun(self: self, ...: unknown): MenuElementDescriptionMixin
---@field SetTooltip fun(self: self, ...: unknown): unknown
---@field SetTitleAndTextTooltip fun(self: self, ...: unknown): unknown
---@field QueueTitle fun(self: self, ...: unknown): unknown
---@field QueueDivider fun(self: self, ...: unknown): unknown
---@field QueueSpacer fun(self: self, ...: unknown): unknown

---@class RootMenuDescriptionMixin: BaseMenuDescriptionMixin
---@field Init fun(self: self, ...: unknown): unknown
---@field AddMenuResponseCallback fun(self: self, ...: unknown): unknown
---@field AddMenuChangedCallback fun(self: self, ...: unknown): unknown
---@field AddMenuAcquiredCallback fun(self: self, ...: unknown): unknown
---@field AddMenuReleasedCallback fun(self: self, ...: unknown): unknown
---@field GetTag fun(self: self): string?, any?
---@field SetTag fun(self: self, tag: string, contextData?: any)
---@field ClearQueuedDescriptions fun(self: self, ...: unknown): unknown
---@field AddQueuedDescription fun(self: self, ...: unknown): unknown
---@field Insert fun(self: self, ...: unknown): unknown
---@field EnumerateElementDescriptions fun(self: self, ...: unknown): unknown

---@class MenuElementDescriptionMixin
---@field Init fun(self: self, ...: unknown): unknown
---@field CallFactory fun(self: self, ...: unknown): unknown
---@field SetElementFactory fun(self: self, ...: unknown): unknown
---@field SetFinalizeGridLayout fun(self: self, ...: unknown): unknown
---@field SendResponseToMenu fun(self: self, ...: unknown): unknown
---@field ForceOpenSubmenu fun(self: self, ...: unknown): unknown
---@field SetRadio fun(self: self, ...: unknown): unknown
---@field IsRadio fun(self: self, ...: unknown): unknown
---@field SetIsSelected fun(self: self, ...: unknown): unknown
---@field IsSelected fun(self: self, ...: unknown): unknown
---@field SetCanSelect fun(self: self, ...: unknown): unknown
---@field CanSelect fun(self: self, ...: unknown): unknown
---@field SetSelectionIgnored fun(self: self, ...: unknown): unknown
---@field IsSelectionIgnored fun(self: self, ...: unknown): unknown
---@field SetSoundKit fun(self: self, ...: unknown): unknown
---@field GetSoundKit fun(self: self, ...: unknown): unknown
---@field SetShouldRespondIfSubmenu fun(self: self, ...: unknown): unknown
---@field ShouldRespondIfSubmenu fun(self: self, ...: unknown): unknown
---@field SetShouldPlaySoundOnSubmenuClick fun(self: self, ...: unknown): unknown
---@field ShouldPlaySoundOnSubmenuClick fun(self: self, ...: unknown): unknown
---@field SetOnEnter fun(self: self, ...: unknown): unknown
---@field HookOnEnter fun(self: self, ...: unknown): unknown
---@field GetOnEnter fun(self: self, ...: unknown): unknown
---@field HandleOnEnter fun(self: self, ...: unknown): unknown
---@field SetOnLeave fun(self: self, ...: unknown): unknown
---@field HookOnLeave fun(self: self, ...: unknown): unknown
---@field GetOnLeave fun(self: self, ...: unknown): unknown
---@field HandleOnLeave fun(self: self, ...: unknown): unknown
---@field SetEnabled fun(self: self, ...: unknown): unknown
---@field IsEnabled fun(self: self, ...: unknown): unknown
---@field ShouldPollEnabled fun(self: self, ...: unknown): unknown
---@field SetData fun(self: self, ...: unknown): unknown
---@field GetData fun(self: self, ...: unknown): unknown
---@field SetResponder fun(self: self, ...: unknown): unknown
---@field HookResponder fun(self: self, ...: unknown): unknown
---@field SetResponse fun(self: self, ...: unknown): unknown
---@field GetDefaultResponse fun(self: self, ...: unknown): unknown
---@field Pick fun(self: self, ...: unknown): unknown
---@field HasElements fun(self: self, ...: unknown): unknown
---@field AddInitializer fun(self: self, ...: unknown): unknown
---@field SetFinalInitializer fun(self: self, ...: unknown): unknown
---@field SetMinimumWidth fun(self: self, ...: unknown): unknown
---@field GetMinimumWidth fun(self: self, ...: unknown): unknown
---@field SetMaximumWidth fun(self: self, ...: unknown): unknown
---@field SetGridMode fun(self: self, ...: unknown): unknown
---@field SetScrollMode fun(self: self, ...: unknown): unknown

---@class DropdownButtonMixin
---@field OpenMenu fun(self: self, ...: unknown): unknown
---@field CloseMenu fun(self: self, ...: unknown): unknown
---@field SetMenuOpen fun(self: self, ...: unknown): unknown
---@field SetMenuAnchor fun(self: self, ...: unknown): unknown
---@field HandlesGlobalMouseEvent fun(self: self, ...: unknown): unknown
---@field RegisterMenu fun(self: self, ...: unknown): unknown
---@field ClearMenuState fun(self: self, ...: unknown): unknown
---@field GetMenuDescription fun(self: self, ...: unknown): unknown
---@field HasElements fun(self: self, ...: unknown): unknown
---@field SetupMenu fun(self: self, generator: fun(dropdown: self, rootDescription: RootMenuDescriptionMixin))
---@field GenerateMenu fun(self: self, ...: unknown): unknown
---@field CreateDefaultRootMenuDescription fun(self: self, ...: unknown): unknown
---@field CreateRootDescription fun(self: self, ...: unknown): unknown
---@field IsMenuOpen fun(self: self, ...: unknown): unknown
---@field SignalUpdate fun(self: self, ...: unknown): unknown
---@field OnMenuResponse fun(self: self, ...: unknown): unknown
---@field EnableRegenerateOnResponse fun(self: self, ...: unknown): unknown
---@field OnMenuAssigned fun(self: self, ...: unknown): unknown
---@field OnMenuChanged fun(self: self, ...: unknown): unknown
---@field OnMenuOpened fun(self: self, ...: unknown): unknown
---@field OnMenuClosed fun(self: self, ...: unknown): unknown
---@field UpdateSelections fun(self: self, ...: unknown): unknown
---@field Update fun(self: self, ...: unknown): unknown
---@field UpdateToMenuSelections fun(self: self, ...: unknown): unknown
---@field Pick fun(self: self, ...: unknown): unknown
---@field Rotate fun(self: self, ...: unknown): unknown
---@field Increment fun(self: self, ...: unknown): unknown
---@field Decrement fun(self: self, ...: unknown): unknown
---@field CollectSelectionData fun(self: self, ...: unknown): unknown
---@field GetSelectionData fun(self: self, ...: unknown): unknown
---@field HasStickyFocus fun(self: self, ...: unknown): unknown

---@class ButtonStateBehaviorMixin
---@field OnLoad fun(self: self, ...: unknown): unknown
---@field SetDisplacedRegions fun(self: self, ...: unknown): unknown
---@field DesaturateIfDisabled fun(self: self, ...: unknown): unknown
---@field OnButtonStateChanged fun(self: self, ...: unknown): unknown
---@field IsDownOver fun(self: self, ...: unknown): unknown
---@field IsDown fun(self: self, ...: unknown): unknown
---@field IsOver fun(self: self, ...: unknown): unknown
---@field OnEnter fun(self: self, ...: unknown): unknown
---@field OnLeave fun(self: self, ...: unknown): unknown
---@field OnMouseDown fun(self: self, ...: unknown): unknown
---@field OnMouseUp fun(self: self, ...: unknown): unknown
---@field OnEnable fun(self: self, ...: unknown): unknown
---@field OnDisable fun(self: self, ...: unknown): unknown
ButtonStateBehaviorMixin = nil

---@class CallbackRegistryMixin
---@field OnLoad fun(self: self)

---@class DirtiableMixin
---@field SetDirtyMethod fun(self: self, method: function)
---@field MarkDirty fun(self: self)
DirtiableMixin = nil

---@class ObjectiveTrackerContainerMixin
---@field modules ObjectiveTrackerModuleMixin[]
---@field topModulePadding number
---@field moduleSpacing number
---@field OnSizeChanged fun(self: self, ...: unknown): unknown
---@field OnShow fun(self: self, ...: unknown): unknown
---@field OnAdded fun(self: self, backgroundAlpha): unknown
---@field Init fun(self: self, ...: unknown): unknown
---@field GetAvailableHeight fun(self: self): number
---@field Update fun(self: self, dirtyUpdate): unknown
---@field AddModule fun(self: self, module): unknown
---@field RemoveModule fun(self: self, module): unknown
---@field HasModule fun(self: self, module): unknown
---@field GetHeightToModule fun(self: self, targetModule): unknown
---@field SetBackgroundAlpha fun(self: self, alpha): unknown
---@field ToggleCollapsed fun(self: self, ...: unknown): unknown
---@field SetCollapsed fun(self: self, collapsed): unknown
---@field IsCollapsed fun(self: self, ...: unknown): unknown
---@field UpdateHeight fun(self: self, ...: unknown): unknown
---@field ForceExpand fun(self: self, ...: unknown): unknown
---@field ForEachModule fun(self: self, callback): unknown
ObjectiveTrackerContainerMixin = nil

---@class ObjectiveTrackerSlidingMixin
---@field IsSliding fun(self: self, ...: unknown): unknown
---@field Slide fun(self: self, ...: unknown): unknown
---@field OnSlideUpdate fun(self: self, ...: unknown): unknown
---@field UpdateSlideProgress fun(self: self, ...: unknown): unknown
---@field EndSlide fun(self: self, ...: unknown): unknown
---@field AdjustSlideAnchor fun(self: self, ...: unknown): unknown
---@field OnEndSlide fun(self: self, ...: unknown): unknown
ObjectiveTrackerSlidingMixin = nil

---@class ObjectiveTrackerModuleMixin: ObjectiveTrackerSlidingMixin
---@field isModule boolean
---@field blockTemplate string
---@field lineTemplate string
---@field progressBarTemplate string
---@field headerHeight number
---@field fromHeaderOffsetY number
---@field blockOffsetX number
---@field fromBlockOffsetY number
---@field lineSpacing number
---@field bottomSpacing number
---@field rightEdgeFrameSpacing number
---@field leftMargin number
---@field hasDisplayPriority boolean
---@field mustFit boolean
---@field state ObjectiveTrackerModuleState
---@field isDirty boolean
---@field isCollapsed boolean
---@field hasTriedBlocks boolean
---@field hasSkippedBlocks boolean
---@field hasContents boolean
---@field contentsHeight number
---@field availableHeight number
---@field uiOrder number?
---@field wasDisplayedLastLayout boolean
---@field cachedOrderList table
---@field cacheIndex number
---@field numCachedBlocks number
---@field init boolean?
---@field headerText string?
---@field parentContainer ObjectiveTrackerContainerMixin?
---@field Header Frame
---@field ContentsFrame Frame
---@field OnLoad fun(self: self, ...: unknown): unknown
---@field OnEvent fun(self: self, ...: unknown): unknown
---@field OnHide fun(self: self, ...: unknown): unknown
---@field SetContainer fun(self: self, ...: unknown): unknown
---@field InitModule fun(self: self, ...: unknown): unknown
---@field MarkDirty fun(self: self, ...: unknown): unknown
---@field IsDirty fun(self: self, ...: unknown): unknown
---@field HasContents fun(self: self, ...: unknown): unknown
---@field IsDisplayable fun(self: self, ...: unknown): unknown
---@field IsFullyDisplayable fun(self: self, ...: unknown): unknown
---@field IsComplete fun(self: self, ...: unknown): unknown
---@field IsTruncated fun(self: self, ...: unknown): unknown
---@field GetContentsHeight fun(self: self): number
---@field SetHeader fun(self: self, text: string)
---@field Update fun(self: self, availableHeight: number, dirtyUpdate?: boolean): number, boolean
---@field BeginLayout fun(self: self, ...: unknown): unknown
---@field CanUpdate fun(self: self, ...: unknown): unknown
---@field LayoutContents fun(self: self, ...: unknown): unknown
---@field EndLayout fun(self: self, ...: unknown): unknown
---@field HasSkippedBlocks fun(self: self, ...: unknown): unknown
---@field UpdateHeight fun(self: self, ...: unknown): unknown
---@field SetHeightModifier fun(self: self, ...: unknown): unknown
---@field ClearHeightModifier fun(self: self, ...: unknown): unknown
---@field AcquireFrame fun(self: self, ...: unknown): unknown
---@field GetBlock fun(self: self, id: any, optTemplate?: string): ObjectiveTrackerBlock
---@field GetExistingBlock fun(self: self, id: any, optTemplate?: string): ObjectiveTrackerBlock
---@field MarkBlocksUnused fun(self: self, ...: unknown): unknown
---@field FreeUnusedBlocks fun(self: self, ...: unknown): unknown
---@field FreeBlock fun(self: self, ...: unknown): unknown
---@field OnFreeBlock fun(self: self, ...: unknown): unknown
---@field ForceRemoveBlock fun(self: self, ...: unknown): unknown
---@field GetNextBlockAnchoring fun(self: self, ...: unknown): unknown
---@field LayoutBlock fun(self: self, block: ObjectiveTrackerBlock)
---@field AddBlock fun(self: self, ...: unknown): unknown
---@field CanFitBlock fun(self: self, ...: unknown): unknown
---@field InternalAddBlock fun(self: self, ...: unknown): unknown
---@field AnchorBlock fun(self: self, ...: unknown): unknown
---@field GetLastBlock fun(self: self, ...: unknown): unknown
---@field OnBlockHeaderClick fun(self: self, ...: unknown): unknown
---@field OnBlockHeaderEnter fun(self: self, ...: unknown): unknown
---@field OnBlockHeaderLeave fun(self: self, ...: unknown): unknown
---@field ToggleCollapsed fun(self: self, ...: unknown): unknown
---@field SetCollapsed fun(self: self, ...: unknown): unknown
---@field IsCollapsed fun(self: self, ...: unknown): unknown
---@field GetContextMenuParent fun(self: self, ...: unknown): unknown
---@field GetTimerBar fun(self: self, ...: unknown): unknown
---@field MarkTimerBarsUnused fun(self: self, ...: unknown): unknown
---@field FreeUnusedTimerBars fun(self: self, ...: unknown): unknown
---@field GetProgressBar fun(self: self, ...: unknown): unknown
---@field MarkProgressBarsUnused fun(self: self, ...: unknown): unknown
---@field FreeUnusedProgressBars fun(self: self, ...: unknown): unknown
---@field GetRightEdgeFrame fun(self: self, ...: unknown): unknown
---@field MarkRightEdgeFramesUnused fun(self: self, ...: unknown): unknown
---@field FreeUnusedRightEdgeFrames fun(self: self, ...: unknown): unknown
---@field AdjustSlideAnchor fun(self: self, ...: unknown): unknown
---@field SetNeedsFanfare fun(self: self, ...: unknown): unknown
---@field NeedsFanfare fun(self: self, ...: unknown): unknown
---@field ClearFanfares fun(self: self, ...: unknown): unknown
---@field ForceExpand fun(self: self, ...: unknown): unknown
---@field AddBlockToCache fun(self: self, ...: unknown): unknown
---@field RemoveBlockFromCache fun(self: self, ...: unknown): unknown
---@field UpdateCachedOrderList fun(self: self, ...: unknown): unknown
---@field CheckCachedBlocks fun(self: self, ...: unknown): unknown
ObjectiveTrackerModuleMixin = nil

---@class ObjectiveTrackerBlock: Frame
---@field height number
---@field isHighlighted boolean
---@field HeaderText Font
---@field HeaderButton Button
---@field Init fun(self: self, ...: unknown): unknown
---@field Reset fun(self: self, ...: unknown): unknown
---@field Free fun(self: self, ...: unknown): unknown
---@field OnAddedRegion fun(self: self, ...: unknown): unknown
---@field GetLine fun(self: self, objectiveKey: any, optTemplate?: string): ObjectiveTrackerLine
---@field GetExistingLine fun(self: self, objectiveKey: any): ObjectiveTrackerLine
---@field FreeUnusedLines fun(self: self, ...: unknown): unknown
---@field FreeLine fun(self: self, ...: unknown): unknown
---@field ForEachUsedLine fun(self: self, ...: unknown): unknown
---@field SetStringText fun(self: self, ...: unknown): unknown
---@field SetHeader fun(self: self, text: string)
---@field AddObjective fun(self: self, objectiveKey: number | string, text: string, template?: string, useFullHeight?: boolean, dashStyle?: number, colorStyle?: ObjectiveTrackerColor, adjustForNoText?: boolean, overrideHeight?: number): ObjectiveTrackerLine
---@field AddCustomRegion fun(self: self, ...: unknown): unknown
---@field AddTimerBar fun(self: self, ...: unknown): unknown
---@field AddProgressBar fun(self: self, ...: unknown): unknown
---@field OnHeaderClick fun(self: self, ...: unknown): unknown
---@field OnHeaderEnter fun(self: self, ...: unknown): unknown
---@field OnHeaderLeave fun(self: self, ...: unknown): unknown
---@field UpdateHighlight fun(self: self, ...: unknown): unknown
---@field AdjustSlideAnchor fun(self: self, ...: unknown): unknown
---@field AdjustRightEdgeOffset fun(self: self, ...: unknown): unknown
---@field AddRightEdgeFrame fun(self: self, ...: unknown): unknown

---@class ObjectiveTrackerAnimBlock: ObjectiveTrackerBlock

---@class ObjectiveTrackerLine: Frame
---@field itemName string
---@field itemID number
---@field Button Button
---@field Text FontString
---@field Icon Texture
---@field Dash FontString
---@field dashStyle number
---@field OnLoad fun(self: self, ...: unknown): unknown
---@field OnHyperlinkClick fun(self: self, ...: unknown): unknown
---@field UpdateModule fun(self: self, ...: unknown): unknown
---@field OnFree? fun(self: self, block: ObjectiveTrackerBlock)

---@class ObjectiveTrackerAnimLine: ObjectiveTrackerLine
---@field OnGlowAnimFinished fun(self: self, ...: unknown): unknown
---@field OnFadeOutAnimFinished fun(self: self, ...: unknown): unknown
---@field SetState fun(self: self, ...: unknown): unknown
---@field SetNoIcon fun(self: self, ...: unknown): unknown
---@field OnFree fun(self: self, ...: unknown): unknown

---@class ObjectiveTrackerColor
---@field r number
---@field g number
---@field b number