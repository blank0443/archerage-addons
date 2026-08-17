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

function runtime.GetTrackedDropRateKey(tracked)
	if type(tracked) ~= "table" then
		return nil
	end
	return tracked.key or BuildItemKey(tracked.name, tracked.grade, tracked.iconPath) or NormalizeName(tracked.name)
end

function runtime.NormalizeTrackedDropCount(count)
	count = math.floor((tonumber(count) or 1) + 0.5)
	if count < 1 then
		return 1
	end
	return count
end

function runtime.GetCurrentSessionKillTotal()
	-- Reads the kill counter runtime directly so rates update even when the counter window is closed.
	local analysis = _G.__LOOT_KILL_COUNTER_ANALYSIS
	if type(analysis) == "table" and type(analysis.GetSessionKillTotal) == "function" then
		local ok, value = pcall(analysis.GetSessionKillTotal)
		value = ok and tonumber(value) or nil
		if value ~= nil then
			return math.floor(value)
		end
	end

	local counterRuntime = _G.__LOOT_KILL_COUNTER_RUNTIME
	if type(counterRuntime) ~= "table" or type(counterRuntime.sessionKillCounts) ~= "table" then
		return nil
	end

	local total = 0
	for _, count in pairs(counterRuntime.sessionKillCounts) do
		count = tonumber(count)
		if count ~= nil and count > 0 then
			total = total + math.floor(count)
		end
	end
	return total
end

function runtime.HasTrackedDropRateStats()
	for _, stats in pairs(runtime.trackedDropRatesByKey or {}) do
		if type(stats) == "table" and (tonumber(stats.drops) or 0) > 0 then
			return true
		end
	end
	return false
end

function runtime.HasTrackedSessionAcquiredStats()
	for _, count in pairs(runtime.trackedSessionAcquiredByKey or {}) do
		if (tonumber(count) or 0) > 0 then
			return true
		end
	end
	return false
end

function runtime:ClearTrackedDropRates()
	self.trackedDropRatesByKey = {}
	self.dropRateSessionKillStart = nil
	self.dropRateIdleElapsed = 0
	self.dropRateLastLootActivityAt = nil
	self.dropRateLastRefreshKillTotal = nil
	local currentKills = runtime.GetCurrentSessionKillTotal()
	if currentKills ~= nil then
		self.dropRateLastObservedKillTotal = currentKills
	end
	for _, row in pairs(rowWidgets) do
		runtime.SetRowDropRateText(row, nil)
	end
end

function runtime:ClearTrackedSessionAcquiredCounts()
	self.trackedSessionAcquiredByKey = {}
	self.sessionAcquiredIdleElapsed = 0
	self.sessionAcquiredLastActivityAt = nil
	self:RefreshTrackedSessionAcquiredLabels()
end

function runtime:MarkSessionAcquiredActivity()
	self.sessionAcquiredIdleElapsed = 0
	local now = CurrentClock()
	if now > 0 then
		self.sessionAcquiredLastActivityAt = now
	end
end

function runtime:GetTrackedSessionAcquiredText(tracked)
	if tracked == nil then
		return nil
	end
	local key = runtime.GetTrackedDropRateKey(tracked)
	local count = key ~= nil and tonumber(self.trackedSessionAcquiredByKey[key]) or nil
	return "x" .. tostring(math.floor(count or 0))
end

function runtime:RefreshTrackedSessionAcquiredLabels()
	for index = 1, runtime.trackedSlotCount do
		runtime.SetRowSessionAcquiredText(rowWidgets[index], self:GetTrackedSessionAcquiredText(trackedItems[index]))
	end
end

function runtime:RecordTrackedSessionAcquisition(tracked, count)
	-- Inventory gains are source-agnostic here, so purchases and loot both increase the session count.
	local key = runtime.GetTrackedDropRateKey(tracked)
	if key == nil or key == "" then
		return false
	end
	count = runtime.NormalizeTrackedDropCount(count)
	self.trackedSessionAcquiredByKey[key] = (tonumber(self.trackedSessionAcquiredByKey[key]) or 0) + count
	self:MarkSessionAcquiredActivity()
	self:RefreshTrackedSessionAcquiredLabels()
	return true
end

function runtime:UpdateTrackedSessionAcquiredCounts(delta)
	if not runtime.HasTrackedSessionAcquiredStats() then
		return
	end

	local safeDelta = tonumber(delta) or 0
	if safeDelta < 0 then
		safeDelta = 0
	elseif safeDelta > 1 then
		safeDelta = 1
	end
	self.sessionAcquiredIdleElapsed = (tonumber(self.sessionAcquiredIdleElapsed) or 0) + safeDelta

	local now = CurrentClock()
	local lastActivityAt = tonumber(self.sessionAcquiredLastActivityAt)
	if lastActivityAt ~= nil and now > 0 then
		if now - lastActivityAt >= CONFIG.TRACKED_DROP_RATE_IDLE_RESET_SECONDS then
			self:ClearTrackedSessionAcquiredCounts()
		end
	elseif self.sessionAcquiredIdleElapsed >= CONFIG.TRACKED_DROP_RATE_IDLE_RESET_SECONDS then
		self:ClearTrackedSessionAcquiredCounts()
	end
end

function runtime:ObserveDropRateKillTotal()
	-- The first observed kill after a reset becomes the denominator boundary for this farming burst.
	local currentKills = runtime.GetCurrentSessionKillTotal()
	if currentKills == nil then
		return nil, nil
	end

	local previousKills = tonumber(self.dropRateLastObservedKillTotal)
	if previousKills ~= nil and currentKills < previousKills then
		self:ClearTrackedDropRates()
		self:ClearTrackedSessionAcquiredCounts()
		previousKills = tonumber(self.dropRateLastObservedKillTotal)
	end
	if previousKills ~= nil and currentKills > previousKills and self.dropRateSessionKillStart == nil then
		self.dropRateSessionKillStart = previousKills
	end
	self.dropRateLastObservedKillTotal = currentKills
	return currentKills, previousKills
end

function runtime:EnsureDropRateSessionStart(currentKills, previousKills)
	currentKills = tonumber(currentKills)
	if currentKills == nil then
		return nil
	end
	if self.dropRateSessionKillStart == nil then
		previousKills = tonumber(previousKills)
		if previousKills ~= nil and previousKills <= currentKills then
			self.dropRateSessionKillStart = previousKills
		else
			self.dropRateSessionKillStart = math.max(0, currentKills - 1)
		end
	end
	return self.dropRateSessionKillStart
end

function runtime:GetDropRateSessionKillCount(currentKills)
	currentKills = tonumber(currentKills)
	if currentKills == nil then
		currentKills = self:ObserveDropRateKillTotal()
	end
	local startKills = tonumber(self.dropRateSessionKillStart)
	if currentKills == nil or startKills == nil then
		return nil
	end

	local kills = currentKills - startKills
	if kills < 1 then
		kills = 1
	end
	return math.floor(kills)
end

function runtime:MarkDropRateLootActivity()
	self.dropRateIdleElapsed = 0
	self.lootActivityFresh = true
	local now = CurrentClock()
	if now > 0 then
		self.dropRateLastLootActivityAt = now
	end
end

function runtime:HasFreshLootActivity()
	if self.lootActivityFresh then
		return true
	end
	local lastLootActivityAt = tonumber(self.dropRateLastLootActivityAt)
	local now = CurrentClock()
	if lastLootActivityAt == nil or now <= 0 then
		return false
	end
	return (now - lastLootActivityAt) <= CONFIG.LOOT_ACTIVITY_FRESH_SECONDS
end

function runtime:FormatTrackedDropRatePercent(percent)
	percent = tonumber(percent)
	if percent == nil or percent < 0 then
		return nil
	end

	local roundedInteger = math.floor(percent + 0.5)
	if math.abs(percent - roundedInteger) < 0.05 or percent >= 10 then
		return tostring(roundedInteger) .. "%"
	end
	if percent >= 1 then
		return string.format("%.1f%%", percent)
	end
	return string.format("%.2f%%", percent)
end

function runtime:GetTrackedDropRateText(tracked, currentKills)
	local key = runtime.GetTrackedDropRateKey(tracked)
	local stats = key ~= nil and self.trackedDropRatesByKey[key] or nil
	if type(stats) ~= "table" or (tonumber(stats.drops) or 0) <= 0 then
		return nil
	end

	local kills = self:GetDropRateSessionKillCount(currentKills)
	if kills == nil or kills <= 0 then
		kills = tonumber(stats.sampleKills)
	end
	if kills == nil or kills <= 0 then
		return nil
	end

	return self:FormatTrackedDropRatePercent(((tonumber(stats.drops) or 0) / kills) * 100)
end

function runtime:RefreshTrackedDropRateLabels(currentKills)
	if currentKills == nil then
		currentKills = self:ObserveDropRateKillTotal()
	end
	self.dropRateLastRefreshKillTotal = currentKills
	for index = 1, runtime.trackedSlotCount do
		runtime.SetRowDropRateText(rowWidgets[index], self:GetTrackedDropRateText(trackedItems[index], currentKills))
	end
end

function runtime:RecordTrackedItemDrop(tracked, count)
	-- A tracked inventory increase may be a stack gain, so store gained item count against the active kill span.
	local key = runtime.GetTrackedDropRateKey(tracked)
	if key == nil or key == "" then
		return false
	end

	local currentKills, previousKills = self:ObserveDropRateKillTotal()
	if currentKills == nil or currentKills <= 0 then
		return false
	end
	self:EnsureDropRateSessionStart(currentKills, previousKills)
	local sampleKills = self:GetDropRateSessionKillCount(currentKills)
	if sampleKills == nil or sampleKills <= 0 then
		return false
	end

	local stats = self.trackedDropRatesByKey[key]
	if type(stats) ~= "table" then
		stats = {
			drops = 0,
			sampleKills = sampleKills,
		}
		self.trackedDropRatesByKey[key] = stats
	end
	stats.drops = (tonumber(stats.drops) or 0) + runtime.NormalizeTrackedDropCount(count)
	stats.sampleKills = sampleKills
	self:MarkDropRateLootActivity()
	self:RefreshTrackedDropRateLabels(currentKills)
	return true
end

function runtime:UpdateTrackedDropRates(delta)
	-- Recalculates existing labels as kill totals rise and clears them after loot activity goes idle.
	local currentKills = self:ObserveDropRateKillTotal()
	if not runtime.HasTrackedDropRateStats() then
		return
	end

	local safeDelta = tonumber(delta) or 0
	if safeDelta < 0 then
		safeDelta = 0
	elseif safeDelta > 1 then
		safeDelta = 1
	end
	self.dropRateIdleElapsed = (tonumber(self.dropRateIdleElapsed) or 0) + safeDelta

	local now = CurrentClock()
	local lastLootActivityAt = tonumber(self.dropRateLastLootActivityAt)
	if lastLootActivityAt ~= nil and now > 0 then
		if now - lastLootActivityAt >= CONFIG.TRACKED_DROP_RATE_IDLE_RESET_SECONDS then
			self:ClearTrackedDropRates()
			return
		end
	elseif self.dropRateIdleElapsed >= CONFIG.TRACKED_DROP_RATE_IDLE_RESET_SECONDS then
		self:ClearTrackedDropRates()
		return
	end

	-- Only redraw when the kill denominator changes; RecordTrackedItemDrop refreshes immediately on loot.
	if currentKills ~= self.dropRateLastRefreshKillTotal then
		self:RefreshTrackedDropRateLabels(currentKills)
	end
end


