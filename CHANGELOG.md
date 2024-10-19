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
