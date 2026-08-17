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

function runtime.ReadInventory()
	if runtime.gameLoadingStarted then
		return runtime.inventoryItemsByKey or {}, runtime.inventoryOrderedItems or {}, runtime.inventoryItemsByName or {}
	end
	local itemsByKey = {}
	local orderedItems = {}
	local itemsByName = {}

	for posInBag = 1, CONFIG.MAX_BAG_SLOTS do
		local item = ReadBagItem(posInBag)
		local name = ExtractItemName(item)
		if name ~= nil and tostring(name) ~= "" then
			local grade = ExtractItemGrade(item)
			local normalizedName = NormalizeName(name)
			local iconCacheKey = ExtractItemIconCacheKey(item)
			local iconPath = nil
			if iconCacheKey ~= nil then
				iconPath = inventoryIconPathCache[iconCacheKey]
			end
			if iconPath == nil then
				iconPath = ExtractItemIconPath(item)
				if iconPath ~= nil and iconCacheKey ~= nil then
					inventoryIconPathCache[iconCacheKey] = iconPath
				end
			end
			local key = BuildItemKey(name, grade, iconPath) or NormalizeName(name)
			local count = ExtractItemCount(item)
			local entry = itemsByKey[key]

			if entry == nil then
				entry = {
					key = key,
					name = tostring(name),
					grade = grade,
					iconPath = iconPath,
					count = 0,
					firstPos = posInBag,
				}
				itemsByKey[key] = entry
				orderedItems[#orderedItems + 1] = entry
				if normalizedName ~= "" then
					local existing = itemsByName[normalizedName]
					if existing == nil then
						itemsByName[normalizedName] = entry
					elseif existing.key ~= nil then
						itemsByName[normalizedName] = { existing, entry }
					else
						existing[#existing + 1] = entry
					end
				end
			elseif entry.iconPath == nil and iconPath ~= nil then
	-- Marks inventory as dirty and requests refresh.
				entry.iconPath = iconPath
			end

			entry.count = entry.count + count
	-- Returns cached inventory snapshot or refreshes if dirty or forced.
		end
	end

	return itemsByKey, orderedItems, itemsByName
end

function runtime.MarkInventoryDirty(immediate)
	runtime.inventoryDirty = true
	runtime.pickerCachedInventoryVersion = -1
	if immediate == false then
		-- First-event-wins: keep elapsed so continuous bag spam still flushes after debounce.
		if not runtime.inventoryRefreshPending then
			runtime.inventoryRefreshPending = true
			runtime.inventoryRefreshPendingElapsed = 0
		end
	else
		runtime.inventoryRefreshPending = false
		runtime.inventoryRefreshPendingElapsed = 0
		runtime.refreshRequested = true
	end
end

function runtime.GetInventorySnapshot(forceRefresh)
	if runtime.gameLoadingStarted then
		return runtime.inventoryItemsByKey or {}, runtime.inventoryOrderedItems or {}, runtime.inventoryItemsByName or {}
	end
	if forceRefresh or runtime.inventoryDirty or runtime.inventoryItemsByKey == nil or runtime.inventoryOrderedItems == nil then
		runtime.inventoryItemsByKey, runtime.inventoryOrderedItems, runtime.inventoryItemsByName = runtime.ReadInventory()
		runtime.inventoryVersion = runtime.inventoryVersion + 1
		runtime.inventoryDirty = false
	end
	return runtime.inventoryItemsByKey, runtime.inventoryOrderedItems, runtime.inventoryItemsByName
end

function runtime.ResolveTrackedInventoryEntry(itemsByKey, tracked, itemsByName)
	-- Resolves a tracked item to its current inventory entry by key or by name/grade/icon fallback match.
	if itemsByKey == nil or tracked == nil then
		return nil
	end

	local current = itemsByKey[tracked.key]
	if current ~= nil then
		return current
	end

	local trackedName = NormalizeName(tracked.name)
	if trackedName == "" then
		return nil
	end

	local candidates = nil
	if itemsByName ~= nil then
		candidates = itemsByName[trackedName]
	end
	-- Missing name means the item is not in inventory; avoid scanning the full bag map.
	if candidates == nil then
		return nil
	end
	if candidates.key ~= nil then
		candidates = { candidates }
	end

	for _, item in pairs(candidates) do
		if NormalizeName(item.name) == trackedName then
			local gradeMatches = tracked.grade == nil or item.grade == tracked.grade
			local iconMatches = tracked.iconPath == nil or item.iconPath == nil or item.iconPath == tracked.iconPath
			if gradeMatches and iconMatches then
				if item.key ~= nil then
					tracked.key = item.key
				end
				if tracked.iconPath == nil and item.iconPath ~= nil then
					tracked.iconPath = item.iconPath
				end
				return item
			end
		end
	end

	return nil
end

