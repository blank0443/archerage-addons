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

local previousRuntime = _G.__LOOT_TRACKER_RUNTIME
if previousRuntime ~= nil then
	previousRuntime.active = false
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
	if previousRuntime.controlsRestoreButton ~= nil then
		previousRuntime.controlsRestoreButton:Show(false)
	end
	if previousRuntime.lootRateTooltip ~= nil then
		previousRuntime.lootRateTooltip:Show(false)
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
	acquisitionGlowActive = false,
	acquisitionGlowRows = {},
	acquisitionGlowBatchStartedAt = nil,
}
_G.__LOOT_TRACKER_RUNTIME = runtime

local TRACKED_SLOT_COUNT = 5
local CONFIG = {
	BAG_KIND = 1,
	MAX_BAG_SLOTS = 150,
	SAVE_KEY = "lootTrackerTrackedItems",
	POSITION_KEY = "lootTrackerWindowPosition",
	RESTORE_POSITION_KEY = "lootTrackerRestoreButtonPosition",
	PICKER_POSITION_KEY = "lootTrackerPickerWindowPosition",
	SET_WINDOW_POSITION_KEY = "lootTrackerSetWindowPosition",
	LAYOUT_KEY = "lootTrackerLayout",
	MENU_MODE_KEY = "lootTrackerEscMenuMode",
	SETS_KEY = "lootTrackerTrackedItemSets",
	DROP_RATE_KEY = "drop_rate_mul",

	LAYOUT_HORIZONTAL = "horizontal",
	LAYOUT_VERTICAL = "vertical",
	ESC_MENU_CATEGORY_ID = 3,
	ESC_MENU_CONTENT_ID = 1552,
	ESC_MENU_ICON_KEY = "bag",
	ESC_MENU_BUTTON_NAME = "Loot Tracker",
	RESTORE_BUTTON_WIDTH = 92,
	RESTORE_BUTTON_HEIGHT = 22,
	PADDING = 9,
	TRACKER_PADDING = 4,
	TRACKER_TOP_PADDING = 1,
	HEADER_HEIGHT = 22,
	HEADER_TITLE_WIDTH = 78,
	HEADER_BUTTON_GAP = 4,
	HEADER_BUTTON_HEIGHT = 18,
	ROTATE_BUTTON_WIDTH = 24,
	RESET_BUTTON_WIDTH = 24,
	MENU_BUTTON_WIDTH = 34,
	HIDE_WINDOW_BUTTON_WIDTH = 34,
	SET_BUTTON_WIDTH = 24,
	LOOT_RATE_MARKER_WIDTH = 48,
	LOOT_RATE_MARKER_HEIGHT = 18,
	LOOT_RATE_TEXT_COLOR = { 0.28, 1.0, 0.36, 1 },
	BOX_SIZE = 40,
	BOX_GAP = 6,
	TRACKER_ROW_TOP_GAP = 3,
	ACQUISITION_GLOW_SECONDS = 40.0,
	ACQUISITION_GLOW_BATCH_SECONDS = 2.0,
	ACQUISITION_GLOW_MAX_ALPHA = 0.8,
	ACQUISITION_GLOW_BORDER_SIZE = 3,
	ACQUISITION_GLOW_COLOR = { 1.0, 0.41, 0.71 },
	ACQUISITION_GLOW_INNER_COLOR = { 0.72, 0.48, 0.95 },
	ACQUISITION_GLOW_INNER_GRADIENT_STEPS = 4,
	ACQUISITION_GLOW_INNER_STEP_SIZE = 2.35,
	ACQUISITION_GLOW_INNER_MAX_ALPHA = 0.5,

	PICKER_WIDTH = 330,
	PICKER_HEIGHT = 328,
	PICKER_COLUMNS = 3,
	PICKER_ROWS = 5,
	PICKER_ITEM_WIDTH = 96,
	PICKER_ITEM_HEIGHT = 34,
	PICKER_ITEM_GAP_X = 6,
	PICKER_ITEM_GAP_Y = 6,
	PICKER_SEARCH_TOP = 42,
	PICKER_SEARCH_HEIGHT = 30,
	PICKER_GRID_TOP = 84,
	SET_WINDOW_WIDTH = 200,
	SET_WINDOW_MIN_HEIGHT = 132,
	SET_ROW_TOP = 104,
	SET_ROW_HEIGHT = 26,
	SET_ROW_GAP = 4,
	SET_WINDOW_PADDING = 10,
	SET_ACTION_BUTTON_HEIGHT = 22,
	SET_SAVE_BUTTON_WIDTH = 44,
	SET_OVERWRITE_BUTTON_WIDTH = 88,
	SET_DELETE_BUTTON_WIDTH = 36,
	SET_STATUS_OUTSIDE_GAP = 4,
	SET_NAME_CHAR_WIDTH = 7,
	SET_NAME_TEXT_MAX_WIDTH = 136,
	MAX_TRACKED_SET_COUNT = 40,
	SET_VISIBLE_ROWS = 10,
	INVENTORY_FALLBACK_REFRESH_SECONDS = 10.0,
	INVENTORY_EVENT_DEBOUNCE_SECONDS = 0.15,
	RESIZE_UPDATE_INTERVAL = 0.05,
	RESIZE_SCALE_EPSILON = 0.01,
	SEARCH_POLL_INTERVAL = 0.12,
}
CONFIG.BOXES_TOP = CONFIG.TRACKER_TOP_PADDING + CONFIG.HEADER_HEIGHT + CONFIG.TRACKER_ROW_TOP_GAP
CONFIG.PICKER_VISIBLE_COUNT = CONFIG.PICKER_COLUMNS * CONFIG.PICKER_ROWS
CONFIG.PICKER_CONTROL_TOP = CONFIG.PICKER_GRID_TOP
	+ (CONFIG.PICKER_ROWS * (CONFIG.PICKER_ITEM_HEIGHT + CONFIG.PICKER_ITEM_GAP_Y))
CONFIG.SET_WINDOW_CONTENT_WIDTH = CONFIG.SET_WINDOW_WIDTH - (CONFIG.SET_WINDOW_PADDING * 2)

local trackedItems = {}
local rowWidgets = {}
local pickerItemWidgets = {}
local pickerItems = {}
local pickerSlotIndex = nil
local pickerScrollIndex = 1
local pickerSearchText = ""
local pickerLastObservedSearchText = ""
local pickerSearchPollElapsed = 0
local pickerSearchTextEventSuppressed = false
local pickerSearchCharHandlerActive = false
local isPickerOpen = false
local refreshRequested = true
local inventoryDirty = true
local inventoryItemsByKey = nil
local inventoryOrderedItems = nil
local inventoryItemsByName = nil
local inventoryVersion = 0
local inventoryRefreshPending = false
local inventoryRefreshPendingElapsed = 0
local pickerCachedSearchText = nil
local pickerCachedInventoryVersion = -1
local pickerCachedItems = nil
local inventoryIconPathCache = {}
local trackerLayout = CONFIG.LAYOUT_HORIZONTAL
local restoreButtonPositionSaved = false
local pickerWindowPositionSaved = false
local trackerHeaderControlsVisible = true
local trackerSlotRightDrag = {
	sourceIndex = nil,
	hoverIndex = nil,
}
local suppressRowRightClickUntil = 0
local UpdatePicker
local RecreatePickerSearchBox
local ApplyTrackerLayout
local AnchorPickerWindow
local SetTrackerHeaderControlsVisible
local trackerWindow

local function SafeMethod(target, methodName, ...)
	if target == nil then
		return false
	end
	local fn = target[methodName]
	if type(fn) ~= "function" then
		return false
	end
	return pcall(fn, target, ...)
end

local function IsRightMouseButton(mouseButton)
	local buttonText = tostring(mouseButton or "")
	return buttonText == "RightButton" or buttonText == "right" or buttonText == "RIGHT" or buttonText == "2"
end

local function NormalizeDt(dt)
	local value = tonumber(dt) or 0
	if value > 10 then
		value = value / 1000
	end
	return value
end

local function Trim(value)
	local text = tostring(value or "")
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	return text
end

local function NormalizeName(value)
	local text = string.lower(Trim(value))
	text = string.gsub(text, "%s+", " ")
	return text
end

local function CurrentClock()
	if os ~= nil and type(os.clock) == "function" then
		local ok, value = pcall(os.clock)
		if ok and value ~= nil then
			return tonumber(value) or 0
		end
	end
	return 0
end

local function ExtractItemName(item)
	if type(item) ~= "table" then
		return nil
	end
	return item.name or item.itemName or item.item_name
end

local function ExtractItemGrade(item)
	if type(item) ~= "table" then
		return nil
	end
	return item.grade or item.itemGrade or item.item_grade
end

local ITEM_ID_FIELD_NAMES = {
	"itemType",
	"item_type",
	"itemTypeId",
	"item_type_id",
	"itemId",
	"item_id",
	"id",
	"type",
}

local function ExtractItemIconCacheKey(item)
	if type(item) ~= "table" then
		return nil
	end

	for _, fieldName in ipairs(ITEM_ID_FIELD_NAMES) do
		local value = item[fieldName]
		if type(value) == "string" or type(value) == "number" then
			local text = Trim(value)
			if text ~= "" then
				return text
			end
		end
	end
	return nil
end

local ICON_FIELD_NAMES = {
	"iconPath",
	"icon_path",
	"itemIconPath",
	"item_icon_path",
	"iconFilePath",
	"icon_file_path",
	"texturePath",
	"texture_path",
	"itemTexturePath",
	"item_texture_path",
	"icon",
	"itemIcon",
	"item_icon",
	"iconFile",
	"icon_file",
	"iconTexture",
	"icon_texture",
	"texture",
	"itemTexture",
	"item_texture",
	"path",
	"image",
	"imagePath",
	"image_path",
}

local function ExtractIconPathValue(value, depth)
	if value == nil then
		return nil
	end

	if type(value) == "string" then
		local text = Trim(value)
		if text ~= "" then
			return text
		end
		return nil
	end

	if type(value) ~= "table" or (depth or 0) > 2 then
		return nil
	end

	for _, fieldName in ipairs(ICON_FIELD_NAMES) do
		local nested = ExtractIconPathValue(value[fieldName], (depth or 0) + 1)
		if nested ~= nil then
			return nested
	-- Extracts icon path from item by calling ExtractIconPathValue.
		end
	end

	return nil
end

	-- Extracts item count from table by trying common count field names, defaults to 1.
local function ExtractItemIconPath(item)
	if type(item) ~= "table" then
		return nil
	end

	for _, fieldName in ipairs(ICON_FIELD_NAMES) do
		local value = item[fieldName]
		if type(value) == "string" then
			local text = Trim(value)
			if text ~= "" then
				return text
			end
		end
	end

	return ExtractIconPathValue(item, 0)
end

local function ExtractItemCount(item)
	if type(item) ~= "table" then
		return 1
	end

	local countFields = {
		"stackCount",
		"stack_count",
		"itemCount",
		"item_count",
		"quantity",
		"amount",
		"count",
		"stack",
	}

	for _, fieldName in ipairs(countFields) do
		local value = tonumber(item[fieldName])
		if value ~= nil and value > 0 then
	-- Builds a unique key for an item from normalized name, grade and iconPath.
			return value
		end
	end

	return 1
end

local function BuildItemKey(name, grade, iconPath)
	-- Safely reads bag item info using pcall for a position in bag.
	local normalizedName = NormalizeName(name)
	if normalizedName == "" then
		return nil
	end

	return normalizedName .. "|" .. tostring(grade or "") .. "|" .. tostring(iconPath or "")
end

local function ReadBagItem(posInBag)
	local ok, item = pcall(function()
		return X2Bag:GetBagItemInfo(CONFIG.BAG_KIND, posInBag)
	end)
	if ok then
		return item
	end
	return nil
end

local function ReadInventory()
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

local function MarkInventoryDirty(immediate)
	inventoryDirty = true
	pickerCachedInventoryVersion = -1
	if immediate == false then
		inventoryRefreshPending = true
		inventoryRefreshPendingElapsed = 0
	else
		inventoryRefreshPending = false
		inventoryRefreshPendingElapsed = 0
		refreshRequested = true
	end
end

local function GetInventorySnapshot(forceRefresh)
	if forceRefresh or inventoryDirty or inventoryItemsByKey == nil or inventoryOrderedItems == nil then
		inventoryItemsByKey, inventoryOrderedItems, inventoryItemsByName = ReadInventory()
		inventoryVersion = inventoryVersion + 1
		inventoryDirty = false
	end
	return inventoryItemsByKey, inventoryOrderedItems, inventoryItemsByName
end

local function ScoreSearchMatch(name, query)
	local normalizedName = NormalizeName(name)
	local normalizedQuery = NormalizeName(query)
	if normalizedQuery == "" then
		return nil
	end

	if normalizedName == normalizedQuery then
		return 100000
	end

	local foundAt = string.find(normalizedName, normalizedQuery, 1, true)
	if foundAt ~= nil then
		if foundAt == 1 then
			return 80000 - math.max(0, string.len(normalizedName) - string.len(normalizedQuery))
		end
		return 60000 - (foundAt * 100) - math.max(0, string.len(normalizedName) - string.len(normalizedQuery))
	end

	local queryIndex = 1
	local firstMatch = nil
	local lastMatch = nil
	for nameIndex = 1, string.len(normalizedName) do
		if string.sub(normalizedName, nameIndex, nameIndex) == string.sub(normalizedQuery, queryIndex, queryIndex) then
			if firstMatch == nil then
				firstMatch = nameIndex
			end
			lastMatch = nameIndex
			queryIndex = queryIndex + 1
			if queryIndex > string.len(normalizedQuery) then
				local span = lastMatch - firstMatch
				return 30000 - (span * 10) - math.max(0, string.len(normalizedName) - string.len(normalizedQuery))
			end
		end
	end

	return nil
end

local function BuildPickerItems(query)
	local _, orderedItems = GetInventorySnapshot(false)
	local normalizedQuery = NormalizeName(query)
	if pickerCachedInventoryVersion == inventoryVersion
		and pickerCachedSearchText == normalizedQuery
		and pickerCachedItems ~= nil
	then
		return pickerCachedItems
	end

	if normalizedQuery == "" then
		pickerCachedSearchText = normalizedQuery
		pickerCachedInventoryVersion = inventoryVersion
		pickerCachedItems = orderedItems
		return orderedItems
	end

	local matches = {}
	for _, item in ipairs(orderedItems) do
		local score = ScoreSearchMatch(item.name, query)
		if score ~= nil then
			matches[#matches + 1] = {
				key = item.key,
				name = item.name,
				grade = item.grade,
				iconPath = item.iconPath,
				count = item.count,
				firstPos = item.firstPos,
				score = score,
			}
		end
	end

	table.sort(matches, function(left, right)
		if left.score ~= right.score then
			return left.score > right.score
		end
		if left.firstPos ~= right.firstPos then
			return left.firstPos < right.firstPos
		end
		return left.name < right.name
	end)

	pickerCachedSearchText = normalizedQuery
	pickerCachedInventoryVersion = inventoryVersion
	pickerCachedItems = matches
	return matches
end

local function SaveTrackedItems()
	local data = {}
	for index = 1, TRACKED_SLOT_COUNT do
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

local function LoadTrackedItems()
	local ok, data = pcall(function()
		return ADDON:LoadData(CONFIG.SAVE_KEY)
	end)
	if not ok or type(data) ~= "table" then
		return
	end

	for index = 1, TRACKED_SLOT_COUNT do
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

local function GetWidgetSavedPosition(widget)
	if widget == nil then
		return nil, nil
	end

	local ok, offsetX, offsetY = pcall(function()
		return widget:GetOffset()
	end)
	if not ok or offsetX == nil or offsetY == nil then
		return nil, nil
	end

	return math.floor((offsetX or 0) + 0.5), math.floor((offsetY or 0) + 0.5)
end

local function SaveWidgetPosition(widget, key)
	if widget == nil or key == nil then
		return
	end

	local x, y = GetWidgetSavedPosition(widget)
	if x == nil or y == nil then
		return
	end

	pcall(function()
		ADDON:ClearData(key)
		ADDON:SaveData(key, {
			x = x,
			y = y,
			version = 2,
		})
	end)
end

local function LoadSavedPosition(key, defaultX, defaultY)
	local ok, data = pcall(function()
		return ADDON:LoadData(key)
	end)
	if ok and type(data) == "table" and data.x ~= nil and data.y ~= nil then
		return tonumber(data.x) or defaultX, tonumber(data.y) or defaultY, true
	end
	return defaultX, defaultY, false
end

local function SaveWindowPosition(window)
	SaveWidgetPosition(window, CONFIG.POSITION_KEY)
end

local function SaveRestoreButtonPosition(button)
	SaveWidgetPosition(button, CONFIG.RESTORE_POSITION_KEY)
	restoreButtonPositionSaved = true
end

local function SavePickerWindowPosition(window)
	SaveWidgetPosition(window, CONFIG.PICKER_POSITION_KEY)
	pickerWindowPositionSaved = true
end

local function LoadWindowPosition()
	return LoadSavedPosition(CONFIG.POSITION_KEY, 420, 320)
end

local function LoadRestoreButtonPosition(defaultX, defaultY)
	return LoadSavedPosition(CONFIG.RESTORE_POSITION_KEY, defaultX, defaultY)
end

local function LoadPickerWindowPosition(defaultX, defaultY)
	return LoadSavedPosition(CONFIG.PICKER_POSITION_KEY, defaultX, defaultY)
end

local function NormalizeTrackerLayout(value)
	if value == CONFIG.LAYOUT_VERTICAL then
		return CONFIG.LAYOUT_VERTICAL
	end
	return CONFIG.LAYOUT_HORIZONTAL
end

local function SaveTrackerLayout()
	pcall(function()
		ADDON:ClearData(CONFIG.LAYOUT_KEY)
		ADDON:SaveData(CONFIG.LAYOUT_KEY, {
			layout = trackerLayout,
		})
	end)
end

local function LoadTrackerLayout()
	local ok, data = pcall(function()
		return ADDON:LoadData(CONFIG.LAYOUT_KEY)
	end)
	if ok then
		if type(data) == "table" then
			return NormalizeTrackerLayout(data.layout)
		end
		if type(data) == "string" then
			return NormalizeTrackerLayout(data)
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

function runtime:SaveSlotCount()
	pcall(function()
		ADDON:ClearData("lootTrackerSlotCount")
		ADDON:SaveData("lootTrackerSlotCount", {
			count = TRACKED_SLOT_COUNT,
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
	count = math.floor(tonumber(count) or TRACKED_SLOT_COUNT)
	if count < 1 then
		count = 1
	elseif count > 20 then
		count = 20
	end
	TRACKED_SLOT_COUNT = count
end

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

function runtime:GetBaseRowsSpan()
	return (TRACKED_SLOT_COUNT * CONFIG.BOX_SIZE) + ((TRACKED_SLOT_COUNT - 1) * CONFIG.BOX_GAP)
end

function runtime:GetBaseWindowWidth()
	if not trackerHeaderControlsVisible then
		if trackerLayout == CONFIG.LAYOUT_VERTICAL then
			return CONFIG.BOX_SIZE
		end
		return self:GetBaseRowsSpan()
	end

	if trackerLayout == CONFIG.LAYOUT_VERTICAL then
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
	if trackerLayout == CONFIG.LAYOUT_VERTICAL then
		if not trackerHeaderControlsVisible then
			return self:GetBaseRowsSpan()
		end
		return math.max(self:GetBaseRowsSpan(), (CONFIG.HEADER_BUTTON_HEIGHT * 9) + (CONFIG.HEADER_BUTTON_GAP * 8))
	end
	if not trackerHeaderControlsVisible then
		return CONFIG.BOX_SIZE
	end
	return CONFIG.BOXES_TOP + CONFIG.BOX_SIZE + CONFIG.TRACKER_PADDING
end

local function GetTrackedRowsSpan()
	return runtime:Scale(runtime:GetBaseRowsSpan())
end

local function GetTrackerWindowWidth()
	return runtime:Scale(runtime:GetBaseWindowWidth())
end

local function GetTrackedRowsLeft()
	if trackerLayout == CONFIG.LAYOUT_VERTICAL then
		return 0
	end
	return math.floor((GetTrackerWindowWidth() - GetTrackedRowsSpan()) / 2)
end

local function GetTrackedRowsTop()
	if not trackerHeaderControlsVisible then
		return 0
	end

	if trackerLayout == CONFIG.LAYOUT_VERTICAL then
		return 0
	end
	return runtime:Scale(CONFIG.BOXES_TOP)
end

local function GetTrackerWindowHeight()
	return runtime:Scale(runtime:GetBaseWindowHeight())
end

local function CompactName(value)
	local text = Trim(value)
	if text == "" then
		return ""
	end
	if string.len(text) <= 7 then
		return text
	end
	return string.sub(text, 1, 6) .. "."
end

local function CompactNameLimit(value, limit)
	local text = Trim(value)
	local maxLen = limit or 12
	if text == "" then
		return ""
	end
	if string.len(text) <= maxLen then
		return text
	end
	return string.sub(text, 1, maxLen - 1) .. "."
end

local function HideIconDrawable(iconDrawable)
	if iconDrawable == nil then
		return
	end
	SafeMethod(iconDrawable, "SetVisible", false)
	SafeMethod(iconDrawable, "Show", false)
end

local function SetIconDrawable(iconDrawable, iconPath)
	-- Sets an icon drawable to display the given icon path, clearing previous if needed, or hides if empty.
	if iconDrawable == nil then
		return
	end

	local nextIconPath = Trim(iconPath)
	if nextIconPath == "" then
		iconDrawable.currentIconPath = nil
		HideIconDrawable(iconDrawable)
		return
	end

	if iconDrawable.currentIconPath ~= nextIconPath then
		SafeMethod(iconDrawable, "ClearAllTextures")
		local ok = SafeMethod(iconDrawable, "AddTexture", nextIconPath)
		if not ok then
			iconDrawable.currentIconPath = nil
			HideIconDrawable(iconDrawable)
			return
		end
		iconDrawable.currentIconPath = nextIconPath
	end

	if not SafeMethod(iconDrawable, "SetVisible", true) then
		SafeMethod(iconDrawable, "Show", true)
	end
end

	-- Sets the background color of a row based on state (tracked, missing, or empty).
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

	row.fullName = nameText or ""
	local compactName = CompactName(nameText)
	local nextCountText = countText or ""
	if row.lastCompactName ~= compactName then
		row.nameLabel:SetText(compactName)
		row.lastCompactName = compactName
	end
	if row.lastCountText ~= nextCountText then
		row.countLabel:SetText(nextCountText)
		row.lastCountText = nextCountText
	end
	SetIconDrawable(row.iconDrawable, iconPath)
	if row.lastState ~= state then
		SetRowBackground(row, state)
		row.lastState = state
	end
end

-- Removes the tracked item at the given index, saves, and requests refresh.
local function RemoveTrackedItem(index)
	if trackedItems[index] == nil then
		return
	end
	trackedItems[index] = nil
	SaveTrackedItems()
	refreshRequested = true
end

-- Copies picker and saved-set item data into the compact tracked-item shape.
local function CopyTrackedItemData(item)
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

local function TrackedItemsMatch(left, right)
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

local function FindTrackedItemIndex(item, ignoredIndex)
	for index = 1, TRACKED_SLOT_COUNT do
		if index ~= ignoredIndex and TrackedItemsMatch(trackedItems[index], item) then
			return index
		end
	end
	return nil
end

-- Sets a tracked item and swaps with an existing matching tracked slot instead of duplicating it.
local function SetTrackedItem(index, item)
	if index == nil or item == nil then
		return
	end

	local nextItem = CopyTrackedItemData(item)
	if nextItem == nil then
		return
	end

	local existingIndex = FindTrackedItemIndex(nextItem, index)
	if existingIndex ~= nil then
		trackedItems[existingIndex] = CopyTrackedItemData(trackedItems[index])
	end
	trackedItems[index] = nextItem
	SaveTrackedItems()
	refreshRequested = true
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
	for index = 1, TRACKED_SLOT_COUNT do
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

	local sourceItem = CopyTrackedItemData(trackedItems[sourceIndex])
	if sourceItem == nil then
		return false
	end

	trackedItems[sourceIndex] = CopyTrackedItemData(trackedItems[targetIndex])
	trackedItems[targetIndex] = sourceItem
	SaveTrackedItems()
	refreshRequested = true
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
		suppressRowRightClickUntil = CurrentClock() + 0.6
		return true
	end
	return false
end

local function ShouldSuppressRowRightClick()
	if suppressRowRightClickUntil <= 0 then
		return false
	end
	if CurrentClock() <= suppressRowRightClickUntil then
		suppressRowRightClickUntil = 0
		return true
	end
	suppressRowRightClickUntil = 0
	return false
end

local UpdateRows

local function ResolveTrackedInventoryEntry(itemsByKey, tracked, itemsByName)
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
	if candidates ~= nil and candidates.key ~= nil then
		candidates = { candidates }
	end
	if candidates == nil then
		candidates = itemsByKey
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

	-- Clears the picker search text, poll state, and clears focus/text on the search box.
local function ClearPickerSearchState()
	pickerSearchText = ""
	pickerLastObservedSearchText = ""
	pickerSearchPollElapsed = 0
	pickerSearchCharHandlerActive = false
	pickerSearchTextEventSuppressed = true
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
	pickerSearchTextEventSuppressed = false
end
	-- Hides the reusable picker search box without destroying or detaching it.

local function HidePickerSearchBox()
	if runtime.pickerSearchBox == nil then
		return
	end
	SafeMethod(runtime.pickerSearchBox, "Show", false)
	SafeMethod(runtime.pickerSearchBox, "SetVisible", false)
	-- Checks if the picker window is currently visible using IsVisible or fallback flag.
end

local function IsPickerWindowVisible()
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
	return isPickerOpen
end

local function IsTrackerWindowVisible()
	if trackerWindow == nil then
		return false
	end

	local fn = trackerWindow.IsVisible
	if type(fn) == "function" then
		local ok, visible = pcall(fn, trackerWindow)
		if ok then
			return visible == true
		end
	end
	return true
end

local function ClearTrackedItems()
	local hadTrackedItems = false
	for index = 1, TRACKED_SLOT_COUNT do
		if trackedItems[index] ~= nil then
			hadTrackedItems = true
		end
		trackedItems[index] = nil
	end

	if hadTrackedItems then
		SaveTrackedItems()
	end
	refreshRequested = true
	if UpdateRows ~= nil then
	-- Opens the picker for a specific tracked slot, resets scroll and search, anchors picker, shows it and sets focus.
		UpdateRows()
	end
end

local function OpenPicker(rowIndex)
	pickerSlotIndex = rowIndex
	pickerScrollIndex = 1
	if RecreatePickerSearchBox ~= nil then
		RecreatePickerSearchBox()
	else
		ClearPickerSearchState()
	end
	if runtime.pickerWindow ~= nil then
		if AnchorPickerWindow ~= nil then
			AnchorPickerWindow()
		else
			runtime.pickerWindow:RemoveAllAnchors()
			runtime.pickerWindow:AddAnchor("TOPLEFT", trackerWindow, 0, GetTrackerWindowHeight() + 8)
		end
		runtime.pickerWindow:Show(true)
	end
	if runtime.pickerSearchBox ~= nil then
		SafeMethod(runtime.pickerSearchBox, "SetFocus")
		SafeMethod(runtime.pickerSearchBox, "SetFocus", true)
	end
	isPickerOpen = true
	-- Closes the picker, clears search state, hides search box and picker window.
	if UpdatePicker ~= nil then
		UpdatePicker()
	end
end

local function ClosePicker()
	isPickerOpen = false
	ClearPickerSearchState()
	-- Handles click on a tracked row: right removes, left opens picker for the slot.
	HidePickerSearchBox()
	if runtime.pickerWindow ~= nil then
		runtime.pickerWindow:Show(false)
	end
end

local function HandleRowClick(rowIndex, mouseButton)
	if IsRightMouseButton(mouseButton) then
		ClearTrackerSlotRightDrag()
		if ShouldSuppressRowRightClick() then
			return
		end
		RemoveTrackedItem(rowIndex)
		UpdateRows()
	else
		OpenPicker(rowIndex)
	end
end

UpdateRows = function()
	-- Updates all tracked rows with current inventory counts or missing state from the snapshot.
	local itemsByKey, _, itemsByName = GetInventorySnapshot(false)

	for index = 1, TRACKED_SLOT_COUNT do
		local row = rowWidgets[index]
		local tracked = trackedItems[index]
		if tracked == nil then
			runtime:SyncRowAcquisitionGlow(row, nil, nil)
			SetRowText(row, "", "", "empty", nil)
		else
			local current = ResolveTrackedInventoryEntry(itemsByKey, tracked, itemsByName)
			if current ~= nil then
				runtime:SyncRowAcquisitionGlow(row, tracked, current)
				SetRowText(row, current.name, "x" .. tostring(current.count), "tracked", current.iconPath or tracked.iconPath)
			else
				runtime:SyncRowAcquisitionGlow(row, tracked, nil)
				SetRowText(row, tracked.name, "x0", "missing", tracked.iconPath)
			end
		end
	end
end

runtime:LoadSlotCount()
runtime:LoadWindowScale()
runtime:LoadMenuMode()
LoadTrackedItems()
trackerLayout = LoadTrackerLayout()

trackerWindow = CreateEmptyWindow("lootTrackerWindow", "UIParent")
runtime.window = trackerWindow
trackerWindow:SetExtent(GetTrackerWindowWidth(), GetTrackerWindowHeight())
trackerWindow:EnableDrag(true)
trackerWindow:Clickable(true)
trackerWindow:Show(true)

local savedX, savedY = LoadWindowPosition()
trackerWindow:AddAnchor("TOPLEFT", "UIParent", savedX, savedY)

local restoreSavedX, restoreSavedY, hasSavedRestoreButtonPosition = LoadRestoreButtonPosition(savedX, savedY)
restoreButtonPositionSaved = hasSavedRestoreButtonPosition
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
local function AnchorWidgetAtSavedPosition(widget, x, y)
	if widget == nil then
		return
	end

	widget:RemoveAllAnchors()
	widget:AddAnchor("TOPLEFT", "UIParent", x, y)
end

local function CenterLootTrackerWindow()
	ClosePicker()
	if runtime.ChangeSlotCount ~= nil then
		runtime:ChangeSlotCount(5 - TRACKED_SLOT_COUNT)
	end
	runtime.trackerScale = 1
	runtime:SaveWindowScale()
	restoreButton:Show(false)
	if runtime.setWindow ~= nil then
		runtime.setWindow:Show(false)
	end
	trackerWindow:Show(true)
	if SetTrackerHeaderControlsVisible ~= nil then
		SetTrackerHeaderControlsVisible(true)
	end
	MarkInventoryDirty()
	ApplyTrackerLayout()
	trackerWindow:RemoveAllAnchors()
	trackerWindow:AddAnchor("CENTER", "UIParent", 0, 0)
	SaveWindowPosition(trackerWindow)
	if runtime.PositionResizeHandles ~= nil then
		runtime:PositionResizeHandles()
	end
	restoreButton:RemoveAllAnchors()
	restoreButton:AddAnchor("CENTER", "UIParent", 0, 0)
	SaveRestoreButtonPosition(restoreButton)
	UpdateRows()
end
	-- Hides the loot tracker window, saves position, closes picker, shows restore button.

local function HideLootTrackerWindow()
	if SetTrackerHeaderControlsVisible ~= nil then
		SetTrackerHeaderControlsVisible(true)
	end
	if runtime.SetResizeHandlesVisible ~= nil then
		runtime:SetResizeHandlesVisible(false)
	end
	SaveWindowPosition(trackerWindow)
	ClosePicker()
	if runtime.setWindow ~= nil then
		runtime.setWindow:Show(false)
	end
	if runtime.menuMode then
		trackerWindow:Show(false)
		restoreButton:Show(false)
		return
	end
	if not restoreButtonPositionSaved then
		local windowX, windowY = GetWidgetSavedPosition(trackerWindow)
		AnchorWidgetAtSavedPosition(restoreButton, windowX, windowY)
	end
	trackerWindow:Show(false)
	restoreButton:Show(true)
	-- Shows the loot tracker window at saved position, hides restore button, marks inventory dirty, applies layout and updates rows.
end

local function ShowLootTrackerWindow()
	trackerHeaderControlsVisible = true
	local windowX, windowY = LoadWindowPosition()
	AnchorWidgetAtSavedPosition(trackerWindow, windowX, windowY)
	restoreButton:Show(false)
	trackerWindow:Show(true)
	if SetTrackerHeaderControlsVisible ~= nil then
		SetTrackerHeaderControlsVisible(true)
	end
	if runtime.SetResizeHandlesVisible ~= nil then
		runtime:SetResizeHandlesVisible(true)
	end
	MarkInventoryDirty()
	ApplyTrackerLayout()
	-- Shows the loot tracker window when restore button is clicked.
	UpdateRows()
end

function runtime:OpenFromEscMenu(show)
	if show == false then
		HideLootTrackerWindow()
		return
	end

	if show == nil
		and trackerWindow ~= nil
		and type(trackerWindow.IsVisible) == "function"
		and trackerWindow:IsVisible()
	then
		HideLootTrackerWindow()
		return
	end

	ShowLootTrackerWindow()
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
		restoreButton:Show(false)
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

if runtime.menuMode or _G.__LOOT_TRACKER_ESC_MENU_BUTTON_ADDED == true then
	runtime:RegisterEscMenuButton()
end

function restoreButton:OnClick()
	-- Starts moving the restore button on drag start.
	ShowLootTrackerWindow()
end
restoreButton:SetHandler("OnClick", restoreButton.OnClick)

	-- Stops moving the restore button and saves its position on drag stop.
function restoreButton:OnDragStart()
	self:StartMoving()
end
restoreButton:SetHandler("OnDragStart", restoreButton.OnDragStart)

function restoreButton:OnDragStop()
	self:StopMovingOrSizing()
	SaveRestoreButtonPosition(self)
end
restoreButton:SetHandler("OnDragStop", restoreButton.OnDragStop)

local background = trackerWindow:CreateColorDrawable(0, 0, 0, 0.58, "background")
background:AddAnchor("TOPLEFT", trackerWindow, 0, 0)
background:AddAnchor("BOTTOMRIGHT", trackerWindow, 0, 0)

local headerLabel = trackerWindow:CreateChildWidget("label", "lootTrackerHeaderLabel", 0, true)
headerLabel:SetText("Loot Tracker")
headerLabel:SetExtent(CONFIG.HEADER_TITLE_WIDTH, CONFIG.HEADER_HEIGHT)
headerLabel.style:SetAlign(ALIGN_LEFT)
headerLabel.style:SetFontSize(11)
headerLabel.style:SetColor(0.95, 0.92, 0.82, 1)
headerLabel.style:SetOutline(true)
headerLabel:AddAnchor("TOPLEFT", trackerWindow, CONFIG.TRACKER_PADDING, CONFIG.TRACKER_TOP_PADDING + 2)
SafeMethod(headerLabel, "EnableDrag", true)

function headerLabel:OnDragStart()
	trackerWindow:StartMoving()
end
headerLabel:SetHandler("OnDragStart", headerLabel.OnDragStart)

function headerLabel:OnDragStop()
	trackerWindow:StopMovingOrSizing()
	SaveWindowPosition(trackerWindow)
	if runtime.PositionResizeHandles ~= nil then
		runtime:PositionResizeHandles()
	end
end
headerLabel:SetHandler("OnDragStop", headerLabel.OnDragStop)

runtime.lootRateMarker = trackerWindow:CreateChildWidget("label", "lootTrackerLootRateMarker", 0, true)
runtime.lootRateMarker:SetText(runtime:FormatLootRatePercent())
runtime.lootRateMarker:SetExtent(CONFIG.LOOT_RATE_MARKER_WIDTH, CONFIG.LOOT_RATE_MARKER_HEIGHT)
runtime.lootRateMarker.style:SetAlign(ALIGN_CENTER)
runtime.lootRateMarker.style:SetFontSize(12)
runtime.lootRateMarker.style:SetOutline(true)
runtime:ApplyLootRateTextColor(runtime.lootRateMarker)
runtime.lootRateMarker:Show(false)
SafeMethod(runtime.lootRateMarker, "EnablePick", false)

local ToggleTrackerLayout

local rotateButton = trackerWindow:CreateChildWidget("button", "lootTrackerRotateButton", 0, true)
rotateButton:SetStyle("text_default")
rotateButton:SetText("R")
rotateButton:SetExtent(CONFIG.ROTATE_BUTTON_WIDTH, 18)

function rotateButton:OnClick()
	ToggleTrackerLayout()
end
rotateButton:SetHandler("OnClick", rotateButton.OnClick)

local resetButton = trackerWindow:CreateChildWidget("button", "lootTrackerResetButton", 0, true)
resetButton:SetStyle("text_default")
resetButton:SetText("C")
resetButton:SetExtent(CONFIG.RESET_BUTTON_WIDTH, 18)

function resetButton:OnClick()
	ClearTrackedItems()
end
resetButton:SetHandler("OnClick", resetButton.OnClick)

runtime.menuModeButton = trackerWindow:CreateChildWidget("button", "lootTrackerMenuModeButton", 0, true)
runtime.menuModeButton:SetStyle("text_default")
runtime.menuModeButton:SetExtent(CONFIG.MENU_BUTTON_WIDTH, 18)
runtime:UpdateMenuModeButton()

function runtime.menuModeButton:OnClick()
	runtime:SetMenuMode(not runtime.menuMode, true)
end
runtime.menuModeButton:SetHandler("OnClick", runtime.menuModeButton.OnClick)

runtime.setManagerButton = trackerWindow:CreateChildWidget("button", "lootTrackerSetManagerButton", 0, true)
runtime.setManagerButton:SetStyle("text_default")
runtime.setManagerButton:SetText("S")
runtime.setManagerButton:SetExtent(CONFIG.SET_BUTTON_WIDTH, 18)

function runtime.setManagerButton:OnClick()
	if runtime.ToggleTrackerSetWindow ~= nil then
		runtime:ToggleTrackerSetWindow()
	end
end
runtime.setManagerButton:SetHandler("OnClick", runtime.setManagerButton.OnClick)

runtime.killCounterButton = trackerWindow:CreateChildWidget("button", "lootTrackerKillCounterButton", 0, true)
runtime.killCounterButton:SetStyle("text_default")
runtime.killCounterButton:SetText("K")
runtime.killCounterButton:SetExtent(CONFIG.RESET_BUTTON_WIDTH, 18)

function runtime:OpenKillCounterWindow()
	local counterRuntime = _G.__LOOT_KILL_COUNTER_RUNTIME
	if counterRuntime ~= nil and type(counterRuntime.ShowCounterWindow) == "function" then
		counterRuntime:ShowCounterWindow()
	end
end

function runtime.killCounterButton:OnClick()
	runtime:OpenKillCounterWindow()
end
runtime.killCounterButton:SetHandler("OnClick", runtime.killCounterButton.OnClick)

runtime.addSlotButton = trackerWindow:CreateChildWidget("button", "lootTrackerAddSlotButton", 0, true)
runtime.addSlotButton:SetStyle("text_default")
runtime.addSlotButton:SetText("+")
runtime.addSlotButton:SetExtent(CONFIG.RESET_BUTTON_WIDTH, 18)

function runtime.addSlotButton:OnClick()
	runtime:ChangeSlotCount(1)
end
runtime.addSlotButton:SetHandler("OnClick", runtime.addSlotButton.OnClick)

runtime.removeSlotButton = trackerWindow:CreateChildWidget("button", "lootTrackerRemoveSlotButton", 0, true)
runtime.removeSlotButton:SetStyle("text_default")
runtime.removeSlotButton:SetText("-")
runtime.removeSlotButton:SetExtent(CONFIG.RESET_BUTTON_WIDTH, 18)

function runtime.removeSlotButton:OnClick()
	runtime:ChangeSlotCount(-1)
end
runtime.removeSlotButton:SetHandler("OnClick", runtime.removeSlotButton.OnClick)

local hideWindowButton = trackerWindow:CreateChildWidget("button", "lootTrackerHideWindowButton", 0, true)
hideWindowButton:SetStyle("text_default")
hideWindowButton:SetText("X")
hideWindowButton:SetExtent(CONFIG.HIDE_WINDOW_BUTTON_WIDTH, 18)

function hideWindowButton:OnClick()
	HideLootTrackerWindow()
end
hideWindowButton:SetHandler("OnClick", hideWindowButton.OnClick)

SetTrackerHeaderControlsVisible = function(visible)
	if trackerHeaderControlsVisible == visible then
		SafeMethod(background, "SetVisible", visible)
		SafeMethod(background, "Show", visible)
		headerLabel:Show(visible and trackerLayout ~= CONFIG.LAYOUT_VERTICAL)
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

	local oldX, oldY = GetWidgetSavedPosition(trackerWindow)
	local oldRowsLeft = GetTrackedRowsLeft()
	local oldRowsTop = GetTrackedRowsTop()

	trackerHeaderControlsVisible = visible
	SafeMethod(background, "SetVisible", visible)
	SafeMethod(background, "Show", visible)
	headerLabel:Show(visible and trackerLayout ~= CONFIG.LAYOUT_VERTICAL)
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
	if ApplyTrackerLayout ~= nil then
		ApplyTrackerLayout()
	end
	if runtime.SetResizeHandlesVisible ~= nil then
		runtime:SetResizeHandlesVisible(visible)
	end

	if oldX ~= nil and oldY ~= nil then
		AnchorWidgetAtSavedPosition(
			trackerWindow,
			oldX + oldRowsLeft - GetTrackedRowsLeft(),
			oldY + oldRowsTop - GetTrackedRowsTop()
		)
	end
	if runtime.PositionResizeHandles ~= nil then
		runtime:PositionResizeHandles()
	end
end

local function ShowTrackerHeaderControls()
	SetTrackerHeaderControlsVisible(true)
end

local function HideTrackerHeaderControls()
	if runtime.IsResizing ~= nil and runtime:IsResizing() then
		return
	end
	SetTrackerHeaderControlsVisible(false)
end

function trackerWindow:OnEnter()
	ShowTrackerHeaderControls()
end
trackerWindow:SetHandler("OnEnter", trackerWindow.OnEnter)

function trackerWindow:OnLeave()
	HideTrackerHeaderControls()
end
trackerWindow:SetHandler("OnLeave", trackerWindow.OnLeave)

function headerLabel:OnEnter()
	ShowTrackerHeaderControls()
end
headerLabel:SetHandler("OnEnter", headerLabel.OnEnter)

rotateButton:SetHandler("OnEnter", ShowTrackerHeaderControls)
resetButton:SetHandler("OnEnter", ShowTrackerHeaderControls)
runtime.menuModeButton:SetHandler("OnEnter", ShowTrackerHeaderControls)
runtime.setManagerButton:SetHandler("OnEnter", ShowTrackerHeaderControls)
runtime.killCounterButton:SetHandler("OnEnter", ShowTrackerHeaderControls)
runtime.addSlotButton:SetHandler("OnEnter", ShowTrackerHeaderControls)
runtime.removeSlotButton:SetHandler("OnEnter", ShowTrackerHeaderControls)
hideWindowButton:SetHandler("OnEnter", ShowTrackerHeaderControls)

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

	if trackerLayout == CONFIG.LAYOUT_VERTICAL then
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
		runtime.lootRateMarker:AddAnchor("TOPLEFT", trackerWindow, markerLeft, 0)

		rotateButton:RemoveAllAnchors()
		rotateButton:AddAnchor(
			"TOPLEFT",
			trackerWindow,
			narrowLeft,
			runtime:Scale(CONFIG.HEADER_BUTTON_HEIGHT + CONFIG.HEADER_BUTTON_GAP)
		)

		resetButton:RemoveAllAnchors()
		resetButton:AddAnchor(
			"TOPLEFT",
			trackerWindow,
			narrowLeft,
			runtime:Scale((CONFIG.HEADER_BUTTON_HEIGHT * 2) + (CONFIG.HEADER_BUTTON_GAP * 2))
		)

		runtime.setManagerButton:RemoveAllAnchors()
		runtime.setManagerButton:AddAnchor(
			"TOPLEFT",
			trackerWindow,
			narrowLeft,
			runtime:Scale((CONFIG.HEADER_BUTTON_HEIGHT * 3) + (CONFIG.HEADER_BUTTON_GAP * 3))
		)

		runtime.menuModeButton:RemoveAllAnchors()
		runtime.menuModeButton:AddAnchor(
			"TOPLEFT",
			trackerWindow,
			menuLeft,
			runtime:Scale((CONFIG.HEADER_BUTTON_HEIGHT * 4) + (CONFIG.HEADER_BUTTON_GAP * 4))
		)

		runtime.killCounterButton:RemoveAllAnchors()
		runtime.killCounterButton:AddAnchor(
			"TOPLEFT",
			trackerWindow,
			narrowLeft,
			runtime:Scale((CONFIG.HEADER_BUTTON_HEIGHT * 5) + (CONFIG.HEADER_BUTTON_GAP * 5))
		)

		runtime.addSlotButton:RemoveAllAnchors()
		runtime.addSlotButton:AddAnchor(
			"TOPLEFT",
			trackerWindow,
			narrowLeft,
			runtime:Scale((CONFIG.HEADER_BUTTON_HEIGHT * 6) + (CONFIG.HEADER_BUTTON_GAP * 6))
		)

		runtime.removeSlotButton:RemoveAllAnchors()
		runtime.removeSlotButton:AddAnchor(
			"TOPLEFT",
			trackerWindow,
			narrowLeft,
			runtime:Scale((CONFIG.HEADER_BUTTON_HEIGHT * 7) + (CONFIG.HEADER_BUTTON_GAP * 7))
		)

		hideWindowButton:RemoveAllAnchors()
		hideWindowButton:AddAnchor(
			"TOPLEFT",
			trackerWindow,
			hideLeft,
			runtime:Scale((CONFIG.HEADER_BUTTON_HEIGHT * 8) + (CONFIG.HEADER_BUTTON_GAP * 8))
		)
		return
	end

	headerLabel:Show(trackerHeaderControlsVisible)
	headerLabel:AddAnchor("TOPLEFT", trackerWindow, runtime:Scale(CONFIG.TRACKER_PADDING), runtime:Scale(CONFIG.TRACKER_TOP_PADDING + 2))

	runtime.lootRateMarker:RemoveAllAnchors()
	runtime.lootRateMarker:AddAnchor(
		"TOPLEFT",
		trackerWindow,
		runtime:Scale(CONFIG.TRACKER_PADDING + CONFIG.HEADER_TITLE_WIDTH + CONFIG.HEADER_BUTTON_GAP),
		runtime:Scale(CONFIG.TRACKER_TOP_PADDING + 1)
	)

	hideWindowButton:RemoveAllAnchors()
	hideWindowButton:AddAnchor("TOPRIGHT", trackerWindow, -runtime:Scale(CONFIG.TRACKER_PADDING), runtime:Scale(CONFIG.TRACKER_TOP_PADDING + 1))

	runtime.removeSlotButton:RemoveAllAnchors()
	runtime.removeSlotButton:AddAnchor(
		"TOPRIGHT",
		trackerWindow,
		-runtime:Scale(CONFIG.TRACKER_PADDING + CONFIG.HIDE_WINDOW_BUTTON_WIDTH + CONFIG.HEADER_BUTTON_GAP),
		runtime:Scale(CONFIG.TRACKER_TOP_PADDING + 1)
	)

	runtime.addSlotButton:RemoveAllAnchors()
	runtime.addSlotButton:AddAnchor(
		"TOPRIGHT",
		trackerWindow,
		-runtime:Scale(CONFIG.TRACKER_PADDING + CONFIG.HIDE_WINDOW_BUTTON_WIDTH + CONFIG.HEADER_BUTTON_GAP + CONFIG.RESET_BUTTON_WIDTH + CONFIG.HEADER_BUTTON_GAP),
		runtime:Scale(CONFIG.TRACKER_TOP_PADDING + 1)
	)

	runtime.killCounterButton:RemoveAllAnchors()
	runtime.killCounterButton:AddAnchor(
		"TOPRIGHT",
		trackerWindow,
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
		trackerWindow,
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
		trackerWindow,
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
		trackerWindow,
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
		trackerWindow,
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
AnchorPickerWindow = function()
	if runtime.pickerWindow == nil then
		return
	end

	runtime.pickerWindow:RemoveAllAnchors()
	if pickerWindowPositionSaved then
		local pickerX, pickerY = LoadPickerWindowPosition(0, 0)
		runtime.pickerWindow:AddAnchor("TOPLEFT", "UIParent", pickerX, pickerY)
		return
	end

	runtime.pickerWindow:AddAnchor("TOPLEFT", trackerWindow, 0, GetTrackerWindowHeight() + 8)
end
	-- Anchors all tracked row widgets according to current layout (horizontal row or vertical column).

local function AnchorTrackedRows()
	for index, row in pairs(rowWidgets) do
		if row ~= nil and index > TRACKED_SLOT_COUNT then
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
			local offsetX = GetTrackedRowsLeft() + ((index - 1) * (boxSize + boxGap))
			local offsetY = GetTrackedRowsTop()

			if trackerLayout == CONFIG.LAYOUT_VERTICAL then
				offsetX = GetTrackedRowsLeft()
				offsetY = GetTrackedRowsTop() + ((index - 1) * (boxSize + boxGap))
			end

			row:RemoveAllAnchors()
			row:AddAnchor("TOPLEFT", trackerWindow, offsetX, offsetY)
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
				runtime:LayoutAcquisitionGlowBorder(row, boxSize)
				runtime:ResizeAcquisitionGlowInner(row, boxSize)
			end
			if row.nameLabel ~= nil then
				row.nameLabel:SetExtent(boxSize - runtime:Scale(5), runtime:Scale(18))
				row.nameLabel:RemoveAllAnchors()
				row.nameLabel:AddAnchor("TOP", row, 0, runtime:Scale(5))
				row.nameLabel.style:SetFontSize(runtime:Scale(8))
			end
			if row.countLabel ~= nil then
				row.countLabel:SetExtent(boxSize - runtime:Scale(5), runtime:Scale(15))
				row.countLabel:RemoveAllAnchors()
				row.countLabel:AddAnchor("BOTTOM", row, 0, -runtime:Scale(3))
				row.countLabel.style:SetFontSize(runtime:Scale(9))
			end
		end
	end
	-- Applies the current tracker layout: resizes window, anchors header and rows, and anchors picker if open.
end

ApplyTrackerLayout = function()
	trackerWindow:SetExtent(GetTrackerWindowWidth(), GetTrackerWindowHeight())
	AnchorHeaderControls()
	AnchorTrackedRows()
	if isPickerOpen then
		AnchorPickerWindow()
	-- Toggles between horizontal and vertical layout, saves it, applies, and refreshes display.
	end
	if runtime.PositionResizeHandles ~= nil then
		runtime:PositionResizeHandles()
	end
end

ToggleTrackerLayout = function()
	if trackerLayout == CONFIG.LAYOUT_VERTICAL then
		trackerLayout = CONFIG.LAYOUT_HORIZONTAL
	else
		trackerLayout = CONFIG.LAYOUT_VERTICAL
	end
	SaveTrackerLayout()
	ApplyTrackerLayout()
	refreshRequested = true
	UpdateRows()
end

function runtime:CreateTrackerRow(index)
	if rowWidgets[index] ~= nil then
		rowWidgets[index]:Show(true)
		return
	end

	local row = trackerWindow:CreateChildWidget("button", "lootTrackerRow" .. tostring(index), 0, true)
	row.index = index
	row:SetText("")
	row:SetExtent(runtime:Scale(CONFIG.BOX_SIZE), runtime:Scale(CONFIG.BOX_SIZE))
	row:AddAnchor(
		"TOPLEFT",
		trackerWindow,
		GetTrackedRowsLeft() + ((index - 1) * (runtime:Scale(CONFIG.BOX_SIZE) + runtime:Scale(CONFIG.BOX_GAP))),
		GetTrackedRowsTop()
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
	HideIconDrawable(rowIcon)
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
	SafeMethod(nameLabel, "EnablePick", false)
	row.nameLabel = nameLabel

	local countLabel = row:CreateChildWidget("label", "lootTrackerRowCount" .. tostring(index), 0, true)
	countLabel:SetText("")
	countLabel:SetExtent(runtime:Scale(CONFIG.BOX_SIZE - 5), runtime:Scale(15))
	countLabel.style:SetAlign(ALIGN_CENTER)
	countLabel.style:SetFontSize(runtime:Scale(9))
	countLabel.style:SetColor(0.92, 0.86, 0.62, 1)
	countLabel.style:SetOutline(true)
	-- Sets hover state to true for the row on mouse enter.
	countLabel:AddAnchor("BOTTOM", row, 0, -runtime:Scale(3))
	SafeMethod(countLabel, "EnablePick", false)
	row.countLabel = countLabel

	function row:OnEnter()
		-- Sets hover state to true for the row on mouse enter.
		ShowTrackerHeaderControls()
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
		HandleRowClick(self.index, mouseButton)
	end
	row:SetHandler("OnClick", row.OnClick)

	function row:OnMouseDown(mouseButton)
		BeginTrackerSlotRightDrag(self.index, mouseButton)
	end
	row:SetHandler("OnMouseDown", row.OnMouseDown)

	function row:OnMouseUp(mouseButton)
		if EndTrackerSlotRightDrag(self.index, mouseButton) then
			UpdateRows()
		end
	end
	row:SetHandler("OnMouseUp", row.OnMouseUp)

	function row:OnRightButtonDown()
		BeginTrackerSlotRightDrag(self.index, "RightButton")
	end
	row:SetHandler("OnRightButtonDown", row.OnRightButtonDown)

	function row:OnRightButtonUp()
		if EndTrackerSlotRightDrag(self.index, "RightButton") then
			UpdateRows()
		end
	end
	row:SetHandler("OnRightButtonUp", row.OnRightButtonUp)

	function row:OnDragStart()
		if trackerSlotRightDrag.sourceIndex == self.index then
			self.draggedTrackerSlot = true
			return true
		end
		self.draggedTrackerWindow = true
		trackerWindow:StartMoving()
		return true
	end
	row:SetHandler("OnDragStart", row.OnDragStart)

	function row:OnDragStop()
		if self.draggedTrackerSlot then
			self.draggedTrackerSlot = false
			if EndTrackerSlotRightDrag(self.index, "RightButton") then
				UpdateRows()
			end
			return
		end
		trackerWindow:StopMovingOrSizing()
		SaveWindowPosition(trackerWindow)
		if runtime.PositionResizeHandles ~= nil then
			runtime:PositionResizeHandles()
		end
	end
	row:SetHandler("OnDragStop", row.OnDragStop)

	rowWidgets[index] = row
end

local function RemoveTrackedSlotAt(removeIndex, currentCount)
	for index = removeIndex, currentCount - 1 do
		trackedItems[index] = CopyTrackedItemData(trackedItems[index + 1])
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
	local nextCount = TRACKED_SLOT_COUNT + (tonumber(delta) or 0)
	if nextCount < 1 then
		nextCount = 1
	elseif nextCount > 20 then
		nextCount = 20
	end
	if nextCount == TRACKED_SLOT_COUNT then
		return
	end

	if nextCount < TRACKED_SLOT_COUNT then
		local currentCount = TRACKED_SLOT_COUNT
		while currentCount > nextCount do
			RemoveOneTrackedSlot(currentCount)
			currentCount = currentCount - 1
		end
		ClearTrackerSlotRightDrag()
		ClosePicker()
	end

	TRACKED_SLOT_COUNT = nextCount
	for index = 1, TRACKED_SLOT_COUNT do
		self:CreateTrackerRow(index)
	end
	if not options.skipSave then
		self:SaveSlotCount()
		SaveTrackedItems()
	end
	if not options.skipLayout and ApplyTrackerLayout ~= nil then
		ApplyTrackerLayout()
	end
	if not options.skipRefresh then
		refreshRequested = true
		if not options.skipUpdateRows and UpdateRows ~= nil then
			UpdateRows()
		end
	end
	return true
end

function runtime:ApplyResizeGeometry(x, y, scale, shouldSave)
	self.trackerScale = self:ClampScale(scale)
	AnchorWidgetAtSavedPosition(trackerWindow, x, y)
	ApplyTrackerLayout()
	if shouldSave then
		SaveWindowPosition(trackerWindow)
		self:SaveWindowScale()
	end
end

function runtime:PositionResizeHandles()
	local handleSize = self:Scale(18)
	local boxSize = self:Scale(CONFIG.BOX_SIZE)
	local boxGap = self:Scale(CONFIG.BOX_GAP)
	local firstBoxX = GetTrackedRowsLeft()
	local firstBoxY = GetTrackedRowsTop()
	local lastBoxX = firstBoxX
	local lastBoxY = firstBoxY
	if trackerLayout == CONFIG.LAYOUT_VERTICAL then
		lastBoxY = firstBoxY + ((TRACKED_SLOT_COUNT - 1) * (boxSize + boxGap))
	else
		lastBoxX = firstBoxX + ((TRACKED_SLOT_COUNT - 1) * (boxSize + boxGap))
	end
	for _, handle in ipairs(self.resizeHandles) do
		if handle ~= nil then
			self:LayoutResizeGrip(handle)
		end
		if handle ~= nil then
			local boxX = firstBoxX
			local boxY = firstBoxY
			if trackerLayout == CONFIG.LAYOUT_VERTICAL then
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
				handle.resizeVisual:AddAnchor("TOPLEFT", trackerWindow, handleX, handleY)
			end
			if not handle.isResizing then
				handle:RemoveAllAnchors()
				handle:AddAnchor("TOPLEFT", trackerWindow, handleX, handleY)
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
	local handle = trackerWindow:CreateChildWidget("button", name, 0, true)
	handle:SetText("")
	handle:SetExtent(self:Scale(18), self:Scale(18))
	handle:EnableDrag(true)
	handle:Clickable(true)
	handle.resizeFromLeft = string.find(anchor, "LEFT", 1, true) ~= nil
	handle.resizeFromTop = string.find(anchor, "TOP", 1, true) ~= nil
	local visual = trackerWindow:CreateChildWidget("button", name .. "Visual", 0, true)
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
		ShowTrackerHeaderControls()
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
		local startX, startY = GetWidgetSavedPosition(trackerWindow)
		local handleStartX, handleStartY = GetWidgetSavedPosition(self)
		if startX == nil or startY == nil or handleStartX == nil or handleStartY == nil then
			return
		end

		self.resizeDrag = {
			startX = startX,
			startY = startY,
			startWidth = GetTrackerWindowWidth(),
			startHeight = GetTrackerWindowHeight(),
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
		ShowTrackerHeaderControls()
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

for index = 1, TRACKED_SLOT_COUNT do
	runtime:CreateTrackerRow(index)
end

runtime.resizeHandles = {
	runtime:CreateResizeHandle("lootTrackerResizeTopLeft", "TOPLEFT"),
	runtime:CreateResizeHandle("lootTrackerResizeTopRight", "TOPRIGHT"),
	runtime:CreateResizeHandle("lootTrackerResizeBottomLeft", "BOTTOMLEFT"),
	runtime:CreateResizeHandle("lootTrackerResizeBottomRight", "BOTTOMRIGHT"),
}

ApplyTrackerLayout()
HideTrackerHeaderControls()

local pickerWindow = CreateEmptyWindow("lootTrackerPickerWindow", "UIParent")
runtime.pickerWindow = pickerWindow
pickerWindow:SetExtent(CONFIG.PICKER_WIDTH, CONFIG.PICKER_HEIGHT)
pickerWindow:EnableDrag(true)
pickerWindow:Clickable(true)
pickerWindow:Show(false)
local pickerSavedX, pickerSavedY, hasSavedPickerWindowPosition = LoadPickerWindowPosition(0, 0)
pickerWindowPositionSaved = hasSavedPickerWindowPosition
if pickerWindowPositionSaved then
	pickerWindow:AddAnchor("TOPLEFT", "UIParent", pickerSavedX, pickerSavedY)
else
	pickerWindow:AddAnchor("TOPLEFT", trackerWindow, 0, GetTrackerWindowHeight() + 8)
end

local pickerBackground = pickerWindow:CreateColorDrawable(0, 0, 0, 0.72, "background")
pickerBackground:AddAnchor("TOPLEFT", pickerWindow, 0, 0)
pickerBackground:AddAnchor("BOTTOMRIGHT", pickerWindow, 0, 0)

local pickerTitle = pickerWindow:CreateChildWidget("label", "lootTrackerPickerTitle", 0, true)
pickerTitle:SetText("Inventory")
pickerTitle:SetExtent(CONFIG.PICKER_WIDTH - 56, CONFIG.HEADER_HEIGHT)
pickerTitle.style:SetAlign(ALIGN_LEFT)
pickerTitle.style:SetFontSize(12)
pickerTitle.style:SetColor(0.95, 0.92, 0.82, 1)
pickerTitle.style:SetOutline(true)
pickerTitle:AddAnchor("TOPLEFT", pickerWindow, CONFIG.PADDING, CONFIG.PADDING + 2)
SafeMethod(pickerTitle, "EnableDrag", true)

function pickerTitle:OnDragStart()
	pickerWindow:StartMoving()
end
pickerTitle:SetHandler("OnDragStart", pickerTitle.OnDragStart)

function pickerTitle:OnDragStop()
	pickerWindow:StopMovingOrSizing()
	SavePickerWindowPosition(pickerWindow)
end
pickerTitle:SetHandler("OnDragStop", pickerTitle.OnDragStop)

local pickerCloseButton = pickerWindow:CreateChildWidget("button", "lootTrackerPickerCloseButton", 0, true)
pickerCloseButton:SetStyle("text_default")
pickerCloseButton:SetText("X")
pickerCloseButton:SetExtent(26, 22)
pickerCloseButton:AddAnchor("TOPRIGHT", pickerWindow, -CONFIG.PADDING, CONFIG.PADDING)

function pickerCloseButton:OnClick()
	ClosePicker()
end
pickerCloseButton:SetHandler("OnClick", pickerCloseButton.OnClick)

local pickerSearchBorder = pickerWindow:CreateColorDrawable(0.96, 0.9, 0.72, 0.62, "artwork")
pickerSearchBorder:AddAnchor("TOPLEFT", pickerWindow, CONFIG.PADDING, CONFIG.PICKER_SEARCH_TOP)
pickerSearchBorder:SetExtent(CONFIG.PICKER_WIDTH - (CONFIG.PADDING * 2), CONFIG.PICKER_SEARCH_HEIGHT)

local pickerSearchBackground = pickerWindow:CreateColorDrawable(0.86, 0.88, 0.82, 0.42, "artwork")
pickerSearchBackground:AddAnchor("TOPLEFT", pickerWindow, CONFIG.PADDING + 2, CONFIG.PICKER_SEARCH_TOP + 2)
pickerSearchBackground:SetExtent(CONFIG.PICKER_WIDTH - (CONFIG.PADDING * 2) - 4, CONFIG.PICKER_SEARCH_HEIGHT - 4)

_G.__LOOT_TRACKER_SEARCH_BOX_SERIAL = _G.__LOOT_TRACKER_SEARCH_BOX_SERIAL or 0
local pickerSearchBox = nil

local function NextPickerSearchBoxName()
	-- Generates the next unique name for the picker search box to avoid conflicts.
	_G.__LOOT_TRACKER_SEARCH_BOX_SERIAL = _G.__LOOT_TRACKER_SEARCH_BOX_SERIAL + 1
	return "lootTrackerPickerSearchBox" .. tostring(_G.__LOOT_TRACKER_SEARCH_BOX_SERIAL)
end

local function ConfigurePickerSearchBox(searchBox)
	-- Configures a picker search box edit widget with anchors, size, font, and visibility.
	if searchBox == nil then
		return
	end
	searchBox:RemoveAllAnchors()
	searchBox:AddAnchor("TOPLEFT", pickerWindow, CONFIG.PADDING + 4, CONFIG.PICKER_SEARCH_TOP + 3)
	searchBox:SetExtent(CONFIG.PICKER_WIDTH - (CONFIG.PADDING * 2) - 8, CONFIG.PICKER_SEARCH_HEIGHT - 6)
	searchBox:SetText("")
	SafeMethod(searchBox, "SetMaxTextLength", 64)
	SafeMethod(searchBox, "SetInset", 7, 0, 7, 0)
	SafeMethod(searchBox, "Show", true)
	SafeMethod(searchBox, "SetVisible", true)
	if searchBox.style ~= nil then
		searchBox.style:SetColor(0.05, 0.06, 0.05, 1)
		searchBox.style:SetFontSize(13)
		searchBox.style:SetAlign(ALIGN_LEFT)
	end
end

pickerSearchBox = pickerWindow:CreateChildWidget("editbox", NextPickerSearchBoxName(), 0, true)
runtime.pickerSearchBox = pickerSearchBox
ConfigurePickerSearchBox(pickerSearchBox)

local pickerStatusLabel = pickerWindow:CreateChildWidget("label", "lootTrackerPickerStatus", 0, true)
pickerStatusLabel:SetText("")
pickerStatusLabel:SetExtent(140, 20)
pickerStatusLabel.style:SetAlign(ALIGN_CENTER)
pickerStatusLabel.style:SetFontSize(10)
pickerStatusLabel.style:SetColor(0.82, 0.82, 0.82, 1)
pickerStatusLabel.style:SetOutline(true)
pickerStatusLabel:AddAnchor("TOP", pickerWindow, 0, CONFIG.PICKER_CONTROL_TOP + 2)

local pickerUpButton = pickerWindow:CreateChildWidget("button", "lootTrackerPickerUpButton", 0, true)
pickerUpButton:SetStyle("text_default")
pickerUpButton:SetText("Up")
pickerUpButton:SetExtent(64, 22)
pickerUpButton:AddAnchor("TOPLEFT", pickerWindow, CONFIG.PADDING, CONFIG.PICKER_CONTROL_TOP)

local pickerDownButton = pickerWindow:CreateChildWidget("button", "lootTrackerPickerDownButton", 0, true)
pickerDownButton:SetStyle("text_default")
pickerDownButton:SetText("Down")
pickerDownButton:SetExtent(64, 22)
pickerDownButton:AddAnchor("TOPRIGHT", pickerWindow, -CONFIG.PADDING, CONFIG.PICKER_CONTROL_TOP)

local pickerSearchGetterCandidates = {
	{ name = "GetText" },
	{ name = "GetDisplayText" },
	{ name = "GetInputText" },
	{ name = "GetString" },
	{ name = "GetEditText" },
	{ name = "GetValue", arg = "text" },
	{ name = "GetValue", arg = "string" },
	{ name = "GetValue", arg = "value" },
}

local function ReadPickerSearchBoxText()
	-- Reads the current text from the picker search box by trying multiple getter methods until a non-empty string is found.
	local sawEmptyText = false
	local searchBox = runtime.pickerSearchBox
	if searchBox == nil then
		return nil
	end

	for _, candidate in ipairs(pickerSearchGetterCandidates) do
		if not candidate.failed then
			local fn = searchBox[candidate.name]
			if type(fn) == "function" then
				local ok, text = pcall(function()
					if candidate.arg ~= nil then
						return fn(searchBox, candidate.arg)
					end
					return fn(searchBox)
				end)
				if not ok then
					candidate.failed = true
				elseif type(text) == "string" then
					if text ~= "" then
						return text
					end
					sawEmptyText = true
				end
			end
		end
	end

	if pickerSearchText == "" and sawEmptyText then
		return ""
	end

	return nil
end

local function SyncPickerSearchBoxText(text)
	-- Synchronizes the picker search box text across multiple possible setter methods while suppressing events.
	local searchBox = runtime.pickerSearchBox
	if searchBox == nil then
		return
	end

	pickerSearchTextEventSuppressed = true
	SafeMethod(searchBox, "SetText", text)
	SafeMethod(searchBox, "SetInputText", text)
	SafeMethod(searchBox, "SetEditText", text)
	SafeMethod(searchBox, "SetDisplayText", text)
	SafeMethod(searchBox, "SetString", text)
	pickerSearchTextEventSuppressed = false
end

local function DropLastSearchCharacter(text)
	-- Drops the last character from text, handling multi-byte UTF8 by finding proper cut point.
	local len = string.len(text or "")
	if len <= 0 then
		return ""
	end

	local cutIndex = len
	while cutIndex > 1 do
		local byte = string.byte(text, cutIndex)
		if byte == nil or byte < 128 or byte >= 192 then
			break
		end
		cutIndex = cutIndex - 1
	end

	return string.sub(text, 1, cutIndex - 1)
end

local function NormalizeKeyToken(value)
	if type(value) == "number" then
		return tostring(value)
	end
	if type(value) ~= "string" then
		return nil
	end
	local text = string.lower(value)
	text = string.gsub(text, "%s+", "")
	text = string.gsub(text, "_", "")
	text = string.gsub(text, "-", "")
	return text
end

local function IsBackspaceKey(value)
	local token = NormalizeKeyToken(value)
	return token == "backspace" or token == "back" or token == "8"
end

local function IsDeleteKey(value)
	local token = NormalizeKeyToken(value)
	return token == "delete" or token == "del" or token == "46"
end

local function IsClearSearchKey(value)
	local token = NormalizeKeyToken(value)
	return token == "escape" or token == "esc" or token == "27"
end

local function FirstPrintableStringArg(...)
	-- Extracts the first printable string arg from varargs, handling numbers as chars if in range.
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if type(value) == "number" then
			if value >= 32 and value <= 126 then
				return string.char(value)
			end
		elseif type(value) == "string" and value ~= "" then
			local numericValue = tonumber(value)
			if numericValue ~= nil and string.match(value, "^%d+$") and numericValue >= 32 and numericValue <= 126 then
				return string.char(numericValue)
			end
			local firstByte = string.byte(value, 1)
			if firstByte ~= nil and firstByte >= 32 and firstByte ~= 127 then
				return value
			end
		end
	end
	return nil
end

local function FirstSearchKeyArg(...)
	-- Extracts the first string or number arg from varargs for search key handling.
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if type(value) == "string" or type(value) == "number" then
			return value
		end
	end
	return nil
end

local function SearchCharacterFromKey(value)
	-- Converts a key value to a printable search character, handling numbers, letters, space, numpad etc.
	if type(value) == "number" then
		if value == 32 then
			return " "
		end
		if value >= 48 and value <= 57 then
			return string.char(value)
		end
		if value >= 65 and value <= 90 then
			return string.char(value)
		end
		if value >= 96 and value <= 105 then
			return tostring(value - 96)
		end
		return nil
	end

	if type(value) ~= "string" or value == "" then
		return nil
	end

	if string.len(value) == 1 then
		local byte = string.byte(value, 1)
		if byte ~= nil and byte >= 32 and byte ~= 127 then
			return value
		end
	end

	local token = NormalizeKeyToken(value)
	if token == "space" or token == "spacebar" then
		return " "
	end
	if token ~= nil and string.len(token) == 4 and string.sub(token, 1, 3) == "key" then
		return string.sub(token, 4, 4)
	end
	if token ~= nil and string.len(token) == 7 and string.sub(token, 1, 6) == "numpad" then
		return string.sub(token, 7, 7)
	end

	return nil
end

local function ApplyPickerSearchText(nextSearchText, syncSearchBox)
	-- Applies new search text to picker, updates state, resets scroll, syncs box if needed, and refreshes picker.
	local text = tostring(nextSearchText or "")
	if text == pickerSearchText then
		return
	end
	pickerSearchText = text
	pickerLastObservedSearchText = text
	pickerScrollIndex = 1
	if syncSearchBox then
		SyncPickerSearchBoxText(text)
	end
	UpdatePicker()
end

local function PollPickerSearchBox()
	-- Polls the picker search box for current text and applies it if changed.
	local text = ReadPickerSearchBoxText()
	if text ~= nil then
		ApplyPickerSearchText(text, false)
	end
end

local function AppendPickerSearchText(text)
	-- Appends text to picker search, handling multi-char or single char, then updates.
	if text == nil or text == "" then
		PollPickerSearchBox()
		return
	end

	if string.len(text) > 1 then
		ApplyPickerSearchText(text, true)
	else
		ApplyPickerSearchText(pickerSearchText .. text, true)
	end
end

local function HandlePickerSearchKey(...)
	-- Handles key input for picker search (backspace, delete, escape, printable chars). Updates search text accordingly.
	local key = FirstSearchKeyArg(...)
	if key == nil then
		PollPickerSearchBox()
		return
	end

	if IsBackspaceKey(key) or IsDeleteKey(key) then
		ApplyPickerSearchText(DropLastSearchCharacter(pickerSearchText), true)
	elseif IsClearSearchKey(key) then
		ApplyPickerSearchText("", true)
	elseif not pickerSearchCharHandlerActive then
		local character = SearchCharacterFromKey(key)
		if character ~= nil then
			AppendPickerSearchText(character)
		else
			PollPickerSearchBox()
		end
	else
		PollPickerSearchBox()
	end
end

local function HandlePickerSearchChar(...)
	-- Handles character input for picker search. Sets active flag and appends printable text.
	local text = FirstPrintableStringArg(...)
	if text ~= nil then
		pickerSearchCharHandlerActive = true
	end
	AppendPickerSearchText(text)
end

local function FirstStringArg(...)
	-- Extracts the first string argument from varargs, used for search change events.
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if type(value) == "string" then
			return tostring(value)
		end
	end
	return nil
end

local function OnPickerSearchChanged(...)
	-- Handler for picker search text changed event. Applies the new search text if not suppressed.
	if pickerSearchTextEventSuppressed then
		return
	end

	local argText = FirstStringArg(...)
	if argText ~= nil then
		ApplyPickerSearchText(argText, false)
	else
		PollPickerSearchBox()
	end
end

local function OnPickerSearchKey(...)
	-- Handler for picker search key input. Delegates to HandlePickerSearchKey.
	HandlePickerSearchKey(...)
end

local function OnPickerSearchChar(...)
	-- Handler for picker search char input. Sets flag and appends the character to search text.
	HandlePickerSearchChar(...)
end

local function OnPickerSearchMouseWheel(delta)
	-- Handles mouse wheel on picker search box by delegating to picker window.
	pickerWindow:OnMouseWheel(delta)
end

local function ClampPickerScroll()
	-- Clamps the picker scroll index to valid range based on total items and visible count.
	local maxStart = #pickerItems - CONFIG.PICKER_VISIBLE_COUNT + 1
	if maxStart < 1 then
		maxStart = 1
	end
	if pickerScrollIndex < 1 then
		pickerScrollIndex = 1
	elseif pickerScrollIndex > maxStart then
		pickerScrollIndex = maxStart
	end
end

local function SetPickerButton(button, item)
	button.itemData = item
	if item == nil then
		button.nameLabel:SetText("")
		button.countLabel:SetText("")
		SetIconDrawable(button.iconDrawable, nil)
		button.bg:SetColor(0.06, 0.06, 0.07, 0.54)
		return
	end

	button.nameLabel:SetText(CompactNameLimit(item.name, 13))
	button.countLabel:SetText("x" .. tostring(item.count))
	SetIconDrawable(button.iconDrawable, item.iconPath)
	button.bg:SetColor(0.08, 0.12, 0.16, 0.88)
end

UpdatePicker = function()
	pickerItems = BuildPickerItems(pickerSearchText)
	ClampPickerScroll()

	for visibleIndex = 1, CONFIG.PICKER_VISIBLE_COUNT do
		local button = pickerItemWidgets[visibleIndex]
		SetPickerButton(button, pickerItems[pickerScrollIndex + visibleIndex - 1])
	end

	local total = #pickerItems
	if total == 0 then
		pickerStatusLabel:SetText("0 / 0")
	else
		local firstVisible = pickerScrollIndex
		local lastVisible = pickerScrollIndex + CONFIG.PICKER_VISIBLE_COUNT - 1
		if lastVisible > total then
			lastVisible = total
		end
		pickerStatusLabel:SetText(tostring(firstVisible) .. "-" .. tostring(lastVisible) .. " / " .. tostring(total))
	end
end

local function ScrollPicker(deltaItems)
	pickerScrollIndex = pickerScrollIndex + deltaItems
	ClampPickerScroll()
	UpdatePicker()
end

function pickerUpButton:OnClick()
	ScrollPicker(-CONFIG.PICKER_COLUMNS)
end
pickerUpButton:SetHandler("OnClick", pickerUpButton.OnClick)

function pickerDownButton:OnClick()
	ScrollPicker(CONFIG.PICKER_COLUMNS)
end
pickerDownButton:SetHandler("OnClick", pickerDownButton.OnClick)

local function AttachPickerSearchHandlers(searchBox)
	if searchBox == nil then
		return
	end
	searchBox:SetHandler("OnTextChanged", OnPickerSearchChanged)
	searchBox:SetHandler("OnTextChange", OnPickerSearchChanged)
	SafeMethod(searchBox, "SetHandler", "OnEditTextChanged", OnPickerSearchChanged)
	SafeMethod(searchBox, "SetHandler", "OnChanged", OnPickerSearchChanged)
	SafeMethod(searchBox, "SetHandler", "OnChar", OnPickerSearchChar)
	SafeMethod(searchBox, "SetHandler", "OnTextInput", OnPickerSearchChar)
	SafeMethod(searchBox, "SetHandler", "OnInput", OnPickerSearchChar)
	SafeMethod(searchBox, "SetHandler", "OnKeyUp", OnPickerSearchKey)
	searchBox:SetHandler("OnMouseWheel", OnPickerSearchMouseWheel)
		-- Reuses the picker search box when available, creating it only if the widget is missing.
	searchBox:SetHandler("OnWheel", OnPickerSearchMouseWheel)
end

AttachPickerSearchHandlers(pickerSearchBox)

function runtime:CopyTrackedItem(item)
	return CopyTrackedItemData(item)
end

function runtime:LoadTrackedItemSets()
	self.trackedItemSets = {}
	self.trackedItemSetsLoaded = true
	self.trackedItemSetsTruncated = false
	local ok, data = pcall(function()
		return ADDON:LoadData(CONFIG.SETS_KEY)
	end)
	if not ok or type(data) ~= "table" then
		return
	end

	local loadedCount = 0
	for setName, setData in pairs(data) do
		if loadedCount >= CONFIG.MAX_TRACKED_SET_COUNT then
			self.trackedItemSetsTruncated = true
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

			local slotCount = math.floor(tonumber(setData.slotCount or setData.count) or TRACKED_SLOT_COUNT)
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

function runtime:GetTrackedSetDisplayName(setName)
	self:EnsureTrackedItemSetsLoaded()
	local setData = self.trackedItemSets[setName]
	if type(setData) == "table" then
		local displayName = Trim(setData.name or setData.displayName)
		if displayName ~= "" then
			return displayName
		end
	end
	return tostring(setName or "")
end

function runtime:FindTrackedSetKeyByName(setName)
	self:EnsureTrackedItemSetsLoaded()
	local exactName = Trim(setName)
	if exactName == "" then
		return nil
	end
	if self.trackedItemSets[exactName] ~= nil then
		return exactName
	end

	local lookupName = string.lower(exactName)
	for savedName, setData in pairs(self.trackedItemSets or {}) do
		if string.lower(Trim(savedName)) == lookupName then
			return savedName
		end
		if type(setData) == "table" and string.lower(Trim(setData.name or setData.displayName)) == lookupName then
			return savedName
		end
	end
	return nil
end

function runtime:GetSortedTrackedSetNames()
	self:EnsureTrackedItemSetsLoaded()
	local names = {}
	for setName, _ in pairs(self.trackedItemSets or {}) do
		names[#names + 1] = setName
	end
	table.sort(names, function(left, right)
		local leftDisplay = string.lower(self:GetTrackedSetDisplayName(left))
		local rightDisplay = string.lower(self:GetTrackedSetDisplayName(right))
		if leftDisplay == rightDisplay then
			return tostring(left) < tostring(right)
		end
		return leftDisplay < rightDisplay
	end)
	return names
end

function runtime:GetTrackedSetItemCount(setData)
	local count = 0
	if type(setData) ~= "table" or type(setData.items) ~= "table" then
		return count
	end
	for _, item in pairs(setData.items) do
		if type(item) == "table" and item.name ~= nil then
			count = count + 1
		end
	end
	return count
end

function runtime:CaptureTrackedSet()
	local captured = {
		slotCount = TRACKED_SLOT_COUNT,
		items = {},
	}
	local itemCount = 0
	for index = 1, TRACKED_SLOT_COUNT do
		local copied = self:CopyTrackedItem(trackedItems[index])
		if copied ~= nil then
			captured.items[index] = copied
			itemCount = itemCount + 1
		end
	end
	return captured, itemCount
end

function runtime:GetTrackerSetNameDisplayText(setName)
	local text = self:GetTrackedSetDisplayName(setName)
	local maxChars = math.floor(CONFIG.SET_NAME_TEXT_MAX_WIDTH / CONFIG.SET_NAME_CHAR_WIDTH)
	if maxChars < 4 or string.len(text) <= maxChars then
		return text
	end
	return string.sub(text, 1, maxChars - 3) .. "..."
end

function runtime:GetTrackerSetWindowHeight(setCount)
	local rowsHeight = 0
	if setCount > 0 then
		rowsHeight = (setCount * CONFIG.SET_ROW_HEIGHT) + ((setCount - 1) * CONFIG.SET_ROW_GAP)
	end

	local height = CONFIG.SET_ROW_TOP + rowsHeight + CONFIG.SET_WINDOW_PADDING
	if height < CONFIG.SET_WINDOW_MIN_HEIGHT then
		return CONFIG.SET_WINDOW_MIN_HEIGHT
	end
	return height
end

function runtime:UpdateTrackerSetWindowSize(setCount)
	if self.setWindow == nil then
		return
	end
	local height = self:GetTrackerSetWindowHeight(setCount or 0)
	self.setWindow:SetExtent(CONFIG.SET_WINDOW_WIDTH, height)
	if self.setWindow.statusLabel ~= nil then
		self.setWindow.statusLabel:RemoveAllAnchors()
		self.setWindow.statusLabel:AddAnchor("TOP", self.setWindow, 0, height + CONFIG.SET_STATUS_OUTSIDE_GAP)
	end
end

function runtime:SetTrackerSetStatus(message, red, green, blue)
	if self.setWindow == nil or self.setWindow.statusLabel == nil then
		return
	end
	local text = tostring(message or "")
	self.setWindow.statusLabel:SetText(text)
	if self.setWindow.statusLabel.style ~= nil then
		self.setWindow.statusLabel.style:SetColor(red or 0.9, green or 0.86, blue or 0.66, 1)
	end
	self.setWindow.statusLabel:Show(text ~= "")
end

function runtime:SyncSetNameInputWidgetText(text, clearWhenEmpty)
	local value = tostring(text or "")
	local input = self.setNameInput
	if input == nil then
		return
	end

	self.setNameInputSyncingText = true
	SafeMethod(input, "SetText", value)
	SafeMethod(input, "SetInputText", value)
	SafeMethod(input, "SetEditText", value)
	SafeMethod(input, "SetDisplayText", value)
	SafeMethod(input, "SetString", value)
	if clearWhenEmpty == true and value == "" then
		SafeMethod(input, "ClearText")
		SafeMethod(input, "ClearInputText")
		SafeMethod(input, "ClearEditText")
	end
	self.setNameInputSyncingText = false
end

function runtime:ReadSetNameInputWidgetText()
	local input = self.setNameInput
	if input == nil then
		return self.setNameText or ""
	end

	local getters = {
		"GetText",
		"GetInputText",
		"GetEditText",
		"GetDisplayText",
		"GetString",
	}
	for _, methodName in ipairs(getters) do
		local fn = input[methodName]
		if type(fn) == "function" then
			local ok, value = pcall(fn, input)
			if ok and type(value) == "string" then
				return value
			end
		end
	end
	return self.setNameText or ""
end

function runtime:SyncSetNameInputStateFromWidget()
	if self.setNameInputSyncingText == true then
		return
	end
	self.setNameText = tostring(self:ReadSetNameInputWidgetText() or "")
end

function runtime:ApplySetNameInputText(text)
	local value = tostring(text or "")
	self.setNameText = value
	self:SyncSetNameInputWidgetText(value, false)
end

function runtime:SyncSetNameInputText(text)
	local value = tostring(text or "")
	self:ApplySetNameInputText(value)

	self:SyncSetNameInputWidgetText(value, value == "")
	if self.setNameInput == nil then
		return
	end
	if value == "" then
		SafeMethod(self.setNameInput, "ClearFocus")
		SafeMethod(self.setNameInput, "SetFocus", false)
	end
end

function runtime:ReadSetNameInput()
	self:SyncSetNameInputStateFromWidget()
	return Trim(self.setNameText)
end

function runtime:ApplyTrackedSet(setName)
	self:EnsureTrackedItemSetsLoaded()
	local setData = self.trackedItemSets[setName]
	if type(setData) ~= "table" then
		self:SetTrackerSetStatus("Set not found.", 1, 0.58, 0.45)
		return
	end
	local displayName = self:GetTrackedSetDisplayName(setName)

	local slotCount = math.floor(tonumber(setData.slotCount) or TRACKED_SLOT_COUNT)
	if slotCount < 1 then
		slotCount = 1
	elseif slotCount > 20 then
		slotCount = 20
	end

	if self.ChangeSlotCount ~= nil and slotCount ~= TRACKED_SLOT_COUNT then
		self:ChangeSlotCount(slotCount - TRACKED_SLOT_COUNT, {
			skipSave = true,
			skipLayout = true,
			skipRefresh = true,
		})
	end

	for index = 1, 20 do
		trackedItems[index] = nil
	end

	local items = setData.items or {}
	for index = 1, slotCount do
		local copied = self:CopyTrackedItem(items[index] or items[tostring(index)])
		if copied ~= nil then
			trackedItems[index] = copied
		end
	end

	self.selectedSetName = setName
	self:SaveSlotCount()
	SaveTrackedItems()
	MarkInventoryDirty(true)
	if ApplyTrackerLayout ~= nil then
		ApplyTrackerLayout()
	end
	UpdateRows()
	self:UpdateTrackerSetList()
	self:SetTrackerSetStatus("Swapped " .. displayName .. ".", 0.62, 1, 0.62)
end

function runtime:SaveNamedTrackedSet(overwrite)
	self:EnsureTrackedItemSetsLoaded()
	local setName = self:ReadSetNameInput()
	local displayName = setName
	local existingSetName = nil
	if overwrite == true and self.selectedSetName ~= nil and self.trackedItemSets[self.selectedSetName] ~= nil then
		existingSetName = self.selectedSetName
		setName = existingSetName
		displayName = self:GetTrackedSetDisplayName(existingSetName)
	elseif setName == "" then
		if overwrite == true then
			self:SetTrackerSetStatus("Select a set or enter a name.", 1, 0.72, 0.42)
		else
			self:SetTrackerSetStatus("Enter a set name.", 1, 0.72, 0.42)
		end
		return
	end

	if existingSetName == nil then
		existingSetName = self:FindTrackedSetKeyByName(setName)
	end
	if existingSetName ~= nil and overwrite ~= true then
		self.selectedSetName = existingSetName
		self:SyncSetNameInputText(self:GetTrackedSetDisplayName(existingSetName))
		self:UpdateTrackerSetList()
		self:SetTrackerSetStatus("Set exists. Use Overwrite.", 1, 0.72, 0.42)
		return
	end
	if existingSetName == nil and self:GetTrackedSetCount() >= CONFIG.MAX_TRACKED_SET_COUNT then
		self:SetTrackerSetStatus("Set limit reached.", 1, 0.58, 0.45)
		return
	end

	local captured, itemCount = self:CaptureTrackedSet()
	if itemCount == 0 then
		self:SetTrackerSetStatus("No tracked items to save.", 1, 0.58, 0.45)
		return
	end

	captured.name = displayName
	if existingSetName ~= nil and existingSetName ~= setName then
		self.trackedItemSets[existingSetName] = nil
	end
	self.trackedItemSets[setName] = captured
	self.selectedSetName = setName
	if not self:SaveTrackedItemSets() then
		self:SetTrackerSetStatus("Save failed.", 1, 0.58, 0.45)
		return
	end

	self:UpdateTrackerSetList()
	self:SyncSetNameInputText("")
	self:SetTrackerSetStatus("Saved " .. displayName .. " (" .. tostring(itemCount) .. " items).", 0.62, 1, 0.62)
end

function runtime:DeleteNamedTrackedSet(setName)
	self:EnsureTrackedItemSetsLoaded()
	local name = Trim(setName or self:ReadSetNameInput())
	local savedName = self:FindTrackedSetKeyByName(name)
	if savedName == nil and name == "" then
		savedName = self.selectedSetName
	end
	if savedName == nil or self.trackedItemSets[savedName] == nil then
		self:SetTrackerSetStatus("Set not found.", 1, 0.58, 0.45)
		return
	end

	local displayName = self:GetTrackedSetDisplayName(savedName)
	self.trackedItemSets[savedName] = nil
	if self.selectedSetName == savedName then
		self.selectedSetName = nil
	end
	self:SaveTrackedItemSets()
	self:SyncSetNameInputText("")
	self:UpdateTrackerSetList()
	self:SetTrackerSetStatus("Deleted " .. displayName .. ".", 0.95, 0.86, 0.6)
end

function runtime:CreateTrackerSetRow(index)
	local row = self.setWindow:CreateChildWidget("button", "lootTrackerSetRow" .. tostring(index), 0, true)
	row:SetText("")
	row:SetStyle("text_default")
	row:SetExtent(CONFIG.SET_WINDOW_CONTENT_WIDTH, CONFIG.SET_ROW_HEIGHT)
	row.index = index

	local rowBackground = row:CreateColorDrawable(0.08, 0.08, 0.09, 0.72, "background")
	rowBackground:AddAnchor("TOPLEFT", row, 0, 0)
	rowBackground:AddAnchor("BOTTOMRIGHT", row, 0, 0)
	row.background = rowBackground

	local nameLabel = row:CreateChildWidget("label", "lootTrackerSetRowName" .. tostring(index), 0, true)
	nameLabel:SetText("")
	nameLabel:SetExtent(CONFIG.SET_NAME_TEXT_MAX_WIDTH, 20)
	nameLabel.style:SetAlign(ALIGN_LEFT)
	nameLabel.style:SetFontSize(11)
	nameLabel.style:SetColor(0.98, 0.98, 0.98, 1)
	nameLabel.style:SetOutline(true)
	nameLabel:AddAnchor("LEFT", row, 8, 0)
	SafeMethod(nameLabel, "EnablePick", false)
	row.nameLabel = nameLabel

	local countLabel = row:CreateChildWidget("label", "lootTrackerSetRowCount" .. tostring(index), 0, true)
	countLabel:SetText("")
	countLabel:SetExtent(28, 20)
	countLabel.style:SetAlign(ALIGN_RIGHT)
	countLabel.style:SetFontSize(10)
	countLabel.style:SetColor(0.92, 0.86, 0.62, 1)
	countLabel.style:SetOutline(true)
	countLabel:AddAnchor("RIGHT", row, -8, 0)
	SafeMethod(countLabel, "EnablePick", false)
	row.countLabel = countLabel

	function row:OnClick()
		if self.setName ~= nil then
			runtime:ApplyTrackedSet(self.setName)
		end
	end
	row:SetHandler("OnClick", row.OnClick)

	function row:OnMouseWheel(delta)
		runtime:ScrollTrackerSetList(delta)
	end
	row:SetHandler("OnMouseWheel", row.OnMouseWheel)
	row:SetHandler("OnWheel", row.OnMouseWheel)

	row:Show(false)
	self.trackerSetRows[index] = row
	return row
end

function runtime:UpdateTrackerSetList()
	if self.setWindow == nil then
		return
	end

	local names = self:GetSortedTrackedSetNames()
	local total = #names
	local visibleCount = total
	if visibleCount > CONFIG.SET_VISIBLE_ROWS then
		visibleCount = CONFIG.SET_VISIBLE_ROWS
	end
	local maxStart = total - visibleCount + 1
	if maxStart < 1 then
		maxStart = 1
	end
	self.setListScrollIndex = math.floor(tonumber(self.setListScrollIndex) or 1)
	if self.setListScrollIndex < 1 then
		self.setListScrollIndex = 1
	elseif self.setListScrollIndex > maxStart then
		self.setListScrollIndex = maxStart
	end
	self:UpdateTrackerSetWindowSize(visibleCount)

	for rowIndex = 1, visibleCount do
		local setName = names[self.setListScrollIndex + rowIndex - 1]
		local row = self.trackerSetRows[rowIndex]
		if row == nil then
			row = self:CreateTrackerSetRow(rowIndex)
		end

		row.setName = setName
		row:RemoveAllAnchors()
		row:AddAnchor(
			"TOPLEFT",
			self.setWindow,
			CONFIG.SET_WINDOW_PADDING,
			CONFIG.SET_ROW_TOP + ((rowIndex - 1) * (CONFIG.SET_ROW_HEIGHT + CONFIG.SET_ROW_GAP))
		)
		row:SetExtent(CONFIG.SET_WINDOW_CONTENT_WIDTH, CONFIG.SET_ROW_HEIGHT)
		row.nameLabel:SetText(self:GetTrackerSetNameDisplayText(setName))
		row.countLabel:SetText(tostring(self:GetTrackedSetItemCount(self.trackedItemSets[setName])))
		row:Show(true)

		if self.selectedSetName == setName then
			row.background:SetColor(0.92, 0.62, 0.18, 0.92)
		else
			row.background:SetColor(0.08, 0.08, 0.09, 0.72)
		end
	end

	for rowIndex = visibleCount + 1, #self.trackerSetRows do
		local row = self.trackerSetRows[rowIndex]
		if row ~= nil then
			row.setName = nil
			row:Show(false)
		end
	end
end

function runtime:ScrollTrackerSetList(delta)
	self:EnsureTrackedItemSetsLoaded()
	local amount = tonumber(delta) or 0
	if amount > 0 then
		self.setListScrollIndex = (self.setListScrollIndex or 1) - 1
	else
		self.setListScrollIndex = (self.setListScrollIndex or 1) + 1
	end
	self:UpdateTrackerSetList()
end

function runtime:CreateTrackerSetWindow()
	if self.setWindow ~= nil then
		return self.setWindow
	end
	self:EnsureTrackedItemSetsLoaded()

	_G.__LOOT_TRACKER_SET_NAME_INPUT_SERIAL = (_G.__LOOT_TRACKER_SET_NAME_INPUT_SERIAL or 0) + 1
	local window = CreateEmptyWindow("lootTrackerSetWindow", "UIParent")
	window:SetExtent(CONFIG.SET_WINDOW_WIDTH, CONFIG.SET_WINDOW_MIN_HEIGHT)
	window:EnableDrag(true)
	window:Clickable(true)
	window:Show(false)
	self.setWindow = window

	local defaultX, defaultY = GetWidgetSavedPosition(trackerWindow)
	if defaultX == nil then
		defaultX = 600
		defaultY = 320
	else
		defaultX = defaultX + GetTrackerWindowWidth() + 8
	end
	local savedX, savedY = LoadSavedPosition(CONFIG.SET_WINDOW_POSITION_KEY, defaultX, defaultY)
	window:AddAnchor("TOPLEFT", "UIParent", savedX, savedY)

	local background = window:CreateColorDrawable(0, 0, 0, 0.76, "background")
	background:AddAnchor("TOPLEFT", window, 0, 0)
	background:AddAnchor("BOTTOMRIGHT", window, 0, 0)

	local title = window:CreateChildWidget("label", "lootTrackerSetTitle", 0, true)
	title:SetText("Loot Sets")
	title:SetExtent(CONFIG.SET_WINDOW_CONTENT_WIDTH - 28, 22)
	title.style:SetAlign(ALIGN_LEFT)
	title.style:SetFontSize(13)
	title.style:SetColor(0.95, 0.92, 0.82, 1)
	title.style:SetOutline(true)
	title:AddAnchor("TOPLEFT", window, CONFIG.SET_WINDOW_PADDING, 8)
	SafeMethod(title, "EnableDrag", true)

	function title:OnDragStart()
		window:StartMoving()
	end
	title:SetHandler("OnDragStart", title.OnDragStart)

	function title:OnDragStop()
		window:StopMovingOrSizing()
		SaveWidgetPosition(window, CONFIG.SET_WINDOW_POSITION_KEY)
	end
	title:SetHandler("OnDragStop", title.OnDragStop)

	local closeButton = window:CreateChildWidget("button", "lootTrackerSetCloseButton", 0, true)
	closeButton:SetStyle("text_default")
	closeButton:SetText("X")
	closeButton:SetExtent(24, 22)
	closeButton:AddAnchor("TOPRIGHT", window, -CONFIG.SET_WINDOW_PADDING, 6)

	function closeButton:OnClick()
		runtime:CloseTrackerSetWindow()
	end
	closeButton:SetHandler("OnClick", closeButton.OnClick)

	local inputBackground = window:CreateColorDrawable(1, 1, 1, 0.18, "background")
	inputBackground:AddAnchor("TOPLEFT", window, CONFIG.SET_WINDOW_PADDING, 36)
	inputBackground:SetExtent(CONFIG.SET_WINDOW_CONTENT_WIDTH, 26)
	window.nameInputBackground = inputBackground

	local nameInput = window:CreateChildWidgetByType(
		UOT_X2_EDITBOX,
		"lootTrackerSetNameInput" .. tostring(_G.__LOOT_TRACKER_SET_NAME_INPUT_SERIAL),
		0,
		true
	)
	nameInput:AddAnchor("TOPLEFT", window, CONFIG.SET_WINDOW_PADDING + 5, 40)
	nameInput:SetHeight(18)
	nameInput:SetWidth(CONFIG.SET_WINDOW_CONTENT_WIDTH - 10)
	nameInput:SetText("")
	SafeMethod(nameInput, "SetMaxTextLength", 32)
	SafeMethod(nameInput, "SetInset", 5, 5, 5, 5)
	SafeMethod(nameInput, "EnableFocus", true)
	SafeMethod(nameInput, "UseSelectAllWhenFocused", true)
	SafeMethod(nameInput, "Enable", true)
	SafeMethod(nameInput, "Show", true)
	SafeMethod(nameInput, "SetVisible", true)
	SafeMethod(nameInput, "Clickable", true)
	SafeMethod(nameInput, "EnableInput", true)
	SafeMethod(nameInput, "SetInputEnabled", true)
	SafeMethod(nameInput, "EnableHitTest", true)
	SafeMethod(nameInput, "SetHitTestEnabled", true)
	if nameInput.style ~= nil then
		nameInput.style:SetAlign(ALIGN_LEFT)
		nameInput.style:SetFontSize(13)
		nameInput.style:SetColor(0.05, 0.06, 0.05, 1)
	end
	self.setNameInput = nameInput

	local function ActivateNameInput()
		if window.nameInputBackground ~= nil then
			window.nameInputBackground:SetColor(0.95, 0.74, 0.32, 0.46)
		end
		runtime:SyncSetNameInputStateFromWidget()
		SafeMethod(nameInput, "SetFocus")
		SafeMethod(nameInput, "SetFocus", true)
	end

	local function OnSetNameTextChanged()
		if runtime.setNameInputSyncingText == true then
			return
		end
		runtime:SyncSetNameInputStateFromWidget()
	end

	SafeMethod(nameInput, "SetHandler", "OnClick", ActivateNameInput)
	SafeMethod(nameInput, "SetHandler", "OnMouseDown", ActivateNameInput)
	SafeMethod(nameInput, "SetHandler", "OnMouseUp", ActivateNameInput)
	SafeMethod(nameInput, "SetHandler", "OnLButtonDown", ActivateNameInput)
	SafeMethod(nameInput, "SetHandler", "OnLButtonUp", ActivateNameInput)
	SafeMethod(nameInput, "SetHandler", "OnLeftButtonDown", ActivateNameInput)
	SafeMethod(nameInput, "SetHandler", "OnLeftButtonUp", ActivateNameInput)
	SafeMethod(nameInput, "SetHandler", "OnDoubleClick", ActivateNameInput)
	SafeMethod(nameInput, "SetHandler", "OnDoubleClicked", ActivateNameInput)
	SafeMethod(nameInput, "SetHandler", "OnTextChanged", OnSetNameTextChanged)
	SafeMethod(nameInput, "SetHandler", "OnTextChange", OnSetNameTextChanged)
	SafeMethod(nameInput, "SetHandler", "OnEditTextChanged", OnSetNameTextChanged)
	SafeMethod(nameInput, "SetHandler", "OnChanged", OnSetNameTextChanged)
	SafeMethod(nameInput, "SetHandler", "OnEditFocusLost", OnSetNameTextChanged)

	function runtime:ConfigureSetNameInput(input)
		if input == nil then
			return
		end
		input:AddAnchor("TOPLEFT", window, CONFIG.SET_WINDOW_PADDING + 5, 40)
		input:SetHeight(18)
		input:SetWidth(CONFIG.SET_WINDOW_CONTENT_WIDTH - 10)
		input:SetText("")
		SafeMethod(input, "SetMaxTextLength", 32)
		SafeMethod(input, "SetInset", 5, 5, 5, 5)
		SafeMethod(input, "EnableFocus", true)
		SafeMethod(input, "UseSelectAllWhenFocused", true)
		SafeMethod(input, "Enable", true)
		SafeMethod(input, "Show", true)
		SafeMethod(input, "SetVisible", true)
		SafeMethod(input, "Clickable", true)
		SafeMethod(input, "EnableInput", true)
		SafeMethod(input, "SetInputEnabled", true)
		SafeMethod(input, "EnableHitTest", true)
		SafeMethod(input, "SetHitTestEnabled", true)
		if input.style ~= nil then
			input.style:SetAlign(ALIGN_LEFT)
			input.style:SetFontSize(13)
			input.style:SetColor(0.05, 0.06, 0.05, 1)
		end
		SafeMethod(input, "SetHandler", "OnClick", ActivateNameInput)
		SafeMethod(input, "SetHandler", "OnMouseDown", ActivateNameInput)
		SafeMethod(input, "SetHandler", "OnMouseUp", ActivateNameInput)
		SafeMethod(input, "SetHandler", "OnLButtonDown", ActivateNameInput)
		SafeMethod(input, "SetHandler", "OnLButtonUp", ActivateNameInput)
		SafeMethod(input, "SetHandler", "OnLeftButtonDown", ActivateNameInput)
		SafeMethod(input, "SetHandler", "OnLeftButtonUp", ActivateNameInput)
		SafeMethod(input, "SetHandler", "OnDoubleClick", ActivateNameInput)
		SafeMethod(input, "SetHandler", "OnDoubleClicked", ActivateNameInput)
		SafeMethod(input, "SetHandler", "OnTextChanged", OnSetNameTextChanged)
		SafeMethod(input, "SetHandler", "OnTextChange", OnSetNameTextChanged)
		SafeMethod(input, "SetHandler", "OnEditTextChanged", OnSetNameTextChanged)
		SafeMethod(input, "SetHandler", "OnChanged", OnSetNameTextChanged)
		SafeMethod(input, "SetHandler", "OnEditFocusLost", OnSetNameTextChanged)
	end

	function runtime:RecreateSetNameInput()
		local oldInput = self.setNameInput
		if oldInput ~= nil then
			SafeMethod(oldInput, "ClearText")
			SafeMethod(oldInput, "ClearInputText")
			SafeMethod(oldInput, "ClearEditText")
			SafeMethod(oldInput, "ClearFocus")
			SafeMethod(oldInput, "SetFocus", false)
			SafeMethod(oldInput, "Show", false)
			SafeMethod(oldInput, "SetVisible", false)
			SafeMethod(oldInput, "ReleaseHandler", "OnClick")
			SafeMethod(oldInput, "ReleaseHandler", "OnMouseDown")
			SafeMethod(oldInput, "ReleaseHandler", "OnMouseUp")
			SafeMethod(oldInput, "ReleaseHandler", "OnLButtonDown")
			SafeMethod(oldInput, "ReleaseHandler", "OnLButtonUp")
			SafeMethod(oldInput, "ReleaseHandler", "OnLeftButtonDown")
			SafeMethod(oldInput, "ReleaseHandler", "OnLeftButtonUp")
			SafeMethod(oldInput, "ReleaseHandler", "OnDoubleClick")
			SafeMethod(oldInput, "ReleaseHandler", "OnDoubleClicked")
			SafeMethod(oldInput, "ReleaseHandler", "OnChar")
			SafeMethod(oldInput, "ReleaseHandler", "OnTextInput")
			SafeMethod(oldInput, "ReleaseHandler", "OnInput")
			SafeMethod(oldInput, "ReleaseHandler", "OnTextChanged")
			SafeMethod(oldInput, "ReleaseHandler", "OnTextChange")
			SafeMethod(oldInput, "ReleaseHandler", "OnEditTextChanged")
			SafeMethod(oldInput, "ReleaseHandler", "OnChanged")
			SafeMethod(oldInput, "ReleaseHandler", "OnEditFocusLost")
			SafeMethod(oldInput, "ReleaseHandler", "OnKeyDown")
			SafeMethod(oldInput, "ReleaseHandler", "OnRawKeyDown")
			SafeMethod(oldInput, "ReleaseHandler", "OnKeyUp")
			SafeMethod(oldInput, "ReleaseHandler", "OnRawKeyUp")
		end

		_G.__LOOT_TRACKER_SET_NAME_INPUT_SERIAL = (_G.__LOOT_TRACKER_SET_NAME_INPUT_SERIAL or 0) + 1
		nameInput = window:CreateChildWidgetByType(
			UOT_X2_EDITBOX,
			"lootTrackerSetNameInput" .. tostring(_G.__LOOT_TRACKER_SET_NAME_INPUT_SERIAL),
			0,
			true
		)
		self.setNameInput = nameInput
		self:ConfigureSetNameInput(nameInput)
		if window.nameInputBackground ~= nil then
			window.nameInputBackground:SetColor(1, 1, 1, 0.18)
		end
		self:SyncSetNameInputText("")
		return nameInput
	end

	local saveButton = window:CreateChildWidget("button", "lootTrackerSetSaveButton", 0, true)
	saveButton:SetStyle("text_default")
	saveButton:SetText("Save")
	saveButton:SetExtent(CONFIG.SET_SAVE_BUTTON_WIDTH, CONFIG.SET_ACTION_BUTTON_HEIGHT)
	saveButton:AddAnchor("TOPLEFT", window, CONFIG.SET_WINDOW_PADDING, 70)

	function saveButton:OnClick()
		runtime:SaveNamedTrackedSet(false)
	end
	saveButton:SetHandler("OnClick", saveButton.OnClick)

	local overwriteButton = window:CreateChildWidget("button", "lootTrackerSetOverwriteButton", 0, true)
	overwriteButton:SetStyle("text_default")
	overwriteButton:SetText("Overwrite")
	overwriteButton:SetExtent(CONFIG.SET_OVERWRITE_BUTTON_WIDTH, CONFIG.SET_ACTION_BUTTON_HEIGHT)
	overwriteButton:AddAnchor("TOPLEFT", window, CONFIG.SET_WINDOW_PADDING + CONFIG.SET_SAVE_BUTTON_WIDTH + 6, 70)

	function overwriteButton:OnClick()
		runtime:SaveNamedTrackedSet(true)
	end
	overwriteButton:SetHandler("OnClick", overwriteButton.OnClick)

	local deleteButton = window:CreateChildWidget("button", "lootTrackerSetDeleteButton", 0, true)
	deleteButton:SetStyle("text_default")
	deleteButton:SetText("Del")
	deleteButton:SetExtent(CONFIG.SET_DELETE_BUTTON_WIDTH, CONFIG.SET_ACTION_BUTTON_HEIGHT)
	deleteButton:AddAnchor(
		"TOPLEFT",
		window,
		CONFIG.SET_WINDOW_PADDING + CONFIG.SET_SAVE_BUTTON_WIDTH + CONFIG.SET_OVERWRITE_BUTTON_WIDTH + 12,
		70
	)

	function deleteButton:OnClick()
		runtime:DeleteNamedTrackedSet()
	end
	deleteButton:SetHandler("OnClick", deleteButton.OnClick)

	local statusLabel = window:CreateChildWidget("label", "lootTrackerSetStatus", 0, true)
	statusLabel:SetText("")
	statusLabel:SetExtent(CONFIG.SET_WINDOW_CONTENT_WIDTH, 20)
	statusLabel.style:SetAlign(ALIGN_CENTER)
	statusLabel.style:SetFontSize(10)
	statusLabel.style:SetColor(0.9, 0.86, 0.66, 1)
	statusLabel.style:SetOutline(true)
	statusLabel:AddAnchor("TOP", window, 0, CONFIG.SET_WINDOW_MIN_HEIGHT + CONFIG.SET_STATUS_OUTSIDE_GAP)
	statusLabel:Show(false)
	window.statusLabel = statusLabel

	function window:OnDragStart()
		self:StartMoving()
	end
	window:SetHandler("OnDragStart", window.OnDragStart)

	function window:OnDragStop()
		self:StopMovingOrSizing()
		SaveWidgetPosition(self, CONFIG.SET_WINDOW_POSITION_KEY)
	end
	window:SetHandler("OnDragStop", window.OnDragStop)

	function window:OnMouseWheel(delta)
		runtime:ScrollTrackerSetList(delta)
	end
	window:SetHandler("OnMouseWheel", window.OnMouseWheel)
	window:SetHandler("OnWheel", window.OnMouseWheel)

	self:UpdateTrackerSetList()
	return window
end

function runtime:OpenTrackerSetWindow()
	self:EnsureTrackedItemSetsLoaded()
	if self.setWindow == nil then
		self:CreateTrackerSetWindow()
	end
	self:UpdateTrackerSetList()
	self.setWindow:Show(true)
end

function runtime:CloseTrackerSetWindow()
	if self.setWindow == nil then
		return
	end
	SaveWidgetPosition(self.setWindow, CONFIG.SET_WINDOW_POSITION_KEY)
	self.setWindow:Show(false)
end

function runtime:ToggleTrackerSetWindow()
	if self.setWindow == nil then
		self:CreateTrackerSetWindow()
	end

	local visible = false
	if type(self.setWindow.IsVisible) == "function" then
		local ok, isVisible = pcall(self.setWindow.IsVisible, self.setWindow)
		visible = ok and isVisible == true
	end
	if visible then
		self:CloseTrackerSetWindow()
	else
		self:OpenTrackerSetWindow()
	end
end

RecreatePickerSearchBox = function()
	ClearPickerSearchState()

	if runtime.pickerSearchBox == nil then
		pickerSearchBox = pickerWindow:CreateChildWidget("editbox", NextPickerSearchBoxName(), 0, true)
	else
		pickerSearchBox = runtime.pickerSearchBox
	end
	runtime.pickerSearchBox = pickerSearchBox
	ConfigurePickerSearchBox(pickerSearchBox)
	AttachPickerSearchHandlers(pickerSearchBox)
	ClearPickerSearchState()
	return pickerSearchBox
end

for rowIndex = 1, CONFIG.PICKER_ROWS do
	for columnIndex = 1, CONFIG.PICKER_COLUMNS do
		local visibleIndex = ((rowIndex - 1) * CONFIG.PICKER_COLUMNS) + columnIndex
		local itemButton =
			pickerWindow:CreateChildWidget("button", "lootTrackerPickerItem" .. tostring(visibleIndex), 0, true)
		itemButton.index = visibleIndex
		itemButton:SetStyle("text_default")
		itemButton:SetText("")
		itemButton:SetExtent(CONFIG.PICKER_ITEM_WIDTH, CONFIG.PICKER_ITEM_HEIGHT)
		itemButton:AddAnchor(
			"TOPLEFT",
			pickerWindow,
			CONFIG.PADDING + ((columnIndex - 1) * (CONFIG.PICKER_ITEM_WIDTH + CONFIG.PICKER_ITEM_GAP_X)),
			CONFIG.PICKER_GRID_TOP + ((rowIndex - 1) * (CONFIG.PICKER_ITEM_HEIGHT + CONFIG.PICKER_ITEM_GAP_Y))
		)

		local itemBg = itemButton:CreateColorDrawable(0.06, 0.06, 0.07, 0.54, "background")
		itemBg:AddAnchor("TOPLEFT", itemButton, 0, 0)
		itemBg:SetExtent(CONFIG.PICKER_ITEM_WIDTH, CONFIG.PICKER_ITEM_HEIGHT)
		itemButton.bg = itemBg

		local itemHighlight = itemButton:CreateColorDrawable(1, 1, 1, 0.04, "overlay")
		itemHighlight:AddAnchor("TOPLEFT", itemButton, 0, 0)
		itemHighlight:SetExtent(CONFIG.PICKER_ITEM_WIDTH, 10)
		itemButton.highlight = itemHighlight

		local itemIcon = itemButton:CreateIconDrawable("artwork")
		itemIcon:SetExtent(28, 28)
		itemIcon:AddAnchor("LEFT", itemButton, 4, 0)
		HideIconDrawable(itemIcon)
		itemButton.iconDrawable = itemIcon

		local itemNameLabel =
			itemButton:CreateChildWidget("label", "lootTrackerPickerItemName" .. tostring(visibleIndex), 0, true)
		itemNameLabel:SetText("")
		itemNameLabel:SetExtent(CONFIG.PICKER_ITEM_WIDTH - 38, 18)
		itemNameLabel.style:SetAlign(ALIGN_LEFT)
		itemNameLabel.style:SetFontSize(10)
		itemNameLabel.style:SetColor(0.98, 0.98, 0.98, 1)
		itemNameLabel.style:SetOutline(true)
		itemNameLabel:AddAnchor("TOPLEFT", itemButton, 35, 3)
		SafeMethod(itemNameLabel, "EnablePick", false)
		itemButton.nameLabel = itemNameLabel

		local itemCountLabel =
			itemButton:CreateChildWidget("label", "lootTrackerPickerItemCount" .. tostring(visibleIndex), 0, true)
		itemCountLabel:SetText("")
		itemCountLabel:SetExtent(CONFIG.PICKER_ITEM_WIDTH - 38, 14)
		itemCountLabel.style:SetAlign(ALIGN_LEFT)
		itemCountLabel.style:SetFontSize(10)
		itemCountLabel.style:SetColor(0.92, 0.86, 0.62, 1)
		itemCountLabel.style:SetOutline(true)
		itemCountLabel:AddAnchor("BOTTOMLEFT", itemButton, 35, -2)
		SafeMethod(itemCountLabel, "EnablePick", false)
		itemButton.countLabel = itemCountLabel

		function itemButton:OnEnter()
		-- Handles mouse enter event on picker item button. Increases highlight opacity for visual feedback.
			if self.highlight ~= nil then
				self.highlight:SetColor(1, 1, 1, 0.11)
			end
		end
		itemButton:SetHandler("OnEnter", itemButton.OnEnter)

		function itemButton:OnLeave()
		-- Handles mouse leave event on picker item button. Reduces highlight opacity.
			if self.highlight ~= nil then
				self.highlight:SetColor(1, 1, 1, 0.04)
			end
		end
		itemButton:SetHandler("OnLeave", itemButton.OnLeave)

		function itemButton:OnClick()
		-- Handles click on a picker item button. Sets the selected item to the tracked slot, closes the picker, and updates rows.
			if self.itemData == nil or pickerSlotIndex == nil then
				return
			end
			SetTrackedItem(pickerSlotIndex, self.itemData)
			ClosePicker()
			UpdateRows()
		end
		itemButton:SetHandler("OnClick", itemButton.OnClick)

		function itemButton:OnMouseWheel(delta)
		-- Handles mouse wheel events on picker item buttons by delegating to the picker window's wheel handler.
			pickerWindow:OnMouseWheel(delta)
		end
		itemButton:SetHandler("OnMouseWheel", itemButton.OnMouseWheel)
		itemButton:SetHandler("OnWheel", itemButton.OnMouseWheel)

		pickerItemWidgets[visibleIndex] = itemButton
	end
end

function pickerWindow:OnHide()
	-- Handles the OnHide event for the picker window. Sets picker open flag to false and clears search state.
	isPickerOpen = false
	ClearPickerSearchState()
	HidePickerSearchBox()
end
pickerWindow:SetHandler("OnHide", pickerWindow.OnHide)

function pickerWindow:OnMouseWheel(delta)
	-- Handles the OnMouseWheel event for the picker window. Scrolls the picker items up or down based on wheel delta.
	local amount = tonumber(delta) or 0
	if amount > 0 then
		ScrollPicker(-CONFIG.PICKER_COLUMNS)
	else
		ScrollPicker(CONFIG.PICKER_COLUMNS)
	end
end
pickerWindow:SetHandler("OnMouseWheel", pickerWindow.OnMouseWheel)
pickerWindow:SetHandler("OnWheel", pickerWindow.OnMouseWheel)

function pickerWindow:OnDragStart()
	-- Handles the OnDragStart event for the picker window. Initiates moving the picker window.
	self:StartMoving()
end
pickerWindow:SetHandler("OnDragStart", pickerWindow.OnDragStart)

function pickerWindow:OnDragStop()
	-- Handles the OnDragStop event for the picker window. Stops moving/sizing and saves the picker window's position.
	self:StopMovingOrSizing()
	SavePickerWindowPosition(self)
end
pickerWindow:SetHandler("OnDragStop", pickerWindow.OnDragStop)

function trackerWindow:OnDragStart()
	-- Handles the OnDragStart event for the tracker window. Initiates moving the window.
	self:StartMoving()
end
trackerWindow:SetHandler("OnDragStart", trackerWindow.OnDragStart)

function trackerWindow:OnDragStop()
	-- Handles the OnDragStop event for the tracker window. Stops moving/sizing and saves the current window position to persistent storage.
	self:StopMovingOrSizing()
	SaveWindowPosition(self)
	if runtime.PositionResizeHandles ~= nil then
		runtime:PositionResizeHandles()
	end
end
trackerWindow:SetHandler("OnDragStop", trackerWindow.OnDragStop)

local watchedEvents = {
	BAG_UPDATE = true,
	BAG_EXPANDED = true,
	ADDED_ITEM = true,
	REMOVED_ITEM = true,
	ITEM_ACQUISITION_BY_LOOT = true,
	SHOW_ADDED_ITEM = true,
	CHAT_MESSAGE = true,
	CHAT_FAILED = true,
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
		CenterLootTrackerWindow()
	end
end

function trackerWindow:OnEvent(event)
	if watchedEvents[event] then
		MarkInventoryDirty(false)
	end
end
trackerWindow:SetHandler("OnEvent", trackerWindow.OnEvent)

for eventName, _ in pairs(watchedEvents) do
	if eventName ~= "CHAT_MESSAGE" and eventName ~= "CHAT_FAILED" then
		trackerWindow:RegisterEvent(eventName)
	end
end

local chatCommandListener = CreateEmptyWindow("lootTrackerChatCommandListener", "UIParent")
runtime.chatCommandListener = chatCommandListener
chatCommandListener:Show(false)

function chatCommandListener:OnEvent(event, ...)
	if event == "CHAT_MESSAGE" or event == "CHAT_FAILED" then
		HandleLootTrackerChatCommand(...)
	end
end
chatCommandListener:SetHandler("OnEvent", chatCommandListener.OnEvent)
chatCommandListener:RegisterEvent("CHAT_MESSAGE")
chatCommandListener:RegisterEvent("CHAT_FAILED")

local inventoryFallbackRefreshElapsed = 0
function trackerWindow:OnUpdate(dt)
	-- Handles the OnUpdate event for the tracker window. Performs periodic tasks such as inventory fallback refresh, picker search polling when open, and updating rows/picker when refreshRequested flag is set.
	if not runtime.active then
		return
	end

	local delta = NormalizeDt(dt)
	inventoryFallbackRefreshElapsed = inventoryFallbackRefreshElapsed + delta
	if inventoryRefreshPending then
		inventoryRefreshPendingElapsed = inventoryRefreshPendingElapsed + delta
		if inventoryRefreshPendingElapsed >= CONFIG.INVENTORY_EVENT_DEBOUNCE_SECONDS then
			inventoryRefreshPending = false
			inventoryRefreshPendingElapsed = 0
			refreshRequested = true
		end
	end
	if isPickerOpen and not IsPickerWindowVisible() then
		ClosePicker()
	end
	if isPickerOpen then
		pickerSearchPollElapsed = pickerSearchPollElapsed + delta
		if pickerSearchPollElapsed >= CONFIG.SEARCH_POLL_INTERVAL then
			pickerSearchPollElapsed = 0
			PollPickerSearchBox()
		end
	end

	if (IsTrackerWindowVisible() or IsPickerWindowVisible())
		and inventoryFallbackRefreshElapsed >= CONFIG.INVENTORY_FALLBACK_REFRESH_SECONDS
	then
		inventoryFallbackRefreshElapsed = 0
		MarkInventoryDirty(false)
	end

	runtime:UpdateAcquisitionGlows(delta)

	if refreshRequested then
		refreshRequested = false
		UpdateRows()
		if isPickerOpen and UpdatePicker ~= nil then
			UpdatePicker()
		end
	end
end
trackerWindow:SetHandler("OnUpdate", trackerWindow.OnUpdate)

UpdateRows()
