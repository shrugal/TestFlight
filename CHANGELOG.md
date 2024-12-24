Version 4.11

- Update ToC version for patch 11.0.7
- Fix game freeze when generating min cost allocations for some orders
- Fix concentration cost increasing when adding extra skill
- Fix extra skill spinner not working when applying concentration
- Fix error when creating new order
- Fix weight/skill tooltip

Version 4.10

- Add filter settings for max cost per knowledge and artisan currency to NPC orders page
- Make "Track All" only track unprofitable orders if they give enough knowledge or currency
- Update concentration cost when adding extra skill in experimentation mode
- Allow enabling concentration without required currency in experimentation mode
- Show correct concentration cost for optimized unclaimed orders
- Track concentration state and reapply it when opening the recipe again
- Hide optimization buttons in linked profession windows
- Fix not updating UIs when profession traits or buff charges change in experimentation mode
- Fix not updating UIs when adding extra skill in experimentation mode
- Fix error when optmizing recipe with bonus skill slot unlocked
- Fix result quality sometimes being off by one when optimizing
- Fix recipes without crafting operation infos
- Internal: Optimize orders in order list asynchronously
- Internal: Improve optimization and operation caching throughout

Version 4.09

- Optimize unclaimed orders for max. profit instead of min. cost
- Ignore locked finishing reagent slots when optimizing reagents
- Include tradable finishing reagents that provide extra skill in optimization
- Don't replace non-tradable finishing reagents when optimizing
- Always clear tradable finishing reagents before optimizing, regardless of method
- Include ingenuity in profit per concentration calculation
- Show profit change per point for resourcefulness, multicraft and ingenuity in tooltips
- Show cost breakdown per reagent in cost tooltip
- Disable NPC order reward icon replacement if "No Mats; No Make" is also installed
- Fix trying to get price from OribosExchange for BoP items
- Fix trying to set unlearned order recipe name color when name isn't loaded yet
- Fix tracking order if customer order form is open when starting to track a recipe
- Internal: Crafting form code refactoring

Version 4.08

- Add track order checkboxes to order list
- Add shift-clicking order list entries to track them
- Add NPC reward item icons to order list
- Add checkbox to toggle tracking of all listed orders below order list
- Add button to start next tracked order below order list
- Add showing projected profit instead of tip amount in order list
- Add marking orders with unlearned recipes in order list
- Add pressing create button again to confirm dialog about providing own reagents
- Automatically untrack recipes when finishing all tracked crafts and orders
- Fix hiding recipes that don't require concentration for max quality when sorting by profit per concentration
- Fix allocating reagents on already crafted orders
- Fix complete order button positioning
- Fix provided reagent detection for recraft orders
- Fix sometimes not updating provided modifying reagents while creating an order
- Fix reagent price not updating while creating an order after tracking and untracking a recipe
- Fix untracking all orders of a recipe when only the recraft or non-recraft variant was untracked
- Fix reagents tracker not showing if a recraft order for a socketed item was tracked
- Fix amount spinner showing while creating a recraft order

Version 4.07

- Add tracking multiple orders of the same recipe
- Properly handle finishing reagents that change resourcefulness/multicraft yield
- Improve profit (~33%) and profit per concentration (~66%) optimization performance
- Updated reagent, perk and recipe data

Version 4.06

- Add Auctionator search button to reagents tracker
- Add cost per concentration optimization method
- Add input to set max. marginal cost per point when using cost per concentration
- Add showing reagent costs in customer order form
- Recalculate optimal allocations when prices from price source addon change
- Clear recipe sort caches when resetting sort order
- Abbreviate long recipe names to prevent line breaks in the recipe tracker
- Fix sometimes using wrong recipe allocation when starting to track a recipe
- Fix not updating scanning progress when many recipes without profit are skipped
- Fix reagents tracker sometimes not hiding when all recipes are untracked
- Fix price source command shorthand

Version 4.05

- Fix error on recipes without quality
- Fix reagents tracker positioning when not all items are loaded immediately
- Fix reagents tracker running some updates when it's disabled
- Internal: Improve background task scheduling

Version 4.04

- Fix showing recipe sort option without a pricesource
- Fix error on load if stock professions addons aren't loaded

Version 4.03

- Update for patch 11.0.5
- Add scanning and sorting recipe list by optimization targets
- Add showing optimization target prices in sorted recipe list
- Fix ignoring provided reagents when tracking unclaimed orders

Version 4.02

- Fix optimize buttons not disabling during optimization process
- Fix considering patron order results as usable reagents
- Fix listing provided basic order reagents as missing

Version 4.01

- Fix profit per concentration optimization for recipes without concentration cost
- Internal: Add error stacktraces for promises

Version 4.0

- Added ability to optimize for profit and profit per concentration, incl. most finishing reagents
- Added dropdown to select optimization target next to optimize buttons
- Optimization is now asynchronous, to not drop frames
- Optimize buttons are now disabled during optimization
- Made addon data available via global "TestFlight" variable
- Fix changing quality while applying concentration
- Internal: Major optimization code refactoring

Version 3.11

- Fix error when clicking on reagents in the recipe tracker

Version 3.10

- Added checkbox to toggle order tracking next to the recipe tracking checkbox
- Show optimization button for crafts without qualities but with quality reagents
- Allow tracked recipe amounts to go to 0 intead of stopping at 1
- Track and show result quality in recipe tracker
- Load optimal allocations for tracked recipes on login
- Show missing instead of owned reagent count for missing reagents in reagents tracker
- Show reagents that are outputs of tracked recipes in separate reagents tracker category
- Handle clicks on crafted reagents in reagents tracker as clicks on the corresponding recipe
- Set optimal allocation when accepting tracked orders
- Fix resetting customer provided reagents when disabling experimentation mode in orders form
- Fix setting allocations for tracked recipes on forms with different order state
- Fix missing basic reagents when toggling experimentation mode
- Internal: Major GUI code refactoring
- Internal: Reworked refresh/update logic to use CallbackRegistry in most cases

Version 3.09

- Fix reagents tracker showing missing reagents as provided when creating public orders

Version 3.08

- Only ever track one order per recipe
- Take customer order reagents provided by crafter into account
- Fix updating reagents tracker after tracked recipe amount changes
- Fix customer order form tracked recipe amount input
- Fix reagents tracker for customer orders form
- Fix reagents in tracker not being clickable sometimes

Version 3.07

- Fix error when hiding objective tracker lines

Version 3.06

- Remember all tracked orders, instead of just the claimed order
- Use optimal allocation for min. crafting order quality when tracking unclaimed orders
- Fix more errors caused by missing recipes
- Fix reagents tracker not showing when no reagents are missing

Version 3.05

- Fix some errors caused by missing recipes or tracked recipe amounts
- Fix reagents tracker positioning if not all blocks can be shown
- Don't show reagents tracker if missing reagents block can't be shown

Version 3.04

- Fix crafting reagents flyout window
- Fix WorldQuestTracker objective tracker compatibility
- Remove recipe tracker Update hook for real this time

Version 3.03

- Added objective tracker module showing reagents for all tracked recipes
- Added command to enable/disable reagents tracker
- Restore previous reagent allocations when navigating to tracked recipes
- Made tracked recipe amounts character specific
- Cleanup modified objective tracker lines to prevent taint
- Use secure hooks for recipe tracker bypass to prevent taint
- Some more refactoring

Version 3.02

- Added profit per concentration point to concentration tooltip
- Added tradable order rewards to profit calculation
- Added price sources as optional dependencies
- Updated specialization data

Version 3.01

- Added more price sources: Auctionator, RECrystallize, OribosExchange, Auctioneer
- Added command to set preferred price source
- Use item link to get result item prices for better accuracy
- Fix addon load handling order

Version 3.0

- Add multicraft, resourcefulness and profit calculations
- Add profit line and tooltip to tradable crafts and crafting orders
- Remove now redundant tooltip hooks
- Fix AllocationsMixin creation to not require a craft with reagents to be opened
- Fix crafting order allocation caches not invalidating correctly
- Some refactoring and simplifications

Version 2.05

- Show cost line and tooltip for reachable qualities for non-fulfillable orders
- Fix skill calculation for orders with basic materials provided
- Fix tooltip post call for when the passed tooltip is nil

Version 2.04

- Added option to show reagent craft weight and provided skill
- Some minor refactoring

Version 2.03

- Added support for order crafting form
- Improve gatheing recipe handling
- Bugfixes galore

Version 2.02

- Improve crafting cost calcuation
- Improve salvage operation handling
- Always disable debugging output in production builds
- Only show optimization buttons for quality crafts

Version 2.01

- Updated for patch 11.0.2
- Updated reagent data
- Fixed some tooltip texts
- Some minor refactoring

Version 2.0

- Major code refactoring
- Added getting reagent costs from TSM if installed
- Added showing crafting cost on the crafting page
- Added showing costs of optimal reagent allocations for reachable crafting qualities
- Added setting optimal reagent allocation for current, previous or next crafting quality
- Changed skill input to show extra skill instead of resulting total skill
- Improved clearing reagent slots when disabling experimentation mode

Version 1.12

- Fixed UI update loop after changing extra skill
- Removed some debug output

Version 1.11

- Removed anything related to the old inspiration system
- Fixed item icon and tooltip not updating when changing crafting skill
- Fixed recipe tracker entries not changing completion state and color
- Fixed removing existing recraft reagents when disabling experimentation mode
- Fixed more bugs caused by patch 11.0 changes

Version 1.10

- Updated for patch 11.0

Version 1.09

- Updated for patch 10.2
- Fixed not applying UI changes when the professions UI is already loaded

Version 1.08

- Updated for patch 10.1.5

Version 1.07

- Updated ToC version for patch 10.1
- Improve crafting tracking to update tracked recipe amounts
- Fix optional reagents override
- Fix clearing optional reagents when disabling experimentation mode
- Fix recipe objective tracker

Version 1.06

- Fix nil error on UI refresh without recraft data

Version 1.05

- Update ToC version for patch 10.0.5
- Add chat command to set recraft item by item link
- Fix experiment checkbox placement in order UI
- Fix not clearing optional reagent slots in order UI
- Fix clearing optional slots if crafting UI hasn't been opened yet

Version 1.04

- Fix breaking crafts without quality

Version 1.03

- Exempt recipe tracker from item count override
- Added ability to show result with inspiration bonus
- Added ability to track multiple crafts of a recipe
- Added searching for reagents in crafting window or AH when clicking on them in the tracker

Version 1.02

- Fix breaking pre dragonflight crafting
- Fix for skill being higher than difficulty

Version 1.01

- Fix missing library import
- Add ability to customize crafting skill level

Version 1.0

- Initial release
