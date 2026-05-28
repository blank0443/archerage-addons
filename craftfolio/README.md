# Craft Calculator

Craft Calculator is an ArcheRage addon that provides an in-game crafting folio search and material cost calculator. It adds a draggable `Craft Calculator` launcher button that opens a searchable crafting window, letting you look up folio items and inspect the materials needed for supported recipes without leaving the game.

## Features

- Search the bundled Crafting Folio index by item or recipe name.
- Shows up to 80 matching recipes, with 10 visible results in the main window.
- Displays recipe details such as output quantity, workbench, vocation, and recipe ID when that data is available.
- Opens a `Craft Requirements` window when a recipe is selected.
- Calculates required direct materials for a target output quantity.
- Expands craftable ingredients into `Base Materials (Raw)` when dependency data is bundled.
- Validates quantity input against recipe output batch size.
- Shows item icons for recipe outputs and materials when icon paths are available.
- Lets you enter gold, silver, and copper unit costs for materials.
- Calculates direct material cost and base material cost separately.
- Lets you enter a sale price per finished item to estimate direct and base profit margins.
- Main window can be dragged and resized from its corners.
- Launcher position, window position, window size, and open/collapsed state are saved between sessions.

## Usage

1. Click the `Craft Calculator` launcher button.
2. Type at least two characters in the `Craft Folio Search` box.
3. Click a search result to open its `Craft Requirements` window.
4. Change the `Quantity` field to scale the material list.
5. Enter material unit costs to calculate total cost.
6. Enter `Sale/unit` to calculate profit margin.

## Data Files

- `folio_index.lua` contains the searchable recipe index generated from the ArcheRage crafting folio.
- `folio_data.lua` contains detailed material trees for recipes that can be fully calculated.
- Recipes that only exist in the index can still be searched, but they will show that no bundled material data is available.

## Requirements

The addon depends on the shared `globals` addon files loaded by `toc.g`. Keep the `globals` folder installed alongside this addon in the ArcheRage addon directory.
