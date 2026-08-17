-- Kill counter module (toc-ordered; uses LT + Analysis + runtime).
local LT = _G.__LOOT_TRACKER
local runtime = _G.__LOOT_KILL_COUNTER_RUNTIME
local Analysis = _G.__LOOT_KILL_COUNTER_ANALYSIS
local C = LT and LT.KC
if LT == nil or runtime == nil or Analysis == nil or C == nil then
	return
end

local SafeCall = LT.SafeCall
local SafeNumber = LT.SafeNumber
local SafeCallValues = LT.SafeCallValues
local Trim = LT.Trim
local NormalizeName = LT.NormalizeName
local IsValidName = LT.IsValidName
local NamesMatch = LT.NamesMatch
local NormalizeDt = LT.NormalizeDt
local Now = LT.Now
local SaveData = LT.SaveData
local LoadData = LT.LoadData
local GetWidgetPosition = LT.GetWidgetPosition
local SaveWidgetPosition = LT.SaveWidgetPosition
local LoadPosition = LT.LoadPosition
local ClampWindowScale = LT.ClampWindowScale
local RoundScaled = LT.RoundScaled
local SetWidgetFontSize = LT.SetWidgetFontSize
local AnchorWidgetAtPosition = LT.AnchorWidgetAtPosition

local SAVE_KEY = C.SAVE_KEY
local SETTINGS_SAVE_KEY = C.SETTINGS_SAVE_KEY
local HISTORY_SAVE_KEY = C.HISTORY_SAVE_KEY
local WINDOW_POSITION_KEY = C.WINDOW_POSITION_KEY
local WINDOW_SIZE_KEY = C.WINDOW_SIZE_KEY
local VIEW_WINDOW_POSITION_KEY = C.VIEW_WINDOW_POSITION_KEY
local WINDOW_WIDTH = C.WINDOW_WIDTH
local WINDOW_HEIGHT = C.WINDOW_HEIGHT
local MIN_WINDOW_WIDTH = C.MIN_WINDOW_WIDTH
local MIN_WINDOW_HEIGHT = C.MIN_WINDOW_HEIGHT
local VIEW_WINDOW_WIDTH = C.VIEW_WINDOW_WIDTH
local VIEW_WINDOW_HEIGHT = C.VIEW_WINDOW_HEIGHT
local VIEW_ROW_TOP = C.VIEW_ROW_TOP
local VIEW_ROW_HEIGHT = C.VIEW_ROW_HEIGHT
local VIEW_CONTENT_ROW_COUNT = C.VIEW_CONTENT_ROW_COUNT
local VIEW_SEGMENT_CHAR_WIDTH = C.VIEW_SEGMENT_CHAR_WIDTH
local MONEY_GOLD_COLOR = C.MONEY_GOLD_COLOR
local MONEY_SILVER_COLOR = C.MONEY_SILVER_COLOR
local MONEY_COPPER_COLOR = C.MONEY_COPPER_COLOR
local MONEY_LABEL_COLOR = C.MONEY_LABEL_COLOR
local BAG_KIND = C.BAG_KIND
local MAX_BAG_SLOTS = C.MAX_BAG_SLOTS
local PADDING = C.PADDING
local ROW_TOP = C.ROW_TOP
local ROW_HEIGHT = C.ROW_HEIGHT
local PAGE_SIZE = C.PAGE_SIZE
local CORNER_HANDLE_SIZE = C.CORNER_HANDLE_SIZE
local RESIZE_GRIP_LINE_ALPHA = C.RESIZE_GRIP_LINE_ALPHA
local RESIZE_GRIP_HOVER_ALPHA = C.RESIZE_GRIP_HOVER_ALPHA
local RESIZE_GRIP_LINE_LENGTH = C.RESIZE_GRIP_LINE_LENGTH
local RESIZE_GRIP_LINE_THICKNESS = C.RESIZE_GRIP_LINE_THICKNESS
local RESIZE_GRIP_INSET = C.RESIZE_GRIP_INSET
local MIN_WINDOW_SCALE = C.MIN_WINDOW_SCALE
local MAX_WINDOW_SCALE = C.MAX_WINDOW_SCALE
local DAMAGE_RECENT_SECONDS = C.DAMAGE_RECENT_SECONDS
local TARGET_CACHE_SECONDS = C.TARGET_CACHE_SECONDS
local LOOT_ATTRIBUTION_SECONDS = C.LOOT_ATTRIBUTION_SECONDS
local EXP_ATTRIBUTION_SECONDS = C.EXP_ATTRIBUTION_SECONDS
local PLAYER_COMBAT_EXIT_GRACE = C.PLAYER_COMBAT_EXIT_GRACE
local EXP_COMBAT_LOG_TIMEOUT = C.EXP_COMBAT_LOG_TIMEOUT
local PENDING_CAPTURE_DEDUPE_SECONDS = C.PENDING_CAPTURE_DEDUPE_SECONDS
local MONEY_EVENT_DEDUPE_SECONDS = C.MONEY_EVENT_DEDUPE_SECONDS
local MAX_PENDING_HITS_PER_TARGET = C.MAX_PENDING_HITS_PER_TARGET
local MAX_PENDING_HITS_TOTAL = C.MAX_PENDING_HITS_TOTAL
local ZONE_GROUP_NAMES = C.ZONE_GROUP_NAMES
local PROJECTILE_CAPTURE_REASONS = C.PROJECTILE_CAPTURE_REASONS
local FULL_HEALTH_CAPTURE_REASONS = C.FULL_HEALTH_CAPTURE_REASONS
local DAMAGE_CATEGORY_ORDER = C.DAMAGE_CATEGORY_ORDER

local viewWindowX, viewWindowY = LoadPosition(VIEW_WINDOW_POSITION_KEY, 720, 318)
local viewWindow = CreateEmptyWindow("lootKillCounterViewWindow", "UIParent")
runtime.viewWindow = viewWindow
viewWindow:SetExtent(VIEW_WINDOW_WIDTH, VIEW_WINDOW_HEIGHT)
viewWindow:AddAnchor("TOPLEFT", "UIParent", viewWindowX, viewWindowY)
viewWindow:EnableDrag(true)
viewWindow:Clickable(true)
viewWindow:Show(false)

local viewBackground = viewWindow:CreateColorDrawable(0, 0, 0, 0.72, "background")
viewBackground:AddAnchor("TOPLEFT", viewWindow, 0, 0)
viewBackground:AddAnchor("BOTTOMRIGHT", viewWindow, 0, 0)

local viewTitleLabel = viewWindow:CreateChildWidget("label", "lootKillCounterViewTitle", 0, true)
runtime.viewTitleLabel = viewTitleLabel
viewTitleLabel:SetText("Kill Session Analysis")
viewTitleLabel:SetExtent(VIEW_WINDOW_WIDTH - (PADDING * 2) - 220, 24)
viewTitleLabel.style:SetAlign(ALIGN_LEFT)
viewTitleLabel.style:SetFontSize(13)
viewTitleLabel.style:SetColor(0.95, 0.92, 0.82, 1)
viewTitleLabel.style:SetOutline(true)
viewTitleLabel:AddAnchor("TOPLEFT", viewWindow, PADDING, 10)

local viewCloseButton = viewWindow:CreateChildWidget("button", "lootKillCounterViewCloseButton", 0, true)
runtime.viewCloseButton = viewCloseButton
viewCloseButton:SetStyle("text_default")
viewCloseButton:SetText("X")
viewCloseButton:SetExtent(32, 20)
viewCloseButton:AddAnchor("TOPRIGHT", viewWindow, -PADDING, 9)

-- Nav cluster (Prev/Page/Next) is grouped next to the close button, and the
-- destructive Clear button is anchored on the far left of the cluster so it can
-- never sit adjacent to Next (prevents accidental history wipes while paging).
local historyNextButton = viewWindow:CreateChildWidget("button", "lootKillCounterHistoryNextButton", 0, true)
historyNextButton:SetStyle("text_default")
historyNextButton:SetText("Next")
historyNextButton:SetExtent(44, 20)
historyNextButton:AddAnchor("TOPRIGHT", viewWindow, -PADDING - 36, 9)

local historyPageLabel = viewWindow:CreateChildWidget("label", "lootKillCounterHistoryPageLabel", 0, true)
historyPageLabel:SetText("")
historyPageLabel:SetExtent(44, 20)
historyPageLabel.style:SetAlign(ALIGN_CENTER)
historyPageLabel.style:SetFontSize(10)
historyPageLabel.style:SetColor(0.84, 0.84, 0.84, 1)
historyPageLabel.style:SetOutline(true)
historyPageLabel:AddAnchor("TOPRIGHT", viewWindow, -PADDING - 84, 10)

local historyPrevButton = viewWindow:CreateChildWidget("button", "lootKillCounterHistoryPrevButton", 0, true)
historyPrevButton:SetStyle("text_default")
historyPrevButton:SetText("Prev")
historyPrevButton:SetExtent(44, 20)
historyPrevButton:AddAnchor("TOPRIGHT", viewWindow, -PADDING - 132, 9)

local historyClearButton = viewWindow:CreateChildWidget("button", "lootKillCounterHistoryClearButton", 0, true)
historyClearButton:SetStyle("text_default")
historyClearButton:SetText("Clear")
historyClearButton:SetExtent(48, 20)
historyClearButton:AddAnchor("TOPRIGHT", viewWindow, -PADDING - 184, 9)

-- Compact clear/delete confirm overlay: N cancels, Y confirms. Widgets live on runtime
-- to stay under the Lua 5.1 main-chunk local limit.
do
	local confirm = viewWindow:CreateChildWidget("window", "lootKillCounterHistoryClearConfirm", 0, true)
	runtime.historyClearConfirm = confirm
	confirm:SetExtent(188, 52)
	confirm:AddAnchor("TOP", viewWindow, 0, 34)
	confirm:Clickable(true)
	confirm:Show(false)
	local confirmBg = confirm:CreateColorDrawable(0.08, 0.08, 0.1, 0.94, "background")
	confirmBg:AddAnchor("TOPLEFT", confirm, 0, 0)
	confirmBg:AddAnchor("BOTTOMRIGHT", confirm, 0, 0)
	local confirmLabel = confirm:CreateChildWidget("label", "lootKillCounterHistoryClearConfirmLabel", 0, true)
	runtime.historyClearConfirmLabel = confirmLabel
	confirmLabel:SetText("Clear history?")
	confirmLabel:SetExtent(176, 18)
	confirmLabel.style:SetAlign(ALIGN_CENTER)
	confirmLabel.style:SetFontSize(10)
	confirmLabel.style:SetColor(0.95, 0.9, 0.78, 1)
	confirmLabel.style:SetOutline(true)
	confirmLabel:AddAnchor("TOP", confirm, 0, 4)
	local noButton = confirm:CreateChildWidget("button", "lootKillCounterHistoryClearConfirmNo", 0, true)
	runtime.historyClearConfirmNoButton = noButton
	noButton:SetStyle("text_default")
	noButton:SetText("N")
	noButton:SetExtent(36, 20)
	noButton:AddAnchor("BOTTOMLEFT", confirm, 28, -6)
	local yesButton = confirm:CreateChildWidget("button", "lootKillCounterHistoryClearConfirmYes", 0, true)
	runtime.historyClearConfirmYesButton = yesButton
	yesButton:SetStyle("text_default")
	yesButton:SetText("Y")
	yesButton:SetExtent(36, 20)
	yesButton:AddAnchor("BOTTOMRIGHT", confirm, -28, -6)
end

runtime.pendingHistoryDeleteSessionIndex = nil
local HISTORY_SESSION_DELETE_BUTTON_WIDTH = 18
local HISTORY_SESSION_DELETE_BUTTON_GAP = 2

function runtime:HideHistoryClearConfirm()
	self.pendingHistoryDeleteSessionIndex = nil
	if self.historyClearConfirm ~= nil then
		self.historyClearConfirm:Show(false)
	end
end

function runtime:ShowHistoryClearConfirm()
	if self.historyClearConfirm == nil then
		return
	end
	self.pendingHistoryDeleteSessionIndex = nil
	if self.historyClearConfirmLabel ~= nil then
		self.historyClearConfirmLabel:SetText("Clear history?")
	end
	self.historyClearConfirm:Show(true)
	SafeCall(self.historyClearConfirm, "Raise")
end

function runtime:ShowHistorySessionDeleteConfirm(sessionIndex)
	sessionIndex = math.floor(tonumber(sessionIndex) or 0)
	if self.historyClearConfirm == nil or sessionIndex < 1 then
		return
	end
	local session = Analysis.GetHistorySession(sessionIndex)
	if type(session) ~= "table" then
		return
	end
	self.pendingHistoryDeleteSessionIndex = sessionIndex
	local sessionName = Trim(session.name or ("S" .. tostring(sessionIndex)))
	if sessionName == "" then
		sessionName = "S" .. tostring(sessionIndex)
	end
	if self.historyClearConfirmLabel ~= nil then
		self.historyClearConfirmLabel:SetText("Delete " .. Analysis.TruncateText(sessionName, 18) .. "?")
	end
	self.historyClearConfirm:Show(true)
	SafeCall(self.historyClearConfirm, "Raise")
end

local viewSummaryLabel = viewWindow:CreateChildWidget("label", "lootKillCounterViewSummary", 0, true)
runtime.viewSummaryLabel = viewSummaryLabel
viewSummaryLabel:SetText("")
viewSummaryLabel:SetExtent(VIEW_WINDOW_WIDTH - (PADDING * 2), 36)
viewSummaryLabel.style:SetAlign(ALIGN_LEFT)
viewSummaryLabel.style:SetFontSize(10)
viewSummaryLabel.style:SetColor(0.78, 0.84, 0.92, 1)
viewSummaryLabel.style:SetOutline(true)
viewSummaryLabel:AddAnchor("TOPLEFT", viewWindow, PADDING, 34)

function Analysis.StartViewWindowDrag(surface)
	local now = Analysis.RefreshClock()
	if surface ~= nil then
		surface.viewDragSuppressUntil = now + 0.5
	end
	viewWindow:StartMoving()
	return true
end

function Analysis.StopViewWindowDrag(surface)
	local now = Analysis.RefreshClock()
	if surface ~= nil then
		surface.viewDragSuppressUntil = now + 0.5
	end
	viewWindow:StopMovingOrSizing()
	SaveWidgetPosition(viewWindow, VIEW_WINDOW_POSITION_KEY)
	return true
end

function Analysis.WasViewWindowDragged(surface)
	local now = Analysis.RefreshClock()
	if surface == nil or surface.viewDragSuppressUntil == nil then
		return false
	end
	if now <= surface.viewDragSuppressUntil then
		surface.viewDragSuppressUntil = nil
		return true
	end
	surface.viewDragSuppressUntil = nil
	return false
end

function Analysis.EnableViewWindowDrag(surface)
	if surface == nil then
		return
	end
	SafeCall(surface, "Clickable", true)
	SafeCall(surface, "EnablePick", true)
	SafeCall(surface, "EnableDrag", true)
	surface:SetHandler("OnDragStart", Analysis.StartViewWindowDrag)
	surface:SetHandler("OnDragStop", Analysis.StopViewWindowDrag)
end

for index = 1, VIEW_CONTENT_ROW_COUNT do
	local row = viewWindow:CreateChildWidget("label", "lootKillCounterViewRow" .. tostring(index), 0, true)
	local rowY = VIEW_ROW_TOP + ((index - 1) * VIEW_ROW_HEIGHT)
	row:SetText("")
	row:SetExtent(VIEW_WINDOW_WIDTH - (PADDING * 2), VIEW_ROW_HEIGHT)
	row.style:SetAlign(ALIGN_LEFT)
	row.style:SetFontSize(9)
	row.style:SetColor(1, 1, 1, 1)
	row.style:SetOutline(true)
	row:AddAnchor("TOPLEFT", viewWindow, PADDING, rowY)
	SafeCall(row, "EnablePick", true)
	SafeCall(row, "Clickable", true)
	function row:OnClick()
		if Analysis.WasViewWindowDragged(self) then
			return
		end
		if runtime.viewMode == "history" and self.historySessionIndex ~= nil then
			runtime:ShowKillMapSession(self.historySessionIndex)
		end
	end
	row:SetHandler("OnClick", row.OnClick)
	row.segmentLabels = {}
	row.viewRowY = rowY
	for segmentIndex = 1, 4 do
		local segment = viewWindow:CreateChildWidget(
			"label",
			"lootKillCounterViewRow" .. tostring(index) .. "Segment" .. tostring(segmentIndex),
			0,
			true
		)
		segment:SetText("")
		segment:SetExtent(1, VIEW_ROW_HEIGHT)
		segment.style:SetAlign(ALIGN_LEFT)
		segment.style:SetFontSize(9)
		segment.style:SetColor(1, 1, 1, 1)
		segment.style:SetOutline(true)
		segment:AddAnchor("TOPLEFT", viewWindow, PADDING, rowY)
		SafeCall(segment, "EnablePick", false)
		segment:Show(false)
		row.segmentLabels[segmentIndex] = segment
	end

	-- Per-session delete control shown at the end of history session-name rows only.
	local deleteButton = viewWindow:CreateChildWidget(
		"button",
		"lootKillCounterViewRowDelete" .. tostring(index),
		0,
		true
	)
	deleteButton:SetStyle("text_default")
	deleteButton:SetText("X")
	deleteButton:SetExtent(HISTORY_SESSION_DELETE_BUTTON_WIDTH, VIEW_ROW_HEIGHT)
	deleteButton:AddAnchor(
		"TOPRIGHT",
		viewWindow,
		-PADDING,
		rowY
	)
	deleteButton:Show(false)
	deleteButton.rowIndex = index
	function deleteButton:OnClick()
		if self.historySessionIndex == nil then
			return
		end
		runtime:ShowHistorySessionDeleteConfirm(self.historySessionIndex)
	end
	deleteButton:SetHandler("OnClick", deleteButton.OnClick)
	row.deleteButton = deleteButton

	runtime.viewContentRows[index] = row
end

Analysis.EnableViewWindowDrag(viewWindow)
Analysis.EnableViewWindowDrag(viewTitleLabel)
Analysis.EnableViewWindowDrag(viewSummaryLabel)
for index = 1, VIEW_CONTENT_ROW_COUNT do
	Analysis.EnableViewWindowDrag(runtime.viewContentRows[index])
end

function Analysis.SetHistorySessionDeleteButton(row, line)
	if row == nil then
		return
	end
	local deleteButton = row.deleteButton
	if deleteButton == nil then
		return
	end

	local showDelete = runtime.viewMode == "history"
		and type(line) == "table"
		and line.showSessionDelete == true
		and line.sessionIndex ~= nil
	if not showDelete then
		deleteButton.historySessionIndex = nil
		deleteButton:Show(false)
		row:SetExtent(VIEW_WINDOW_WIDTH - (PADDING * 2), VIEW_ROW_HEIGHT)
		return
	end

	deleteButton.historySessionIndex = line.sessionIndex
	deleteButton:Show(true)
	row:SetExtent(
		VIEW_WINDOW_WIDTH - (PADDING * 2) - HISTORY_SESSION_DELETE_BUTTON_WIDTH - HISTORY_SESSION_DELETE_BUTTON_GAP,
		VIEW_ROW_HEIGHT
	)
end

function Analysis.SetViewSegmentColor(label, color)
	if label == nil or label.style == nil then
		return
	end
	color = color or MONEY_LABEL_COLOR
	label.style:SetColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
end

function Analysis.MeasureViewSegmentText(text)
	return math.max(1, (#tostring(text or "") * VIEW_SEGMENT_CHAR_WIDTH) + 2)
end

function Analysis.HideViewRowSegments(row)
	if row == nil or type(row.segmentLabels) ~= "table" then
		return
	end
	for _, label in ipairs(row.segmentLabels) do
		if label ~= nil then
			label:SetText("")
			label:Show(false)
		end
	end
end

function Analysis.ApplyViewLineToRow(row, line)
	if row == nil then
		return
	end
	Analysis.HideViewRowSegments(row)
	if line == nil then
		row:SetText("")
		return
	end

	Analysis.ApplyViewLineStyle(row, line.kind)
	if type(line.segments) ~= "table" then
		row:SetText(tostring(line.text or ""))
		return
	end

	-- Money rows use sibling labels so gold, silver, and copper can each keep their own color.
	row:SetText("")
	local cursorX = PADDING
	for segmentIndex, segment in ipairs(line.segments) do
		local label = row.segmentLabels and row.segmentLabels[segmentIndex] or nil
		if label ~= nil then
			local text = tostring(segment.text or "")
			local width = Analysis.MeasureViewSegmentText(text)
			label:SetText(text)
			label:SetExtent(width, VIEW_ROW_HEIGHT)
			label:RemoveAllAnchors()
			label:AddAnchor("TOPLEFT", viewWindow, cursorX, row.viewRowY or 0)
			Analysis.SetViewSegmentColor(label, segment.color)
			label:Show(text ~= "")
			cursorX = cursorX + width
		end
	end
end

function Analysis.SetHistoryViewControlsVisible(visible, hasPages)
	historyClearButton:Show(visible and #runtime.historySessions > 0)
	historyPrevButton:Show(visible and hasPages == true)
	historyPageLabel:Show(visible and hasPages == true)
	historyNextButton:Show(visible and hasPages == true)
	if not visible then
		runtime:HideHistoryClearConfirm()
	end
end
Analysis.SetHistoryViewControlsVisible(false, false)

Analysis.UpdateViewWindow = function(forcedMode)
	if runtime.viewSummaryLabel == nil then
		return
	end
	local mode = forcedMode or runtime.viewMode or "current"
	if mode ~= "history" then
		mode = "current"
	end
	runtime.viewMode = mode

	if mode == "history" then
		runtime.viewTitleLabel:SetText("Kill Session History")
		runtime.viewTitleLabel:SetExtent(VIEW_WINDOW_WIDTH - (PADDING * 2) - 220, 24)
		local latest = runtime.historySessions[#runtime.historySessions]
		local summaryText = tostring(#runtime.historySessions) .. " saved sessions"
		if type(latest) == "table" and latest.name ~= nil then
			summaryText = summaryText .. " | Latest " .. tostring(latest.name)
		end
		runtime.viewSummaryLabel:SetText(summaryText)
		local historyLines, page, totalPages = Analysis.BuildHistoryDisplayLines()
		local hasPages = totalPages > 1
		historyPageLabel:SetText(tostring(page) .. "/" .. tostring(totalPages))
		Analysis.SetHistoryViewControlsVisible(true, hasPages)
		for rowIndex = 1, VIEW_CONTENT_ROW_COUNT do
			local row = runtime.viewContentRows[rowIndex]
			if row ~= nil then
				local line = historyLines[rowIndex]
				if line == nil then
					Analysis.ApplyViewLineToRow(row, nil)
					row.historySessionIndex = nil
					Analysis.SetHistorySessionDeleteButton(row, nil)
				else
					Analysis.ApplyViewLineToRow(row, line)
					row.historySessionIndex = line.sessionIndex
					Analysis.SetHistorySessionDeleteButton(row, line)
				end
			end
		end
		return
	end

	Analysis.SetHistoryViewControlsVisible(false, false)
	runtime.viewTitleLabel:SetText("Kill Session Analysis")
	runtime.viewTitleLabel:SetExtent(VIEW_WINDOW_WIDTH - (PADDING * 2) - 36, 24)
	local playerName = Analysis.GetLocalPlayerName() or "You"
	local summaryText = playerName .. " current session"
	local location = Analysis.CaptureCurrentSessionLocation()
	if IsValidName(location) then
		summaryText = summaryText .. " | " .. location
	end
	runtime.viewSummaryLabel:SetText(Analysis.TruncateText(summaryText, 120))

	local lines = nil
	local buildOk, buildResult = pcall(Analysis.BuildViewDisplayLines)
	if buildOk and type(buildResult) == "table" then
		lines = buildResult
	else
		lines = {
			{ kind = "unit", text = "  No session data recorded yet." },
			{ kind = "metric", text = "  Kill mobs or loot items, then open View again." },
		}
	end
	for rowIndex = 1, VIEW_CONTENT_ROW_COUNT do
		local row = runtime.viewContentRows[rowIndex]
		if row ~= nil then
			local line = lines[rowIndex]
			row.historySessionIndex = nil
			Analysis.SetHistorySessionDeleteButton(row, nil)
			if line == nil then
				Analysis.ApplyViewLineToRow(row, nil)
			else
				Analysis.ApplyViewLineToRow(row, line)
			end
		end
	end
end

Analysis.RefreshViewWindowIfVisible = function()
	if runtime.viewWindow == nil or Analysis.UpdateViewWindow == nil then
		return
	end
	local ok, visible = SafeCall(runtime.viewWindow, "IsVisible")
	if ok and visible then
		Analysis.UpdateViewWindow(runtime.viewMode)
	end
end

function runtime:ShowViewWindow()
	runtime:HideHistoryClearConfirm()
	runtime.viewMode = "current"
	-- Apply analysis chrome immediately so a content-update error cannot leave History UI visible.
	if runtime.viewTitleLabel ~= nil then
		runtime.viewTitleLabel:SetText("Kill Session Analysis")
		runtime.viewTitleLabel:SetExtent(VIEW_WINDOW_WIDTH - (PADDING * 2) - 36, 24)
	end
	Analysis.SetHistoryViewControlsVisible(false, false)
	viewWindow:Show(true)
	SafeCall(viewWindow, "CorrectOffsetByScreen")
	SafeCall(viewWindow, "Raise")
	pcall(function()
		Analysis.SyncSessionResourceSnapshots()
		Analysis.UpdateViewWindow("current")
	end)
end

function runtime:ShowHistoryWindow()
	runtime:HideHistoryClearConfirm()
	runtime.viewMode = "history"
	runtime.historyPage = 1
	if runtime.viewTitleLabel ~= nil then
		runtime.viewTitleLabel:SetText("Kill Session History")
		runtime.viewTitleLabel:SetExtent(VIEW_WINDOW_WIDTH - (PADDING * 2) - 220, 24)
	end
	viewWindow:Show(true)
	SafeCall(viewWindow, "CorrectOffsetByScreen")
	SafeCall(viewWindow, "Raise")
	pcall(function()
		Analysis.LoadSessionHistory()
		Analysis.UpdateViewWindow("history")
	end)
end

function viewCloseButton:OnClick()
	runtime:HideHistoryClearConfirm()
	viewWindow:Show(false)
end
viewCloseButton:SetHandler("OnClick", viewCloseButton.OnClick)

function historyClearButton:OnClick()
	if Analysis.WasViewWindowDragged(self) then
		return
	end
	if #runtime.historySessions <= 0 then
		return
	end
	runtime:ShowHistoryClearConfirm()
end
historyClearButton:SetHandler("OnClick", historyClearButton.OnClick)

do
	local noButton = runtime.historyClearConfirmNoButton
	local yesButton = runtime.historyClearConfirmYesButton
	function noButton:OnClick()
		runtime:HideHistoryClearConfirm()
	end
	noButton:SetHandler("OnClick", noButton.OnClick)

	function yesButton:OnClick()
		local sessionIndex = runtime.pendingHistoryDeleteSessionIndex
		runtime:HideHistoryClearConfirm()
		if sessionIndex ~= nil then
			Analysis.DeleteHistorySession(sessionIndex)
		else
			Analysis.ClearSessionHistory()
		end
	end
	yesButton:SetHandler("OnClick", yesButton.OnClick)
end

function historyPrevButton:OnClick()
	if Analysis.WasViewWindowDragged(self) then
		return
	end
	if runtime.historyPage > 1 then
		runtime.historyPage = runtime.historyPage - 1
	end
	if Analysis.UpdateViewWindow ~= nil then
		Analysis.UpdateViewWindow()
	end
end
historyPrevButton:SetHandler("OnClick", historyPrevButton.OnClick)

function historyNextButton:OnClick()
	if Analysis.WasViewWindowDragged(self) then
		return
	end
	runtime.historyPage = runtime.historyPage + 1
	if Analysis.UpdateViewWindow ~= nil then
		Analysis.UpdateViewWindow()
	end
end
historyNextButton:SetHandler("OnClick", historyNextButton.OnClick)

function runtime:ShowKillMapSession(sessionIndex)
	local session = Analysis.GetHistorySession(sessionIndex)
	if type(session) ~= "table" then
		return
	end
	runtime.killMapSessionIndex = tonumber(sessionIndex)
	runtime.pendingKillMapSession = nil
	Analysis.ClearKillMapObjects()
	local opened, hasMapCoordinates = Analysis.OpenKillSessionWorldMap(session)
	if opened and hasMapCoordinates then
		Analysis.ScheduleKillMapOverlay(session)
	end
end

