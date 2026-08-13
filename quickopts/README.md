# Quick Opts

A compact settings panel for ArcheRage. Toggle common game options from one window instead of digging through the in-game Options UI.

## Features

- ESC menu button (**Quick Opts**, guide icon) to show or hide the window
- Drag to reposition; position and visibility are saved
- Close with the **X** in the top-right corner
- Rows always display the live game setting, including changes made in the in-game Options window

## Settings

| Row | What it does |
| --- | --- |
| **Personal Portal** | Use only your portals (**Mine**) or any portal (**All**) |
| **Mount Own** | Mount only your mounts (**Mine**) or allow any mounts (**All**) |
| **Auto Target** | Enable or disable auto-selecting a target when using skills |
| **Gear Status** | Set gear privacy to **Public** or **Private** |
| **Skill Queue** | Cycle skill queue: **Disabled**, **Limited** (no combo), **Full** |

Click a row button to cycle or toggle that option. Chat confirms the change.

## Usage

1. Install the `globals` folder (required).
2. Enable **quickopts** on the character select Player UI screen.
3. Open the panel from the ESC menu, or restore it if it was left visible.
4. Click a setting to change it. The same values stay in sync if you change them in the game Options UI.

Do not run the standalone `skillqueue` addon at the same time. Both would fight over the same ESC menu slot.

## Files

Each setting lives in its own file and registers a row with the hub in `ui.lua`. Add another option by creating a new file and listing it in `toc.g` after `ui.lua`.
