# dpsbasics

Combat and targeting helpers for open-world PvP and party play. Includes target role display, Unit Tracker (friendly/hostile lists), Role Dancer alerts, and a Songcraft passive timer.

## Requirements

Requires the shared [`globals`](https://github.com/Schiz-n/ArcheRage-addons/tree/master/globals) folder next to this addon.

## Modules

| File | Purpose |
|------|---------|
| `dpsbasics.lua` | Target class/role icons and shield indicators |
| `unit_tracker.lua` | Friendly/hostile player lists, notes, markers, hotkeys |
| `roledancer.lua` | Role / spell-dance related UI helpers |
| `passive_tracker.lua` | Sustained Rhythm (Songcraft) timer alert |

## Unit Tracker

Track players you care about in the open world: mark them friendly or hostile, keep per-player notes, and bind hotkeys so adding someone is one keypress.

### Features

- Separate **Friendly** and **Hostile** lists (persisted between sessions).
- Name + unitId tracking so renamed players can still be recognized.
- Per-player notes with a sticky-note editor and preview on the main window.
- Hostile target markers applied automatically when a listed hostile is selected.
- Auto-opens when you take verified damage from another player (not NPCs).
- **Opts**: view full lists, export to a text file, and bind Friendly/Hostile hotkeys.
- Draggable windows; positions are saved.

### Usage

1. Click the **Unit Tracker** launch button (or open it when incoming player damage auto-opens the window).
2. Target a player, then click **Friendly** or **Hostile** (or use your bound hotkeys).
3. Click the note preview to open the player note window; **Save** stores the note.
4. Open **Opts** for:
   - **View List** — browse / remove players from either list
   - **Export** — write lists + notes to a dated text file
   - **Friendly** / **Hostile** — click a button, then press a key (optional Ctrl/Shift/Alt) to bind that hotkey; **Esc** cancels

Listed friendlies show in dark green; hostiles show in red. The same player can only be on one list at a time — adding them to the other list moves them.

### Hotkeys

Hotkeys use the game’s binding API (same approach as combatcloset):

1. Opts → click **Friendly** or **Hostile**
2. Press the key you want (e.g. `F5` or `Ctrl-F`)
3. Binding is saved and works even when the Unit Tracker window is closed

Reusing a key on the other list clears the previous binding.
