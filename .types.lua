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

---@alias RecipeOrOrder CraftingRecipeSchematic | TradeSkillRecipeInfo | CraftingOrderInfo | number

---@alias BuffAuraInfo { SLOT: Buffs.AuraSlot, EXPANSION: number, SKILL: number, RECIPE?: number, ITEM?: number | true, PERKS?: table<BonusStat, number>[], STATS?: table<BonusStat, number>[] }

-- MC: Multicraft
-- RF: Resourcefulness
-- CC: Concentration
-- IG: Ingenuity
-- FI: Finesse
-- SK: Skill
---@alias BonusStat "MC" | "RF" | "CC" | "IG" | "FI" | "SK"

---@class UtilChain
---@overload fun(): unknown

---@class UtilNil: UtilChain
---@overload fun(): nil

---@class UtilTbl: UtilChain
---@overload fun(): table
---@field Get fun(self: UtilChain, path): UtilAny
---@field Set fun(self: UtilChain, path, val): UtilNil
---@field SetAll fun(self: UtilChain, val): UtilTbl
---@field Enum fun(self: UtilChain, n, key): UtilFn
---@field Keys fun(self: UtilChain): UtilTbl
---@field Values fun(self: UtilChain): UtilTbl
---@field Copy fun(self: UtilChain, recursive): UtilTbl
---@field Slice fun(self: UtilChain, i, l): UtilTbl
---@field Flip fun(self: UtilChain, val): UtilTbl
---@field Push fun(self: UtilChain, ...): UtilTbl
---@field Fill fun(self: UtilChain, ...): UtilTbl
---@field Merge fun(self: UtilChain, ...): UtilTbl
---@field Map fun(self: UtilChain, fn, key, obj, ...): UtilTbl
---@field Pick fun(self: UtilChain, key): UtilTbl
---@field GroupBy fun(self: UtilChain, by, key, obj, ...): UtilTbl
---@field Match fun(self: UtilChain, ...): UtilBool
---@field Where fun(self: UtilChain, ...): UtilTbl
---@field Filter fun(self: UtilChain, fn, key, obj, ...): UtilTbl
---@field FilterWhere fun(self: UtilChain, ...): UtilTbl
---@field Contains fun(self: UtilChain, ...): UtilBool
---@field Equals fun(self: UtilChain, tbl2): UtilTbl
---@field Reduce fun(self: UtilChain, fn, value, obj): UtilAny
---@field IReduce fun(self: UtilChain, fn, value, obj): UtilAny
---@field Aggregate fun(self: UtilChain, fn, value, obj): UtilAny
---@field Find fun(self: UtilChain, fn, key, obj, ...): UtilNum
---@field FindWhere fun(self: UtilChain, ...): UtilNum
---@field Some fun(self: UtilChain, fn, key, obj, ...): UtilBool
---@field SomeWhere fun(self: UtilChain, ...): UtilBool
---@field Every fun(self: UtilChain, fn, key, obj, ...): UtilBool
---@field EveryWhere fun(self: UtilChain, ...): UtilBool
---@field IndexOf fun(self: UtilChain, value): UtilNum
---@field Includes fun(self: UtilChain, value): UtilBool
---@field Sort fun(self: UtilChain, fn): UtilTbl
---@field SortBy fun(self: UtilChain, by): UtilTbl
---@field Scan fun(self: UtilChain, fn, start, stop): UtilAny
---@field IsList fun(self: UtilChain): UtilBool
---@field Count fun(self: UtilChain, fn, key, obj, ...): UtilNum
---@field IsEmpty fun(self: UtilChain): UtilBool
---@field CountWhere fun(self: UtilChain, ...): UtilNum
---@field Join fun(self: UtilChain, sep): UtilStr
---@field CreateMixin fun(self: UtilChain): UtilTbl
---@field CombineMixins fun(self: UtilChain, ...): UtilTbl
---@field Hook fun(self: UtilChain, key, fn, obj): UtilFn
---@field HookScript fun(self: UtilChain, key, fn, obj): UtilFn
---@field Unhook fun(self: UtilChain, key): UtilFn
---@field UnhookScript fun(self: UtilChain, key): UtilFn
---@field GetHooks fun(self: UtilChain): UtilTbl
---@field IsHooked fun(self: UtilChain, key): UtilBool
---@field GetHooked fun(self: UtilChain, key): UtilFn

---@class UtilStr: UtilChain
---@overload fun(): string
---@field IsEmpty fun(self: UtilChain): UtilBool
---@field UcFirst fun(self: UtilChain): UtilStr
---@field StartCase fun(self: UtilChain): UtilStr
---@field StartsWith fun(self: UtilChain, prefix): UtilStr
---@field EndsWith fun(self: UtilChain, suffix): UtilBool
---@field Abbr fun(self: UtilChain, maxLength): UtilStr
---@field Trim fun(self: UtilChain, chars): UtilStr
---@field Wrap fun(self: UtilChain, prefix, postfix): UtilStr
---@field Lower fun(self: UtilChain): UtilStr

---@class UtilNum: UtilChain
---@overload fun(): number
---@field Round fun(self: UtilChain, p): UtilNum
---@field IsNaN fun(self: UtilChain): UtilBool
---@field RoundCurrency fun(self: UtilChain): UtilNum
---@field CurrencyString fun(self: UtilChain, color, fontHeight): UtilStr
---@field Mask fun(self: UtilChain, ...): UtilNum
---@field MaskSome fun(self: UtilChain, ...): UtilBool
---@field MaskEvery fun(self: UtilChain, ...): UtilBool

---@class UtilBool: UtilChain
---@overload fun(): boolean
---@field Xor fun(self: UtilChain, b): UtilBool

---@class UtilFn: UtilChain
---@overload fun(): function
---@field Val fun(self: UtilChain, val): UtilFn
---@field Call fun(self: UtilChain, v, k, s, ...): UtilAny
---@field CompareBy fun(self: UtilChain): UtilBool
---@field Bind fun(self: UtilChain, ...): UtilFn
---@field Combine fun(self: UtilChain, ...): UtilFn
---@field Compose fun(self: UtilChain, ...): UtilFn
---@field Capture fun(self: UtilChain, onSuccess, onFailure, errorHandler): UtilFn
---@field SlowDown fun(self: UtilChain, n, debounce, leading, trailing, update): UtilFn
---@field Throttle fun(self: UtilChain, n, leading, trailing, update): UtilFn
---@field Debounce fun(self: UtilChain, n, leading, trailing, update): UtilFn
---@field DelayedUpdate fun(self: UtilChain, n, update): UtilFn
---@field Once fun(self: UtilChain): UtilFn

---@class UtilAny: UtilChain, UtilTbl, UtilStr, UtilNum, UtilBool, UtilFn
---@overload fun(): unknown

-----------------------------------------------------
---                   Globals                      --
-----------------------------------------------------

---[Documentation](https://warcraft.wiki.gg/wiki/API_debugstack)
---@param coroutine thread
---@param start? number
---@param count1? number
---@param count2? number
---@return string description
---@overload fun(start?: number, count1?: number, count2?: number)
function debugstack(coroutine, start, count1, count2) end

ipairs_reverse = ipairs

---@class ProfessionsTableConstants
---@field StandardPadding number
---@field NoPadding number
---@field Name ProfessionsTableConstantsColumn
---@field Tip ProfessionsTableConstantsColumn
---@field NumAvailable ProfessionsTableConstantsColumn
---@field Quality ProfessionsTableConstantsColumn
---@field Reagents ProfessionsTableConstantsColumn
---@field Expiration ProfessionsTableConstantsColumn
---@field ItemName ProfessionsTableConstantsColumn
---@field Ilvl ProfessionsTableConstantsColumn
---@field Slots ProfessionsTableConstantsColumn
---@field Level ProfessionsTableConstantsColumn
---@field Skill ProfessionsTableConstantsColumn
---@field Status ProfessionsTableConstantsColumn
---@field CustomerName ProfessionsTableConstantsColumn
---@field OrderType ProfessionsTableConstantsColumn
ProfessionsTableConstants = nil

---[FrameXML](https://www.townlong-yak.com/framexml/go/MenuUtil.CreateButton)
---@param text string
---@param callback? MenuResponder
---@param data any? # stored as element's data
---@return ElementMenuDescriptionProxy
function MenuUtil.CreateButton(text, callback, data) end

---@class ProfessionsTableConstantsColumn
---@field Width number
---@field Padding number
---@field LeftCellPadding number
---@field RightCellPadding number

---@class DevTool
---@field MainWindow DevToolMainWindow
---@field list table
---@field AddData fun(self: DevTool, data: any, name?: string | number)
DevTool = nil

---@class DevToolMainWindow: Frame
---@field scrollFrame HybridScrollFrame

---@class HybridScrollFrame: ScrollFrame
---@field buttonHeight number

---@class TSMAPI
---@field GetCustomPriceValue fun(customPriceStr: string, itemString: string)
---@field GetBagQuantity fun(itemStr: string, character?: string, factionrealm?: string): number
---@field GetBankQuantity fun(itemStr: string, character?: string, factionrealm?: string): number
---@field GetReagentBankQuantity fun(itemStr: string, character?: string, factionrealm?: string): number
---@field GetAuctionQuantity fun(itemStr: string, character?: string, factionrealm?: string): number
---@field GetMailQuantity fun(itemString: string, character?: string, factionrealm?: string): number
---@field GetWarbankQuantity fun(itemStr: string): number
---@field GetGuildQuantity fun(itemStr: string, guild?: string): number
---@field GetPlayerTotals fun(itemStr: string): number, number, number, number
---@field ToItemString fun(item: string): string
---@field IsUIVisible fun(ui: "AUCTION" | "CRAFTING" | "MAILING" | "VENDORING"): boolean
TSM_API = nil

---@type string
AUCTIONATOR_L_TEMPORARY_LOWER_CASE = nil

---@class Auctionator
---@field API { v1: AuctionatorAPIV1 }
---@field SavedState { TimeOfLastGetAllScan?: number, TimeOfLastBrowseScan?: number, TimeOfLastReplicateScan?: number }
---@field Config AuctionatorConfig
Auctionator = nil

---@class AuctionatorAPIV1
---@field GetVendorPriceByItemID fun(callerID: string, itemID: number): number?
---@field GetAuctionPriceByItemID fun(callerID: string, itemID: number): number?
---@field GetAuctionAgeByItemID fun(callerID: string, itemID: number): number?
---@field GetVendorPriceByItemLink fun(callerID: string, itemLink: string): number?
---@field GetAuctionPriceByItemLink fun(callerID: string, itemLink: string): number?
---@field GetAuctionAgeByItemLink fun(callerID: string, itemLink: string): number?
---@field MultiSearchAdvanced fun(callerID: string, searchTerms: table)
---@field ConvertToSearchString fun(callerID: string, searchTerm: table): string
---@field GetShoppingListItems fun(callerID: string, shoppingListName: string): string[]
---@field AlterShoppingListItem fun(callerID: string, shoppingListName: string, oldItemSearchString: string, newItemSearchString: string)
---@field DeleteShoppingListItem fun(callerID: string, shoppingListName: string, itemSearchString: string)

---@class AuctionatorConfig
---@field Get fun(key: string): unknown
---@field Options { AUTO_LIST_SEARCH: string }

---@class AuctionatorInitalizeMainlineFrame: Frame
---@field AuctionHouseShown function
AuctionatorInitalizeMainlineFrame = nil

---@class AuctionatorAHFrame: Frame
AuctionatorAHFrame = nil

---@class AuctionatorAHFrameMixin
---@field OnShow function
AuctionatorAHFrameMixin = nil

---@class AuctionatorResultsListingContainer: Frame
---@field ResultsListing AuctionatorResultsListing
---@field DataProvider AuctionatorDataProviderMixin

---@class AuctionatorResultsListing: Frame
---@field tableBuilder TableBuilderMixin
---@field dataProvider AuctionatorDataProviderMixin

---@class AuctionatorDataProviderMixin
---@field results table
---@field entriesToProcess table
---@field OnLoad fun(self:self): unknown
---@field OnUpdate fun(self:self, elapsed): unknown
---@field Reset fun(self:self): unknown
---@field UniqueKey fun(self:self, entry): unknown
---@field Sort fun(self:self, fieldName, sortDirection): unknown
---@field SetPresetSort fun(self:self, fieldName, sortDirection): unknown
---@field ClearSort fun(self:self): unknown
---@field GetTableLayout fun(self:self): unknown
---@field GetColumnHideStates fun(self:self): unknown
---@field GetRowTemplate fun(self:self): unknown
---@field GetEntryAt fun(self:self, index): unknown
---@field GetCount fun(self:self): number
---@field SetOnEntryProcessedCallback fun(self:self, onEntryProcessedCallback): unknown
---@field SetOnUpdateCallback fun(self:self, onUpdateCallback): unknown
---@field SetOnSearchStartedCallback fun(self:self, onSearchStartedCallback): unknown
---@field SetOnSearchEndedCallback fun(self:self, onSearchEndedCallback): unknown
---@field NotifyCacheUsed fun(self:self): unknown
---@field SetDirty fun(self:self): unknown
---@field SetOnPreserveScrollCallback fun(self:self, onPreserveScrollCallback): unknown
---@field SetOnResetScrollCallback fun(self:self, onResetScrollCallback): unknown
---@field AppendEntries fun(self:self, entries, isLastSetOfResults): unknown
---@field CheckForEntriesToProcess fun(self:self): unknown
---@field GetCSV fun(self:self, callback): unknown

---@class AuctionatorShoppingEntry
---@field itemKey ItemKey
---@field name string
---@field plainItemName string
---@field purchaseQuantity? number
---@field totalQuantitiy number
---@field sortingIndex number

---@class AuctionatorShoppingFrame: AuctionatorResultsListingContainer
---@field SearchOptions AuctionatorShoppingFrameSearchOptions
---@field ListsContainer AuctionatorShoppingTabListsContainer
AuctionatorShoppingFrame = nil

---@class AuctionatorShoppingFrameSearchOptions: Frame
---@field AddToListButton Button

---@class AuctionatorShoppingList
---@field data table
---@field manager table
---@field Init fun(self: self, data, manager): unknown
---@field GetName fun(self: self): string
---@field Rename fun(self: self, newName): unknown
---@field IsTemporary fun(self: self): unknown
---@field MakePermanent fun(self: self): unknown
---@field GetItemCount fun(self: self): unknown
---@field GetItemByIndex fun(self: self, index): unknown
---@field GetIndexForItem fun(self: self, item): unknown
---@field GetAllItems fun(self: self): unknown
---@field DeleteItem fun(self: self, index): unknown
---@field AlterItem fun(self: self, index, newItem): unknown
---@field InsertItem fun(self: self, newItem, index): unknown
---@field AppendItems fun(self: self, newItems): unknown
---@field Sort fun(self: self): unknown

---@class AuctionatorShoppingTabListsContainer: Frame
---@field GetExpandedList fun(self: self): AuctionatorShoppingList?

---@class AuctionatorBuyCommodityFrame: AuctionatorResultsListingContainer
---@field itemKey ItemKey
---@field DetailsContainer AunctionatorBuyCommodityFrameDetailsContainer
---@field FinalConfirmationDialog AuctionatorBuyCommodityFinalConfirmationDialog
---@field WidePriceRangeWarningDialog AuctionatorBuyCommodityWidePriceRangeWarningDialog
---@field QuantityCheckConfirmationDialog AuctionatorBuyCommodityQuantityCheckConfirmationDialog
---@field BuyClicked fun(self: self)
AuctionatorBuyCommodityFrame = nil

---@class AunctionatorBuyCommodityFrameDetailsContainer
---@field Quantity EditBox

---@class AuctionatorBuyCommodityFinalConfirmationDialog: Frame
---@field AcceptButton Button

---@class AuctionatorBuyCommodityWidePriceRangeWarningDialog: Frame
---@field ContinueButton Button

---@class AuctionatorBuyCommodityQuantityCheckConfirmationDialog: Frame
---@field AcceptButton Button

---@class AuctionatorBuyItemFrame: AuctionatorResultsListingContainer
---@field expectedItemKey ItemKey
---@field BuyDialog AuctionatorBuyItemDialog
AuctionatorBuyItemFrame = nil

---@class AuctionatorBuyItemDialog: Frame
---@field Buy Button

---@class RECrystallize
---@field Config { LastScan: number }
RECrystallize = nil
---@type fun(itemID: number): number?
RECrystallize_PriceCheckItemID = nil
---@type fun(itemLink: string): number?
RECrystallize_PriceCheck = nil

---@type fun(itemLinkOrID: string | number, result: table): { market?: number, region?: number }?
OEMarketInfo = nil

---@class Auctioneer
---@field Statistics fun(self: self, itemKey: ItemKey): { ["Stats:OverTime"]?: { Best: (fun(self: self): number), points: AuctioneerPoint[] } }
Auctioneer = nil

---@class AuctioneerPoint
---@field timeslice number

---@class Syndicator
---@field API SyndicatorAPI
Syndicator = nil

---@class SyndicatorAPI
---@field GetInventoryInfo fun(itemLink: string, sameConnectedRealm?: boolean, sameFaction?: boolean): SyndicatorInventoryInfo
---@field GetInventoryInfoByItemLink fun(itemLink: string, sameConnectedRealm?: boolean, sameFaction?: boolean): SyndicatorInventoryInfo
---@field GetInventoryInfoByItemID fun(itemID: number, sameConnectedRealm?: boolean, sameFaction?: boolean): SyndicatorInventoryInfo
---@field GetCurrentCharacter fun(): string
---@field IsReady fun(): boolean

---@class SyndicatorInventoryInfo
---@field characters SyndicatorCharacterInfo[]
---@field guilds SyndicatorGuildInfo[]
---@field warband number[]

---@class SyndicatorCharacterInfo
---@field character string
---@field realmNormalized string
---@field className string
---@field race string
---@field sex number
---@field bags number
---@field bank number
---@field mail number
---@field equipped number
---@field void number
---@field auctions number

---@class SyndicatorGuildInfo
---@field guild string
---@field realmNormalized string
---@field bank number

---@class DataStore
---@field ThisCharID number
---@field ThisCharKey string
---@field GetAuctionHouseItemCount fun(self: DataStore, charKey: string, searchedID: number): number
---@field GetMailItemCount fun(self: DataStore, charKey: string, searchedID: number): number
---@field GetInventoryItemCount fun(self: DataStore, charKey: string, searchedID: number): number
---@field GetPlayerBankItemCount fun(self: DataStore, charKey: string, searchedID: number): number
---@field GetCharacters fun(): string[]
DataStore = nil

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

---@class EquipmentFlyoutFrame: Frame
EquipmentFlyoutFrame = nil

---@class FlyoutElementData
---@field item ItemMixin | SpellMixin | { enabled?: boolean, auraID: number, level: number }
---@field itemGUID? string
---@field itemLocation? ItemLocationMixin
---@field onlyCountStack? boolean
---@field forceAccumulateInventory? boolean

---@class StaticPopupFrame: Frame
---@field which any
---@field data table

---@type number
STATICPOPUP_NUMDIALOGS = nil
---@type fun(index: number): StaticPopupFrame?
StaticPopup_GetDialog = nil
---@type fun(which: any): string?, StaticPopupFrame?
StaticPopup_Visible = nil
---@type fun(which: any, data?: table)
StaticPopup_Hide = nil
---@type fun(dialog: StaticPopupFrame, buttonIndex: number)
StaticPopup_OnClick = nil

---@class ScrollFrame
---@field view ScrollBoxListTreeListViewMixin
---@field SetDataProvider fun(self: self, dataProvider: TreeDataProviderMixin, retainScrollPosition?: boolean)
---@field GetDataProvider fun(self: self): TreeDataProviderMixin
---@field FindFrame fun(self: self, node: TreeNodeMixin): ScrollBoxListViewElementFrame?

---@class ButtonFitToText: Button
---@field tooltipText? string
---@field SetTextToFit fun(self: self, text?: string)
---@field FitToText fun(self: self)

---@class ItemButtonMixin
---@field slotName string
---@field slotID number
---@field icon Texture
---@field Count FontString
---@field Stock FontString
---@field searchOverlay Texture
---@field ItemContextOverlay Texture
---@field IconBorder Texture
---@field IconOverlay Texture
---@field IconOverlay2 Texture
---@field NormalTexture Texture
---@field PushedTexture Texture
---@field HighlightTexture Texture
---@field Glow? Frame
---@field OnItemContextChanged fun(self: self)
---@field PostOnShow fun(self: self)
---@field PostOnHide fun(self: self)
---@field PostOnEvent fun(self: self, event, ...)
---@field SetMatchesSearch fun(self: self, matchesSearch)
---@field GetMatchesSearch fun(self: self)
---@field UpdateItemContextMatching fun(self: self)
---@field UpdateCraftedProfessionsQualityShown fun(self: self)
---@field GetItemContextOverlayMode fun(self: self)
---@field UpdateItemContextOverlay fun(self: self)
---@field UpdateItemContextOverlayTextures fun(self: self, contextMode)
---@field Reset fun(self: self)
---@field SetItemSource fun(self: self, itemLocation)
---@field SetItemLocation fun(self: self, itemLocation)
---@field SetItem fun(self: self, item)
---@field SetItemInternal fun(self: self, item)
---@field GetItemInfo fun(self: self)
---@field GetItemID fun(self: self)
---@field GetItem fun(self: self)
---@field GetItemLink fun(self: self)
---@field GetItemLocation fun(self: self)
---@field SetItemButtonCount fun(self: self, count)
---@field SetItemButtonAnchorPoint fun(self: self, point, x, y)
---@field SetItemButtonScale fun(self: self, scale)
---@field GetItemButtonCount fun(self: self)
---@field SetAlpha fun(self: self, alpha)
---@field SetBagID fun(self: self, bagID)
---@field GetBagID fun(self: self)
---@field GetSlotAndBagID fun(self: self)
---@field OnUpdateItemContextMatching fun(self: self, bagID)
---@field RegisterBagButtonUpdateItemContextMatching fun(self: self)
---@field SetItemButtonQuality fun(self: self, quality, itemIDOrLink, suppressOverlays, isBound)
---@field SetItemButtonBorderVertexColor fun(self: self, r, g, b)
---@field SetItemButtonTextureVertexColor fun(self: self, r, g, b)
---@field SetItemButtonTexture fun(self: self, texture)
---@field GetItemButtonIconTexture fun(self: self)
---@field GetItemButtonBackgroundTexture fun(self: self)
ItemButtonMixin = nil

---@class ItemButton: Button, ItemButtonMixin

---@class DropdownButton: Button, DropdownButtonMixin
---@field ResetButton Button
---@field SetDefaultCallback fun(self: self, onDefault: function)
---@field SetIsDefaultCallback fun(self: self, callback: (fun(): boolean))

---@class FramePool
---@field Acquire fun(self: self): Frame
---@field Release fun(self: self, widget: Frame)
---@field IsActive fun(self: self, widget: Frame): boolean
---@field EnumerateActive fun(self:self): Enumerator<true, Frame>, Frame[]

---@class ReagentSlotFramePool: FramePool
---@field Acquire fun(self: self): ReagentSlot
---@field EnumerateActive fun(self:self): Enumerator<true, ReagentSlot>, ReagentSlot[]

---@class StatLineFramePool: FramePool
---@field Acquire fun(self: self): RecipeStatLine
---@field EnumerateActive fun(self:self): Enumerator<true, RecipeStatLine>, RecipeStatLine[]

---@class RecipeForm: Frame
---@field transaction ProfessionTransaction
---@field reagentSlots table<Enum.CraftingReagentType, ReagentSlot[]>
---@field reagentSlotPool ReagentSlotFramePool
---@field OutputIcon OutputSlot
---@field AllocateBestQualityCheckbox CheckButton
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
---@field SetApplyConcentration fun(self: self, applyConcentration: boolean)
---@field ShouldUseCharacterInventoryOnly fun(self: self): boolean
---@field GetEnchantAllocation fun(self: self): ItemMixin?
---@field SetEnchantAllocation fun(self: self, item: ItemMixin)

---@alias ProfessionTransationReagent { reagentSlotSchematic: CraftingReagentSlotSchematic, allocations: ProfessionTransationAllocations}

---@class ProfessionTransationAllocations
---@field allocs ProfessionTransactionAllocation[]
---@field Clear fun(self: self)
---@field SelectFirst fun(self: self): ProfessionTransactionAllocation
---@field FindAllocationByPredicate fun(self: self, predicate: fun(v: ProfessionTransactionAllocation): boolean): ProfessionTransactionAllocation
---@field FindAllocationByReagent fun(self: self, reagent: CraftingReagent | CraftingReagentInfo): ProfessionTransactionAllocation
---@field GetQuantityAllocated fun(self: self, reagent: CraftingReagent | CraftingReagentInfo | CraftingItemSlotModification): number
---@field Accumulate fun(self: self): number
---@field HasAnyAllocations fun(self: self): boolean
---@field HasAllAllocations fun(self: self, quantityRequired: number): boolean
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
---@field recipesTabID number
---@field specializationsTabID number
---@field craftingOrdersTabID number
---@field CraftingPage CraftingPage
---@field OrdersPage OrdersPage
---@field GetTab fun(self: self): number
ProfessionsFrame = nil

---@class RecipeFormContainer: Frame
---@field RankBar RankBar
---@field InventorySlots ItemButton[]
---@field Prof0ToolSlot ItemButton
---@field Prof0Gear0Slot ItemButton
---@field Prof0Gear1Slot ItemButton
---@field Prof1ToolSlot ItemButton
---@field Prof1Gear0Slot ItemButton
---@field Prof1Gear1Slot ItemButton
---@field GearSlotDivider Frame
---@field CreateButton Button
---@field ConfigureInventorySlots fun(self: self, info: ProfessionInfo)
---@field HideInventorySlots fun(self: self)

---@class CraftingPage: RecipeFormContainer
---@field vellumItemID? number
---@field professionInfo ProfessionInfo
---@field SchematicForm CraftingForm
---@field RecipeList RecipeList
---@field CreateAllButton Button
---@field CreateMultipleInputBox NumericInputSpinner
---@field Init fun(self: self, professionInfo: ProfessionInfo)
---@field ValidateControls fun(self: self)
---@field SetCreateButtonTooltipText fun(self: self, text: string)
---@field OnRecipeSelected fun(self: self, recipeInfo: TradeSkillRecipeInfo, recipeList?: RecipeList)
---@field SelectRecipe fun(self: self, recipeInfo: TradeSkillRecipeInfo, skipSelectInList?: boolean)
---@field CheckShowHelptips fun(self: self)

---@class RankBar: Frame
---@field Background Texture
---@field Fill Texture
---@field Flare Texture
---@field Mask MaskTexture
---@field Border Texture
---@field Rank Frame
---@field ExpansionDropdownButton DropdownButton
---@field Texture Texture
---@field BarAnimation AnimationGroup
---@field FlareFadeOut AnimationGroup

---@class RecipeList: Frame
---@field previousRecipeID? number
---@field selectionBehavior SelectionBehaviorMixin
---@field FilterDropdown DropdownButton
---@field ScrollBox ScrollFrame
---@field SearchBox Frame
---@field NoResultsText FontString

---@class OrdersPage: Frame
---@field orderType Enum.CraftingOrderType
---@field tableBuilder ProfessionsTableBuilderMixin
---@field RecipeList Frame
---@field OrderView OrdersView
---@field BrowseFrame OrdersBrowseFrame
---@field ViewOrder fun(self: self, order: CraftingOrderInfo)
---@field StartDefaultSearch fun(self: self)

---@class OrdersBrowseFrame: Frame
---@field OrderList OrdersListFrame
---@field RecipeList Frame

---@class OrdersListFrame: Frame
---@field NineSlice Frame

---@class OrdersView: RecipeFormContainer
---@field order CraftingOrderInfo
---@field OrderDetails OrdersDetails
---@field CompleteOrderButton Button
---@field UpdateCreateButton fun(self: self)
---@field IsRecrafting fun(self: self): boolean
---@field CraftOrder fun(self: self)
---@field RecraftOrder fun(self: self)

---@class OrdersDetails: Frame
---@field SchematicForm OrdersForm

---@class RecipeCraftingForm: RecipeForm, CallbackRegistryMixin
---@field recipeSchematic CraftingRecipeSchematic
---@field Concentrate ConcentrateContainer
---@field Details RecipeFormDetails
---@field TrackRecipeCheckbox CheckButton
---@field RequiredTools FontString
---@field Reagents ProfessionsReagentContainer
---@field OptionalReagents ProfessionsReagentContainer
---@field RecraftingDescription FontString
---@field UpdateRequiredTools fun()
---@field currentRecipeInfo TradeSkillRecipeInfo
---@field recraftSlot RecraftSlot
---@field GetRecipeOperationInfo fun(self: self): CraftingOperationInfo
---@field Init fun(self: self, recipe: CraftingRecipeSchematic)
---@field Refresh fun(self: self)
---@field UpdateDetailsStats fun(self: self)
---@field UpdateRecraftSlot fun(self: self)
---@field GetRecipeInfo fun(self: self): TradeSkillRecipeInfo
---@field GetCurrentRecipeLevel fun(self: self): number
---@field GetTransaction fun(self: self): ProfessionTransaction

---@class CraftingForm: RecipeCraftingForm

---@class OrdersForm: RecipeCraftingForm

---@class RecipeFormDetails: Frame
---@field recipeInfo TradeSkillRecipeInfo
---@field operationInfo CraftingOperationInfo
---@field transaction ProfessionTransaction
---@field craftingQuality number
---@field statLinePool StatLineFramePool
---@field StatLines RecipeStatLines
---@field CraftingChoicesContainer CraftingChoicesContainer
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
---@field LeftLabel FontString
---@field RightLabel FontString
---@field SetLabel fun(self: self, text: string)
---@field GetStatFormat fun(self: self): string

---@class CraftingChoicesContainer: Frame
---@field ConcentrateContainer ConcentrateContainer

---@class ConcentrateContainer: Frame
---@field ConcentrateToggleButton ConcentrateToggleButton

---@class ConcentrateToggleButton: Frame
---@field HasEnoughConcentration fun(self: self): boolean
---@field UpdateState fun(self: self)

---@class Flyout: Frame
---@field OnElementEnabledImplementation fun(): boolean
---@field GetElementValidImplementation function

---@class ProfessionsReagentContainer: Frame
---@field Label FontString
---@field SetText fun(self: self, text: string)

---@class ReagentSlot: Frame, ProfessionsReagentSlotMixin

---@class ProfessionsReagentSlotButtonMixin: ItemButtonMixin
---@field locked? boolean
---@field Icon Texture
---@field QualityOverlay Texture
---@field InputOverlay ProfessionsReagentSlotButtonInputOverlay
---@field SetItem fun(self: self, item)
---@field SetCurrency fun(self: self, currencyID: number)
---@field GetCurrencyID fun(self: self)
---@field Reset fun(self: self)
---@field Update fun(self: self)
---@field SetLocked fun(self: self, locked: boolean)
---@field SetCropOverlayShown fun(self: self, shown)
---@field SetModifyingRequired fun(self: self, isModifyingRequired: boolean)
---@field IsModifyingRequired fun(self: self)
---@field UpdateOverlay fun(self: self)
---@field UpdateCursor fun(self: self)
---@field SetSlotQuality fun(self: self, quality?: Enum.ItemQuality)
---@field SetItemInternal fun(self: self, item)
ProfessionsReagentSlotButtonMixin = nil

---@class ProfessionsReagentSlotButtonInputOverlay: Frame
---@field LockedIcon Texture
---@field AddIcon Texture

---@class ProfessionsReagentSlotMixin
---@field Button ProfessionsReagentSlotButtonMixin
---@field Name FontString
---@field item? ItemMixin
---@field originalItem? ItemMixin
---@field reagentSlotSchematic CraftingReagentSlotSchematic
---@field Checkbox CheckButton
---@field Reset fun(self: self)
---@field SetSlotBehaviorModifyingRequired fun(self: self, isModifyingRequired: boolean)
---@field Init fun(self: self, transaction, reagentSlotSchematic)
---@field SetOverrideNameColor fun(self: self, color, skipUpdate)
---@field SetOverrideQuantity fun(self: self, quantity, skipUpdate)
---@field GetNameColor fun(self: self)
---@field Update fun(self: self)
---@field SetShowOnlyRequired fun(self: self, value, skipUpdate)
---@field UpdateAllocationText fun(self: self)
---@field GetAllocationDetails fun(self: self)
---@field GetInventoryDetails fun(self: self)
---@field UpdateQualityOverlay fun(self: self)
---@field SetNameText fun(self: self, text)
---@field SetUnallocatable fun(self: self, val: boolean)
---@field IsUnallocatable fun(self: self): boolean
---@field ClearItem fun(self: self)
---@field RestoreOriginalItem fun(self: self)
---@field IsOriginalItemSet fun(self: self): boolean
---@field SetOriginalItem fun(self: self, item)
---@field GetOriginalItem fun(self: self): ItemMixin?
---@field ApplySlotInfo fun(self: self)
---@field SetItem fun(self: self, item?: ItemMixin)
---@field SetCurrency fun(self: self, currencyID)
---@field GetSlotIndex fun(self: self): number
---@field GetReagentType fun(self: self): Enum.CraftingReagentType
---@field SetTransaction fun(self: self, transaction: ProfessionTransaction)
---@field GetTransaction fun(self: self): ProfessionTransaction
---@field SetReagentSlotSchematic fun(self: self, reagentSlotSchematic: CraftingReagentSlotSchematic)
---@field GetReagentSlotSchematic fun(self: self): CraftingReagentSlotSchematic
---@field SetAllocateIconShown fun(self: self, shown)
---@field SetCheckboxShown fun(self: self, shown)
---@field SetCheckboxChecked fun(self: self, checked)
---@field SetCheckboxEnabled fun(self: self, enabled)
---@field SetCheckboxCallback fun(self: self, cb: fun(checked: boolean))
---@field SetCheckboxTooltipText fun(self: self, text)
---@field SetHighlightShown fun(self: self, shown)
---@field SetCheckmarkShown fun(self: self, shown)
---@field SetCheckmarkAtlas fun(self: self, atlas)
---@field SetCheckmarkTooltipText fun(self: self, text)
---@field SetColorOverlay fun(self: self, color, alpha)
---@field SetAddIconDesaturated fun(self: self, desaturated)
ProfessionsReagentSlotMixin = nil

---@class ProfessionsItemFlyoutButtonMixin
---@field Init fun(self: self, elementData, onElementEnabledImplementation, onElementValidImplementation)
ProfessionsItemFlyoutButtonMixin = nil

---@class ProfessionsItemFlyoutMixin: CallbackRegistryMixin
---@field Event { UndoClicked: "UndoClicked", ItemSelected: "ItemSelected", ShiftClicked: "ShiftClicked" }
---@field Text FontString
---@field UndoItem ItemButton
---@field UndoButton Button
---@field ScrollBox Frame
---@field ScrollBar EventFrame
---@field HideUnownedCheckbox CheckButton
---@field OnElementEnterImplementation? function
---@field GetElementValidImplementation? function
---@field OnElementEnabledImplementation? function
---@field owner? Frame
---@field OnLoad fun(self: self)
---@field OnShow fun(self: self)
---@field OnHide fun(self: self)
---@field ClearHandlers fun(self: self)
---@field OnEvent fun(self: self, event, ...)
---@field InitializeContents fun(self: self)
---@field Init fun(self: self, owner, transaction, canModifyFilter)
ProfessionsItemFlyoutMixin = nil

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
---@field depositCost number
---@field order CraftingOrderInfo
---@field PaymentContainer OrdersFormPayments
---@field ReagentContainer OrdersFormReagents
---@field TrackRecipeCheckbox OrdersFormTrackRecipeCheckbox
---@field InitSchematic fun(self: self)

---@class OrdersFormPayments: Frame
---@field ListOrderButton Button
---@field Tip FontString
---@field Duration DropdownButton
---@field TimeRemaining FontString
---@field PostingFee FontString
---@field TotalPrice FontString
---@field TipMoneyInputFrame LargeMoneyInputFrame
---@field TotalPriceMoneyDisplayFrame MoneyDisplayFrame

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

---@param ... ItemButton
function PaperDollItemSlotButton_SetAutoEquipSlotIDs(...) end

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

---@param location number
---@return boolean player Equipped
---@return boolean bank In bank
---@return boolean bags In bags
---@return boolean voidStorage In void storage
---@return number slot Equipment, bank or bag slot
---@return number bag Bag
---@return number tab Void storage tab
---@return number voidSlot Void storage slot
function EquipmentManager_UnpackLocation(location) end

---@param location number
---@param invSlot number
---@return table
function EquipmentManager_EquipItemByLocation(location, invSlot) end

---@param action table
---@return boolean
function EquipmentManager_RunAction(action) end

---@class C_TradeSkillUI
---@field GetRecipeItemLink fun(recipeID: number): string
---@field GetFilteredRecipeIDs fun(): number[]
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
---@field InitFilterMenu fun(dropdown: DropdownButton, onUpdate?: function, onDefault?: function, ignoreSkillLine?: boolean)
---@field SetDefaultFilters fun(ignoreSkillLine?: boolean)
---@field GetReagentSlotStatus fun(reagent: CraftingReagentSlotSchematic, recipeInfo, TradeSkillRecipeInfo): boolean, string?
---@field IsUsingDefaultFilters fun(ignoreSkillLine?: boolean): boolean
---@field InLocalCraftingMode fun(): boolean
---@field GetProfessionInfo fun(): ProfessionInfo
---@field EraseRecraftingTransitionData fun()
---@field LayoutAndShowReagentSlotContainer fun(slots, container)
Professions = {}

---@class ProfessionsUtil
---@field GetReagentQuantityInPossession fun(reagent: { itemID: number } | { currencyID: number }, characterInventoryOnly?: boolean): number
---@field IsCraftingMinimized fun(): boolean
---@field IsReagentSlotRequired fun(reagent: CraftingReagentSlotSchematic): boolean
---@field IsReagentSlotBasicRequired fun(reagent: CraftingReagentSlotSchematic): boolean
---@field IsReagentSlotModifyingRequired fun(reagent: CraftingReagentSlotSchematic): boolean
---@field AccumulateReagentsInPossession fun(reagents: CraftingReagent[]): number
---@field OpenProfessionFrameToRecipe fun(recipeID: number)
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

---@class ScrollDirectionMixin
---@field SetHorizontal fun(self: self, isHorizontal)
---@field IsHorizontal fun(self: self)
---@field GetFrameExtent fun(self: self, frame)
---@field SetFrameExtent fun(self: self, frame, value)
---@field GetUpper fun(self: self, frame)
---@field GetLower fun(self: self, frame)
---@field SelectCursorComponent fun(self: self, parent)
---@field SelectPointComponent fun(self: self, frame)

---@class ScrollBoxViewMixin: ScrollDirectionMixin
---@field GetFrameLevelPolicy fun(self: self)
---@field SetFrameLevelPolicy fun(self: self, frameLevelPolicy)
---@field IsElementStretchDisabled fun(self: self)
---@field SetElementStretchDisabled fun(self: self, elementStretchDisabled)
---@field Init fun(self: self)
---@field IsInitialized fun(self: self)
---@field SetPadding fun(self: self, padding)
---@field GetPadding fun(self: self)
---@field SetPanExtent fun(self: self, panExtent)
---@field SetScrollBox fun(self: self, scrollBox)
---@field GetScrollBox fun(self: self)
---@field InitDefaultDrag fun(self: self, scrollBox)
---@field IsExtentValid fun(self: self)
---@field SetExtent fun(self: self, extent)
---@field GetScrollTarget fun(self: self)
---@field RequiresFullUpdateOnScrollTargetSizeChange fun(self: self)
---@field GetFrames fun(self: self)
---@field FindFrame fun(self: self, elementData)
---@field FindFrameByPredicate fun(self: self, predicate: (fun(frame: Frame, elementData: any): boolean)): Frame?

---@class ScrollBoxListViewMixin: ScrollBoxViewMixin, CallbackRegistryMixin
---@field factoryFrame? frame
---@field factoryFrameIsNew? boolean
---@field initializers table<Frame, function>
---@field Init fun(self: self)
---@field GetExtentFromInfo fun(self: self, info)
---@field GetTemplateInfo fun(self: self, frameTemplate)
---@field AssignAccessors fun(self: self, frame, elementData)
---@field UnassignAccessors fun(self: self, frame)
---@field Flush fun(self: self)
---@field ForEachFrame fun(self: self, func)
---@field ReverseForEachFrame fun(self: self, func: (fun(frame: ScrollBoxListViewElementFrame, data: any)))
---@field EnumerateFrames fun(self: self)
---@field FindFrame fun(self: self, elementData: any): ScrollBoxListViewElementFrame?
---@field FindFrameByPredicate fun(self: self, predicate: (fun(frame: ScrollBoxListViewElementFrame, elementData: any): boolean)): ScrollBoxListViewElementFrame?
---@field FindFrameElementDataIndex fun(self: self, findFrame: ScrollBoxListViewElementFrame): number?
---@field ForEachElementData fun(self: self, func)
---@field ReverseForEachElementData fun(self: self, func)
---@field FindElementData fun(self: self, index)
---@field FindElementDataIndex fun(self: self, elementData)
---@field FindElementDataByPredicate fun(self: self, predicate)
---@field FindElementDataIndexByPredicate fun(self: self, predicate)
---@field FindByPredicate fun(self: self, predicate)
---@field Find fun(self: self, index)
---@field FindIndex fun(self: self, elementData)
---@field ContainsElementDataByPredicate fun(self: self, predicate)
---@field EnumerateDataProviderEntireRange fun(self: self)
---@field EnumerateDataProvider fun(self: self, indexBegin, indexEnd)
---@field ReverseEnumerateDataProviderEntireRange fun(self: self)
---@field ReverseEnumerateDataProvider fun(self: self, indexBegin, indexEnd)
---@field GetDataProviderSize fun(self: self)
---@field TranslateElementDataToUnderlyingData fun(self: self, elementData)
---@field IsScrollToDataIndexSafe fun(self: self)
---@field PrepareScrollToElementDataByPredicate fun(self: self, predicate)
---@field PrepareScrollToElementData fun(self: self, elementData)
---@field GetDataProvider fun(self: self)
---@field HasDataProvider fun(self: self)
---@field RemoveDataProviderInternal fun(self: self)
---@field RemoveDataProvider fun(self: self)
---@field FlushDataProvider fun(self: self)
---@field SetDataProvider fun(self: self, dataProvider, retainScrollPosition)
---@field OnDataProviderSizeChanged fun(self: self, pendingSort)
---@field OnDataProviderSort fun(self: self)
---@field DataProviderContentsChanged fun(self: self)
---@field SignalDataChangeEvent fun(self: self, invalidationReason)
---@field IsAcquireLocked fun(self: self)
---@field SetAcquireLocked fun(self: self, locked)
---@field AcquireInternal fun(self: self, dataIndex, elementData)
---@field InvokeInitializer fun(self: self, frame, initializer)
---@field InvokeInitializers fun(self: self)
---@field AcquireRange fun(self: self, dataIndices)
---@field ReinitializeFrames fun(self: self)
---@field Release fun(self: self, frame)
---@field GetFrameCount fun(self: self)
---@field SetElementInitializer fun(self: self, frameTemplateOrFrameType, initializer)
---@field SetElementFactory fun(self: self, elementFactory)
---@field SetFrameFactoryResetter fun(self: self, resetter)
---@field SetElementResetter fun(self: self, resetter)
---@field SetVirtualized fun(self: self, virtualized)
---@field CalculateFrameExtent fun(self: self, dataIndex, elementData)
---@field GetFactoryDataFromElementData fun(self: self, elementData)
---@field GetTemplateExtentFromElementData fun(self: self, elementData)
---@field GetTemplateExtent fun(self: self, frameTemplate)
---@field GetPanExtent fun(self: self, spacing)
---@field IsVirtualized fun(self: self)
---@field CalculateDataIndices fun(self: self, scrollBox, stride, spacing)
---@field RecalculateExtent fun(self: self, scrollBox, stride, spacing)
---@field GetExtent fun(self: self, scrollBox, stride, spacing)
---@field HasIdenticalElementExtents fun(self: self)
---@field GetIdenticalElementExtents fun(self: self)
---@field GetElementExtent fun(self: self, dataIndex)
---@field SetElementExtent fun(self: self, extent)
---@field SetElementExtentCalculator fun(self: self, elementExtentCalculator)
---@field GetElementExtentCalculator fun(self: self)
---@field GetExtentUntil fun(self: self, scrollBox, dataIndex, stride, spacing)
---@field GetDataScrollOffset fun(self: self, scrollBox)
---@field ValidateDataRange fun(self: self, scrollBox)
---@field SortFrames fun(self: self)
---@field SetInvalidationReason fun(self: self, invalidationReason)
---@field GetInvalidationReason fun(self: self)
---@field ClearInvalidation fun(self: self)
---@field IsInvalidated fun(self: self)
---@field GetDataIndexBegin fun(self: self)
---@field GetDataIndexEnd fun(self: self)
---@field GetDataRange fun(self: self)
---@field SetDataRange fun(self: self, dataIndexBegin, dataIndexEnd)
---@field IsDataIndexWithinRange fun(self: self, dataIndex)

---@class ScrollBoxListViewElementFrame: Frame
---@field GetData fun(self: self): any?
---@field GetElementData fun(self: self): any?
---@field GetElementDataIndex fun(self: self): number?
---@field ElementDataMatches fun(self: self, elementData: any): boolean
---@field GetOrderIndex fun(self: self): number
---@field SetOrderIndex fun(self: self, orderIndex: number)

---@class ScrollBoxLinearBaseViewMixin
---@field SetPadding fun(self: self, top, bottom, left, right, spacing)
---@field GetSpacing fun(self: self)
---@field GetStride fun(self: self)
---@field LayoutInternal fun(self: self, layoutFunction)
---@field SetElementIndentCalculator fun(self: self, elementIndentCalculator)
---@field GetElementIndent fun(self: self, frame)
---@field GetLayoutFunction fun(self: self)
---@field Layout fun(self: self)

---@class ScrollBoxListLinearViewMixin: ScrollBoxListViewMixin, ScrollBoxLinearBaseViewMixin
---@field Init fun(self: self, top, bottom, left, right, spacing)
---@field SetScrollBox fun(self: self, scrollBox)
---@field InitDefaultDrag fun(self: self, scrollBox)
---@field CalculateDataIndices fun(self: self, scrollBox)
---@field GetExtent fun(self: self, scrollBox)
---@field RecalculateExtent fun(self: self, scrollBox)
---@field GetExtentUntil fun(self: self, scrollBox, dataIndex)
---@field GetPanExtent fun(self: self)

---@class ScrollBoxListTreeListViewMixin: ScrollBoxListLinearViewMixin
---@field Init fun(self: self, indent, top, bottom, left, right, spacing)
---@field InitDefaultDrag fun(self: self, scrollBox)
---@field ForEachElementData fun(self: self, func)
---@field ReverseForEachElementData fun(self: self, func)
---@field Find fun(self: self, index)
---@field FindIndex fun(self: self, elementData)
---@field FindElementData fun(self: self, index)
---@field FindElementDataIndex fun(self: self, elementData)
---@field FindElementDataByPredicate fun(self: self, predicate)
---@field FindElementDataIndexByPredicate fun(self: self, predicate)
---@field FindByPredicate fun(self: self, predicate)
---@field ContainsElementDataByPredicate fun(self: self, predicate)
---@field EnumerateDataProviderEntireRange fun(self: self)
---@field EnumerateDataProvider fun(self: self, indexBegin, indexEnd)
---@field ReverseEnumerateDataProviderEntireRange fun(self: self)
---@field ReverseEnumerateDataProvider fun(self: self, indexBegin, indexEnd)
---@field GetDataProviderSize fun(self: self)
---@field TranslateElementDataToUnderlyingData fun(self: self, elementData)
---@field IsScrollToDataIndexSafe fun(self: self)
---@field PrepareScrollToElementDataByPredicate fun(self: self, predicate)
---@field PrepareScrollToElementData fun(self: self, elementData)
---@field SetElementIndent fun(self: self, indent)
---@field GetElementIndent fun(self: self)
---@field AssignAccessors fun(self: self, frame, elementData)
---@field UnassignAccessors fun(self: self, frame)
---@field GetLayoutFunction fun(self: self)
---@field Layout fun(self: self)

---@class ItemMixin
---@field IsStackable fun(self: self): boolean

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

---@class MenuElementDescriptionMixin: BaseMenuDescriptionMixin
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
---@field menuGenerator fun(dropdown: self, rootDescription: RootMenuDescriptionMixin)
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

---@class DataProviderMixin
---@field Event { OnSizeChanged: "OnSizeChanged", OnInsert: "OnInsert", OnRemove: "OnRemove", OnSort: "OnSort", OnMove: "OnMove" }
---@field Init fun(self: self, ...: unknown): unknown
---@field Enumerate fun(self: self, ...: unknown): unknown
---@field EnumerateEntireRange fun(self: self, ...: unknown): unknown
---@field ReverseEnumerate fun(self: self, ...: unknown): unknown
---@field ReverseEnumerateEntireRange fun(self: self, ...: unknown): unknown
---@field GetCollection fun(self: self, ...: unknown): unknown
---@field GetSize fun(self: self, ...: unknown): unknown
---@field IsEmpty fun(self: self, ...: unknown): unknown
---@field InsertInternal fun(self: self, ...: unknown): unknown
---@field InsertAtIndex fun(self: self, ...: unknown): unknown
---@field Insert fun(self: self, ...: unknown): unknown
---@field InsertTable fun(self: self, ...: unknown): unknown
---@field InsertTableRange fun(self: self, ...: unknown): unknown
---@field MoveElementDataToIndex fun(self: self, ...: unknown): unknown
---@field Remove fun(self: self, ...: unknown): unknown
---@field RemoveByPredicate fun(self: self, ...: unknown): unknown
---@field RemoveIndex fun(self: self, ...: unknown): unknown
---@field RemoveIndexRange fun(self: self, ...: unknown): unknown
---@field SetSortComparator fun(self: self, ...: unknown): unknown
---@field ClearSortComparator fun(self: self, ...: unknown): unknown
---@field HasSortComparator fun(self: self, ...: unknown): unknown
---@field Sort fun(self: self, ...: unknown): unknown
---@field Find fun(self: self, ...: unknown): unknown
---@field FindIndex fun(self: self, ...: unknown): unknown
---@field FindByPredicate fun(self: self, ...: unknown): unknown
---@field FindElementDataByPredicate fun(self: self, ...: unknown): unknown
---@field FindIndexByPredicate fun(self: self, ...: unknown): unknown
---@field ContainsByPredicate fun(self: self, ...: unknown): unknown
---@field ForEach fun(self: self, ...: unknown): unknown
---@field ReverseForEach fun(self: self, ...: unknown): unknown
---@field Flush fun(self: self, ...: unknown): unknown
DataProviderMixin = nil

---@class TreeNodeMixin
---@field data unknown
---@field sortComparator fun(a: TreeNodeMixin, b: TreeNodeMixin): boolean
---@field Init fun(self: self, ...: unknown): unknown
---@field GetNodes fun(self: self, ...: unknown): unknown
---@field GetDepth fun(self: self, ...: unknown): unknown
---@field GetData fun(self: self, ...: unknown): unknown
---@field GetSize fun(self: self, ...: unknown): unknown
---@field GetFirstNode fun(self: self, ...: unknown): unknown
---@field MoveNode fun(self: self, ...: unknown): unknown
---@field MoveNodeRelativeTo fun(self: self, ...: unknown): unknown
---@field GetParent fun(self: self, ...: unknown): unknown
---@field Flush fun(self: self, ...: unknown): unknown
---@field Insert fun(self: self, ...: unknown): unknown
---@field InsertNode fun(self: self, ...: unknown): unknown
---@field Remove fun(self: self, ...: unknown): unknown
---@field SetSortComparator fun(self: self, comp: (fun(a: TreeNodeMixin, b: TreeNodeMixin): boolean), affectChildren?: boolean, skipSort?: boolean)
---@field HasSortComparator fun(self: self): boolean
---@field Sort fun(self: self)
---@field Invalidate fun(self: self, ...: unknown): unknown
---@field SetChildrenCollapsed fun(self: self, ...: unknown): unknown
---@field SetCollapsed fun(self: self, ...: unknown): unknown
---@field ToggleCollapsed fun(self: self, ...: unknown): unknown
---@field IsCollapsed fun(self: self, ...: unknown): unknown
TreeNodeMixin = nil

---@class TreeDataProviderMixin: CallbackRegistryMixin
---@field sortComparator? fun(a: TreeNodeMixin, b: TreeNodeMixin): boolean
---@field Init fun(self: self, ...: unknown): unknown
---@field GetChildrenNodes fun(self: self): TreeNodeMixin[]
---@field GetFirstChildNode fun(self: self): TreeNodeMixin?
---@field GetRootNode fun(self: self): TreeNodeMixin
---@field Invalidate fun(self: self)
---@field IsEmpty fun(self: self): boolean
---@field Insert fun(self: self, data: any)
---@field Remove fun(self: self, node: TreeNodeMixin)
---@field SetSortComparator fun(self: self, comp?: (fun(a: TreeNodeMixin, b: TreeNodeMixin): boolean), affectChildren?: boolean, skipSort?: boolean)
---@field HasSortComparator fun(self: self): boolean
---@field Sort fun(self: self)
---@field GetSize fun(self: self): number
---@field SetCollapsedByPredicate fun(self: self, ...: unknown): unknown
---@field InsertInParentByPredicate fun(self: self, ...: unknown): unknown
---@field EnumerateEntireRange fun(self: self): Enumerator<TreeNodeMixin, number>
---@field Enumerate fun(self: self, startIndex?: number, endIndex?: number, excludeCollapsed: boolean): Enumerator<TreeNodeMixin, number>
---@field ForEach fun(self: self, ...: unknown): unknown
---@field Find fun(self: self, ...: unknown): unknown
---@field FindIndex fun(self: self, ...: unknown): unknown
---@field FindElementDataByPredicate fun(self: self, ...: unknown): unknown
---@field FindByPredicate fun(self: self, predicate: (fun(node: TreeNodeMixin): boolean), excludeCollapsed: boolean): number?, TreeNodeMixin?
---@field FindIndexByPredicate fun(self: self, ...: unknown): unknown
---@field ContainsByPredicate fun(self: self, ...: unknown): unknown
---@field Flush fun(self: self, ...: unknown): unknown
---@field SetAllCollapsed fun(self: self, ...: unknown): unknown
---@field CollapseAll fun(self: self, ...: unknown): unknown
---@field UncollapseAll fun(self: self, ...: unknown): unknown
TreeDataProviderMixin = nil

---@class LinearizedTreeDataProviderMixin: TreeDataProviderMixin
---@field GetSize fun(self: self, ...: unknown): unknown
---@field Enumerate fun(self: self, ...: unknown): unknown
---@field Flush fun(self: self, ...: unknown): unknown
---@field Invalidate fun(self: self, ...: unknown): unknown
---@field GetLinearized fun(self: self, ...: unknown): unknown
LinearizedTreeDataProviderMixin = nil

---@return LinearizedTreeDataProviderMixin
function CreateTreeDataProvider() end

ScrollBoxConstants = {
    UpdateQueued = false,
    UpdateImmediately = true,
    NoScrollInterpolation = true,
    RetainScrollPosition = true,
    DiscardScrollPosition = false,
    AlignBegin = 0,
    AlignCenter = .5,
    AlignEnd = 1,
    AlignNearest = -1,
    ScrollBegin = MathUtil.Epsilon,
    ScrollEnd = (1 - MathUtil.Epsilon),
    StopIteration = true,
    ContinueIteration = false,
}

---@class ProfessionsRecipeListRecipeMixin
---@field learned boolean
---@field SkillUps Button
---@field LockedIcon Button
---@field Label FontString
---@field Count FontString
---@field SelectedOverlay Texture
---@field HighlightOverlay Texture
---@field OnLoad fun(self: self, ...: unknown): unknown
---@field Init fun(self: self, ...: unknown): unknown
---@field GetLabelColor fun(self: self): ColorMixin
---@field SetLabelFontColors fun(self: self, ...: unknown): unknown
---@field OnEnter fun(self: self, ...: unknown): unknown
---@field OnLeave fun(self: self, ...: unknown): unknown
---@field SetSelected fun(self: self, ...: unknown): unknown
ProfessionsRecipeListRecipeMixin = nil

---@class ProfessionsRecipeListRecipeFrame: ScrollBoxListViewElementFrame, ProfessionsRecipeListRecipeMixin

---@class SelectionBehaviorMixin: CallbackRegistryMixin
---@field Event { OnSelectionChanged: "OnSelectionChanged" }
---@field IsIntrusiveSelected fun(self: self, ...: unknown): unknown
---@field IsElementDataIntrusiveSelected fun(self: self, ...: unknown): unknown
---@field IsSelected fun(self: self, ...: unknown): unknown
---@field IsElementDataSelected fun(self: self, ...: unknown): unknown
---@field Init fun(self: self, ...: unknown): unknown
---@field SetSelectionFlags fun(self: self, ...: unknown): unknown
---@field HasSelection fun(self: self, ...: unknown): unknown
---@field GetFirstSelectedElementData fun(self: self, ...: unknown): TreeNodeMixin?
---@field GetSelectedElementData fun(self: self, ...: unknown): TreeNodeMixin[]
---@field IsFlagSet fun(self: self, ...: unknown): unknown
---@field DeselectByPredicate fun(self: self, ...: unknown): unknown
---@field DeselectSelectedElements fun(self: self, ...: unknown): unknown
---@field ClearSelections fun(self: self, ...: unknown): unknown
---@field ToggleSelectElementData fun(self: self, ...: unknown): unknown
---@field SelectFirstElementData fun(self: self, predicate?: (fun(data: any): boolean))
---@field SelectNextElementData fun(self: self, ...: unknown): unknown
---@field SelectPreviousElementData fun(self: self, ...: unknown): unknown
---@field SelectOffsetElementData fun(self: self, ...: unknown): unknown
---@field SelectElementData fun(self: self, ...: unknown): unknown
---@field SelectElementDataByPredicate fun(self: self, ...: unknown): unknown
---@field SetElementDataSelected_Internal fun(self: self, ...: unknown): unknown
---@field Select fun(self: self, ...: unknown): unknown
---@field ToggleSelect fun(self: self, ...: unknown): unknown
SelectionBehaviorMixin = nil

---@class StatusBar
---@field Text FontString
---@field Icon Texture

---@class MoneyDenominationDisplayMixin
---@field amount? number
---@field showsZeroAmount? boolean
---@field formatter? fun(amount: number): number | string
---@field OnLoad fun(self: self, ...: unknown): unknown
---@field SetDisplayType fun(self: self, ...: unknown): unknown
---@field UpdateDisplayType fun(self: self, ...: unknown): unknown
---@field SetFontObject fun(self: self, ...: unknown): unknown
---@field GetFontObject fun(self: self, ...: unknown): unknown
---@field SetFontAndIconDisabled fun(self: self, ...: unknown): unknown
---@field SetFormatter fun(self: self, ...: unknown): unknown
---@field SetForcedHidden fun(self: self, ...: unknown): unknown
---@field IsForcedHidden fun(self: self, ...: unknown): unknown
---@field SetShowsZeroAmount fun(self: self, ...: unknown): unknown
---@field ShowsZeroAmount fun(self: self, ...: unknown): unknown
---@field ShouldBeShown fun(self: self, ...: unknown): unknown
---@field SetAmount fun(self: self, ...: unknown): unknown
---@field UpdateWidth fun(self: self, ...: unknown): unknown

---@class MoneyDenominationDisplayFrame: Frame, MoneyDenominationDisplayMixin
---@field Text FontString
---@field Icon Texture

---@class MoneyDisplayFrameMixin
---@field hideCopper boolean
---@field leftAlign boolean
---@field useAuctionHouseIcons boolean
---@field CopperDisplay MoneyDenominationDisplayFrame
---@field SilverDisplay MoneyDenominationDisplayFrame
---@field GoldDisplay MoneyDenominationDisplayFrame
---@field OnLoad fun(self: self, ...: unknown): unknown
---@field SetFontAndIconDisabled fun(self: self, ...: unknown): unknown
---@field SetFontObject fun(self: self, ...: unknown): unknown
---@field GetFontObject fun(self: self, ...: unknown): unknown
---@field UpdateAnchoring fun(self: self, ...: unknown): unknown
---@field SetAmount fun(self: self, amount: number)
---@field UpdateWidth fun(self: self, ...: unknown): unknown
---@field GetAmount fun(self: self): number
---@field SetResizeToFit fun(self: self, ...: unknown): unknown

---@class MoneyDisplayFrame: Frame, MoneyDisplayFrameMixin

---@class LargeMoneyInputFrameMixin
---@field OnLoad fun(self: self, ...: unknown): unknown
---@field SetNextEditBox fun(self: self, ...: unknown): unknown
---@field Clear fun(self: self, ...: unknown): unknown
---@field SetEnabled fun(self: self, ...: unknown): unknown
---@field SetAmount fun(self: self, amount: number)
---@field GetAmount fun(self: self): number
---@field SetOnValueChangedCallback fun(self: self, ...: unknown): unknown
---@field OnAmountChanged fun(self: self, ...: unknown): unknown

---@class LargeMoneyInputFrame: Frame, LargeMoneyInputFrameMixin

---@class TableBuilderElementMixin
---@field Init fun(self: self, ...: unknown): unknown
---@field Populate fun(self: self, ...: unknown): unknown

---@class TableBuilderCellMixin: TableBuilderElementMixin
---@field OnLineEnter fun(self: self, ...: unknown): unknown
---@field OnLineLeave fun(self: self, ...: unknown): unknown

---@class TableBuilderMixin
---@field rows table
---@field Init fun(self: self, ...: unknown): unknown
---@field GetDataProvider fun(self: self, ...: unknown): unknown
---@field SetDataProvider fun(self: self, ...: unknown): unknown
---@field GetDataProviderData fun(self: self, ...: unknown): unknown
---@field SetTableMargins fun(self: self, ...: unknown): unknown
---@field SetColumnHeaderOverlap fun(self: self, ...: unknown): unknown
---@field SetTableWidth fun(self: self, ...: unknown): unknown
---@field GetTableWidth fun(self: self, ...: unknown): unknown
---@field GetTableMargins fun(self: self, ...: unknown): unknown
---@field GetColumnHeaderOverlap fun(self: self, ...: unknown): unknown
---@field GetColumns fun(self: self, ...: unknown): unknown
---@field GetHeaderContainer fun(self: self, ...: unknown): unknown
---@field SetHeaderContainer fun(self: self, ...: unknown): unknown
---@field GetHeaderPoolCollection fun(self: self, ...: unknown): unknown
---@field EnumerateHeaders fun(self: self, ...: unknown): unknown
---@field ConstructHeader fun(self: self, ...: unknown): unknown
---@field Arrange fun(self: self, ...: unknown): unknown
---@field Reset fun(self: self, ...: unknown): unknown
---@field AddRow fun(self: self, ...: unknown): unknown
---@field RemoveRow fun(self: self, ...: unknown): unknown
---@field ArrangeCells fun(self: self, ...: unknown): unknown
---@field AddColumn fun(self: self, ...: unknown): unknown
---@field CalculateColumnSpacing fun(self: self, ...: unknown): unknown
---@field ArrangeHorizontally fun(self: self, ...: unknown): unknown
---@field ArrangeHeaders fun(self: self, ...: unknown): unknown

---@class ProfessionsTableCellTextMixin: TableBuilderCellMixin
---@field Text FontString
---@field SetText fun(self: self, text: string)

---@class ProfessionsCrafterTableCellItemNameMixin: TableBuilderCellMixin
---@field Icon Texture
---@field IconBorder Texture
---@field Text FontString

---@class ProfessionsCrafterTableCellItemNameFrame: Frame, ProfessionsCrafterTableCellItemNameMixin
---@field GetParent fun(self: self): ProfessionsCrafterOrderListElementMixin

---@class ProfessionsCrafterTableCellCommissionMixin: TableBuilderCellMixin
---@field TipMoneyDisplayFrame MoneyDisplayFrame
---@field RewardsContainer Frame
---@field RewardIcon Texture

---@class ProfessionsCrafterTableCellCommissionFrame: Frame, ProfessionsCrafterTableCellCommissionMixin
---@field GetParent fun(self: self): ProfessionsCrafterOrderListElementMixin

---@class ProfessionsTableBuilderMixin: TableBuilderMixin
---@field AddColumnInternal fun(self: self, ...: unknown): unknown
---@field AddUnsortableColumnInternal fun(self: self, ...: unknown): unknown
---@field AddFixedWidthColumn fun(self: self, ...: unknown): unknown
---@field AddFillColumn fun(self: self, ...: unknown): unknown
---@field AddUnsortableFixedWidthColumn fun(self: self, owner: Frame, padding?: number, width?: number, leftCellPadding?: number, rightCellPadding?: number, headerText?: string, cellTemplate?: string, ...: unknown): unknown
---@field AddUnsortableFillColumn fun(self: self, owner: Frame, padding?: number, fillCoefficient?: number, leftCellPadding?: number, rightCellPadding?: number, headerText?: string, cellTemplate?: string, ...: unknown): unknown

---@class ProfessionsCrafterOrderListRowData
---@field browseType number
---@field option CraftingOrderInfo
---@field pageFrame OrdersPage

---@class ProfessionsCrafterOrderListElementMixin: ProfessionsCrafterOrderListRowData
---@field OnLineEnter fun(self: self)
---@field OnLineLeave fun(self: self)
---@field OnUpdate fun(self: self)
---@field OnClick fun(self: self, button: "LeftButton" | "RightButton")
---@field Init fun(self: self, rowData: ProfessionsCrafterOrderListRowData)