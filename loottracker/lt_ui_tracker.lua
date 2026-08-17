-- Loot tracker module (toc-ordered; uses LT + runtime).
local LT = _G.__LOOT_TRACKER
local runtime = _G.__LOOT_TRACKER_RUNTIME
local CONFIG = LT and LT.C
if LT == nil or runtime == nil or CONFIG == nil then
	return
end

local SafeMethod = LT.SafeMethod
local SafeCall = LT.SafeCall
local IsRightMouseButton = LT.IsRightMouseButton
local NormalizeDt = LT.NormalizeDt
local Trim = LT.Trim
local NormalizeName = LT.NormalizeName
local CurrentClock = LT.CurrentClock
local CompactNameLimit = LT.CompactNameLimit
local GetWidgetSavedPosition = LT.GetWidgetSavedPosition
local SaveWidgetPosition = LT.SaveWidgetSavedPosition
local LoadSavedPosition = LT.LoadSavedPosition
local ExtractItemName = LT.ExtractItemName
local ExtractItemGrade = LT.ExtractItemGrade
local ExtractItemIconCacheKey = LT.ExtractItemIconCacheKey
local ExtractIconPathValue = LT.ExtractIconPathValue
local ExtractItemIconPath = LT.ExtractItemIconPath
local ExtractItemCount = LT.ExtractItemCount
local BuildItemKey = LT.BuildItemKey
local ReadBagItem = LT.ReadBagItem
local ITEM_ID_FIELD_NAMES = CONFIG.ITEM_ID_FIELD_NAMES
local ICON_FIELD_NAMES = CONFIG.ICON_FIELD_NAMES
local COUNT_FIELD_NAMES = CONFIG.COUNT_FIELD_NAMES

local trackedItems = runtime.trackedItems
local rowWidgets = runtime.rowWidgets
local pickerItemWidgets = runtime.pickerItemWidgets
local inventoryIconPathCache = runtime.inventoryIconPathCache
local trackerSlotRightDrag = runtime.trackerSlotRightDrag

function runtime:ClampScale(scale)
	scale = tonumber(scale) or 1
	if scale < 0.85 then
		return 0.85
	end
	if scale > 1.35 then
		return 1.35
	end
	return scale
end

function runtime:Scale(value)
	local number = tonumber(value) or 0
	local scaled = math.floor((number * self:ClampScale(self.trackerScale)) + 0.5)
	if scaled < 1 and number > 0 then
		return 1
	end
	return scaled
end

function runtime:ScaleAt(value, scale)
	local number = tonumber(value) or 0
	local scaled = math.floor((number * self:ClampScale(scale)) + 0.5)
	if scaled < 1 and number > 0 then
		return 1
	end
	return scaled
end

function runtime:GetBaseRowsSpan()
	return (runtime.trackedSlotCount * CONFIG.BOX_SIZE) + ((runtime.trackedSlotCount - 1) * CONFIG.BOX_GAP)
end

function runtime:GetBaseWindowWidth()
	if not runtime.trackerHeaderControlsVisible then
		if runtime.trackerLayout == CONFIG.LAYOUT_VERTICAL then
			return CONFIG.BOX_SIZE
		end
		return self:GetBaseRowsSpan()
	end

	if runtime.trackerLayout == CONFIG.LAYOUT_VERTICAL then
		return CONFIG.BOX_SIZE
			+ CONFIG.HEADER_BUTTON_GAP
			+ math.max(CONFIG.HIDE_WINDOW_BUTTON_WIDTH, CONFIG.MENU_BUTTON_WIDTH, CONFIG.LOOT_RATE_MARKER_WIDTH)
	end
	return math.max(
		self:GetBaseRowsSpan(),
		CONFIG.HEADER_TITLE_WIDTH
			+ CONFIG.LOOT_RATE_MARKER_WIDTH
			+ CONFIG.HEADER_BUTTON_GAP
			+ CONFIG.ROTATE_BUTTON_WIDTH
			+ CONFIG.RESET_BUTTON_WIDTH
			+ CONFIG.SET_BUTTON_WIDTH
			+ CONFIG.MENU_BUTTON_WIDTH
			+ CONFIG.RESET_BUTTON_WIDTH
			+ CONFIG.RESET_BUTTON_WIDTH
			+ CONFIG.RESET_BUTTON_WIDTH
			+ CONFIG.HIDE_WINDOW_BUTTON_WIDTH
			+ (CONFIG.HEADER_BUTTON_GAP * 8)
	) + (CONFIG.TRACKER_PADDING * 2)
end

function runtime:GetBaseWindowHeight()
	if runtime.trackerLayout == CONFIG.LAYOUT_VERTICAL then
		if not runtime.trackerHeaderControlsVisible then
			return self:GetBaseRowsSpan()
		end
		return math.max(self:GetBaseRowsSpan(), (CONFIG.HEADER_BUTTON_HEIGHT * 9) + (CONFIG.HEADER_BUTTON_GAP * 8))
	end
	if not runtime.trackerHeaderControlsVisible then
		return CONFIG.BOX_SIZE
	end
	return CONFIG.BOXES_TOP + CONFIG.BOX_SIZE + CONFIG.TRACKER_PADDING
end

function runtime.GetTrackedRowsSpan()
	return runtime:Scale(runtime:GetBaseRowsSpan())
end

function runtime.GetTrackerWindowWidth()
	return runtime:Scale(runtime:GetBaseWindowWidth())
end

function runtime.GetTrackedRowsLeft()
	if runtime.trackerLayout == CONFIG.LAYOUT_VERTICAL then
		return 0
	end
	return math.floor((runtime.GetTrackerWindowWidth() - runtime.GetTrackedRowsSpan()) / 2)
end

function runtime.GetTrackedRowsTop()
	if not runtime.trackerHeaderControlsVisible then
		return 0
	end

	if runtime.trackerLayout == CONFIG.LAYOUT_VERTICAL then
		return 0
	end
	return runtime:Scale(CONFIG.BOXES_TOP)
end

function runtime.GetTrackerWindowHeight()
	return runtime:Scale(runtime:GetBaseWindowHeight())
end

function runtime.HideIconDrawable(iconDrawable)
	if iconDrawable == nil then
		return
	end
	SafeMethod(iconDrawable, "SetVisible", false)
	SafeMethod(iconDrawable, "Show", false)
end

function runtime.SetIconDrawable(iconDrawable, iconPath)
	-- Sets an icon drawable to display the given icon path, clearing previous if needed, or hides if empty.
	if iconDrawable == nil then
		return
	end

	local nextIconPath = Trim(iconPath)
	if nextIconPath == "" then
		iconDrawable.currentIconPath = nil
		runtime.HideIconDrawable(iconDrawable)
		return
	end

	if iconDrawable.currentIconPath ~= nextIconPath then
		SafeMethod(iconDrawable, "ClearAllTextures")
		local ok = SafeMethod(iconDrawable, "AddTexture", nextIconPath)
		if not ok then
			iconDrawable.currentIconPath = nil
			runtime.HideIconDrawable(iconDrawable)
			return
		end
		iconDrawable.currentIconPath = nextIconPath
	end

	if not SafeMethod(iconDrawable, "SetVisible", true) then
		SafeMethod(iconDrawable, "Show", true)
	end
end

local function ApplyTrackedDropRateTextColor(label)
	if label == nil or label.style == nil then
		return
	end
	local color = CONFIG.TRACKED_DROP_RATE_TEXT_COLOR
	label.style:SetColor(color[1], color[2], color[3], color[4])
end

local function ApplyTrackedSessionCountTextColor(label)
	if label == nil or label.style == nil then
		return
	end
	local color = CONFIG.TRACKED_SESSION_COUNT_TEXT_COLOR
	label.style:SetColor(color[1], color[2], color[3], color[4])
end

function runtime.SetRowDropRateText(row, text)
	if row == nil then
		return
	end

	local nextText = tostring(text or "")
	local visible = nextText ~= "" and row.dropRateLabel ~= nil
	if row.dropRateLabel ~= nil then
		local textChanged = row.lastDropRateText ~= nextText
		local visibilityChanged = row.lastDropRateVisible ~= visible
		if textChanged then
			row.dropRateLabel:SetText(nextText)
			row.lastDropRateText = nextText
		end
		if textChanged or visibilityChanged then
			if visible then
				ApplyTrackedDropRateTextColor(row.dropRateLabel)
				row.dropRateLabel:Show(true)
				SafeMethod(row.dropRateLabel, "Raise")
			else
				row.dropRateLabel:Show(false)
			end
			row.lastDropRateVisible = visible
		end
	end
	if row.nameLabel ~= nil then
		row.nameLabel:Show(false)
	end
end

function runtime.SetRowSessionAcquiredText(row, text)
	if row == nil or row.sessionAcquiredLabel == nil then
		return
	end

	local nextText = tostring(text or "")
	if row.lastSessionAcquiredText ~= nextText then
		row.sessionAcquiredLabel:SetText(nextText)
		row.lastSessionAcquiredText = nextText
	end
	ApplyTrackedSessionCountTextColor(row.sessionAcquiredLabel)
	row.sessionAcquiredLabel:Show(nextText ~= "")
	if nextText ~= "" then
		SafeMethod(row.sessionAcquiredLabel, "Raise")
	end
	if row.nameLabel ~= nil then
		row.nameLabel:Show(false)
	end
end

local function SetRowBackground(row, state)
	if row == nil or row.bg == nil then
		return
	end

	if state == "tracked" then
		row.bg:SetColor(0.08, 0.14, 0.10, 0.88)
	elseif state == "missing" then
		row.bg:SetColor(0.16, 0.08, 0.07, 0.82)
	else
		row.bg:SetColor(0.06, 0.06, 0.07, 0.64)
	end
end
	-- Sets the hover border alpha for a row based on isHovered flag.

local function SetRowHover(row, isHovered)
	if row == nil or row.hoverBorder == nil then
		return
	end

	local alpha = 0
	if isHovered then
		alpha = 0.82
	end

	for _, border in ipairs(row.hoverBorder) do
		border:SetColor(1, 0.86, 0.42, alpha)
	end
	-- Sets text, compact name, count, icon and background state on a row widget.
end

local function SetAcquisitionGlowDrawableAlpha(drawable, color, alpha)
	if drawable == nil or color == nil then
		return
	end

	drawable:SetColor(color[1], color[2], color[3], alpha)
	if alpha > 0 then
		if not SafeMethod(drawable, "SetVisible", true) then
			SafeMethod(drawable, "Show", true)
		end
		SafeMethod(drawable, "Raise")
	else
		if not SafeMethod(drawable, "SetVisible", false) then
			SafeMethod(drawable, "Show", false)
		end
	end
end

-- Positions the hot-pink border strips so side pieces skip the corners and avoid overlap brightening.
function runtime:LayoutAcquisitionGlowBorder(row, boxSize)
	if row == nil or row.acquisitionGlowBorder == nil then
		return
	end

	local glowBorderSize = runtime:Scale(CONFIG.ACQUISITION_GLOW_BORDER_SIZE)
	if glowBorderSize < 1 then
		glowBorderSize = 1
	end

	local verticalSpan = boxSize - (glowBorderSize * 2)
	if verticalSpan < 0 then
		verticalSpan = 0
	end

	local border = row.acquisitionGlowBorder
	if border[1] ~= nil then
		border[1]:RemoveAllAnchors()
		border[1]:AddAnchor("TOPLEFT", row, 0, 0)
		border[1]:SetExtent(boxSize, glowBorderSize)
	end
	if border[2] ~= nil then
		border[2]:RemoveAllAnchors()
		border[2]:AddAnchor("BOTTOMLEFT", row, 0, 0)
		border[2]:SetExtent(boxSize, glowBorderSize)
	end
	if border[3] ~= nil then
		border[3]:RemoveAllAnchors()
		border[3]:AddAnchor("TOPLEFT", row, 0, glowBorderSize)
		border[3]:SetExtent(glowBorderSize, verticalSpan)
	end
	if border[4] ~= nil then
		border[4]:RemoveAllAnchors()
		border[4]:AddAnchor("TOPRIGHT", row, 0, glowBorderSize)
		border[4]:SetExtent(glowBorderSize, verticalSpan)
	end
end

-- Builds inset ring drawables that simulate a light-pink gradient inside the hot-pink border.
function runtime:CreateAcquisitionGlowInnerGradient(row)
	if row == nil then
		return
	end

	local boxSize = runtime:Scale(CONFIG.BOX_SIZE)
	local borderSize = runtime:Scale(CONFIG.ACQUISITION_GLOW_BORDER_SIZE)
	if borderSize < 1 then
		borderSize = 1
	end
	local stepSize = runtime:Scale(CONFIG.ACQUISITION_GLOW_INNER_STEP_SIZE)
	if stepSize < 1 then
		stepSize = 1
	end

	local color = CONFIG.ACQUISITION_GLOW_INNER_COLOR
	row.acquisitionGlowInner = {}

	for ringIndex = 1, CONFIG.ACQUISITION_GLOW_INNER_GRADIENT_STEPS do
		local inset = borderSize + ((ringIndex - 1) * stepSize)
		local innerWidth = boxSize - (inset * 2)
		local innerHeight = boxSize - (inset * 2)
		if innerWidth < 0 then
			innerWidth = 0
		end
		if innerHeight < 0 then
			innerHeight = 0
		end
		local verticalSpan = innerHeight - (stepSize * 2)
		if verticalSpan < 0 then
			verticalSpan = 0
		end

		local top = row:CreateColorDrawable(color[1], color[2], color[3], 0, "overlay")
		top:AddAnchor("TOPLEFT", row, inset, inset)
		top:SetExtent(innerWidth, stepSize)

		local bottom = row:CreateColorDrawable(color[1], color[2], color[3], 0, "overlay")
		bottom:AddAnchor("BOTTOMLEFT", row, inset, -inset)
		bottom:SetExtent(innerWidth, stepSize)

		local left = row:CreateColorDrawable(color[1], color[2], color[3], 0, "overlay")
		left:AddAnchor("TOPLEFT", row, inset, inset + stepSize)
		left:SetExtent(stepSize, verticalSpan)

		local right = row:CreateColorDrawable(color[1], color[2], color[3], 0, "overlay")
		right:AddAnchor("TOPRIGHT", row, -inset, inset + stepSize)
		right:SetExtent(stepSize, verticalSpan)

		row.acquisitionGlowInner[ringIndex] = {
			top,
			bottom,
			left,
			right,
		}
	end
end

function runtime:ResizeAcquisitionGlowInner(row, boxSize)
	if row == nil or row.acquisitionGlowInner == nil then
		return
	end

	local borderSize = runtime:Scale(CONFIG.ACQUISITION_GLOW_BORDER_SIZE)
	if borderSize < 1 then
		borderSize = 1
	end
	local stepSize = runtime:Scale(CONFIG.ACQUISITION_GLOW_INNER_STEP_SIZE)
	if stepSize < 1 then
		stepSize = 1
	end

	for ringIndex, ring in ipairs(row.acquisitionGlowInner) do
		local inset = borderSize + ((ringIndex - 1) * stepSize)
		local innerWidth = boxSize - (inset * 2)
		local innerHeight = boxSize - (inset * 2)
		if innerWidth < 0 then
			innerWidth = 0
		end
		if innerHeight < 0 then
			innerHeight = 0
		end
		local verticalSpan = innerHeight - (stepSize * 2)
		if verticalSpan < 0 then
			verticalSpan = 0
		end

		if ring[1] ~= nil then
			ring[1]:RemoveAllAnchors()
			ring[1]:AddAnchor("TOPLEFT", row, inset, inset)
			ring[1]:SetExtent(innerWidth, stepSize)
		end
		if ring[2] ~= nil then
			ring[2]:RemoveAllAnchors()
			ring[2]:AddAnchor("BOTTOMLEFT", row, inset, -inset)
			ring[2]:SetExtent(innerWidth, stepSize)
		end
		if ring[3] ~= nil then
			ring[3]:RemoveAllAnchors()
			ring[3]:AddAnchor("TOPLEFT", row, inset, inset + stepSize)
			ring[3]:SetExtent(stepSize, verticalSpan)
		end
		if ring[4] ~= nil then
			ring[4]:RemoveAllAnchors()
			ring[4]:AddAnchor("TOPRIGHT", row, -inset, inset + stepSize)
			ring[4]:SetExtent(stepSize, verticalSpan)
		end
	end
end

function runtime:SetRowAcquisitionGlowAlpha(row, alpha)
	if row == nil or row.acquisitionGlowBorder == nil then
		return
	end

	local boundedAlpha = tonumber(alpha) or 0
	if boundedAlpha < 0 then
		boundedAlpha = 0
	elseif boundedAlpha > CONFIG.ACQUISITION_GLOW_MAX_ALPHA then
		boundedAlpha = CONFIG.ACQUISITION_GLOW_MAX_ALPHA
	end
	if row.lastAcquisitionGlowAlpha == boundedAlpha then
		return
	end
	row.lastAcquisitionGlowAlpha = boundedAlpha

	if row.acquisitionGlowInner ~= nil then
		local innerAlphaScale = CONFIG.ACQUISITION_GLOW_INNER_MAX_ALPHA / CONFIG.ACQUISITION_GLOW_MAX_ALPHA
		for ringIndex, ring in ipairs(row.acquisitionGlowInner) do
			local fade = (CONFIG.ACQUISITION_GLOW_INNER_GRADIENT_STEPS - ringIndex + 1)
				/ CONFIG.ACQUISITION_GLOW_INNER_GRADIENT_STEPS
			local ringAlpha = boundedAlpha * innerAlphaScale * fade
			for _, drawable in ipairs(ring) do
				SetAcquisitionGlowDrawableAlpha(drawable, CONFIG.ACQUISITION_GLOW_INNER_COLOR, ringAlpha)
			end
		end
	end

	for _, border in ipairs(row.acquisitionGlowBorder) do
		SetAcquisitionGlowDrawableAlpha(border, CONFIG.ACQUISITION_GLOW_COLOR, boundedAlpha)
	end
end

function runtime:HasActiveAcquisitionGlowRows()
	for _, _ in pairs(self.acquisitionGlowRows or {}) do
		return true
	end
	return false
end

function runtime:ClearRowAcquisitionGlow(row)
	if row == nil then
		return
	end

	row.acquisitionGlowRemaining = 0
	row.acquisitionGlowExpireAt = nil
	if self.acquisitionGlowRows ~= nil then
		self.acquisitionGlowRows[row] = nil
	end
	if not self:HasActiveAcquisitionGlowRows() then
		self.acquisitionGlowActive = false
		self.acquisitionGlowBatchStartedAt = nil
	end
	self:SetRowAcquisitionGlowAlpha(row, 0)
end

function runtime:ClearAllAcquisitionGlows()
	for row, _ in pairs(self.acquisitionGlowRows or {}) do
		if row ~= nil then
			row.acquisitionGlowRemaining = 0
			row.acquisitionGlowExpireAt = nil
			self:SetRowAcquisitionGlowAlpha(row, 0)
		end
	end
	self.acquisitionGlowRows = {}
	self.acquisitionGlowActive = false
	self.acquisitionGlowBatchStartedAt = nil
end

function runtime:StartRowAcquisitionGlow(row)
	if row == nil then
		return
	end

	local now = CurrentClock()
	if now > 0 then
		if self.acquisitionGlowBatchStartedAt == nil
			or now - self.acquisitionGlowBatchStartedAt > CONFIG.ACQUISITION_GLOW_BATCH_SECONDS
		then
			self:ClearAllAcquisitionGlows()
			self.acquisitionGlowBatchStartedAt = now
		end
	elseif not self.acquisitionGlowActive then
		self.acquisitionGlowBatchStartedAt = nil
	end

	if self.acquisitionGlowRows == nil then
		self.acquisitionGlowRows = {}
	end
	self.acquisitionGlowRows[row] = true
	row.acquisitionGlowRemaining = CONFIG.ACQUISITION_GLOW_SECONDS
	if now > 0 then
		row.acquisitionGlowExpireAt = now + CONFIG.ACQUISITION_GLOW_SECONDS
	else
		row.acquisitionGlowExpireAt = nil
	end
	self.acquisitionGlowActive = true
	self:SetRowAcquisitionGlowAlpha(row, CONFIG.ACQUISITION_GLOW_MAX_ALPHA)
end

function runtime:SyncRowAcquisitionGlow(row, tracked, current)
	-- Keeps a per-row count baseline so only real inventory increases trigger the temporary icon outline.
	if row == nil then
		return
	end

	if tracked == nil then
		row.lastObservedTrackedKey = nil
		row.lastObservedTrackedCount = nil
		self:ClearRowAcquisitionGlow(row)
		return
	end

	local nextKey = tracked.key or BuildItemKey(tracked.name, tracked.grade, tracked.iconPath) or NormalizeName(tracked.name)
	local nextCount = 0
	if current ~= nil then
		if nextKey == nil then
			nextKey = current.key
		end
		nextCount = math.floor(tonumber(current.count) or 0)
	end
	if nextKey == nil then
		row.lastObservedTrackedKey = nil
		row.lastObservedTrackedCount = nil
		self:ClearRowAcquisitionGlow(row)
		return
	end

	if row.lastObservedTrackedKey ~= nextKey then
		row.lastObservedTrackedKey = nextKey
		row.lastObservedTrackedCount = nextCount
		self:ClearRowAcquisitionGlow(row)
		return
	end

	if row.lastObservedTrackedCount ~= nil and nextCount > row.lastObservedTrackedCount then
		self:RecordTrackedSessionAcquisition(tracked, nextCount - row.lastObservedTrackedCount)
		-- Drop % only counts gains that coincide with loot-activity events (not buys/mail/crafts).
		if self:HasFreshLootActivity() then
			self:RecordTrackedItemDrop(tracked, nextCount - row.lastObservedTrackedCount)
		end
		self:StartRowAcquisitionGlow(row)
	end
	row.lastObservedTrackedCount = nextCount
end

function runtime:UpdateAcquisitionGlows(delta)
	-- Keeps all rows in the current acquisition burst outlined until they expire or a later burst replaces them.
	if not self.acquisitionGlowActive then
		return
	end

	local now = CurrentClock()
	local safeDelta = tonumber(delta) or 0
	if safeDelta < 0 then
		safeDelta = 0
	elseif safeDelta > 1 then
		safeDelta = 1
	end

	local expiredRows = {}
	for row, _ in pairs(self.acquisitionGlowRows or {}) do
		local shouldClear = false
		if row == nil then
			shouldClear = true
		elseif row.acquisitionGlowExpireAt ~= nil then
			if now > 0 and now >= row.acquisitionGlowExpireAt then
				shouldClear = true
			end
		elseif row.acquisitionGlowRemaining ~= nil and row.acquisitionGlowRemaining > 0 then
			row.acquisitionGlowRemaining = row.acquisitionGlowRemaining - safeDelta
			if row.acquisitionGlowRemaining <= 0 then
				shouldClear = true
			end
		else
			shouldClear = true
		end

		if shouldClear then
			expiredRows[#expiredRows + 1] = row
		end
	end

	for _, row in ipairs(expiredRows) do
		self:ClearRowAcquisitionGlow(row)
	end
end

local function SetRowText(row, nameText, countText, state, iconPath)
	if row == nil then
		return
	end

	local nextCountText = countText or ""
	if row.nameLabel ~= nil then
		row.nameLabel:SetText("")
		row.nameLabel:Show(false)
	end
	if row.lastCountText ~= nextCountText then
		row.countLabel:SetText(nextCountText)
		row.lastCountText = nextCountText
	end
	runtime.SetIconDrawable(row.iconDrawable, iconPath)
	if row.lastState ~= state then
		SetRowBackground(row, state)
		row.lastState = state
	end
end

local function ClearTrackerSlotRightDrag()
	trackerSlotRightDrag.sourceIndex = nil
	trackerSlotRightDrag.hoverIndex = nil
end

local function SetTrackerSlotRightDragHover(rowIndex)
	if trackerSlotRightDrag.sourceIndex ~= nil then
		trackerSlotRightDrag.hoverIndex = rowIndex
	end
end

local function ClearTrackerSlotRightDragHover(rowIndex)
	if trackerSlotRightDrag.hoverIndex == rowIndex then
		trackerSlotRightDrag.hoverIndex = nil
	end
end

local function BeginTrackerSlotRightDrag(rowIndex, mouseButton)
	if not IsRightMouseButton(mouseButton) or trackedItems[rowIndex] == nil then
		return false
	end

	trackerSlotRightDrag.sourceIndex = rowIndex
	trackerSlotRightDrag.hoverIndex = rowIndex
	return true
end

local function FindMouseOverTrackedRowIndex()
	for index = 1, runtime.trackedSlotCount do
		local row = rowWidgets[index]
		local ok, isMouseOver = SafeMethod(row, "IsMouseOver")
		if ok and isMouseOver then
			return index
		end
	end
	return nil
end

local function SwapTrackedItemSlots(sourceIndex, targetIndex)
	-- Copies both sides before assignment so dropping onto an empty slot moves the item without aliasing tables.
	if sourceIndex == nil or targetIndex == nil or sourceIndex == targetIndex then
		return false
	end

	local sourceItem = runtime.CopyTrackedItemData(trackedItems[sourceIndex])
	if sourceItem == nil then
		return false
	end

	trackedItems[sourceIndex] = runtime.CopyTrackedItemData(trackedItems[targetIndex])
	trackedItems[targetIndex] = sourceItem
	runtime.SaveTrackedItems()
	runtime.refreshRequested = true
	return true
end

local function EndTrackerSlotRightDrag(rowIndex, mouseButton)
	-- Drop uses the row under the cursor first because drag-stop may fire on the source row after release.
	if mouseButton ~= nil and not IsRightMouseButton(mouseButton) then
		return false
	end
	if trackerSlotRightDrag.sourceIndex == nil then
		return false
	end

	local sourceIndex = trackerSlotRightDrag.sourceIndex
	local targetIndex = FindMouseOverTrackedRowIndex() or trackerSlotRightDrag.hoverIndex or rowIndex
	ClearTrackerSlotRightDrag()

	if SwapTrackedItemSlots(sourceIndex, targetIndex) then
		runtime.suppressRowRightClickUntil = CurrentClock() + 0.6
		return true
	end
	return false
end

local function ShouldSuppressRowRightClick()
	if runtime.suppressRowRightClickUntil <= 0 then
		return false
	end
	if CurrentClock() <= runtime.suppressRowRightClickUntil then
		runtime.suppressRowRightClickUntil = 0
		return true
	end
	runtime.suppressRowRightClickUntil = 0
	return false
end

-- UpdateRows on runtime
function runtime.ClearPickerSearchState()
	runtime.pickerSearchText = ""
	runtime.pickerSearchPollElapsed = 0
	runtime.pickerSearchTextEventSuppressed = true
	if runtime.pickerSearchBox ~= nil then
		SafeMethod(runtime.pickerSearchBox, "ClearFocus")
		SafeMethod(runtime.pickerSearchBox, "SetFocus", false)
		SafeMethod(runtime.pickerSearchBox, "SetText", "")
		SafeMethod(runtime.pickerSearchBox, "SetInputText", "")
		SafeMethod(runtime.pickerSearchBox, "SetEditText", "")
		SafeMethod(runtime.pickerSearchBox, "SetDisplayText", "")
		SafeMethod(runtime.pickerSearchBox, "SetString", "")
		SafeMethod(runtime.pickerSearchBox, "ClearText")
		SafeMethod(runtime.pickerSearchBox, "ClearInputText")
		SafeMethod(runtime.pickerSearchBox, "ClearEditText")
	end
	runtime.pickerSearchTextEventSuppressed = false
end
	-- Hides the reusable picker search box without destroying or detaching it.

function runtime.HidePickerSearchBox()
	if runtime.pickerSearchBox == nil then
		return
	end
	SafeMethod(runtime.pickerSearchBox, "Show", false)
	SafeMethod(runtime.pickerSearchBox, "SetVisible", false)
	-- Checks if the picker window is currently visible using IsVisible or fallback flag.
end

function runtime.IsPickerWindowVisible()
	if runtime.pickerWindow == nil then
		return false
	end

	local fn = runtime.pickerWindow.IsVisible
	if type(fn) == "function" then
		local ok, visible = pcall(fn, runtime.pickerWindow)
		if ok then
			return visible == true
		end
	end

	-- Clears all tracked items, saves if any were present, and refreshes rows.
	return runtime.isPickerOpen
end

function runtime.IsTrackerWindowVisible()
	if runtime.window == nil then
		return false
	end

	local fn = runtime.window.IsVisible
	if type(fn) == "function" then
		local ok, visible = pcall(fn, runtime.window)
		if ok then
			return visible == true
		end
	end
	return true
end

function runtime.ClearTrackedItems()
	local hadTrackedItems = false
	for index = 1, runtime.trackedSlotCount do
		if trackedItems[index] ~= nil then
			hadTrackedItems = true
		end
		trackedItems[index] = nil
	end

	if hadTrackedItems then
		runtime.SaveTrackedItems()
	end
	runtime:ClearTrackedDropRates()
	runtime:ClearTrackedSessionAcquiredCounts()
	runtime.refreshRequested = true
	if runtime.UpdateRows ~= nil then
	-- Opens the picker for a specific tracked slot, resets scroll and search, anchors picker, shows it and sets focus.
		runtime.UpdateRows()
	end
end

function runtime.OpenPicker(rowIndex)
	runtime.pickerSlotIndex = rowIndex
	runtime.pickerScrollIndex = 1
	if runtime.RecreatePickerSearchBox ~= nil then
		runtime.RecreatePickerSearchBox()
	else
		runtime.ClearPickerSearchState()
	end
	if runtime.pickerWindow ~= nil then
		if runtime.AnchorPickerWindow ~= nil then
			runtime.AnchorPickerWindow()
		else
			runtime.pickerWindow:RemoveAllAnchors()
			runtime.pickerWindow:AddAnchor("TOPLEFT", runtime.window, 0, runtime.GetTrackerWindowHeight() + 8)
		end
		runtime.pickerWindow:Show(true)
	end
	if runtime.pickerSearchBox ~= nil then
		SafeMethod(runtime.pickerSearchBox, "SetFocus")
		SafeMethod(runtime.pickerSearchBox, "SetFocus", true)
	end
	runtime.isPickerOpen = true
	-- Closes the picker, clears search state, hides search box and picker window.
	if runtime.UpdatePicker ~= nil then
		runtime.UpdatePicker()
	end
end

function runtime.ClosePicker()
	runtime.isPickerOpen = false
	runtime.ClearPickerSearchState()
	-- Handles click on a tracked row: right removes, left opens picker for the slot.
	runtime.HidePickerSearchBox()
	if runtime.pickerWindow ~= nil then
		runtime.pickerWindow:Show(false)
	end
end

function runtime.HandleRowClick(rowIndex, mouseButton)
	if IsRightMouseButton(mouseButton) then
		ClearTrackerSlotRightDrag()
		if ShouldSuppressRowRightClick() then
			return
		end
		runtime.RemoveTrackedItem(rowIndex)
		runtime.UpdateRows()
	else
		runtime.OpenPicker(rowIndex)
	end
end

runtime.UpdateRows = function()
	-- Updates all tracked rows with current inventory counts or missing state from the snapshot.
	local itemsByKey, _, itemsByName = runtime.GetInventorySnapshot(false)
	local currentDropRateKills = runtime:ObserveDropRateKillTotal()

	for index = 1, runtime.trackedSlotCount do
		local row = rowWidgets[index]
		local tracked = trackedItems[index]
		if tracked == nil then
			runtime:SyncRowAcquisitionGlow(row, nil, nil)
			SetRowText(row, "", "", "empty", nil)
			runtime.SetRowDropRateText(row, nil)
			runtime.SetRowSessionAcquiredText(row, nil)
		else
			local current = runtime.ResolveTrackedInventoryEntry(itemsByKey, tracked, itemsByName)
			if current ~= nil then
				runtime:SyncRowAcquisitionGlow(row, tracked, current)
				SetRowText(row, current.name, "x" .. tostring(current.count), "tracked", current.iconPath or tracked.iconPath)
			else
				runtime:SyncRowAcquisitionGlow(row, tracked, nil)
				SetRowText(row, tracked.name, "x0", "missing", tracked.iconPath)
			end
			runtime.SetRowDropRateText(row, runtime:GetTrackedDropRateText(tracked, currentDropRateKills))
			runtime.SetRowSessionAcquiredText(row, runtime:GetTrackedSessionAcquiredText(tracked))
		end
	end
	runtime.lootActivityFresh = false
	runtime.dropRateLastRefreshKillTotal = currentDropRateKills
end

runtime:LoadSlotCount()
runtime:LoadWindowScale()
runtime:LoadMenuMode()
runtime.LoadTrackedItems()
runtime.trackerLayout = runtime.LoadTrackerLayout()

runtime.window = CreateEmptyWindow("lootTrackerWindow", "UIParent")
runtime.window = runtime.window
runtime.window:SetExtent(runtime.GetTrackerWindowWidth(), runtime.GetTrackerWindowHeight())
runtime.window:EnableDrag(true)
runtime.window:Clickable(true)
runtime.window:Show(true)

local savedX, savedY = runtime.LoadWindowPosition()
runtime.window:AddAnchor("TOPLEFT", "UIParent", savedX, savedY)
runtime.lastKnownTrackerX = savedX
runtime.lastKnownTrackerY = savedY

local restoreSavedX, restoreSavedY, hasSavedRestoreButtonPosition = runtime.LoadRestoreButtonPosition(savedX, savedY)
runtime.restoreButtonPositionSaved = hasSavedRestoreButtonPosition
runtime.lastKnownRestoreX = restoreSavedX
runtime.lastKnownRestoreY = restoreSavedY
local restoreButton = UIParent:CreateWidget("button", "lootTrackerRestoreButton", "UIParent", "")
runtime.restoreButton = restoreButton
restoreButton:SetStyle("text_default")
restoreButton:SetText("Loot Tracker")
restoreButton:SetExtent(CONFIG.RESTORE_BUTTON_WIDTH, CONFIG.RESTORE_BUTTON_HEIGHT)
restoreButton:EnableDrag(true)
SafeMethod(restoreButton, "Clickable", true)
restoreButton:AddAnchor("TOPLEFT", "UIParent", restoreSavedX, restoreSavedY)
restoreButton:Show(false)

	-- Anchors a widget at the given saved screen position.
function runtime.AnchorWidgetAtSavedPosition(widget, x, y)
	if widget == nil then
		return
	end

	widget:RemoveAllAnchors()
	widget:AddAnchor("TOPLEFT", "UIParent", x, y)
end

function runtime.CenterLootTrackerWindow()
	runtime.ClosePicker()
	if runtime.ChangeSlotCount ~= nil then
		runtime:ChangeSlotCount(5 - runtime.trackedSlotCount)
	end
	runtime.trackerScale = 1
	runtime:SaveWindowScale()
	restoreButton:Show(false)
	if runtime.setWindow ~= nil then
		runtime.setWindow:Show(false)
	end
	runtime.window:Show(true)
	if runtime.SetTrackerHeaderControlsVisible ~= nil then
		runtime.SetTrackerHeaderControlsVisible(true)
	end
	runtime.MarkInventoryDirty()
	runtime.ApplyTrackerLayout()
	runtime.window:RemoveAllAnchors()
	runtime.window:AddAnchor("CENTER", "UIParent", 0, 0)
	runtime.SaveWindowPosition(runtime.window)
	if runtime.PositionResizeHandles ~= nil then
		runtime:PositionResizeHandles()
	end
	restoreButton:RemoveAllAnchors()
	restoreButton:AddAnchor("CENTER", "UIParent", 0, 0)
	runtime.SaveRestoreButtonPosition(restoreButton)
	runtime.UpdateRows()
end
	-- Hides the loot tracker window, saves position, closes picker, shows restore button.

function runtime.HideLootTrackerWindow()
	if runtime.SetTrackerHeaderControlsVisible ~= nil then
		runtime.SetTrackerHeaderControlsVisible(true)
	end
	if runtime.SetResizeHandlesVisible ~= nil then
		runtime:SetResizeHandlesVisible(false)
	end
	runtime.SaveWindowPosition(runtime.window)
	runtime.ClosePicker()
	if runtime.setWindow ~= nil then
		runtime.setWindow:Show(false)
	end
	if runtime.menuMode then
		runtime.window:Show(false)
		restoreButton:Show(false)
		return
	end
	if not runtime.restoreButtonPositionSaved then
		local windowX, windowY = GetWidgetSavedPosition(runtime.window)
		runtime.AnchorWidgetAtSavedPosition(restoreButton, windowX, windowY)
	end
	runtime.window:Show(false)
	restoreButton:Show(true)
	-- Shows the loot tracker window at saved position, hides restore button, marks inventory dirty, applies layout and updates rows.
end

function runtime.ShowLootTrackerWindow(overrideX, overrideY)
	runtime.trackerHeaderControlsVisible = true
	local windowX, windowY
	if overrideX ~= nil and overrideY ~= nil then
		windowX, windowY = overrideX, overrideY
	elseif runtime.lastKnownTrackerX ~= nil and runtime.lastKnownTrackerY ~= nil then
		windowX, windowY = runtime.lastKnownTrackerX, runtime.lastKnownTrackerY
	else
		windowX, windowY = runtime.LoadWindowPosition()
	end
	windowX = math.floor((tonumber(windowX) or 420) + 0.5)
	windowY = math.floor((tonumber(windowY) or 320) + 0.5)
	runtime.AnchorWidgetAtSavedPosition(runtime.window, windowX, windowY)
	runtime.lastKnownTrackerX = windowX
	runtime.lastKnownTrackerY = windowY
	restoreButton:Show(false)
	runtime.window:Show(true)
	if runtime.SetTrackerHeaderControlsVisible ~= nil then
		runtime.SetTrackerHeaderControlsVisible(true)
	end
	if runtime.SetResizeHandlesVisible ~= nil then
		runtime:SetResizeHandlesVisible(true)
	end
	SafeMethod(runtime.window, "CorrectOffsetByScreen")
	runtime.MarkInventoryDirty()
	runtime.ApplyTrackerLayout()
	-- Shows the loot tracker window when restore button is clicked.
	runtime.UpdateRows()
end

if runtime.menuMode or _G.__LOOT_TRACKER_ESC_MENU_BUTTON_ADDED == true then
	runtime:RegisterEscMenuButton()
end

function restoreButton:OnClick()
	-- Starts moving the restore button on drag start.
	runtime.ShowLootTrackerWindow()
end
restoreButton:SetHandler("OnClick", restoreButton.OnClick)

	-- Stops moving the restore button and saves its position on drag stop.
function restoreButton:OnDragStart()
	self:StartMoving()
end
restoreButton:SetHandler("OnDragStart", restoreButton.OnDragStart)

function restoreButton:OnDragStop()
	self:StopMovingOrSizing()
	runtime.SaveRestoreButtonPosition(self)
end
restoreButton:SetHandler("OnDragStop", restoreButton.OnDragStop)

local background = runtime.window:CreateColorDrawable(0, 0, 0, 0.58, "background")
background:AddAnchor("TOPLEFT", runtime.window, 0, 0)
background:AddAnchor("BOTTOMRIGHT", runtime.window, 0, 0)

local headerLabel = runtime.window:CreateChildWidget("label", "lootTrackerHeaderLabel", 0, true)
headerLabel:SetText("Loot Tracker")
headerLabel:SetExtent(CONFIG.HEADER_TITLE_WIDTH, CONFIG.HEADER_HEIGHT)
headerLabel.style:SetAlign(ALIGN_LEFT)
headerLabel.style:SetFontSize(11)
headerLabel.style:SetColor(0.95, 0.92, 0.82, 1)
headerLabel.style:SetOutline(true)
headerLabel:AddAnchor("TOPLEFT", runtime.window, CONFIG.TRACKER_PADDING, CONFIG.TRACKER_TOP_PADDING + 2)
SafeMethod(headerLabel, "EnableDrag", true)

function headerLabel:OnDragStart()
	runtime.window:StartMoving()
end
headerLabel:SetHandler("OnDragStart", headerLabel.OnDragStart)

function headerLabel:OnDragStop()
	runtime.window:StopMovingOrSizing()
	runtime.SaveWindowPosition(runtime.window)
	if runtime.PositionResizeHandles ~= nil then
		runtime:PositionResizeHandles()
	end
end
headerLabel:SetHandler("OnDragStop", headerLabel.OnDragStop)

runtime.lootRateMarker = runtime.window:CreateChildWidget("label", "lootTrackerLootRateMarker", 0, true)
runtime.lootRateMarker:SetText(runtime:FormatLootRatePercent())
runtime.lootRateMarker:SetExtent(CONFIG.LOOT_RATE_MARKER_WIDTH, CONFIG.LOOT_RATE_MARKER_HEIGHT)
runtime.lootRateMarker.style:SetAlign(ALIGN_CENTER)
runtime.lootRateMarker.style:SetFontSize(12)
runtime.lootRateMarker.style:SetOutline(true)
runtime:ApplyLootRateTextColor(runtime.lootRateMarker)
runtime.lootRateMarker:Show(false)
SafeMethod(runtime.lootRateMarker, "EnablePick", false)

-- ToggleTrackerLayout on runtime

local rotateButton = runtime.window:CreateChildWidget("button", "lootTrackerRotateButton", 0, true)
rotateButton:SetStyle("text_default")
rotateButton:SetText("R")
rotateButton:SetExtent(CONFIG.ROTATE_BUTTON_WIDTH, 18)

function rotateButton:OnClick()
	runtime.ToggleTrackerLayout()
end
rotateButton:SetHandler("OnClick", rotateButton.OnClick)

local resetButton = runtime.window:CreateChildWidget("button", "lootTrackerResetButton", 0, true)
resetButton:SetStyle("text_default")
resetButton:SetText("C")
resetButton:SetExtent(CONFIG.RESET_BUTTON_WIDTH, 18)

function resetButton:OnClick()
	runtime.ClearTrackedItems()
end
resetButton:SetHandler("OnClick", resetButton.OnClick)

runtime.menuModeButton = runtime.window:CreateChildWidget("button", "lootTrackerMenuModeButton", 0, true)
runtime.menuModeButton:SetStyle("text_default")
runtime.menuModeButton:SetExtent(CONFIG.MENU_BUTTON_WIDTH, 18)
runtime:UpdateMenuModeButton()

function runtime.menuModeButton:OnClick()
	runtime:SetMenuMode(not runtime.menuMode, true)
end
runtime.menuModeButton:SetHandler("OnClick", runtime.menuModeButton.OnClick)

runtime.setManagerButton = runtime.window:CreateChildWidget("button", "lootTrackerSetManagerButton", 0, true)
runtime.setManagerButton:SetStyle("text_default")
runtime.setManagerButton:SetText("S")
runtime.setManagerButton:SetExtent(CONFIG.SET_BUTTON_WIDTH, 18)

function runtime.setManagerButton:OnClick()
	if runtime.ToggleTrackerSetWindow ~= nil then
		runtime:ToggleTrackerSetWindow()
	end
end
runtime.setManagerButton:SetHandler("OnClick", runtime.setManagerButton.OnClick)

runtime.killCounterButton = runtime.window:CreateChildWidget("button", "lootTrackerKillCounterButton", 0, true)
runtime.killCounterButton:SetStyle("text_default")
runtime.killCounterButton:SetText("K")
runtime.killCounterButton:SetExtent(CONFIG.RESET_BUTTON_WIDTH, 18)

function runtime:OpenKillCounterWindow()
	local counterRuntime = _G.__LOOT_KILL_COUNTER_RUNTIME
	if counterRuntime == nil then
		return
	end
	if type(counterRuntime.ToggleCounterWindow) == "function" then
		counterRuntime:ToggleCounterWindow()
	elseif type(counterRuntime.ShowCounterWindow) == "function" then
		counterRuntime:ShowCounterWindow()
	end
end

function runtime.killCounterButton:OnClick()
	runtime:OpenKillCounterWindow()
end
runtime.killCounterButton:SetHandler("OnClick", runtime.killCounterButton.OnClick)

runtime.addSlotButton = runtime.window:CreateChildWidget("button", "lootTrackerAddSlotButton", 0, true)
runtime.addSlotButton:SetStyle("text_default")
runtime.addSlotButton:SetText("+")
runtime.addSlotButton:SetExtent(CONFIG.RESET_BUTTON_WIDTH, 18)

function runtime.addSlotButton:OnClick()
	runtime:ChangeSlotCount(1)
end
runtime.addSlotButton:SetHandler("OnClick", runtime.addSlotButton.OnClick)

runtime.removeSlotButton = runtime.window:CreateChildWidget("button", "lootTrackerRemoveSlotButton", 0, true)
runtime.removeSlotButton:SetStyle("text_default")
runtime.removeSlotButton:SetText("-")
runtime.removeSlotButton:SetExtent(CONFIG.RESET_BUTTON_WIDTH, 18)

function runtime.removeSlotButton:OnClick()
	runtime:ChangeSlotCount(-1)
end
runtime.removeSlotButton:SetHandler("OnClick", runtime.removeSlotButton.OnClick)

local hideWindowButton = runtime.window:CreateChildWidget("button", "lootTrackerHideWindowButton", 0, true)
hideWindowButton:SetStyle("text_default")
hideWindowButton:SetText("X")
hideWindowButton:SetExtent(CONFIG.HIDE_WINDOW_BUTTON_WIDTH, 18)

function hideWindowButton:OnClick()
	runtime.HideLootTrackerWindow()
end
hideWindowButton:SetHandler("OnClick", hideWindowButton.OnClick)

runtime.SetTrackerHeaderControlsVisible = function(visible)
	if runtime.trackerHeaderControlsVisible == visible then
		SafeMethod(background, "SetVisible", visible)
		SafeMethod(background, "Show", visible)
		headerLabel:Show(visible and runtime.trackerLayout ~= CONFIG.LAYOUT_VERTICAL)
		rotateButton:Show(visible)
		resetButton:Show(visible)
		runtime.menuModeButton:Show(visible)
		runtime.setManagerButton:Show(visible)
		runtime.killCounterButton:Show(visible)
		runtime.addSlotButton:Show(visible)
		runtime.removeSlotButton:Show(visible)
		hideWindowButton:Show(visible)
		if visible then
			runtime:UpdateLootRateMarkerText()
		end
		runtime.lootRateMarker:Show(visible)
		if runtime.SetResizeHandlesVisible ~= nil then
			runtime:SetResizeHandlesVisible(visible)
		end
		return
	end

	local oldX, oldY = GetWidgetSavedPosition(runtime.window)
	local oldRowsLeft = runtime.GetTrackedRowsLeft()
	local oldRowsTop = runtime.GetTrackedRowsTop()

	runtime.trackerHeaderControlsVisible = visible
	SafeMethod(background, "SetVisible", visible)
	SafeMethod(background, "Show", visible)
	headerLabel:Show(visible and runtime.trackerLayout ~= CONFIG.LAYOUT_VERTICAL)
	rotateButton:Show(visible)
	resetButton:Show(visible)
	runtime.menuModeButton:Show(visible)
	runtime.setManagerButton:Show(visible)
	runtime.killCounterButton:Show(visible)
	runtime.addSlotButton:Show(visible)
	runtime.removeSlotButton:Show(visible)
	hideWindowButton:Show(visible)
	if visible then
		runtime:UpdateLootRateMarkerText()
	end
	runtime.lootRateMarker:Show(visible)
	if runtime.ApplyTrackerLayout ~= nil then
		runtime.ApplyTrackerLayout()
	end
	if runtime.SetResizeHandlesVisible ~= nil then
		runtime:SetResizeHandlesVisible(visible)
	end

	if oldX ~= nil and oldY ~= nil then
		runtime.AnchorWidgetAtSavedPosition(
			runtime.window,
			oldX + oldRowsLeft - runtime.GetTrackedRowsLeft(),
			oldY + oldRowsTop - runtime.GetTrackedRowsTop()
		)
	end
	if runtime.PositionResizeHandles ~= nil then
		runtime:PositionResizeHandles()
	end
end

function runtime.ShowTrackerHeaderControls()
	runtime.SetTrackerHeaderControlsVisible(true)
end

function runtime.HideTrackerHeaderControls()
	if runtime.IsResizing ~= nil and runtime:IsResizing() then
		return
	end
	runtime.SetTrackerHeaderControlsVisible(false)
end

function runtime.window:OnEnter()
	runtime.ShowTrackerHeaderControls()
end
runtime.window:SetHandler("OnEnter", runtime.window.OnEnter)

function runtime.window:OnLeave()
	runtime.HideTrackerHeaderControls()
end
runtime.window:SetHandler("OnLeave", runtime.window.OnLeave)

function headerLabel:OnEnter()
	runtime.ShowTrackerHeaderControls()
end
headerLabel:SetHandler("OnEnter", headerLabel.OnEnter)

rotateButton:SetHandler("OnEnter", runtime.ShowTrackerHeaderControls)
resetButton:SetHandler("OnEnter", runtime.ShowTrackerHeaderControls)
runtime.menuModeButton:SetHandler("OnEnter", runtime.ShowTrackerHeaderControls)
runtime.setManagerButton:SetHandler("OnEnter", runtime.ShowTrackerHeaderControls)
runtime.killCounterButton:SetHandler("OnEnter", runtime.ShowTrackerHeaderControls)
runtime.addSlotButton:SetHandler("OnEnter", runtime.ShowTrackerHeaderControls)
runtime.removeSlotButton:SetHandler("OnEnter", runtime.ShowTrackerHeaderControls)
hideWindowButton:SetHandler("OnEnter", runtime.ShowTrackerHeaderControls)

local function AnchorHeaderControls()
	-- Anchors the header label and control buttons based on current tracker layout.
	headerLabel:RemoveAllAnchors()
	headerLabel:SetExtent(runtime:Scale(CONFIG.HEADER_TITLE_WIDTH), runtime:Scale(CONFIG.HEADER_HEIGHT))
	headerLabel.style:SetAlign(ALIGN_LEFT)
	headerLabel.style:SetFontSize(runtime:Scale(11))
	runtime.lootRateMarker:SetExtent(runtime:Scale(CONFIG.LOOT_RATE_MARKER_WIDTH), runtime:Scale(CONFIG.LOOT_RATE_MARKER_HEIGHT))
	runtime.lootRateMarker.style:SetFontSize(runtime:Scale(12))
	runtime:ApplyLootRateTextColor(runtime.lootRateMarker)
	rotateButton:SetExtent(runtime:Scale(CONFIG.ROTATE_BUTTON_WIDTH), runtime:Scale(CONFIG.HEADER_BUTTON_HEIGHT))
	resetButton:SetExtent(runtime:Scale(CONFIG.RESET_BUTTON_WIDTH), runtime:Scale(CONFIG.HEADER_BUTTON_HEIGHT))
	runtime.menuModeButton:SetExtent(runtime:Scale(CONFIG.MENU_BUTTON_WIDTH), runtime:Scale(CONFIG.HEADER_BUTTON_HEIGHT))
	runtime.setManagerButton:SetExtent(runtime:Scale(CONFIG.SET_BUTTON_WIDTH), runtime:Scale(CONFIG.HEADER_BUTTON_HEIGHT))
	runtime.killCounterButton:SetExtent(runtime:Scale(CONFIG.RESET_BUTTON_WIDTH), runtime:Scale(CONFIG.HEADER_BUTTON_HEIGHT))
	runtime.addSlotButton:SetExtent(runtime:Scale(CONFIG.RESET_BUTTON_WIDTH), runtime:Scale(CONFIG.HEADER_BUTTON_HEIGHT))
	runtime.removeSlotButton:SetExtent(runtime:Scale(CONFIG.RESET_BUTTON_WIDTH), runtime:Scale(CONFIG.HEADER_BUTTON_HEIGHT))
	hideWindowButton:SetExtent(runtime:Scale(CONFIG.HIDE_WINDOW_BUTTON_WIDTH), runtime:Scale(CONFIG.HEADER_BUTTON_HEIGHT))

	if runtime.trackerLayout == CONFIG.LAYOUT_VERTICAL then
		local railButtonWidth = math.max(
			CONFIG.HIDE_WINDOW_BUTTON_WIDTH,
			CONFIG.MENU_BUTTON_WIDTH,
			CONFIG.SET_BUTTON_WIDTH,
			CONFIG.RESET_BUTTON_WIDTH,
			CONFIG.LOOT_RATE_MARKER_WIDTH
		)
		local railLeft = runtime:Scale(CONFIG.BOX_SIZE + CONFIG.HEADER_BUTTON_GAP)
		local narrowLeft = railLeft + math.floor((runtime:Scale(railButtonWidth) - runtime:Scale(CONFIG.RESET_BUTTON_WIDTH)) / 2)
		local menuLeft = railLeft + math.floor((runtime:Scale(railButtonWidth) - runtime:Scale(CONFIG.MENU_BUTTON_WIDTH)) / 2)
		local hideLeft = railLeft + math.floor((runtime:Scale(railButtonWidth) - runtime:Scale(CONFIG.HIDE_WINDOW_BUTTON_WIDTH)) / 2)
		local markerLeft = railLeft + math.floor((runtime:Scale(railButtonWidth) - runtime:Scale(CONFIG.LOOT_RATE_MARKER_WIDTH)) / 2)
		headerLabel:Show(false)

		runtime.lootRateMarker:RemoveAllAnchors()
		runtime.lootRateMarker:AddAnchor("TOPLEFT", runtime.window, markerLeft, 0)

		rotateButton:RemoveAllAnchors()
		rotateButton:AddAnchor(
			"TOPLEFT",
			runtime.window,
			narrowLeft,
			runtime:Scale(CONFIG.HEADER_BUTTON_HEIGHT + CONFIG.HEADER_BUTTON_GAP)
		)

		resetButton:RemoveAllAnchors()
		resetButton:AddAnchor(
			"TOPLEFT",
			runtime.window,
			narrowLeft,
			runtime:Scale((CONFIG.HEADER_BUTTON_HEIGHT * 2) + (CONFIG.HEADER_BUTTON_GAP * 2))
		)

		runtime.setManagerButton:RemoveAllAnchors()
		runtime.setManagerButton:AddAnchor(
			"TOPLEFT",
			runtime.window,
			narrowLeft,
			runtime:Scale((CONFIG.HEADER_BUTTON_HEIGHT * 3) + (CONFIG.HEADER_BUTTON_GAP * 3))
		)

		runtime.menuModeButton:RemoveAllAnchors()
		runtime.menuModeButton:AddAnchor(
			"TOPLEFT",
			runtime.window,
			menuLeft,
			runtime:Scale((CONFIG.HEADER_BUTTON_HEIGHT * 4) + (CONFIG.HEADER_BUTTON_GAP * 4))
		)

		runtime.killCounterButton:RemoveAllAnchors()
		runtime.killCounterButton:AddAnchor(
			"TOPLEFT",
			runtime.window,
			narrowLeft,
			runtime:Scale((CONFIG.HEADER_BUTTON_HEIGHT * 5) + (CONFIG.HEADER_BUTTON_GAP * 5))
		)

		runtime.addSlotButton:RemoveAllAnchors()
		runtime.addSlotButton:AddAnchor(
			"TOPLEFT",
			runtime.window,
			narrowLeft,
			runtime:Scale((CONFIG.HEADER_BUTTON_HEIGHT * 6) + (CONFIG.HEADER_BUTTON_GAP * 6))
		)

		runtime.removeSlotButton:RemoveAllAnchors()
		runtime.removeSlotButton:AddAnchor(
			"TOPLEFT",
			runtime.window,
			narrowLeft,
			runtime:Scale((CONFIG.HEADER_BUTTON_HEIGHT * 7) + (CONFIG.HEADER_BUTTON_GAP * 7))
		)

		hideWindowButton:RemoveAllAnchors()
		hideWindowButton:AddAnchor(
			"TOPLEFT",
			runtime.window,
			hideLeft,
			runtime:Scale((CONFIG.HEADER_BUTTON_HEIGHT * 8) + (CONFIG.HEADER_BUTTON_GAP * 8))
		)
		return
	end

	headerLabel:Show(runtime.trackerHeaderControlsVisible)
	headerLabel:AddAnchor("TOPLEFT", runtime.window, runtime:Scale(CONFIG.TRACKER_PADDING), runtime:Scale(CONFIG.TRACKER_TOP_PADDING + 2))

	runtime.lootRateMarker:RemoveAllAnchors()
	runtime.lootRateMarker:AddAnchor(
		"TOPLEFT",
		runtime.window,
		runtime:Scale(CONFIG.TRACKER_PADDING + CONFIG.HEADER_TITLE_WIDTH + CONFIG.HEADER_BUTTON_GAP),
		runtime:Scale(CONFIG.TRACKER_TOP_PADDING + 1)
	)

	hideWindowButton:RemoveAllAnchors()
	hideWindowButton:AddAnchor("TOPRIGHT", runtime.window, -runtime:Scale(CONFIG.TRACKER_PADDING), runtime:Scale(CONFIG.TRACKER_TOP_PADDING + 1))

	runtime.removeSlotButton:RemoveAllAnchors()
	runtime.removeSlotButton:AddAnchor(
		"TOPRIGHT",
		runtime.window,
		-runtime:Scale(CONFIG.TRACKER_PADDING + CONFIG.HIDE_WINDOW_BUTTON_WIDTH + CONFIG.HEADER_BUTTON_GAP),
		runtime:Scale(CONFIG.TRACKER_TOP_PADDING + 1)
	)

	runtime.addSlotButton:RemoveAllAnchors()
	runtime.addSlotButton:AddAnchor(
		"TOPRIGHT",
		runtime.window,
		-runtime:Scale(CONFIG.TRACKER_PADDING + CONFIG.HIDE_WINDOW_BUTTON_WIDTH + CONFIG.HEADER_BUTTON_GAP + CONFIG.RESET_BUTTON_WIDTH + CONFIG.HEADER_BUTTON_GAP),
		runtime:Scale(CONFIG.TRACKER_TOP_PADDING + 1)
	)

	runtime.killCounterButton:RemoveAllAnchors()
	runtime.killCounterButton:AddAnchor(
		"TOPRIGHT",
		runtime.window,
		-runtime:Scale(
			CONFIG.TRACKER_PADDING
				+ CONFIG.HIDE_WINDOW_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
				+ CONFIG.RESET_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
				+ CONFIG.RESET_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
		),
		runtime:Scale(CONFIG.TRACKER_TOP_PADDING + 1)
	)

	runtime.menuModeButton:RemoveAllAnchors()
	runtime.menuModeButton:AddAnchor(
		"TOPRIGHT",
		runtime.window,
		-runtime:Scale(
			CONFIG.TRACKER_PADDING
				+ CONFIG.HIDE_WINDOW_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
				+ CONFIG.RESET_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
				+ CONFIG.RESET_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
				+ CONFIG.RESET_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
		),
		runtime:Scale(CONFIG.TRACKER_TOP_PADDING + 1)
	)

	runtime.setManagerButton:RemoveAllAnchors()
	runtime.setManagerButton:AddAnchor(
		"TOPRIGHT",
		runtime.window,
		-runtime:Scale(
			CONFIG.TRACKER_PADDING
				+ CONFIG.HIDE_WINDOW_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
				+ CONFIG.RESET_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
				+ CONFIG.RESET_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
				+ CONFIG.RESET_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
				+ CONFIG.MENU_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
		),
		runtime:Scale(CONFIG.TRACKER_TOP_PADDING + 1)
	)

	resetButton:RemoveAllAnchors()
	resetButton:AddAnchor(
		"TOPRIGHT",
		runtime.window,
		-runtime:Scale(
			CONFIG.TRACKER_PADDING
				+ CONFIG.HIDE_WINDOW_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
				+ CONFIG.RESET_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
				+ CONFIG.RESET_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
				+ CONFIG.RESET_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
				+ CONFIG.MENU_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
				+ CONFIG.SET_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
		),
		runtime:Scale(CONFIG.TRACKER_TOP_PADDING + 1)
	)

	rotateButton:RemoveAllAnchors()
	rotateButton:AddAnchor(
		"TOPRIGHT",
		runtime.window,
		-runtime:Scale(
			CONFIG.TRACKER_PADDING
				+ CONFIG.HIDE_WINDOW_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
				+ CONFIG.RESET_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
				+ CONFIG.RESET_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
				+ CONFIG.RESET_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
				+ CONFIG.RESET_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
				+ CONFIG.MENU_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
				+ CONFIG.SET_BUTTON_WIDTH
				+ CONFIG.HEADER_BUTTON_GAP
		),
		runtime:Scale(CONFIG.TRACKER_TOP_PADDING + 1)
	)

end

	-- Anchors the picker window either at saved position or below the tracker window.
runtime.AnchorPickerWindow = function()
	if runtime.pickerWindow == nil then
		return
	end

	runtime.pickerWindow:RemoveAllAnchors()
	if runtime.pickerWindowPositionSaved then
		local pickerX, pickerY = runtime.LoadPickerWindowPosition(0, 0)
		runtime.pickerWindow:AddAnchor("TOPLEFT", "UIParent", pickerX, pickerY)
		return
	end

	runtime.pickerWindow:AddAnchor("TOPLEFT", runtime.window, 0, runtime.GetTrackerWindowHeight() + 8)
end
	-- Anchors all tracked row widgets according to current layout (horizontal row or vertical column).

local function AnchorTrackedRows()
	for index, row in pairs(rowWidgets) do
		if row ~= nil and index > runtime.trackedSlotCount then
			row:Show(false)
		elseif row ~= nil then
			row:Show(true)
			local boxSize = runtime:Scale(CONFIG.BOX_SIZE)
			local boxGap = runtime:Scale(CONFIG.BOX_GAP)
			local borderSize = runtime:Scale(1)
			local iconInset = runtime:Scale(1)
			local iconSize = boxSize - (iconInset * 2)
			if iconSize < 1 then
				iconSize = 1
			end
			local offsetX = runtime.GetTrackedRowsLeft() + ((index - 1) * (boxSize + boxGap))
			local offsetY = runtime.GetTrackedRowsTop()

			if runtime.trackerLayout == CONFIG.LAYOUT_VERTICAL then
				offsetX = runtime.GetTrackedRowsLeft()
				offsetY = runtime.GetTrackedRowsTop() + ((index - 1) * (boxSize + boxGap))
			end

			row:RemoveAllAnchors()
			row:AddAnchor("TOPLEFT", runtime.window, offsetX, offsetY)
			row:SetExtent(boxSize, boxSize)
			if row.bg ~= nil then
				row.bg:SetExtent(boxSize, boxSize)
			end
			if row.iconDrawable ~= nil then
				row.iconDrawable:RemoveAllAnchors()
				row.iconDrawable:SetExtent(iconSize, iconSize)
				row.iconDrawable:AddAnchor("TOPLEFT", row, iconInset, iconInset)
			end
			if row.hoverBorder ~= nil then
				if row.hoverBorder[1] ~= nil then
					row.hoverBorder[1]:SetExtent(boxSize, borderSize)
				end
				if row.hoverBorder[2] ~= nil then
					row.hoverBorder[2]:SetExtent(boxSize, borderSize)
				end
				if row.hoverBorder[3] ~= nil then
					row.hoverBorder[3]:SetExtent(borderSize, boxSize)
				end
				if row.hoverBorder[4] ~= nil then
					row.hoverBorder[4]:SetExtent(borderSize, boxSize)
				end
			end
			if row.acquisitionGlowBorder ~= nil then
				if row.lastGlowBoxSize ~= boxSize then
					runtime:LayoutAcquisitionGlowBorder(row, boxSize)
					runtime:ResizeAcquisitionGlowInner(row, boxSize)
					row.lastGlowBoxSize = boxSize
				end
			end
			if row.nameLabel ~= nil then
				row.nameLabel:SetExtent(boxSize - runtime:Scale(5), runtime:Scale(18))
				row.nameLabel:RemoveAllAnchors()
				row.nameLabel:AddAnchor("TOP", row, 0, runtime:Scale(5))
				row.nameLabel.style:SetFontSize(runtime:Scale(8))
				row.nameLabel:Show(false)
			end
			if row.countLabel ~= nil then
				row.countLabel:SetExtent(boxSize - runtime:Scale(5), runtime:Scale(13))
				row.countLabel:RemoveAllAnchors()
				row.countLabel:AddAnchor("TOP", row, 0, runtime:Scale(26))
				row.countLabel.style:SetFontSize(runtime:Scale(9))
			end
			if row.sessionAcquiredLabel ~= nil then
				row.sessionAcquiredLabel:SetExtent(boxSize - runtime:Scale(5), runtime:Scale(13))
				row.sessionAcquiredLabel:RemoveAllAnchors()
				row.sessionAcquiredLabel:AddAnchor("TOP", row, 0, runtime:Scale(13))
				row.sessionAcquiredLabel.style:SetFontSize(runtime:Scale(9))
				ApplyTrackedSessionCountTextColor(row.sessionAcquiredLabel)
			end
			if row.dropRateLabel ~= nil then
				row.dropRateLabel:SetExtent(boxSize - runtime:Scale(2), runtime:Scale(CONFIG.TRACKED_DROP_RATE_LABEL_HEIGHT))
				row.dropRateLabel:RemoveAllAnchors()
				row.dropRateLabel:AddAnchor("TOP", row, 0, 0)
				row.dropRateLabel.style:SetFontSize(runtime:Scale(CONFIG.TRACKED_DROP_RATE_LABEL_FONT_SIZE))
				ApplyTrackedDropRateTextColor(row.dropRateLabel)
			end
		end
	end
	-- Applies the current tracker layout: resizes window, anchors header and rows, and anchors picker if open.
end

runtime.ApplyTrackerLayout = function()
	runtime.window:SetExtent(runtime.GetTrackerWindowWidth(), runtime.GetTrackerWindowHeight())
	AnchorHeaderControls()
	AnchorTrackedRows()
	if runtime.isPickerOpen then
		runtime.AnchorPickerWindow()
	-- Toggles between horizontal and vertical layout, saves it, applies, and refreshes display.
	end
	if runtime.PositionResizeHandles ~= nil then
		runtime:PositionResizeHandles()
	end
end

runtime.ToggleTrackerLayout = function()
	if runtime.trackerLayout == CONFIG.LAYOUT_VERTICAL then
		runtime.trackerLayout = CONFIG.LAYOUT_HORIZONTAL
	else
		runtime.trackerLayout = CONFIG.LAYOUT_VERTICAL
	end
	runtime.SaveTrackerLayout()
	runtime.ApplyTrackerLayout()
	runtime.refreshRequested = true
	runtime.UpdateRows()
end

function runtime:CreateTrackerRow(index)
	if rowWidgets[index] ~= nil then
		rowWidgets[index]:Show(true)
		return
	end

	local row = runtime.window:CreateChildWidget("button", "lootTrackerRow" .. tostring(index), 0, true)
	row.index = index
	row:SetText("")
	row:SetExtent(runtime:Scale(CONFIG.BOX_SIZE), runtime:Scale(CONFIG.BOX_SIZE))
	row:AddAnchor(
		"TOPLEFT",
		runtime.window,
		runtime.GetTrackedRowsLeft() + ((index - 1) * (runtime:Scale(CONFIG.BOX_SIZE) + runtime:Scale(CONFIG.BOX_GAP))),
		runtime.GetTrackedRowsTop()
	)
	SafeMethod(row, "Clickable", true)
	SafeMethod(row, "EnableDrag", true)
	SafeMethod(row, "RegisterForClicks", "RightButton")

	local rowBackground = row:CreateColorDrawable(0.06, 0.06, 0.07, 0.64, "background")
	rowBackground:AddAnchor("TOPLEFT", row, 0, 0)
	rowBackground:SetExtent(runtime:Scale(CONFIG.BOX_SIZE), runtime:Scale(CONFIG.BOX_SIZE))
	row.bg = rowBackground

	local hoverTop = row:CreateColorDrawable(1, 0.86, 0.42, 0, "artwork")
	hoverTop:AddAnchor("TOPLEFT", row, 0, 0)
	hoverTop:SetExtent(runtime:Scale(CONFIG.BOX_SIZE), runtime:Scale(1))

	local hoverBottom = row:CreateColorDrawable(1, 0.86, 0.42, 0, "artwork")
	hoverBottom:AddAnchor("BOTTOMLEFT", row, 0, 0)
	hoverBottom:SetExtent(runtime:Scale(CONFIG.BOX_SIZE), runtime:Scale(1))

	local hoverLeft = row:CreateColorDrawable(1, 0.86, 0.42, 0, "artwork")
	hoverLeft:AddAnchor("TOPLEFT", row, 0, 0)
	hoverLeft:SetExtent(runtime:Scale(1), runtime:Scale(CONFIG.BOX_SIZE))

	local hoverRight = row:CreateColorDrawable(1, 0.86, 0.42, 0, "artwork")
	hoverRight:AddAnchor("TOPRIGHT", row, 0, 0)
	hoverRight:SetExtent(runtime:Scale(1), runtime:Scale(CONFIG.BOX_SIZE))

	row.hoverBorder = {
		hoverTop,
		hoverBottom,
		hoverLeft,
		hoverRight,
	}

	local rowIcon = row:CreateIconDrawable("artwork")
	rowIcon:SetExtent(runtime:Scale(CONFIG.BOX_SIZE - 2), runtime:Scale(CONFIG.BOX_SIZE - 2))
	rowIcon:AddAnchor("TOPLEFT", row, runtime:Scale(1), runtime:Scale(1))
	runtime.HideIconDrawable(rowIcon)
	row.iconDrawable = rowIcon

	local glowTop = row:CreateColorDrawable(
		CONFIG.ACQUISITION_GLOW_COLOR[1],
		CONFIG.ACQUISITION_GLOW_COLOR[2],
		CONFIG.ACQUISITION_GLOW_COLOR[3],
		0,
		"artwork"
	)
	local glowBottom = row:CreateColorDrawable(
		CONFIG.ACQUISITION_GLOW_COLOR[1],
		CONFIG.ACQUISITION_GLOW_COLOR[2],
		CONFIG.ACQUISITION_GLOW_COLOR[3],
		0,
		"artwork"
	)

	local glowLeft = row:CreateColorDrawable(
		CONFIG.ACQUISITION_GLOW_COLOR[1],
		CONFIG.ACQUISITION_GLOW_COLOR[2],
		CONFIG.ACQUISITION_GLOW_COLOR[3],
		0,
		"artwork"
	)

	local glowRight = row:CreateColorDrawable(
		CONFIG.ACQUISITION_GLOW_COLOR[1],
		CONFIG.ACQUISITION_GLOW_COLOR[2],
		CONFIG.ACQUISITION_GLOW_COLOR[3],
		0,
		"artwork"
	)

	row.acquisitionGlowBorder = {
		glowTop,
		glowBottom,
		glowLeft,
		glowRight,
	}
	runtime:LayoutAcquisitionGlowBorder(row, runtime:Scale(CONFIG.BOX_SIZE))
	runtime:CreateAcquisitionGlowInnerGradient(row)
	runtime:ClearRowAcquisitionGlow(row)

	local nameLabel = row:CreateChildWidget("label", "lootTrackerRowName" .. tostring(index), 0, true)
	nameLabel:SetText("")
	nameLabel:SetExtent(runtime:Scale(CONFIG.BOX_SIZE - 5), runtime:Scale(18))
	nameLabel.style:SetAlign(ALIGN_CENTER)
	nameLabel.style:SetFontSize(runtime:Scale(8))
	nameLabel.style:SetColor(0.98, 0.98, 0.98, 1)
	nameLabel.style:SetOutline(true)
	nameLabel:AddAnchor("TOP", row, 0, runtime:Scale(5))
	nameLabel:Show(false)
	SafeMethod(nameLabel, "EnablePick", false)
	row.nameLabel = nameLabel

	local countLabel = row:CreateChildWidget("label", "lootTrackerRowCount" .. tostring(index), 0, true)
	countLabel:SetText("")
	countLabel:SetExtent(runtime:Scale(CONFIG.BOX_SIZE - 5), runtime:Scale(13))
	countLabel.style:SetAlign(ALIGN_CENTER)
	countLabel.style:SetFontSize(runtime:Scale(9))
	countLabel.style:SetColor(0.92, 0.86, 0.62, 1)
	countLabel.style:SetOutline(true)
	-- Sets hover state to true for the row on mouse enter.
	countLabel:AddAnchor("TOP", row, 0, runtime:Scale(26))
	SafeMethod(countLabel, "EnablePick", false)
	row.countLabel = countLabel

	local sessionAcquiredLabel = row:CreateChildWidget("label", "lootTrackerRowSessionCount" .. tostring(index), 0, true)
	sessionAcquiredLabel:SetText("")
	sessionAcquiredLabel:SetExtent(runtime:Scale(CONFIG.BOX_SIZE - 5), runtime:Scale(13))
	sessionAcquiredLabel.style:SetAlign(ALIGN_CENTER)
	sessionAcquiredLabel.style:SetFontSize(runtime:Scale(9))
	sessionAcquiredLabel.style:SetOutline(true)
	ApplyTrackedSessionCountTextColor(sessionAcquiredLabel)
	sessionAcquiredLabel:AddAnchor("TOP", row, 0, runtime:Scale(13))
	SafeMethod(sessionAcquiredLabel, "EnablePick", false)
	row.sessionAcquiredLabel = sessionAcquiredLabel

	local dropRateLabel = row:CreateChildWidget("label", "lootTrackerRowDropRate" .. tostring(index), 0, true)
	dropRateLabel:SetText("")
	dropRateLabel:SetExtent(runtime:Scale(CONFIG.BOX_SIZE - 2), runtime:Scale(CONFIG.TRACKED_DROP_RATE_LABEL_HEIGHT))
	dropRateLabel.style:SetAlign(ALIGN_CENTER)
	dropRateLabel.style:SetFontSize(runtime:Scale(CONFIG.TRACKED_DROP_RATE_LABEL_FONT_SIZE))
	dropRateLabel.style:SetOutline(true)
	ApplyTrackedDropRateTextColor(dropRateLabel)
	dropRateLabel:AddAnchor("TOP", row, 0, 0)
	dropRateLabel:Show(false)
	SafeMethod(dropRateLabel, "EnablePick", false)
	row.dropRateLabel = dropRateLabel

	function row:OnEnter()
		-- Sets hover state to true for the row on mouse enter.
		runtime.ShowTrackerHeaderControls()
		SetTrackerSlotRightDragHover(self.index)
		SetRowHover(self, true)
	end
	row:SetHandler("OnEnter", row.OnEnter)

		-- Sets hover state to false for the row on mouse leave.
	function row:OnLeave()
		ClearTrackerSlotRightDragHover(self.index)
		SetRowHover(self, false)
	end
	row:SetHandler("OnLeave", row.OnLeave)
		-- Handles click on a tracked row: right click removes item, left opens picker.

	function row:OnClick(mouseButton)
		if self.draggedTrackerSlot then
			self.draggedTrackerSlot = false
			return
		end
		if self.draggedTrackerWindow then
			self.draggedTrackerWindow = false
			return
		end
		runtime.HandleRowClick(self.index, mouseButton)
	end
	row:SetHandler("OnClick", row.OnClick)

	function row:OnMouseDown(mouseButton)
		BeginTrackerSlotRightDrag(self.index, mouseButton)
	end
	row:SetHandler("OnMouseDown", row.OnMouseDown)

	function row:OnMouseUp(mouseButton)
		if EndTrackerSlotRightDrag(self.index, mouseButton) then
			runtime.UpdateRows()
		end
	end
	row:SetHandler("OnMouseUp", row.OnMouseUp)

	function row:OnRightButtonDown()
		BeginTrackerSlotRightDrag(self.index, "RightButton")
	end
	row:SetHandler("OnRightButtonDown", row.OnRightButtonDown)

	function row:OnRightButtonUp()
		if EndTrackerSlotRightDrag(self.index, "RightButton") then
			runtime.UpdateRows()
		end
	end
	row:SetHandler("OnRightButtonUp", row.OnRightButtonUp)

	function row:OnDragStart()
		if trackerSlotRightDrag.sourceIndex == self.index then
			self.draggedTrackerSlot = true
			return true
		end
		self.draggedTrackerWindow = true
		runtime.window:StartMoving()
		return true
	end
	row:SetHandler("OnDragStart", row.OnDragStart)

	function row:OnDragStop()
		if self.draggedTrackerSlot then
			self.draggedTrackerSlot = false
			if EndTrackerSlotRightDrag(self.index, "RightButton") then
				runtime.UpdateRows()
			end
			return
		end
		runtime.window:StopMovingOrSizing()
		runtime.SaveWindowPosition(runtime.window)
		if runtime.PositionResizeHandles ~= nil then
			runtime:PositionResizeHandles()
		end
	end
	row:SetHandler("OnDragStop", row.OnDragStop)

	rowWidgets[index] = row
end

local function RemoveTrackedSlotAt(removeIndex, currentCount)
	for index = removeIndex, currentCount - 1 do
		trackedItems[index] = runtime.CopyTrackedItemData(trackedItems[index + 1])
	end
	trackedItems[currentCount] = nil
end

local function FindEmptyTrackedSlotIndex(currentCount)
	for index = 1, currentCount do
		if trackedItems[index] == nil then
			return index
		end
	end
	return nil
end

local function RemoveOneTrackedSlot(currentCount)
	-- Reductions preserve tracked items by removing the first empty slot; only full layouts lose the rightmost item.
	local emptyIndex = FindEmptyTrackedSlotIndex(currentCount)
	if emptyIndex ~= nil then
		RemoveTrackedSlotAt(emptyIndex, currentCount)
	else
		RemoveTrackedSlotAt(currentCount, currentCount)
	end
end

function runtime:ChangeSlotCount(delta, options)
	options = options or {}
	local nextCount = runtime.trackedSlotCount + (tonumber(delta) or 0)
	if nextCount < 1 then
		nextCount = 1
	elseif nextCount > 20 then
		nextCount = 20
	end
	if nextCount == runtime.trackedSlotCount then
		return
	end

	if nextCount < runtime.trackedSlotCount then
		local currentCount = runtime.trackedSlotCount
		while currentCount > nextCount do
			RemoveOneTrackedSlot(currentCount)
			currentCount = currentCount - 1
		end
		ClearTrackerSlotRightDrag()
		runtime.ClosePicker()
	end

	runtime.trackedSlotCount = nextCount
	for index = 1, runtime.trackedSlotCount do
		self:CreateTrackerRow(index)
	end
	if not options.skipSave then
		self:SaveSlotCount()
		runtime.SaveTrackedItems()
	end
	if not options.skipLayout and runtime.ApplyTrackerLayout ~= nil then
		runtime.ApplyTrackerLayout()
	end
	if not options.skipRefresh then
		runtime.refreshRequested = true
		if not options.skipUpdateRows and runtime.UpdateRows ~= nil then
			runtime.UpdateRows()
		end
	end
	return true
end

function runtime:ApplyResizeGeometry(x, y, scale, shouldSave)
	self.trackerScale = self:ClampScale(scale)
	runtime.AnchorWidgetAtSavedPosition(runtime.window, x, y)
	runtime.ApplyTrackerLayout()
	if shouldSave then
		runtime.SaveWindowPosition(runtime.window)
		self:SaveWindowScale()
	end
end

function runtime:PositionResizeHandles()
	local handleSize = self:Scale(18)
	local boxSize = self:Scale(CONFIG.BOX_SIZE)
	local boxGap = self:Scale(CONFIG.BOX_GAP)
	local firstBoxX = runtime.GetTrackedRowsLeft()
	local firstBoxY = runtime.GetTrackedRowsTop()
	local lastBoxX = firstBoxX
	local lastBoxY = firstBoxY
	if runtime.trackerLayout == CONFIG.LAYOUT_VERTICAL then
		lastBoxY = firstBoxY + ((runtime.trackedSlotCount - 1) * (boxSize + boxGap))
	else
		lastBoxX = firstBoxX + ((runtime.trackedSlotCount - 1) * (boxSize + boxGap))
	end
	for _, handle in ipairs(self.resizeHandles) do
		if handle ~= nil then
			self:LayoutResizeGrip(handle)
		end
		if handle ~= nil then
			local boxX = firstBoxX
			local boxY = firstBoxY
			if runtime.trackerLayout == CONFIG.LAYOUT_VERTICAL then
				if not handle.resizeFromTop then
					boxX = lastBoxX
					boxY = lastBoxY
				end
			elseif not handle.resizeFromLeft then
				boxX = lastBoxX
				boxY = lastBoxY
			end
			local handleX = boxX
			local handleY = boxY
			if not handle.resizeFromTop then
				handleY = boxY + boxSize - handleSize
			end
			if not handle.resizeFromLeft then
				handleX = boxX + boxSize - handleSize
			end
			if handle.resizeVisual ~= nil then
				handle.resizeVisual:RemoveAllAnchors()
				handle.resizeVisual:AddAnchor("TOPLEFT", runtime.window, handleX, handleY)
			end
			if not handle.isResizing then
				handle:RemoveAllAnchors()
				handle:AddAnchor("TOPLEFT", runtime.window, handleX, handleY)
			end
			SafeMethod(handle.resizeVisual, "Raise")
			SafeMethod(handle, "Raise")
		end
	end
end

function runtime:SetResizeHandlesVisible(visible)
	for _, handle in ipairs(self.resizeHandles) do
		if handle ~= nil then
			handle:Show(visible or handle.isResizing == true)
			if handle.resizeVisual ~= nil then
				handle.resizeVisual:Show(visible or handle.isResizing == true)
			end
			if visible then
				SafeMethod(handle.resizeVisual, "Raise")
				SafeMethod(handle, "Raise")
			end
		end
	end
end

function runtime:IsResizing()
	for _, handle in ipairs(self.resizeHandles) do
		if handle ~= nil and handle.isResizing then
			return true
		end
	end
	return false
end

function runtime:SetResizeGripAlpha(handle, alpha)
	if handle == nil then
		return
	end
	local visual = handle.resizeVisual or handle
	if visual.resizeGripA ~= nil then
		visual.resizeGripA:SetColor(1, 1, 1, alpha)
	end
	if visual.resizeGripB ~= nil then
		visual.resizeGripB:SetColor(1, 1, 1, alpha)
	end
end

function runtime:LayoutResizeGrip(handle)
	if handle == nil then
		return
	end
	local visual = handle.resizeVisual or handle
	local handleSize = self:Scale(18)
	local lineLength = self:Scale(9)
	local lineThickness = self:Scale(2)
	local inset = self:Scale(5)
	local horizontalX = inset
	local verticalX = inset
	local horizontalY = inset
	local verticalY = inset
	if not handle.resizeFromLeft then
		horizontalX = handleSize - inset - lineLength
		verticalX = handleSize - inset - lineThickness
	end
	if not handle.resizeFromTop then
		horizontalY = handleSize - inset - lineThickness
		verticalY = handleSize - inset - lineLength
	end
	handle:SetExtent(handleSize, handleSize)
	visual:SetExtent(handleSize, handleSize)
	if visual.resizeGripA ~= nil then
		visual.resizeGripA:RemoveAllAnchors()
		visual.resizeGripA:SetExtent(lineLength, lineThickness)
		visual.resizeGripA:AddAnchor("TOPLEFT", visual, horizontalX, horizontalY)
	end
	if visual.resizeGripB ~= nil then
		visual.resizeGripB:RemoveAllAnchors()
		visual.resizeGripB:SetExtent(lineThickness, lineLength)
		visual.resizeGripB:AddAnchor("TOPLEFT", visual, verticalX, verticalY)
	end
end

function runtime:ComputeResizeGeometry(handle)
	local data = handle.resizeDrag
	if data == nil then
		return nil
	end

	local handleX, handleY = GetWidgetSavedPosition(handle)
	if handleX == nil or handleY == nil then
		return nil
	end

	local deltaX = handleX - data.handleStartX
	local deltaY = handleY - data.handleStartY
	local width = data.startWidth
	local height = data.startHeight
	if data.resizeFromLeft then
		width = data.startWidth - deltaX
	else
		width = data.startWidth + deltaX
	end
	if data.resizeFromTop then
		height = data.startHeight - deltaY
	else
		height = data.startHeight + deltaY
	end

	local widthScale = width / data.baseWidth
	local heightScale = height / data.baseHeight
	local scale = widthScale
	if math.abs(heightScale - data.startScale) > math.abs(widthScale - data.startScale) then
		scale = heightScale
	end
	scale = self:ClampScale(scale)
	width = self:ScaleAt(data.baseWidth, scale)
	height = self:ScaleAt(data.baseHeight, scale)
	local x = data.startX
	local y = data.startY
	if data.resizeFromLeft then
		x = data.startX + data.startWidth - width
	end
	if data.resizeFromTop then
		y = data.startY + data.startHeight - height
	end
	return x, y, scale
end

function runtime:ShouldApplyResizeGeometry(handle, x, y, scale)
	local data = handle and handle.resizeDrag
	if data == nil then
		return true
	end
	if data.lastAppliedX == nil then
		data.lastAppliedX = x
		data.lastAppliedY = y
		data.lastAppliedScale = scale
		return true
	end
	if math.abs(x - data.lastAppliedX) >= 1
		or math.abs(y - data.lastAppliedY) >= 1
		or math.abs(scale - data.lastAppliedScale) >= CONFIG.RESIZE_SCALE_EPSILON
	then
		data.lastAppliedX = x
		data.lastAppliedY = y
		data.lastAppliedScale = scale
		return true
	end
	return false
end

function runtime:CreateResizeHandle(name, anchor)
	local handle = runtime.window:CreateChildWidget("button", name, 0, true)
	handle:SetText("")
	handle:SetExtent(self:Scale(18), self:Scale(18))
	handle:EnableDrag(true)
	handle:Clickable(true)
	handle.resizeFromLeft = string.find(anchor, "LEFT", 1, true) ~= nil
	handle.resizeFromTop = string.find(anchor, "TOP", 1, true) ~= nil
	local visual = runtime.window:CreateChildWidget("button", name .. "Visual", 0, true)
	visual:SetText("")
	visual:SetExtent(self:Scale(18), self:Scale(18))
	SafeMethod(visual, "Clickable", false)
	SafeMethod(visual, "EnableDrag", false)
	SafeMethod(visual, "EnablePick", false)
	visual.resizeGripA = visual:CreateColorDrawable(1, 1, 1, 0, "background")
	visual.resizeGripB = visual:CreateColorDrawable(1, 1, 1, 0, "background")
	handle.resizeVisual = visual
	handle:Show(false)
	visual:Show(false)
	self:LayoutResizeGrip(handle)

	function handle:OnEnter()
		runtime.ShowTrackerHeaderControls()
		runtime:SetResizeGripAlpha(self, 0.65)
	end
	handle:SetHandler("OnEnter", handle.OnEnter)

	function handle:OnLeave()
		if not self.isResizing then
			runtime:SetResizeGripAlpha(self, 0)
		end
	end
	handle:SetHandler("OnLeave", handle.OnLeave)

	function handle:OnDragStart()
		local startX, startY = GetWidgetSavedPosition(runtime.window)
		local handleStartX, handleStartY = GetWidgetSavedPosition(self)
		if startX == nil or startY == nil or handleStartX == nil or handleStartY == nil then
			return
		end

		self.resizeDrag = {
			startX = startX,
			startY = startY,
			startWidth = runtime.GetTrackerWindowWidth(),
			startHeight = runtime.GetTrackerWindowHeight(),
			startScale = runtime.trackerScale,
			baseWidth = runtime:GetBaseWindowWidth(),
			baseHeight = runtime:GetBaseWindowHeight(),
			handleStartX = handleStartX,
			handleStartY = handleStartY,
			resizeFromLeft = self.resizeFromLeft,
			resizeFromTop = self.resizeFromTop,
			updateElapsed = CONFIG.RESIZE_UPDATE_INTERVAL,
		}
		self:RemoveAllAnchors()
		self:AddAnchor("TOPLEFT", "UIParent", handleStartX, handleStartY)
		self.isResizing = true
		runtime:SetResizeGripAlpha(self, 0.65)
		runtime.ShowTrackerHeaderControls()
		self:StartMoving()
	end
	handle:SetHandler("OnDragStart", handle.OnDragStart)

	function handle:OnUpdate(dt)
		if self.isResizing then
			local data = self.resizeDrag
			if data ~= nil then
				data.updateElapsed = (data.updateElapsed or 0) + NormalizeDt(dt)
				if data.updateElapsed < CONFIG.RESIZE_UPDATE_INTERVAL then
					return
				end
				data.updateElapsed = 0
			end
			local x, y, scale = runtime:ComputeResizeGeometry(self)
			if x ~= nil and runtime:ShouldApplyResizeGeometry(self, x, y, scale) then
				runtime:ApplyResizeGeometry(x, y, scale, false)
			end
		end
	end
	handle:SetHandler("OnUpdate", handle.OnUpdate)

	function handle:OnDragStop()
		self:StopMovingOrSizing()
		local x, y, scale = runtime:ComputeResizeGeometry(self)
		if x ~= nil then
			runtime:ApplyResizeGeometry(x, y, scale, true)
		end
		self.resizeDrag = nil
		self.isResizing = false
		runtime:SetResizeGripAlpha(self, 0)
		runtime:PositionResizeHandles()
	end
	handle:SetHandler("OnDragStop", handle.OnDragStop)

	return handle
end

for index = 1, runtime.trackedSlotCount do
	runtime:CreateTrackerRow(index)
end

runtime.resizeHandles = {
	runtime:CreateResizeHandle("lootTrackerResizeTopLeft", "TOPLEFT"),
	runtime:CreateResizeHandle("lootTrackerResizeTopRight", "TOPRIGHT"),
	runtime:CreateResizeHandle("lootTrackerResizeBottomLeft", "BOTTOMLEFT"),
	runtime:CreateResizeHandle("lootTrackerResizeBottomRight", "BOTTOMRIGHT"),
}

runtime.ApplyTrackerLayout()
runtime.HideTrackerHeaderControls()

