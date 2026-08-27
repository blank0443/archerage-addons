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

local SetLabelColor = UT.SetLabelColor
local SetButtonTextColor = UT.SetButtonTextColor
local FormatNotePreview = UT.FormatNotePreview
local EstimateLabelPaintWidth = UT.EstimateLabelPaintWidth
local FitTextToLabelWidth = UT.FitTextToLabelWidth
local MeasureLabelTextWidth = UT.MeasureLabelTextWidth

local function GetTrackedNameForKey(key)
	if key == nil or key == "" then
		return nil
	end
	return GetEntryName(runtime.friendly[key] or runtime.hostile[key])
end

local function SetWindowStatus(window, message, color)
	if window ~= nil and window.statusLabel ~= nil then
		window.statusLabel:SetText(message or "")
		UT.SetLabelColor(window.statusLabel, color or { 0.72, 0.86, 1, 1 })
	end
end

local function RefreshNoteRemoveConfirm()
	local noteWindow = runtime.noteWindow
	if noteWindow == nil then
		return
	end

	local key = runtime.noteTargetKey
	local listName = nil
	if key ~= nil and key ~= "" then
		listName = select(1, UT.FindTrackedEntry(key, nil))
	end
	local confirming = listName ~= nil and UT.IsRemoveConfirmPending(listName, key)
	local pickingFaction = runtime.noteFactionPicker == true and not confirming

	UT.SetWidgetVisible(noteWindow.factionButton, not confirming and not pickingFaction)
	UT.SetWidgetVisible(noteWindow.removeButton, not confirming and not pickingFaction)
	UT.SetWidgetVisible(noteWindow.mapButton, not confirming and not pickingFaction)
	UT.SetWidgetVisible(noteWindow.saveButton, not confirming and not pickingFaction)
	UT.SetWidgetVisible(noteWindow.confirmNoButton, confirming)
	UT.SetWidgetVisible(noteWindow.confirmYesButton, confirming)
	UT.SetWidgetVisible(noteWindow.factionNuiaButton, pickingFaction)
	UT.SetWidgetVisible(noteWindow.factionHaranyaButton, pickingFaction)
	UT.SetWidgetVisible(noteWindow.factionPirateButton, pickingFaction)
	if pickingFaction then
		SafeCall(noteWindow.factionNuiaButton, "Enable", true)
		SafeCall(noteWindow.factionHaranyaButton, "Enable", true)
		SafeCall(noteWindow.factionPirateButton, "Enable", true)
		SafeCall(noteWindow.factionNuiaButton, "Raise")
		SafeCall(noteWindow.factionHaranyaButton, "Raise")
		SafeCall(noteWindow.factionPirateButton, "Raise")
	end
	UT.SetWidgetVisible(noteWindow.statusLabel, not pickingFaction)
	SafeCall(noteWindow.saveButton, "Enable", not confirming and not pickingFaction)
	SafeCall(noteWindow.removeButton, "Enable", not confirming and not pickingFaction)
	SafeCall(noteWindow.factionButton, "Enable", not confirming and not pickingFaction)
	if confirming or pickingFaction then
		SafeCall(noteWindow.mapButton, "Enable", false)
	elseif runtime.map.RefreshNoteMapButton ~= nil then
		runtime.map.RefreshNoteMapButton()
	end

	if confirming then
		SetWindowStatus(noteWindow, "Remove from list?", { 1, 0.52, 0.42, 1 })
	end
end

local function CloseNoteFactionPicker()
	runtime.noteFactionPicker = false
	if RefreshNoteRemoveConfirm ~= nil then
		RefreshNoteRemoveConfirm()
	end
end

local function OpenNoteFactionPicker()
	runtime.removeConfirm = nil
	runtime.noteFactionPicker = true
	if RefreshNoteRemoveConfirm ~= nil then
		RefreshNoteRemoveConfirm()
	end
	local noteWindow = runtime.noteWindow
	if noteWindow == nil then
		return
	end
	-- Pick buttons are created before Save/Map; raise so hidden siblings cannot steal clicks.
	SafeCall(noteWindow.factionNuiaButton, "Raise")
	SafeCall(noteWindow.factionHaranyaButton, "Raise")
	SafeCall(noteWindow.factionPirateButton, "Raise")
end

local function ApplyNoteFactionPick(camp)
	local key = runtime.noteTargetKey
	if not runtime.faction.SetManual(key, camp) then
		SetWindowStatus(runtime.noteWindow, "Faction not set.", { 1, 0.52, 0.42, 1 })
		CloseNoteFactionPicker()
		return
	end
	CloseNoteFactionPicker()
	SetWindowStatus(
		runtime.noteWindow,
		"Faction: " .. runtime.faction.DisplayName(camp) .. ".",
		{ 0.72, 0.86, 1, 1 }
	)
	-- Force a list redraw so the name color updates immediately.
	if runtime.RefreshViewList ~= nil then
		runtime.RefreshViewList()
	elseif UT.UpdateViewWindow ~= nil then
		UT.UpdateViewWindow()
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
	if runtime.editboxPollElapsed < timing.EDITBOX_POLL_SECONDS then
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
	UT.SaveLists(true)
	runtime.lastRefreshNote = runtime.notes[key]
	UT.UpdateWindowText()
	if UT.UpdateViewWindow ~= nil then
		UT.UpdateViewWindow()
	end
	SetWindowStatus(runtime.noteWindow, "Saved.", { 0.72, 0.86, 1, 1 })
end

local function CreateNoteInput(window)
	local state = CreateTrackedEditBox(
		window,
		"unitTrackerNoteInput",
		ui.NOTE_INPUT_LEFT,
		ui.NOTE_INPUT_TOP,
		ui.NOTE_INPUT_WIDTH,
		ui.NOTE_INPUT_HEIGHT,
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

	local noteX, noteY = LoadPosition(persist.NOTE_POSITION_KEY, 760, 420)
	local noteWindow = CreateEmptyWindow("unitTrackerNoteWindow", "UIParent")
	runtime.noteWindow = noteWindow
	noteWindow:SetExtent(ui.NOTE_WINDOW_WIDTH, ui.NOTE_WINDOW_HEIGHT)
	noteWindow:AddAnchor("TOPLEFT", "UIParent", noteX, noteY)
	noteWindow:EnableDrag(true)
	noteWindow:Clickable(true)
	noteWindow:Show(false)

	local background = noteWindow:CreateColorDrawable(0, 0, 0, 0.72, "background")
	background:AddAnchor("TOPLEFT", noteWindow, 0, 0)
	background:AddAnchor("BOTTOMRIGHT", noteWindow, 0, 0)

	noteWindow.titleLabel = CreateLabel(
		noteWindow,
		"unitTrackerNoteTitle",
		"Player Note",
		ui.NOTE_WINDOW_WIDTH - 44,
		22,
		ui.PADDING,
		6,
		11,
		{ 0.95, 0.92, 0.82, 1 }
	)
	SafeCall(noteWindow.titleLabel, "EnableDrag", true)
	-- Clickable so left-click can post the full name to local system chat for copy.
	SafeCall(noteWindow.titleLabel, "Clickable", true)
	SafeCall(noteWindow.titleLabel, "EnablePick", true)
	SafeCall(noteWindow.titleLabel, "EnableHitTest", true)
	SafeCall(noteWindow.titleLabel, "SetHitTestEnabled", true)

	noteWindow.closeButton = noteWindow:CreateChildWidget("button", "unitTrackerNoteCloseButton", 0, true)
	noteWindow.closeButton:SetStyle("text_default")
	noteWindow.closeButton:SetText("X")
	noteWindow.closeButton:SetExtent(26, 20)
	noteWindow.closeButton:AddAnchor("TOPRIGHT", noteWindow, -6, 6)

	CreateNoteInput(noteWindow)
	local dateY = ui.NOTE_INPUT_TOP + ui.NOTE_INPUT_HEIGHT + 2
	noteWindow.dateLabel = CreateLabel(
		noteWindow,
		"unitTrackerNoteDate",
		"",
		ui.NOTE_INPUT_WIDTH,
		ui.NOTE_DATE_LABEL_HEIGHT,
		ui.NOTE_INPUT_LEFT,
		dateY,
		10,
		{ 0.72, 0.86, 1, 1 }
	)
	if noteWindow.dateLabel.style ~= nil then
		noteWindow.dateLabel.style:SetAlign(ALIGN_LEFT)
	end

	local actionY = dateY + ui.NOTE_DATE_LABEL_HEIGHT + ui.NOTE_AFTER_DATE_GAP
	local actionBtnSize = runtime.map.BUTTON_SIZE
	local saveX = ui.NOTE_WINDOW_WIDTH - ui.PADDING - ui.BUTTON_WIDTH
	local mapButtonX = saveX - ui.BUTTON_GAP - actionBtnSize
	local removeButtonX = mapButtonX - ui.BUTTON_GAP - actionBtnSize
	local factionButtonX = removeButtonX - ui.BUTTON_GAP - actionBtnSize
	noteWindow.statusLabel = CreateLabel(
		noteWindow,
		"unitTrackerNoteStatus",
		"",
		factionButtonX - ui.PADDING - 4,
		18,
		ui.PADDING,
		actionY + 4,
		10,
		{ 0.72, 0.86, 1, 1 }
	)

	-- Faction pick sits left of Remove; opens Nuia/Haranya/Pirate choices.
	noteWindow.factionButton = noteWindow:CreateChildWidget("button", "unitTrackerNoteFactionButton", 0, true)
	noteWindow.factionButton:SetStyle("text_default")
	noteWindow.factionButton:SetText("F")
	noteWindow.factionButton:SetExtent(actionBtnSize, actionBtnSize)
	noteWindow.factionButton:AddAnchor("TOPLEFT", noteWindow, factionButtonX, actionY)
	noteWindow.factionButton:Show(true)

	-- Remove sits left of Map/Save; drops this player from friendly/hostile listing.
	noteWindow.removeButton = noteWindow:CreateChildWidget("button", "unitTrackerNoteRemoveButton", 0, true)
	noteWindow.removeButton:SetStyle("text_default")
	noteWindow.removeButton:SetText("R")
	noteWindow.removeButton:SetExtent(actionBtnSize, actionBtnSize)
	noteWindow.removeButton:AddAnchor("TOPLEFT", noteWindow, removeButtonX, actionY)
	noteWindow.removeButton:Show(true)
	SetButtonTextColor(noteWindow.removeButton, LIST_COLORS.hostile)

	-- N/Y confirm replaces F/R/M/Save while a note remove is pending.
	noteWindow.confirmNoButton = noteWindow:CreateChildWidget("button", "unitTrackerNoteConfirmNo", 0, true)
	noteWindow.confirmNoButton:SetStyle("text_default")
	noteWindow.confirmNoButton:SetText("N")
	noteWindow.confirmNoButton:SetExtent(actionBtnSize, actionBtnSize)
	noteWindow.confirmNoButton:AddAnchor("TOPLEFT", noteWindow, removeButtonX, actionY)
	noteWindow.confirmNoButton:Show(false)

	noteWindow.confirmYesButton = noteWindow:CreateChildWidget("button", "unitTrackerNoteConfirmYes", 0, true)
	noteWindow.confirmYesButton:SetStyle("text_default")
	noteWindow.confirmYesButton:SetText("Y")
	noteWindow.confirmYesButton:SetExtent(actionBtnSize, actionBtnSize)
	noteWindow.confirmYesButton:AddAnchor("TOPLEFT", noteWindow, mapButtonX, actionY)
	noteWindow.confirmYesButton:Show(false)
	SetButtonTextColor(noteWindow.confirmYesButton, LIST_COLORS.hostile)

	-- Map button sits immediately left of Save; opens saved add-location like kill_count history.
	noteWindow.mapButton = noteWindow:CreateChildWidget("button", "unitTrackerNoteMapButton", 0, true)
	noteWindow.mapButton:SetStyle("text_default")
	noteWindow.mapButton:SetText("M")
	noteWindow.mapButton:SetExtent(actionBtnSize, actionBtnSize)
	noteWindow.mapButton:AddAnchor("TOPLEFT", noteWindow, mapButtonX, actionY)
	noteWindow.mapButton:Show(true)
	noteWindow.mapButton:Enable(false)

	noteWindow.saveButton = CreateButton(
		noteWindow,
		"unitTrackerNoteSaveButton",
		"Save",
		saveX,
		actionY
	)

	-- Faction picker created last so Nuia/Haranya/Pirate sit above Map/Save for clicks.
	local factionPickWidth = math.floor((ui.NOTE_WINDOW_WIDTH - (ui.PADDING * 2) - (ui.BUTTON_GAP * 2)) / 3)
	noteWindow.factionNuiaButton = noteWindow:CreateChildWidget("button", "unitTrackerNoteFactionNuia", 0, true)
	noteWindow.factionNuiaButton:SetStyle("text_default")
	noteWindow.factionNuiaButton:SetText("Nuia")
	noteWindow.factionNuiaButton:SetExtent(factionPickWidth, actionBtnSize)
	noteWindow.factionNuiaButton:AddAnchor("TOPLEFT", noteWindow, ui.PADDING, actionY)
	noteWindow.factionNuiaButton:Show(false)
	SetButtonTextColor(noteWindow.factionNuiaButton, LIST_COLORS.sameFaction)

	noteWindow.factionHaranyaButton = noteWindow:CreateChildWidget("button", "unitTrackerNoteFactionHaranya", 0, true)
	noteWindow.factionHaranyaButton:SetStyle("text_default")
	noteWindow.factionHaranyaButton:SetText("Haranya")
	noteWindow.factionHaranyaButton:SetExtent(factionPickWidth, actionBtnSize)
	noteWindow.factionHaranyaButton:AddAnchor(
		"TOPLEFT",
		noteWindow,
		ui.PADDING + factionPickWidth + ui.BUTTON_GAP,
		actionY
	)
	noteWindow.factionHaranyaButton:Show(false)
	SetButtonTextColor(noteWindow.factionHaranyaButton, LIST_COLORS.hostile)

	noteWindow.factionPirateButton = noteWindow:CreateChildWidget("button", "unitTrackerNoteFactionPirate", 0, true)
	noteWindow.factionPirateButton:SetStyle("text_default")
	noteWindow.factionPirateButton:SetText("Pirate")
	noteWindow.factionPirateButton:SetExtent(factionPickWidth, actionBtnSize)
	noteWindow.factionPirateButton:AddAnchor(
		"TOPLEFT",
		noteWindow,
		ui.PADDING + (factionPickWidth + ui.BUTTON_GAP) * 2,
		actionY
	)
	noteWindow.factionPirateButton:Show(false)
	SetButtonTextColor(noteWindow.factionPirateButton, LIST_COLORS.pirate)

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

	-- Left-click posts the full player name to local system chat for chat-line copy.
	function noteWindow.titleLabel:OnClick()
		local name = GetTrackedNameForKey(runtime.noteTargetKey)
		if name == nil or Trim(tostring(name)) == "" then
			SetWindowStatus(noteWindow, "No player name.", { 1, 0.52, 0.42, 1 })
			return
		end
		if UT.DispatchExportStatus ~= nil then
			UT.DispatchExportStatus(tostring(name))
		end
		SetWindowStatus(noteWindow, "Name sent to chat.", { 0.72, 0.86, 1, 1 })
	end
	noteWindow.titleLabel:SetHandler("OnClick", noteWindow.titleLabel.OnClick)

	function noteWindow.closeButton:OnClick()
		runtime.noteFactionPicker = false
		SaveNoteWindowPosition()
		noteWindow:Show(false)
	end
	noteWindow.closeButton:SetHandler("OnClick", noteWindow.closeButton.OnClick)

	function noteWindow.mapButton:OnClick()
		runtime.map.OpenNoteTargetLocation()
	end
	noteWindow.mapButton:SetHandler("OnClick", noteWindow.mapButton.OnClick)

	function noteWindow.factionButton:OnClick()
		if runtime.noteFactionPicker then
			CloseNoteFactionPicker()
			SetWindowStatus(noteWindow, "", { 0.72, 0.86, 1, 1 })
			return
		end
		local key = runtime.noteTargetKey
		if key == nil or key == "" then
			SetWindowStatus(noteWindow, "No player selected.", { 1, 0.52, 0.42, 1 })
			return
		end
		if select(1, UT.FindTrackedEntry(key, nil)) == nil then
			SetWindowStatus(noteWindow, "Not on a list.", { 1, 0.52, 0.42, 1 })
			return
		end
		OpenNoteFactionPicker()
	end
	noteWindow.factionButton:SetHandler("OnClick", noteWindow.factionButton.OnClick)

	function noteWindow.factionNuiaButton:OnClick()
		ApplyNoteFactionPick("nuia")
	end
	noteWindow.factionNuiaButton:SetHandler("OnClick", noteWindow.factionNuiaButton.OnClick)

	function noteWindow.factionHaranyaButton:OnClick()
		ApplyNoteFactionPick("haranya")
	end
	noteWindow.factionHaranyaButton:SetHandler("OnClick", noteWindow.factionHaranyaButton.OnClick)

	function noteWindow.factionPirateButton:OnClick()
		ApplyNoteFactionPick("pirate")
	end
	noteWindow.factionPirateButton:SetHandler("OnClick", noteWindow.factionPirateButton.OnClick)

	function noteWindow.removeButton:OnClick()
		runtime.noteFactionPicker = false
		local key = runtime.noteTargetKey
		if key == nil or key == "" then
			SetWindowStatus(noteWindow, "No player selected.", { 1, 0.52, 0.42, 1 })
			return
		end
		local listName = select(1, UT.FindTrackedEntry(key, nil))
		if listName == nil then
			SetWindowStatus(noteWindow, "Not on a list.", { 1, 0.52, 0.42, 1 })
			return
		end
		UT.BeginRemoveConfirm(listName, key)
	end
	noteWindow.removeButton:SetHandler("OnClick", noteWindow.removeButton.OnClick)

	function noteWindow.confirmNoButton:OnClick()
		UT.ClearRemoveConfirm()
	end
	noteWindow.confirmNoButton:SetHandler("OnClick", noteWindow.confirmNoButton.OnClick)

	function noteWindow.confirmYesButton:OnClick()
		local key = runtime.noteTargetKey
		local listName = key ~= nil and select(1, UT.FindTrackedEntry(key, nil)) or nil
		if listName == nil or key == nil then
			UT.ClearRemoveConfirm()
			return
		end
		UT.RemoveNameFromList(listName, key)
	end
	noteWindow.confirmYesButton:SetHandler("OnClick", noteWindow.confirmYesButton.OnClick)

	function noteWindow.saveButton:OnClick()
		SaveNoteFromInput()
	end
	noteWindow.saveButton:SetHandler("OnClick", noteWindow.saveButton.OnClick)

	function noteWindow:OnUpdate(dt)
		runtime.map.UpdatePendingOverlay(dt)
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
	runtime.noteFactionPicker = false
	-- Drop any leftover View List / prior-note remove confirm when opening a note.
	if runtime.removeConfirm ~= nil and runtime.removeConfirm.key ~= key then
		runtime.removeConfirm = nil
		if UT.UpdateViewWindow ~= nil then
			UT.UpdateViewWindow()
		end
	end
	RefreshNoteRemoveConfirm()
	runtime.map.RefreshNoteMapButton()
	noteWindow:Show(true)
end

UT.GetTrackedNameForKey = GetTrackedNameForKey
UT.SetWindowStatus = SetWindowStatus
UT.RefreshNoteRemoveConfirm = RefreshNoteRemoveConfirm
UT.CloseNoteFactionPicker = CloseNoteFactionPicker
UT.OpenNoteFactionPicker = OpenNoteFactionPicker
UT.ApplyNoteFactionPick = ApplyNoteFactionPick
UT.NormalizeDt = NormalizeDt
UT.PollNoteEditBox = PollNoteEditBox
UT.SaveNoteFromInput = SaveNoteFromInput
UT.CreateNoteInput = CreateNoteInput
UT.CreateNoteWindow = CreateNoteWindow
UT.OpenNoteWindow = OpenNoteWindow
