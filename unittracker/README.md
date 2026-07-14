# Unit Tracker

Friendly and hostile player lists for open-world PvP. Part of the `dpsbasics` addon (`unit_tracker.lua`).

## Requirements

Requires the shared [`globals`](https://github.com/Schiz-n/ArcheRage-addons/tree/master/globals) folder next to `dpsbasics`.

## Features

- Separate **Friendly** and **Hostile** lists, saved between sessions
- Tracks by player name and unitId so renamed players can still be matched
- Per-player notes with a sticky-note editor and a two-line preview on the main window
- Auto-applies hostile markers when a listed hostile is targeted
- Auto-opens when you take verified damage from another player (not NPCs)
- **Opts** panel: view lists, export to file, bind Friendly/Hostile hotkeys
- Draggable windows with saved positions

## Usage

1. Click the **Unit Tracker** launch button (or let incoming player damage open it).
2. Target a player → **Friendly** or **Hostile** to add them.
3. Click the note preview to edit that player’s note → **Save**.
4. Open **Opts** for list management, export, and hotkey binding.

A player can only be on one list. Adding them to the other list moves them. Friendlies show in dark green; hostiles in red.

## Opts

| Button | Action |
|--------|--------|
| **View List** | Browse Friendly/Hostile entries; remove with confirm |
| **Export** | Write lists and notes to a dated `.txt` file |
| **Friendly** | Click, then press a key to bind “add target as friendly” |
| **Hostile** | Click, then press a key to bind “add target as hostile” |

While binding: press the desired key (optional Ctrl/Shift/Alt), or **Esc** to cancel. Buttons show the current binding, e.g. `Friendly [F5]`. Reusing a key on the other list clears the previous binding. Hotkeys work with the tracker window closed.

## Notes

- Notes are keyed to the tracked player and persist with the lists.
- The main window preview shows up to two lines; click it to open the full editor.
- The note window title is the player name; the date appears under the input.

## Persistence

| Data | Storage key |
|------|-------------|
| Friendly / Hostile lists + notes | `dpsBasicsUnitTrackerLists` |
| Hotkey bindings | `dpsBasicsUnitTrackerHotkeys` |
| Window positions | `dpsBasicsUnitTracker*Position` keys |

Export files use the prefix `dpsbasics_unit_tracker_export_` plus the current date.
