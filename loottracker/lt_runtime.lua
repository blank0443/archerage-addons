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
ADDON:ImportObject(OBJECT_TYPE.X2_EDITBOX)
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)

ADDON:ImportAPI(API_TYPE.BAG.id)
ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)


local LT = _G.__LOOT_TRACKER
local CONFIG = LT and LT.C
if LT == nil or CONFIG == nil then
	return
end

local SafeMethod = LT.SafeMethod
local NormalizeName = LT.NormalizeName
local BuildItemKey = LT.BuildItemKey

local previousRuntime = _G.__LOOT_TRACKER_RUNTIME
if previousRuntime ~= nil then
	previousRuntime.active = false
	previousRuntime.gameLoadingStarted = true
	-- Prefer the explicit flag over widget IsVisible (unreliable across UI refresh).
	local trackerVisible = previousRuntime.trackerWindowVisible
	if trackerVisible == nil then
		local function IsWidgetVisible(widget)
			if widget == nil or type(widget.IsVisible) ~= "function" then
				return false
			end
			local ok, visible = pcall(widget.IsVisible, widget)
			return ok and visible == true
		end
		local restoreVisible = IsWidgetVisible(previousRuntime.restoreButton)
		trackerVisible = IsWidgetVisible(previousRuntime.window) and not restoreVisible
		LT.uiRefreshRestoreVisible = restoreVisible
	else
		trackerVisible = trackerVisible == true
		LT.uiRefreshRestoreVisible = (not trackerVisible)
			and previousRuntime.menuMode ~= true
	end
	LT.uiRefreshTrackerVisible = trackerVisible == true
	local function ClearWidgetHandlers(widget)
		if widget == nil or type(widget.SetHandler) ~= "function" then
			return
		end
		pcall(widget.SetHandler, widget, "OnUpdate", nil)
		pcall(widget.SetHandler, widget, "OnEvent", nil)
	end
	ClearWidgetHandlers(previousRuntime.window)
	ClearWidgetHandlers(previousRuntime.chatCommandListener)
	ClearWidgetHandlers(previousRuntime.pickerWindow)
	ClearWidgetHandlers(previousRuntime.setWindow)
	if previousRuntime.resizeHandles ~= nil then
		for _, handle in ipairs(previousRuntime.resizeHandles) do
			ClearWidgetHandlers(handle)
			if handle ~= nil then
				handle:Show(false)
			end
		end
	end
	if previousRuntime.window ~= nil then
		previousRuntime.window:Show(false)
	end
	if previousRuntime.pickerWindow ~= nil then
		previousRuntime.pickerWindow:Show(false)
	end
	if previousRuntime.setWindow ~= nil then
		previousRuntime.setWindow:Show(false)
	end
	if previousRuntime.restoreButton ~= nil then
		previousRuntime.restoreButton:Show(false)
	end
	if previousRuntime.chatCommandListener ~= nil then
		previousRuntime.chatCommandListener:Show(false)
	end
	if previousRuntime.SetResizeHandlesVisible ~= nil then
		previousRuntime:SetResizeHandlesVisible(false)
	end
end

local runtime = {
	active = true,
	window = nil,
	pickerWindow = nil,
	setWindow = nil,
	restoreButton = nil,
	chatCommandListener = nil,
	resizeHandles = {},
	trackedItemSets = {},
	trackerSetRows = {},
	selectedSetName = nil,
	setNameText = "",
	setNameInputSyncingText = false,
	trackerScale = 1,
	menuMode = false,
	escMenuButtonRegistered = false,
	lootRateMarker = nil,
	trackedDropRatesByKey = {},
	trackedSessionAcquiredByKey = {},
	dropRateSessionKillStart = nil,
	dropRateLastObservedKillTotal = nil,
	dropRateLastRefreshKillTotal = nil,
	dropRateIdleElapsed = 0,
	dropRateLastLootActivityAt = nil,
	lootActivityFresh = false,
	sessionAcquiredIdleElapsed = 0,
	sessionAcquiredLastActivityAt = nil,
	acquisitionGlowActive = false,
	acquisitionGlowRows = {},
	acquisitionGlowBatchStartedAt = nil,
	gameLoadingStarted = false,
	wasTrackerVisibleBeforeLoading = false,
	wasRestoreVisibleBeforeLoading = false,
	-- Explicit open/hidden intent; do not infer from widget IsVisible across refresh/loading.
	trackerWindowVisible = true,
	lastKnownTrackerX = nil,
	lastKnownTrackerY = nil,
	lastKnownRestoreX = nil,
	lastKnownRestoreY = nil,
}
_G.__LOOT_TRACKER_RUNTIME = runtime

runtime.trackedItems = runtime.trackedItems or {}
runtime.rowWidgets = runtime.rowWidgets or {}
runtime.pickerItemWidgets = runtime.pickerItemWidgets or {}
runtime.pickerItems = runtime.pickerItems or {}
runtime.pickerSlotIndex = nil
runtime.pickerScrollIndex = 1
runtime.pickerSearchText = ""
runtime.pickerSearchPollElapsed = 0
runtime.pickerSearchTextEventSuppressed = false
runtime.isPickerOpen = false
runtime.refreshRequested = true
runtime.inventoryDirty = true
runtime.inventoryItemsByKey = nil
runtime.inventoryOrderedItems = nil
runtime.inventoryItemsByName = nil
runtime.inventoryVersion = 0
runtime.inventoryRefreshPending = false
runtime.inventoryRefreshPendingElapsed = 0
runtime.pickerCachedSearchText = nil
runtime.pickerCachedInventoryVersion = -1
runtime.pickerCachedItems = nil
runtime.inventoryIconPathCache = runtime.inventoryIconPathCache or {}
runtime.trackerLayout = CONFIG.LAYOUT_HORIZONTAL
runtime.restoreButtonPositionSaved = false
runtime.pickerWindowPositionSaved = false
runtime.trackerHeaderControlsVisible = true
runtime.trackerSlotRightDrag = runtime.trackerSlotRightDrag or { sourceIndex = nil, hoverIndex = nil }
runtime.suppressRowRightClickUntil = 0
runtime.trackedSlotCount = CONFIG.DEFAULT_TRACKED_SLOT_COUNT

-- Keep a file-local alias to the shared table; bare `trackedItems` would write a global.
local trackedItems = runtime.trackedItems

function runtime:RegisterEscMenuButton()
	if ADDON == nil
		or type(ADDON.RegisterContentTriggerFunc) ~= "function"
		or type(ADDON.AddEscMenuButton) ~= "function"
	then
		return false
	end

	local ok = pcall(function()
		ADDON:RegisterContentTriggerFunc(CONFIG.ESC_MENU_CONTENT_ID, function(show)
			local currentRuntime = _G.__LOOT_TRACKER_RUNTIME
			if currentRuntime ~= nil
				and currentRuntime.active
				and type(currentRuntime.OpenFromEscMenu) == "function"
			then
				currentRuntime:OpenFromEscMenu(show)
			end
		end)
		if _G.__LOOT_TRACKER_ESC_MENU_BUTTON_ADDED ~= true then
			ADDON:AddEscMenuButton(
				CONFIG.ESC_MENU_CATEGORY_ID,
				CONFIG.ESC_MENU_CONTENT_ID,
				CONFIG.ESC_MENU_ICON_KEY,
				CONFIG.ESC_MENU_BUTTON_NAME
			)
			_G.__LOOT_TRACKER_ESC_MENU_BUTTON_ADDED = true
		end
	end)

	if ok then
		self.escMenuButtonRegistered = true
	end
	return ok
end
function runtime:SuspendForLoading()
	if self.gameLoadingStarted then
		return
	end

	-- Remember user intent from the flag (and disk), never widget IsVisible.
	-- Loading hide must not call HideLootTrackerWindow / SaveWindowVisible.
	local savedVisible = nil
	if self.LoadWindowVisible ~= nil then
		savedVisible = self:LoadWindowVisible()
	end
	if savedVisible ~= nil then
		self.trackerWindowVisible = savedVisible == true
	end
	self.wasTrackerVisibleBeforeLoading = self.trackerWindowVisible == true
	self.wasRestoreVisibleBeforeLoading = (not self.wasTrackerVisibleBeforeLoading)
		and self.menuMode ~= true
	self.gameLoadingStarted = true
	runtime.inventoryRefreshPending = false
	runtime.inventoryRefreshPendingElapsed = 0
	runtime.refreshRequested = false
	self.lootActivityFresh = false
	if self.ClearAllAcquisitionGlows ~= nil then
		self:ClearAllAcquisitionGlows()
	end
	if runtime.ClosePicker ~= nil then
		runtime.ClosePicker()
	end
	if self.setWindow ~= nil then
		self.setWindow:Show(false)
	end
	if self.SetResizeHandlesVisible ~= nil then
		self:SetResizeHandlesVisible(false)
	end
	if runtime.window ~= nil then
		runtime.window:Show(false)
	end
	if runtime.restoreButton ~= nil then
		runtime.restoreButton:Show(false)
	end
end

local function ResolveTrackerResumePosition()
	if runtime.lastKnownTrackerX ~= nil and runtime.lastKnownTrackerY ~= nil then
		return runtime.lastKnownTrackerX, runtime.lastKnownTrackerY
	end
	return runtime.LoadWindowPosition()
end

local function ResolveRestoreResumePosition()
	if runtime.lastKnownRestoreX ~= nil and runtime.lastKnownRestoreY ~= nil then
		return runtime.lastKnownRestoreX, runtime.lastKnownRestoreY
	end
	if runtime.restoreButtonPositionSaved then
		return runtime.LoadRestoreButtonPosition(420, 320)
	end
	return ResolveTrackerResumePosition()
end

-- Clears the loading gate and restores the tracker at the last known good screen position.
function runtime:ResumeAfterLoading()
	if not self.gameLoadingStarted then
		return
	end
	self.gameLoadingStarted = false

	-- Disk is authoritative (same pattern as quickopts). Fall back to pre-loading flag.
	local shouldShowTracker = self.wasTrackerVisibleBeforeLoading == true
	if self.LoadWindowVisible ~= nil then
		local savedVisible = self:LoadWindowVisible()
		if savedVisible ~= nil then
			shouldShowTracker = savedVisible == true
		end
	end
	local shouldShowRestore = (not shouldShowTracker) and not self.menuMode
	self.wasTrackerVisibleBeforeLoading = false
	self.wasRestoreVisibleBeforeLoading = false
	self.trackerWindowVisible = shouldShowTracker

	if shouldShowTracker then
		local trackerX, trackerY = ResolveTrackerResumePosition()
		runtime.ShowLootTrackerWindow(trackerX, trackerY)
		return
	end

	runtime.MarkInventoryDirty(true)
	-- Keep hidden without going through HideLootTrackerWindow (already saved false on disk).
	if runtime.window ~= nil then
		runtime.window:Show(false)
	end
	if runtime.SetResizeHandlesVisible ~= nil then
		runtime:SetResizeHandlesVisible(false)
	end
	if shouldShowRestore and runtime.restoreButton ~= nil then
		local restoreX, restoreY = ResolveRestoreResumePosition()
		if runtime.AnchorWidgetAtSavedPosition ~= nil then
			runtime.AnchorWidgetAtSavedPosition(runtime.restoreButton, restoreX, restoreY)
		end
		runtime.lastKnownRestoreX = restoreX
		runtime.lastKnownRestoreY = restoreY
		runtime.restoreButton:Show(true)
		SafeMethod(runtime.restoreButton, "CorrectOffsetByScreen")
	elseif runtime.restoreButton ~= nil then
		runtime.restoreButton:Show(false)
	end
end

function runtime:OpenFromEscMenu(show)
	if show == false then
		if runtime.HideLootTrackerWindow ~= nil then
			runtime.HideLootTrackerWindow()
		end
		return
	end

	if show == nil
		and runtime.window ~= nil
		and type(runtime.window.IsVisible) == "function"
		and runtime.window:IsVisible()
	then
		if runtime.HideLootTrackerWindow ~= nil then
			runtime.HideLootTrackerWindow()
		end
		return
	end

	if runtime.ShowLootTrackerWindow ~= nil then
		runtime.ShowLootTrackerWindow()
	end
end

function runtime:UpdateMenuModeButton()
	if self.menuModeButton ~= nil then
		self.menuModeButton:SetText("M:" .. (self.menuMode and "1" or "0"))
	end
end

function runtime:SetMenuMode(enabled, shouldSave)
	if enabled == true then
		if not self:RegisterEscMenuButton() then
			return
		end
		self.menuMode = true
		if runtime.restoreButton ~= nil then
			runtime.restoreButton:Show(false)
		end
	else
		self.menuMode = false
	end

	self:UpdateMenuModeButton()
	if shouldSave then
		self:SaveMenuMode()
	end
end

function runtime:GetPlayerDropRateMul()
	if X2Unit == nil or type(X2Unit.UnitInfo) ~= "function" then
		return nil
	end

	local ok, unitInfo = pcall(function()
		return X2Unit:UnitInfo("player")
	end)
	if not ok or type(unitInfo) ~= "table" then
		return nil
	end

	local valueOk, value = pcall(function()
		return unitInfo[CONFIG.DROP_RATE_KEY]
	end)
	if valueOk then
		return tonumber(value)
	end
	return nil
end

function runtime:FormatLootRatePercent()
	local dropRateMul = self:GetPlayerDropRateMul()
	if dropRateMul == nil then
		return "N/A"
	end

	local percent = 100 + dropRateMul
	if percent == math.floor(percent) then
		return tostring(math.floor(percent)) .. "%"
	end
	return string.format("%.1f%%", percent)
end

function runtime:ApplyLootRateTextColor(label)
	if label == nil or label.style == nil then
		return
	end
	label.style:SetColor(
		CONFIG.LOOT_RATE_TEXT_COLOR[1],
		CONFIG.LOOT_RATE_TEXT_COLOR[2],
		CONFIG.LOOT_RATE_TEXT_COLOR[3],
		CONFIG.LOOT_RATE_TEXT_COLOR[4]
	)
end

function runtime:UpdateLootRateMarkerText()
	if self.lootRateMarker ~= nil then
		self.lootRateMarker:SetText(self:FormatLootRatePercent())
	end
end
function runtime.RemoveTrackedItem(index)
	if trackedItems[index] == nil then
		return
	end
	trackedItems[index] = nil
	runtime.SaveTrackedItems()
	runtime.refreshRequested = true
end

-- Copies picker and saved-set item data into the compact tracked-item shape.
function runtime.CopyTrackedItemData(item)
	if type(item) ~= "table" or item.name == nil then
		return nil
	end

	local itemName = tostring(item.name)
	local itemGrade = item.grade
	local itemIconPath = item.iconPath
	return {
		key = item.key or BuildItemKey(itemName, itemGrade, itemIconPath) or NormalizeName(itemName),
		name = itemName,
		grade = itemGrade,
		iconPath = itemIconPath,
	}
end

function runtime:CopyTrackedItem(item)
	return runtime.CopyTrackedItemData(item)
end

function runtime.TrackedItemsMatch(left, right)
	-- Saved data may have older name-only keys, so compare exact keys first and then use compatible item fields.
	if type(left) ~= "table" or type(right) ~= "table" or left.name == nil or right.name == nil then
		return false
	end

	local leftKey = left.key or BuildItemKey(left.name, left.grade, left.iconPath) or NormalizeName(left.name)
	local rightKey = right.key or BuildItemKey(right.name, right.grade, right.iconPath) or NormalizeName(right.name)
	if leftKey ~= nil and leftKey ~= "" and leftKey == rightKey then
		return true
	end

	local leftName = NormalizeName(left.name)
	local rightName = NormalizeName(right.name)
	if leftName == "" or leftName ~= rightName then
		return false
	end

	local gradeMatches = left.grade == nil or right.grade == nil or left.grade == right.grade
	local iconMatches = left.iconPath == nil or right.iconPath == nil or left.iconPath == right.iconPath
	return gradeMatches and iconMatches
end

function runtime.FindTrackedItemIndex(item, ignoredIndex)
	for index = 1, runtime.trackedSlotCount do
		if index ~= ignoredIndex and runtime.TrackedItemsMatch(trackedItems[index], item) then
			return index
		end
	end
	return nil
end

-- Sets a tracked item and swaps with an existing matching tracked slot instead of duplicating it.
function runtime.SetTrackedItem(index, item)
	if index == nil or item == nil then
		return
	end

	local nextItem = runtime.CopyTrackedItemData(item)
	if nextItem == nil then
		return
	end

	local existingIndex = runtime.FindTrackedItemIndex(nextItem, index)
	if existingIndex ~= nil then
		trackedItems[existingIndex] = runtime.CopyTrackedItemData(trackedItems[index])
	end
	trackedItems[index] = nextItem
	runtime.SaveTrackedItems()
	runtime.refreshRequested = true
end
