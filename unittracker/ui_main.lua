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

local SafeCall = UT.SafeCall
local Trim = UT.Trim
local NormalizeName = UT.NormalizeName
local NormalizeNoteText = UT.NormalizeNoteText
local CompactText = UT.CompactText
local CreateTrackedEditBox = UT.CreateTrackedEditBox
local SetEditBoxText = UT.SetEditBoxText
local PollEditBoxText = UT.PollEditBoxText
local StripWorldSuffix = UT.StripWorldSuffix
local NamesMatch = UT.NamesMatch
local IsValidName = UT.IsValidName
local Now = UT.Now
local GetLocalPlayerName = UT.GetLocalPlayerName
local IsLocalPlayerName = UT.IsLocalPlayerName
local GetPlayerNameKey = UT.GetPlayerNameKey
local GetLocalPlayerUnitId = UT.GetLocalPlayerUnitId
local IsLocalPlayerUnitId = UT.IsLocalPlayerUnitId
local GetUnitInfoById = UT.GetUnitInfoById
local IsUnitIdPlayerCharacter = UT.IsUnitIdPlayerCharacter
local IsSelectedTargetPlayerCharacter = UT.IsSelectedTargetPlayerCharacter
local GetUnitNameById = UT.GetUnitNameById
local MaybePruneSourceCaches = UT.MaybePruneSourceCaches
local RememberRecentPlayerDamageSourceName = UT.RememberRecentPlayerDamageSourceName
local IsRecentPlayerDamageSourceName = UT.IsRecentPlayerDamageSourceName
local RememberPendingDamageSourceName = UT.RememberPendingDamageSourceName
local IsPendingDamageSourceName = UT.IsPendingDamageSourceName
local GetDamageAmount = UT.GetDamageAmount
local ParseCombatMessage = UT.ParseCombatMessage
local ParseCombatTextMessage = UT.ParseCombatTextMessage
local IsDamageCombatText = UT.IsDamageCombatText
local IsIncomingPlayerDamage = UT.IsIncomingPlayerDamage
local IsIncomingDamageCandidate = UT.IsIncomingDamageCandidate
local SaveData = UT.SaveData
local LoadData = UT.LoadData
local SaveWindowPosition = UT.SaveWindowPosition
local SaveViewWindowPosition = UT.SaveViewWindowPosition
local SaveOptsWindowPosition = UT.SaveOptsWindowPosition
local SaveNoteWindowPosition = UT.SaveNoteWindowPosition
local LoadPosition = UT.LoadPosition
local NormalizeUnitId = UT.NormalizeUnitId
local GetEntryName = UT.GetEntryName
local GetEntryUnitId = UT.GetEntryUnitId
local GetEntryAddedAt = UT.GetEntryAddedAt
local GetEntryGuild = UT.GetEntryGuild
local SetEntryGuild = UT.SetEntryGuild
local CreateLabel = UT.CreateLabel
local CreateButton = UT.CreateButton
local SetWidgetVisible = UT.SetWidgetVisible

local function SetLabelColor(label, color)
	if label == nil or label.style == nil or type(color) ~= "table" then
		return
	end
	local r = tonumber(color[1]) or 1
	local g = tonumber(color[2]) or 1
	local b = tonumber(color[3]) or 1
	local a = tonumber(color[4]) or 1
	-- Re-assert outline after color; some styles reset paint when text changes.
	pcall(function()
		label.style:SetColor(r, g, b, a)
		label.style:SetOutline(true)
	end)
end

local function SetButtonTextColor(button, color)
	if button == nil or type(color) ~= "table" then
		return
	end
	SafeCall(button, "SetTextColor", color[1], color[2], color[3], color[4] or 1)
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

-- Painted outline text is wider than GetTextWidth / naive char guesses report.
-- Prefer over-estimate so guild never starts underneath the name.
local function EstimateLabelPaintWidth(label, text)
	text = tostring(text or "")
	if text == "" then
		return 0
	end

	local fontSize = 11
	if label ~= nil and label.style ~= nil then
		local okSize, size = pcall(function()
			return label.style:GetFontSize()
		end)
		if okSize and tonumber(size) ~= nil and tonumber(size) > 0 then
			fontSize = tonumber(size)
		end
	end

	-- Size-11 outline glyphs are roughly this wide; keep a floor so short names still clear.
	local byChars = string.len(text) * (fontSize * 0.85)
	local measured = MeasureLabelTextWidth(label, text)
	if measured ~= nil and measured > 0 then
		-- Inflate API width for outline; take the larger of the two estimates.
		measured = measured * 1.35 + 6
		if measured > byChars then
			return measured
		end
	end
	return byChars + 4
end

-- Truncate text so its estimated painted width fits maxWidth.
local function FitTextToLabelWidth(label, text, maxWidth)
	text = tostring(text or "")
	maxWidth = tonumber(maxWidth) or 0
	if text == "" or maxWidth <= 0 then
		return ""
	end

	if EstimateLabelPaintWidth(label, text) <= maxWidth then
		return text
	end

	local ellipsis = "..."
	if EstimateLabelPaintWidth(label, ellipsis) > maxWidth then
		return ""
	end

	local lo = 1
	local hi = string.len(text)
	local best = ellipsis
	while lo <= hi do
		local mid = math.floor((lo + hi) / 2)
		local candidate = string.sub(text, 1, mid) .. ellipsis
		if EstimateLabelPaintWidth(label, candidate) <= maxWidth then
			best = candidate
			lo = mid + 1
		else
			hi = mid - 1
		end
	end
	return best
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

	maxWidth = tonumber(maxWidth) or ui.NOTE_PREVIEW_WIDTH
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

	local trackedKey = UT.GetTrackedKeyForRecord(runtime.currentTarget)
	line1.trackedKey = trackedKey
	line2.trackedKey = trackedKey

	local note = ""
	if trackedKey ~= nil then
		note = NormalizeNoteText(runtime.notes[trackedKey] or "")
	end

	local preview1, preview2 = "", ""
	if note ~= "" then
		local previewWidth = ui.NOTE_PREVIEW_WIDTH
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
	SetLabelColor(line1, { 1, 0.9, 0.35, 1 })
	SetLabelColor(line2, { 1, 0.9, 0.35, 1 })
end

local function HideTrackerWindow()
	runtime.removeConfirm = nil
	hotkeys.CancelCapture()
	listSave.FlushNow()
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
	if runtime.exportNotifyWindow ~= nil then
		runtime.exportNotifyWindow:Show(false)
	end
	runtime.exportNotifyHideAt = 0
end

local function ShowTrackerWindow()
	if runtime.window ~= nil then
		runtime.window:Show(true)
		UT.RefreshTargetState()
	end
end

local function OpenTrackerWindowForIncomingDamage()
	if not settings.IsAutoOpenDamage() then
		return
	end
	if runtime.loading then
		return
	end
	if runtime.window == nil or runtime.window:IsVisible() then
		return
	end
	local now = Now()
	if now - (tonumber(runtime.lastAutoOpenTime) or 0) < timing.AUTO_OPEN_COOLDOWN_SECONDS then
		return
	end
	runtime.lastAutoOpenTime = now
	ShowTrackerWindow()
end

local function HandleCombatTextMessage(...)
	-- Auto-open is the only consumer of COMBAT_TEXT, so skip all work (including the
	-- message-table allocation) whenever an auto-open could not happen anyway.
	if not settings.IsAutoOpenDamage() then
		return
	end
	if runtime.loading then
		return
	end
	if runtime.window == nil or runtime.window:IsVisible() then
		return
	end
	if Now() - (tonumber(runtime.lastAutoOpenTime) or 0) < timing.AUTO_OPEN_COOLDOWN_SECONDS then
		return
	end

	-- Cheap pre-filter on raw args before allocating: positive damage aimed at us.
	local amount = tonumber(select(3, ...))
	if amount == nil or amount <= 0 then
		return
	end
	if not IsLocalPlayerUnitId(Trim(tostring(select(2, ...) or ""))) then
		return
	end

	local msg = ParseCombatTextMessage(...)
	if not IsDamageCombatText(msg) then
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
	if runtime.window ~= nil then
		return runtime.window
	end

	local windowX, windowY = LoadPosition(persist.POSITION_KEY, 460, 360)
	local window = CreateEmptyWindow("unitTrackerWindow", "UIParent")
	runtime.window = window
	window:SetExtent(ui.WINDOW_WIDTH, ui.WINDOW_HEIGHT)
	window:AddAnchor("TOPLEFT", "UIParent", windowX, windowY)
	window:EnableDrag(true)
	window:Clickable(true)
	window:Show(false)

	local background = window:CreateColorDrawable(0, 0, 0, 0.68, "background")
	background:AddAnchor("TOPLEFT", window, 0, 0)
	background:AddAnchor("BOTTOMRIGHT", window, 0, 0)

	window.titleLabel = CreateLabel(window, "unitTrackerTitle", "Unit Tracker", ui.WINDOW_WIDTH - 58, 22, ui.PADDING, 8, 13, {
		0.95,
		0.92,
		0.82,
		1,
	})
	SafeCall(window.titleLabel, "EnableDrag", true)

	window.closeButton = window:CreateChildWidget("button", "unitTrackerCloseButton", 0, true)
	window.closeButton:SetStyle("text_default")
	window.closeButton:SetText("X")
	window.closeButton:SetExtent(30, 20)
	window.closeButton:AddAnchor("TOPRIGHT", window, -ui.PADDING, 8)

	local function BindNotePreviewClick(label)
		SafeCall(label, "Clickable", true)
		SafeCall(label, "EnablePick", true)
		SafeCall(label, "EnableHitTest", true)
		SafeCall(label, "SetHitTestEnabled", true)
		function label:OnClick()
			local key = self.trackedKey
			if key == nil or key == "" then
				key = UT.GetTrackedKeyForRecord(runtime.currentTarget)
			end
			if key ~= nil and key ~= "" then
				UT.OpenNoteWindow(key)
			end
		end
		label:SetHandler("OnClick", label.OnClick)
	end

	window.noteLine1 = CreateLabel(
		window,
		"unitTrackerNoteLine1",
		"",
		ui.NOTE_PREVIEW_WIDTH,
		ui.NOTE_PREVIEW_LINE_HEIGHT,
		ui.PADDING,
		ui.NOTE_PREVIEW_TOP,
		11,
		{ 0.9, 0.9, 0.9, 1 }
	)
	window.noteLine2 = CreateLabel(
		window,
		"unitTrackerNoteLine2",
		"",
		ui.NOTE_PREVIEW_WIDTH,
		ui.NOTE_PREVIEW_LINE_HEIGHT,
		ui.PADDING,
		ui.NOTE_PREVIEW_TOP + ui.NOTE_PREVIEW_LINE_HEIGHT,
		11,
		{ 0.9, 0.9, 0.9, 1 }
	)
	SafeCall(window.noteLine1.style, "SetEllipsis", true)
	SafeCall(window.noteLine2.style, "SetEllipsis", true)
	-- Keep a combined clickable hit-area covering both preview lines.
	window.noteLabel = window.noteLine1
	BindNotePreviewClick(window.noteLine1)
	BindNotePreviewClick(window.noteLine2)

	-- Name box above Friendly/Hostile: typed text makes those buttons manual-add.
	window.addNameState = CreateTrackedEditBox(
		window,
		"unitTrackerAddName",
		ui.PADDING,
		ui.NAME_INPUT_TOP,
		ui.WINDOW_WIDTH - (ui.PADDING * 2),
		ui.NAME_INPUT_HEIGHT,
		40,
		"Add name...",
		function(text)
			runtime.addNameText = tostring(text or "")
		end
	)
	runtime.addNameState = window.addNameState
	SetEditBoxText(window.addNameState, runtime.addNameText or "", true)

	window.friendlyButton = CreateButton(
		window,
		"unitTrackerFriendlyButton",
		"Friendly",
		ui.PADDING,
		ui.BUTTON_ROW_Y
	)
	SetButtonTextColor(window.friendlyButton, LIST_COLORS.friendly)
	window.hostileButton = CreateButton(
		window,
		"unitTrackerHostileButton",
		"Hostile",
		ui.PADDING + ui.BUTTON_WIDTH + ui.BUTTON_GAP,
		ui.BUTTON_ROW_Y
	)
	SetButtonTextColor(window.hostileButton, LIST_COLORS.hostile)
	window.optsButton = CreateButton(
		window,
		"unitTrackerOptsButton",
		"Opts",
		ui.PADDING + ((ui.BUTTON_WIDTH + ui.BUTTON_GAP) * 2),
		ui.BUTTON_ROW_Y
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

	local function TryAddFromMainButtons(listName)
		PollEditBoxText(runtime.addNameState)
		local typed = Trim(runtime.addNameText or "")
		if typed ~= "" then
			UT.AddManualNameToList(listName, typed)
			return
		end
		UT.AddCurrentTargetToList(listName)
	end

	function window.friendlyButton:OnClick()
		TryAddFromMainButtons("friendly")
	end
	window.friendlyButton:SetHandler("OnClick", window.friendlyButton.OnClick)

	function window.hostileButton:OnClick()
		TryAddFromMainButtons("hostile")
	end
	window.hostileButton:SetHandler("OnClick", window.hostileButton.OnClick)

	function window.optsButton:OnClick()
		UT.OpenOptsWindow()
	end
	window.optsButton:SetHandler("OnClick", window.optsButton.OnClick)

	function window:OnUpdate(dt)
		if not runtime.active or runtime.loading then
			return
		end
		runtime.addNamePollElapsed = (tonumber(runtime.addNamePollElapsed) or 0) + NormalizeDt(dt)
		if runtime.addNamePollElapsed < timing.EDITBOX_POLL_SECONDS then
			return
		end
		runtime.addNamePollElapsed = 0
		PollEditBoxText(runtime.addNameState)
	end
	window:SetHandler("OnUpdate", window.OnUpdate)
end

UT.SetLabelColor = SetLabelColor
UT.SetButtonTextColor = SetButtonTextColor
UT.MeasureLabelTextWidth = MeasureLabelTextWidth
UT.EstimateLabelPaintWidth = EstimateLabelPaintWidth
UT.FitTextToLabelWidth = FitTextToLabelWidth
UT.FormatNotePreview = FormatNotePreview
UT.UpdateWindowText = UpdateWindowText
UT.HideTrackerWindow = HideTrackerWindow
UT.ShowTrackerWindow = ShowTrackerWindow
UT.OpenTrackerWindowForIncomingDamage = OpenTrackerWindowForIncomingDamage
UT.HandleCombatTextMessage = HandleCombatTextMessage
UT.CreateTrackerWindow = CreateTrackerWindow
