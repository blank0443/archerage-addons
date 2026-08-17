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

function runtime.SaveTrackedItems()
	local data = {}
	for index = 1, runtime.trackedSlotCount do
		local item = trackedItems[index]
		if item ~= nil then
			data[index] = {
				key = item.key,
				name = item.name,
				grade = item.grade,
				iconPath = item.iconPath,
			}
		end
	end

	pcall(function()
		ADDON:ClearData(CONFIG.SAVE_KEY)
		ADDON:SaveData(CONFIG.SAVE_KEY, data)
	end)
end

function runtime.LoadTrackedItems()
	local ok, data = pcall(function()
		return ADDON:LoadData(CONFIG.SAVE_KEY)
	end)
	if not ok or type(data) ~= "table" then
		return
	end

	for index = 1, runtime.trackedSlotCount do
		local item = data[index] or data[tostring(index)]
		if type(item) == "table" and item.name ~= nil then
			local itemName = tostring(item.name)
			local itemGrade = item.grade
			local itemIconPath = item.iconPath
			trackedItems[index] = {
				key = item.key or BuildItemKey(itemName, itemGrade, itemIconPath) or NormalizeName(itemName),
				name = itemName,
				grade = itemGrade,
				iconPath = itemIconPath,
			}
		elseif type(item) == "string" and item ~= "" then
			trackedItems[index] = {
				key = NormalizeName(item),
				name = item,
				grade = nil,
			}
		end
	end
end

function runtime.SaveWindowPosition(window)
	local x, y = GetWidgetSavedPosition(window)
	if x ~= nil and y ~= nil then
		-- Keep a pre-loading snapshot; GetOffset during ENTERED_LOADING is unreliable.
		runtime.lastKnownTrackerX = x
		runtime.lastKnownTrackerY = y
	end
	SaveWidgetPosition(window, CONFIG.POSITION_KEY)
end

function runtime.SaveRestoreButtonPosition(button)
	local x, y = GetWidgetSavedPosition(button)
	if x ~= nil and y ~= nil then
		runtime.lastKnownRestoreX = x
		runtime.lastKnownRestoreY = y
	end
	SaveWidgetPosition(button, CONFIG.RESTORE_POSITION_KEY)
	runtime.restoreButtonPositionSaved = true
end

function runtime.SavePickerWindowPosition(window)
	SaveWidgetPosition(window, CONFIG.PICKER_POSITION_KEY)
	runtime.pickerWindowPositionSaved = true
end

function runtime.LoadWindowPosition()
	return LoadSavedPosition(CONFIG.POSITION_KEY, 420, 320)
end

function runtime.LoadRestoreButtonPosition(defaultX, defaultY)
	return LoadSavedPosition(CONFIG.RESTORE_POSITION_KEY, defaultX, defaultY)
end

function runtime.LoadPickerWindowPosition(defaultX, defaultY)
	return LoadSavedPosition(CONFIG.PICKER_POSITION_KEY, defaultX, defaultY)
end

function runtime.NormalizeTrackerLayout(value)
	if value == CONFIG.LAYOUT_VERTICAL then
		return CONFIG.LAYOUT_VERTICAL
	end
	return CONFIG.LAYOUT_HORIZONTAL
end

function runtime.SaveTrackerLayout()
	pcall(function()
		ADDON:ClearData(CONFIG.LAYOUT_KEY)
		ADDON:SaveData(CONFIG.LAYOUT_KEY, {
			layout = runtime.trackerLayout,
		})
	end)
end

function runtime.LoadTrackerLayout()
	local ok, data = pcall(function()
		return ADDON:LoadData(CONFIG.LAYOUT_KEY)
	end)
	if ok then
		if type(data) == "table" then
			return runtime.NormalizeTrackerLayout(data.layout)
		end
		if type(data) == "string" then
			return runtime.NormalizeTrackerLayout(data)
		end
	end
	return CONFIG.LAYOUT_HORIZONTAL
end

function runtime:SaveMenuMode()
	pcall(function()
		ADDON:ClearData(CONFIG.MENU_MODE_KEY)
		ADDON:SaveData(CONFIG.MENU_MODE_KEY, {
			enabled = self.menuMode == true,
		})
	end)
end

function runtime:LoadMenuMode()
	local ok, data = pcall(function()
		return ADDON:LoadData(CONFIG.MENU_MODE_KEY)
	end)
	if not ok then
		return
	end

	if type(data) == "table" then
		self.menuMode = data.enabled == true
	elseif type(data) == "boolean" then
		self.menuMode = data == true
	end
end

function runtime:SaveSlotCount()
	pcall(function()
		ADDON:ClearData("lootTrackerSlotCount")
		ADDON:SaveData("lootTrackerSlotCount", {
			count = runtime.trackedSlotCount,
		})
	end)
end

function runtime:LoadSlotCount()
	local ok, data = pcall(function()
		return ADDON:LoadData("lootTrackerSlotCount")
	end)
	if not ok then
		return
	end

	local count = data
	if type(data) == "table" then
		count = data.count
	end
	count = math.floor(tonumber(count) or runtime.trackedSlotCount)
	if count < 1 then
		count = 1
	elseif count > 20 then
		count = 20
	end
	runtime.trackedSlotCount = count
end

function runtime:SaveWindowScale()
	pcall(function()
		ADDON:ClearData("lootTrackerWindowScale")
		ADDON:SaveData("lootTrackerWindowScale", {
			scale = self:ClampScale(self.trackerScale),
		})
	end)
end

function runtime:LoadWindowScale()
	local ok, data = pcall(function()
		return ADDON:LoadData("lootTrackerWindowScale")
	end)
	if not ok then
		return
	end

	local scale = data
	if type(data) == "table" then
		scale = data.scale
	end
	self.trackerScale = self:ClampScale(scale)
end

function runtime:SaveActiveSetName()
	local name = self.selectedSetName
	if type(name) == "string" then
		name = Trim(name)
		if name == "" then
			name = nil
		end
	else
		name = nil
	end

	pcall(function()
		ADDON:ClearData(CONFIG.ACTIVE_SET_KEY)
		if name ~= nil then
			ADDON:SaveData(CONFIG.ACTIVE_SET_KEY, {
				name = name,
			})
		end
	end)
end

-- Restores last applied/saved set identity; independent of current slot contents.
function runtime:LoadActiveSetName()
	local ok, data = pcall(function()
		return ADDON:LoadData(CONFIG.ACTIVE_SET_KEY)
	end)
	local savedName = nil
	if ok then
		if type(data) == "table" then
			savedName = Trim(data.name)
		elseif type(data) == "string" then
			savedName = Trim(data)
		end
	end
	if savedName == nil or savedName == "" then
		self.selectedSetName = nil
		return
	end

	local resolved = savedName
	if self.trackedItemSets[resolved] == nil then
		resolved = nil
		local lookupName = string.lower(savedName)
		for setName, setData in pairs(self.trackedItemSets or {}) do
			if string.lower(Trim(setName)) == lookupName then
				resolved = setName
				break
			end
			if type(setData) == "table" and string.lower(Trim(setData.name or setData.displayName)) == lookupName then
				resolved = setName
				break
			end
		end
	end

	-- Drop stale identity when the saved set no longer exists.
	if resolved == nil or self.trackedItemSets[resolved] == nil then
		self.selectedSetName = nil
		self:SaveActiveSetName()
		return
	end
	self.selectedSetName = resolved
end

function runtime:SetActiveTrackedSetName(setName)
	local name = Trim(setName)
	if name == "" then
		name = nil
	elseif self.trackedItemSets[name] == nil then
		name = nil
	end
	if self.selectedSetName == name then
		return
	end
	self.selectedSetName = name
	self:SaveActiveSetName()
end

function runtime:LoadTrackedItemSets()
	self.trackedItemSets = {}
	self.trackedItemSetsLoaded = true
	local ok, data = pcall(function()
		return ADDON:LoadData(CONFIG.SETS_KEY)
	end)
	if not ok or type(data) ~= "table" then
		self:LoadActiveSetName()
		return
	end

	local loadedCount = 0
	for setName, setData in pairs(data) do
		if loadedCount >= CONFIG.MAX_TRACKED_SET_COUNT then
			break
		end
		local normalizedName = Trim(setName)
		if normalizedName ~= "" and type(setData) == "table" then
			local displayName = Trim(setData.name or setData.displayName or setName)
			if displayName == "" then
				displayName = normalizedName
			end
			local itemsSource = setData.items
			if type(itemsSource) ~= "table" then
				itemsSource = setData
			end

			local slotCount = math.floor(tonumber(setData.slotCount or setData.count) or runtime.trackedSlotCount)
			if slotCount < 1 then
				slotCount = 1
			elseif slotCount > 20 then
				slotCount = 20
			end

			local normalizedSet = {
				name = displayName,
				slotCount = slotCount,
				items = {},
			}
			for index = 1, slotCount do
				local item = itemsSource[index] or itemsSource[tostring(index)]
				local copied = self:CopyTrackedItem(item)
				if copied ~= nil then
					normalizedSet.items[index] = copied
				end
			end
			self.trackedItemSets[normalizedName] = normalizedSet
			loadedCount = loadedCount + 1
		end
	end
	self:LoadActiveSetName()
end

function runtime:EnsureTrackedItemSetsLoaded()
	if self.trackedItemSetsLoaded ~= true then
		self:LoadTrackedItemSets()
	end
end

function runtime:GetTrackedSetCount()
	self:EnsureTrackedItemSetsLoaded()
	local count = 0
	for _, _ in pairs(self.trackedItemSets or {}) do
		count = count + 1
	end
	return count
end

function runtime:SaveTrackedItemSets()
	self:EnsureTrackedItemSetsLoaded()
	local ok = pcall(function()
		ADDON:ClearData(CONFIG.SETS_KEY)
		ADDON:SaveData(CONFIG.SETS_KEY, self.trackedItemSets)
	end)
	return ok
end

