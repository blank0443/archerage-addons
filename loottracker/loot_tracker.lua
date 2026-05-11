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
end

local runtime = {
	active = true,
	window = nil,
	pickerWindow = nil,
	restoreButton = nil,
}
_G.__LOOT_TRACKER_RUNTIME = runtime

local TRACKED_SLOT_COUNT = 5
local BAG_KIND = 1
local MAX_BAG_SLOTS = 150
local SAVE_KEY = "lootTrackerTrackedItems"
local POSITION_KEY = "lootTrackerWindowPosition"

local WINDOW_WIDTH = 242
local WINDOW_HEIGHT = 86
local RESTORE_BUTTON_WIDTH = 92
local RESTORE_BUTTON_HEIGHT = 22
local PADDING = 9
local HEADER_HEIGHT = 22
local BOX_SIZE = 40
local BOX_GAP = 6
local BOXES_TOP = PADDING + HEADER_HEIGHT + 7

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
local UpdatePicker
local RecreatePickerSearchBox
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
		end
	end

	return nil
end

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
			return value
		end
	end

	return 1
end

local function BuildItemKey(name, grade, iconPath)
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
				entry.iconPath = iconPath
			end

			entry.count = entry.count + count
		end
	end

	return itemsByKey, orderedItems
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
	local _, orderedItems = ReadInventory()
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

local function SaveWindowPosition(window)
	if window == nil then
		return
	end

	local offsetX, offsetY = window:GetOffset()
	local uiScale = UIParent:GetUIScale() or 1.0
	local data = {
		x = math.floor((offsetX * uiScale) + 0.5),
		y = math.floor((offsetY * uiScale) + 0.5),
	}

	pcall(function()
		ADDON:ClearData(POSITION_KEY)
		ADDON:SaveData(POSITION_KEY, data)
	end)
end

local function LoadWindowPosition()
	local ok, data = pcall(function()
		return ADDON:LoadData(POSITION_KEY)
	end)
	if ok and type(data) == "table" and data.x ~= nil and data.y ~= nil then
		return tonumber(data.x) or 420, tonumber(data.y) or 320
	end
	return 420, 320
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

local function SetRowText(row, nameText, countText, state, iconPath)
	if row == nil then
		return
	end

	row.fullName = nameText or ""
	row.nameLabel:SetText(CompactName(nameText))
	row.countLabel:SetText(countText or "")
	SetIconDrawable(row.iconDrawable, iconPath)
	SetRowBackground(row, state)
end

local function RemoveTrackedItem(index)
	if trackedItems[index] == nil then
		return
	end
	trackedItems[index] = nil
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
		UpdateRows()
	end
end

local function OpenPicker(rowIndex)
	pickerSlotIndex = rowIndex
	pickerScrollIndex = 1
	ClearPickerSearchState()
	if RecreatePickerSearchBox ~= nil then
		RecreatePickerSearchBox()
	end
	if runtime.pickerWindow ~= nil then
		runtime.pickerWindow:RemoveAllAnchors()
		runtime.pickerWindow:AddAnchor("TOPLEFT", trackerWindow, 0, WINDOW_HEIGHT + 8)
		runtime.pickerWindow:Show(true)
	end
	ClearPickerSearchState()
	if runtime.pickerSearchBox ~= nil then
		SafeMethod(runtime.pickerSearchBox, "SetFocus")
		SafeMethod(runtime.pickerSearchBox, "SetFocus", true)
	end
	isPickerOpen = true
	if UpdatePicker ~= nil then
		UpdatePicker()
	end
end

local function ClosePicker()
	isPickerOpen = false
	ClearPickerSearchState()
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
	local itemsByKey = ReadInventory()

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

trackerWindow = CreateEmptyWindow("lootTrackerWindow", "UIParent")
runtime.window = trackerWindow
trackerWindow:SetExtent(WINDOW_WIDTH, WINDOW_HEIGHT)
trackerWindow:EnableDrag(true)
trackerWindow:Clickable(true)
trackerWindow:Show(true)

local savedX, savedY = LoadWindowPosition()
trackerWindow:AddAnchor("TOPLEFT", "UIParent", savedX, savedY)

local restoreButton = UIParent:CreateWidget("button", "lootTrackerRestoreButton", "UIParent", "")
runtime.restoreButton = restoreButton
restoreButton:SetStyle("text_default")
restoreButton:SetText("Loot Tracker")
restoreButton:SetExtent(RESTORE_BUTTON_WIDTH, RESTORE_BUTTON_HEIGHT)
restoreButton:EnableDrag(true)
SafeMethod(restoreButton, "Clickable", true)
restoreButton:AddAnchor("TOPLEFT", "UIParent", savedX, savedY)
restoreButton:Show(false)

local function AnchorWidgetAtSavedPosition(widget, x, y)
	if widget == nil then
		return
	end

	widget:RemoveAllAnchors()
	widget:AddAnchor("TOPLEFT", "UIParent", x, y)
end

local function AnchorWidgetToCurrentPosition(widgetToMove, positionSource)
	if widgetToMove == nil or positionSource == nil then
		return
	end

	local offsetX, offsetY = positionSource:GetOffset()
	local uiScale = UIParent:GetUIScale() or 1.0
	AnchorWidgetAtSavedPosition(
		widgetToMove,
		math.floor((offsetX * uiScale) + 0.5),
		math.floor((offsetY * uiScale) + 0.5)
	)
end

local function HideLootTrackerWindow()
	SaveWindowPosition(trackerWindow)
	ClosePicker()
	AnchorWidgetToCurrentPosition(restoreButton, trackerWindow)
	trackerWindow:Show(false)
	restoreButton:Show(true)
end

local function ShowLootTrackerWindow()
	SaveWindowPosition(restoreButton)
	AnchorWidgetToCurrentPosition(trackerWindow, restoreButton)
	restoreButton:Show(false)
	trackerWindow:Show(true)
	refreshRequested = true
	UpdateRows()
end

function restoreButton:OnClick()
	ShowLootTrackerWindow()
end
restoreButton:SetHandler("OnClick", restoreButton.OnClick)

function restoreButton:OnDragStart()
	self:StartMoving()
end
restoreButton:SetHandler("OnDragStart", restoreButton.OnDragStart)

function restoreButton:OnDragStop()
	self:StopMovingOrSizing()
	SaveWindowPosition(self)
end
restoreButton:SetHandler("OnDragStop", restoreButton.OnDragStop)

local background = trackerWindow:CreateColorDrawable(0, 0, 0, 0.58, "background")
background:AddAnchor("TOPLEFT", trackerWindow, 0, 0)
background:AddAnchor("BOTTOMRIGHT", trackerWindow, 0, 0)

local headerLabel = trackerWindow:CreateChildWidget("label", "lootTrackerHeaderLabel", 0, true)
headerLabel:SetText("Loot Tracker")
headerLabel:SetExtent(76, HEADER_HEIGHT)
headerLabel.style:SetAlign(ALIGN_LEFT)
headerLabel.style:SetFontSize(11)
headerLabel.style:SetColor(0.95, 0.92, 0.82, 1)
headerLabel.style:SetOutline(true)
headerLabel:AddAnchor("TOPLEFT", trackerWindow, PADDING, PADDING + 2)
SafeMethod(headerLabel, "EnableDrag", true)

function headerLabel:OnDragStart()
	trackerWindow:StartMoving()
end
headerLabel:SetHandler("OnDragStart", headerLabel.OnDragStart)

function headerLabel:OnDragStop()
	trackerWindow:StopMovingOrSizing()
	SaveWindowPosition(trackerWindow)
end
headerLabel:SetHandler("OnDragStop", headerLabel.OnDragStop)

local hideButton = trackerWindow:CreateChildWidget("button", "lootTrackerHideButton", 0, true)
hideButton:SetStyle("text_default")
hideButton:SetText("Hide UI")
hideButton:SetExtent(58, 18)
hideButton:AddAnchor("TOPRIGHT", trackerWindow, -PADDING - 54, PADDING + 1)

function hideButton:OnClick()
	HideLootTrackerWindow()
end
hideButton:SetHandler("OnClick", hideButton.OnClick)

local resetButton = trackerWindow:CreateChildWidget("button", "lootTrackerResetButton", 0, true)
resetButton:SetStyle("text_default")
resetButton:SetText("Reset")
resetButton:SetExtent(50, 18)
resetButton:AddAnchor("TOPRIGHT", trackerWindow, -PADDING, PADDING + 1)

function resetButton:OnClick()
	ClearTrackedItems()
end
resetButton:SetHandler("OnClick", resetButton.OnClick)

for index = 1, TRACKED_SLOT_COUNT do
	local row = trackerWindow:CreateChildWidget("button", "lootTrackerRow" .. tostring(index), 0, true)
	row.index = index
	row:SetStyle("text_default")
	row:SetText("")
	row:SetExtent(BOX_SIZE, BOX_SIZE)
	row:AddAnchor("TOPLEFT", trackerWindow, PADDING + ((index - 1) * (BOX_SIZE + BOX_GAP)), BOXES_TOP)

	local rowBackground = row:CreateColorDrawable(0.06, 0.06, 0.07, 0.64, "background")
	rowBackground:AddAnchor("TOPLEFT", row, 0, 0)
	rowBackground:SetExtent(BOX_SIZE, BOX_SIZE)
	row.bg = rowBackground

	local rowHighlight = row:CreateColorDrawable(1, 1, 1, 0.04, "overlay")
	rowHighlight:AddAnchor("TOPLEFT", row, 0, 0)
	rowHighlight:SetExtent(BOX_SIZE, 11)
	row.highlight = rowHighlight

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
	countLabel:AddAnchor("BOTTOM", row, 0, -3)
	SafeMethod(countLabel, "EnablePick", false)
	row.countLabel = countLabel

	function row:OnEnter()
		if self.highlight ~= nil then
			self.highlight:SetColor(1, 1, 1, 0.11)
		end
	end
	row:SetHandler("OnEnter", row.OnEnter)

	function row:OnLeave()
		if self.highlight ~= nil then
			self.highlight:SetColor(1, 1, 1, 0.04)
		end
	end
	row:SetHandler("OnLeave", row.OnLeave)

	function row:OnClick(mouseButton)
		HandleRowClick(self.index, mouseButton)
	end
	row:SetHandler("OnClick", row.OnClick)

	rowWidgets[index] = row
end

local pickerWindow = CreateEmptyWindow("lootTrackerPickerWindow", "UIParent")
runtime.pickerWindow = pickerWindow
pickerWindow:SetExtent(PICKER_WIDTH, PICKER_HEIGHT)
pickerWindow:EnableDrag(true)
pickerWindow:Clickable(true)
pickerWindow:Show(false)
pickerWindow:AddAnchor("TOPLEFT", trackerWindow, 0, WINDOW_HEIGHT + 8)

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
	_G.__LOOT_TRACKER_SEARCH_BOX_SERIAL = _G.__LOOT_TRACKER_SEARCH_BOX_SERIAL + 1
	return "lootTrackerPickerSearchBox" .. tostring(_G.__LOOT_TRACKER_SEARCH_BOX_SERIAL)
end

local function ConfigurePickerSearchBox(searchBox)
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
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if type(value) == "string" or type(value) == "number" then
			return value
		end
	end
	return nil
end

local function SearchCharacterFromKey(value)
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
	local text = ReadPickerSearchBoxText()
	if text ~= nil then
		ApplyPickerSearchText(text, false)
	end
end

local function AppendPickerSearchText(text)
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
	local text = FirstPrintableStringArg(...)
	if text ~= nil then
		pickerSearchCharHandlerActive = true
	end
	AppendPickerSearchText(text)
end

local function FirstStringArg(...)
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if type(value) == "string" then
			return tostring(value)
		end
	end
	return nil
end

local function OnPickerSearchChanged(...)
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
	HandlePickerSearchKey(...)
end

local function OnPickerSearchChar(...)
	HandlePickerSearchChar(...)
end

local function OnPickerSearchMouseWheel(delta)
	pickerWindow:OnMouseWheel(delta)
end

local function OnPickerSearchUpdate()
	if isPickerOpen then
		PollPickerSearchBox()
	end
end

local function ClampPickerScroll()
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

local function ScrollPicker(deltaItems)
	pickerScrollIndex = pickerScrollIndex + deltaItems
	ClampPickerScroll()
	UpdatePicker()
end

function pickerUpButton:OnClick()
	ScrollPicker(-PICKER_COLUMNS)
end
pickerUpButton:SetHandler("OnClick", pickerUpButton.OnClick)

function pickerDownButton:OnClick()
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
	searchBox:SetHandler("OnUpdate", OnPickerSearchUpdate)
	searchBox:SetHandler("OnMouseWheel", OnPickerSearchMouseWheel)
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
			if self.highlight ~= nil then
				self.highlight:SetColor(1, 1, 1, 0.11)
			end
		end
		itemButton:SetHandler("OnEnter", itemButton.OnEnter)

		function itemButton:OnLeave()
			if self.highlight ~= nil then
				self.highlight:SetColor(1, 1, 1, 0.04)
			end
		end
		itemButton:SetHandler("OnLeave", itemButton.OnLeave)

		function itemButton:OnClick()
			if self.itemData == nil or pickerSlotIndex == nil then
				return
			end
			SetTrackedItem(pickerSlotIndex, self.itemData)
			ClosePicker()
			UpdateRows()
		end
		itemButton:SetHandler("OnClick", itemButton.OnClick)

		function itemButton:OnMouseWheel(delta)
			pickerWindow:OnMouseWheel(delta)
		end
		itemButton:SetHandler("OnMouseWheel", itemButton.OnMouseWheel)
		itemButton:SetHandler("OnWheel", itemButton.OnMouseWheel)

		pickerItemWidgets[visibleIndex] = itemButton
	end
end

function pickerWindow:OnHide()
	isPickerOpen = false
	ClearPickerSearchState()
	HidePickerSearchBox()
end
pickerWindow:SetHandler("OnHide", pickerWindow.OnHide)

function pickerWindow:OnMouseWheel(delta)
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
	self:StartMoving()
end
pickerWindow:SetHandler("OnDragStart", pickerWindow.OnDragStart)

function pickerWindow:OnDragStop()
	self:StopMovingOrSizing()
end
pickerWindow:SetHandler("OnDragStop", pickerWindow.OnDragStop)

function pickerWindow:OnUpdate(dt)
	if isPickerOpen then
		PollPickerSearchBox()
	end
end
pickerWindow:SetHandler("OnUpdate", pickerWindow.OnUpdate)

function trackerWindow:OnDragStart()
	self:StartMoving()
end
trackerWindow:SetHandler("OnDragStart", trackerWindow.OnDragStart)

function trackerWindow:OnDragStop()
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
}

function trackerWindow:OnEvent(event)
	if watchedEvents[event] then
		refreshRequested = true
		UpdateRows()
		if isPickerOpen and UpdatePicker ~= nil then
			UpdatePicker()
		end
	end
end
trackerWindow:SetHandler("OnEvent", trackerWindow.OnEvent)

for eventName, _ in pairs(watchedEvents) do
	trackerWindow:RegisterEvent(eventName)
end

local quantityRefreshElapsed = 0
function trackerWindow:OnUpdate(dt)
	if not runtime.active then
		return
	end

	local delta = NormalizeDt(dt)
	quantityRefreshElapsed = quantityRefreshElapsed + delta
	if isPickerOpen and not IsPickerWindowVisible() then
		ClosePicker()
	end
	if isPickerOpen then
		pickerSearchPollElapsed = pickerSearchPollElapsed + delta
		if pickerSearchPollElapsed >= 0.12 then
			pickerSearchPollElapsed = 0
			PollPickerSearchBox()
		end
	end

	if quantityRefreshElapsed >= 0.5 then
		quantityRefreshElapsed = 0
		refreshRequested = true
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
