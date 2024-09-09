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
