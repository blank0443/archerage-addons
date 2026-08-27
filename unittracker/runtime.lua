if API_TYPE == nil then
	ADDON:ImportAPI(8)
	X2Chat:DispatchChatMessage(
		CMF_SYSTEM,
		"Globals folder not found. Please install it at https://github.com/Schiz-n/ArcheRage-addons/tree/master/globals"
	)
	return
end

ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.X2_EDITBOX)
if OBJECT_TYPE.EDITBOX_MULTILINE ~= nil then
	ADDON:ImportObject(OBJECT_TYPE.EDITBOX_MULTILINE)
end
if OBJECT_TYPE.WORLD_MAP ~= nil then
	ADDON:ImportObject(OBJECT_TYPE.WORLD_MAP)
end

ADDON:ImportAPI(API_TYPE.UNIT.id)
if API_TYPE.FACTION ~= nil then
	ADDON:ImportAPI(API_TYPE.FACTION.id)
end
if API_TYPE.HOTKEY ~= nil then
	ADDON:ImportAPI(API_TYPE.HOTKEY.id)
end
if API_TYPE.INPUT ~= nil then
	ADDON:ImportAPI(API_TYPE.INPUT.id)
end
if API_TYPE.CHAT ~= nil then
	ADDON:ImportAPI(API_TYPE.CHAT.id)
end
if API_TYPE.MAP ~= nil then
	ADDON:ImportAPI(API_TYPE.MAP.id)
end

local UT = _G.__UNIT_TRACKER
if UT == nil then
	return
end

local previousRuntime = _G.__UNIT_TRACKER_RUNTIME

-- Unit Tracker: friendly and hostile player lists for open-world PvP.



if previousRuntime ~= nil then
	previousRuntime.active = false
	if previousRuntime.window ~= nil then
		previousRuntime.window:Show(false)
	end
	if previousRuntime.eventWindow ~= nil then
		previousRuntime.eventWindow:Show(false)
	end
	if previousRuntime.viewWindow ~= nil then
		previousRuntime.viewWindow:Show(false)
	end
	if previousRuntime.optsWindow ~= nil then
		previousRuntime.optsWindow:Show(false)
	end
	if previousRuntime.noteWindow ~= nil then
		previousRuntime.noteWindow:Show(false)
	end
	if previousRuntime.exportNotifyWindow ~= nil then
		previousRuntime.exportNotifyWindow:Show(false)
	end
	if previousRuntime.launchButton ~= nil then
		previousRuntime.launchButton:Show(false)
	end
end

local runtime = {
	active = true,
	loading = false,
	window = nil,
	viewWindow = nil,
	optsWindow = nil,
	noteWindow = nil,
	eventWindow = nil,
	exportNotifyWindow = nil,
	exportNotifyHideAt = 0,
	launchButton = nil,
	friendly = {},
	hostile = {},
	notes = {},
	friendlyOrder = {},
	hostileOrder = {},
	viewRows = {
		friendly = {},
		hostile = {},
	},
	removeConfirm = nil,
	hotkeys = {
		friendly = "",
		hostile = "",
	},
	hotkeysActive = {
		friendly = nil,
		hostile = nil,
	},
	hotkeyCapture = nil,
	hotkeyCaptureInput = nil,
	settings = {
		autoOpenDamage = true,
		autoOpenListedTarget = true,
	},
	friendlyPage = 1,
	hostilePage = 1,
	viewTab = "friendly",
	viewSort = "recent",
	viewFilter = "",
	viewFilterState = nil,
	viewTotalPages = 1,
	viewPollElapsed = 0,
	addNameText = "",
	addNameState = nil,
	addNamePollElapsed = 0,
	markersByKey = {},
	keysByMarker = {},
	unitIdKeys = {},
	markerWriteAttempts = {},
	currentTarget = nil,
	updateElapsed = 0,
	lastMarkedKey = nil,
	lastMarkedMarker = nil,
	lastMarkTime = 0,
	lastMarkerWriteTime = -UT.timing.MARK_RETRY_SECONDS,
	editboxPollElapsed = 0,
	noteTargetKey = nil,
	noteText = "",
	noteFactionPicker = false,
	noteInputState = nil,
	noteInput = nil,
	recentPlayerDamageSourceTimes = {},
	pendingDamageSourceTimes = {},
	lastAutoOpenTime = -UT.timing.AUTO_OPEN_COOLDOWN_SECONDS,
	listsSavePending = false,
	lastListsSaveAt = 0,
	lastSourceCachePruneAt = 0,
	lastRefreshTargetKey = nil,
	lastRefreshTargetUnitId = nil,
	lastRefreshListName = nil,
	lastRefreshNote = "",
	markerScanCache = { key = nil, unitId = nil, index = nil, shouldWrite = false, at = 0 },
	localPlayerFaction = "",
	localPlayerFactionRaw = "",
	localFactionReady = false,
	pirateFactionRaws = {},
	pirateFactionLoaded = false,
	guildFactions = {},
	guildFactionsLoaded = false,
	mapOverlay = {
		pending = nil,
		elapsed = 0,
		attempts = 0,
	},
}
_G.__UNIT_TRACKER_RUNTIME = runtime

runtime.faction = runtime.faction or {}
runtime.map = runtime.map or {}
UT.runtime = runtime
