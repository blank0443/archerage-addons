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
	if previousRuntime.restoreButton ~= nil then
		previousRuntime.restoreButton:Show(false)
	end
	if previousRuntime.controlsRestoreButton ~= nil then
		previousRuntime.controlsRestoreButton:Show(false)
	end
	if previousRuntime.chatCommandListener ~= nil then
		previousRuntime.chatCommandListener:Show(false)
	end
end

local runtime = {
	active = true,
	window = nil,
	pickerWindow = nil,
	restoreButton = nil,
	chatCommandListener = nil,
}
_G.__LOOT_TRACKER_RUNTIME = runtime

local TRACKED_SLOT_COUNT = 5
local BAG_KIND = 1
local MAX_BAG_SLOTS = 150
local SAVE_KEY = "lootTrackerTrackedItems"
local POSITION_KEY = "lootTrackerWindowPosition"
local RESTORE_POSITION_KEY = "lootTrackerRestoreButtonPosition"
local PICKER_POSITION_KEY = "lootTrackerPickerWindowPosition"
local LAYOUT_KEY = "lootTrackerLayout"

local LAYOUT_HORIZONTAL = "horizontal"
local LAYOUT_VERTICAL = "vertical"
local RESTORE_BUTTON_WIDTH = 92
local RESTORE_BUTTON_HEIGHT = 22
local PADDING = 9
local TRACKER_PADDING = 4
local TRACKER_TOP_PADDING = 1
local HEADER_HEIGHT = 22
local HEADER_TITLE_WIDTH = 78
local HEADER_BUTTON_GAP = 4
local HEADER_BUTTON_HEIGHT = 18
local ROTATE_BUTTON_WIDTH = 24
local RESET_BUTTON_WIDTH = 24
local HIDE_WINDOW_BUTTON_WIDTH = 34
local BOX_SIZE = 40
local BOX_GAP = 6
local TRACKER_ROW_TOP_GAP = 3
local BOXES_TOP = TRACKER_TOP_PADDING + HEADER_HEIGHT + TRACKER_ROW_TOP_GAP
local VERTICAL_BOXES_TOP = TRACKER_TOP_PADDING + HEADER_HEIGHT + HEADER_BUTTON_GAP + (HEADER_BUTTON_HEIGHT * 3)
	+ (HEADER_BUTTON_GAP * 3)
	+ TRACKER_ROW_TOP_GAP

local PICKER_WIDTH = 330
local PICKER_HEIGHT = 328
local PICKER_COLUMNS = 3
local PICKER_ROWS = 5
local PICKER_VISIBLE_COUNT = PICKER_COLUMNS * PICKER_ROWS
local PICKER_ITEM_WIDTH = 96
local PICKER_ITEM_HEIGHT = 34
local PICKER_ITEM_GAP_X = 6
local PICKER_ITEM_GAP_Y = 6
local PICKER_SEARCH_TOP = 42
local PICKER_SEARCH_HEIGHT = 30
local PICKER_GRID_TOP = 84
local PICKER_CONTROL_TOP = PICKER_GRID_TOP + (PICKER_ROWS * (PICKER_ITEM_HEIGHT + PICKER_ITEM_GAP_Y))
local INVENTORY_FALLBACK_REFRESH_SECONDS = 2.0
local SEARCH_POLL_INTERVAL = 0.12

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
local trackerLayout = LAYOUT_HORIZONTAL
local restoreButtonPositionSaved = false
local pickerWindowPositionSaved = false
local trackerHeaderControlsVisible = true
local UpdatePicker
local RecreatePickerSearchBox
local ApplyTrackerLayout
local AnchorPickerWindow
local SetTrackerHeaderControlsVisible
local trackerWindow

local function SafeMethod(target, methodName, ...)
	-- Safely calls a method on target if it exists and is a function, using pcall to avoid errors.
	if target == nil then
		return false
	end
	local fn = target[methodName]
	if type(fn) ~= "function" then
		return false
	end
	return pcall(fn, target, ...)
end

	-- Normalizes delta time, converting milliseconds to seconds if value >10.
local function NormalizeDt(dt)
	local value = tonumber(dt) or 0
	if value > 10 then
		value = value / 1000
	end
	return value
end
	-- Trims leading and trailing whitespace from a string value.

local function Trim(value)
	local text = tostring(value or "")
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	return text
	-- Normalizes a name by trimming and lowercasing, collapsing multiple spaces to single.
end

local function NormalizeName(value)
	local text = string.lower(Trim(value))
	text = string.gsub(text, "%s+", " ")
	-- Extracts the item name from table using common field names.
	return text
end

local function ExtractItemName(item)
	if type(item) ~= "table" then
		return nil
	-- Extracts the item grade from table using common field names.
	end
	return item.name or item.itemName or item.item_name
end

local function ExtractItemGrade(item)
	if type(item) ~= "table" then
		return nil
	end
	return item.grade or item.itemGrade or item.item_grade
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
	-- Recursively extracts icon path from item table by trying common field names.
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
		return X2Bag:GetBagItemInfo(BAG_KIND, posInBag)
	end)
	if ok then
		return item
	end
	return nil
end

local function ReadInventory()
	local itemsByKey = {}
	local orderedItems = {}

	for posInBag = 1, MAX_BAG_SLOTS do
		local item = ReadBagItem(posInBag)
		local name = ExtractItemName(item)
		if name ~= nil and tostring(name) ~= "" then
			local grade = ExtractItemGrade(item)
			local iconPath = ExtractItemIconPath(item)
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
			elseif entry.iconPath == nil and iconPath ~= nil then
	-- Marks inventory as dirty and requests refresh.
				entry.iconPath = iconPath
			end

			entry.count = entry.count + count
	-- Returns cached inventory snapshot or refreshes if dirty or forced.
		end
	end

	return itemsByKey, orderedItems
end

local function MarkInventoryDirty()
	inventoryDirty = true
	refreshRequested = true
end

local function GetInventorySnapshot(forceRefresh)
	if forceRefresh or inventoryDirty or inventoryItemsByKey == nil or inventoryOrderedItems == nil then
		inventoryItemsByKey, inventoryOrderedItems = ReadInventory()
		inventoryDirty = false
	end
	return inventoryItemsByKey, inventoryOrderedItems
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
	if normalizedQuery == "" then
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
		ADDON:ClearData(SAVE_KEY)
		ADDON:SaveData(SAVE_KEY, data)
	end)
end

local function LoadTrackedItems()
	local ok, data = pcall(function()
		return ADDON:LoadData(SAVE_KEY)
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

	local offsetX, offsetY = widget:GetOffset()
	local uiScale = UIParent:GetUIScale() or 1.0
	return math.floor((offsetX * uiScale) + 0.5), math.floor((offsetY * uiScale) + 0.5)
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
	SaveWidgetPosition(window, POSITION_KEY)
end

local function SaveRestoreButtonPosition(button)
	SaveWidgetPosition(button, RESTORE_POSITION_KEY)
	restoreButtonPositionSaved = true
end

local function SavePickerWindowPosition(window)
	SaveWidgetPosition(window, PICKER_POSITION_KEY)
	pickerWindowPositionSaved = true
end

local function LoadWindowPosition()
	return LoadSavedPosition(POSITION_KEY, 420, 320)
end

local function LoadRestoreButtonPosition(defaultX, defaultY)
	return LoadSavedPosition(RESTORE_POSITION_KEY, defaultX, defaultY)
end

local function LoadPickerWindowPosition(defaultX, defaultY)
	return LoadSavedPosition(PICKER_POSITION_KEY, defaultX, defaultY)
end

local function NormalizeTrackerLayout(value)
	if value == LAYOUT_VERTICAL then
		return LAYOUT_VERTICAL
	end
	return LAYOUT_HORIZONTAL
end

local function SaveTrackerLayout()
	pcall(function()
		ADDON:ClearData(LAYOUT_KEY)
		ADDON:SaveData(LAYOUT_KEY, {
			layout = trackerLayout,
		})
	end)
end

local function LoadTrackerLayout()
	local ok, data = pcall(function()
		return ADDON:LoadData(LAYOUT_KEY)
	end)
	if ok then
		if type(data) == "table" then
			return NormalizeTrackerLayout(data.layout)
		end
		if type(data) == "string" then
			return NormalizeTrackerLayout(data)
		end
	end
	return LAYOUT_HORIZONTAL
end

local function GetTrackedRowsSpan()
	return (TRACKED_SLOT_COUNT * BOX_SIZE) + ((TRACKED_SLOT_COUNT - 1) * BOX_GAP)
end

local function GetTrackerWindowWidth()
	if trackerLayout == LAYOUT_VERTICAL then
		if not trackerHeaderControlsVisible then
			return BOX_SIZE + (TRACKER_PADDING * 2)
		end
		return HEADER_TITLE_WIDTH + (TRACKER_PADDING * 2)
	end
	return GetTrackedRowsSpan() + (TRACKER_PADDING * 2)
end

local function GetTrackedRowsLeft()
	if trackerLayout == LAYOUT_VERTICAL then
		return math.floor((GetTrackerWindowWidth() - BOX_SIZE) / 2)
	end
	return math.floor((GetTrackerWindowWidth() - GetTrackedRowsSpan()) / 2)
end

local function GetTrackedRowsTop()
	if not trackerHeaderControlsVisible then
		return TRACKER_TOP_PADDING
	end

	if trackerLayout == LAYOUT_VERTICAL then
		return VERTICAL_BOXES_TOP
	end
	return BOXES_TOP
end

local function GetTrackerWindowHeight()
	if trackerLayout == LAYOUT_VERTICAL then
		return GetTrackedRowsTop() + GetTrackedRowsSpan() + TRACKER_PADDING
	end
	return GetTrackedRowsTop() + BOX_SIZE + TRACKER_PADDING
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
	-- Removes the tracked item at the given index, saves, and requests refresh.
	end
end

local function RemoveTrackedItem(index)
	if trackedItems[index] == nil then
		return
	end
	trackedItems[index] = nil
	-- Sets the tracked item at index to the provided item data, saves, and requests refresh.
	SaveTrackedItems()
	refreshRequested = true
end

local function SetTrackedItem(index, item)
	if index == nil or item == nil then
		return
	end
	trackedItems[index] = {
		key = item.key,
		name = item.name,
		grade = item.grade,
		iconPath = item.iconPath,
	}
	SaveTrackedItems()
	refreshRequested = true
end

local UpdateRows

local function ResolveTrackedInventoryEntry(itemsByKey, tracked)
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

	for _, item in pairs(itemsByKey) do
		if NormalizeName(item.name) == trackedName then
			local gradeMatches = tracked.grade == nil or item.grade == tracked.grade
			local iconMatches = tracked.iconPath == nil or item.iconPath == nil or item.iconPath == tracked.iconPath
			if gradeMatches and iconMatches then
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
	-- Hides the picker search box and releases all its event handlers.

local function HidePickerSearchBox()
	if runtime.pickerSearchBox == nil then
		return
	end
	SafeMethod(runtime.pickerSearchBox, "Show", false)
	SafeMethod(runtime.pickerSearchBox, "SetVisible", false)
	SafeMethod(runtime.pickerSearchBox, "ReleaseHandler", "OnTextChanged")
	SafeMethod(runtime.pickerSearchBox, "ReleaseHandler", "OnTextChange")
	SafeMethod(runtime.pickerSearchBox, "ReleaseHandler", "OnEditTextChanged")
	SafeMethod(runtime.pickerSearchBox, "ReleaseHandler", "OnChanged")
	SafeMethod(runtime.pickerSearchBox, "ReleaseHandler", "OnChar")
	SafeMethod(runtime.pickerSearchBox, "ReleaseHandler", "OnTextInput")
	SafeMethod(runtime.pickerSearchBox, "ReleaseHandler", "OnInput")
	SafeMethod(runtime.pickerSearchBox, "ReleaseHandler", "OnKeyUp")
	SafeMethod(runtime.pickerSearchBox, "ReleaseHandler", "OnUpdate")
	SafeMethod(runtime.pickerSearchBox, "ReleaseHandler", "OnMouseWheel")
	SafeMethod(runtime.pickerSearchBox, "ReleaseHandler", "OnWheel")
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
	if mouseButton == "RightButton" then
		RemoveTrackedItem(rowIndex)
		UpdateRows()
	else
		OpenPicker(rowIndex)
	end
end

UpdateRows = function()
	-- Updates all tracked rows with current inventory counts or missing state from the snapshot.
	local itemsByKey = GetInventorySnapshot(false)

	for index = 1, TRACKED_SLOT_COUNT do
		local row = rowWidgets[index]
		local tracked = trackedItems[index]
		if tracked == nil then
			SetRowText(row, "", "", "empty", nil)
		else
			local current = ResolveTrackedInventoryEntry(itemsByKey, tracked)
			if current ~= nil then
				SetRowText(row, current.name, "x" .. tostring(current.count), "tracked", current.iconPath or tracked.iconPath)
			else
				SetRowText(row, tracked.name, "x0", "missing", tracked.iconPath)
			end
		end
	end
end

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
restoreButton:SetExtent(RESTORE_BUTTON_WIDTH, RESTORE_BUTTON_HEIGHT)
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
	restoreButton:Show(false)
	trackerWindow:Show(true)
	if SetTrackerHeaderControlsVisible ~= nil then
		SetTrackerHeaderControlsVisible(true)
	end
	MarkInventoryDirty()
	ApplyTrackerLayout()
	trackerWindow:RemoveAllAnchors()
	trackerWindow:AddAnchor("CENTER", "UIParent", 0, 0)
	SaveWindowPosition(trackerWindow)
	UpdateRows()
end
	-- Hides the loot tracker window, saves position, closes picker, shows restore button.

local function HideLootTrackerWindow()
	if SetTrackerHeaderControlsVisible ~= nil then
		SetTrackerHeaderControlsVisible(true)
	end
	SaveWindowPosition(trackerWindow)
	ClosePicker()
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
	MarkInventoryDirty()
	ApplyTrackerLayout()
	-- Shows the loot tracker window when restore button is clicked.
	UpdateRows()
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
headerLabel:SetExtent(HEADER_TITLE_WIDTH, HEADER_HEIGHT)
headerLabel.style:SetAlign(ALIGN_LEFT)
	-- Starts moving the tracker window when header is dragged.
headerLabel.style:SetFontSize(11)
headerLabel.style:SetColor(0.95, 0.92, 0.82, 1)
headerLabel.style:SetOutline(true)
headerLabel:AddAnchor("TOPLEFT", trackerWindow, TRACKER_PADDING, TRACKER_TOP_PADDING + 2)
SafeMethod(headerLabel, "EnableDrag", true)

	-- Stops moving the tracker window and saves position on header drag stop.
function headerLabel:OnDragStart()
	trackerWindow:StartMoving()
end
headerLabel:SetHandler("OnDragStart", headerLabel.OnDragStart)

function headerLabel:OnDragStop()
	trackerWindow:StopMovingOrSizing()
	SaveWindowPosition(trackerWindow)
end
headerLabel:SetHandler("OnDragStop", headerLabel.OnDragStop)
	-- Toggles the tracker layout when rotate button is clicked.

local ToggleTrackerLayout

local rotateButton = trackerWindow:CreateChildWidget("button", "lootTrackerRotateButton", 0, true)
rotateButton:SetStyle("text_default")
rotateButton:SetText("R")
rotateButton:SetExtent(ROTATE_BUTTON_WIDTH, 18)

function rotateButton:OnClick()
	-- Clears all tracked items when reset button is clicked.
	ToggleTrackerLayout()
end
rotateButton:SetHandler("OnClick", rotateButton.OnClick)

local resetButton = trackerWindow:CreateChildWidget("button", "lootTrackerResetButton", 0, true)
resetButton:SetStyle("text_default")
resetButton:SetText("C")
resetButton:SetExtent(RESET_BUTTON_WIDTH, 18)

	-- Hides the loot tracker window when hide button is clicked.
function resetButton:OnClick()
	ClearTrackedItems()
end
resetButton:SetHandler("OnClick", resetButton.OnClick)

local hideWindowButton = trackerWindow:CreateChildWidget("button", "lootTrackerHideWindowButton", 0, true)
hideWindowButton:SetStyle("text_default")
hideWindowButton:SetText("X")
hideWindowButton:SetExtent(HIDE_WINDOW_BUTTON_WIDTH, 18)

function hideWindowButton:OnClick()
	HideLootTrackerWindow()
end
hideWindowButton:SetHandler("OnClick", hideWindowButton.OnClick)

SetTrackerHeaderControlsVisible = function(visible)
	if trackerHeaderControlsVisible == visible then
		headerLabel:Show(visible)
		rotateButton:Show(visible)
		resetButton:Show(visible)
		hideWindowButton:Show(visible)
		return
	end

	local oldX, oldY = GetWidgetSavedPosition(trackerWindow)
	local oldRowsLeft = GetTrackedRowsLeft()
	local oldRowsTop = GetTrackedRowsTop()

	trackerHeaderControlsVisible = visible
	headerLabel:Show(visible)
	rotateButton:Show(visible)
	resetButton:Show(visible)
	hideWindowButton:Show(visible)
	if ApplyTrackerLayout ~= nil then
		ApplyTrackerLayout()
	end

	if oldX ~= nil and oldY ~= nil then
		AnchorWidgetAtSavedPosition(
			trackerWindow,
			oldX + oldRowsLeft - GetTrackedRowsLeft(),
			oldY + oldRowsTop - GetTrackedRowsTop()
		)
	end
end

local function ShowTrackerHeaderControls()
	SetTrackerHeaderControlsVisible(true)
end

local function HideTrackerHeaderControls()
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
hideWindowButton:SetHandler("OnEnter", ShowTrackerHeaderControls)

local function AnchorHeaderControls()
	-- Anchors the header label and control buttons (rotate, reset, hide) based on current tracker layout (horizontal or vertical).
	headerLabel:RemoveAllAnchors()
	headerLabel:SetExtent(HEADER_TITLE_WIDTH, HEADER_HEIGHT)
	headerLabel.style:SetAlign(ALIGN_LEFT)

	if trackerLayout == LAYOUT_VERTICAL then
		headerLabel:AddAnchor("TOP", trackerWindow, 0, TRACKER_TOP_PADDING + 2)
		headerLabel.style:SetAlign(ALIGN_CENTER)

		rotateButton:RemoveAllAnchors()
		rotateButton:AddAnchor("TOP", trackerWindow, 0, TRACKER_TOP_PADDING + HEADER_HEIGHT + HEADER_BUTTON_GAP)

		resetButton:RemoveAllAnchors()
		resetButton:AddAnchor(
			"TOP",
			trackerWindow,
			0,
			TRACKER_TOP_PADDING + HEADER_HEIGHT + HEADER_BUTTON_GAP + HEADER_BUTTON_HEIGHT + HEADER_BUTTON_GAP
		)

		hideWindowButton:RemoveAllAnchors()
		hideWindowButton:AddAnchor(
			"TOP",
			trackerWindow,
			0,
			TRACKER_TOP_PADDING + HEADER_HEIGHT + HEADER_BUTTON_GAP + (HEADER_BUTTON_HEIGHT * 2) + (HEADER_BUTTON_GAP * 2)
		)
		return
	end

	headerLabel:AddAnchor("TOPLEFT", trackerWindow, TRACKER_PADDING, TRACKER_TOP_PADDING + 2)

	hideWindowButton:RemoveAllAnchors()
	hideWindowButton:AddAnchor("TOPRIGHT", trackerWindow, -TRACKER_PADDING, TRACKER_TOP_PADDING + 1)

	resetButton:RemoveAllAnchors()
	resetButton:AddAnchor(
		"TOPRIGHT",
		trackerWindow,
		-TRACKER_PADDING - HIDE_WINDOW_BUTTON_WIDTH - HEADER_BUTTON_GAP,
		TRACKER_TOP_PADDING + 1
	)

	rotateButton:RemoveAllAnchors()
	rotateButton:AddAnchor(
		"TOPRIGHT",
		trackerWindow,
		-TRACKER_PADDING
			- HIDE_WINDOW_BUTTON_WIDTH
			- HEADER_BUTTON_GAP
			- RESET_BUTTON_WIDTH
			- HEADER_BUTTON_GAP,
		TRACKER_TOP_PADDING + 1
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
	for index = 1, TRACKED_SLOT_COUNT do
		local row = rowWidgets[index]
		if row ~= nil then
			local offsetX = GetTrackedRowsLeft() + ((index - 1) * (BOX_SIZE + BOX_GAP))
			local offsetY = GetTrackedRowsTop()

			if trackerLayout == LAYOUT_VERTICAL then
				offsetX = GetTrackedRowsLeft()
				offsetY = GetTrackedRowsTop() + ((index - 1) * (BOX_SIZE + BOX_GAP))
			end

			row:RemoveAllAnchors()
			row:AddAnchor("TOPLEFT", trackerWindow, offsetX, offsetY)
			row:SetExtent(BOX_SIZE, BOX_SIZE)
			if row.bg ~= nil then
				row.bg:SetExtent(BOX_SIZE, BOX_SIZE)
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
end

ToggleTrackerLayout = function()
	if trackerLayout == LAYOUT_VERTICAL then
		trackerLayout = LAYOUT_HORIZONTAL
	else
		trackerLayout = LAYOUT_VERTICAL
	end
	SaveTrackerLayout()
	ApplyTrackerLayout()
	refreshRequested = true
	UpdateRows()
end

for index = 1, TRACKED_SLOT_COUNT do
	local row = trackerWindow:CreateChildWidget("button", "lootTrackerRow" .. tostring(index), 0, true)
	row.index = index
	row:SetText("")
	row:SetExtent(BOX_SIZE, BOX_SIZE)
	row:AddAnchor(
		"TOPLEFT",
		trackerWindow,
		GetTrackedRowsLeft() + ((index - 1) * (BOX_SIZE + BOX_GAP)),
		GetTrackedRowsTop()
	)
	SafeMethod(row, "Clickable", true)

	local rowBackground = row:CreateColorDrawable(0.06, 0.06, 0.07, 0.64, "background")
	rowBackground:AddAnchor("TOPLEFT", row, 0, 0)
	rowBackground:SetExtent(BOX_SIZE, BOX_SIZE)
	row.bg = rowBackground

	local hoverTop = row:CreateColorDrawable(1, 0.86, 0.42, 0, "artwork")
	hoverTop:AddAnchor("TOPLEFT", row, 0, 0)
	hoverTop:SetExtent(BOX_SIZE, 1)

	local hoverBottom = row:CreateColorDrawable(1, 0.86, 0.42, 0, "artwork")
	hoverBottom:AddAnchor("BOTTOMLEFT", row, 0, 0)
	hoverBottom:SetExtent(BOX_SIZE, 1)

	local hoverLeft = row:CreateColorDrawable(1, 0.86, 0.42, 0, "artwork")
	hoverLeft:AddAnchor("TOPLEFT", row, 0, 0)
	hoverLeft:SetExtent(1, BOX_SIZE)

	local hoverRight = row:CreateColorDrawable(1, 0.86, 0.42, 0, "artwork")
	hoverRight:AddAnchor("TOPRIGHT", row, 0, 0)
	hoverRight:SetExtent(1, BOX_SIZE)

	row.hoverBorder = {
		hoverTop,
		hoverBottom,
		hoverLeft,
		hoverRight,
	}

	local rowIcon = row:CreateIconDrawable("artwork")
	rowIcon:SetExtent(23, 23)
	rowIcon:AddAnchor("CENTER", row, 0, -1)
	HideIconDrawable(rowIcon)
	row.iconDrawable = rowIcon

	local nameLabel = row:CreateChildWidget("label", "lootTrackerRowName" .. tostring(index), 0, true)
	nameLabel:SetText("")
	nameLabel:SetExtent(BOX_SIZE - 5, 18)
	nameLabel.style:SetAlign(ALIGN_CENTER)
	nameLabel.style:SetFontSize(8)
	nameLabel.style:SetColor(0.98, 0.98, 0.98, 1)
	nameLabel.style:SetOutline(true)
	nameLabel:AddAnchor("TOP", row, 0, 5)
	SafeMethod(nameLabel, "EnablePick", false)
	row.nameLabel = nameLabel

	local countLabel = row:CreateChildWidget("label", "lootTrackerRowCount" .. tostring(index), 0, true)
	countLabel:SetText("")
	countLabel:SetExtent(BOX_SIZE - 5, 15)
	countLabel.style:SetAlign(ALIGN_CENTER)
	countLabel.style:SetFontSize(9)
	countLabel.style:SetColor(0.92, 0.86, 0.62, 1)
	countLabel.style:SetOutline(true)
	-- Sets hover state to true for the row on mouse enter.
	countLabel:AddAnchor("BOTTOM", row, 0, -3)
	SafeMethod(countLabel, "EnablePick", false)
	row.countLabel = countLabel

	function row:OnEnter()
		-- Sets hover state to true for the row on mouse enter.
		ShowTrackerHeaderControls()
		SetRowHover(self, true)
	end
	row:SetHandler("OnEnter", row.OnEnter)

		-- Sets hover state to false for the row on mouse leave.
	function row:OnLeave()
		SetRowHover(self, false)
	end
	row:SetHandler("OnLeave", row.OnLeave)
		-- Handles click on a tracked row: right click removes item, left opens picker.

	function row:OnClick(mouseButton)
		HandleRowClick(self.index, mouseButton)
	end
	row:SetHandler("OnClick", row.OnClick)

	rowWidgets[index] = row
end

ApplyTrackerLayout()
HideTrackerHeaderControls()

local pickerWindow = CreateEmptyWindow("lootTrackerPickerWindow", "UIParent")
runtime.pickerWindow = pickerWindow
pickerWindow:SetExtent(PICKER_WIDTH, PICKER_HEIGHT)
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
pickerTitle:SetExtent(PICKER_WIDTH - 56, HEADER_HEIGHT)
pickerTitle.style:SetAlign(ALIGN_LEFT)
pickerTitle.style:SetFontSize(12)
pickerTitle.style:SetColor(0.95, 0.92, 0.82, 1)
pickerTitle.style:SetOutline(true)
pickerTitle:AddAnchor("TOPLEFT", pickerWindow, PADDING, PADDING + 2)
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
pickerCloseButton:AddAnchor("TOPRIGHT", pickerWindow, -PADDING, PADDING)

function pickerCloseButton:OnClick()
	ClosePicker()
end
pickerCloseButton:SetHandler("OnClick", pickerCloseButton.OnClick)

local pickerSearchBorder = pickerWindow:CreateColorDrawable(0.96, 0.9, 0.72, 0.62, "artwork")
pickerSearchBorder:AddAnchor("TOPLEFT", pickerWindow, PADDING, PICKER_SEARCH_TOP)
pickerSearchBorder:SetExtent(PICKER_WIDTH - (PADDING * 2), PICKER_SEARCH_HEIGHT)

local pickerSearchBackground = pickerWindow:CreateColorDrawable(0.86, 0.88, 0.82, 0.42, "artwork")
pickerSearchBackground:AddAnchor("TOPLEFT", pickerWindow, PADDING + 2, PICKER_SEARCH_TOP + 2)
pickerSearchBackground:SetExtent(PICKER_WIDTH - (PADDING * 2) - 4, PICKER_SEARCH_HEIGHT - 4)

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
	searchBox:AddAnchor("TOPLEFT", pickerWindow, PADDING + 4, PICKER_SEARCH_TOP + 3)
	searchBox:SetExtent(PICKER_WIDTH - (PADDING * 2) - 8, PICKER_SEARCH_HEIGHT - 6)
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
pickerStatusLabel:AddAnchor("TOP", pickerWindow, 0, PICKER_CONTROL_TOP + 2)

local pickerUpButton = pickerWindow:CreateChildWidget("button", "lootTrackerPickerUpButton", 0, true)
pickerUpButton:SetStyle("text_default")
pickerUpButton:SetText("Up")
pickerUpButton:SetExtent(64, 22)
pickerUpButton:AddAnchor("TOPLEFT", pickerWindow, PADDING, PICKER_CONTROL_TOP)

local pickerDownButton = pickerWindow:CreateChildWidget("button", "lootTrackerPickerDownButton", 0, true)
pickerDownButton:SetStyle("text_default")
pickerDownButton:SetText("Down")
pickerDownButton:SetExtent(64, 22)
pickerDownButton:AddAnchor("TOPRIGHT", pickerWindow, -PADDING, PICKER_CONTROL_TOP)

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
	-- Drops the last character from text, handling multi-byte UTF8 by finding proper cut point.
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

	-- Normalizes a key value to lowercase token without spaces/underscores for comparison.
local function IsBackspaceKey(value)
	-- Checks if key token is backspace key.
	local token = NormalizeKeyToken(value)
	return token == "backspace" or token == "back" or token == "8"
end

local function IsDeleteKey(value)
	-- Checks if key token is delete key.
	local token = NormalizeKeyToken(value)
	return token == "delete" or token == "del" or token == "46"
end

local function IsClearSearchKey(value)
	-- Checks if key token is clear search (escape).
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
	local maxStart = #pickerItems - PICKER_VISIBLE_COUNT + 1
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
	-- Sets the item data on a picker button widget and updates its labels, icon, and background color based on whether an item is provided or not.
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

	-- Updates the picker UI: rebuilds the filtered item list, clamps scroll, populates visible buttons, and updates the status label with visible range.
UpdatePicker = function()
	-- Updates the picker UI: rebuilds the filtered item list, clamps scroll, populates visible buttons, and updates the status label with visible range.
	pickerItems = BuildPickerItems(pickerSearchText)
	ClampPickerScroll()

	for visibleIndex = 1, PICKER_VISIBLE_COUNT do
		local button = pickerItemWidgets[visibleIndex]
		SetPickerButton(button, pickerItems[pickerScrollIndex + visibleIndex - 1])
	end

	local total = #pickerItems
	if total == 0 then
		pickerStatusLabel:SetText("0 / 0")
	else
		local firstVisible = pickerScrollIndex
		local lastVisible = pickerScrollIndex + PICKER_VISIBLE_COUNT - 1
		if lastVisible > total then
			lastVisible = total
		end
		pickerStatusLabel:SetText(tostring(firstVisible) .. "-" .. tostring(lastVisible) .. " / " .. tostring(total))
	end
end
	-- Scrolls the picker by the given delta items, clamps the scroll index, and refreshes the picker display.
	-- Scrolls the picker by the given delta items, clamps the scroll index, and refreshes the picker display.

local function ScrollPicker(deltaItems)
	pickerScrollIndex = pickerScrollIndex + deltaItems
	ClampPickerScroll()
	UpdatePicker()
	-- Handles click on the picker up button to scroll up by one column.
end

function pickerUpButton:OnClick()
	ScrollPicker(-PICKER_COLUMNS)
end
	-- Handles click on the picker down button to scroll down by one column.
pickerUpButton:SetHandler("OnClick", pickerUpButton.OnClick)

function pickerDownButton:OnClick()
	-- Attaches all necessary event handlers (text change, key, mouse wheel) to the picker search box.
	ScrollPicker(PICKER_COLUMNS)
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
	-- Recreates the picker search box widget, clears state, configures it, attaches handlers, and returns the new box.
	searchBox:SetHandler("OnWheel", OnPickerSearchMouseWheel)
end

AttachPickerSearchHandlers(pickerSearchBox)

RecreatePickerSearchBox = function()
	ClearPickerSearchState()
	HidePickerSearchBox()

	pickerSearchBox = pickerWindow:CreateChildWidget("editbox", NextPickerSearchBoxName(), 0, true)
	runtime.pickerSearchBox = pickerSearchBox
	ConfigurePickerSearchBox(pickerSearchBox)
	AttachPickerSearchHandlers(pickerSearchBox)
	ClearPickerSearchState()
	return pickerSearchBox
end

for rowIndex = 1, PICKER_ROWS do
	for columnIndex = 1, PICKER_COLUMNS do
		local visibleIndex = ((rowIndex - 1) * PICKER_COLUMNS) + columnIndex
		local itemButton =
			pickerWindow:CreateChildWidget("button", "lootTrackerPickerItem" .. tostring(visibleIndex), 0, true)
		itemButton.index = visibleIndex
		itemButton:SetStyle("text_default")
		itemButton:SetText("")
		itemButton:SetExtent(PICKER_ITEM_WIDTH, PICKER_ITEM_HEIGHT)
		itemButton:AddAnchor(
			"TOPLEFT",
			pickerWindow,
			PADDING + ((columnIndex - 1) * (PICKER_ITEM_WIDTH + PICKER_ITEM_GAP_X)),
			PICKER_GRID_TOP + ((rowIndex - 1) * (PICKER_ITEM_HEIGHT + PICKER_ITEM_GAP_Y))
		)

		local itemBg = itemButton:CreateColorDrawable(0.06, 0.06, 0.07, 0.54, "background")
		itemBg:AddAnchor("TOPLEFT", itemButton, 0, 0)
		itemBg:SetExtent(PICKER_ITEM_WIDTH, PICKER_ITEM_HEIGHT)
		itemButton.bg = itemBg

		local itemHighlight = itemButton:CreateColorDrawable(1, 1, 1, 0.04, "overlay")
		itemHighlight:AddAnchor("TOPLEFT", itemButton, 0, 0)
		itemHighlight:SetExtent(PICKER_ITEM_WIDTH, 10)
		itemButton.highlight = itemHighlight

		local itemIcon = itemButton:CreateIconDrawable("artwork")
		itemIcon:SetExtent(28, 28)
		itemIcon:AddAnchor("LEFT", itemButton, 4, 0)
		HideIconDrawable(itemIcon)
		itemButton.iconDrawable = itemIcon

		local itemNameLabel =
			itemButton:CreateChildWidget("label", "lootTrackerPickerItemName" .. tostring(visibleIndex), 0, true)
		itemNameLabel:SetText("")
		itemNameLabel:SetExtent(PICKER_ITEM_WIDTH - 38, 18)
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
		itemCountLabel:SetExtent(PICKER_ITEM_WIDTH - 38, 14)
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
		ScrollPicker(-PICKER_COLUMNS)
	else
		ScrollPicker(PICKER_COLUMNS)
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
	local text = string.lower(Trim(value))
	if text ~= "/loottracker reset" then
		return false
	end

	return true
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

local function HasLootTrackerResetCommandText(...)
	for index = 1, select("#", ...) do
		if IsLootTrackerResetCommandText(select(index, ...)) then
			return true
		end
	end
	return false
end

local function HandleLootTrackerChatCommand(channel, relation, name, message, info, ...)
	if IsOwnLootTrackerResetCommand(name, message)
		or HasLootTrackerResetCommandText(channel, relation, name, message, info, ...)
	then
		CenterLootTrackerWindow()
	end
end

function trackerWindow:OnEvent(event)
	if watchedEvents[event] then
		MarkInventoryDirty()
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
	if isPickerOpen and not IsPickerWindowVisible() then
		ClosePicker()
	end
	if isPickerOpen then
		pickerSearchPollElapsed = pickerSearchPollElapsed + delta
		if pickerSearchPollElapsed >= SEARCH_POLL_INTERVAL then
			pickerSearchPollElapsed = 0
			PollPickerSearchBox()
		end
	end

	if inventoryFallbackRefreshElapsed >= INVENTORY_FALLBACK_REFRESH_SECONDS then
		inventoryFallbackRefreshElapsed = 0
		MarkInventoryDirty()
	end

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
