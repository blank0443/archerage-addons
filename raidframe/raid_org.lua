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
ADDON:ImportObject(OBJECT_TYPE.EDITBOX)

ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.TEAM.id)
ADDON:ImportAPI(API_TYPE.CURSOR.id)

local ADDON_KEY = "raidframe_raid_org"
local WINDOW_POSITION_KEY = ADDON_KEY .. "_window_position"
local BUTTON_POSITION_KEY = ADDON_KEY .. "_button_position"
local WINDOW_SIZE_KEY = ADDON_KEY .. "_window_size"
local MENU_POSITION_KEY = ADDON_KEY .. "_menu_position"
local RANGE_WINDOW_POSITION_KEY = ADDON_KEY .. "_range_window_position"
local RANGE_VALUE_KEY = ADDON_KEY .. "_range_value"
local GROUP_ROW_GAP_KEY = ADDON_KEY .. "_group_row_gap"

local DEFAULT_WINDOW_WIDTH = 420
local DEFAULT_WINDOW_HEIGHT = 260
local MIN_WINDOW_WIDTH = 110
local MIN_WINDOW_HEIGHT = 64
local AUTO_WINDOW_MIN_WIDTH = 260
local WINDOW_BACKGROUND_ALPHA = 0.4
local WINDOW_LOCKED_BACKGROUND_ALPHA = 0
local RAID_ORG_UI_LAYER = "hud"
local DEFAULT_RANGE_VALUE = "30"

local MENU_WIDTH = 122
local MENU_BUTTON_HEIGHT = 22
local RANGE_WINDOW_WIDTH = 180
local RANGE_WINDOW_HEIGHT = 158
local RANGE_INPUT_WIDTH = 82
local RANGE_INPUT_HEIGHT = 24
local RANGE_DIGIT_BUTTON_WIDTH = 36
local RANGE_DIGIT_BUTTON_HEIGHT = 22
local RANGE_DIGIT_BUTTON_GAP = 4
local CORNER_HANDLE_SIZE = 18
local RESIZE_GRIP_LINE_ALPHA = 0.32
local RESIZE_GRIP_HOVER_ALPHA = 0.72
local RESIZE_GRIP_LINE_LENGTH = 9
local RESIZE_GRIP_LINE_THICKNESS = 2
local RESIZE_GRIP_INSET = 5
local TOP_BUTTON_WIDTH = 24
local TOP_BUTTON_HEIGHT = 24
local TOP_MENU_BUTTON_WIDTH = TOP_BUTTON_WIDTH
local TOP_MENU_BUTTON_HEIGHT = TOP_BUTTON_HEIGHT
local TOP_BUTTON_X_OFFSET = 15
local TOP_BUTTON_Y_OFFSET = 4
local TOP_BUTTON_GAP = 1
local TOP_BUTTON_COMPACT_RIGHT_OFFSET = 3
local TOP_MENU_BUTTON_COLOR = { 0.86, 0.73, 0.46, 0.92 }
local TOP_MENU_BUTTON_BORDER_COLOR = { 0.36, 0.27, 0.13, 0.95 }
local TOP_CONTROLS_HORIZONTAL_MIN_WIDTH = 330
local MEMBER_MAX_COUNT = 50
local MEMBER_GROUP_SIZE = 5
local MEMBER_GROUP_COLUMNS = 5
local MEMBER_MAX_GROUPS = 10
local MEMBER_GRID_TOP = 34
local MEMBER_GRID_PADDING_X = 22
local MEMBER_GRID_PADDING_Y = 8
local MEMBER_CELL_GAP = 2
local DEFAULT_MEMBER_GROUP_ROW_GAP = 8
local MIN_MEMBER_GROUP_ROW_GAP = 0
local MAX_MEMBER_GROUP_ROW_GAP = 36
local MEMBER_GROUP_ROW_GAP_STEP = 2
local MEMBER_CELL_MIN_WIDTH = 24
local MEMBER_CELL_MIN_HEIGHT = 12
local MEMBER_AUTO_CELL_WIDTH = 78
local MEMBER_AUTO_CELL_HEIGHT = 22
local MEMBER_DISTANCE_WIDTH = 42
local MEMBER_REFRESH_INTERVAL = 0.35
local CONTROL_HOVER_PADDING = 3
local MEMBER_NAME_AVERAGE_CHAR_WIDTH = 5
local ROLE_COLOR_MAP = {
	blue = { bg = { 0.10, 0.22, 0.42, 0.86 }, border = { 0.36, 0.62, 1.00, 0.42 } },
	green = { bg = { 0.08, 0.34, 0.16, 0.86 }, border = { 0.36, 0.94, 0.48, 0.48 } },
	yellow = { bg = { 0.40, 0.34, 0.08, 0.86 }, border = { 1.00, 0.86, 0.32, 0.50 } },
	pink = { bg = { 0.46, 0.18, 0.43, 0.86 }, border = { 1.00, 0.58, 0.92, 0.50 } },
	red = { bg = { 0.40, 0.12, 0.10, 0.86 }, border = { 1.00, 0.44, 0.36, 0.48 } },
	purple = { bg = { 0.30, 0.14, 0.46, 0.86 }, border = { 0.76, 0.48, 1.00, 0.50 } },
}
local ROLE_NUMBER_KEY_MAP = {
	[0] = "blue",
	[1] = "green",
	[2] = "pink",
	[3] = "red",
	[4] = "purple",
}
local DEFAULT_ROLE_COLOR_KEY = "blue"
local OUT_OF_RANGE_CELL_COLOR = {
	bg = { 0.22, 0.22, 0.22, 0.90 },
	border = { 0.55, 0.55, 0.55, 0.95 },
}
local SELECTED_CELL_BORDER_COLOR = { 1.00, 0.86, 0.18, 1.00 }
local SELECT_MODE_CELL_BORDER_COLOR = { 1.00, 1.00, 1.00, 0.22 }

local state = {
	locked = false,
	rangeValue = DEFAULT_RANGE_VALUE,
	rangeInputText = DEFAULT_RANGE_VALUE,
	hpAlertSettingsKey = ADDON_KEY .. "_hp_alert",
	hpAlertWindowPositionKey = ADDON_KEY .. "_hp_alert_window_position",
	hpAlertValue = "50",
	hpAlertInputText = "50",
	hpAlertEnabled = false,
	hpAlertColor = {
		bg = { 1.00, 0.92, 0.02, 0.96 },
		border = { 1.00, 0.98, 0.25, 1.00 },
		text = { 0.08, 0.07, 0.02, 1.00 },
	},
	normalNameColor = { 0.94, 0.95, 0.96, 1.00 },
	activeMemberArea = "raid",
	selectMode = false,
	selectionFilterActive = false,
	outOfRangeMode = false,
	memberRefreshElapsed = 0,
	controlsHidden = false,
	cursorPositionGetter = nil,
	memberGroupRowGap = DEFAULT_MEMBER_GROUP_ROW_GAP,
	memberRoleByName = {},
	selectedMemberByName = {},
	lastAutoLayoutMemberCount = nil,
	lastAutoLayoutRows = nil,
	lastAutoLayoutGroupRows = nil,
	controlHoverGraceRemaining = 0,
}
local rangeLastTextChangeText = nil
local rangeLastCharacterText = nil
local rangeInputDirty = false
local rangeInputProgrammatic = false

local function ResetRangeInputEventState()
	rangeLastTextChangeText = nil
	rangeLastCharacterText = nil
	rangeInputDirty = false
end

local previousRuntime = _G.__RAIDFRAME_RAID_ORG_RUNTIME
if previousRuntime ~= nil then
	if previousRuntime.launcherButton ~= nil then
		previousRuntime.launcherButton:Show(false)
	end
	if previousRuntime.raidWindow ~= nil then
		previousRuntime.raidWindow:Show(false)
	end
	if previousRuntime.menuWindow ~= nil then
		previousRuntime.menuWindow:Show(false)
	end
	if previousRuntime.rangeWindow ~= nil then
		previousRuntime.rangeWindow:Show(false)
	end
	if previousRuntime.hpAlertWindow ~= nil then
		previousRuntime.hpAlertWindow:Show(false)
	end
	if previousRuntime.eventWindow ~= nil then
		previousRuntime.eventWindow:Show(false)
	end
	if previousRuntime.controlHoverWindow ~= nil then
		previousRuntime.controlHoverWindow:Show(false)
	end
	if previousRuntime.resizeHandles ~= nil then
		for _, handle in ipairs(previousRuntime.resizeHandles) do
			handle:Show(false)
		end
	end
end

local runtime = {}
_G.__RAIDFRAME_RAID_ORG_RUNTIME = runtime

local function SafeCall(widget, methodName, ...)
	if widget == nil or widget[methodName] == nil then
		return nil
	end
	return widget[methodName](widget, ...)
end

local function TryCall(target, methodName, ...)
	if target == nil or type(target[methodName]) ~= "function" then
		return false
	end

	local ok = pcall(function(...)
		target[methodName](target, ...)
	end, ...)
	return ok
end

local function ApplyRaidOrgLayer(widget)
	if widget == nil then
		return
	end
	TryCall(widget, "SetUILayer", RAID_ORG_UI_LAYER)
	TryCall(widget, "Raise")
end

local function SaveData(key, value)
	ADDON:ClearData(key)
	ADDON:SaveData(key, value)
end

local function LoadPosition(key, fallbackX, fallbackY)
	local saved = ADDON:LoadData(key)
	if saved ~= nil then
		local x = tonumber(saved.x)
		local y = tonumber(saved.y)
		if x ~= nil and y ~= nil then
			local maxX = 4000
			local maxY = 3000
			if UIParent ~= nil then
				if type(UIParent.GetWidth) == "function" then
					maxX = tonumber(UIParent:GetWidth()) or maxX
				end
				if type(UIParent.GetHeight) == "function" then
					maxY = tonumber(UIParent:GetHeight()) or maxY
				end
			end
			if x < -100 or y < -100 or x > maxX - 20 or y > maxY - 20 then
				return fallbackX, fallbackY
			end
			return x, y
		end
	end
	return fallbackX, fallbackY
end

local function LoadSize()
	local saved = ADDON:LoadData(WINDOW_SIZE_KEY)
	if saved ~= nil then
		local width = tonumber(saved.width)
		local height = tonumber(saved.height)
		if width ~= nil and height ~= nil then
			if width < MIN_WINDOW_WIDTH then
				width = MIN_WINDOW_WIDTH
			end
			if height < MIN_WINDOW_HEIGHT then
				height = MIN_WINDOW_HEIGHT
			end
			return width, height
		end
	end
	return DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT
end

local function LoadRangeValue()
	local function loadedValue(value)
		if value == nil then
			return nil
		end
		value = tostring(value):match("^%s*(.-)%s*$")
		if value ~= "" and value ~= "0" and string.match(value, "^%d+$") then
			return value
		end
		return nil
	end

	local saved = ADDON:LoadData(RANGE_VALUE_KEY)
	if type(saved) == "table" then
		return loadedValue(saved.value) or DEFAULT_RANGE_VALUE
	end
	return loadedValue(saved) or DEFAULT_RANGE_VALUE
end

local function ClampGroupRowGap(value)
	local gap = tonumber(value) or DEFAULT_MEMBER_GROUP_ROW_GAP
	if gap < MIN_MEMBER_GROUP_ROW_GAP then
		return MIN_MEMBER_GROUP_ROW_GAP
	end
	if gap > MAX_MEMBER_GROUP_ROW_GAP then
		return MAX_MEMBER_GROUP_ROW_GAP
	end
	return gap
end

local function LoadGroupRowGap()
	local saved = ADDON:LoadData(GROUP_ROW_GAP_KEY)
	if type(saved) == "table" then
		return ClampGroupRowGap(saved.value)
	end
	return ClampGroupRowGap(saved)
end

local function GetSavedWidgetPosition(widget)
	local x, y = widget:GetOffset()
	local uiScale = UIParent:GetUIScale() or 1.0
	return x * uiScale, y * uiScale
end

local function SaveWidgetPosition(widget, key)
	local x, y = GetSavedWidgetPosition(widget)
	SaveData(key, { x = x, y = y })
end

local function SaveWindowSize(window)
	local width = window:GetWidth()
	local height = window:GetHeight()
	SaveData(WINDOW_SIZE_KEY, { width = width, height = height })
end

local function SetWidgetPoint(widget, x, y)
	widget:RemoveAllAnchors()
	widget:AddAnchor("TOPLEFT", "UIParent", x, y)
end

local function FirstStringArg(...)
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if type(value) == "string" then
			return value
		end
	end
	return nil
end

local function FirstInputArg(...)
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if type(value) == "string" or type(value) == "number" then
			return value
		end
	end
	return nil
end

local function NormalizeKeyToken(value)
	if value == nil then
		return nil
	end

	local token = string.lower(tostring(value))
	token = string.gsub(token, "%s+", "")
	token = string.gsub(token, "_", "")
	token = string.gsub(token, "-", "")
	return token
end

local function DropLastCharacter(text)
	local len = string.len(text or "")
	if len <= 0 then
		return ""
	end

	return string.sub(text, 1, len - 1)
end

local function PrintableDigitText(value)
	if type(value) == "number" then
		if value >= 48 and value <= 57 then
			return string.char(value)
		end
		if value >= 96 and value <= 105 then
			return tostring(value - 96)
		end
		return nil
	end

	if type(value) ~= "string" or value == "" then
		return nil
	end

	if string.match(value, "^%d+$") then
		return value
	end

	local numericValue = tonumber(value)
	if numericValue ~= nil and numericValue >= 48 and numericValue <= 57 then
		return string.char(numericValue)
	end

	return nil
end

local function StoreRangeInputText(text)
	if text == nil then
		return
	end

	local textValue = tostring(text):match("^%s*(.-)%s*$")
	state.rangeInputText = textValue
end

local rangeInputGetterCandidates = {
	{ name = "GetText" },
	{ name = "GetDisplayText" },
	{ name = "GetInputText" },
	{ name = "GetString" },
	{ name = "GetEditText" },
	{ name = "GetValue", arg = "text" },
	{ name = "GetValue", arg = "string" },
	{ name = "GetValue", arg = "value" },
}

local function NormalizeRangeInputText(text)
	if text == nil then
		return nil
	end

	local value = tostring(text):match("^%s*(.-)%s*$")
	if value == "" or not string.match(value, "^%d+$") then
		return nil
	end

	local currentValueText = tostring(state.rangeValue or "")
	if currentValueText ~= ""
		and value ~= currentValueText
		and string.sub(value, 1, string.len(currentValueText)) == currentValueText then
		value = string.sub(value, string.len(currentValueText) + 1)
	end

	if value == "0" then
		return nil
	end
	return value
end

local function ReadRangeInputText(input)
	if input == nil then
		return nil
	end

	local fallbackValue = nil
	local currentValueText = tostring(state.rangeValue or "")
	for _, candidate in ipairs(rangeInputGetterCandidates) do
		local fn = input[candidate.name]
		if type(fn) == "function" then
			local ok, text = pcall(function()
				if candidate.arg ~= nil then
					return fn(input, candidate.arg)
				end
				return fn(input)
			end)
			if ok then
				local value = NormalizeRangeInputText(text)
				if value ~= nil then
					if currentValueText == "" or value ~= currentValueText then
						return value
					end
					fallbackValue = fallbackValue or value
				end
			end
		end
	end

	return fallbackValue
end

local function SetRangeInputText(input, text)
	local textValue = tostring(text or "")
	rangeInputProgrammatic = true
	TryCall(input, "SetText", textValue)
	TryCall(input, "SetInputText", textValue)
	TryCall(input, "SetEditText", textValue)
	TryCall(input, "SetDisplayText", textValue)
	TryCall(input, "SetString", textValue)
	if input ~= nil and input.rangeDisplayLabel ~= nil then
		input.rangeDisplayLabel:SetText(textValue)
	end
	rangeInputProgrammatic = false
end

local function FocusRangeInput(input)
	if input == nil then
		return
	end
	TryCall(input, "Show", true)
	TryCall(input, "Enable", true)
	TryCall(input, "Clickable", true)
	TryCall(input, "SetFocus", true)
end

local function SetRangeDraftText(input, text)
	StoreRangeInputText(text or "")
	SetRangeInputText(input, state.rangeInputText)
	rangeInputDirty = true
	rangeLastTextChangeText = state.rangeInputText
	rangeLastCharacterText = nil
end

local function AppendRangeDigit(input, digit)
	local digitText = tostring(digit or "")
	if not string.match(digitText, "^%d$") then
		return
	end

	local nextText = ""
	if rangeInputDirty then
		nextText = tostring(state.rangeInputText or "")
	end
	nextText = nextText .. digitText
	if string.len(nextText) > 4 then
		nextText = string.sub(nextText, -4)
	end
	SetRangeDraftText(input, nextText)
end

local function DropRangeDraftCharacter(input)
	local text = DropLastCharacter(state.rangeInputText)
	SetRangeDraftText(input, text)
end

local function AppendRangeInputText(text)
	local digitText = PrintableDigitText(text)
	if digitText == nil then
		return
	end
	if rangeLastCharacterText == digitText then
		return
	end
	rangeLastCharacterText = digitText

	if rangeLastTextChangeText ~= nil and string.sub(rangeLastTextChangeText, -string.len(digitText)) == digitText then
		rangeLastTextChangeText = nil
		return
	end

	local nextText
	if rangeInputDirty then
		nextText = state.rangeInputText .. digitText
	else
		nextText = digitText
	end
	if string.len(nextText) > 4 then
		nextText = string.sub(nextText, -4)
	end
	StoreRangeInputText(nextText)
	rangeInputDirty = true
end

local function HandleRangeInputKey(...)
	local key = FirstInputArg(...)
	local token = NormalizeKeyToken(key)
	rangeLastTextChangeText = nil
	rangeLastCharacterText = nil
	if token == "backspace" or token == "back" or token == "8" or token == "delete" or token == "del" or token == "46" then
		state.rangeInputText = DropLastCharacter(state.rangeInputText)
		rangeInputDirty = true
	elseif token == "escape" or token == "esc" or token == "27" then
		state.rangeInputText = ""
		rangeInputDirty = true
	end
end

local function HideMenu()
	if runtime.menuWindow ~= nil then
		runtime.menuWindow:Show(false)
	end
	if runtime.rangeWindow ~= nil then
		runtime.rangeWindow:Show(false)
	end
	if runtime.hpAlertWindow ~= nil then
		runtime.hpAlertWindow:Show(false)
	end
end

local UpdateAllMemberCells
local ApplyAllCellVisuals
local EnableHitTesting
local DisableHitTesting
local ApplyControlButtonsVisibility
local ApplyLockState
local PositionResizeHandles
local LayoutMemberCells
local LayoutTopControls
local ApplyControlHoverWindow
local UpdateMemberDistances
local SetControlButtonsHidden
local UpdateControlHover
local HideControlsIfCursorIsOutside
local ToggleSelectMode
local ToggleOutOfRangeMode

local function SetWidgetVisible(widget, visible)
	if widget ~= nil then
		widget:Show(visible)
	end
end

local function IsWidgetVisible(widget)
	return widget ~= nil and type(widget.IsVisible) == "function" and widget:IsVisible()
end

local function SetWidgetAlpha(widget, alpha)
	TryCall(widget, "SetAlpha", alpha)
	TryCall(widget, "SetOpacity", alpha)
end

local function SetDrawableVisible(drawable, visible)
	if drawable ~= nil and type(drawable.SetVisible) == "function" then
		drawable:SetVisible(visible)
	end
end

local function SetButtonDefaultBackgroundVisible(button, visible)
	if button == nil or button.bgs == nil then
		return
	end

	for _, background in pairs(button.bgs) do
		SetDrawableVisible(background, visible)
	end
end

local function SetMenuButtonVisualVisible(visible)
	SetDrawableVisible(runtime.menuButtonBackground, visible)
	SetDrawableVisible(runtime.menuButtonBorderTop, visible)
	SetDrawableVisible(runtime.menuButtonBorderBottom, visible)
	SetDrawableVisible(runtime.menuButtonBorderLeft, visible)
	SetDrawableVisible(runtime.menuButtonBorderRight, visible)
end

local function AttachControlHoverHandlers(widget)
	if widget == nil or type(widget.SetHandler) ~= "function" then
		return
	end

	function widget:OnEnter()
		state.controlHoverGraceRemaining = 0
		SetControlButtonsHidden(false)
	end
	widget:SetHandler("OnEnter", widget.OnEnter)

	function widget:OnLeave()
		if state.locked then
			state.controlHoverGraceRemaining = 0.35
		else
			HideControlsIfCursorIsOutside()
		end
	end
	widget:SetHandler("OnLeave", widget.OnLeave)
end

local function ExtractCursorPosition(x, y)
	if type(x) == "table" then
		return tonumber(x.x or x[1] or x.posX or x.left), tonumber(x.y or x[2] or x.posY or x.top)
	end
	return tonumber(x), tonumber(y)
end

local function TryGetCursorPositionFrom(source, methodName)
	if source == nil or type(source[methodName]) ~= "function" then
		return nil, nil
	end

	local ok, x, y = pcall(function()
		return source[methodName](source)
	end)
	x, y = ExtractCursorPosition(x, y)
	if ok and x ~= nil and y ~= nil then
		return x, y
	end

	ok, x, y = pcall(function()
		return source[methodName]()
	end)
	x, y = ExtractCursorPosition(x, y)
	if ok and x ~= nil and y ~= nil then
		return x, y
	end
	return nil, nil
end

local function FindCursorPositionGetter()
	local candidates = {
		{ X2Cursor, "GetCursorPosition" },
		{ X2Cursor, "GetMousePosition" },
		{ X2Cursor, "GetCursorPos" },
		{ X2Cursor, "GetPosition" },
		{ UIParent, "GetCursorPosition" },
		{ UIParent, "GetMousePosition" },
	}

	for _, candidate in ipairs(candidates) do
		local source = candidate[1]
		local methodName = candidate[2]
		local x, y = TryGetCursorPositionFrom(source, methodName)
		if x ~= nil and y ~= nil then
			return function()
				return TryGetCursorPositionFrom(source, methodName)
			end
		end
	end

	return nil
end

local function GetCursorPosition()
	if state.cursorPositionGetter == nil then
		state.cursorPositionGetter = FindCursorPositionGetter()
	end
	if state.cursorPositionGetter == nil then
		return nil, nil
	end
	return state.cursorPositionGetter()
end

local function IsPointInWidget(widget, x, y, padding)
	if widget == nil or x == nil or y == nil or not widget:IsVisible() then
		return false
	end

	local wx, wy = widget:GetOffset()
	local width = widget:GetWidth()
	local height = widget:GetHeight()
	local pad = padding or 0
	return x >= wx - pad and x <= wx + width + pad and y >= wy - pad and y <= wy + height + pad
end

local function IsCursorOverRaidOrgControls(x, y)
	return IsPointInWidget(runtime.closeButton, x, y, CONTROL_HOVER_PADDING)
		or IsPointInWidget(runtime.menuButton, x, y, CONTROL_HOVER_PADDING)
		or IsPointInWidget(runtime.memberAreaButton, x, y, CONTROL_HOVER_PADDING)
		or IsPointInWidget(runtime.menuWindow, x, y, CONTROL_HOVER_PADDING)
end

local function IsCursorOverRaidOrg(x, y)
	return IsPointInWidget(runtime.raidWindow, x, y, CONTROL_HOVER_PADDING) or IsCursorOverRaidOrgControls(x, y)
end

HideControlsIfCursorIsOutside = function()
	if IsWidgetVisible(runtime.menuWindow) then
		return
	end

	local x, y = GetCursorPosition()
	if x == nil or y == nil then
		SetControlButtonsHidden(true)
		return
	end

	SetControlButtonsHidden(not IsCursorOverRaidOrg(x, y))
end

SetControlButtonsHidden = function(hidden)
	if state.controlsHidden == hidden then
		return
	end

	state.controlsHidden = hidden
	ApplyControlButtonsVisibility()
	if LayoutTopControls ~= nil then
		LayoutTopControls()
	end
	ApplyLockState()
end

UpdateControlHover = function(dt)
	local raidWindow = runtime.raidWindow
	if not IsWidgetVisible(raidWindow) then
		return
	end

	local delta = dt or 0
	if delta > 1 then
		delta = delta / 1000
	end
	if state.controlHoverGraceRemaining > 0 then
		state.controlHoverGraceRemaining = state.controlHoverGraceRemaining - delta
		return
	end

	local x, y = GetCursorPosition()
	if x == nil or y == nil then
		return
	end

	SetControlButtonsHidden(not IsCursorOverRaidOrg(x, y))
end

ApplyControlHoverWindow = function()
	local hoverWindow = runtime.controlHoverWindow
	local raidWindow = runtime.raidWindow
	if hoverWindow == nil or raidWindow == nil then
		return
	end

	local showWakeTarget = state.locked
		and not IsWidgetVisible(runtime.menuWindow)
		and IsWidgetVisible(raidWindow)
	hoverWindow:Show(showWakeTarget)
	if not showWakeTarget then
		DisableHitTesting(hoverWindow)
		return
	end

	hoverWindow:RemoveAllAnchors()
	local memberAreaWidth = 0
	if state.locked and runtime.memberAreaButton ~= nil and IsWidgetVisible(runtime.memberAreaButton) then
		memberAreaWidth = runtime.memberAreaButton:GetWidth() + 7 + CONTROL_HOVER_PADDING
	end
	hoverWindow:AddAnchor("TOPLEFT", raidWindow, memberAreaWidth, 0)
	local hoverWidth = raidWindow:GetWidth() - memberAreaWidth
	local excludedControlWidth = TOP_BUTTON_X_OFFSET + TOP_BUTTON_WIDTH + TOP_BUTTON_GAP + TOP_MENU_BUTTON_WIDTH + CONTROL_HOVER_PADDING
	if runtime.compactTopControls then
		excludedControlWidth = TOP_BUTTON_COMPACT_RIGHT_OFFSET + TOP_BUTTON_WIDTH + TOP_BUTTON_GAP + TOP_MENU_BUTTON_WIDTH + CONTROL_HOVER_PADDING
	end
	hoverWidth = hoverWidth - excludedControlWidth
	if hoverWidth < 1 then
		hoverWidth = 1
	end
	hoverWindow:SetExtent(hoverWidth, MEMBER_GRID_TOP)
	ApplyRaidOrgLayer(hoverWindow)
	EnableHitTesting(hoverWindow)
	TryCall(hoverWindow, "Raise")
end

ApplyControlButtonsVisibility = function()
	local menuVisible = IsWidgetVisible(runtime.menuWindow)
	local controlsVisible = not state.controlsHidden or menuVisible
	local showMenuButton = controlsVisible or state.locked
	local showMemberAreaButton = controlsVisible or state.locked
	local showRaidControls = controlsVisible and not state.locked

	SetWidgetVisible(runtime.closeButton, showRaidControls)
	SetWidgetVisible(runtime.menuButton, showMenuButton)
	SetWidgetVisible(runtime.menuButtonLabel, showMenuButton)
	SetMenuButtonVisualVisible(showMenuButton)
	SetWidgetVisible(runtime.memberAreaButton, showMemberAreaButton)
	SetWidgetVisible(runtime.memberAreaLabel, false)
	if runtime.menuButton ~= nil then
		runtime.menuButton:SetText("")
		SafeCall(runtime.menuButton, "SetAutoResize", false)
		runtime.menuButton:SetExtent(TOP_MENU_BUTTON_WIDTH, TOP_MENU_BUTTON_HEIGHT)
		SetButtonDefaultBackgroundVisible(runtime.menuButton, false)
		SetWidgetAlpha(runtime.menuButton, 1)
	end
	if runtime.menuButtonLabel ~= nil then
		runtime.menuButtonLabel:SetText("M")
	end

	if showMenuButton then
		EnableHitTesting(runtime.menuButton)
	else
		DisableHitTesting(runtime.menuButton)
	end
	DisableHitTesting(runtime.menuButtonLabel)

	if showRaidControls then
		EnableHitTesting(runtime.closeButton)
	else
		DisableHitTesting(runtime.closeButton)
	end

	if showMemberAreaButton then
		EnableHitTesting(runtime.memberAreaButton)
	else
		DisableHitTesting(runtime.memberAreaButton)
	end

	ApplyControlHoverWindow()
end

local function ApplyRaidWindowBackground()
	local background = runtime.raidWindowBackground
	if background == nil then
		return
	end

	if state.locked then
		TryCall(background, "SetColor", 0, 0, 0, WINDOW_LOCKED_BACKGROUND_ALPHA)
		TryCall(background, "SetVisible", false)
		TryCall(background, "Show", false)
	else
		TryCall(background, "SetVisible", true)
		TryCall(background, "Show", true)
		TryCall(background, "SetColor", 0, 0, 0, WINDOW_BACKGROUND_ALPHA)
	end
end

ApplyLockState = function()
	local raidWindow = runtime.raidWindow

	if raidWindow ~= nil then
		raidWindow:EnableDrag(not state.locked)
		ApplyRaidOrgLayer(raidWindow)
		if state.locked then
			DisableHitTesting(raidWindow)
			DisableHitTesting(runtime.raidWindowBackground)
		else
			EnableHitTesting(raidWindow)
		end
	end

	ApplyRaidWindowBackground()
	ApplyControlButtonsVisibility()

	if runtime.lockButton ~= nil then
		if state.locked then
			runtime.lockButton:SetText("Unlock")
		else
			runtime.lockButton:SetText("Lock")
		end
	end

	for _, handle in ipairs(runtime.resizeHandles or {}) do
		handle:Show(not state.locked and runtime.raidWindow ~= nil and runtime.raidWindow:IsVisible())
		if not state.locked and runtime.raidWindow ~= nil and runtime.raidWindow:IsVisible() then
			EnableHitTesting(handle)
			TryCall(handle, "Raise")
		end
	end

	if runtime.memberCells ~= nil then
		for _, cell in ipairs(runtime.memberCells) do
			if state.selectMode and not state.locked and cell.memberName ~= nil then
				EnableHitTesting(cell)
			else
				DisableHitTesting(cell)
			end
			DisableHitTesting(cell.nameLabel)
			DisableHitTesting(cell.distanceLabel)
		end
		ApplyAllCellVisuals()
	end
end

local function ApplyModeButtons()
	if runtime.rangeButton ~= nil then
		runtime.rangeButton:SetText("Range: " .. tostring(state.rangeValue))
	end
	if runtime.selectModeButton ~= nil then
		if state.selectMode then
			runtime.selectModeButton:SetText("Done")
		else
			runtime.selectModeButton:SetText("Select Mode")
		end
	end
	if runtime.outOfRangeButton ~= nil then
		if state.outOfRangeMode then
			runtime.outOfRangeButton:SetText("Range Block: On")
		else
			runtime.outOfRangeButton:SetText("Range Block")
		end
	end
	if runtime.setHpAlertButtonText ~= nil then
		runtime.setHpAlertButtonText()
	end
	if runtime.memberAreaButton ~= nil then
		if state.activeMemberArea == "co_raid" then
			runtime.memberAreaButton:SetText("Co-Raid")
			runtime.memberAreaButton:SetExtent(74, TOP_BUTTON_HEIGHT)
		else
			runtime.memberAreaButton:SetText("Raid")
			runtime.memberAreaButton:SetExtent(50, TOP_BUTTON_HEIGHT)
		end
	end
	if runtime.memberAreaLabel ~= nil then
		runtime.memberAreaLabel:SetText("")
	end
end

local function AdjustGroupRowGap(delta)
	state.memberGroupRowGap = ClampGroupRowGap(state.memberGroupRowGap + delta)
	SaveData(GROUP_ROW_GAP_KEY, { value = state.memberGroupRowGap })
	if LayoutMemberCells ~= nil then
		LayoutMemberCells()
	end
	if PositionResizeHandles ~= nil then
		PositionResizeHandles()
	end
end

local function GetMemberGridTop()
	return MEMBER_GRID_TOP
end

local function ToggleRaidWindow()
	local raidWindow = runtime.raidWindow
	if raidWindow == nil then
		return
	end

	if raidWindow:IsVisible() then
		SaveWidgetPosition(raidWindow, WINDOW_POSITION_KEY)
		SaveWindowSize(raidWindow)
		HideMenu()
		raidWindow:Show(false)
		ApplyLockState()
	else
		state.controlsHidden = true
		local x, y = LoadPosition(WINDOW_POSITION_KEY, 520, 320)
		SetWidgetPoint(raidWindow, x, y)
		raidWindow:Show(true)
		PositionResizeHandles()
		ApplyLockState()
		if UpdateAllMemberCells ~= nil then
			UpdateAllMemberCells()
		end
		UpdateControlHover()
	end
end

local function CreateLauncherButton()
	local button = UIParent:CreateWidget("button", "raidOrgLauncherButton", "UIParent", "")
	button:SetStyle("text_default")
	button:SetText("Raid Org")
	button:SetExtent(88, 25)
	button:EnableDrag(true)
	SafeCall(button, "Clickable", true)

	local x, y = LoadPosition(BUTTON_POSITION_KEY, 460, 760)
	button:AddAnchor("TOPLEFT", "UIParent", x, y)
	button:Show(true)
	ApplyRaidOrgLayer(button)

	function button:OnClick()
		ToggleRaidWindow()
	end
	button:SetHandler("OnClick", button.OnClick)

	function button:OnDragStart()
		self:StartMoving()
	end
	button:SetHandler("OnDragStart", button.OnDragStart)

	function button:OnDragStop()
		self:StopMovingOrSizing()
		SaveWidgetPosition(self, BUTTON_POSITION_KEY)
	end
	button:SetHandler("OnDragStop", button.OnDragStop)

	runtime.launcherButton = button
	return button
end

local function CreateMenuButton(parent, name, text, offsetY, onClick)
	local button = parent:CreateChildWidget("button", name, 0, true)
	button:SetStyle("text_default")
	button:SetText(text)
	button:SetExtent(MENU_WIDTH - 10, MENU_BUTTON_HEIGHT)
	button:AddAnchor("TOPLEFT", parent, 5, offsetY)
	button:SetHandler("OnClick", onClick)
	return button
end

local function CreateRangeKeyButton(parent, input, name, text, x, y, onClick)
	local button = parent:CreateChildWidget("button", name, 0, true)
	button:SetStyle("text_default")
	button:SetText(text)
	button:SetExtent(RANGE_DIGIT_BUTTON_WIDTH, RANGE_DIGIT_BUTTON_HEIGHT)
	button:AddAnchor("TOPLEFT", parent, x, y)
	button:SetHandler("OnClick", function()
		onClick()
	end)
	return button
end

local function CreateRangeWindow()
	local rangeWindow = CreateEmptyWindow("raidOrgRangeWindow", "UIParent")
	ApplyRaidOrgLayer(rangeWindow)
	rangeWindow:SetExtent(RANGE_WINDOW_WIDTH, RANGE_WINDOW_HEIGHT)
	rangeWindow:EnableDrag(true)
	rangeWindow:Clickable(true)
	rangeWindow:Show(false)

	local rangeBackground = rangeWindow:CreateColorDrawable(0, 0, 0, 0.72, "background")
	rangeBackground:AddAnchor("TOPLEFT", rangeWindow, 0, 0)
	rangeBackground:AddAnchor("BOTTOMRIGHT", rangeWindow, 0, 0)

	local title = rangeWindow:CreateChildWidget("label", "raidOrgRangeTitle", 0, true)
	title:SetText("Range")
	title:SetExtent(90, 20)
	title.style:SetAlign(ALIGN_LEFT)
	title.style:SetFontSize(12)
	title.style:SetColor(0.95, 0.92, 0.82, 1)
	title.style:SetOutline(true)
	title:AddAnchor("TOPLEFT", rangeWindow, 8, 8)

	local closeButton = rangeWindow:CreateChildWidget("button", "raidOrgRangeCloseButton", 0, true)
	closeButton:SetStyle("text_default")
	closeButton:SetText("X")
	closeButton:SetExtent(24, 22)
	closeButton:AddAnchor("TOPRIGHT", rangeWindow, -6, 5)
	function closeButton:OnClick()
		SaveWidgetPosition(rangeWindow, RANGE_WINDOW_POSITION_KEY)
		rangeWindow:Show(false)
	end
	closeButton:SetHandler("OnClick", closeButton.OnClick)

	local inputBackground = rangeWindow:CreateColorDrawable(1, 1, 1, 0.18, "background")
	inputBackground:AddAnchor("TOPLEFT", rangeWindow, 8, 35)
	inputBackground:SetExtent(RANGE_INPUT_WIDTH, RANGE_INPUT_HEIGHT)

	local input = rangeWindow:CreateChildWidget("editbox", "raidOrgRangeInput", 0, true)
	input:AddAnchor("TOPLEFT", rangeWindow, 12, 38)
	input:SetExtent(RANGE_INPUT_WIDTH - 8, RANGE_INPUT_HEIGHT - 6)
	SafeCall(input, "SetMaxTextLength", 4)
	SafeCall(input, "SetInset", 4, 0, 4, 0)
	SafeCall(input, "Enable", false)
	DisableHitTesting(input)
	if input.style ~= nil then
		input.style:SetAlign(ALIGN_LEFT)
		input.style:SetFontSize(13)
		input.style:SetColor(0.05, 0.06, 0.05, 0)
	end

	local inputDisplay = rangeWindow:CreateChildWidget("label", "raidOrgRangeInputDisplay", 0, true)
	inputDisplay:SetText("")
	inputDisplay:SetExtent(RANGE_INPUT_WIDTH - 8, RANGE_INPUT_HEIGHT - 6)
	inputDisplay.style:SetAlign(ALIGN_LEFT)
	inputDisplay.style:SetFontSize(13)
	inputDisplay.style:SetColor(0.05, 0.06, 0.05, 1)
	inputDisplay:AddAnchor("TOPLEFT", rangeWindow, 12, 38)
	DisableHitTesting(inputDisplay)
	input.rangeDisplayLabel = inputDisplay

	SetRangeInputText(input, state.rangeValue)
	state.rangeInputText = tostring(state.rangeValue)
	ResetRangeInputEventState()

	local keyStartX = 8
	local keyStartY = 66
	local keyStepX = RANGE_DIGIT_BUTTON_WIDTH + RANGE_DIGIT_BUTTON_GAP
	local keyStepY = RANGE_DIGIT_BUTTON_HEIGHT + RANGE_DIGIT_BUTTON_GAP
	local keyRows = {
		{ "1", "2", "3", "C" },
		{ "4", "5", "6", "<" },
		{ "7", "8", "9", "0" },
	}
	for rowIndex, row in ipairs(keyRows) do
		for columnIndex, keyText in ipairs(row) do
			local x = keyStartX + ((columnIndex - 1) * keyStepX)
			local y = keyStartY + ((rowIndex - 1) * keyStepY)
			CreateRangeKeyButton(rangeWindow, input, "raidOrgRangeKey" .. tostring(rowIndex) .. tostring(columnIndex), keyText, x, y, function()
				if keyText == "C" then
					SetRangeDraftText(input, "")
				elseif keyText == "<" then
					DropRangeDraftCharacter(input)
				else
					AppendRangeDigit(input, keyText)
				end
			end)
		end
	end

	local applyButton = rangeWindow:CreateChildWidget("button", "raidOrgRangeApplyButton", 0, true)
	applyButton:SetStyle("text_default")
	applyButton:SetText("Save")
	applyButton:SetExtent(64, 24)
	applyButton:AddAnchor("TOPRIGHT", rangeWindow, -8, 35)
	function applyButton:OnClick()
		local value = NormalizeRangeInputText(state.rangeInputText)
		if value == nil then
			value = DEFAULT_RANGE_VALUE
		end
		state.rangeValue = value
		state.rangeInputText = value
		SetRangeInputText(input, value)
		ResetRangeInputEventState()
		SaveData(RANGE_VALUE_KEY, { value = value })
		SaveWidgetPosition(rangeWindow, RANGE_WINDOW_POSITION_KEY)
		ApplyModeButtons()
		UpdateMemberDistances()
		rangeWindow:Show(false)
	end
	applyButton:SetHandler("OnClick", applyButton.OnClick)

	function rangeWindow:OnDragStart()
		self:StartMoving()
	end
	rangeWindow:SetHandler("OnDragStart", rangeWindow.OnDragStart)

	function rangeWindow:OnDragStop()
		self:StopMovingOrSizing()
		SaveWidgetPosition(self, RANGE_WINDOW_POSITION_KEY)
	end
	rangeWindow:SetHandler("OnDragStop", rangeWindow.OnDragStop)

	runtime.rangeWindow = rangeWindow
	runtime.rangeInput = input
	return rangeWindow
end

local function ToggleRangeWindow()
	local rangeWindow = runtime.rangeWindow
	if rangeWindow == nil then
		return
	end

	if rangeWindow:IsVisible() then
		SaveWidgetPosition(rangeWindow, RANGE_WINDOW_POSITION_KEY)
		rangeWindow:Show(false)
		return
	end

	local x, y = LoadPosition(RANGE_WINDOW_POSITION_KEY, 560, 360)
	SetWidgetPoint(rangeWindow, x, y)
	if runtime.rangeInput ~= nil then
		state.rangeInputText = tostring(state.rangeValue)
		SetRangeInputText(runtime.rangeInput, state.rangeValue)
		ResetRangeInputEventState()
	end
	rangeWindow:Show(true)
end

runtime.normalizeHpAlertInputText = function(text)
	if text == nil then
		return nil
	end

	local value = tostring(text):match("^%s*(.-)%s*$")
	if value == "" or not string.match(value, "^%d+$") then
		return nil
	end

	local numberValue = tonumber(value)
	if numberValue == nil or numberValue < 1 then
		return nil
	end
	if numberValue > 100 then
		numberValue = 100
	end
	return tostring(math.floor(numberValue))
end

runtime.loadHpAlertSettings = function()
	local saved = ADDON:LoadData(state.hpAlertSettingsKey)
	if type(saved) == "table" then
		state.hpAlertValue = runtime.normalizeHpAlertInputText(saved.value) or "50"
		state.hpAlertInputText = state.hpAlertValue
		local enabledText = string.lower(tostring(saved.enabled))
		state.hpAlertEnabled = saved.enabled == true or saved.enabled == 1 or enabledText == "1" or enabledText == "true"
		return
	end

	state.hpAlertValue = runtime.normalizeHpAlertInputText(saved) or "50"
	state.hpAlertInputText = state.hpAlertValue
	state.hpAlertEnabled = false
end

runtime.saveHpAlertSettings = function()
	SaveData(state.hpAlertSettingsKey, { value = state.hpAlertValue, enabled = state.hpAlertEnabled })
end

runtime.setHpAlertButtonText = function()
	if runtime.hpAlertButton ~= nil then
		if state.hpAlertEnabled then
			runtime.hpAlertButton:SetText("HP Alert: On")
		else
			runtime.hpAlertButton:SetText("HP Alert")
		end
	end
	if runtime.hpAlertToggleButton ~= nil then
		if state.hpAlertEnabled then
			runtime.hpAlertToggleButton:SetText("On")
		else
			runtime.hpAlertToggleButton:SetText("Off")
		end
	end
end

runtime.createHpAlertWindow = function()
	local hpAlertWindow = CreateEmptyWindow("raidOrgHpAlertWindow", "UIParent")
	ApplyRaidOrgLayer(hpAlertWindow)
	hpAlertWindow:SetExtent(RANGE_WINDOW_WIDTH, RANGE_WINDOW_HEIGHT + 28)
	hpAlertWindow:EnableDrag(true)
	hpAlertWindow:Clickable(true)
	hpAlertWindow:Show(false)

	local background = hpAlertWindow:CreateColorDrawable(0, 0, 0, 0.72, "background")
	background:AddAnchor("TOPLEFT", hpAlertWindow, 0, 0)
	background:AddAnchor("BOTTOMRIGHT", hpAlertWindow, 0, 0)

	local title = hpAlertWindow:CreateChildWidget("label", "raidOrgHpAlertTitle", 0, true)
	title:SetText("HP Alert %")
	title:SetExtent(90, 20)
	title.style:SetAlign(ALIGN_LEFT)
	title.style:SetFontSize(12)
	title.style:SetColor(0.95, 0.92, 0.82, 1)
	title.style:SetOutline(true)
	title:AddAnchor("TOPLEFT", hpAlertWindow, 8, 8)

	local closeButton = hpAlertWindow:CreateChildWidget("button", "raidOrgHpAlertCloseButton", 0, true)
	closeButton:SetStyle("text_default")
	closeButton:SetText("X")
	closeButton:SetExtent(24, 22)
	closeButton:AddAnchor("TOPRIGHT", hpAlertWindow, -6, 5)
	function closeButton:OnClick()
		SaveWidgetPosition(hpAlertWindow, state.hpAlertWindowPositionKey)
		hpAlertWindow:Show(false)
	end
	closeButton:SetHandler("OnClick", closeButton.OnClick)

	local inputBackground = hpAlertWindow:CreateColorDrawable(1, 1, 1, 0.18, "background")
	inputBackground:AddAnchor("TOPLEFT", hpAlertWindow, 8, 35)
	inputBackground:SetExtent(RANGE_INPUT_WIDTH, RANGE_INPUT_HEIGHT)

	local input = hpAlertWindow:CreateChildWidget("editbox", "raidOrgHpAlertInput", 0, true)
	input:AddAnchor("TOPLEFT", hpAlertWindow, 12, 38)
	input:SetExtent(RANGE_INPUT_WIDTH - 8, RANGE_INPUT_HEIGHT - 6)
	SafeCall(input, "SetMaxTextLength", 3)
	SafeCall(input, "SetInset", 4, 0, 4, 0)
	SafeCall(input, "Enable", false)
	DisableHitTesting(input)
	if input.style ~= nil then
		input.style:SetAlign(ALIGN_LEFT)
		input.style:SetFontSize(13)
		input.style:SetColor(0.05, 0.06, 0.05, 0)
	end

	local inputDisplay = hpAlertWindow:CreateChildWidget("label", "raidOrgHpAlertInputDisplay", 0, true)
	inputDisplay:SetText("")
	inputDisplay:SetExtent(RANGE_INPUT_WIDTH - 8, RANGE_INPUT_HEIGHT - 6)
	inputDisplay.style:SetAlign(ALIGN_LEFT)
	inputDisplay.style:SetFontSize(13)
	inputDisplay.style:SetColor(0.05, 0.06, 0.05, 1)
	inputDisplay:AddAnchor("TOPLEFT", hpAlertWindow, 12, 38)
	DisableHitTesting(inputDisplay)
	input.rangeDisplayLabel = inputDisplay

	local function setDraftText(text)
		state.hpAlertInputText = tostring(text or ""):match("^%s*(.-)%s*$")
		SetRangeInputText(input, state.hpAlertInputText)
	end

	local function appendDigit(digit)
		local digitText = tostring(digit or "")
		if not string.match(digitText, "^%d$") then
			return
		end
		local nextText = tostring(state.hpAlertInputText or "") .. digitText
		if string.len(nextText) > 3 then
			nextText = string.sub(nextText, -3)
		end
		setDraftText(nextText)
	end

	SetRangeInputText(input, state.hpAlertValue)
	state.hpAlertInputText = tostring(state.hpAlertValue)

	local toggleButton = hpAlertWindow:CreateChildWidget("button", "raidOrgHpAlertToggleButton", 0, true)
	toggleButton:SetStyle("text_default")
	toggleButton:SetExtent(64, 24)
	toggleButton:AddAnchor("TOPRIGHT", hpAlertWindow, -8, 35)
	function toggleButton:OnClick()
		state.hpAlertEnabled = not state.hpAlertEnabled
		runtime.saveHpAlertSettings()
		runtime.setHpAlertButtonText()
		UpdateMemberDistances()
	end
	toggleButton:SetHandler("OnClick", toggleButton.OnClick)
	runtime.hpAlertToggleButton = toggleButton

	local keyStartX = 8
	local keyStartY = 66
	local keyStepX = RANGE_DIGIT_BUTTON_WIDTH + RANGE_DIGIT_BUTTON_GAP
	local keyStepY = RANGE_DIGIT_BUTTON_HEIGHT + RANGE_DIGIT_BUTTON_GAP
	local keyRows = {
		{ "1", "2", "3", "C" },
		{ "4", "5", "6", "<" },
		{ "7", "8", "9", "0" },
	}
	for rowIndex, row in ipairs(keyRows) do
		for columnIndex, keyText in ipairs(row) do
			local x = keyStartX + ((columnIndex - 1) * keyStepX)
			local y = keyStartY + ((rowIndex - 1) * keyStepY)
			CreateRangeKeyButton(hpAlertWindow, input, "raidOrgHpAlertKey" .. tostring(rowIndex) .. tostring(columnIndex), keyText, x, y, function()
				if keyText == "C" then
					setDraftText("")
				elseif keyText == "<" then
					setDraftText(DropLastCharacter(state.hpAlertInputText))
				else
					appendDigit(keyText)
				end
			end)
		end
	end

	local applyButton = hpAlertWindow:CreateChildWidget("button", "raidOrgHpAlertApplyButton", 0, true)
	applyButton:SetStyle("text_default")
	applyButton:SetText("Save")
	applyButton:SetExtent(64, 24)
	applyButton:AddAnchor("TOPRIGHT", hpAlertWindow, -8, 150)
	function applyButton:OnClick()
		local value = runtime.normalizeHpAlertInputText(state.hpAlertInputText) or "50"
		state.hpAlertValue = value
		state.hpAlertInputText = value
		SetRangeInputText(input, value)
		runtime.saveHpAlertSettings()
		SaveWidgetPosition(hpAlertWindow, state.hpAlertWindowPositionKey)
		UpdateMemberDistances()
		hpAlertWindow:Show(false)
	end
	applyButton:SetHandler("OnClick", applyButton.OnClick)

	function hpAlertWindow:OnDragStart()
		self:StartMoving()
	end
	hpAlertWindow:SetHandler("OnDragStart", hpAlertWindow.OnDragStart)

	function hpAlertWindow:OnDragStop()
		self:StopMovingOrSizing()
		SaveWidgetPosition(self, state.hpAlertWindowPositionKey)
	end
	hpAlertWindow:SetHandler("OnDragStop", hpAlertWindow.OnDragStop)

	runtime.hpAlertWindow = hpAlertWindow
	runtime.hpAlertInput = input
	runtime.setHpAlertButtonText()
	return hpAlertWindow
end

runtime.toggleHpAlertWindow = function()
	local hpAlertWindow = runtime.hpAlertWindow
	if hpAlertWindow == nil then
		return
	end

	if hpAlertWindow:IsVisible() then
		SaveWidgetPosition(hpAlertWindow, state.hpAlertWindowPositionKey)
		hpAlertWindow:Show(false)
		return
	end

	local x, y = LoadPosition(state.hpAlertWindowPositionKey, 590, 390)
	SetWidgetPoint(hpAlertWindow, x, y)
	if runtime.hpAlertInput ~= nil then
		state.hpAlertInputText = tostring(state.hpAlertValue)
		SetRangeInputText(runtime.hpAlertInput, state.hpAlertValue)
	end
	runtime.setHpAlertButtonText()
	hpAlertWindow:Show(true)
end

local function CreateMenuWindow()
	local menuWindow = CreateEmptyWindow("raidOrgMenuWindow", "UIParent")
	ApplyRaidOrgLayer(menuWindow)
	menuWindow:SetExtent(MENU_WIDTH, (MENU_BUTTON_HEIGHT * 7) + 10)
	menuWindow:EnableDrag(true)
	menuWindow:Show(false)
	SafeCall(menuWindow, "Clickable", true)

	local menuBackground = menuWindow:CreateColorDrawable(0, 0, 0, 0.72, "background")
	menuBackground:AddAnchor("TOPLEFT", menuWindow, 0, 0)
	menuBackground:AddAnchor("BOTTOMRIGHT", menuWindow, 0, 0)

	runtime.selectModeButton = CreateMenuButton(menuWindow, "raidOrgSelectModeButton", "Select Mode", 5, function()
		ToggleSelectMode()
	end)

	runtime.rangeButton = CreateMenuButton(menuWindow, "raidOrgRangeButton", "Range: " .. tostring(state.rangeValue), 5 + MENU_BUTTON_HEIGHT, function()
		ToggleRangeWindow()
	end)

	runtime.outOfRangeButton = CreateMenuButton(menuWindow, "raidOrgOutOfRangeButton", "Range Block", 5 + (MENU_BUTTON_HEIGHT * 2), function()
		ToggleOutOfRangeMode()
	end)

	runtime.hpAlertButton = CreateMenuButton(menuWindow, "raidOrgHpAlertButton", "HP Alert", 5 + (MENU_BUTTON_HEIGHT * 3), function()
		runtime.toggleHpAlertWindow()
	end)

	runtime.lockButton = CreateMenuButton(menuWindow, "raidOrgLockButton", "Lock", 5 + (MENU_BUTTON_HEIGHT * 4), function()
		state.locked = not state.locked
		state.controlsHidden = true
		ApplyLockState()
		UpdateControlHover()
	end)

	runtime.spacingMinusButton = CreateMenuButton(menuWindow, "raidOrgSpacingMinusButton", "Spacing -", 5 + (MENU_BUTTON_HEIGHT * 5), function()
		AdjustGroupRowGap(-MEMBER_GROUP_ROW_GAP_STEP)
	end)

	runtime.spacingPlusButton = CreateMenuButton(menuWindow, "raidOrgSpacingPlusButton", "Spacing +", 5 + (MENU_BUTTON_HEIGHT * 6), function()
		AdjustGroupRowGap(MEMBER_GROUP_ROW_GAP_STEP)
	end)

	function menuWindow:OnDragStart()
		self:StartMoving()
	end
	menuWindow:SetHandler("OnDragStart", menuWindow.OnDragStart)

	function menuWindow:OnDragStop()
		self:StopMovingOrSizing()
		SaveWidgetPosition(self, MENU_POSITION_KEY)
	end
	menuWindow:SetHandler("OnDragStop", menuWindow.OnDragStop)

	runtime.menuWindow = menuWindow
	return menuWindow
end

local function ToggleMenu()
	local menuWindow = runtime.menuWindow
	local raidWindow = runtime.raidWindow
	if menuWindow == nil or raidWindow == nil then
		return
	end

	if menuWindow:IsVisible() then
		SaveWidgetPosition(menuWindow, MENU_POSITION_KEY)
		menuWindow:Show(false)
		ApplyControlButtonsVisibility()
		UpdateControlHover()
		return
	end

	local fallbackX, fallbackY = GetSavedWidgetPosition(raidWindow)
	local x, y = LoadPosition(MENU_POSITION_KEY, fallbackX + raidWindow:GetWidth() - MENU_WIDTH, fallbackY + 30)
	SetWidgetPoint(menuWindow, x, y)
	ApplyModeButtons()
	menuWindow:Show(true)
	ApplyLockState()
end

EnableHitTesting = function(widget)
	TryCall(widget, "Clickable", true)
	TryCall(widget, "EnablePick", true)
	TryCall(widget, "SetEnablePick", true)
	TryCall(widget, "SetPickable", true)
	TryCall(widget, "EnableMouse", true)
	TryCall(widget, "SetMouseEnabled", true)
	TryCall(widget, "EnableInput", true)
	TryCall(widget, "SetInputEnabled", true)
	TryCall(widget, "EnableHitTest", true)
	TryCall(widget, "SetHitTestEnabled", true)
end

local function EnableResizeHitTesting(widget)
	EnableHitTesting(widget)
end

DisableHitTesting = function(widget)
	TryCall(widget, "Clickable", false)
	TryCall(widget, "EnablePick", false)
	TryCall(widget, "SetEnablePick", false)
	TryCall(widget, "SetPickable", false)
	TryCall(widget, "EnableMouse", false)
	TryCall(widget, "SetMouseEnabled", false)
	TryCall(widget, "EnableInput", false)
	TryCall(widget, "SetInputEnabled", false)
	TryCall(widget, "EnableHitTest", false)
	TryCall(widget, "SetHitTestEnabled", false)
end

PositionResizeHandles = function()
	local raidWindow = runtime.raidWindow
	if raidWindow == nil or runtime.resizeHandles == nil then
		return
	end

	local windowX, windowY = GetSavedWidgetPosition(raidWindow)
	local width = raidWindow:GetWidth()
	local height = raidWindow:GetHeight()

	for _, handle in ipairs(runtime.resizeHandles) do
		if handle ~= nil and not handle.isResizing then
			local x = windowX
			local y = windowY

			if not handle.resizeFromLeft then
				x = windowX + width - CORNER_HANDLE_SIZE
			end
			if not handle.resizeFromTop then
				y = windowY + height - CORNER_HANDLE_SIZE
			end

			SetWidgetPoint(handle, x, y)
			TryCall(handle, "Raise")
		end
	end
end

local function ApplyWindowGeometry(window, x, y, width, height, shouldSave)
	if window == nil then
		return
	end

	window:SetExtent(width, height)
	SetWidgetPoint(window, x, y)
	PositionResizeHandles()
	if LayoutMemberCells ~= nil then
		LayoutMemberCells()
	end

	if shouldSave then
		SaveData(WINDOW_POSITION_KEY, { x = x, y = y })
		SaveData(WINDOW_SIZE_KEY, { width = width, height = height })
	end
end

local function TryGetUnitName(token)
	if token == nil or X2Unit == nil then
		return nil
	end

	local ok, name = pcall(function()
		return X2Unit:UnitName(token)
	end)
	if not ok or type(name) ~= "string" then
		return nil
	end

	name = name:match("^%s*(.-)%s*$")
	if name == "" then
		return nil
	end
	return name
end

local function TryGetUnitDistance(token, memberName)
	if token == nil or X2Unit == nil then
		return nil
	end

	local playerName = TryGetUnitName("player")
	if playerName ~= nil and memberName ~= nil and memberName == playerName then
		return 0
	end

	local ok, distanceInfo = pcall(function()
		return X2Unit:UnitDistance(token)
	end)
	if not ok then
		return nil
	end

	if type(distanceInfo) == "table" then
		distanceInfo = distanceInfo.distance
	end

	local distance = tonumber(distanceInfo)
	if distance == nil or distance < 0 then
		return nil
	end
	return distance
end

local function NormalizeHealthValue(value)
	if type(value) == "table" then
		return tonumber(value.current or value.health or value.hp or value.value or value[1])
	end
	return tonumber(value)
end

local function TryGetUnitHealthPercent(token)
	if token == nil or X2Unit == nil then
		return nil
	end
	if type(X2Unit.UnitHealth) ~= "function" or type(X2Unit.UnitMaxHealth) ~= "function" then
		return nil
	end

	local okHealth, healthInfo = pcall(function()
		return X2Unit:UnitHealth(token)
	end)
	local okMaxHealth, maxHealthInfo = pcall(function()
		return X2Unit:UnitMaxHealth(token)
	end)
	if not okHealth or not okMaxHealth then
		return nil
	end

	local health = NormalizeHealthValue(healthInfo)
	local maxHealth = NormalizeHealthValue(maxHealthInfo)
	if health == nil or maxHealth == nil or maxHealth <= 0 then
		return nil
	end

	local percent = health / maxHealth
	if percent < 0 then
		return 0
	end
	if percent > 1 then
		return 1
	end
	return percent
end

local function GetTokenCandidates(area, flatIndex)
	if area == "co_raid" then
		return {
			string.format("team_2_%d", flatIndex),
		}
	end

	return {
		string.format("team_1_%d", flatIndex),
		string.format("team%d", flatIndex),
		string.format("team_%d", flatIndex),
	}
end

local function GetMemberForArea(area, flatIndex)
	local candidates = GetTokenCandidates(area, flatIndex)
	for _, token in ipairs(candidates) do
		local name = TryGetUnitName(token)
		if name ~= nil then
			return token, name
		end
	end
	return nil, nil
end

local function NormalizeRoleKey(role)
	if type(role) == "table" then
		return NormalizeRoleKey(
			role.role
				or role.roleType
				or role.roleId
				or role.id
				or role.value
				or role.name
				or role.type
				or role.colorKey
				or role.roleColor
				or role.color
		)
	end

	if role == nil then
		return DEFAULT_ROLE_COLOR_KEY
	end

	local numericRole = tonumber(role)
	if numericRole ~= nil then
		return ROLE_NUMBER_KEY_MAP[numericRole] or DEFAULT_ROLE_COLOR_KEY
	end

	local key = string.lower(tostring(role))
	if string.find(key, "blue", 1, true) or string.find(key, "undecided", 1, true) or string.find(key, "none", 1, true) then
		return "blue"
	end
	if string.find(key, "green", 1, true) or string.find(key, "tank", 1, true) or string.find(key, "def") then
		return "green"
	end
	if string.find(key, "pink", 1, true) or string.find(key, "heal", 1, true) then
		return "pink"
	end
	if string.find(key, "purple", 1, true)
		or string.find(key, "range", 1, true)
		or string.find(key, "archer", 1, true)
		or string.find(key, "mage", 1, true)
		or string.find(key, "gunner", 1, true)
		or string.find(key, "sorcery", 1, true) then
		return "purple"
	end
	if string.find(key, "red", 1, true) or string.find(key, "melee", 1, true) or string.find(key, "attack", 1, true) then
		return "red"
	end
	return DEFAULT_ROLE_COLOR_KEY
end

local function TryReadRoleFromCall(...)
	if X2Team == nil or type(X2Team.GetRole) ~= "function" then
		return nil
	end

	local ok, role = pcall(function(...)
		return X2Team:GetRole(...)
	end, ...)
	if ok then
		return role
	end
	return nil
end

local function TryReadRoleBySlot(area, flatIndex, token, name)
	if flatIndex == nil then
		return nil
	end

	local slotIndex = tonumber(flatIndex)
	if slotIndex == nil or slotIndex < 1 then
		return nil
	end

	local teamIndex = 0
	if area == "co_raid" then
		teamIndex = 1
	end

	local fallbackRole = nil
	local function useRole(role)
		if role == nil then
			return nil
		end

		local roleKey = NormalizeRoleKey(role)
		if roleKey ~= DEFAULT_ROLE_COLOR_KEY then
			return role
		end
		fallbackRole = fallbackRole or role
		return nil
	end

	local role = useRole(TryReadRoleFromCall(teamIndex, slotIndex))
	if role ~= nil then
		return role
	end

	local alternateTeamIndex = teamIndex + 1
	role = useRole(TryReadRoleFromCall(alternateTeamIndex, slotIndex))
	if role ~= nil then
		return role
	end

	role = useRole(TryReadRoleFromCall(slotIndex))
	if role ~= nil then
		return role
	end

	role = useRole(TryReadRoleFromCall(token))
	if role ~= nil then
		return role
	end

	role = useRole(TryReadRoleFromCall(name))
	if role ~= nil then
		return role
	end

	return fallbackRole
end

local function GetMemberRoleKey(area, flatIndex, token, name)
	local role = TryReadRoleBySlot(area, flatIndex, token, name)
	if role ~= nil then
		return NormalizeRoleKey(role)
	end

	return nil
end

local function FormatDistance(distance)
	if distance == nil then
		return "--"
	end
	return string.format("%.1fm", math.floor((distance * 10) + 0.5) / 10)
end

local function EllipsizeText(text, maxCharacters)
	local value = tostring(text or "")
	local limit = tonumber(maxCharacters) or 0
	if limit <= 0 or string.len(value) <= limit then
		return value
	end
	if limit <= 3 then
		return string.sub("...", 1, limit)
	end
	return string.sub(value, 1, limit - 3) .. "..."
end

local function IsMemberDistanceOutOfRange(distance)
	if state.selectMode or state.selectionFilterActive or not state.outOfRangeMode then
		return false
	end
	local rangeValue = tonumber(state.rangeValue)
	return distance ~= nil and rangeValue ~= nil and distance > rangeValue
end

local function SetDrawableColor(drawable, r, g, b, a)
	if drawable ~= nil then
		TryCall(drawable, "SetColor", r, g, b, a)
	end
end

runtime.isMemberHpAlertActive = function(cell)
	if cell == nil or not state.hpAlertEnabled then
		return false
	end

	local threshold = tonumber(state.hpAlertValue)
	local percent = tonumber(cell.memberHealthPercent)
	if threshold == nil or percent == nil then
		return false
	end
	return (percent * 100) < threshold
end

runtime.setCellNameColor = function(cell, color)
	if cell ~= nil and cell.nameLabel ~= nil and cell.nameLabel.style ~= nil then
		cell.nameLabel.style:SetColor(color[1], color[2], color[3], color[4])
	end
end

runtime.applyCellHpAlertVisual = function(cell)
	if cell == nil then
		return
	end

	SetDrawableVisible(cell.background, true)
	SetDrawableColor(cell.background, state.hpAlertColor.bg[1], state.hpAlertColor.bg[2], state.hpAlertColor.bg[3], state.hpAlertColor.bg[4])
	local percent = cell.memberHealthPercent or 1
	if percent < 0 then
		percent = 0
	elseif percent > 1 then
		percent = 1
	end
	local width = math.floor((cell:GetWidth() * percent) + 0.5)
	if width < 1 and percent > 0 then
		width = 1
	end
	cell.background:SetExtent(width, cell:GetHeight())
	runtime.setCellNameColor(cell, state.hpAlertColor.text)
	if cell.distanceLabel ~= nil and cell.distanceLabel.style ~= nil then
		cell.distanceLabel.style:SetColor(state.hpAlertColor.text[1], state.hpAlertColor.text[2], state.hpAlertColor.text[3], state.hpAlertColor.text[4])
	end
	SetDrawableColor(cell.borderTop, state.hpAlertColor.border[1], state.hpAlertColor.border[2], state.hpAlertColor.border[3], state.locked and 0 or state.hpAlertColor.border[4])
	SetDrawableColor(cell.borderBottom, state.hpAlertColor.border[1], state.hpAlertColor.border[2], state.hpAlertColor.border[3], state.locked and 0 or state.hpAlertColor.border[4])
	SetDrawableColor(cell.borderLeft, state.hpAlertColor.border[1], state.hpAlertColor.border[2], state.hpAlertColor.border[3], state.locked and 0 or state.hpAlertColor.border[4])
	SetDrawableColor(cell.borderRight, state.hpAlertColor.border[1], state.hpAlertColor.border[2], state.hpAlertColor.border[3], state.locked and 0 or state.hpAlertColor.border[4])
end

local function GetCellSelectionKey(cell)
	if cell == nil or cell.memberName == nil then
		return nil
	end
	return string.lower(cell.memberName)
end

local function IsCellSelected(cell)
	local key = GetCellSelectionKey(cell)
	return key ~= nil and state.selectedMemberByName[key] == true
end

local function GetSelectedMemberCount()
	local count = 0
	for _, selected in pairs(state.selectedMemberByName or {}) do
		if selected then
			count = count + 1
		end
	end
	return count
end

local function IsCellSelectionFiltered(cell)
	return state.selectionFilterActive and not state.selectMode and cell ~= nil and cell.memberName ~= nil and not IsCellSelected(cell)
end

local function SetCellBorderColor(cell, color)
	if cell == nil or color == nil then
		return
	end
	SetDrawableColor(cell.borderTop, color[1], color[2], color[3], color[4])
	SetDrawableColor(cell.borderBottom, color[1], color[2], color[3], color[4])
	SetDrawableColor(cell.borderLeft, color[1], color[2], color[3], color[4])
	SetDrawableColor(cell.borderRight, color[1], color[2], color[3], color[4])
end

local function UpdateCellHealthFill(cell)
	if cell == nil or cell.background == nil then
		return
	end

	if cell.memberOutOfRange then
		cell.background:SetExtent(cell:GetWidth(), cell:GetHeight())
		return
	end

	local percent = cell.memberHealthPercent
	if percent == nil then
		percent = 1
	end
	if percent < 0 then
		percent = 0
	elseif percent > 1 then
		percent = 1
	end

	local width = math.floor((cell:GetWidth() * percent) + 0.5)
	if width < 1 and percent > 0 then
		width = 1
	end
	cell.background:SetExtent(width, cell:GetHeight())
end

local function SetDistanceLabelColor(cell, distance)
	if cell.memberHpAlertActive then
		cell.distanceLabel.style:SetColor(state.hpAlertColor.text[1], state.hpAlertColor.text[2], state.hpAlertColor.text[3], state.hpAlertColor.text[4])
		return
	end

	if state.selectMode then
		cell.distanceLabel.style:SetColor(0.74, 0.76, 0.78, 1)
		return
	end

	local rangeValue = tonumber(state.rangeValue)
	if distance ~= nil and rangeValue ~= nil and distance <= rangeValue then
		cell.distanceLabel.style:SetColor(0.44, 0.98, 0.52, 1)
	elseif distance ~= nil then
		cell.distanceLabel.style:SetColor(1, 0.54, 0.46, 1)
	else
		cell.distanceLabel.style:SetColor(0.74, 0.76, 0.78, 1)
	end
end

local function ApplyCellInfoText(cell)
	if cell == nil then
		return
	end

	if not state.selectMode and (cell.memberOutOfRange or IsCellSelectionFiltered(cell)) then
		cell.nameLabel:SetText("")
		cell.distanceLabel:SetText("")
		return
	end

	cell.nameLabel:SetText(EllipsizeText(cell.memberName or "", cell.nameCharacterLimit))
	cell.distanceLabel:SetText(FormatDistance(cell.memberDistance))
end

local function ApplyCellOutOfRangeVisual(cell)
	if cell == nil then
		return
	end

	SetDrawableVisible(cell.background, true)
	SetDrawableColor(
		cell.background,
		OUT_OF_RANGE_CELL_COLOR.bg[1],
		OUT_OF_RANGE_CELL_COLOR.bg[2],
		OUT_OF_RANGE_CELL_COLOR.bg[3],
		OUT_OF_RANGE_CELL_COLOR.bg[4]
	)
	cell.background:SetExtent(cell:GetWidth(), cell:GetHeight())
	SetDrawableColor(
		cell.borderTop,
		OUT_OF_RANGE_CELL_COLOR.border[1],
		OUT_OF_RANGE_CELL_COLOR.border[2],
		OUT_OF_RANGE_CELL_COLOR.border[3],
		state.locked and 0 or OUT_OF_RANGE_CELL_COLOR.border[4]
	)
	SetDrawableColor(
		cell.borderBottom,
		OUT_OF_RANGE_CELL_COLOR.border[1],
		OUT_OF_RANGE_CELL_COLOR.border[2],
		OUT_OF_RANGE_CELL_COLOR.border[3],
		state.locked and 0 or OUT_OF_RANGE_CELL_COLOR.border[4]
	)
	SetDrawableColor(
		cell.borderLeft,
		OUT_OF_RANGE_CELL_COLOR.border[1],
		OUT_OF_RANGE_CELL_COLOR.border[2],
		OUT_OF_RANGE_CELL_COLOR.border[3],
		state.locked and 0 or OUT_OF_RANGE_CELL_COLOR.border[4]
	)
	SetDrawableColor(
		cell.borderRight,
		OUT_OF_RANGE_CELL_COLOR.border[1],
		OUT_OF_RANGE_CELL_COLOR.border[2],
		OUT_OF_RANGE_CELL_COLOR.border[3],
		state.locked and 0 or OUT_OF_RANGE_CELL_COLOR.border[4]
	)
end

local function ApplyCellSelectModeVisual(cell)
	if cell == nil then
		return
	end

	SetDrawableVisible(cell.background, false)
	SetDrawableColor(cell.background, 0, 0, 0, 0)
	cell.background:SetExtent(0, cell:GetHeight())
	if IsCellSelected(cell) then
		SetCellBorderColor(cell, SELECTED_CELL_BORDER_COLOR)
	else
		SetCellBorderColor(cell, SELECT_MODE_CELL_BORDER_COLOR)
	end
end

local function ApplyCellSelectionFilteredVisual(cell)
	if cell == nil then
		return
	end

	ApplyCellOutOfRangeVisual(cell)
end

local function ApplyCellRoleVisual(cell)
	if cell == nil then
		return
	end

	cell.memberHpAlertActive = false
	runtime.setCellNameColor(cell, state.normalNameColor)

	if state.selectMode then
		ApplyCellSelectModeVisual(cell)
		return
	end

	if IsCellSelectionFiltered(cell) then
		ApplyCellSelectionFilteredVisual(cell)
		return
	end

	cell.memberHpAlertActive = runtime.isMemberHpAlertActive(cell)
	if cell.memberHpAlertActive then
		runtime.applyCellHpAlertVisual(cell)
		return
	end

	if cell.memberOutOfRange then
		ApplyCellOutOfRangeVisual(cell)
		return
	end

	local roleColor = ROLE_COLOR_MAP[cell.memberRoleKey or DEFAULT_ROLE_COLOR_KEY] or ROLE_COLOR_MAP[DEFAULT_ROLE_COLOR_KEY]
	SetDrawableVisible(cell.background, true)
	SetDrawableColor(cell.background, roleColor.bg[1], roleColor.bg[2], roleColor.bg[3], roleColor.bg[4])
	UpdateCellHealthFill(cell)
	if state.locked then
		SetDrawableColor(cell.borderTop, roleColor.border[1], roleColor.border[2], roleColor.border[3], 0)
		SetDrawableColor(cell.borderBottom, roleColor.border[1], roleColor.border[2], roleColor.border[3], 0)
		SetDrawableColor(cell.borderLeft, roleColor.border[1], roleColor.border[2], roleColor.border[3], 0)
		SetDrawableColor(cell.borderRight, roleColor.border[1], roleColor.border[2], roleColor.border[3], 0)
	else
		SetDrawableColor(cell.borderTop, roleColor.border[1], roleColor.border[2], roleColor.border[3], 0.95)
		SetDrawableColor(cell.borderBottom, roleColor.border[1], roleColor.border[2], roleColor.border[3], 0.95)
		SetDrawableColor(cell.borderLeft, roleColor.border[1], roleColor.border[2], roleColor.border[3], 0.95)
		SetDrawableColor(cell.borderRight, roleColor.border[1], roleColor.border[2], roleColor.border[3], 0.95)
	end
end

local function ToggleCellSelection(cell)
	local key = GetCellSelectionKey(cell)
	if key == nil then
		return
	end

	state.selectedMemberByName[key] = not state.selectedMemberByName[key]
	if not state.selectedMemberByName[key] then
		state.selectedMemberByName[key] = nil
	end
	ApplyCellInfoText(cell)
	ApplyCellRoleVisual(cell)
end

local function ApplyCellState(cell, name, distance, roleKey)
	if cell == nil then
		return
	end

	if name == nil then
		cell.memberToken = nil
		cell.memberName = nil
		cell.memberDistance = nil
		cell.memberHealthPercent = nil
		cell.memberHpAlertActive = nil
		cell.memberRoleKey = nil
		cell.memberOutOfRange = nil
		cell.nameLabel:SetText("")
		cell.distanceLabel:SetText("")
		SetDrawableVisible(cell.background, false)
		SetDrawableColor(cell.background, 0, 0, 0, 0)
		SetDrawableColor(cell.borderTop, 1, 1, 1, 0.05)
		SetDrawableColor(cell.borderBottom, 1, 1, 1, 0.05)
		SetDrawableColor(cell.borderLeft, 1, 1, 1, 0.05)
		SetDrawableColor(cell.borderRight, 1, 1, 1, 0.05)
		return
	end

	cell.memberName = name
	cell.memberDistance = distance
	cell.memberHealthPercent = TryGetUnitHealthPercent(cell.memberToken)
	local memberRoleCacheKey = string.lower(name)
	if roleKey ~= nil then
		cell.memberRoleKey = roleKey
		state.memberRoleByName[memberRoleCacheKey] = roleKey
	elseif state.memberRoleByName[memberRoleCacheKey] ~= nil then
		cell.memberRoleKey = state.memberRoleByName[memberRoleCacheKey]
	elseif cell.memberRoleKey == nil then
		cell.memberRoleKey = DEFAULT_ROLE_COLOR_KEY
	end
	cell.memberOutOfRange = IsMemberDistanceOutOfRange(distance)
	ApplyCellInfoText(cell)
	ApplyCellRoleVisual(cell)
	if not cell.memberOutOfRange then
		SetDistanceLabelColor(cell, distance)
	end
end

ApplyAllCellVisuals = function()
	for _, cell in ipairs(runtime.memberCells or {}) do
		if cell.memberName ~= nil then
			cell.memberOutOfRange = IsMemberDistanceOutOfRange(cell.memberDistance)
			ApplyCellInfoText(cell)
			ApplyCellRoleVisual(cell)
			if not cell.memberOutOfRange then
				SetDistanceLabelColor(cell, cell.memberDistance)
			end
		end
	end
end

local function GetMemberGroupCount(memberCount)
	if memberCount <= 0 then
		return 1
	end
	local groupCount = math.ceil(memberCount / MEMBER_GROUP_SIZE)
	if groupCount > MEMBER_MAX_GROUPS then
		return MEMBER_MAX_GROUPS
	end
	return groupCount
end

local function GetMemberGroupRows(memberCount)
	local groupRows = math.ceil(GetMemberGroupCount(memberCount) / MEMBER_GROUP_COLUMNS)
	if groupRows < 1 then
		return 1
	end
	return groupRows
end

local function GetMemberGridColumns(memberCount)
	local groupCount = GetMemberGroupCount(memberCount)
	if groupCount < MEMBER_GROUP_COLUMNS then
		return groupCount
	end
	return MEMBER_GROUP_COLUMNS
end

local function GetMemberGridRows(memberCount)
	if memberCount <= 0 then
		return 1
	end
	local fullGroupRows = math.floor((memberCount - 1) / (MEMBER_GROUP_COLUMNS * MEMBER_GROUP_SIZE))
	local remainingMembers = memberCount - (fullGroupRows * MEMBER_GROUP_COLUMNS * MEMBER_GROUP_SIZE)
	local partialRows = remainingMembers
	if partialRows > MEMBER_GROUP_SIZE then
		partialRows = MEMBER_GROUP_SIZE
	end
	if partialRows < 1 then
		partialRows = 1
	end
	return (fullGroupRows * MEMBER_GROUP_SIZE) + partialRows
end

local function ResizeWindowForMemberCount(memberCount)
	local raidWindow = runtime.raidWindow
	if raidWindow == nil or memberCount <= 0 then
		return
	end

	local groupRows = GetMemberGroupRows(memberCount)
	local reservedRows = groupRows * MEMBER_GROUP_SIZE
	if groupRows <= 1 and memberCount < MEMBER_GROUP_SIZE then
		reservedRows = memberCount
	end
	if reservedRows < 1 then
		reservedRows = 1
	end

	local visibleRows = GetMemberGridRows(memberCount)
	if state.lastAutoLayoutMemberCount ~= memberCount or state.lastAutoLayoutRows ~= visibleRows then
		local groupRowGap = state.memberGroupRowGap or DEFAULT_MEMBER_GROUP_ROW_GAP
		local currentContentHeight = raidWindow:GetHeight() - GetMemberGridTop() - MEMBER_GRID_PADDING_Y
		local currentRows = state.lastAutoLayoutRows or reservedRows
		local currentGroupRows = state.lastAutoLayoutGroupRows or groupRows
		local currentGapHeight = ((currentRows - currentGroupRows) * MEMBER_CELL_GAP) + ((currentGroupRows - 1) * groupRowGap)
		local cellHeight = math.floor((currentContentHeight - currentGapHeight) / currentRows)
		if cellHeight < MEMBER_CELL_MIN_HEIGHT then
			cellHeight = MEMBER_CELL_MIN_HEIGHT
		end

		local visibleGapHeight = ((visibleRows - groupRows) * MEMBER_CELL_GAP) + ((groupRows - 1) * groupRowGap)
		local height = GetMemberGridTop() + (visibleRows * cellHeight) + visibleGapHeight + MEMBER_GRID_PADDING_Y
		if height < MIN_WINDOW_HEIGHT then
			height = MIN_WINDOW_HEIGHT
		end
		raidWindow:SetExtent(raidWindow:GetWidth(), height)
	end

	state.lastAutoLayoutMemberCount = memberCount
	state.lastAutoLayoutRows = visibleRows
	state.lastAutoLayoutGroupRows = groupRows
	runtime.compactTopControls = raidWindow:GetWidth() < TOP_CONTROLS_HORIZONTAL_MIN_WIDTH
	LayoutMemberCells()
	PositionResizeHandles()
end

local function HasAnyMemberInArea(area)
	for flatIndex = 1, MEMBER_MAX_COUNT do
		local _, name = GetMemberForArea(area, flatIndex)
		if name ~= nil then
			return true
		end
	end
	return false
end

local function IsUserInRaid()
	return HasAnyMemberInArea("raid") or HasAnyMemberInArea("co_raid")
end

UpdateAllMemberCells = function()
	local visibleCount = 0
	local layoutMemberCount = 0
	local memberCells = runtime.memberCells or {}
	local seenMembers = {}
	local wasLocked = state.locked

	for flatIndex = 1, MEMBER_MAX_COUNT do
		local cell = memberCells[flatIndex]
		local token, name = GetMemberForArea(state.activeMemberArea, flatIndex)
		local memberKey = nil
		if name ~= nil then
			memberKey = string.lower(name)
		end
		if cell ~= nil and memberKey ~= nil and not seenMembers[memberKey] then
			seenMembers[memberKey] = true
			visibleCount = visibleCount + 1
			layoutMemberCount = flatIndex
			cell.sourceFlatIndex = flatIndex
			cell.memberToken = token
			cell:Show(true)
			ApplyCellState(cell, name, TryGetUnitDistance(token, name), GetMemberRoleKey(state.activeMemberArea, flatIndex, token, name))
		elseif cell ~= nil then
			cell.sourceFlatIndex = nil
			ApplyCellState(cell, nil, nil)
			cell:Show(false)
		end
	end
	runtime.visibleMemberCount = layoutMemberCount
	runtime.actualVisibleMemberCount = visibleCount
	if not IsUserInRaid() then
		state.locked = false
	end
	ResizeWindowForMemberCount(layoutMemberCount)
	ApplyModeButtons()
	if wasLocked ~= state.locked then
		ApplyLockState()
	end
end

UpdateMemberDistances = function()
	for _, cell in ipairs(runtime.memberCells or {}) do
		if cell.memberToken ~= nil and cell.memberName ~= nil then
			local distance = TryGetUnitDistance(cell.memberToken, cell.memberName)
			local roleKey = GetMemberRoleKey(state.activeMemberArea, cell.sourceFlatIndex, cell.memberToken, cell.memberName)
			local wasOutOfRange = cell.memberOutOfRange
			local wasHpAlertActive = cell.memberHpAlertActive
			cell.memberDistance = distance
			cell.memberOutOfRange = IsMemberDistanceOutOfRange(distance)
			cell.memberHealthPercent = TryGetUnitHealthPercent(cell.memberToken)
			cell.memberHpAlertActive = runtime.isMemberHpAlertActive(cell)
			if roleKey ~= nil and roleKey ~= cell.memberRoleKey then
				cell.memberRoleKey = roleKey
				state.memberRoleByName[string.lower(cell.memberName)] = roleKey
				ApplyCellRoleVisual(cell)
			elseif wasOutOfRange ~= cell.memberOutOfRange then
				ApplyCellRoleVisual(cell)
			elseif wasHpAlertActive ~= cell.memberHpAlertActive then
				ApplyCellRoleVisual(cell)
			else
				UpdateCellHealthFill(cell)
			end
			ApplyCellInfoText(cell)
			if not cell.memberOutOfRange then
				SetDistanceLabelColor(cell, distance)
			end
		end
	end
end

local function ToggleMemberArea()
	if state.activeMemberArea == "raid" then
		state.activeMemberArea = "co_raid"
	else
		state.activeMemberArea = "raid"
	end
	UpdateAllMemberCells()
end

ToggleSelectMode = function()
	if state.selectMode then
		state.selectMode = false
		state.selectionFilterActive = GetSelectedMemberCount() > 0
	else
		state.selectMode = true
		state.selectionFilterActive = false
		state.locked = false
	end
	ApplyModeButtons()
	UpdateMemberDistances()
	ApplyAllCellVisuals()
	ApplyLockState()
end

ToggleOutOfRangeMode = function()
	state.outOfRangeMode = not state.outOfRangeMode
	ApplyModeButtons()
	UpdateMemberDistances()
end

local function ClampResizeGeometry(data, newX, newY, newWidth, newHeight)
	if newWidth < MIN_WINDOW_WIDTH then
		if data.resizeFromLeft then
			newX = data.startX + data.startWidth - MIN_WINDOW_WIDTH
		end
		newWidth = MIN_WINDOW_WIDTH
	end

	if newHeight < MIN_WINDOW_HEIGHT then
		if data.resizeFromTop then
			newY = data.startY + data.startHeight - MIN_WINDOW_HEIGHT
		end
		newHeight = MIN_WINDOW_HEIGHT
	end

	return newX, newY, newWidth, newHeight
end

local function ComputeResizeGeometry(handle)
	local data = handle.resizeDrag
	if data == nil then
		return nil
	end

	local handleX, handleY = GetSavedWidgetPosition(handle)
	local deltaX = handleX - data.handleStartX
	local deltaY = handleY - data.handleStartY

	local newX = data.startX
	local newY = data.startY
	local newWidth = data.startWidth
	local newHeight = data.startHeight

	if data.resizeFromLeft then
		newX = data.startX + deltaX
		newWidth = data.startWidth - deltaX
	else
		newWidth = data.startWidth + deltaX
	end

	if data.resizeFromTop then
		newY = data.startY + deltaY
		newHeight = data.startHeight - deltaY
	else
		newHeight = data.startHeight + deltaY
	end

	return ClampResizeGeometry(data, newX, newY, newWidth, newHeight)
end

local function UpdateResizeFromHandle(handle)
	local parent = handle.resizeParent
	local x, y, width, height = ComputeResizeGeometry(handle)
	if x ~= nil then
		ApplyWindowGeometry(parent, x, y, width, height, false)
	end
end

local function SetResizeGripAlpha(handle, alpha)
	if handle == nil or handle.gripLines == nil then
		return
	end

	for _, line in ipairs(handle.gripLines) do
		if line ~= nil then
			TryCall(line, "SetColor", 1, 1, 1, alpha)
		end
	end
end

local function AddResizeGripLine(handle, x, y, width, height)
	local line = handle:CreateColorDrawable(1, 1, 1, RESIZE_GRIP_LINE_ALPHA, "background")
	line:SetExtent(width, height)
	line:AddAnchor("TOPLEFT", handle, x, y)
	table.insert(handle.gripLines, line)
end

local function CreateResizeGripVisuals(handle)
	handle.gripLines = {}

	local horizontalX
	local horizontalY
	local verticalX
	local verticalY

	if handle.resizeFromLeft then
		horizontalX = RESIZE_GRIP_INSET
		verticalX = RESIZE_GRIP_INSET
	else
		horizontalX = CORNER_HANDLE_SIZE - RESIZE_GRIP_INSET - RESIZE_GRIP_LINE_LENGTH
		verticalX = CORNER_HANDLE_SIZE - RESIZE_GRIP_INSET - RESIZE_GRIP_LINE_THICKNESS
	end

	if handle.resizeFromTop then
		horizontalY = RESIZE_GRIP_INSET
		verticalY = RESIZE_GRIP_INSET
	else
		horizontalY = CORNER_HANDLE_SIZE - RESIZE_GRIP_INSET - RESIZE_GRIP_LINE_THICKNESS
		verticalY = CORNER_HANDLE_SIZE - RESIZE_GRIP_INSET - RESIZE_GRIP_LINE_LENGTH
	end

	AddResizeGripLine(handle, horizontalX, horizontalY, RESIZE_GRIP_LINE_LENGTH, RESIZE_GRIP_LINE_THICKNESS)
	AddResizeGripLine(handle, verticalX, verticalY, RESIZE_GRIP_LINE_THICKNESS, RESIZE_GRIP_LINE_LENGTH)
end

local function CreateResizeHandle(parent, name, anchor)
	local handle = parent:CreateChildWidget("button", name, 0, true)
	handle:SetText("")
	handle:SetExtent(CORNER_HANDLE_SIZE, CORNER_HANDLE_SIZE)
	handle:EnableDrag(true)
	EnableResizeHitTesting(handle)
	handle:Show(false)
	handle.resizeParent = parent
	handle.resizeFromLeft = string.find(anchor, "LEFT", 1, true) ~= nil
	handle.resizeFromTop = string.find(anchor, "TOP", 1, true) ~= nil

	CreateResizeGripVisuals(handle)

	function handle:OnEnter()
		if not state.locked then
			SetResizeGripAlpha(self, RESIZE_GRIP_HOVER_ALPHA)
		end
	end
	handle:SetHandler("OnEnter", handle.OnEnter)

	function handle:OnLeave()
		if not self.isResizing then
			SetResizeGripAlpha(self, RESIZE_GRIP_LINE_ALPHA)
		end
	end
	handle:SetHandler("OnLeave", handle.OnLeave)

	function handle:OnDragStart()
		if state.locked then
			return
		end

		SetResizeGripAlpha(self, RESIZE_GRIP_HOVER_ALPHA)
		local startX, startY = GetSavedWidgetPosition(parent)
		local handleStartX, handleStartY = GetSavedWidgetPosition(self)
		self.resizeDrag = {
			startX = startX,
			startY = startY,
			startWidth = parent:GetWidth(),
			startHeight = parent:GetHeight(),
			handleStartX = handleStartX,
			handleStartY = handleStartY,
			resizeFromLeft = self.resizeFromLeft,
			resizeFromTop = self.resizeFromTop,
		}
		self.isResizing = true
		self:StartMoving()
	end
	handle:SetHandler("OnDragStart", handle.OnDragStart)

	function handle:OnUpdate()
		if self.isResizing then
			UpdateResizeFromHandle(self)
		end
	end
	handle:SetHandler("OnUpdate", handle.OnUpdate)

	function handle:OnDragStop()
		self:StopMovingOrSizing()

		local x, y, width, height = ComputeResizeGeometry(self)
		if x ~= nil then
			ApplyWindowGeometry(parent, x, y, width, height, true)
		end

		self.resizeDrag = nil
		self.isResizing = false
		SetResizeGripAlpha(self, RESIZE_GRIP_LINE_ALPHA)
		PositionResizeHandles()
	end
	handle:SetHandler("OnDragStop", handle.OnDragStop)

	return handle
end

local function CreateMemberCell(parent, flatIndex)
	local cell = parent:CreateChildWidget("button", "raidOrgMemberCell" .. tostring(flatIndex), 0, true)
	cell:SetText("")
	cell.flatIndex = flatIndex
	cell.sourceFlatIndex = nil
	cell:Show(false)
	DisableHitTesting(cell)
	function cell:OnClick()
		if state.selectMode and self.memberName ~= nil then
			ToggleCellSelection(self)
		end
	end
	cell:SetHandler("OnClick", cell.OnClick)

	local background = cell:CreateColorDrawable(0, 0, 0, 0, "background")
	background:AddAnchor("TOPLEFT", cell, 0, 0)
	background:SetExtent(0, MEMBER_CELL_MIN_HEIGHT)
	SetDrawableVisible(background, false)
	cell.background = background

	local borderTop = cell:CreateColorDrawable(1, 1, 1, 0.05, "artwork")
	borderTop:SetExtent(1, 1)
	borderTop:AddAnchor("TOPLEFT", cell, 0, 0)
	borderTop:AddAnchor("TOPRIGHT", cell, 0, 0)
	cell.borderTop = borderTop

	local borderBottom = cell:CreateColorDrawable(1, 1, 1, 0.05, "artwork")
	borderBottom:SetExtent(1, 1)
	borderBottom:AddAnchor("BOTTOMLEFT", cell, 0, 0)
	borderBottom:AddAnchor("BOTTOMRIGHT", cell, 0, 0)
	cell.borderBottom = borderBottom

	local borderLeft = cell:CreateColorDrawable(1, 1, 1, 0.05, "artwork")
	borderLeft:SetExtent(1, 1)
	borderLeft:AddAnchor("TOPLEFT", cell, 0, 0)
	borderLeft:AddAnchor("BOTTOMLEFT", cell, 0, 0)
	cell.borderLeft = borderLeft

	local borderRight = cell:CreateColorDrawable(1, 1, 1, 0.05, "artwork")
	borderRight:SetExtent(1, 1)
	borderRight:AddAnchor("TOPRIGHT", cell, 0, 0)
	borderRight:AddAnchor("BOTTOMRIGHT", cell, 0, 0)
	cell.borderRight = borderRight

	local nameLabel = cell:CreateChildWidget("label", "raidOrgMemberName" .. tostring(flatIndex), 0, true)
	nameLabel:SetText("")
	nameLabel.style:SetAlign(ALIGN_LEFT)
	nameLabel.style:SetFontSize(10)
	nameLabel.style:SetColor(0.94, 0.95, 0.96, 1)
	nameLabel.style:SetOutline(true)
	nameLabel:AddAnchor("LEFT", cell, 4, 0)
	DisableHitTesting(nameLabel)
	cell.nameLabel = nameLabel

	local distanceLabel = cell:CreateChildWidget("label", "raidOrgMemberDistance" .. tostring(flatIndex), 0, true)
	distanceLabel:SetText("")
	distanceLabel.style:SetAlign(ALIGN_LEFT)
	distanceLabel.style:SetFontSize(8)
	distanceLabel.style:SetColor(0.74, 0.76, 0.78, 1)
	distanceLabel.style:SetOutline(true)
	distanceLabel:AddAnchor("LEFT", cell, 4, 0)
	DisableHitTesting(distanceLabel)
	cell.distanceLabel = distanceLabel

	return cell
end

LayoutTopControls = function()
	local raidWindow = runtime.raidWindow
	if raidWindow == nil then
		return
	end

	local closeButton = runtime.closeButton
	local menuButton = runtime.menuButton
	local menuButtonLabel = runtime.menuButtonLabel
	local menuButtonBackground = runtime.menuButtonBackground
	local memberAreaButton = runtime.memberAreaButton
	local memberAreaLabel = runtime.memberAreaLabel
	if closeButton == nil
		or menuButton == nil
		or memberAreaButton == nil
		or memberAreaLabel == nil then
		return
	end

	local compact = raidWindow:GetWidth() < TOP_CONTROLS_HORIZONTAL_MIN_WIDTH
	runtime.compactTopControls = compact
	local memberAreaButtonWidth = 50
	if state.activeMemberArea == "co_raid" then
		memberAreaButtonWidth = 74
	end

	closeButton:RemoveAllAnchors()
	menuButton:RemoveAllAnchors()
	menuButton:SetExtent(TOP_MENU_BUTTON_WIDTH, TOP_MENU_BUTTON_HEIGHT)
	SetButtonDefaultBackgroundVisible(menuButton, false)
	if menuButtonLabel ~= nil then
		menuButtonLabel:RemoveAllAnchors()
		menuButtonLabel:SetExtent(TOP_MENU_BUTTON_WIDTH, TOP_MENU_BUTTON_HEIGHT)
	end
	TryCall(menuButtonBackground, "RemoveAllAnchors")
	memberAreaButton:RemoveAllAnchors()
	memberAreaLabel:RemoveAllAnchors()

	if compact then
		local rightOffset = TOP_BUTTON_COMPACT_RIGHT_OFFSET
		local menuRightOffset = rightOffset + TOP_BUTTON_WIDTH + TOP_BUTTON_GAP

		closeButton:AddAnchor("TOPRIGHT", raidWindow, -rightOffset, TOP_BUTTON_Y_OFFSET)
		menuButton:AddAnchor("TOPRIGHT", raidWindow, -menuRightOffset, TOP_BUTTON_Y_OFFSET)
		if menuButtonBackground ~= nil then
			menuButtonBackground:AddAnchor("TOPRIGHT", raidWindow, -menuRightOffset, TOP_BUTTON_Y_OFFSET)
		end
		if menuButtonLabel ~= nil then
			menuButtonLabel:AddAnchor("TOPRIGHT", raidWindow, -menuRightOffset, TOP_BUTTON_Y_OFFSET)
		end
		memberAreaButton:SetExtent(memberAreaButtonWidth, TOP_BUTTON_HEIGHT)
		memberAreaButton:AddAnchor("TOPLEFT", raidWindow, 7, TOP_BUTTON_Y_OFFSET)
		memberAreaLabel:SetExtent(0, TOP_BUTTON_HEIGHT)
		memberAreaLabel.style:SetAlign(ALIGN_LEFT)
		memberAreaLabel:AddAnchor("TOPLEFT", raidWindow, 7 + memberAreaButtonWidth, TOP_BUTTON_Y_OFFSET + 2)
	else
		closeButton:AddAnchor("TOPRIGHT", raidWindow, -TOP_BUTTON_X_OFFSET, TOP_BUTTON_Y_OFFSET)
		menuButton:AddAnchor(
			"TOPRIGHT",
			raidWindow,
			-(TOP_BUTTON_X_OFFSET + TOP_BUTTON_WIDTH + TOP_BUTTON_GAP),
			TOP_BUTTON_Y_OFFSET
		)
		if menuButtonBackground ~= nil then
			menuButtonBackground:AddAnchor(
				"TOPRIGHT",
				raidWindow,
				-(TOP_BUTTON_X_OFFSET + TOP_BUTTON_WIDTH + TOP_BUTTON_GAP),
				TOP_BUTTON_Y_OFFSET
			)
		end
		if menuButtonLabel ~= nil then
			menuButtonLabel:AddAnchor(
				"TOPRIGHT",
				raidWindow,
				-(TOP_BUTTON_X_OFFSET + TOP_BUTTON_WIDTH + TOP_BUTTON_GAP),
				TOP_BUTTON_Y_OFFSET
			)
		end
		memberAreaButton:SetExtent(memberAreaButtonWidth, TOP_BUTTON_HEIGHT)
		memberAreaButton:AddAnchor("TOPLEFT", raidWindow, 7, TOP_BUTTON_Y_OFFSET)
		memberAreaLabel:SetExtent(0, TOP_BUTTON_HEIGHT)
		memberAreaLabel.style:SetAlign(ALIGN_LEFT)
		memberAreaLabel:AddAnchor("TOPLEFT", raidWindow, 7 + memberAreaButtonWidth, TOP_BUTTON_Y_OFFSET + 2)
	end

	TryCall(closeButton, "Raise")
	TryCall(menuButton, "Raise")
	TryCall(runtime.menuButtonBackground, "Raise")
	TryCall(runtime.menuButtonBorderTop, "Raise")
	TryCall(runtime.menuButtonBorderBottom, "Raise")
	TryCall(runtime.menuButtonBorderLeft, "Raise")
	TryCall(runtime.menuButtonBorderRight, "Raise")
	TryCall(menuButtonLabel, "Raise")
	TryCall(memberAreaButton, "Raise")
	TryCall(memberAreaLabel, "Raise")
	if ApplyControlHoverWindow ~= nil then
		ApplyControlHoverWindow()
	end
end

LayoutMemberCells = function()
	local raidWindow = runtime.raidWindow
	if raidWindow == nil or runtime.memberCells == nil then
		return
	end

	LayoutTopControls()

	local contentWidth = raidWindow:GetWidth() - (MEMBER_GRID_PADDING_X * 2)
	local gridTop = GetMemberGridTop()
	local contentHeight = raidWindow:GetHeight() - gridTop - MEMBER_GRID_PADDING_Y
	local memberCount = runtime.visibleMemberCount or MEMBER_MAX_COUNT
	local columns = GetMemberGridColumns(memberCount)
	local rows = GetMemberGridRows(memberCount)
	local groupRows = GetMemberGroupRows(memberCount)
	local groupRowGap = state.memberGroupRowGap or DEFAULT_MEMBER_GROUP_ROW_GAP
	local cellWidth = math.floor((contentWidth - ((columns - 1) * MEMBER_CELL_GAP)) / columns)
	local rowGapHeight = ((rows - groupRows) * MEMBER_CELL_GAP) + ((groupRows - 1) * groupRowGap)
	local cellHeight = math.floor((contentHeight - rowGapHeight) / rows)
	if cellWidth < MEMBER_CELL_MIN_WIDTH then
		cellWidth = MEMBER_CELL_MIN_WIDTH
	end
	if cellHeight < MEMBER_CELL_MIN_HEIGHT then
		cellHeight = MEMBER_CELL_MIN_HEIGHT
	end

	for index, cell in ipairs(runtime.memberCells) do
		local groupIndex = math.floor((index - 1) / MEMBER_GROUP_SIZE)
		local groupColumn = groupIndex % MEMBER_GROUP_COLUMNS
		local groupRow = math.floor(groupIndex / MEMBER_GROUP_COLUMNS)
		local row = (index - 1) % MEMBER_GROUP_SIZE
		local x = MEMBER_GRID_PADDING_X + (groupColumn * (cellWidth + MEMBER_CELL_GAP))
		local groupHeight = (MEMBER_GROUP_SIZE * cellHeight) + ((MEMBER_GROUP_SIZE - 1) * MEMBER_CELL_GAP)
		local y = gridTop + (groupRow * (groupHeight + groupRowGap)) + (row * (cellHeight + MEMBER_CELL_GAP))

		cell:RemoveAllAnchors()
		cell:SetExtent(cellWidth, cellHeight)
		cell:AddAnchor("TOPLEFT", raidWindow, x, y)
		UpdateCellHealthFill(cell)

		local labelWidth = cellWidth - 8
		if labelWidth < 4 then
			labelWidth = 4
		end
		cell.nameCharacterLimit = math.floor(labelWidth / MEMBER_NAME_AVERAGE_CHAR_WIDTH)
		if cell.nameCharacterLimit < 1 then
			cell.nameCharacterLimit = 1
		end

		local nameHeight = math.floor(cellHeight * 0.58)
		if nameHeight < 8 then
			nameHeight = 8
		end
		local distanceHeight = cellHeight - nameHeight
		if distanceHeight < 6 then
			distanceHeight = 6
		end

		cell.nameLabel:RemoveAllAnchors()
		cell.nameLabel:SetExtent(labelWidth, nameHeight)
		cell.nameLabel:AddAnchor("TOPLEFT", cell, 4, 1)

		cell.distanceLabel:RemoveAllAnchors()
		cell.distanceLabel:SetExtent(labelWidth, distanceHeight)
		cell.distanceLabel:AddAnchor("TOPLEFT", cell, 4, nameHeight - 1)
		if cell.memberName ~= nil then
			ApplyCellInfoText(cell)
		end
	end
end

local function CreateMemberCells(parent)
	runtime.memberCells = {}
	for flatIndex = 1, MEMBER_MAX_COUNT do
		table.insert(runtime.memberCells, CreateMemberCell(parent, flatIndex))
	end
	LayoutMemberCells()
	UpdateAllMemberCells()
end

local function CreateEventWindow()
	local eventWindow = CreateEmptyWindow("raidOrgEventWindow", "UIParent")
	eventWindow:SetExtent(1, 1)
	eventWindow:AddAnchor("TOPLEFT", "UIParent", -20, -20)
	eventWindow:Show(true)
	runtime.eventWindow = eventWindow

	local events = {
		TEAM_MEMBERS_CHANGED = true,
		TEAM_MEMBER_DISCONNECTED = true,
		TEAM_MEMBER_UNIT_ID_CHANGED = true,
		TEAM_ROLE_CHANGED = true,
		TEAM_JOINTED = true,
		TEAM_JOINT_BROKEN = true,
		TEAM_JOINT_CHAT = true,
		TEAM_JOINT_TARGET = true,
	}

	eventWindow:SetHandler("OnEvent", function(this, event)
		if events[event] then
			UpdateAllMemberCells()
		end
	end)

	function eventWindow:OnUpdate()
		if runtime.raidWindow ~= nil and runtime.raidWindow:IsVisible() then
			UpdateControlHover()
		end
	end
	eventWindow:SetHandler("OnUpdate", eventWindow.OnUpdate)

	for eventName, _ in pairs(events) do
		eventWindow:RegisterEvent(eventName)
	end
end

local function CreateRaidWindow()
	state.rangeValue = LoadRangeValue()
	state.memberGroupRowGap = LoadGroupRowGap()
	runtime.loadHpAlertSettings()

	local width, height = LoadSize()
	local x, y = LoadPosition(WINDOW_POSITION_KEY, 520, 320)

	local raidWindow = CreateEmptyWindow("raidOrgWindow", "UIParent")
	ApplyRaidOrgLayer(raidWindow)
	raidWindow:SetExtent(width, height)
	raidWindow:AddAnchor("TOPLEFT", "UIParent", x, y)
	raidWindow:EnableDrag(true)
	raidWindow:Clickable(true)
	raidWindow:Show(false)
	runtime.raidWindow = raidWindow

	local controlHoverWindow = CreateEmptyWindow("raidOrgControlHoverWindow", "UIParent")
	ApplyRaidOrgLayer(controlHoverWindow)
	controlHoverWindow:SetExtent(width, MEMBER_GRID_TOP)
	controlHoverWindow:AddAnchor("TOPLEFT", raidWindow, 0, 0)
	controlHoverWindow:Clickable(true)
	controlHoverWindow:Show(false)
	function controlHoverWindow:OnEnter()
		state.controlHoverGraceRemaining = 0
		SetControlButtonsHidden(false)
	end
	controlHoverWindow:SetHandler("OnEnter", controlHoverWindow.OnEnter)
	function controlHoverWindow:OnLeave()
		state.controlHoverGraceRemaining = 0.35
	end
	controlHoverWindow:SetHandler("OnLeave", controlHoverWindow.OnLeave)
	runtime.controlHoverWindow = controlHoverWindow

	local background = raidWindow:CreateColorDrawable(0, 0, 0, WINDOW_BACKGROUND_ALPHA, "background")
	background:AddAnchor("TOPLEFT", raidWindow, 0, 0)
	background:AddAnchor("BOTTOMRIGHT", raidWindow, 0, 0)
	runtime.raidWindowBackground = background
	AttachControlHoverHandlers(background)

	local closeButton = raidWindow:CreateChildWidget("button", "raidOrgCloseButton", 0, true)
	closeButton:SetStyle("text_default")
	closeButton:SetText("X")
	closeButton:SetExtent(TOP_BUTTON_WIDTH, TOP_BUTTON_HEIGHT)
	closeButton:AddAnchor("TOPRIGHT", raidWindow, -TOP_BUTTON_X_OFFSET, TOP_BUTTON_Y_OFFSET)
	function closeButton:OnClick()
		SaveWidgetPosition(raidWindow, WINDOW_POSITION_KEY)
		SaveWindowSize(raidWindow)
		HideMenu()
		raidWindow:Show(false)
		ApplyLockState()
	end
	closeButton:SetHandler("OnClick", closeButton.OnClick)
	runtime.closeButton = closeButton

	local menuButton = raidWindow:CreateChildWidget("button", "raidOrgMenuButton", 0, true)
	menuButton:SetStyle("text_default")
	menuButton:SetText("")
	SafeCall(menuButton, "SetAutoResize", false)
	menuButton:SetExtent(TOP_MENU_BUTTON_WIDTH, TOP_MENU_BUTTON_HEIGHT)
	SafeCall(menuButton, "SetInset", 0, 0, 0, 0)
	menuButton:AddAnchor(
		"TOPRIGHT",
		raidWindow,
		-(TOP_BUTTON_X_OFFSET + TOP_BUTTON_WIDTH + TOP_BUTTON_GAP),
		TOP_BUTTON_Y_OFFSET
	)
	function menuButton:OnClick()
		ToggleMenu()
	end
	menuButton:SetHandler("OnClick", menuButton.OnClick)
	SetButtonDefaultBackgroundVisible(menuButton, false)
	runtime.menuButton = menuButton

	local menuButtonBackground = raidWindow:CreateColorDrawable(
		TOP_MENU_BUTTON_COLOR[1],
		TOP_MENU_BUTTON_COLOR[2],
		TOP_MENU_BUTTON_COLOR[3],
		TOP_MENU_BUTTON_COLOR[4],
		"artwork"
	)
	menuButtonBackground:SetExtent(TOP_MENU_BUTTON_WIDTH, TOP_MENU_BUTTON_HEIGHT)
	menuButtonBackground:AddAnchor(
		"TOPRIGHT",
		raidWindow,
		-(TOP_BUTTON_X_OFFSET + TOP_BUTTON_WIDTH + TOP_BUTTON_GAP),
		TOP_BUTTON_Y_OFFSET
	)
	runtime.menuButtonBackground = menuButtonBackground

	local menuButtonBorderTop = raidWindow:CreateColorDrawable(
		TOP_MENU_BUTTON_BORDER_COLOR[1],
		TOP_MENU_BUTTON_BORDER_COLOR[2],
		TOP_MENU_BUTTON_BORDER_COLOR[3],
		TOP_MENU_BUTTON_BORDER_COLOR[4],
		"artwork"
	)
	menuButtonBorderTop:SetExtent(1, 1)
	menuButtonBorderTop:AddAnchor("TOPLEFT", menuButtonBackground, 0, 0)
	menuButtonBorderTop:AddAnchor("TOPRIGHT", menuButtonBackground, 0, 0)
	runtime.menuButtonBorderTop = menuButtonBorderTop

	local menuButtonBorderBottom = raidWindow:CreateColorDrawable(
		TOP_MENU_BUTTON_BORDER_COLOR[1],
		TOP_MENU_BUTTON_BORDER_COLOR[2],
		TOP_MENU_BUTTON_BORDER_COLOR[3],
		TOP_MENU_BUTTON_BORDER_COLOR[4],
		"artwork"
	)
	menuButtonBorderBottom:SetExtent(1, 1)
	menuButtonBorderBottom:AddAnchor("BOTTOMLEFT", menuButtonBackground, 0, 0)
	menuButtonBorderBottom:AddAnchor("BOTTOMRIGHT", menuButtonBackground, 0, 0)
	runtime.menuButtonBorderBottom = menuButtonBorderBottom

	local menuButtonBorderLeft = raidWindow:CreateColorDrawable(
		TOP_MENU_BUTTON_BORDER_COLOR[1],
		TOP_MENU_BUTTON_BORDER_COLOR[2],
		TOP_MENU_BUTTON_BORDER_COLOR[3],
		TOP_MENU_BUTTON_BORDER_COLOR[4],
		"artwork"
	)
	menuButtonBorderLeft:SetExtent(1, 1)
	menuButtonBorderLeft:AddAnchor("TOPLEFT", menuButtonBackground, 0, 0)
	menuButtonBorderLeft:AddAnchor("BOTTOMLEFT", menuButtonBackground, 0, 0)
	runtime.menuButtonBorderLeft = menuButtonBorderLeft

	local menuButtonBorderRight = raidWindow:CreateColorDrawable(
		TOP_MENU_BUTTON_BORDER_COLOR[1],
		TOP_MENU_BUTTON_BORDER_COLOR[2],
		TOP_MENU_BUTTON_BORDER_COLOR[3],
		TOP_MENU_BUTTON_BORDER_COLOR[4],
		"artwork"
	)
	menuButtonBorderRight:SetExtent(1, 1)
	menuButtonBorderRight:AddAnchor("TOPRIGHT", menuButtonBackground, 0, 0)
	menuButtonBorderRight:AddAnchor("BOTTOMRIGHT", menuButtonBackground, 0, 0)
	runtime.menuButtonBorderRight = menuButtonBorderRight

	local menuButtonLabel = raidWindow:CreateChildWidget("label", "raidOrgMenuButtonLabel", 0, true)
	menuButtonLabel:SetText("M")
	menuButtonLabel:SetExtent(TOP_MENU_BUTTON_WIDTH, TOP_MENU_BUTTON_HEIGHT)
	menuButtonLabel.style:SetAlign(ALIGN_CENTER)
	menuButtonLabel.style:SetFontSize(12)
	menuButtonLabel.style:SetColor(0.12, 0.10, 0.06, 1)
	menuButtonLabel:AddAnchor(
		"TOPRIGHT",
		raidWindow,
		-(TOP_BUTTON_X_OFFSET + TOP_BUTTON_WIDTH + TOP_BUTTON_GAP),
		TOP_BUTTON_Y_OFFSET
	)
	DisableHitTesting(menuButtonLabel)
	runtime.menuButtonLabel = menuButtonLabel

	local memberAreaButton = raidWindow:CreateChildWidget("button", "raidOrgMemberAreaButton", 0, true)
	memberAreaButton:SetStyle("text_default")
	memberAreaButton:SetText("Raid")
	memberAreaButton:SetExtent(50, TOP_BUTTON_HEIGHT)
	memberAreaButton:AddAnchor("TOPLEFT", raidWindow, 7, TOP_BUTTON_Y_OFFSET)
	function memberAreaButton:OnClick()
		ToggleMemberArea()
	end
	memberAreaButton:SetHandler("OnClick", memberAreaButton.OnClick)
	runtime.memberAreaButton = memberAreaButton

	local memberAreaLabel = raidWindow:CreateChildWidget("label", "raidOrgMemberAreaLabel", 0, true)
	memberAreaLabel:SetText("")
	memberAreaLabel:SetExtent(0, TOP_BUTTON_HEIGHT)
	memberAreaLabel.style:SetAlign(ALIGN_LEFT)
	memberAreaLabel.style:SetFontSize(12)
	memberAreaLabel.style:SetColor(0.95, 0.92, 0.82, 1)
	memberAreaLabel.style:SetOutline(true)
	memberAreaLabel:AddAnchor("TOPLEFT", raidWindow, 116, TOP_BUTTON_Y_OFFSET + 2)
	runtime.memberAreaLabel = memberAreaLabel

	LayoutTopControls()
	AttachControlHoverHandlers(raidWindow)
	AttachControlHoverHandlers(closeButton)
	AttachControlHoverHandlers(menuButton)
	AttachControlHoverHandlers(memberAreaButton)
	AttachControlHoverHandlers(memberAreaLabel)

	function raidWindow:OnDragStart()
		if state.locked then
			return
		end
		self.isMovingRaidWindow = true
		self:StartMoving()
	end
	raidWindow:SetHandler("OnDragStart", raidWindow.OnDragStart)

	function raidWindow:OnUpdate(dt)
		if self.isMovingRaidWindow then
			PositionResizeHandles()
		end
		local delta = dt or 0.016
		if delta > 1 then
			delta = delta / 1000
		end
		UpdateControlHover(delta)
		state.memberRefreshElapsed = state.memberRefreshElapsed + delta
		if state.memberRefreshElapsed >= MEMBER_REFRESH_INTERVAL then
			state.memberRefreshElapsed = 0
			if self:IsVisible() then
				UpdateMemberDistances()
			end
		end
	end
	raidWindow:SetHandler("OnUpdate", raidWindow.OnUpdate)

	function raidWindow:OnDragStop()
		self:StopMovingOrSizing()
		self.isMovingRaidWindow = false
		SaveWidgetPosition(self, WINDOW_POSITION_KEY)
		PositionResizeHandles()
		if runtime.menuWindow ~= nil and runtime.menuWindow:IsVisible() then
			ToggleMenu()
			ToggleMenu()
		end
	end
	raidWindow:SetHandler("OnDragStop", raidWindow.OnDragStop)

	function raidWindow:OnHide()
		HideMenu()
		ApplyLockState()
	end
	raidWindow:SetHandler("OnHide", raidWindow.OnHide)

	runtime.resizeHandles = {
		CreateResizeHandle(raidWindow, "raidOrgResizeTopLeft", "TOPLEFT"),
		CreateResizeHandle(raidWindow, "raidOrgResizeTopRight", "TOPRIGHT"),
		CreateResizeHandle(raidWindow, "raidOrgResizeBottomLeft", "BOTTOMLEFT"),
		CreateResizeHandle(raidWindow, "raidOrgResizeBottomRight", "BOTTOMRIGHT"),
	}
	PositionResizeHandles()

	CreateMemberCells(raidWindow)
	CreateRangeWindow()
	runtime.createHpAlertWindow()
	CreateMenuWindow()
	ApplyModeButtons()
	return raidWindow
end

CreateLauncherButton()
CreateRaidWindow()
CreateEventWindow()
