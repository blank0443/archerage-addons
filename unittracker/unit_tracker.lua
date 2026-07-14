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

ADDON:ImportAPI(API_TYPE.UNIT.id)
if API_TYPE.TEAM ~= nil then
	ADDON:ImportAPI(API_TYPE.TEAM.id)
end

local SAVE_KEY = "dpsBasicsUnitTrackerLists"
local LEGACY_SAVE_KEY = "dpsBasicsPlayerTrackerLists"
local POSITION_KEY = "dpsBasicsUnitTrackerPosition"
local LEGACY_POSITION_KEY = "dpsBasicsPlayerTrackerPosition"
local VIEW_POSITION_KEY = "dpsBasicsUnitTrackerViewPosition"
local LEGACY_VIEW_POSITION_KEY = "dpsBasicsPlayerTrackerViewPosition"
local NOTE_POSITION_KEY = "dpsBasicsUnitTrackerNotePosition"
local LEGACY_NOTE_POSITION_KEY = "dpsBasicsPlayerTrackerNotePosition"
local OPTS_POSITION_KEY = "dpsBasicsUnitTrackerOptsPosition"
local HOSTILE_MARKER_INDEX = 12
local NUMBERED_HOSTILE_MARKERS = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
local TARGET_REFRESH_SECONDS = 0.2
local MARK_RETRY_SECONDS = 1.0
local PLAYER_NAME_REFRESH_SECONDS = 10.0
local PLAYER_DAMAGE_SOURCE_CACHE_SECONDS = 10.0
local AUTO_OPEN_COOLDOWN_SECONDS = 2.0

local WINDOW_WIDTH = 242
local WINDOW_HEIGHT = 112
local EXPORT_FILE_PREFIX = "dpsbasics_unit_tracker_export_"
local VIEW_WINDOW_WIDTH = 306
local VIEW_ROW_HEIGHT = 22
local VIEW_ROWS_PER_PAGE = 5
local VIEW_SECTION_GAP = 6
local VIEW_SECTION_HEADER_HEIGHT = 22
local VIEW_REMOVE_BUTTON_WIDTH = 24
local VIEW_CONFIRM_BUTTON_WIDTH = 22
local VIEW_CONFIRM_GAP = 2
local VIEW_ROW_ACTION_WIDTH = (VIEW_CONFIRM_BUTTON_WIDTH * 2) + VIEW_CONFIRM_GAP
local PAGE_BUTTON_WIDTH = 32
local PAGE_BUTTON_HEIGHT = 20
local PAGE_LABEL_WIDTH = 48
local NOTE_WINDOW_WIDTH = 208
local NOTE_WINDOW_HEIGHT = 198
local OPTS_WINDOW_WIDTH = 170
local OPTS_WINDOW_HEIGHT = 106
local NOTE_PREVIEW_WIDTH = WINDOW_WIDTH - 20
local NOTE_PREVIEW_LINE_HEIGHT = 16
local NOTE_PREVIEW_HEIGHT = NOTE_PREVIEW_LINE_HEIGHT * 2
local NOTE_PREVIEW_TOP = 30
local PADDING = 10
local VIEW_HEIGHT = 38
	+ ((VIEW_SECTION_HEADER_HEIGHT + (VIEW_ROWS_PER_PAGE * VIEW_ROW_HEIGHT) + VIEW_SECTION_GAP) * 2)
	+ PADDING
local BUTTON_WIDTH = 70
local BUTTON_HEIGHT = 24
local BUTTON_GAP = 6
-- Sticky-note body: equal side padding, date under input, compact footer.
local NOTE_INPUT_SIDE_PADDING = PADDING
local NOTE_INPUT_LEFT = NOTE_INPUT_SIDE_PADDING
local NOTE_INPUT_WIDTH = NOTE_WINDOW_WIDTH - (NOTE_INPUT_SIDE_PADDING * 2)
local NOTE_INPUT_TOP = 32
local NOTE_DATE_LABEL_HEIGHT = 14
local NOTE_AFTER_DATE_GAP = 4
local NOTE_INPUT_HEIGHT = NOTE_WINDOW_HEIGHT
	- NOTE_INPUT_TOP
	- NOTE_DATE_LABEL_HEIGHT
	- NOTE_AFTER_DATE_GAP
	- BUTTON_HEIGHT
	- PADDING
local EDITBOX_POLL_SECONDS = 0.12

local previousRuntime = _G.__DPS_BASICS_UNIT_TRACKER_RUNTIME or _G.__DPS_BASICS_PLAYER_TRACKER_RUNTIME

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
	if previousRuntime.launchButton ~= nil then
		previousRuntime.launchButton:Show(false)
	end
end

local runtime = {
	active = true,
	window = nil,
	viewWindow = nil,
	optsWindow = nil,
	noteWindow = nil,
	eventWindow = nil,
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
	friendlyPage = 1,
	hostilePage = 1,
	markersByKey = {},
	keysByMarker = {},
	unitIdKeys = {},
	currentTarget = nil,
	updateElapsed = 0,
	lastMarkedKey = nil,
	lastMarkedMarker = nil,
	lastMarkTime = 0,
	lastMarkerWriteTime = -MARK_RETRY_SECONDS,
	editboxPollElapsed = 0,
	noteTargetKey = nil,
	noteText = "",
	noteInputState = nil,
	noteInput = nil,
	knownPlayerNames = {},
	knownPlayerNamesUpdatedAt = -PLAYER_NAME_REFRESH_SECONDS,
	recentPlayerDamageSourceTimes = {},
	pendingDamageSourceTimes = {},
	lastAutoOpenTime = -AUTO_OPEN_COOLDOWN_SECONDS,
}
_G.__DPS_BASICS_UNIT_TRACKER_RUNTIME = runtime

local function SafeCall(target, methodName, ...)
	if target == nil or type(target[methodName]) ~= "function" then
		return false, nil
	end
	return pcall(target[methodName], target, ...)
end

local function Trim(value)
	local text = tostring(value or "")
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	return text
end

local function NormalizeName(value)
	local text = string.lower(Trim(value))
	text = string.gsub(text, "%s+", " ")
	return text
end

local function NormalizeNoteText(value)
	return tostring(value or "")
end

local function CompactText(value, maxLength)
	local text = tostring(value or "")
	if string.len(text) <= maxLength then
		return text
	end
	if maxLength <= 3 then
		return string.sub(text, 1, maxLength)
	end
	return string.sub(text, 1, maxLength - 3) .. "..."
end

local EDITBOX_GETTER_METHODS = {
	"GetText",
	"GetInputText",
	"GetEditText",
	"GetDisplayText",
	"GetString",
}

local EDITBOX_SETTER_METHODS = {
	"SetText",
	"SetInputText",
	"SetEditText",
	"SetDisplayText",
	"SetString",
}

local function FirstStringArg(...)
	for index = 1, select("#", ...) do
		local value = select(index, ...)
		if type(value) == "string" then
			return tostring(value)
		end
	end
	return nil
end

local function NextEditBoxName(baseName)
	_G.__DPS_BASICS_UNIT_TRACKER_EDITBOX_SERIAL =
		(_G.__DPS_BASICS_UNIT_TRACKER_EDITBOX_SERIAL or 0) + 1
	return baseName .. tostring(_G.__DPS_BASICS_UNIT_TRACKER_EDITBOX_SERIAL)
end

local function ReadEditBoxText(state)
	if state == nil or state.widget == nil then
		return state ~= nil and state.text or ""
	end

	for _, methodName in ipairs(EDITBOX_GETTER_METHODS) do
		local ok, value = SafeCall(state.widget, methodName)
		if ok and type(value) == "string" then
			return value
		end
	end
	return state.text or ""
end

local function SyncEditBoxText(state, text, clearWhenEmpty)
	if state == nil or state.widget == nil then
		return
	end

	local value = tostring(text or "")
	state.syncing = true
	for _, methodName in ipairs(EDITBOX_SETTER_METHODS) do
		SafeCall(state.widget, methodName, value)
	end
	if clearWhenEmpty == true and value == "" then
		SafeCall(state.widget, "ClearText")
		SafeCall(state.widget, "ClearInputText")
		SafeCall(state.widget, "ClearEditText")
	end
	state.syncing = false
end

local function SetEditBoxText(state, text, clearWhenEmpty)
	if state == nil then
		return
	end

	state.text = tostring(text or "")
	SyncEditBoxText(state, state.text, clearWhenEmpty)
end

local function ApplyEditBoxText(state, text, syncWidget)
	if state == nil then
		return
	end

	local value = tostring(text or "")
	if value == state.text then
		return
	end
	state.text = value
	if syncWidget then
		SyncEditBoxText(state, value, false)
	end
	if type(state.onChanged) == "function" then
		state.onChanged(value)
	end
end

local function PollEditBoxText(state)
	if state == nil then
		return
	end
	ApplyEditBoxText(state, ReadEditBoxText(state), false)
end

local function ConfigureEditBoxWidget(input, width, height, maxLength, guideText, allowNewlines)
	input:SetHeight(height)
	input:SetWidth(width)
	input:SetText("")
	SafeCall(input, "SetMaxTextLength", maxLength or 240)
	if allowNewlines == true or height > 28 then
		-- Tall note body: keep caret/text at the top-left instead of vertically centered.
		SafeCall(input, "SetInset", 6, 3, 6, 6)
		SafeCall(input, "SetLineSpace", 1)
		SafeCall(input, "ClearTextOnEnter", false)
		SafeCall(input, "UseSelectAllWhenFocused", false)
	else
		SafeCall(input, "SetInset", 5, 5, 5, 5)
		SafeCall(input, "UseSelectAllWhenFocused", true)
	end
	SafeCall(input, "EnableFocus", true)
	SafeCall(input, "Enable", true)
	SafeCall(input, "Show", true)
	SafeCall(input, "SetVisible", true)
	SafeCall(input, "Clickable", true)
	SafeCall(input, "EnableInput", true)
	SafeCall(input, "SetInputEnabled", true)
	SafeCall(input, "EnableHitTest", true)
	SafeCall(input, "SetHitTestEnabled", true)
	if guideText ~= nil then
		SafeCall(input, "SetGuideText", guideText)
	end
	if input.style ~= nil then
		if (allowNewlines == true or height > 28) and ALIGN_TOP_LEFT ~= nil then
			input.style:SetAlign(ALIGN_TOP_LEFT)
		else
			input.style:SetAlign(ALIGN_LEFT)
		end
		input.style:SetFontSize(13)
		input.style:SetColor(0.05, 0.06, 0.05, 1)
	end

	-- Cursor height uses a small font-relative offset (-2), not absolute pixels.
	SafeCall(input, "SetCursorColor", 0.95, 0.92, 0.82, 1)
	SafeCall(input, "SetCursorColorByColorKey", "brown")
	SafeCall(input, "SetCursorHeight", -2)
	SafeCall(input, "SetCursorOffset", -3)
end

local function AttachEditBoxHandlers(state)
	local input = state and state.widget
	if input == nil then
		return
	end

	local function ActivateInput()
		if state.background ~= nil then
			state.background:SetColor(0.95, 0.74, 0.32, 0.46)
		end
		PollEditBoxText(state)
		SafeCall(input, "SetCursorColor", 0.95, 0.92, 0.82, 1)
		SafeCall(input, "SetCursorColorByColorKey", "brown")
		SafeCall(input, "SetCursorHeight", -2)
		SafeCall(input, "SetCursorOffset", -3)
		SafeCall(input, "SetFocus")
		SafeCall(input, "SetFocus", true)
	end

	local function OnFocusLost()
		if state.background ~= nil then
			state.background:SetColor(1, 1, 1, 0.18)
		end
		PollEditBoxText(state)
	end

	local function OnTextChanged(...)
		if state.syncing == true then
			return
		end

		local text = FirstStringArg(...)
		if text ~= nil then
			ApplyEditBoxText(state, text, false)
		else
			PollEditBoxText(state)
		end
	end

	local function OnEnterPressed()
		if state.allowNewlines ~= true then
			return
		end

		-- Insert a line break at the caret when possible; otherwise append.
		local inserted = SafeCall(input, "Insert", "\n")
		if inserted then
			PollEditBoxText(state)
			return
		end
		ApplyEditBoxText(state, ReadEditBoxText(state) .. "\n", true)
	end

	SafeCall(input, "SetHandler", "OnClick", ActivateInput)
	SafeCall(input, "SetHandler", "OnMouseDown", ActivateInput)
	SafeCall(input, "SetHandler", "OnMouseUp", ActivateInput)
	SafeCall(input, "SetHandler", "OnLButtonDown", ActivateInput)
	SafeCall(input, "SetHandler", "OnLButtonUp", ActivateInput)
	SafeCall(input, "SetHandler", "OnLeftButtonDown", ActivateInput)
	SafeCall(input, "SetHandler", "OnLeftButtonUp", ActivateInput)
	SafeCall(input, "SetHandler", "OnDoubleClick", ActivateInput)
	SafeCall(input, "SetHandler", "OnDoubleClicked", ActivateInput)
	SafeCall(input, "SetHandler", "OnTextChanged", OnTextChanged)
	SafeCall(input, "SetHandler", "OnTextChange", OnTextChanged)
	SafeCall(input, "SetHandler", "OnEditTextChanged", OnTextChanged)
	SafeCall(input, "SetHandler", "OnChanged", OnTextChanged)
	SafeCall(input, "SetHandler", "OnEditFocusLost", OnFocusLost)
	SafeCall(input, "SetHandler", "OnEnterPressed", OnEnterPressed)
end

local function CreateTrackedEditBox(parent, baseName, x, y, width, height, maxLength, guideText, onChanged, widgetType)
	local background = parent:CreateColorDrawable(1, 1, 1, 0.18, "background")
	background:AddAnchor("TOPLEFT", parent, x, y)
	background:SetExtent(width, height)

	local allowNewlines = widgetType == UOT_EDITBOX_MULTILINE or height > 28
	local inputType = widgetType
	if inputType == nil and allowNewlines and UOT_EDITBOX_MULTILINE ~= nil then
		inputType = UOT_EDITBOX_MULTILINE
	end
	local input = parent:CreateChildWidgetByType(inputType or UOT_X2_EDITBOX, NextEditBoxName(baseName), 0, true)
	input:AddAnchor("TOPLEFT", parent, x + 5, y + 3)
	ConfigureEditBoxWidget(input, width - 10, height - 6, maxLength, guideText, allowNewlines)

	local state = {
		widget = input,
		background = background,
		text = "",
		syncing = false,
		onChanged = onChanged,
		allowNewlines = allowNewlines,
	}
	AttachEditBoxHandlers(state)
	return state
end

local function StripWorldSuffix(name)
	name = Trim(name or "")
	local atPos = string.find(name, "@", 1, true)
	if atPos ~= nil then
		return Trim(string.sub(name, 1, atPos - 1))
	end
	return name
end

local function NamesMatch(left, right)
	left = NormalizeName(StripWorldSuffix(left))
	right = NormalizeName(StripWorldSuffix(right))
	return left ~= "" and right ~= "" and left == right
end

local function IsValidName(value)
	return type(value) == "string" and Trim(value) ~= ""
end

local function Now()
	if os ~= nil and type(os.clock) == "function" then
		local ok, value = pcall(os.clock)
		if ok and tonumber(value) ~= nil then
			return tonumber(value)
		end
	end
	return 0
end

local function GetLocalPlayerName()
	if IsValidName(runtime.localPlayerName) then
		return runtime.localPlayerName
	end

	if X2Unit ~= nil then
		local ok, name = SafeCall(X2Unit, "UnitName", "player")
		if ok and IsValidName(name) then
			runtime.localPlayerName = Trim(name)
			return runtime.localPlayerName
		end

		ok, name = SafeCall(X2Unit, "UnitNameWithWorld", "player")
		if ok and IsValidName(name) then
			runtime.localPlayerName = Trim(name)
			return runtime.localPlayerName
		end
	end

	return nil
end

local function IsLocalPlayerName(value)
	value = Trim(value or "")
	if value == "" then
		return false
	end
	if NormalizeName(value) == "you" then
		return true
	end
	return NamesMatch(value, GetLocalPlayerName())
end

local function GetPlayerNameKey(name)
	local key = NormalizeName(StripWorldSuffix(name))
	if key == "" or key == "unknown" then
		return nil
	end
	return key
end

local function RememberKnownPlayerName(name)
	local key = GetPlayerNameKey(name)
	if key ~= nil then
		runtime.knownPlayerNames[key] = true
	end
end

local function RefreshKnownPlayerNames()
	runtime.knownPlayerNames = {}
	RememberKnownPlayerName(GetLocalPlayerName())

	if X2Team ~= nil then
		for teamIndex = 0, 2 do
			for memberIndex = 1, 50 do
				local ok, memberName = SafeCall(X2Team, "GetTeamMemberName", teamIndex, memberIndex)
				if ok and IsValidName(memberName) then
					RememberKnownPlayerName(memberName)
				end
			end
		end
	end
	runtime.knownPlayerNamesUpdatedAt = Now()
end

local function IsKnownPlayerName(name)
	local key = GetPlayerNameKey(name)
	if key == nil then
		return false
	end

	if Now() - (tonumber(runtime.knownPlayerNamesUpdatedAt) or 0) > PLAYER_NAME_REFRESH_SECONDS then
		RefreshKnownPlayerNames()
	end
	return runtime.knownPlayerNames[key] == true
end

local function GetLocalPlayerUnitId()
	if X2Unit == nil then
		return nil
	end

	local ok, unitId = SafeCall(X2Unit, "GetUnitId", "player")
	if ok and IsValidName(unitId) then
		return tostring(unitId)
	end
	return nil
end

local function IsLocalPlayerUnitId(unitId)
	unitId = Trim(tostring(unitId or ""))
	if unitId == "" then
		return false
	end
	if unitId == "player" then
		return true
	end
	return unitId == GetLocalPlayerUnitId()
end

local function GetUnitInfoById(unitId)
	unitId = Trim(tostring(unitId or ""))
	if unitId == "" or X2Unit == nil then
		return nil
	end

	local ok, unitInfo = SafeCall(X2Unit, "GetUnitInfoById", unitId)
	if ok and type(unitInfo) == "table" then
		return unitInfo
	end
	return nil
end

local function IsUnitIdPlayerCharacter(unitId)
	local unitInfo = GetUnitInfoById(unitId)
	return type(unitInfo) == "table" and unitInfo.type == "character"
end

local function GetUnitNameById(unitId, unitInfo)
	if type(unitInfo) == "table" and IsValidName(unitInfo.name) then
		return Trim(unitInfo.name)
	end
	if X2Unit == nil then
		return nil
	end

	local ok, unitName = SafeCall(X2Unit, "GetUnitNameById", unitId)
	if ok and IsValidName(unitName) then
		return Trim(unitName)
	end
	return nil
end

local function RememberRecentPlayerDamageSourceName(name)
	local key = GetPlayerNameKey(name)
	if key ~= nil then
		runtime.recentPlayerDamageSourceTimes[key] = Now()
	end
end

local function IsRecentPlayerDamageSourceName(name)
	local key = GetPlayerNameKey(name)
	if key == nil then
		return false
	end

	local lastSeenAt = tonumber(runtime.recentPlayerDamageSourceTimes[key])
	return lastSeenAt ~= nil and Now() - lastSeenAt <= PLAYER_DAMAGE_SOURCE_CACHE_SECONDS
end

local function RememberPendingDamageSourceName(name)
	local key = GetPlayerNameKey(name)
	if key ~= nil then
		runtime.pendingDamageSourceTimes[key] = Now()
	end
end

local function IsPendingDamageSourceName(name)
	local key = GetPlayerNameKey(name)
	if key == nil then
		return false
	end

	local lastSeenAt = tonumber(runtime.pendingDamageSourceTimes[key])
	return lastSeenAt ~= nil and Now() - lastSeenAt <= PLAYER_DAMAGE_SOURCE_CACHE_SECONDS
end

local function GetCombatEventKind(eventType)
	eventType = tostring(eventType or "")
	if string.find(eventType, "DAMAGE", 1, true) ~= nil then
		return "damage"
	end
	return "other"
end

local function GetDamageAmount(eventType, abilityId, effectType)
	if GetCombatEventKind(eventType) ~= "damage" then
		return nil
	end

	-- COMBAT_MSG reports melee damage in abilityId, while most other damage events use effectType.
	local amount = nil
	if string.find(tostring(eventType or ""), "MELEE_DAMAGE", 1, true) ~= nil then
		amount = tonumber(abilityId)
	end
	if amount == nil then
		amount = tonumber(effectType)
	end
	if amount == nil then
		amount = tonumber(abilityId)
	end
	if amount == nil then
		return nil
	end

	amount = math.abs(amount)
	if amount <= 0 then
		return nil
	end
	return math.floor(amount)
end

local function ParseCombatMessage(...)
	return {
		unitId = select(1, ...),
		eventType = tostring(select(2, ...) or ""),
		sourceName = Trim(select(3, ...) or ""),
		targetName = Trim(select(4, ...) or ""),
		abilityId = select(5, ...),
		effectType = select(8, ...),
	}
end

local function ParseCombatTextMessage(...)
	return {
		sourceUnitId = Trim(tostring(select(1, ...) or "")),
		targetUnitId = Trim(tostring(select(2, ...) or "")),
		amount = tonumber(select(3, ...)),
		hitType = Trim(tostring(select(6, ...) or "")),
	}
end

local function IsDamageCombatText(msg)
	if type(msg) ~= "table" or msg.amount == nil or msg.amount <= 0 then
		return false
	end
	return msg.hitType == "" or msg.hitType == "HIT" or msg.hitType == "CRITICAL"
end

local function IsLocalPlayerCombatTarget(msg)
	if type(msg) ~= "table" then
		return false
	end
	if IsLocalPlayerName(msg.targetName) then
		return true
	end
	return Trim(tostring(msg.unitId or "")) == "player"
end

local GetTargetRecord

local function IsCurrentTargetPlayerSource(sourceName)
	local record = runtime.currentTarget or GetTargetRecord()
	if record == nil or not NamesMatch(sourceName, record.name) then
		return false
	end
	if not IsUnitIdPlayerCharacter(record.unitId) then
		return false
	end

	RememberRecentPlayerDamageSourceName(record.name)
	return true
end

local function IsVerifiedPlayerDamageSource(sourceName)
	if not IsValidName(sourceName) or IsLocalPlayerName(sourceName) then
		return false
	end
	-- COMBAT_MSG only exposes a source name, so require a known player name or recent unit-id verification.
	return IsKnownPlayerName(sourceName)
		or IsRecentPlayerDamageSourceName(sourceName)
		or IsCurrentTargetPlayerSource(sourceName)
end

local function IsIncomingDamageCandidate(msg)
	if type(msg) ~= "table" then
		return false
	end
	if msg.sourceName == "" then
		return false
	end
	if GetDamageAmount(msg.eventType, msg.abilityId, msg.effectType) == nil then
		return false
	end
	return IsLocalPlayerCombatTarget(msg) and not IsLocalPlayerName(msg.sourceName)
end

local function IsIncomingPlayerDamage(msg)
	return IsIncomingDamageCandidate(msg) and IsVerifiedPlayerDamageSource(msg.sourceName)
end

local function SaveData(key, value)
	pcall(function()
		ADDON:SaveData(key, value)
	end)
end

local function LoadData(key)
	local ok, data = pcall(function()
		return ADDON:LoadData(key)
	end)
	if ok then
		return data
	end
	return nil
end

local function GetWidgetPosition(widget)
	if widget == nil then
		return nil, nil
	end

	local ok, offsetX, offsetY = pcall(function()
		return widget:GetOffset()
	end)
	if not ok then
		return nil, nil
	end

	local uiScale = 1.0
	local okScale, scale = pcall(function()
		return UIParent:GetUIScale()
	end)
	if okScale and tonumber(scale) ~= nil then
		uiScale = tonumber(scale)
	end

	return math.floor((offsetX * uiScale) + 0.5), math.floor((offsetY * uiScale) + 0.5)
end

local function SaveWidgetPosition(widget, key)
	local x, y = GetWidgetPosition(widget)
	if x ~= nil and y ~= nil then
		SaveData(key, { x = x, y = y })
	end
end

local function SaveWindowPosition()
	SaveWidgetPosition(runtime.window, POSITION_KEY)
end

local function SaveViewWindowPosition()
	SaveWidgetPosition(runtime.viewWindow, VIEW_POSITION_KEY)
end

local function SaveOptsWindowPosition()
	SaveWidgetPosition(runtime.optsWindow, OPTS_POSITION_KEY)
end

local function SaveNoteWindowPosition()
	SaveWidgetPosition(runtime.noteWindow, NOTE_POSITION_KEY)
end

local function LoadPosition(key, defaultX, defaultY, legacyKey)
	local data = LoadData(key)
	if (type(data) ~= "table" or data.x == nil or data.y == nil) and legacyKey ~= nil then
		data = LoadData(legacyKey)
	end
	if type(data) == "table" and data.x ~= nil and data.y ~= nil then
		return tonumber(data.x) or defaultX, tonumber(data.y) or defaultY
	end
	return defaultX, defaultY
end

local function NormalizeUnitId(unitId)
	unitId = Trim(tostring(unitId or ""))
	if unitId == "" or unitId == "player" or unitId == "target" then
		return nil
	end
	return unitId
end

local function GetEntryName(entry)
	if type(entry) == "table" then
		return entry.name
	end
	if type(entry) == "string" then
		return entry
	end
	return nil
end

local function GetEntryUnitId(entry)
	if type(entry) ~= "table" then
		return nil
	end
	return NormalizeUnitId(entry.unitId or entry.playerId)
end

local function GetEntryAddedAt(entry)
	if type(entry) ~= "table" then
		return nil
	end
	local addedAt = Trim(tostring(entry.addedAt or entry.added or entry.dateAdded or ""))
	if addedAt == "" then
		return nil
	end
	return addedAt
end

local function GetCurrentDateTimeText()
	if type(os) == "table" and type(os.date) == "function" then
		local ok, value = pcall(os.date, "%Y-%m-%d %H:%M:%S")
		if ok and type(value) == "string" and value ~= "" then
			return value
		end
	end

	local ok, timeTable = SafeCall(UIParent, "GetServerTimeTable")
	if ok and type(timeTable) == "table" then
		local year = tonumber(timeTable.year)
		local month = tonumber(timeTable.month)
		local day = tonumber(timeTable.day)
		local hour = tonumber(timeTable.hour) or 0
		local minute = tonumber(timeTable.minute) or 0
		local second = tonumber(timeTable.second) or 0
		if year ~= nil and month ~= nil and day ~= nil then
			return string.format("%04d-%02d-%02d %02d:%02d:%02d", year, month, day, hour, minute, second)
		end
	end

	return ""
end

local function ClearUnitIdKey(unitId, key)
	unitId = NormalizeUnitId(unitId)
	if unitId ~= nil and runtime.unitIdKeys[unitId] == key then
		runtime.unitIdKeys[unitId] = nil
	end
end

local function BindUnitIdKey(unitId, key)
	unitId = NormalizeUnitId(unitId)
	if unitId == nil or key == nil or key == "" then
		return
	end

	-- One unitId maps to one list key; drop a stale reverse mapping if needed.
	local previousKey = runtime.unitIdKeys[unitId]
	if previousKey ~= nil and previousKey ~= key then
		local previousEntry = runtime.friendly[previousKey] or runtime.hostile[previousKey]
		if type(previousEntry) == "table" and NormalizeUnitId(previousEntry.unitId) == unitId then
			previousEntry.unitId = nil
		end
	end
	runtime.unitIdKeys[unitId] = key
end

-- Membership: name key first, then unitId when the name is missing (rename / stale key).
local function FindTrackedEntry(nameKey, unitId)
	if nameKey ~= nil and nameKey ~= "" then
		if runtime.friendly[nameKey] ~= nil then
			return "friendly", nameKey, runtime.friendly[nameKey]
		end
		if runtime.hostile[nameKey] ~= nil then
			return "hostile", nameKey, runtime.hostile[nameKey]
		end
	end

	unitId = NormalizeUnitId(unitId)
	if unitId == nil then
		return nil, nil, nil
	end

	local key = runtime.unitIdKeys[unitId]
	if key == nil or key == "" then
		return nil, nil, nil
	end
	if runtime.friendly[key] ~= nil then
		return "friendly", key, runtime.friendly[key]
	end
	if runtime.hostile[key] ~= nil then
		return "hostile", key, runtime.hostile[key]
	end

	runtime.unitIdKeys[unitId] = nil
	return nil, nil, nil
end

local function MigrateTrackedKey(oldKey, newKey)
	if oldKey == nil or newKey == nil or oldKey == "" or newKey == "" or oldKey == newKey then
		return
	end

	if runtime.notes[oldKey] ~= nil and runtime.notes[newKey] == nil then
		runtime.notes[newKey] = runtime.notes[oldKey]
	end
	runtime.notes[oldKey] = nil

	if runtime.noteTargetKey == oldKey then
		runtime.noteTargetKey = newKey
	end
	if runtime.lastMarkedKey == oldKey then
		runtime.lastMarkedKey = newKey
	end
end

local function AddOrderedEntry(list, order, key, name, unitId, addedAt)
	if key == nil or key == "" then
		return
	end
	if list[key] == nil then
		table.insert(order, key)
	end

	local entry = list[key]
	if type(entry) ~= "table" then
		entry = {}
		list[key] = entry
	end
	entry.name = name

	local previousUnitId = GetEntryUnitId(entry)
	unitId = NormalizeUnitId(unitId)
	if previousUnitId ~= nil and previousUnitId ~= unitId then
		ClearUnitIdKey(previousUnitId, key)
	end
	entry.unitId = unitId
	if unitId ~= nil then
		BindUnitIdKey(unitId, key)
	end

	-- Keep the original add timestamp; only stamp newly created or legacy entries.
	if GetEntryAddedAt(entry) == nil then
		addedAt = Trim(tostring(addedAt or ""))
		if addedAt == "" then
			addedAt = GetCurrentDateTimeText()
		end
		if addedAt ~= "" then
			entry.addedAt = addedAt
		end
	end
end

local function RemoveOrderedEntry(list, order, key)
	if key == nil or key == "" or list[key] == nil then
		return
	end

	ClearUnitIdKey(GetEntryUnitId(list[key]), key)
	list[key] = nil
	for index = #order, 1, -1 do
		if order[index] == key then
			table.remove(order, index)
		end
	end
end

local function LoadSavedEntry(keyOrIndex, entry, list, order)
	local key = nil
	local name = nil
	local note = nil
	local unitId = nil
	local addedAt = nil

	if type(entry) == "table" then
		name = Trim(entry.name or entry.displayName or entry.identity)
		key = NormalizeName(entry.key or entry.identity or name)
		note = entry.note or entry.notes or entry[3]
		unitId = entry.unitId or entry.playerId or entry.id
		addedAt = entry.addedAt or entry.added or entry.dateAdded
	elseif type(keyOrIndex) == "number" then
		name = Trim(entry)
		key = NormalizeName(name)
	else
		name = Trim(entry)
		key = NormalizeName(keyOrIndex)
	end

	if key ~= "" and name ~= "" then
		AddOrderedEntry(list, order, key, name, unitId, addedAt)
		if note ~= nil then
			runtime.notes[key] = NormalizeNoteText(note)
		end
	end
end

local function LoadSavedList(source, list, order)
	if type(source) ~= "table" then
		return
	end

	-- Saved lists are arrays in current builds, but this also accepts old map-style data.
	if #source > 0 then
		for index = 1, #source do
			LoadSavedEntry(index, source[index], list, order)
		end
		return
	end

	for keyOrIndex, entry in pairs(source) do
		LoadSavedEntry(keyOrIndex, entry, list, order)
	end
end

local function LoadLists()
	local data = LoadData(SAVE_KEY)
	if type(data) ~= "table" then
		data = LoadData(LEGACY_SAVE_KEY)
	end
	if type(data) ~= "table" then
		return
	end

	LoadSavedList(data.friendly or data.friendlyList, runtime.friendly, runtime.friendlyOrder)
	LoadSavedList(data.hostile or data.hostileList, runtime.hostile, runtime.hostileOrder)
end

local function BuildSavedList(list, order)
	local saved = {}
	for _, key in ipairs(order) do
		if list[key] ~= nil then
			table.insert(saved, {
				key = key,
				name = GetEntryName(list[key]),
				unitId = GetEntryUnitId(list[key]) or "",
				addedAt = GetEntryAddedAt(list[key]) or "",
				note = runtime.notes[key] or "",
			})
		end
	end
	return saved
end

local function SaveLists()
	SaveData(SAVE_KEY, {
		friendly = BuildSavedList(runtime.friendly, runtime.friendlyOrder),
		hostile = BuildSavedList(runtime.hostile, runtime.hostileOrder),
	})
end

local function EscapeFileField(value)
	local text = tostring(value or "")
	text = string.gsub(text, "\\", "\\\\")
	text = string.gsub(text, "\t", "\\t")
	text = string.gsub(text, "\r", "\\r")
	text = string.gsub(text, "\n", "\\n")
	return text
end

local function GetCurrentDateText()
	if type(os) == "table" and type(os.date) == "function" then
		local ok, value = pcall(os.date, "%Y-%m-%d")
		if ok and type(value) == "string" and value ~= "" then
			return value
		end
	end

	local ok, timeTable = SafeCall(UIParent, "GetServerTimeTable")
	if ok and type(timeTable) == "table" then
		local year = tonumber(timeTable.year)
		local month = tonumber(timeTable.month)
		local day = tonumber(timeTable.day)
		if year ~= nil and month ~= nil and day ~= nil then
			return string.format("%04d-%02d-%02d", year, month, day)
		end
	end

	return "unknown-date"
end

local function AddUniquePath(paths, path)
	if path == nil or path == "" then
		return
	end

	local normalizedPath = string.gsub(tostring(path), "\\", "/")
	for _, existingPath in ipairs(paths) do
		if existingPath == normalizedPath then
			return
		end
	end
	table.insert(paths, normalizedPath)
end

local function GetAddonSourceDirectory()
	if type(debug) ~= "table" or type(debug.getinfo) ~= "function" then
		return nil
	end

	local ok, info = pcall(debug.getinfo, 1, "S")
	if not ok or type(info) ~= "table" or type(info.source) ~= "string" then
		return nil
	end

	local source = info.source
	if string.sub(source, 1, 1) == "@" then
		source = string.sub(source, 2)
	end
	source = string.gsub(source, "\\", "/")

	local directory = string.match(source, "^(.*)/[^/]+$")
	if directory == nil or directory == "" then
		return nil
	end
	return directory
end

local function TryOpenFile(path, mode)
	if type(io) ~= "table" or type(io.open) ~= "function" then
		return nil, "io.open unavailable"
	end

	local ok, file, errorMessage = pcall(io.open, path, mode)
	if ok and file ~= nil then
		return file, nil
	end
	if ok then
		return nil, errorMessage
	end
	return nil, file
end

local function BuildExportFilePaths(fileName)
	local paths = {}
	local sourceDirectory = GetAddonSourceDirectory()
	if sourceDirectory ~= nil then
		AddUniquePath(paths, sourceDirectory .. "/" .. fileName)
	end
	AddUniquePath(paths, "dpsbasics/" .. fileName)
	AddUniquePath(paths, fileName)
	return paths
end

local function WriteExportSection(file, sectionTitle, list, order)
	file:write("[")
	file:write(sectionTitle)
	file:write("]\n")
	for _, key in ipairs(order) do
		local name = GetEntryName(list[key])
		if name ~= nil then
			file:write(EscapeFileField(Trim(name)))
			local unitId = GetEntryUnitId(list[key])
			file:write("\t")
			file:write(EscapeFileField(unitId or ""))
			local addedAt = GetEntryAddedAt(list[key])
			file:write("\t")
			file:write(EscapeFileField(addedAt or ""))
			local note = NormalizeNoteText(runtime.notes[key] or "")
			if note ~= "" then
				file:write("\t")
				file:write(EscapeFileField(note))
			end
			file:write("\n")
		end
	end
	file:write("\n")
end

local function WriteExportFile(fileName)
	local lastError = nil
	for _, path in ipairs(BuildExportFilePaths(fileName)) do
		local file, openError = TryOpenFile(path, "w")
		if file ~= nil then
			local ok, writeError = pcall(function()
				file:write("# DPS Basics Unit Tracker Export - ")
				file:write(GetCurrentDateText())
				file:write("\n\n")
				WriteExportSection(file, "Friendly", runtime.friendly, runtime.friendlyOrder)
				WriteExportSection(file, "Hostile", runtime.hostile, runtime.hostileOrder)
				if type(file.flush) == "function" then
					file:flush()
				end
				file:close()
			end)
			if ok then
				return true, path, nil
			end
			pcall(function()
				file:close()
			end)
			lastError = tostring(writeError or "write failed")
		else
			lastError = tostring(openError or "open failed")
		end
	end
	return false, nil, lastError
end

local function DispatchExportStatus(message)
	if X2Chat ~= nil and type(X2Chat.DispatchChatMessage) == "function" then
		pcall(X2Chat.DispatchChatMessage, X2Chat, CMF_SYSTEM, tostring(message or ""))
	end
end

local function ExportPlayerLists()
	local fileName = EXPORT_FILE_PREFIX .. GetCurrentDateText() .. ".txt"
	local exported, path, exportError = WriteExportFile(fileName)
	if exported then
		DispatchExportStatus("[Unit Tracker] Exported to " .. tostring(path) .. ".")
	else
		local message = "[Unit Tracker] Export failed."
		if exportError ~= nil and tostring(exportError) ~= "" then
			message = message .. " " .. tostring(exportError)
		end
		DispatchExportStatus(message)
	end
end

local function GetCurrentTargetUnitId()
	local okTarget, targetUnitId = SafeCall(X2Unit, "GetTargetUnitId")
	if okTarget and IsValidName(targetUnitId) then
		return tostring(targetUnitId)
	end

	local okUnit, unitId = SafeCall(X2Unit, "GetUnitId", "target")
	if okUnit and IsValidName(unitId) then
		return tostring(unitId)
	end

	return nil
end

GetTargetRecord = function()
	local okWorld, worldName = SafeCall(X2Unit, "UnitNameWithWorld", "target")
	local okName, name = SafeCall(X2Unit, "UnitName", "target")

	local displayName = nil
	if okWorld and IsValidName(worldName) then
		displayName = Trim(worldName)
	elseif okName and IsValidName(name) then
		displayName = Trim(name)
	end

	if displayName == nil or displayName == "" then
		return nil
	end

	return {
		key = NormalizeName(displayName),
		name = displayName,
		unitId = GetCurrentTargetUnitId(),
	}
end

local function SetLabelColor(label, color)
	if label ~= nil and label.style ~= nil then
		label.style:SetColor(color[1], color[2], color[3], color[4])
	end
end

local function SetButtonTextColor(button, color)
	if button == nil or type(color) ~= "table" then
		return
	end
	SafeCall(button, "SetTextColor", color[1], color[2], color[3], color[4] or 1)
end

local function GetTrackedKeyForRecord(record)
	if record == nil then
		return nil
	end
	local _, trackedKey = FindTrackedEntry(record.key, record.unitId)
	return trackedKey
end

local function MeasureLabelTextWidth(label, text)
	if label == nil or label.style == nil then
		return nil
	end
	local ok, width = pcall(function()
		return label.style:GetTextWidth(tostring(text or ""))
	end)
	if ok and tonumber(width) ~= nil then
		return tonumber(width)
	end
	return nil
end

-- Pack note text into at most two preview lines; overflow becomes trailing "...".
-- Returns line1, line2 (labels do not honor "\n", so callers use two widgets).
local function FormatNotePreview(note, label, maxWidth)
	note = tostring(note or "")
	note = string.gsub(note, "\r\n", "\n")
	note = string.gsub(note, "\r", "\n")
	note = string.gsub(note, "\n+", " ")
	-- Drop private-use leftovers (often shown as boxes from bad newline glyphs).
	note = string.gsub(note, "\238[\128-\191][\128-\191]", " ")
	note = string.gsub(note, "\239[\128-\163][\128-\191]", " ")
	note = string.gsub(note, "%s+", " ")
	note = Trim(note)
	if note == "" then
		return "", ""
	end

	maxWidth = tonumber(maxWidth) or NOTE_PREVIEW_WIDTH
	-- Small inset for outline; slight slack offsets GetTextWidth over-reporting.
	local usableWidth = maxWidth - 4
	if usableWidth < 40 then
		usableWidth = maxWidth
	end
	local widthSlack = 1.08

	-- Mixed sample ≈ average preview text better than narrow "n" or wide "W" alone.
	local sample = "The quick brown Fox jumps 0123.-,"
	local sampleWidth = MeasureLabelTextWidth(label, sample)
	local avgCharWidth = 6.4
	if sampleWidth ~= nil and sampleWidth > 0 then
		avgCharWidth = sampleWidth / string.len(sample)
	end

	local function EstimateWidth(text)
		text = tostring(text or "")
		local measured = MeasureLabelTextWidth(label, text)
		if measured ~= nil and measured > 0 then
			return measured
		end
		return string.len(text) * avgCharWidth
	end

	local function Fits(text)
		return EstimateWidth(text) <= (usableWidth * widthSlack)
	end

	local function FitLine(text)
		text = tostring(text or "")
		if text == "" then
			return ""
		end
		if Fits(text) then
			return text
		end

		local lo = 1
		local hi = string.len(text)
		local best = "..."
		while lo <= hi do
			local mid = math.floor((lo + hi) / 2)
			local candidate = string.sub(text, 1, mid) .. "..."
			if Fits(candidate) then
				best = candidate
				lo = mid + 1
			else
				hi = mid - 1
			end
		end
		return best
	end

	local words = {}
	for word in string.gmatch(note, "%S+") do
		table.insert(words, word)
	end

	local line1 = ""
	local index = 1
	while index <= #words do
		local candidate = line1
		if candidate == "" then
			candidate = words[index]
		else
			candidate = candidate .. " " .. words[index]
		end
		if Fits(candidate) then
			line1 = candidate
			index = index + 1
		else
			break
		end
	end

	if line1 == "" then
		line1 = FitLine(words[1] or "")
		index = 2
	end

	if index > #words then
		return line1, ""
	end

	local remaining = table.concat(words, " ", index, #words)
	return line1, FitLine(remaining)
end

local function UpdateWindowText()
	if runtime.window == nil then
		return
	end
	local line1 = runtime.window.noteLine1
	local line2 = runtime.window.noteLine2
	if line1 == nil or line2 == nil then
		return
	end

	local trackedKey = GetTrackedKeyForRecord(runtime.currentTarget)
	line1.trackedKey = trackedKey
	line2.trackedKey = trackedKey

	local note = ""
	if trackedKey ~= nil then
		note = NormalizeNoteText(runtime.notes[trackedKey] or "")
	end

	local preview1, preview2 = "", ""
	if note ~= "" then
		local previewWidth = NOTE_PREVIEW_WIDTH
		local okWidth, labelWidth = pcall(function()
			return line1:GetWidth()
		end)
		if okWidth and tonumber(labelWidth) ~= nil and tonumber(labelWidth) > 0 then
			previewWidth = tonumber(labelWidth)
		end
		preview1, preview2 = FormatNotePreview(note, line1, previewWidth)
	end
	line1:SetText(preview1 or "")
	line2:SetText(preview2 or "")
	SetLabelColor(line1, { 0.9, 0.9, 0.9, 1 })
	SetLabelColor(line2, { 0.9, 0.9, 0.9, 1 })
end

local function IsHostileMarker(markerIndex)
	markerIndex = tonumber(markerIndex)
	if markerIndex == HOSTILE_MARKER_INDEX then
		return true
	end
	for _, numberedMarker in ipairs(NUMBERED_HOSTILE_MARKERS) do
		if markerIndex == numberedMarker then
			return true
		end
	end
	return false
end

local function GetCurrentTargetMarker()
	local okCurrent, currentMarker = SafeCall(X2Unit, "GetOverHeadMarker", "target")
	if okCurrent then
		return tonumber(currentMarker)
	end
	return nil
end

local function SameUnitId(left, right)
	return IsValidName(left) and IsValidName(right) and tostring(left) == tostring(right)
end

local function IsMarkerAvailable(markerIndex, targetUnitId)
	local ok, markerUnitId = SafeCall(X2Unit, "GetOverHeadMarkerUnitId", markerIndex)
	if not ok or not IsValidName(markerUnitId) then
		return true
	end
	return SameUnitId(markerUnitId, targetUnitId)
end

-- Use X first, then 1-9. When every slot is taken, recycle X onto the new target.
local function ChooseHostileMarker(record)
	local currentMarker = GetCurrentTargetMarker()
	if IsHostileMarker(currentMarker) then
		return currentMarker, false
	end

	if IsMarkerAvailable(HOSTILE_MARKER_INDEX, record.unitId) then
		return HOSTILE_MARKER_INDEX, true
	end

	for _, markerIndex in ipairs(NUMBERED_HOSTILE_MARKERS) do
		if IsMarkerAvailable(markerIndex, record.unitId) then
			return markerIndex, true
		end
	end

	return HOSTILE_MARKER_INDEX, true
end

local function ForgetMarkerForKey(key)
	local markerIndex = runtime.markersByKey[key]
	if markerIndex ~= nil then
		runtime.keysByMarker[markerIndex] = nil
	end
	runtime.markersByKey[key] = nil
end

local function RememberMarkerForKey(key, markerIndex)
	ForgetMarkerForKey(key)

	local previousKey = runtime.keysByMarker[markerIndex]
	if previousKey ~= nil and previousKey ~= key then
		runtime.markersByKey[previousKey] = nil
	end

	runtime.markersByKey[key] = markerIndex
	runtime.keysByMarker[markerIndex] = key
end

local function ApplyHostileTargetMarker()
	local record = runtime.currentTarget
	if record == nil then
		return
	end
	local listName, trackedKey = FindTrackedEntry(record.key, record.unitId)
	if listName ~= "hostile" or trackedKey == nil then
		return
	end

	local markerIndex, shouldWrite = ChooseHostileMarker(record)
	if markerIndex == nil then
		return
	end

	local now = os.clock()
	if not shouldWrite then
		runtime.lastMarkedKey = trackedKey
		runtime.lastMarkedMarker = markerIndex
		runtime.lastMarkTime = now
		return
	end

	-- Native marker writes have a cooldown, so target polling only writes when the chosen mark changes or the retry gap has elapsed.
	if runtime.lastMarkedKey == trackedKey
		and runtime.lastMarkedMarker == markerIndex
		and (now - runtime.lastMarkTime) < MARK_RETRY_SECONDS
	then
		return
	end
	if (now - runtime.lastMarkerWriteTime) < MARK_RETRY_SECONDS then
		return
	end

	local ok = SafeCall(X2Unit, "SetOverHeadMarker", "target", markerIndex)
	runtime.lastMarkedKey = trackedKey
	runtime.lastMarkedMarker = markerIndex
	runtime.lastMarkTime = now
	runtime.lastMarkerWriteTime = now
	if ok then
		RememberMarkerForKey(trackedKey, markerIndex)
	end
end

local function ClearOwnedHostileMarker(record)
	if record == nil then
		return
	end

	local _, trackedKey = FindTrackedEntry(record.key, record.unitId)
	trackedKey = trackedKey or record.key
	local ownedMarker = runtime.markersByKey[trackedKey]
	if ownedMarker == nil and record.key ~= trackedKey then
		ownedMarker = runtime.markersByKey[record.key]
		if ownedMarker ~= nil then
			trackedKey = record.key
		end
	end
	if ownedMarker == nil then
		return
	end

	-- Avoid RemoveAllOverHeadMarker; only try clearing the mark this addon assigned to the selected target.
	local currentMarker = GetCurrentTargetMarker()
	if tonumber(currentMarker) == tonumber(ownedMarker) then
		SafeCall(X2Unit, "SetOverHeadMarker", "target", 0)
	end

	ForgetMarkerForKey(trackedKey)
	if runtime.lastMarkedKey == trackedKey or runtime.lastMarkedKey == record.key then
		runtime.lastMarkedKey = nil
		runtime.lastMarkedMarker = nil
		runtime.lastMarkTime = 0
	end
end

local function SyncTrackedEntryForRecord(record)
	if record == nil then
		return nil, nil
	end

	local listName, trackedKey, entry = FindTrackedEntry(record.key, record.unitId)
	if listName == nil or trackedKey == nil then
		return nil, nil
	end

	local list = listName == "friendly" and runtime.friendly or runtime.hostile
	local order = listName == "friendly" and runtime.friendlyOrder or runtime.hostileOrder
	local changed = false

	if trackedKey ~= record.key then
		local markerIndex = runtime.markersByKey[trackedKey]
		local preservedAddedAt = GetEntryAddedAt(entry)
		RemoveOrderedEntry(list, order, trackedKey)
		MigrateTrackedKey(trackedKey, record.key)
		AddOrderedEntry(list, order, record.key, record.name, record.unitId, preservedAddedAt)
		if markerIndex ~= nil then
			RememberMarkerForKey(record.key, markerIndex)
		end
		trackedKey = record.key
		changed = true
	else
		local previousName = GetEntryName(entry)
		local previousUnitId = GetEntryUnitId(entry)
		local nextUnitId = NormalizeUnitId(record.unitId) or previousUnitId
		if previousName ~= record.name or previousUnitId ~= nextUnitId then
			AddOrderedEntry(list, order, trackedKey, record.name, nextUnitId, GetEntryAddedAt(entry))
			changed = previousName ~= record.name or previousUnitId ~= GetEntryUnitId(list[trackedKey])
		end
	end

	if changed then
		SaveLists()
	end
	return listName, trackedKey
end

local function RefreshTargetState()
	runtime.currentTarget = GetTargetRecord()
	local listName = nil
	if runtime.currentTarget ~= nil then
		listName = select(1, SyncTrackedEntryForRecord(runtime.currentTarget))
	end
	UpdateWindowText()
	if runtime.currentTarget ~= nil and listName ~= "hostile" then
		ClearOwnedHostileMarker(runtime.currentTarget)
	else
		ApplyHostileTargetMarker()
	end
end

local UpdateViewWindow

local function AddCurrentTargetToList(listName)
	local record = GetTargetRecord()
	if record == nil then
		RefreshTargetState()
		return
	end

	local existingList, existingKey = FindTrackedEntry(record.key, record.unitId)
	local preservedAddedAt = nil
	if existingKey ~= nil then
		preservedAddedAt = GetEntryAddedAt(runtime.friendly[existingKey] or runtime.hostile[existingKey])
	end
	if existingList == "friendly" and existingKey ~= nil then
		if existingKey ~= record.key then
			MigrateTrackedKey(existingKey, record.key)
		end
		RemoveOrderedEntry(runtime.friendly, runtime.friendlyOrder, existingKey)
	elseif existingList == "hostile" and existingKey ~= nil then
		if existingKey ~= record.key then
			MigrateTrackedKey(existingKey, record.key)
		end
		local markerIndex = runtime.markersByKey[existingKey]
		RemoveOrderedEntry(runtime.hostile, runtime.hostileOrder, existingKey)
		if listName ~= "hostile" then
			ForgetMarkerForKey(existingKey)
			ForgetMarkerForKey(record.key)
		elseif markerIndex ~= nil and existingKey ~= record.key then
			RememberMarkerForKey(record.key, markerIndex)
		end
	end

	if listName == "friendly" then
		AddOrderedEntry(runtime.friendly, runtime.friendlyOrder, record.key, record.name, record.unitId, preservedAddedAt)
		ClearOwnedHostileMarker(record)
	elseif listName == "hostile" then
		AddOrderedEntry(runtime.hostile, runtime.hostileOrder, record.key, record.name, record.unitId, preservedAddedAt)
	end

	SaveLists()
	RefreshTargetState()
	if UpdateViewWindow ~= nil then
		UpdateViewWindow()
	end
end

local function RemoveNameFromList(listName, key)
	if key == nil or key == "" then
		return
	end

	runtime.removeConfirm = nil

	if listName == "friendly" then
		RemoveOrderedEntry(runtime.friendly, runtime.friendlyOrder, key)
	elseif listName == "hostile" then
		RemoveOrderedEntry(runtime.hostile, runtime.hostileOrder, key)
		local record = runtime.currentTarget or GetTargetRecord()
		local recordUnitId = record ~= nil and NormalizeUnitId(record.unitId) or nil
		if record ~= nil and (record.key == key or (recordUnitId ~= nil and runtime.unitIdKeys[recordUnitId] == key)) then
			ClearOwnedHostileMarker(record)
		else
			ForgetMarkerForKey(key)
		end
	end

	if runtime.friendly[key] == nil and runtime.hostile[key] == nil then
		runtime.notes[key] = nil
		if runtime.noteTargetKey == key then
			runtime.noteTargetKey = nil
			if runtime.noteWindow ~= nil then
				runtime.noteWindow:Show(false)
			end
		end
	end

	SaveLists()
	RefreshTargetState()
	if UpdateViewWindow ~= nil then
		UpdateViewWindow()
	end
end

local function IsRemoveConfirmPending(listName, key)
	local pending = runtime.removeConfirm
	return pending ~= nil and pending.listName == listName and pending.key == key
end

local function ClearRemoveConfirm()
	if runtime.removeConfirm == nil then
		return
	end
	runtime.removeConfirm = nil
	if UpdateViewWindow ~= nil then
		UpdateViewWindow()
	end
end

local function BeginRemoveConfirm(listName, key)
	if listName == nil or key == nil or key == "" then
		return
	end
	runtime.removeConfirm = {
		listName = listName,
		key = key,
	}
	if UpdateViewWindow ~= nil then
		UpdateViewWindow()
	end
end

local function CreateLabel(parent, name, text, width, height, x, y, fontSize, color)
	local label = parent:CreateChildWidget("label", name, 0, true)
	label:SetText(text or "")
	label:SetExtent(width, height)
	label.style:SetAlign(ALIGN_LEFT)
	label.style:SetFontSize(fontSize)
	label.style:SetColor(color[1], color[2], color[3], color[4])
	label.style:SetOutline(true)
	label:AddAnchor("TOPLEFT", parent, x, y)
	return label
end

local function CreateButton(parent, name, text, x, y)
	local button = parent:CreateChildWidget("button", name, 0, true)
	button:SetStyle("text_default")
	button:SetText(text)
	button:SetExtent(BUTTON_WIDTH, BUTTON_HEIGHT)
	button:AddAnchor("TOPLEFT", parent, x, y)
	return button
end

local function SetWidgetVisible(widget, visible)
	if widget ~= nil then
		widget:Show(visible == true)
	end
end

local function GetTrackedNameForKey(key)
	if key == nil or key == "" then
		return nil
	end
	return GetEntryName(runtime.friendly[key] or runtime.hostile[key])
end

local function SetWindowStatus(window, message, color)
	if window ~= nil and window.statusLabel ~= nil then
		window.statusLabel:SetText(message or "")
		SetLabelColor(window.statusLabel, color or { 0.72, 0.86, 1, 1 })
	end
end

local function NormalizeDt(dt)
	local delta = tonumber(dt) or 0
	if delta > 1 then
		delta = delta / 1000
	end
	return delta
end

local function PollNoteEditBox(dt)
	if not runtime.active then
		return
	end

	runtime.editboxPollElapsed = runtime.editboxPollElapsed + NormalizeDt(dt)
	if runtime.editboxPollElapsed < EDITBOX_POLL_SECONDS then
		return
	end
	runtime.editboxPollElapsed = 0
	PollEditBoxText(runtime.noteInputState)
end

local function SaveNoteFromInput()
	local key = runtime.noteTargetKey
	local name = GetTrackedNameForKey(key)
	if key == nil or name == nil then
		SetWindowStatus(runtime.noteWindow, "Select a player.", { 1, 0.52, 0.42, 1 })
		return
	end

	PollEditBoxText(runtime.noteInputState)
	runtime.notes[key] = NormalizeNoteText(runtime.noteText)
	SaveLists()
	UpdateWindowText()
	if UpdateViewWindow ~= nil then
		UpdateViewWindow()
	end
	SetWindowStatus(runtime.noteWindow, "Saved.", { 0.72, 0.86, 1, 1 })
end

local function CreateNoteInput(window)
	local state = CreateTrackedEditBox(
		window,
		"dpsBasicsUnitTrackerNoteInput",
		NOTE_INPUT_LEFT,
		NOTE_INPUT_TOP,
		NOTE_INPUT_WIDTH,
		NOTE_INPUT_HEIGHT,
		240,
		"Player note",
		function(text)
			runtime.noteText = tostring(text or "")
		end,
		UOT_EDITBOX_MULTILINE
	)
	runtime.noteInputState = state
	runtime.noteInput = state.widget
	return state.widget
end

local function CreateNoteWindow()
	if runtime.noteWindow ~= nil then
		return runtime.noteWindow
	end

	local noteX, noteY = LoadPosition(NOTE_POSITION_KEY, 760, 420, LEGACY_NOTE_POSITION_KEY)
	local noteWindow = CreateEmptyWindow("dpsBasicsUnitTrackerNoteWindow", "UIParent")
	runtime.noteWindow = noteWindow
	noteWindow:SetExtent(NOTE_WINDOW_WIDTH, NOTE_WINDOW_HEIGHT)
	noteWindow:AddAnchor("TOPLEFT", "UIParent", noteX, noteY)
	noteWindow:EnableDrag(true)
	noteWindow:Clickable(true)
	noteWindow:Show(false)

	local background = noteWindow:CreateColorDrawable(0, 0, 0, 0.72, "background")
	background:AddAnchor("TOPLEFT", noteWindow, 0, 0)
	background:AddAnchor("BOTTOMRIGHT", noteWindow, 0, 0)

	noteWindow.titleLabel = CreateLabel(
		noteWindow,
		"dpsBasicsUnitTrackerNoteTitle",
		"Player Note",
		NOTE_WINDOW_WIDTH - 44,
		22,
		PADDING,
		6,
		11,
		{ 0.95, 0.92, 0.82, 1 }
	)
	SafeCall(noteWindow.titleLabel, "EnableDrag", true)

	noteWindow.closeButton = noteWindow:CreateChildWidget("button", "dpsBasicsUnitTrackerNoteCloseButton", 0, true)
	noteWindow.closeButton:SetStyle("text_default")
	noteWindow.closeButton:SetText("X")
	noteWindow.closeButton:SetExtent(26, 20)
	noteWindow.closeButton:AddAnchor("TOPRIGHT", noteWindow, -6, 6)

	CreateNoteInput(noteWindow)
	local dateY = NOTE_INPUT_TOP + NOTE_INPUT_HEIGHT + 2
	noteWindow.dateLabel = CreateLabel(
		noteWindow,
		"dpsBasicsUnitTrackerNoteDate",
		"",
		NOTE_INPUT_WIDTH,
		NOTE_DATE_LABEL_HEIGHT,
		NOTE_INPUT_LEFT,
		dateY,
		10,
		{ 0.72, 0.86, 1, 1 }
	)
	if noteWindow.dateLabel.style ~= nil then
		noteWindow.dateLabel.style:SetAlign(ALIGN_LEFT)
	end

	local actionY = dateY + NOTE_DATE_LABEL_HEIGHT + NOTE_AFTER_DATE_GAP
	noteWindow.statusLabel = CreateLabel(
		noteWindow,
		"dpsBasicsUnitTrackerNoteStatus",
		"",
		NOTE_WINDOW_WIDTH - BUTTON_WIDTH - (PADDING * 3),
		18,
		PADDING,
		actionY + 4,
		10,
		{ 0.72, 0.86, 1, 1 }
	)
	noteWindow.saveButton = CreateButton(
		noteWindow,
		"dpsBasicsUnitTrackerNoteSaveButton",
		"Save",
		NOTE_WINDOW_WIDTH - PADDING - BUTTON_WIDTH,
		actionY
	)

	function noteWindow:OnDragStart()
		self:StartMoving()
	end
	noteWindow:SetHandler("OnDragStart", noteWindow.OnDragStart)

	function noteWindow:OnDragStop()
		self:StopMovingOrSizing()
		SaveNoteWindowPosition()
	end
	noteWindow:SetHandler("OnDragStop", noteWindow.OnDragStop)

	function noteWindow.titleLabel:OnDragStart()
		noteWindow:StartMoving()
	end
	noteWindow.titleLabel:SetHandler("OnDragStart", noteWindow.titleLabel.OnDragStart)

	function noteWindow.titleLabel:OnDragStop()
		noteWindow:StopMovingOrSizing()
		SaveNoteWindowPosition()
	end
	noteWindow.titleLabel:SetHandler("OnDragStop", noteWindow.titleLabel.OnDragStop)

	function noteWindow.closeButton:OnClick()
		SaveNoteWindowPosition()
		noteWindow:Show(false)
	end
	noteWindow.closeButton:SetHandler("OnClick", noteWindow.closeButton.OnClick)

	function noteWindow.saveButton:OnClick()
		SaveNoteFromInput()
	end
	noteWindow.saveButton:SetHandler("OnClick", noteWindow.saveButton.OnClick)

	function noteWindow:OnUpdate(dt)
		PollNoteEditBox(dt)
	end
	noteWindow:SetHandler("OnUpdate", noteWindow.OnUpdate)

	return noteWindow
end

local function OpenNoteWindow(key)
	local name = GetTrackedNameForKey(key)
	if key == nil or name == nil then
		return
	end

	local noteWindow = CreateNoteWindow()
	runtime.noteTargetKey = key
	runtime.noteText = runtime.notes[key] or ""
	noteWindow.titleLabel:SetText(CompactText(name, 22))
	local addedAt = GetEntryAddedAt(runtime.friendly[key] or runtime.hostile[key])
	if noteWindow.dateLabel ~= nil then
		if addedAt ~= nil then
			noteWindow.dateLabel:SetText(addedAt)
		else
			noteWindow.dateLabel:SetText("")
		end
	end
	SetEditBoxText(runtime.noteInputState, runtime.noteText, true)
	SetWindowStatus(noteWindow, "", { 0.72, 0.86, 1, 1 })
	noteWindow:Show(true)
end

local function EnsureViewRow(listName, index)
	local rows = runtime.viewRows[listName]
	local row = rows[index]
	if row ~= nil then
		return row
	end

	local viewWindow = runtime.viewWindow
	row = {}
	row.nameLabel = CreateLabel(
		viewWindow,
		"dpsBasicsUnitTrackerView" .. listName .. "Name" .. tostring(index),
		"",
		VIEW_WINDOW_WIDTH - (PADDING * 2) - VIEW_ROW_ACTION_WIDTH - 4,
		20,
		PADDING,
		0,
		11,
		{ 0.9, 0.9, 0.9, 1 }
	)
	SafeCall(row.nameLabel, "Clickable", true)
	SafeCall(row.nameLabel, "EnablePick", true)
	SafeCall(row.nameLabel, "EnableHitTest", true)
	SafeCall(row.nameLabel, "SetHitTestEnabled", true)
	function row.nameLabel:OnClick()
		OpenNoteWindow(self.entryKey)
	end
	row.nameLabel:SetHandler("OnClick", row.nameLabel.OnClick)

	row.removeButton = viewWindow:CreateChildWidget(
		"button",
		"dpsBasicsUnitTrackerView" .. listName .. "Remove" .. tostring(index),
		0,
		true
	)
	row.removeButton:SetStyle("text_default")
	row.removeButton:SetText("X")
	row.removeButton:SetExtent(VIEW_REMOVE_BUTTON_WIDTH, 20)

	function row.removeButton:OnClick()
		BeginRemoveConfirm(self.listName, self.entryKey)
	end
	row.removeButton:SetHandler("OnClick", row.removeButton.OnClick)

	row.confirmNoButton = viewWindow:CreateChildWidget(
		"button",
		"dpsBasicsUnitTrackerView" .. listName .. "ConfirmNo" .. tostring(index),
		0,
		true
	)
	row.confirmNoButton:SetStyle("text_default")
	row.confirmNoButton:SetText("N")
	row.confirmNoButton:SetExtent(VIEW_CONFIRM_BUTTON_WIDTH, 20)

	function row.confirmNoButton:OnClick()
		ClearRemoveConfirm()
	end
	row.confirmNoButton:SetHandler("OnClick", row.confirmNoButton.OnClick)

	row.confirmYesButton = viewWindow:CreateChildWidget(
		"button",
		"dpsBasicsUnitTrackerView" .. listName .. "ConfirmYes" .. tostring(index),
		0,
		true
	)
	row.confirmYesButton:SetStyle("text_default")
	row.confirmYesButton:SetText("Y")
	row.confirmYesButton:SetExtent(VIEW_CONFIRM_BUTTON_WIDTH, 20)

	function row.confirmYesButton:OnClick()
		RemoveNameFromList(self.listName, self.entryKey)
	end
	row.confirmYesButton:SetHandler("OnClick", row.confirmYesButton.OnClick)

	rows[index] = row
	return row
end

local function PositionViewRow(row, listName, key, name, y, color)
	local confirming = IsRemoveConfirmPending(listName, key)
	local nameWidth = VIEW_WINDOW_WIDTH - (PADDING * 2) - VIEW_ROW_ACTION_WIDTH - 4

	row.nameLabel.entryKey = key
	row.nameLabel:SetText(name)
	row.nameLabel:RemoveAllAnchors()
	row.nameLabel:AddAnchor("TOPLEFT", runtime.viewWindow, PADDING, y + 2)
	row.nameLabel:SetExtent(nameWidth, 20)
	SetLabelColor(row.nameLabel, color)
	row.nameLabel:Show(true)

	row.removeButton.listName = listName
	row.removeButton.entryKey = key
	row.removeButton:RemoveAllAnchors()
	row.removeButton:AddAnchor("TOPRIGHT", runtime.viewWindow, -PADDING, y)
	row.removeButton:Show(not confirming)

	row.confirmYesButton.listName = listName
	row.confirmYesButton.entryKey = key
	row.confirmYesButton:RemoveAllAnchors()
	row.confirmYesButton:AddAnchor("TOPRIGHT", runtime.viewWindow, -PADDING, y)
	row.confirmYesButton:Show(confirming)

	row.confirmNoButton:RemoveAllAnchors()
	row.confirmNoButton:AddAnchor(
		"TOPRIGHT",
		runtime.viewWindow,
		-(PADDING + VIEW_CONFIRM_BUTTON_WIDTH + VIEW_CONFIRM_GAP),
		y
	)
	row.confirmNoButton:Show(confirming)
end

local function HideUnusedViewRows(listName, firstUnusedIndex)
	local rows = runtime.viewRows[listName]
	for index = firstUnusedIndex, #rows do
		SetWidgetVisible(rows[index].nameLabel, false)
		SetWidgetVisible(rows[index].removeButton, false)
		SetWidgetVisible(rows[index].confirmNoButton, false)
		SetWidgetVisible(rows[index].confirmYesButton, false)
	end
end

local function GetTotalPagesForCount(count)
	count = tonumber(count) or 0
	if count <= 0 then
		return 1
	end
	return math.ceil(count / VIEW_ROWS_PER_PAGE)
end

local function GetSectionPage(listName)
	if listName == "friendly" then
		return tonumber(runtime.friendlyPage) or 1
	end
	return tonumber(runtime.hostilePage) or 1
end

local function SetSectionPage(listName, page)
	page = tonumber(page) or 1
	if page < 1 then
		page = 1
	end
	if listName == "friendly" then
		runtime.friendlyPage = page
	else
		runtime.hostilePage = page
	end
end

local function BuildOrderedKeys(list, order)
	local keys = {}
	for _, key in ipairs(order) do
		if list[key] ~= nil then
			table.insert(keys, key)
		end
	end
	return keys
end

local function ClampSectionPage(listName, count)
	local totalPages = GetTotalPagesForCount(count)
	local page = GetSectionPage(listName)
	if page > totalPages then
		page = totalPages
	end
	if page < 1 then
		page = 1
	end
	SetSectionPage(listName, page)
	return page, totalPages
end

local function PositionSectionPagination(pagination, y)
	if pagination == nil then
		return
	end

	local viewWindow = runtime.viewWindow
	local rightInset = PADDING

	pagination.nextButton:RemoveAllAnchors()
	pagination.nextButton:AddAnchor("TOPRIGHT", viewWindow, -rightInset, y)
	pagination.nextButton:Show(true)

	rightInset = rightInset + PAGE_BUTTON_WIDTH + 2
	pagination.pageLabel:RemoveAllAnchors()
	pagination.pageLabel:AddAnchor("TOPRIGHT", viewWindow, -rightInset, y + 1)
	pagination.pageLabel:Show(true)

	rightInset = rightInset + PAGE_LABEL_WIDTH + 2
	pagination.prevButton:RemoveAllAnchors()
	pagination.prevButton:AddAnchor("TOPRIGHT", viewWindow, -rightInset, y)
	pagination.prevButton:Show(true)
end

local function UpdateSectionPagination(pagination, page, totalPages)
	if pagination == nil then
		return
	end

	local showPager = totalPages > 1
	pagination.pageLabel:SetText(tostring(page) .. "/" .. tostring(totalPages))
	SetWidgetVisible(pagination.prevButton, showPager)
	SetWidgetVisible(pagination.nextButton, showPager)
	SetWidgetVisible(pagination.pageLabel, showPager)
end

local function CreateSectionPagination(viewWindow, listName, prefix)
	local pagination = {}

	pagination.prevButton = viewWindow:CreateChildWidget("button", prefix .. "PrevButton", 0, true)
	pagination.prevButton:SetStyle("text_default")
	pagination.prevButton:SetText("<")
	pagination.prevButton:SetExtent(PAGE_BUTTON_WIDTH, PAGE_BUTTON_HEIGHT)

	pagination.pageLabel = CreateLabel(
		viewWindow,
		prefix .. "PageLabel",
		"1/1",
		PAGE_LABEL_WIDTH,
		18,
		0,
		0,
		10,
		{ 0.72, 0.86, 1, 1 }
	)
	pagination.pageLabel.style:SetAlign(ALIGN_CENTER)

	pagination.nextButton = viewWindow:CreateChildWidget("button", prefix .. "NextButton", 0, true)
	pagination.nextButton:SetStyle("text_default")
	pagination.nextButton:SetText(">")
	pagination.nextButton:SetExtent(PAGE_BUTTON_WIDTH, PAGE_BUTTON_HEIGHT)

	function pagination.prevButton:OnClick()
		local page = GetSectionPage(listName)
		if page > 1 then
			SetSectionPage(listName, page - 1)
			UpdateViewWindow()
		end
	end
	pagination.prevButton:SetHandler("OnClick", pagination.prevButton.OnClick)

	function pagination.nextButton:OnClick()
		local keys = BuildOrderedKeys(
			listName == "friendly" and runtime.friendly or runtime.hostile,
			listName == "friendly" and runtime.friendlyOrder or runtime.hostileOrder
		)
		local totalPages = GetTotalPagesForCount(#keys)
		local page = GetSectionPage(listName)
		if page < totalPages then
			SetSectionPage(listName, page + 1)
			UpdateViewWindow()
		end
	end
	pagination.nextButton:SetHandler("OnClick", pagination.nextButton.OnClick)

	return pagination
end

local function LayoutViewSection(listName, titleLabel, titleText, list, order, y, color, pagination)
	local keys = BuildOrderedKeys(list, order)
	local count = #keys
	local page, totalPages = ClampSectionPage(listName, count)
	local pageStart = ((page - 1) * VIEW_ROWS_PER_PAGE) + 1
	local sectionStartY = y

	titleLabel:SetText(titleText .. " (" .. tostring(count) .. ")")
	titleLabel:RemoveAllAnchors()
	titleLabel:AddAnchor("TOPLEFT", runtime.viewWindow, PADDING, y)
	titleLabel:Show(true)
	PositionSectionPagination(pagination, y)
	UpdateSectionPagination(pagination, page, totalPages)
	y = y + VIEW_SECTION_HEADER_HEIGHT

	local visibleIndex = 1
	for slot = 1, VIEW_ROWS_PER_PAGE do
		local keyIndex = pageStart + slot - 1
		local rowY = y + ((slot - 1) * VIEW_ROW_HEIGHT)
		if keyIndex <= count then
			local key = keys[keyIndex]
			local row = EnsureViewRow(listName, visibleIndex)
			PositionViewRow(row, listName, key, GetEntryName(list[key]), rowY, color)
			visibleIndex = visibleIndex + 1
		end
	end

	HideUnusedViewRows(listName, visibleIndex)
	return sectionStartY + VIEW_SECTION_HEADER_HEIGHT + (VIEW_ROWS_PER_PAGE * VIEW_ROW_HEIGHT) + VIEW_SECTION_GAP
end

UpdateViewWindow = function()
	local viewWindow = runtime.viewWindow
	if viewWindow == nil then
		return
	end

	local pending = runtime.removeConfirm
	if pending ~= nil then
		local list = pending.listName == "friendly" and runtime.friendly or runtime.hostile
		if pending.key == nil or list[pending.key] == nil then
			runtime.removeConfirm = nil
		end
	end

	local y = 38
	y = LayoutViewSection(
		"friendly",
		viewWindow.friendlyTitle,
		"Friendly",
		runtime.friendly,
		runtime.friendlyOrder,
		y,
		{ 0.45, 1, 0.55, 1 },
		viewWindow.friendlyPagination
	)
	y = LayoutViewSection(
		"hostile",
		viewWindow.hostileTitle,
		"Hostile",
		runtime.hostile,
		runtime.hostileOrder,
		y,
		{ 1, 0.42, 0.42, 1 },
		viewWindow.hostilePagination
	)

	viewWindow:SetExtent(VIEW_WINDOW_WIDTH, VIEW_HEIGHT)
end

local function CreateViewWindow()
	if runtime.viewWindow ~= nil then
		return runtime.viewWindow
	end

	local viewX, viewY = LoadPosition(VIEW_POSITION_KEY, 710, 360, LEGACY_VIEW_POSITION_KEY)
	local viewWindow = CreateEmptyWindow("dpsBasicsUnitTrackerViewWindow", "UIParent")
	runtime.viewWindow = viewWindow
	viewWindow:SetExtent(VIEW_WINDOW_WIDTH, VIEW_HEIGHT)
	viewWindow:AddAnchor("TOPLEFT", "UIParent", viewX, viewY)
	viewWindow:EnableDrag(true)
	viewWindow:Clickable(true)
	viewWindow:Show(false)

	local background = viewWindow:CreateColorDrawable(0, 0, 0, 0.72, "background")
	background:AddAnchor("TOPLEFT", viewWindow, 0, 0)
	background:AddAnchor("BOTTOMRIGHT", viewWindow, 0, 0)

	viewWindow.titleLabel = CreateLabel(
		viewWindow,
		"dpsBasicsUnitTrackerViewTitle",
		"Unit Lists",
		VIEW_WINDOW_WIDTH - 58,
		22,
		PADDING,
		8,
		13,
		{ 0.95, 0.92, 0.82, 1 }
	)
	SafeCall(viewWindow.titleLabel, "EnableDrag", true)

	viewWindow.closeButton = viewWindow:CreateChildWidget("button", "dpsBasicsUnitTrackerViewCloseButton", 0, true)
	viewWindow.closeButton:SetStyle("text_default")
	viewWindow.closeButton:SetText("X")
	viewWindow.closeButton:SetExtent(30, 20)
	viewWindow.closeButton:AddAnchor("TOPRIGHT", viewWindow, -PADDING, 8)

	viewWindow.friendlyTitle =
		CreateLabel(viewWindow, "dpsBasicsUnitTrackerViewFriendlyTitle", "", VIEW_WINDOW_WIDTH - 120, 20, PADDING, 38, 12, {
			0.45,
			1,
			0.55,
			1,
		})
	viewWindow.hostileTitle =
		CreateLabel(viewWindow, "dpsBasicsUnitTrackerViewHostileTitle", "", VIEW_WINDOW_WIDTH - 120, 20, PADDING, 64, 12, {
			1,
			0.42,
			0.42,
			1,
		})
	viewWindow.friendlyPagination = CreateSectionPagination(
		viewWindow,
		"friendly",
		"dpsBasicsUnitTrackerViewFriendly"
	)
	viewWindow.hostilePagination = CreateSectionPagination(
		viewWindow,
		"hostile",
		"dpsBasicsUnitTrackerViewHostile"
	)

	function viewWindow:OnDragStart()
		self:StartMoving()
	end
	viewWindow:SetHandler("OnDragStart", viewWindow.OnDragStart)

	function viewWindow:OnDragStop()
		self:StopMovingOrSizing()
		SaveViewWindowPosition()
	end
	viewWindow:SetHandler("OnDragStop", viewWindow.OnDragStop)

	function viewWindow.titleLabel:OnDragStart()
		viewWindow:StartMoving()
	end
	viewWindow.titleLabel:SetHandler("OnDragStart", viewWindow.titleLabel.OnDragStart)

	function viewWindow.titleLabel:OnDragStop()
		viewWindow:StopMovingOrSizing()
		SaveViewWindowPosition()
	end
	viewWindow.titleLabel:SetHandler("OnDragStop", viewWindow.titleLabel.OnDragStop)

	function viewWindow.closeButton:OnClick()
		runtime.removeConfirm = nil
		viewWindow:Show(false)
	end
	viewWindow.closeButton:SetHandler("OnClick", viewWindow.closeButton.OnClick)

	return viewWindow
end

local function OpenViewWindow()
	local viewWindow = CreateViewWindow()
	UpdateViewWindow()
	viewWindow:Show(true)
end

local function CreateOptsWindow()
	if runtime.optsWindow ~= nil then
		return runtime.optsWindow
	end

	local optsX, optsY = LoadPosition(OPTS_POSITION_KEY, 520, 360)
	local optsWindow = CreateEmptyWindow("dpsBasicsUnitTrackerOptsWindow", "UIParent")
	runtime.optsWindow = optsWindow
	optsWindow:SetExtent(OPTS_WINDOW_WIDTH, OPTS_WINDOW_HEIGHT)
	optsWindow:AddAnchor("TOPLEFT", "UIParent", optsX, optsY)
	optsWindow:EnableDrag(true)
	optsWindow:Clickable(true)
	optsWindow:Show(false)

	local background = optsWindow:CreateColorDrawable(0, 0, 0, 0.72, "background")
	background:AddAnchor("TOPLEFT", optsWindow, 0, 0)
	background:AddAnchor("BOTTOMRIGHT", optsWindow, 0, 0)

	optsWindow.titleLabel = CreateLabel(
		optsWindow,
		"dpsBasicsUnitTrackerOptsTitle",
		"Opts",
		OPTS_WINDOW_WIDTH - 58,
		22,
		PADDING,
		8,
		13,
		{ 0.95, 0.92, 0.82, 1 }
	)
	SafeCall(optsWindow.titleLabel, "EnableDrag", true)

	optsWindow.closeButton = optsWindow:CreateChildWidget("button", "dpsBasicsUnitTrackerOptsCloseButton", 0, true)
	optsWindow.closeButton:SetStyle("text_default")
	optsWindow.closeButton:SetText("X")
	optsWindow.closeButton:SetExtent(30, 20)
	optsWindow.closeButton:AddAnchor("TOPRIGHT", optsWindow, -PADDING, 8)

	optsWindow.viewListButton = CreateButton(
		optsWindow,
		"dpsBasicsUnitTrackerOptsViewListButton",
		"View List",
		PADDING,
		38
	)
	optsWindow.viewListButton:SetExtent(OPTS_WINDOW_WIDTH - (PADDING * 2), BUTTON_HEIGHT)

	optsWindow.exportButton = CreateButton(
		optsWindow,
		"dpsBasicsUnitTrackerOptsExportButton",
		"Export",
		PADDING,
		38 + BUTTON_HEIGHT + BUTTON_GAP
	)
	optsWindow.exportButton:SetExtent(OPTS_WINDOW_WIDTH - (PADDING * 2), BUTTON_HEIGHT)

	function optsWindow:OnDragStart()
		self:StartMoving()
	end
	optsWindow:SetHandler("OnDragStart", optsWindow.OnDragStart)

	function optsWindow:OnDragStop()
		self:StopMovingOrSizing()
		SaveOptsWindowPosition()
	end
	optsWindow:SetHandler("OnDragStop", optsWindow.OnDragStop)

	function optsWindow.titleLabel:OnDragStart()
		optsWindow:StartMoving()
	end
	optsWindow.titleLabel:SetHandler("OnDragStart", optsWindow.titleLabel.OnDragStart)

	function optsWindow.titleLabel:OnDragStop()
		optsWindow:StopMovingOrSizing()
		SaveOptsWindowPosition()
	end
	optsWindow.titleLabel:SetHandler("OnDragStop", optsWindow.titleLabel.OnDragStop)

	function optsWindow.closeButton:OnClick()
		SaveOptsWindowPosition()
		optsWindow:Show(false)
	end
	optsWindow.closeButton:SetHandler("OnClick", optsWindow.closeButton.OnClick)

	function optsWindow.viewListButton:OnClick()
		OpenViewWindow()
	end
	optsWindow.viewListButton:SetHandler("OnClick", optsWindow.viewListButton.OnClick)

	function optsWindow.exportButton:OnClick()
		ExportPlayerLists()
	end
	optsWindow.exportButton:SetHandler("OnClick", optsWindow.exportButton.OnClick)

	return optsWindow
end

local function OpenOptsWindow()
	local optsWindow = CreateOptsWindow()
	optsWindow:Show(true)
end

local function HideTrackerWindow()
	runtime.removeConfirm = nil
	if runtime.window ~= nil then
		runtime.window:Show(false)
	end
	if runtime.optsWindow ~= nil then
		runtime.optsWindow:Show(false)
	end
	if runtime.viewWindow ~= nil then
		runtime.viewWindow:Show(false)
	end
	if runtime.noteWindow ~= nil then
		runtime.noteWindow:Show(false)
	end
end

local function ShowTrackerWindow()
	if runtime.window ~= nil then
		runtime.window:Show(true)
		RefreshTargetState()
	end
end

local function OpenTrackerWindowForIncomingDamage()
	if runtime.window == nil or runtime.window:IsVisible() then
		return
	end
	local now = Now()
	if now - (tonumber(runtime.lastAutoOpenTime) or 0) < AUTO_OPEN_COOLDOWN_SECONDS then
		return
	end
	runtime.lastAutoOpenTime = now
	ShowTrackerWindow()
end

local function HandleCombatTextMessage(...)
	local msg = ParseCombatTextMessage(...)
	if not IsDamageCombatText(msg) or not IsLocalPlayerUnitId(msg.targetUnitId) then
		return
	end
	if IsLocalPlayerUnitId(msg.sourceUnitId) then
		return
	end

	local sourceInfo = GetUnitInfoById(msg.sourceUnitId)
	if type(sourceInfo) ~= "table" or sourceInfo.type ~= "character" then
		return
	end

	local sourceName = GetUnitNameById(msg.sourceUnitId, sourceInfo)
	if not IsValidName(sourceName) or IsLocalPlayerName(sourceName) then
		return
	end

	RememberRecentPlayerDamageSourceName(sourceName)
	-- Only open from COMBAT_TEXT when it confirms a pending incoming-damage COMBAT_MSG source.
	if IsPendingDamageSourceName(sourceName) then
		OpenTrackerWindowForIncomingDamage()
	end
end

local function CreateTrackerWindow()
	local windowX, windowY = LoadPosition(POSITION_KEY, 460, 360, LEGACY_POSITION_KEY)
	local window = CreateEmptyWindow("dpsBasicsUnitTrackerWindow", "UIParent")
	runtime.window = window
	window:SetExtent(WINDOW_WIDTH, WINDOW_HEIGHT)
	window:AddAnchor("TOPLEFT", "UIParent", windowX, windowY)
	window:EnableDrag(true)
	window:Clickable(true)
	window:Show(false)

	local background = window:CreateColorDrawable(0, 0, 0, 0.68, "background")
	background:AddAnchor("TOPLEFT", window, 0, 0)
	background:AddAnchor("BOTTOMRIGHT", window, 0, 0)

	window.titleLabel = CreateLabel(window, "dpsBasicsUnitTrackerTitle", "Unit Tracker", WINDOW_WIDTH - 58, 22, PADDING, 8, 13, {
		0.95,
		0.92,
		0.82,
		1,
	})
	SafeCall(window.titleLabel, "EnableDrag", true)

	window.closeButton = window:CreateChildWidget("button", "dpsBasicsUnitTrackerCloseButton", 0, true)
	window.closeButton:SetStyle("text_default")
	window.closeButton:SetText("X")
	window.closeButton:SetExtent(30, 20)
	window.closeButton:AddAnchor("TOPRIGHT", window, -PADDING, 8)

	local function BindNotePreviewClick(label)
		SafeCall(label, "Clickable", true)
		SafeCall(label, "EnablePick", true)
		SafeCall(label, "EnableHitTest", true)
		SafeCall(label, "SetHitTestEnabled", true)
		function label:OnClick()
			local key = self.trackedKey
			if key == nil or key == "" then
				key = GetTrackedKeyForRecord(runtime.currentTarget)
			end
			if key ~= nil and key ~= "" then
				OpenNoteWindow(key)
			end
		end
		label:SetHandler("OnClick", label.OnClick)
	end

	window.noteLine1 = CreateLabel(
		window,
		"dpsBasicsUnitTrackerNoteLine1",
		"",
		NOTE_PREVIEW_WIDTH,
		NOTE_PREVIEW_LINE_HEIGHT,
		PADDING,
		NOTE_PREVIEW_TOP,
		11,
		{ 0.9, 0.9, 0.9, 1 }
	)
	window.noteLine2 = CreateLabel(
		window,
		"dpsBasicsUnitTrackerNoteLine2",
		"",
		NOTE_PREVIEW_WIDTH,
		NOTE_PREVIEW_LINE_HEIGHT,
		PADDING,
		NOTE_PREVIEW_TOP + NOTE_PREVIEW_LINE_HEIGHT,
		11,
		{ 0.9, 0.9, 0.9, 1 }
	)
	SafeCall(window.noteLine1.style, "SetEllipsis", true)
	SafeCall(window.noteLine2.style, "SetEllipsis", true)
	-- Keep a combined clickable hit-area covering both preview lines.
	window.noteLabel = window.noteLine1
	BindNotePreviewClick(window.noteLine1)
	BindNotePreviewClick(window.noteLine2)

	window.friendlyButton = CreateButton(window, "dpsBasicsUnitTrackerFriendlyButton", "Friendly", PADDING, 78)
	SetButtonTextColor(window.friendlyButton, { 0.05, 0.42, 0.12, 1 })
	window.hostileButton = CreateButton(
		window,
		"dpsBasicsUnitTrackerHostileButton",
		"Hostile",
		PADDING + BUTTON_WIDTH + BUTTON_GAP,
		78
	)
	SetButtonTextColor(window.hostileButton, { 1, 0.35, 0.35, 1 })
	window.optsButton = CreateButton(
		window,
		"dpsBasicsUnitTrackerOptsButton",
		"Opts",
		PADDING + ((BUTTON_WIDTH + BUTTON_GAP) * 2),
		78
	)

	function window:OnDragStart()
		self:StartMoving()
	end
	window:SetHandler("OnDragStart", window.OnDragStart)

	function window:OnDragStop()
		self:StopMovingOrSizing()
		SaveWindowPosition()
	end
	window:SetHandler("OnDragStop", window.OnDragStop)

	function window.titleLabel:OnDragStart()
		window:StartMoving()
	end
	window.titleLabel:SetHandler("OnDragStart", window.titleLabel.OnDragStart)

	function window.titleLabel:OnDragStop()
		window:StopMovingOrSizing()
		SaveWindowPosition()
	end
	window.titleLabel:SetHandler("OnDragStop", window.titleLabel.OnDragStop)

	function window.closeButton:OnClick()
		HideTrackerWindow()
	end
	window.closeButton:SetHandler("OnClick", window.closeButton.OnClick)

	function window.friendlyButton:OnClick()
		AddCurrentTargetToList("friendly")
	end
	window.friendlyButton:SetHandler("OnClick", window.friendlyButton.OnClick)

	function window.hostileButton:OnClick()
		AddCurrentTargetToList("hostile")
	end
	window.hostileButton:SetHandler("OnClick", window.hostileButton.OnClick)

	function window.optsButton:OnClick()
		OpenOptsWindow()
	end
	window.optsButton:SetHandler("OnClick", window.optsButton.OnClick)

	function window:OnUpdate(dt)
		if not runtime.active then
			return
		end

		local delta = tonumber(dt) or 0
		if delta > 1 then
			delta = delta / 1000
		end

		runtime.updateElapsed = runtime.updateElapsed + delta
		if runtime.updateElapsed < TARGET_REFRESH_SECONDS then
			return
		end
		runtime.updateElapsed = 0
		RefreshTargetState()
	end
	window:SetHandler("OnUpdate", window.OnUpdate)
end

LoadLists()
CreateTrackerWindow()
RefreshTargetState()

local launchButton = CreateSimpleButton("Unit Tracker", 700, -430)
runtime.launchButton = launchButton
launchButton:SetHandler("OnClick", function()
	if runtime.window ~= nil and runtime.window:IsVisible() then
		HideTrackerWindow()
	else
		ShowTrackerWindow()
	end
end)

local eventWindow = CreateEmptyWindow("dpsBasicsUnitTrackerEventWindow", "UIParent")
runtime.eventWindow = eventWindow
eventWindow:Show(false)

function eventWindow:OnEvent(event, ...)
	if not runtime.active then
		return
	end
	if event == "TARGET_CHANGED" or event == "ENTERED_WORLD" then
		RefreshTargetState()
	elseif event == "COMBAT_MSG" then
		local eventType = tostring(select(2, ...) or "")
		if string.find(eventType, "DAMAGE", 1, true) == nil then
			return
		end
		local sourceName = Trim(select(3, ...) or "")
		local targetName = Trim(select(4, ...) or "")
		if sourceName == "" or targetName == "" then
			return
		end
		local msg = {
			unitId = select(1, ...),
			eventType = eventType,
			sourceName = sourceName,
			targetName = targetName,
			abilityId = select(5, ...),
			effectType = select(8, ...),
		}
		if IsIncomingPlayerDamage(msg) then
			OpenTrackerWindowForIncomingDamage()
		elseif IsIncomingDamageCandidate(msg) then
			RememberPendingDamageSourceName(msg.sourceName)
		end
	elseif event == "COMBAT_TEXT" then
		HandleCombatTextMessage(...)
	end
end
eventWindow:SetHandler("OnEvent", eventWindow.OnEvent)
eventWindow:RegisterEvent("TARGET_CHANGED")
eventWindow:RegisterEvent("ENTERED_WORLD")
eventWindow:RegisterEvent("COMBAT_MSG")
eventWindow:RegisterEvent("COMBAT_TEXT")
