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

runtime:LoadSlotCount()
runtime:LoadWindowScale()
runtime:LoadMenuMode()
runtime.LoadTrackedItems()
runtime.trackerLayout = runtime.LoadTrackerLayout()

function runtime.window:OnDragStart()
	-- Handles the OnDragStart event for the tracker window. Initiates moving the window.
	self:StartMoving()
end
runtime.window:SetHandler("OnDragStart", runtime.window.OnDragStart)

function runtime.window:OnDragStop()
	-- Handles the OnDragStop event for the tracker window. Stops moving/sizing and saves the current window position to persistent storage.
	self:StopMovingOrSizing()
	runtime.SaveWindowPosition(self)
	if runtime.PositionResizeHandles ~= nil then
		runtime:PositionResizeHandles()
	end
end
runtime.window:SetHandler("OnDragStop", runtime.window.OnDragStop)

local watchedEvents = {
	BAG_UPDATE = true,
	BAG_EXPANDED = true,
	ADDED_ITEM = true,
	REMOVED_ITEM = true,
	ITEM_ACQUISITION_BY_LOOT = true,
	SHOW_ADDED_ITEM = true,
}

local dropRateLootActivityEvents = {
	ADDED_ITEM = true,
	ITEM_ACQUISITION_BY_LOOT = true,
	SHOW_ADDED_ITEM = true,
}

local function IsLootTrackerResetCommandText(value)
	if type(value) ~= "string" then
		return false
	end
	local length = string.len(value)
	if length < 18 or length > 24 then
		return false
	end
	if string.sub(value, 1, 1) ~= "/" then
		return false
	end
	return string.lower(Trim(value)) == "/loottracker reset"
end

local function IsOwnLootTrackerResetCommand(name, message)
	if not IsLootTrackerResetCommandText(message) then
		return false
	end

	if X2Unit == nil or type(X2Unit.UnitName) ~= "function" then
		return true
	end

	return name == X2Unit:UnitName("player")
end

local function HandleLootTrackerChatCommand(channel, relation, name, message, info)
	if IsOwnLootTrackerResetCommand(name, message) then
		runtime.CenterLootTrackerWindow()
	end
end

function runtime.window:OnEvent(event)
	if not runtime.active then
		return
	end
	if event == "ENTERED_LOADING" then
		runtime:SuspendForLoading()
		return
	end
	if event == "LEFT_LOADING" or event == "ENTERED_WORLD" then
		runtime:ResumeAfterLoading()
		return
	end
	if runtime.gameLoadingStarted then
		return
	end
	if watchedEvents[event] then
		runtime.MarkInventoryDirty(false)
	end
	if dropRateLootActivityEvents[event] then
		local currentKills = runtime.GetCurrentSessionKillTotal()
		if currentKills ~= nil and currentKills > 0 then
			runtime:MarkDropRateLootActivity()
		end
	end
end
runtime.window:SetHandler("OnEvent", runtime.window.OnEvent)

for eventName, _ in pairs(watchedEvents) do
	runtime.window:RegisterEvent(eventName)
end
runtime.window:RegisterEvent("ENTERED_LOADING")
runtime.window:RegisterEvent("LEFT_LOADING")
runtime.window:RegisterEvent("ENTERED_WORLD")

local chatCommandListener = CreateEmptyWindow("lootTrackerChatCommandListener", "UIParent")
runtime.chatCommandListener = chatCommandListener
chatCommandListener:Show(false)

function chatCommandListener:OnEvent(event, ...)
	if not runtime.active or runtime.gameLoadingStarted then
		return
	end
	if event == "CHAT_MESSAGE" or event == "CHAT_FAILED" then
		HandleLootTrackerChatCommand(...)
	end
end
chatCommandListener:SetHandler("OnEvent", chatCommandListener.OnEvent)
chatCommandListener:RegisterEvent("CHAT_MESSAGE")
chatCommandListener:RegisterEvent("CHAT_FAILED")

local inventoryFallbackRefreshElapsed = 0
function runtime.window:OnUpdate(dt)
	-- Handles the OnUpdate event for the tracker window. Performs periodic tasks such as inventory fallback refresh, picker search polling when open, and updating rows/picker when runtime.refreshRequested flag is set.
	if not runtime.active then
		return
	end
	if runtime.gameLoadingStarted then
		return
	end

	local delta = NormalizeDt(dt)
	inventoryFallbackRefreshElapsed = inventoryFallbackRefreshElapsed + delta
	if runtime.inventoryRefreshPending then
		runtime.inventoryRefreshPendingElapsed = runtime.inventoryRefreshPendingElapsed + delta
		if runtime.inventoryRefreshPendingElapsed >= CONFIG.INVENTORY_EVENT_DEBOUNCE_SECONDS
			or runtime.inventoryRefreshPendingElapsed >= CONFIG.INVENTORY_EVENT_MAX_DEFER_SECONDS
		then
			runtime.inventoryRefreshPending = false
			runtime.inventoryRefreshPendingElapsed = 0
			runtime.refreshRequested = true
		end
	end
	if runtime.isPickerOpen and not runtime.IsPickerWindowVisible() then
		runtime.ClosePicker()
	end
	if runtime.isPickerOpen then
		runtime.pickerSearchPollElapsed = runtime.pickerSearchPollElapsed + delta
		if runtime.pickerSearchPollElapsed >= CONFIG.SEARCH_POLL_INTERVAL then
			runtime.pickerSearchPollElapsed = 0
			runtime.PollPickerSearchBox()
		end
	end

	if (runtime.IsTrackerWindowVisible() or runtime.IsPickerWindowVisible())
		and inventoryFallbackRefreshElapsed >= CONFIG.INVENTORY_FALLBACK_REFRESH_SECONDS
	then
		inventoryFallbackRefreshElapsed = 0
		runtime.MarkInventoryDirty(true)
	end

	runtime:UpdateAcquisitionGlows(delta)
	runtime:UpdateTrackedDropRates(delta)
	runtime:UpdateTrackedSessionAcquiredCounts(delta)

	if runtime.refreshRequested then
		runtime.refreshRequested = false
		runtime.UpdateRows()
		if runtime.isPickerOpen and runtime.UpdatePicker ~= nil then
			runtime.UpdatePicker()
		end
	end
end
runtime.window:SetHandler("OnUpdate", runtime.window.OnUpdate)

runtime.UpdateRows()

