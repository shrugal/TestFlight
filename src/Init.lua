---@diagnostic disable: missing-fields

---@class TestFlight
local Addon = select(2, ...)

---@type Util
Addon.Util = {}
---@type Prices
Addon.Prices = {}
---@type Recipes
Addon.Recipes = {}
---@type Reagents
Addon.Reagents = {}
---@type Orders
Addon.Orders = {}
---@type Optimization
Addon.Optimization = {}

---@class GUI
Addon.GUI = {
    ObjectiveTracker = {
        ---@type GUI.ObjectiveTracker.ProfessionsTrackerModule
        ProfessionsTrackerModule = {},
        ---@type GUI.ObjectiveTracker.RecipeTracker
        RecipeTracker = {},
        ---@type GUI.ObjectiveTracker.ReagentsTracker
        ReagentsTracker = {},
        ---@type GUI.ObjectiveTracker.WorldQuestTracker
        WorldQuestTracker = {},
    },

    RecipeForm = {
        ---@type GUI.RecipeForm.AmountForm
        AmountForm = {},
        ---@type GUI.RecipeForm.RecipeForm
        RecipeForm = {},
        ---@type GUI.RecipeForm.RecipeCraftingForm
        RecipeCraftingForm = {},
        ---@type GUI.RecipeForm.CraftingForm
        CraftingForm = {},
        ---@type GUI.RecipeForm.OrdersForm
        OrdersForm = {},
        ---@type GUI.RecipeForm.CustomerOrderForm
        CustomerOrderForm = {},
    },

    ---@type GUI.CraftingPage
    CraftingPage = {},
    ---@type GUI.OrdersView
    OrdersView = {},
    ---@type GUI.ItemFlyout
    ItemFlyout = {}
}