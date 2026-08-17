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

function Analysis.GetTotalKillCount()
	local total = 0
	for _, count in pairs(runtime.killCounts) do
		count = tonumber(count)
		if count ~= nil and count > 0 then
			total = total + math.floor(count)
		end
	end
	return total
end

function Analysis.BuildSortedMobNames()
	local names = {}
	for mobName, count in pairs(runtime.killCounts) do
		if tonumber(count) ~= nil and tonumber(count) > 0 then
			names[#names + 1] = mobName
		end
	end
	table.sort(names, function(left, right)
		local leftCount = runtime.killCounts[left] or 0
		local rightCount = runtime.killCounts[right] or 0
		if leftCount ~= rightCount then
			return leftCount > rightCount
		end
		return string.lower(left) < string.lower(right)
	end)
	return names
end

function Analysis.GetTotalPages(totalRows)
	local pages = math.ceil(totalRows / PAGE_SIZE)
	if pages < 1 then
		return 1
	end
	return pages
end

function Analysis.ClampCurrentPage(totalRows)
	local totalPages = Analysis.GetTotalPages(totalRows)
	if runtime.currentPage < 1 then
		runtime.currentPage = 1
	elseif runtime.currentPage > totalPages then
		runtime.currentPage = totalPages
	end
	return totalPages
end

local windowX, windowY = LoadPosition(WINDOW_POSITION_KEY, 420, 318)
local windowWidth, windowHeight = Analysis.LoadWindowSize()
local counterWindow = CreateEmptyWindow("lootKillCounterWindow", "UIParent")
runtime.counterWindow = counterWindow
counterWindow:SetExtent(windowWidth, windowHeight)
counterWindow:AddAnchor("TOPLEFT", "UIParent", windowX, windowY)
counterWindow:EnableDrag(true)
counterWindow:Clickable(true)
counterWindow:Show(false)

local background = counterWindow:CreateColorDrawable(0, 0, 0, 0.68, "background")
background:AddAnchor("TOPLEFT", counterWindow, 0, 0)
background:AddAnchor("BOTTOMRIGHT", counterWindow, 0, 0)

local titleLabel = counterWindow:CreateChildWidget("label", "lootKillCounterTitle", 0, true)
titleLabel:SetText("Kill Counter: 0")
titleLabel:SetExtent(220, 24)
titleLabel.style:SetAlign(ALIGN_LEFT)
titleLabel.style:SetFontSize(13)
titleLabel.style:SetColor(0.95, 0.92, 0.82, 1)
titleLabel.style:SetOutline(true)
titleLabel:AddAnchor("TOPLEFT", counterWindow, PADDING, 10)
SafeCall(titleLabel, "EnableDrag", true)

local closeButton = counterWindow:CreateChildWidget("button", "lootKillCounterCloseButton", 0, true)
closeButton:SetStyle("text_default")
closeButton:SetText("X")
closeButton:SetExtent(32, 20)
closeButton:AddAnchor("TOPRIGHT", counterWindow, -PADDING, 9)

local historyButton = counterWindow:CreateChildWidget("button", "lootKillCounterHistoryButton", 0, true)
runtime.historyButton = historyButton
historyButton:SetStyle("text_default")
historyButton:SetText("History")
historyButton:SetExtent(64, 20)
historyButton:AddAnchor("TOPRIGHT", counterWindow, -PADDING - 36, 9)

local autoButton = counterWindow:CreateChildWidget("button", "lootKillCounterAutoButton", 0, true)
runtime.autoButton = autoButton
autoButton:SetStyle("text_default")
autoButton:SetText("Auto: Off")
autoButton:SetExtent(62, 20)
autoButton:AddAnchor("TOPRIGHT", counterWindow, -PADDING - 104, 9)

local statusLabel = counterWindow:CreateChildWidget("label", "lootKillCounterStatus", 0, true)
statusLabel:SetText("")
statusLabel:SetExtent(WINDOW_WIDTH - (PADDING * 2), 20)
statusLabel.style:SetAlign(ALIGN_LEFT)
statusLabel.style:SetFontSize(10)
statusLabel.style:SetColor(0.78, 0.84, 0.92, 1)
statusLabel.style:SetOutline(true)
statusLabel:AddAnchor("TOPLEFT", counterWindow, PADDING, 30)

for index = 1, PAGE_SIZE do
	local row = counterWindow:CreateChildWidget("label", "lootKillCounterRow" .. tostring(index), 0, true)
	row:SetText("")
	row:SetExtent(WINDOW_WIDTH - (PADDING * 2), ROW_HEIGHT)
	row.style:SetAlign(ALIGN_LEFT)
	row.style:SetFontSize(12)
	row.style:SetColor(1, 1, 1, 1)
	row.style:SetOutline(true)
	row:AddAnchor("TOPLEFT", counterWindow, PADDING, ROW_TOP + ((index - 1) * ROW_HEIGHT))
	runtime.rows[index] = row
end

local clearButton = counterWindow:CreateChildWidget("button", "lootKillCounterClearButton", 0, true)
clearButton:SetStyle("text_default")
clearButton:SetText("Clear")
clearButton:SetExtent(48, 22)
clearButton:AddAnchor("BOTTOMLEFT", counterWindow, PADDING, -PADDING)

local viewButton = counterWindow:CreateChildWidget("button", "lootKillCounterViewButton", 0, true)
runtime.viewButton = viewButton
viewButton:SetStyle("text_default")
viewButton:SetText("View")
viewButton:SetExtent(48, 22)
viewButton:AddAnchor("BOTTOMLEFT", counterWindow, PADDING + 52, -PADDING)

local prevButton = counterWindow:CreateChildWidget("button", "lootKillCounterPrevButton", 0, true)
prevButton:SetStyle("text_default")
prevButton:SetText("Prev")
prevButton:SetExtent(48, 22)
prevButton:AddAnchor("BOTTOMRIGHT", counterWindow, -122, -PADDING)

local nextButton = counterWindow:CreateChildWidget("button", "lootKillCounterNextButton", 0, true)
nextButton:SetStyle("text_default")
nextButton:SetText("Next")
nextButton:SetExtent(48, 22)
nextButton:AddAnchor("BOTTOMRIGHT", counterWindow, -PADDING, -PADDING)

local pageLabel = counterWindow:CreateChildWidget("label", "lootKillCounterPageLabel", 0, true)
pageLabel:SetText("")
pageLabel:SetExtent(38, 20)
pageLabel.style:SetAlign(ALIGN_CENTER)
pageLabel.style:SetFontSize(10)
pageLabel.style:SetColor(0.84, 0.84, 0.84, 1)
pageLabel.style:SetOutline(true)
pageLabel:AddAnchor("BOTTOMRIGHT", counterWindow, -67, -PADDING - 1)

-- PositionCounterResizeHandles provided via Analysis.PositionCounterResizeHandles
-- ShowCounterWindowButtons provided via Analysis.ShowCounterWindowButtons
-- ApplyResizeGripVisualScale provided via Analysis.ApplyResizeGripVisualScale
-- UpdateAutoOpenButton provided via Analysis.UpdateAutoOpenButton
local function GetCounterWindowScale()
	local widthScale = counterWindow:GetWidth() / WINDOW_WIDTH
	local heightScale = counterWindow:GetHeight() / WINDOW_HEIGHT
	local scale = widthScale
	if heightScale < scale then
		scale = heightScale
	end
	return ClampWindowScale(scale)
end

local function ApplyCounterWindowLayout()
	local width = counterWindow:GetWidth()
	local scale = GetCounterWindowScale()
	local padding = RoundScaled(PADDING, scale)
	local rowTop = RoundScaled(ROW_TOP, scale)
	local rowHeight = RoundScaled(ROW_HEIGHT, scale)
	local handleSize = RoundScaled(CORNER_HANDLE_SIZE, scale)
	local contentWidth = width - (padding * 2)
	if contentWidth < 1 then
		contentWidth = 1
	end

	local closeWidth = RoundScaled(32, scale)
	local closeHeight = RoundScaled(20, scale)
	local historyWidth = RoundScaled(64, scale)
	local autoWidth = RoundScaled(62, scale)
	local historyGap = RoundScaled(4, scale)
	local autoGap = RoundScaled(4, scale)
	local titleHeight = RoundScaled(24, scale)
	local statusHeight = RoundScaled(20, scale)
	local buttonHeight = RoundScaled(22, scale)
	local clearWidth = RoundScaled(48, scale)
	local viewWidth = RoundScaled(48, scale)
	local pageWidth = RoundScaled(38, scale)
	local pageHeight = RoundScaled(20, scale)
	local navWidth = RoundScaled(48, scale)
	local navGap = RoundScaled(4, scale)
	local titleWidth = width - (padding * 3) - closeWidth - historyWidth - historyGap - autoWidth - autoGap
	if titleWidth < 80 then
		titleWidth = 80
	end

	titleLabel:RemoveAllAnchors()
	titleLabel:AddAnchor("TOPLEFT", counterWindow, padding, padding)
	titleLabel:SetExtent(titleWidth, titleHeight)
	SetWidgetFontSize(titleLabel, RoundScaled(13, scale))

	closeButton:SetExtent(closeWidth, closeHeight)
	closeButton:RemoveAllAnchors()
	closeButton:AddAnchor("TOPRIGHT", counterWindow, -padding, padding - 1)
	SetWidgetFontSize(closeButton, RoundScaled(11, scale))

	historyButton:SetExtent(historyWidth, closeHeight)
	historyButton:RemoveAllAnchors()
	historyButton:AddAnchor("TOPRIGHT", counterWindow, -(padding + closeWidth + historyGap), padding - 1)
	SetWidgetFontSize(historyButton, RoundScaled(11, scale))

	autoButton:SetExtent(autoWidth, closeHeight)
	autoButton:RemoveAllAnchors()
	autoButton:AddAnchor(
		"TOPRIGHT",
		counterWindow,
		-(padding + closeWidth + historyGap + historyWidth + autoGap),
		padding - 1
	)
	SetWidgetFontSize(autoButton, RoundScaled(11, scale))
	if Analysis.UpdateAutoOpenButton ~= nil then
		Analysis.UpdateAutoOpenButton()
	end

	statusLabel:RemoveAllAnchors()
	statusLabel:AddAnchor("TOPLEFT", counterWindow, padding, RoundScaled(30, scale))
	statusLabel:SetExtent(contentWidth, statusHeight)
	SetWidgetFontSize(statusLabel, RoundScaled(10, scale))

	for index = 1, PAGE_SIZE do
		local row = runtime.rows[index]
		row:RemoveAllAnchors()
		row:AddAnchor("TOPLEFT", counterWindow, padding, rowTop + ((index - 1) * rowHeight))
		row:SetExtent(contentWidth, rowHeight)
		SetWidgetFontSize(row, RoundScaled(12, scale))
	end

	clearButton:SetExtent(clearWidth, buttonHeight)
	clearButton:RemoveAllAnchors()
	clearButton:AddAnchor("BOTTOMLEFT", counterWindow, padding, -padding)
	SetWidgetFontSize(clearButton, RoundScaled(11, scale))

	viewButton:SetExtent(viewWidth, buttonHeight)
	viewButton:RemoveAllAnchors()
	viewButton:AddAnchor("BOTTOMLEFT", counterWindow, padding + clearWidth + navGap, -padding)
	SetWidgetFontSize(viewButton, RoundScaled(11, scale))

	nextButton:SetExtent(navWidth, buttonHeight)
	nextButton:RemoveAllAnchors()
	nextButton:AddAnchor("BOTTOMRIGHT", counterWindow, -padding, -padding)
	SetWidgetFontSize(nextButton, RoundScaled(11, scale))

	prevButton:SetExtent(navWidth, buttonHeight)
	prevButton:RemoveAllAnchors()
	local prevLeft = padding + clearWidth + navGap + viewWidth + navGap
	local rightGroupWidth = navWidth + navGap + pageWidth + navGap + navWidth
	local rightGroupLeft = width - padding - rightGroupWidth
	if prevLeft + navWidth + navGap < rightGroupLeft then
		prevButton:AddAnchor("BOTTOMLEFT", counterWindow, prevLeft, -padding)
	else
		prevButton:AddAnchor("BOTTOMRIGHT", counterWindow, -(padding + navWidth + navGap + pageWidth + navGap), -padding)
	end
	SetWidgetFontSize(prevButton, RoundScaled(11, scale))

	pageLabel:SetExtent(pageWidth, pageHeight)
	pageLabel:RemoveAllAnchors()
	pageLabel:AddAnchor("BOTTOMRIGHT", counterWindow, -(padding + navWidth + navGap), -padding - 1)
	SetWidgetFontSize(pageLabel, RoundScaled(10, scale))

	for _, handle in ipairs(runtime.resizeHandles) do
		if handle ~= nil then
			handle:SetExtent(handleSize, handleSize)
			if Analysis.ApplyResizeGripVisualScale ~= nil then
				Analysis.ApplyResizeGripVisualScale(handle, scale)
			end
		end
	end

	if Analysis.PositionCounterResizeHandles ~= nil then
		Analysis.PositionCounterResizeHandles()
	end
end

local function SaveCounterWindowSize()
	local width, height = Analysis.ClampWindowSize(counterWindow:GetWidth(), counterWindow:GetHeight())
	SaveData(WINDOW_SIZE_KEY, { width = width, height = height })
end

local function ApplyCounterWindowGeometry(x, y, width, height, shouldSave)
	width, height = Analysis.ClampWindowSize(width, height)
	AnchorWidgetAtPosition(counterWindow, x, y)
	counterWindow:SetExtent(width, height)
	ApplyCounterWindowLayout()
	if shouldSave then
		SaveWidgetPosition(counterWindow, WINDOW_POSITION_KEY)
		SaveCounterWindowSize()
	end
end

Analysis.PositionCounterResizeHandles = function()
	local x, y = GetWidgetPosition(counterWindow)
	if x == nil or y == nil then
		return
	end

	local width = counterWindow:GetWidth()
	local height = counterWindow:GetHeight()
	local handleSize = RoundScaled(CORNER_HANDLE_SIZE, GetCounterWindowScale())
	for _, handle in ipairs(runtime.resizeHandles) do
		if handle ~= nil and not handle.isResizing then
			local handleX = x
			local handleY = y
			if not handle.resizeFromLeft then
				handleX = x + width - handleSize
			end
			if not handle.resizeFromTop then
				handleY = y + height - handleSize
			end
			AnchorWidgetAtPosition(handle, handleX, handleY)
			SafeCall(handle, "Raise")
		end
	end
end

local function SetCounterResizeHandlesVisible(visible)
	for _, handle in ipairs(runtime.resizeHandles) do
		if handle ~= nil then
			handle:Show(visible)
			if visible then
				SafeCall(handle, "Raise")
			end
		end
	end
end

local function ClampResizeGeometry(data, x, y, width, height)
	if width < MIN_WINDOW_WIDTH then
		if data.resizeFromLeft then
			x = data.startX + data.startWidth - MIN_WINDOW_WIDTH
		end
		width = MIN_WINDOW_WIDTH
	end

	if height < MIN_WINDOW_HEIGHT then
		if data.resizeFromTop then
			y = data.startY + data.startHeight - MIN_WINDOW_HEIGHT
		end
		height = MIN_WINDOW_HEIGHT
	end

	return x, y, width, height
end

local function ComputeResizeGeometry(handle)
	local data = handle.resizeDrag
	if data == nil then
		return nil
	end

	local handleX, handleY = GetWidgetPosition(handle)
	if handleX == nil or handleY == nil then
		return nil
	end

	local deltaX = handleX - data.handleStartX
	local deltaY = handleY - data.handleStartY
	local x = data.startX
	local y = data.startY
	local width = data.startWidth
	local height = data.startHeight

	if data.resizeFromLeft then
		x = data.startX + deltaX
		width = data.startWidth - deltaX
	else
		width = data.startWidth + deltaX
	end

	if data.resizeFromTop then
		y = data.startY + deltaY
		height = data.startHeight - deltaY
	else
		height = data.startHeight + deltaY
	end

	return ClampResizeGeometry(data, x, y, width, height)
end

local function UpdateResizeFromHandle(handle)
	local x, y, width, height = ComputeResizeGeometry(handle)
	if x ~= nil then
		ApplyCounterWindowGeometry(x, y, width, height, false)
	end
end

local function SetResizeGripAlpha(handle, alpha)
	if handle == nil or handle.gripLines == nil then
		return
	end
	for _, line in ipairs(handle.gripLines) do
		SafeCall(line, "SetColor", 1, 1, 1, alpha)
	end
end

local function AddResizeGripLine(handle, x, y, width, height)
	local line = handle:CreateColorDrawable(1, 1, 1, RESIZE_GRIP_LINE_ALPHA, "background")
	line:SetExtent(width, height)
	line:AddAnchor("TOPLEFT", handle, x, y)
	handle.gripLines[#handle.gripLines + 1] = line
end

local function CreateResizeGripVisuals(handle)
	handle.gripLines = {}

	local horizontalX
	local verticalX
	if handle.resizeFromLeft then
		horizontalX = RESIZE_GRIP_INSET
		verticalX = RESIZE_GRIP_INSET
	else
		horizontalX = CORNER_HANDLE_SIZE - RESIZE_GRIP_INSET - RESIZE_GRIP_LINE_LENGTH
		verticalX = CORNER_HANDLE_SIZE - RESIZE_GRIP_INSET - RESIZE_GRIP_LINE_THICKNESS
	end

	local horizontalY
	local verticalY
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

Analysis.ApplyResizeGripVisualScale = function(handle, scale)
	if handle == nil or handle.gripLines == nil then
		return
	end

	local handleSize = RoundScaled(CORNER_HANDLE_SIZE, scale)
	local lineLength = RoundScaled(RESIZE_GRIP_LINE_LENGTH, scale)
	local lineThickness = RoundScaled(RESIZE_GRIP_LINE_THICKNESS, scale)
	local inset = RoundScaled(RESIZE_GRIP_INSET, scale)

	local horizontalX
	local verticalX
	if handle.resizeFromLeft then
		horizontalX = inset
		verticalX = inset
	else
		horizontalX = handleSize - inset - lineLength
		verticalX = handleSize - inset - lineThickness
	end

	local horizontalY
	local verticalY
	if handle.resizeFromTop then
		horizontalY = inset
		verticalY = inset
	else
		horizontalY = handleSize - inset - lineThickness
		verticalY = handleSize - inset - lineLength
	end

	if handle.gripLines[1] ~= nil then
		handle.gripLines[1]:RemoveAllAnchors()
		handle.gripLines[1]:SetExtent(lineLength, lineThickness)
		handle.gripLines[1]:AddAnchor("TOPLEFT", handle, horizontalX, horizontalY)
	end
	if handle.gripLines[2] ~= nil then
		handle.gripLines[2]:RemoveAllAnchors()
		handle.gripLines[2]:SetExtent(lineThickness, lineLength)
		handle.gripLines[2]:AddAnchor("TOPLEFT", handle, verticalX, verticalY)
	end
end

local function CreateCounterResizeHandle(name, anchor)
	local handle = counterWindow:CreateChildWidget("button", name, 0, true)
	handle:SetText("")
	handle:SetExtent(CORNER_HANDLE_SIZE, CORNER_HANDLE_SIZE)
	handle:EnableDrag(true)
	handle:Clickable(true)
	handle.resizeFromLeft = string.find(anchor, "LEFT", 1, true) ~= nil
	handle.resizeFromTop = string.find(anchor, "TOP", 1, true) ~= nil
	handle:Show(false)
	CreateResizeGripVisuals(handle)

	function handle:OnEnter()
		Analysis.ShowCounterWindowButtons()
		SetResizeGripAlpha(self, RESIZE_GRIP_HOVER_ALPHA)
	end
	handle:SetHandler("OnEnter", handle.OnEnter)

	function handle:OnLeave()
		if not self.isResizing then
			SetResizeGripAlpha(self, RESIZE_GRIP_LINE_ALPHA)
		end
	end
	handle:SetHandler("OnLeave", handle.OnLeave)

	function handle:OnDragStart()
		local startX, startY = GetWidgetPosition(counterWindow)
		local handleStartX, handleStartY = GetWidgetPosition(self)
		if startX == nil or startY == nil or handleStartX == nil or handleStartY == nil then
			return
		end

		self.resizeDrag = {
			startX = startX,
			startY = startY,
			startWidth = counterWindow:GetWidth(),
			startHeight = counterWindow:GetHeight(),
			handleStartX = handleStartX,
			handleStartY = handleStartY,
			resizeFromLeft = self.resizeFromLeft,
			resizeFromTop = self.resizeFromTop,
		}
		self.isResizing = true
		SetResizeGripAlpha(self, RESIZE_GRIP_HOVER_ALPHA)
		Analysis.ShowCounterWindowButtons()
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
			ApplyCounterWindowGeometry(x, y, width, height, true)
		end
		self.resizeDrag = nil
		self.isResizing = false
		SetResizeGripAlpha(self, RESIZE_GRIP_LINE_ALPHA)
		Analysis.PositionCounterResizeHandles()
	end
	handle:SetHandler("OnDragStop", handle.OnDragStop)

	return handle
end

local counterWindowButtonsVisible

local function SetCounterWindowButtonsVisible(visible)
	if counterWindowButtonsVisible == visible then
		return
	end
	counterWindowButtonsVisible = visible
	closeButton:Show(visible)
	historyButton:Show(visible)
	autoButton:Show(visible)
	clearButton:Show(visible)
	viewButton:Show(visible)
	prevButton:Show(visible)
	nextButton:Show(visible)
end

Analysis.ShowCounterWindowButtons = function()
	SetCounterWindowButtonsVisible(true)
end

local function HideCounterWindowButtons()
	SetCounterWindowButtonsVisible(false)
end

local function EnableCounterWindowHover(surface)
	if surface == nil or type(surface.SetHandler) ~= "function" then
		return
	end
	surface:SetHandler("OnEnter", Analysis.ShowCounterWindowButtons)
end

local function StartCounterWindowDrag(surface)
	local now = Analysis.RefreshClock()
	if surface ~= nil then
		surface.counterDragSuppressUntil = now + 0.5
	end
	counterWindow:StartMoving()
	return true
end

local function StopCounterWindowDrag(surface)
	local now = Analysis.RefreshClock()
	if surface ~= nil then
		surface.counterDragSuppressUntil = now + 0.5
	end
	counterWindow:StopMovingOrSizing()
	SaveWidgetPosition(counterWindow, WINDOW_POSITION_KEY)
	Analysis.PositionCounterResizeHandles()
	return true
end

function Analysis.WasCounterWindowDragged(surface)
	local now = Analysis.RefreshClock()
	if surface == nil or surface.counterDragSuppressUntil == nil then
		return false
	end
	if now <= surface.counterDragSuppressUntil then
		surface.counterDragSuppressUntil = nil
		return true
	end
	surface.counterDragSuppressUntil = nil
	return false
end

local function EnableCounterWindowDrag(surface)
	if surface == nil then
		return
	end
	SafeCall(surface, "Clickable", true)
	SafeCall(surface, "EnableDrag", true)
	surface:SetHandler("OnDragStart", StartCounterWindowDrag)
	surface:SetHandler("OnDragStop", StopCounterWindowDrag)
end

runtime.resizeHandles = {
	CreateCounterResizeHandle("lootKillCounterResizeTopLeft", "TOPLEFT"),
	CreateCounterResizeHandle("lootKillCounterResizeTopRight", "TOPRIGHT"),
	CreateCounterResizeHandle("lootKillCounterResizeBottomLeft", "BOTTOMLEFT"),
	CreateCounterResizeHandle("lootKillCounterResizeBottomRight", "BOTTOMRIGHT"),
}
ApplyCounterWindowLayout()
SetCounterResizeHandlesVisible(false)

EnableCounterWindowDrag(titleLabel)
EnableCounterWindowDrag(statusLabel)
EnableCounterWindowDrag(pageLabel)
-- Action buttons stay clickable-only; drag-from-button was swallowing OnClick
-- via WasCounterWindowDragged after zero-move drag start/stop pairs.
EnableCounterWindowHover(titleLabel)
EnableCounterWindowHover(statusLabel)
EnableCounterWindowHover(pageLabel)
EnableCounterWindowHover(closeButton)
EnableCounterWindowHover(historyButton)
EnableCounterWindowHover(autoButton)
EnableCounterWindowHover(clearButton)
EnableCounterWindowHover(viewButton)
EnableCounterWindowHover(prevButton)
EnableCounterWindowHover(nextButton)
for index = 1, PAGE_SIZE do
	EnableCounterWindowDrag(runtime.rows[index])
	EnableCounterWindowHover(runtime.rows[index])
end
HideCounterWindowButtons()

Analysis.UpdateAutoOpenButton = function()
	if runtime.autoOpenCounterWindow == true then
		autoButton:SetText("Auto: On")
	else
		autoButton:SetText("Auto: Off")
	end
end
Analysis.UpdateAutoOpenButton()

Analysis.UpdateCounterWindow = function()
	local names = Analysis.BuildSortedMobNames()
	local totalPages = Analysis.ClampCurrentPage(#names)
	local startIndex = ((runtime.currentPage - 1) * PAGE_SIZE) + 1

	titleLabel:SetText(
		"Kill Counter: "
			.. tostring(Analysis.GetTotalKillCount())
			.. " | KPM "
			.. Analysis.FormatPerMinute(Analysis.GetKillsPerMinute(Analysis.RefreshClock()))
	)

	if runtime.lastKill ~= nil and runtime.lastKill.mobName ~= nil then
		statusLabel:SetText("Last: " .. tostring(runtime.lastKill.killerName or "Unknown") .. " -> " .. tostring(runtime.lastKill.mobName))
	else
		statusLabel:SetText("No kills tracked")
	end

	for rowIndex = 1, PAGE_SIZE do
		local mobName = names[startIndex + rowIndex - 1]
		local row = runtime.rows[rowIndex]
		if mobName == nil then
			row:SetText("")
			Analysis.ApplyCounterRowStyle(row, nil)
		else
			row:SetText(mobName .. ": " .. tostring(runtime.killCounts[mobName] or 0))
			Analysis.ApplyCounterRowStyle(row, mobName)
		end
	end

	pageLabel:SetText(tostring(runtime.currentPage) .. "/" .. tostring(totalPages))
end

function runtime:ShowCounterWindow()
	HideCounterWindowButtons()
	counterWindow:Show(true)
	SetCounterResizeHandlesVisible(true)
	Analysis.PositionCounterResizeHandles()
	Analysis.UpdateCounterWindow()
	SafeCall(counterWindow, "CorrectOffsetByScreen")
	SafeCall(counterWindow, "Raise")
end

function runtime:HideCounterWindow()
	SetCounterResizeHandlesVisible(false)
	if runtime.viewWindow ~= nil then
		runtime.viewWindow:Show(false)
	end
	if runtime.HideHistoryClearConfirm ~= nil then
		runtime:HideHistoryClearConfirm()
	end
	counterWindow:Show(false)
end

function runtime:ToggleCounterWindow()
	local visible = false
	if type(counterWindow.IsVisible) == "function" then
		local ok, isVisible = pcall(counterWindow.IsVisible, counterWindow)
		visible = ok and isVisible == true
	end
	if visible then
		self:HideCounterWindow()
	else
		self:ShowCounterWindow()
	end
end

function counterWindow:OnDragStart()
	self:StartMoving()
end
counterWindow:SetHandler("OnDragStart", counterWindow.OnDragStart)

function counterWindow:OnDragStop()
	self:StopMovingOrSizing()
	SaveWidgetPosition(self, WINDOW_POSITION_KEY)
	Analysis.PositionCounterResizeHandles()
end
counterWindow:SetHandler("OnDragStop", counterWindow.OnDragStop)

function counterWindow:OnEnter()
	Analysis.ShowCounterWindowButtons()
end
counterWindow:SetHandler("OnEnter", counterWindow.OnEnter)

function counterWindow:OnLeave()
	HideCounterWindowButtons()
end
counterWindow:SetHandler("OnLeave", counterWindow.OnLeave)

function closeButton:OnClick()
	if Analysis.WasCounterWindowDragged(self) then
		return
	end
	runtime:HideCounterWindow()
end
closeButton:SetHandler("OnClick", closeButton.OnClick)

function clearButton:OnClick()
	if Analysis.WasCounterWindowDragged(self) then
		return
	end
	Analysis.ClearKillCounts()
end
clearButton:SetHandler("OnClick", clearButton.OnClick)

-- Wire action buttons here (same file as widget creation). Methods may be
-- defined later in ui_view.lua; lookup happens at click time.
viewButton:SetHandler("OnClick", function(self)
	if Analysis.WasCounterWindowDragged(self) then
		return
	end
	if type(runtime.ShowViewWindow) == "function" then
		runtime:ShowViewWindow()
	end
end)

historyButton:SetHandler("OnClick", function(self)
	if Analysis.WasCounterWindowDragged(self) then
		return
	end
	if type(runtime.ShowHistoryWindow) == "function" then
		runtime:ShowHistoryWindow()
	end
end)

autoButton:SetHandler("OnClick", function(self)
	if Analysis.WasCounterWindowDragged(self) then
		return
	end
	runtime.autoOpenCounterWindow = not runtime.autoOpenCounterWindow
	if Analysis.UpdateAutoOpenButton ~= nil then
		Analysis.UpdateAutoOpenButton()
	end
	if Analysis.SaveCounterSettings ~= nil then
		Analysis.SaveCounterSettings()
	end
end)

function prevButton:OnClick()
	if Analysis.WasCounterWindowDragged(self) then
		return
	end
	runtime.currentPage = runtime.currentPage - 1
	Analysis.UpdateCounterWindow()
end
prevButton:SetHandler("OnClick", prevButton.OnClick)

function nextButton:OnClick()
	if Analysis.WasCounterWindowDragged(self) then
		return
	end
	runtime.currentPage = runtime.currentPage + 1
	Analysis.UpdateCounterWindow()
end
nextButton:SetHandler("OnClick", nextButton.OnClick)

