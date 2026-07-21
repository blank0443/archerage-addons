# Unit Tracker

Addon for tracking if players are friendly or hostile by adding to list.

## Features

- Separate **Friendly** and **Hostile** lists, saved between sessions
- Tracks by player name and unitId so renamed players can still be matched
- Per-player notes with a sticky-note editor and a two-line **yellow** preview on the main window
- Saves your current world coordinates when a player is added to either list
- Note window **M** button opens the world map and marks that saved location (disabled if no coordinates)
- Auto-applies hostile markers when a listed hostile is targeted
- Auto-opens when you take verified damage from another player (not NPCs)
- Auto-opens the main window when you select a **hostile** player who has notes (so the preview is visible)
- **Opts** panel: view lists, export to file, bind Friendly/Hostile hotkeys (with clear)
- Draggable windows with saved positions

## Usage

1. Click the **Unit Tracker** launch button (or let incoming player damage / a noted hostile open it).
2. Target a player → **Friendly** or **Hostile** to add them (your position is stamped at that moment).
3. Click the note preview to edit that player’s note → **Save**. Use **M** to open the map at the add location when available.
4. Open **Opts** for list management, export, and hotkey binding.

A player can only be on one list. Adding them to the other list moves them. Friendlies show in dark green; hostiles in red.

## Opts

| Button | Action |
|--------|--------|
| **View List** | Tabbed Friendly/Hostile browser with name filter, sort, and remove-with-confirm |
| **Export** | Write lists, notes, and coordinates to a dated `.txt` in the addon folder |
| **Friendly** / **X** | Bind “add target as friendly”, or clear that hotkey |
| **Hostile** / **X** | Bind “add target as hostile”, or clear that hotkey |

### View List

- **Friendly** / **Hostile** tabs with entry counts
- Name filter box
- **Sort** cycles: Recent → A–Z → Notes (players with notes first)
- Click a name to open its note; remove with confirm

### Hotkeys

While binding: press the desired key (optional Ctrl/Shift/Alt), or **Esc** to cancel. Buttons show the current binding, e.g. `Friendly [F5]`. Reusing a key on the other list clears the previous binding. Use the **X** beside a hotkey button to clear it. Hotkeys work with the tracker window closed.

## Notes

- Notes are keyed to the tracked player and persist with the lists.
- The main window preview shows up to two lines in yellow; click it to open the full editor.
- The note window title is the player name; the date added appears under the input.
- **Enter** inserts a single line break in the note editor.
- **M** (left of Save) opens the world map at the coordinates captured when the player was added. If no coordinates exist, the button stays disabled and the map does not open.

## Locations

When you add someone to Friendly or Hostile, the addon stores your local player position (world/local coords + zone group) on that entry. Locations are kept across list moves and key remaps when a fresh capture is unavailable, and are included in saves and exports.

## Export

- Writes into the addon folder (loaded source directory, with `Documents/Addon` fallbacks).
- Filename: `export_unit_tracker_YYYY-MM-DD.txt`
- If that file already exists for the day, appends unix epoch: `export_unit_tracker_YYYY-MM-DD_1784625937.txt`
- Each row includes name, unitId, date added, note, and coordinates when available (`x, y, z | zone N`)
- On success, a short on-screen confirmation shows **Export successful.** plus the full path, then disappears after 4 seconds

## Persistence

| Data | Storage key |
|------|-------------|
| Friendly / Hostile lists + notes + locations | `dpsBasicsUnitTrackerLists` |
| Hotkey bindings | `dpsBasicsUnitTrackerHotkeys` |
| Window positions | `dpsBasicsUnitTracker*Position` keys |
