---@diagnostic disable: duplicate-set-field
---@meta

---
-- This class contains EmmyLua annotations to help
-- IDEs work with some external classes and types
---

-- Types

---@alias Enumerator<T, K> fun(tbl: table<K, T>, index?: K): K, T

---@alias RecipeAllocation ProfessionTransationAllocations[]

---@class OptimizationFormButton: ButtonFitToText
---@field form CraftingForm

-- Globals

---@class DevTool
---@field AddData fun(self: DevTool, data: any, name?: string)
DevTool = {}

---@class TSMAPI
---@field GetCustomPriceValue fun(customPriceStr: string, itemStr: string)
TSM_API = {}

-- WoW frames

---@class ButtonFitToText: Button
---@field tooltipText? string
---@field SetTextToFit fun(self: self, text?: string)
---@field FitToText fun(self: self)

---@class FramePool
---@field EnumerateActive fun(self:self): Enumerator<true, Frame>, Frame[]

---@class ReagentSlotFramePool
---@field EnumerateActive fun(self:self): Enumerator<true, ReagentSlot>, ReagentSlot[]

---@class ProfessionForm: Frame
---@field recipeSchematic CraftingRecipeSchematic
---@field transaction ProfessionTransaction
---@field reagentSlots table<Enum.CraftingReagentType, ReagentSlot[]>
---@field reagentSlotPool ReagentSlotFramePool
---@field TriggerEvent fun(self: self, event: string)

---@class ProfessionTransaction
---@field allocationTbls ProfessionTransationAllocations[]
---@field GetRecraftAllocation fun(self: self): string
---@field CreateCraftingReagentInfoTblIf fun(self: self, predicate: function): CraftingReagentInfo[]
---@field CreateCraftingReagentInfoTbl fun(self: self): CraftingReagentInfo[]
---@field CreateOptionalOrFinishingCraftingReagentInfoTbl fun(self: self): CraftingReagentInfo[]
---@field GetAllocationItemGUID fun(self: self): string
---@field ClearAllocations fun(self: self, slotIndex: number)
---@field GetModification fun(self: self, dataSlotIndex: number): CraftingItemSlotModification
---@field OverwriteAllocations fun(self: self, slotIndex: number, allocations: { allocs: ProfessionTransationAllocations[] })
---@field OverwriteAllocation fun(self: self, slotIndex: number, reagent: CraftingReagent | CraftingReagentInfo, quantity: number)
---@field HasAnyAllocations fun(self: self, slotIndex: number): boolean
---@field SetManuallyAllocated fun(self: self, manuallyAllocated: boolean)
---@field GetAllocations fun(self: self, slotIndex: number): ProfessionTransationAllocations
---@field Enumerate fun(self: self): Enumerator<ProfessionTransationReagent, number>, ProfessionTransationReagent[], number
---@field EnumerateAllocations fun(self: self, slotIndex: number): Enumerator<ProfessionTransactionAllocation, number>, ProfessionTransactionAllocation[], number

---@alias ProfessionTransationReagent { reagentSlotSchematic: CraftingReagentSlotSchematic, allocations: ProfessionTransationAllocations}

---@class ProfessionTransationAllocations
---@field allocs ProfessionTransactionAllocation[]
---@field Clear fun(self: self)
---@field SelectFirst fun(self: self): ProfessionTransactionAllocation
---@field FindAllocationByPredicate fun(self: self, predicate: fun(v: ProfessionTransactionAllocation): boolean): ProfessionTransactionAllocation
---@field FindAllocationByReagent fun(self: self, reagent: CraftingReagent): ProfessionTransactionAllocation
---@field GetQuantityAllocated fun(self: self, reagent: CraftingReagent): number
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

---@class ProfessionAllocations

---@class ProfessionsFrame: Frame
---@field CraftingPage CraftingFrame
ProfessionsFrame = {}

---@class CraftingFrame: Frame
---@field SchematicForm CraftingForm
---@field RecipeList Frame
---@field ValidateControls function

---@class CraftingForm: ProfessionForm
---@field currentRecipeInfo TradeSkillRecipeInfo
---@field recraftSlot RecraftSlot
---@field Details CraftingFormDetails
---@field AllocateBestQualityCheckbox CheckButton
---@field TrackRecipeCheckbox CheckButton
---@field GetRecipeInfo fun(self: self): CraftingRecipeSchematic
---@field Refresh fun(self: self)
---@field UpdateDetailsStats fun(self: self)
---@field UpdateRecraftSlot fun(self: self)
---@field GetCurrentRecipeLevel fun(self: self): number
---@field GetRecipeOperationInfo fun(self: self): CraftingOperationInfo
---@field GetTransaction fun(self: self): ProfessionTransaction

---@class CraftingFormDetails: Frame
---@field StatLines CraftingStatLines

---@class CraftingStatLines: Frame
---@field SkillStatLine Frame

---@class Flyout: Frame
---@field OnElementEnabledImplementation fun(): boolean
---@field GetElementValidImplementation function

---@class ReagentSlot: Frame
---@field Update fun(self: self)
---@field GetSlotIndex fun(self: self): number
---@field GetReagentSlotSchematic fun(self: self): CraftingReagentSlotSchematic
---@field GetOriginalItem fun(self: self): ItemMixin?
---@field IsOriginalItemSet fun(self: self): boolean
---@field RestoreOriginalItem fun(self: self)
---@field ClearItem fun(self: self)

---@class RecraftSlot: ReagentSlot
---@field Init fun(self: self, a: unknown, b: function, c: function, link: string)

---@class OrderFrame: Frame
---@field Form OrderForm
ProfessionsCustomerOrdersFrame = {}

---@class OrderForm: ProfessionForm
---@field order CraftingOrderInfo
---@field PaymentContainer OrdersFormPayments
---@field ReagentContainer OrdersFormReagents
---@field AllocateBestQualityCheckbox CheckButton
---@field TrackRecipeCheckbox CheckButton
---@field InitSchematic fun(self: self)

---@class OrdersFormReagents: Frame

---@class OrdersFormPayments: Frame
---@field ListOrderButton Button

-- WoW methods

---@type fun(reagent: ProfessionTransationReagent, quality: number): ProfessionTransactionAllocation
function CreateAllocation() end

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
Professions = {}

---@class ProfessionsUtil
---@field GetReagentQuantityInPossession fun(reagent: { itemID: number } | { currencyID: number }, characterInventoryOnly?: boolean): number
---@field IsCraftingMinimized fun(): boolean
---@field IsReagentSlotRequired fun(reagent: CraftingReagentSlotSchematic): boolean
---@field IsReagentSlotBasicRequired fun(reagent: CraftingReagentSlotSchematic): boolean
---@field IsReagentSlotModifyingRequired fun(reagent: CraftingReagentSlotSchematic): boolean
---@field AccumulateReagentsInPossession fun(reagents: CraftingReagent[]): number
ProfessionsUtil = {}

-- WoW Enums

---@enum Professions.ReagentInputMode
Professions.ReagentInputMode = { Fixed = 1, Quality = 2, Any = 3 }