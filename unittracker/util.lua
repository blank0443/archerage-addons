local UT = _G.__UNIT_TRACKER
local runtime = _G.__UNIT_TRACKER_RUNTIME
if UT == nil or runtime == nil then
	return
end

local persist = UT.persist
local timing = UT.timing
local markerCfg = UT.markerCfg
local ui = UT.ui
local LIST_COLORS = UT.LIST_COLORS
local listSave = UT.listSave
local hotkeys = UT.hotkeys
local settings = UT.settings
local listView = UT.listView

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

local editboxApi = {
	GETTERS = {
		"GetText",
		"GetInputText",
		"GetEditText",
		"GetDisplayText",
		"GetString",
	},
	SETTERS = {
		"SetText",
		"SetInputText",
		"SetEditText",
		"SetDisplayText",
		"SetString",
	},
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
	_G.__UNIT_TRACKER_EDITBOX_SERIAL =
		(_G.__UNIT_TRACKER_EDITBOX_SERIAL or 0) + 1
	return baseName .. tostring(_G.__UNIT_TRACKER_EDITBOX_SERIAL)
end

local function ReadEditBoxText(state)
	if state == nil or state.widget == nil then
		return state ~= nil and state.text or ""
	end

	for _, methodName in ipairs(editboxApi.GETTERS) do
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
	for _, methodName in ipairs(editboxApi.SETTERS) do
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

		-- Multiline editboxes already insert one newline on Enter; only sync state.
		PollEditBoxText(state)
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

local function GetLocalPlayerUnitId()
	-- Cache the id: it is stable within a zone/session and is queried per combat event.
	if IsValidName(runtime.localPlayerUnitId) then
		return runtime.localPlayerUnitId
	end
	if X2Unit == nil then
		return nil
	end

	local ok, unitId = SafeCall(X2Unit, "GetUnitId", "player")
	if ok and IsValidName(unitId) then
		runtime.localPlayerUnitId = tostring(unitId)
		return runtime.localPlayerUnitId
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

-- Prefer false-negative safety: only treat the selected target as a player when
-- UnitInfo or GetUnitInfoById confirms type "character". NPCs/unknown stay out.
local function IsSelectedTargetPlayerCharacter(unitId)
	local okInfo, unitInfo = SafeCall(X2Unit, "UnitInfo", "target")
	if okInfo and type(unitInfo) == "table" then
		return unitInfo.type == "character"
	end
	return IsUnitIdPlayerCharacter(unitId)
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

-- Drop cache entries older than the damage-source window so these name->time
-- tables cannot grow without bound during long PvP sessions.
local function PruneStaleSourceTimes(times)
	local cutoff = Now() - timing.PLAYER_DAMAGE_SOURCE_CACHE_SECONDS
	for existingKey, lastSeenAt in pairs(times) do
		if tonumber(lastSeenAt) == nil or lastSeenAt < cutoff then
			times[existingKey] = nil
		end
	end
end

local function MaybePruneSourceCaches()
	if Now() - (runtime.lastSourceCachePruneAt or 0) < timing.SOURCE_CACHE_PRUNE_SECONDS then
		return
	end
	runtime.lastSourceCachePruneAt = Now()
	PruneStaleSourceTimes(runtime.recentPlayerDamageSourceTimes)
	PruneStaleSourceTimes(runtime.pendingDamageSourceTimes)
end

local function RememberRecentPlayerDamageSourceName(name)
	MaybePruneSourceCaches()
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
	return lastSeenAt ~= nil and Now() - lastSeenAt <= timing.PLAYER_DAMAGE_SOURCE_CACHE_SECONDS
end

local function RememberPendingDamageSourceName(name)
	MaybePruneSourceCaches()
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
	return lastSeenAt ~= nil and Now() - lastSeenAt <= timing.PLAYER_DAMAGE_SOURCE_CACHE_SECONDS
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

local function IsCurrentTargetPlayerSource(sourceName)
	local record = runtime.currentTarget or (UT.GetTargetRecord ~= nil and UT.GetTargetRecord() or nil)
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
	-- COMBAT_MSG only exposes a source name; verify via recent unit-id confirmation or current target.
	-- Team roster is not consulted: party/raid members cannot be the hostile auto-open source.
	return IsRecentPlayerDamageSourceName(sourceName)
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
	-- Clear then save: ArcheRage often keeps a stale blob if SaveData alone is used.
	pcall(function()
		ADDON:ClearData(key)
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
	SaveWidgetPosition(runtime.window, persist.POSITION_KEY)
end

local function SaveViewWindowPosition()
	SaveWidgetPosition(runtime.viewWindow, persist.VIEW_POSITION_KEY)
end

local function SaveOptsWindowPosition()
	SaveWidgetPosition(runtime.optsWindow, persist.OPTS_POSITION_KEY)
end

local function SaveNoteWindowPosition()
	SaveWidgetPosition(runtime.noteWindow, persist.NOTE_POSITION_KEY)
end

local function LoadPosition(key, defaultX, defaultY)
	local data = LoadData(key)
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

local function GetEntryGuild(entry)
	if type(entry) ~= "table" then
		return ""
	end
	return Trim(tostring(entry.guild or entry.expeditionName or entry.guildName or ""))
end

-- Returns true when the stored guild string changed (including clear-to-blank).
local function SetEntryGuild(entry, guild)
	if type(entry) ~= "table" then
		return false
	end
	guild = Trim(tostring(guild or ""))
	local previous = GetEntryGuild(entry)
	if guild == previous then
		return false
	end
	if guild == "" then
		entry.guild = nil
	else
		entry.guild = guild
	end
	return true
end

-- Faction colors use allowed GetUnitId + GetUnitInfoById (.faction string).
-- Local raw faction is cached on load; same = raw match or camp match.
-- Colors: pirate=pink, same=green, Nuia<->Haranya=red, unknown=orange.
runtime.faction = {}

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
	button:SetExtent(ui.BUTTON_WIDTH, ui.BUTTON_HEIGHT)
	button:AddAnchor("TOPLEFT", parent, x, y)
	return button
end

local function SetWidgetVisible(widget, visible)
	if widget ~= nil then
		widget:Show(visible == true)
	end
end

UT.SafeCall = SafeCall
UT.Trim = Trim
UT.NormalizeName = NormalizeName
UT.NormalizeNoteText = NormalizeNoteText
UT.CompactText = CompactText
UT.FirstStringArg = FirstStringArg
UT.NextEditBoxName = NextEditBoxName
UT.ReadEditBoxText = ReadEditBoxText
UT.SyncEditBoxText = SyncEditBoxText
UT.SetEditBoxText = SetEditBoxText
UT.ApplyEditBoxText = ApplyEditBoxText
UT.PollEditBoxText = PollEditBoxText
UT.ConfigureEditBoxWidget = ConfigureEditBoxWidget
UT.AttachEditBoxHandlers = AttachEditBoxHandlers
UT.CreateTrackedEditBox = CreateTrackedEditBox
UT.StripWorldSuffix = StripWorldSuffix
UT.NamesMatch = NamesMatch
UT.IsValidName = IsValidName
UT.Now = Now
UT.GetLocalPlayerName = GetLocalPlayerName
UT.IsLocalPlayerName = IsLocalPlayerName
UT.GetPlayerNameKey = GetPlayerNameKey
UT.GetLocalPlayerUnitId = GetLocalPlayerUnitId
UT.IsLocalPlayerUnitId = IsLocalPlayerUnitId
UT.GetUnitInfoById = GetUnitInfoById
UT.IsUnitIdPlayerCharacter = IsUnitIdPlayerCharacter
UT.IsSelectedTargetPlayerCharacter = IsSelectedTargetPlayerCharacter
UT.GetUnitNameById = GetUnitNameById
UT.PruneStaleSourceTimes = PruneStaleSourceTimes
UT.MaybePruneSourceCaches = MaybePruneSourceCaches
UT.RememberRecentPlayerDamageSourceName = RememberRecentPlayerDamageSourceName
UT.IsRecentPlayerDamageSourceName = IsRecentPlayerDamageSourceName
UT.RememberPendingDamageSourceName = RememberPendingDamageSourceName
UT.IsPendingDamageSourceName = IsPendingDamageSourceName
UT.GetCombatEventKind = GetCombatEventKind
UT.GetDamageAmount = GetDamageAmount
UT.ParseCombatMessage = ParseCombatMessage
UT.ParseCombatTextMessage = ParseCombatTextMessage
UT.IsDamageCombatText = IsDamageCombatText
UT.IsLocalPlayerCombatTarget = IsLocalPlayerCombatTarget
UT.IsCurrentTargetPlayerSource = IsCurrentTargetPlayerSource
UT.IsVerifiedPlayerDamageSource = IsVerifiedPlayerDamageSource
UT.IsIncomingDamageCandidate = IsIncomingDamageCandidate
UT.IsIncomingPlayerDamage = IsIncomingPlayerDamage
UT.SaveData = SaveData
UT.LoadData = LoadData
UT.GetWidgetPosition = GetWidgetPosition
UT.SaveWidgetPosition = SaveWidgetPosition
UT.SaveWindowPosition = SaveWindowPosition
UT.SaveViewWindowPosition = SaveViewWindowPosition
UT.SaveOptsWindowPosition = SaveOptsWindowPosition
UT.SaveNoteWindowPosition = SaveNoteWindowPosition
UT.LoadPosition = LoadPosition
UT.NormalizeUnitId = NormalizeUnitId
UT.GetEntryName = GetEntryName
UT.GetEntryUnitId = GetEntryUnitId
UT.GetEntryAddedAt = GetEntryAddedAt
UT.GetEntryGuild = GetEntryGuild
UT.SetEntryGuild = SetEntryGuild
UT.CreateLabel = CreateLabel
UT.CreateButton = CreateButton
UT.SetWidgetVisible = SetWidgetVisible
