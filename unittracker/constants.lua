-- Unit Tracker shared bag + constants
_G.__UNIT_TRACKER = _G.__UNIT_TRACKER or {}
local UT = _G.__UNIT_TRACKER

UT.persist = {
	SAVE_KEY = "unitTrackerLists",
	HOTKEY_SAVE_KEY = "unitTrackerHotkeys",
	POSITION_KEY = "unitTrackerPosition",
	VIEW_POSITION_KEY = "unitTrackerViewPosition",
	NOTE_POSITION_KEY = "unitTrackerNotePosition",
	OPTS_POSITION_KEY = "unitTrackerOptsPosition",
	SETTINGS_KEY = "unitTrackerSettings",
	LOCAL_FACTION_KEY = "unitTrackerLocalFaction",
	PIRATE_FACTION_KEY = "unitTrackerPirateFactions",
	GUILD_FACTION_KEY = "unitTrackerGuildFactions",
	IMPORT_DONE_KEY = "unitTrackerImportedFromFile",
}

UT.timing = {
	TARGET_REFRESH_SECONDS = 0.2,
	MARK_RETRY_SECONDS = 1.0,
	PLAYER_DAMAGE_SOURCE_CACHE_SECONDS = 10.0,
	AUTO_OPEN_COOLDOWN_SECONDS = 2.0,
	LIST_SAVE_DEBOUNCE_SECONDS = 1.0,
	SOURCE_CACHE_PRUNE_SECONDS = 5.0,
	EDITBOX_POLL_SECONDS = 0.12,
}

UT.markerCfg = {
	HOSTILE_MARKER_INDEX = 12,
	NUMBERED_HOSTILE_MARKERS = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
}

UT.ui = {
	WINDOW_WIDTH = 242,
	WINDOW_HEIGHT = 138,
	VIEW_WINDOW_WIDTH = 306,
	VIEW_ROW_HEIGHT = 22,
	VIEW_ROWS_PER_PAGE = 10,
	VIEW_REMOVE_BUTTON_WIDTH = 24,
	VIEW_CONFIRM_BUTTON_WIDTH = 22,
	VIEW_CONFIRM_GAP = 2,
	PAGE_BUTTON_WIDTH = 32,
	PAGE_BUTTON_HEIGHT = 20,
	PAGE_LABEL_WIDTH = 48,
	NOTE_WINDOW_WIDTH = 208,
	NOTE_WINDOW_HEIGHT = 198,
	OPTS_WINDOW_WIDTH = 170,
	OPTS_WINDOW_HEIGHT = 228,
	NOTE_PREVIEW_LINE_HEIGHT = 16,
	NOTE_PREVIEW_TOP = 30,
	NAME_INPUT_TOP = 62,
	NAME_INPUT_HEIGHT = 22,
	BUTTON_ROW_Y = 90,
	PADDING = 10,
	BUTTON_WIDTH = 70,
	BUTTON_HEIGHT = 24,
	BUTTON_GAP = 6,
	NOTE_INPUT_TOP = 32,
	NOTE_DATE_LABEL_HEIGHT = 14,
	NOTE_AFTER_DATE_GAP = 4,
}
local ui = UT.ui
UT.ui.VIEW_ROW_ACTION_WIDTH = (ui.VIEW_CONFIRM_BUTTON_WIDTH * 2) + ui.VIEW_CONFIRM_GAP
UT.ui.NOTE_PREVIEW_WIDTH = ui.WINDOW_WIDTH - 20
UT.ui.NOTE_PREVIEW_HEIGHT = ui.NOTE_PREVIEW_LINE_HEIGHT * 2
-- Single tabbed list: title(38) + tabs(28) + filter/sort(28) + header(22) = 116 top,
-- then the rows, then a bottom padding.
UT.ui.VIEW_HEIGHT = 114 + (ui.VIEW_ROWS_PER_PAGE * ui.VIEW_ROW_HEIGHT) + ui.PADDING
-- Sticky-note body: equal side padding, date under input, compact footer.
UT.ui.NOTE_INPUT_SIDE_PADDING = ui.PADDING
UT.ui.NOTE_INPUT_LEFT = ui.NOTE_INPUT_SIDE_PADDING
UT.ui.NOTE_INPUT_WIDTH = ui.NOTE_WINDOW_WIDTH - (ui.NOTE_INPUT_SIDE_PADDING * 2)
UT.ui.NOTE_INPUT_HEIGHT = ui.NOTE_WINDOW_HEIGHT
	- ui.NOTE_INPUT_TOP
	- ui.NOTE_DATE_LABEL_HEIGHT
	- ui.NOTE_AFTER_DATE_GAP
	- ui.BUTTON_HEIGHT
	- ui.PADDING


-- Single source of truth for the Friendly (green) and Hostile (red) text colors.
-- Matches the main Unit Tracker window's Friendly/Hostile buttons; change here to
-- recolor every Friendly/Hostile label, tab, and button consistently.
UT.LIST_COLORS = {
	friendly = { 0.05, 0.42, 0.12, 1 },
	hostile = { 1, 0.35, 0.35, 1 },
	guild = { 0.35, 0.7, 1, 1 },
	pirate = { 0.90196, 0.54510, 0.72941, 1 },
	sameFaction = { 0.09412, 0.81569, 0.14510, 1 },
	unknown = { 1.0, 0.55, 0.15, 1 },
}

UT.listSave = UT.listSave or {}
UT.hotkeys = UT.hotkeys or {}
UT.settings = UT.settings or {}
UT.listView = UT.listView or {}
