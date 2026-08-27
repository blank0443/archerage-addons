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

local function CreateOptsWindow()
	if runtime.optsWindow ~= nil then
		return runtime.optsWindow
	end

	local optsX, optsY = LoadPosition(persist.OPTS_POSITION_KEY, 520, 360)
	local optsWindow = CreateEmptyWindow("unitTrackerOptsWindow", "UIParent")
	runtime.optsWindow = optsWindow
	optsWindow:SetExtent(ui.OPTS_WINDOW_WIDTH, ui.OPTS_WINDOW_HEIGHT)
	optsWindow:AddAnchor("TOPLEFT", "UIParent", optsX, optsY)
	optsWindow:EnableDrag(true)
	optsWindow:Clickable(true)
	optsWindow:Show(false)

	local background = optsWindow:CreateColorDrawable(0, 0, 0, 0.72, "background")
	background:AddAnchor("TOPLEFT", optsWindow, 0, 0)
	background:AddAnchor("BOTTOMRIGHT", optsWindow, 0, 0)

	optsWindow.titleLabel = CreateLabel(
		optsWindow,
		"unitTrackerOptsTitle",
		"Opts",
		ui.OPTS_WINDOW_WIDTH - 58,
		22,
		ui.PADDING,
		8,
		13,
		{ 0.95, 0.92, 0.82, 1 }
	)
	SafeCall(optsWindow.titleLabel, "EnableDrag", true)

	optsWindow.closeButton = optsWindow:CreateChildWidget("button", "unitTrackerOptsCloseButton", 0, true)
	optsWindow.closeButton:SetStyle("text_default")
	optsWindow.closeButton:SetText("X")
	optsWindow.closeButton:SetExtent(30, 20)
	optsWindow.closeButton:AddAnchor("TOPRIGHT", optsWindow, -ui.PADDING, 8)

	local buttonY = 38
	local fullButtonWidth = ui.OPTS_WINDOW_WIDTH - (ui.PADDING * 2)

	optsWindow.viewListButton = CreateButton(
		optsWindow,
		"unitTrackerOptsViewListButton",
		"View List",
		ui.PADDING,
		buttonY
	)
	optsWindow.viewListButton:SetExtent(fullButtonWidth, ui.BUTTON_HEIGHT)
	buttonY = buttonY + ui.BUTTON_HEIGHT + ui.BUTTON_GAP

	optsWindow.exportButton = CreateButton(
		optsWindow,
		"unitTrackerOptsExportButton",
		"Export",
		ui.PADDING,
		buttonY
	)
	optsWindow.exportButton:SetExtent(fullButtonWidth, ui.BUTTON_HEIGHT)
	buttonY = buttonY + ui.BUTTON_HEIGHT + ui.BUTTON_GAP

	optsWindow.damagePopupButton = CreateButton(
		optsWindow,
		"unitTrackerOptsDamagePopupButton",
		settings.ButtonLabel("autoOpenDamage"),
		ui.PADDING,
		buttonY
	)
	optsWindow.damagePopupButton:SetExtent(fullButtonWidth, ui.BUTTON_HEIGHT)
	buttonY = buttonY + ui.BUTTON_HEIGHT + ui.BUTTON_GAP

	optsWindow.listPopupButton = CreateButton(
		optsWindow,
		"unitTrackerOptsListPopupButton",
		settings.ButtonLabel("autoOpenListedTarget"),
		ui.PADDING,
		buttonY
	)
	optsWindow.listPopupButton:SetExtent(fullButtonWidth, ui.BUTTON_HEIGHT)
	buttonY = buttonY + ui.BUTTON_HEIGHT + ui.BUTTON_GAP

	local hotkeyButtonWidth = fullButtonWidth - ui.VIEW_REMOVE_BUTTON_WIDTH - ui.VIEW_CONFIRM_GAP

	optsWindow.friendlyHotkeyButton = CreateButton(
		optsWindow,
		"unitTrackerOptsFriendlyHotkeyButton",
		hotkeys.ButtonLabel("friendly"),
		ui.PADDING,
		buttonY
	)
	optsWindow.friendlyHotkeyButton:SetExtent(hotkeyButtonWidth, ui.BUTTON_HEIGHT)
	UT.SetButtonTextColor(optsWindow.friendlyHotkeyButton, LIST_COLORS.friendly)

	optsWindow.friendlyHotkeyClearButton = optsWindow:CreateChildWidget(
		"button",
		"unitTrackerOptsFriendlyHotkeyClearButton",
		0,
		true
	)
	optsWindow.friendlyHotkeyClearButton:SetStyle("text_default")
	optsWindow.friendlyHotkeyClearButton:SetText("X")
	optsWindow.friendlyHotkeyClearButton:SetExtent(ui.VIEW_REMOVE_BUTTON_WIDTH, ui.BUTTON_HEIGHT)
	optsWindow.friendlyHotkeyClearButton:AddAnchor("TOPRIGHT", optsWindow, -ui.PADDING, buttonY)
	buttonY = buttonY + ui.BUTTON_HEIGHT + ui.BUTTON_GAP

	optsWindow.hostileHotkeyButton = CreateButton(
		optsWindow,
		"unitTrackerOptsHostileHotkeyButton",
		hotkeys.ButtonLabel("hostile"),
		ui.PADDING,
		buttonY
	)
	optsWindow.hostileHotkeyButton:SetExtent(hotkeyButtonWidth, ui.BUTTON_HEIGHT)
	UT.SetButtonTextColor(optsWindow.hostileHotkeyButton, LIST_COLORS.hostile)

	optsWindow.hostileHotkeyClearButton = optsWindow:CreateChildWidget(
		"button",
		"unitTrackerOptsHostileHotkeyClearButton",
		0,
		true
	)
	optsWindow.hostileHotkeyClearButton:SetStyle("text_default")
	optsWindow.hostileHotkeyClearButton:SetText("X")
	optsWindow.hostileHotkeyClearButton:SetExtent(ui.VIEW_REMOVE_BUTTON_WIDTH, ui.BUTTON_HEIGHT)
	optsWindow.hostileHotkeyClearButton:AddAnchor("TOPRIGHT", optsWindow, -ui.PADDING, buttonY)

	-- Focus target for capturing the next key press while assigning bindings.
	local captureInput = optsWindow:CreateChildWidgetByType(
		UOT_X2_EDITBOX,
		"unitTrackerHotkeyCaptureInput",
		0,
		true
	)
	captureInput:AddAnchor("TOPLEFT", optsWindow, ui.PADDING, ui.OPTS_WINDOW_HEIGHT - 2)
	captureInput:SetExtent(1, 1)
	SafeCall(captureInput, "SetMaxTextLength", 1)
	SafeCall(captureInput, "Show", true)
	SafeCall(captureInput, "EnableFocus", true)
	runtime.hotkeyCaptureInput = captureInput

	local function OnCaptureKey(arg1, arg2)
		local key = arg1
		-- Widget handlers may pass (self, key) or just (key).
		if type(arg1) == "table" or type(arg1) == "userdata" then
			key = arg2
		end
		if type(key) ~= "string" or key == "" then
			return
		end
		hotkeys.HandleCaptureKey(key)
	end

	SafeCall(captureInput, "SetHandler", "OnKeyDown", OnCaptureKey)
	SafeCall(captureInput, "SetHandler", "OnRawKeyDown", OnCaptureKey)
	SafeCall(optsWindow, "SetHandler", "OnKeyDown", OnCaptureKey)
	SafeCall(optsWindow, "SetHandler", "OnRawKeyDown", OnCaptureKey)

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
		hotkeys.CancelCapture()
		SaveOptsWindowPosition()
		optsWindow:Show(false)
	end
	optsWindow.closeButton:SetHandler("OnClick", optsWindow.closeButton.OnClick)

	function optsWindow.viewListButton:OnClick()
		hotkeys.CancelCapture()
		UT.OpenViewWindow()
	end
	optsWindow.viewListButton:SetHandler("OnClick", optsWindow.viewListButton.OnClick)

	function optsWindow.exportButton:OnClick()
		hotkeys.CancelCapture()
		UT.ExportPlayerLists()
	end
	optsWindow.exportButton:SetHandler("OnClick", optsWindow.exportButton.OnClick)

	function optsWindow.damagePopupButton:OnClick()
		hotkeys.CancelCapture()
		settings.Toggle("autoOpenDamage")
	end
	optsWindow.damagePopupButton:SetHandler("OnClick", optsWindow.damagePopupButton.OnClick)

	function optsWindow.listPopupButton:OnClick()
		hotkeys.CancelCapture()
		settings.Toggle("autoOpenListedTarget")
	end
	optsWindow.listPopupButton:SetHandler("OnClick", optsWindow.listPopupButton.OnClick)

	function optsWindow.friendlyHotkeyButton:OnClick()
		hotkeys.BeginCapture("friendly")
	end
	optsWindow.friendlyHotkeyButton:SetHandler("OnClick", optsWindow.friendlyHotkeyButton.OnClick)

	function optsWindow.friendlyHotkeyClearButton:OnClick()
		hotkeys.CancelCapture()
		hotkeys.Assign("friendly", "")
	end
	optsWindow.friendlyHotkeyClearButton:SetHandler("OnClick", optsWindow.friendlyHotkeyClearButton.OnClick)

	function optsWindow.hostileHotkeyButton:OnClick()
		hotkeys.BeginCapture("hostile")
	end
	optsWindow.hostileHotkeyButton:SetHandler("OnClick", optsWindow.hostileHotkeyButton.OnClick)

	function optsWindow.hostileHotkeyClearButton:OnClick()
		hotkeys.CancelCapture()
		hotkeys.Assign("hostile", "")
	end
	optsWindow.hostileHotkeyClearButton:SetHandler("OnClick", optsWindow.hostileHotkeyClearButton.OnClick)

	hotkeys.RefreshButtons()
	settings.RefreshButtons()
	return optsWindow
end

local function OpenOptsWindow()
	local optsWindow = CreateOptsWindow()
	hotkeys.RefreshButtons()
	settings.RefreshButtons()
	optsWindow:Show(true)
end

UT.CreateOptsWindow = CreateOptsWindow
UT.OpenOptsWindow = OpenOptsWindow
