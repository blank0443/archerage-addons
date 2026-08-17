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

function runtime.ScoreSearchMatch(name, query)
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

function runtime.BuildPickerItems(query)
	local _, orderedItems = runtime.GetInventorySnapshot(false)
	local normalizedQuery = NormalizeName(query)
	if runtime.pickerCachedInventoryVersion == runtime.inventoryVersion
		and runtime.pickerCachedSearchText == normalizedQuery
		and runtime.pickerCachedItems ~= nil
	then
		return runtime.pickerCachedItems
	end

	if normalizedQuery == "" then
		runtime.pickerCachedSearchText = normalizedQuery
		runtime.pickerCachedInventoryVersion = runtime.inventoryVersion
		runtime.pickerCachedItems = orderedItems
		return orderedItems
	end

	local matches = {}
	for _, item in ipairs(orderedItems) do
		local score = runtime.ScoreSearchMatch(item.name, query)
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

	runtime.pickerCachedSearchText = normalizedQuery
	runtime.pickerCachedInventoryVersion = runtime.inventoryVersion
	runtime.pickerCachedItems = matches
	return matches
end

local pickerWindow = CreateEmptyWindow("lootTrackerPickerWindow", "UIParent")
runtime.pickerWindow = pickerWindow
pickerWindow:SetExtent(CONFIG.PICKER_WIDTH, CONFIG.PICKER_HEIGHT)
pickerWindow:EnableDrag(true)
pickerWindow:Clickable(true)
pickerWindow:Show(false)
local pickerSavedX, pickerSavedY, hasSavedPickerWindowPosition = runtime.LoadPickerWindowPosition(0, 0)
runtime.pickerWindowPositionSaved = hasSavedPickerWindowPosition
if runtime.pickerWindowPositionSaved then
	pickerWindow:AddAnchor("TOPLEFT", "UIParent", pickerSavedX, pickerSavedY)
else
	pickerWindow:AddAnchor("TOPLEFT", runtime.window, 0, runtime.GetTrackerWindowHeight() + 8)
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
	runtime.SavePickerWindowPosition(pickerWindow)
end
pickerTitle:SetHandler("OnDragStop", pickerTitle.OnDragStop)

local pickerCloseButton = pickerWindow:CreateChildWidget("button", "lootTrackerPickerCloseButton", 0, true)
pickerCloseButton:SetStyle("text_default")
pickerCloseButton:SetText("X")
pickerCloseButton:SetExtent(26, 22)
pickerCloseButton:AddAnchor("TOPRIGHT", pickerWindow, -CONFIG.PADDING, CONFIG.PADDING)

function pickerCloseButton:OnClick()
	runtime.ClosePicker()
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

local function CreatePickerSearchBox()
	return pickerWindow:CreateChildWidgetByType(UOT_X2_EDITBOX, NextPickerSearchBoxName(), 0, true)
end

local function ConfigurePickerSearchBox(searchBox)
	-- Configures a picker search box edit widget with anchors, size, font, and visibility.
	if searchBox == nil then
		return
	end
	searchBox:RemoveAllAnchors()
	searchBox:AddAnchor("TOPLEFT", pickerWindow, CONFIG.PADDING + 4, CONFIG.PICKER_SEARCH_TOP + 3)
	searchBox:SetHeight(CONFIG.PICKER_SEARCH_HEIGHT - 6)
	searchBox:SetWidth(CONFIG.PICKER_WIDTH - (CONFIG.PADDING * 2) - 8)
	searchBox:SetText("")
	SafeMethod(searchBox, "SetMaxTextLength", 64)
	SafeMethod(searchBox, "SetInset", 5, 5, 5, 5)
	SafeMethod(searchBox, "EnableFocus", true)
	SafeMethod(searchBox, "UseSelectAllWhenFocused", true)
	SafeMethod(searchBox, "Enable", true)
	SafeMethod(searchBox, "Show", true)
	SafeMethod(searchBox, "SetVisible", true)
	SafeMethod(searchBox, "Clickable", true)
	SafeMethod(searchBox, "EnableInput", true)
	SafeMethod(searchBox, "SetInputEnabled", true)
	SafeMethod(searchBox, "EnableHitTest", true)
	SafeMethod(searchBox, "SetHitTestEnabled", true)
	if searchBox.style ~= nil then
		searchBox.style:SetColor(0.05, 0.06, 0.05, 1)
		searchBox.style:SetFontSize(13)
		searchBox.style:SetAlign(ALIGN_LEFT)
	end
end

pickerSearchBox = CreatePickerSearchBox()
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

local pickerSearchGetterMethods = {
	"GetText",
	"GetInputText",
	"GetEditText",
	"GetDisplayText",
	"GetString",
}

local function ReadPickerSearchBoxText()
	-- Mirrors the Save set input: trust the native editbox text getters and allow an empty string to clear search.
	local searchBox = runtime.pickerSearchBox
	if searchBox == nil then
		return runtime.pickerSearchText or ""
	end

	for _, methodName in ipairs(pickerSearchGetterMethods) do
		local fn = searchBox[methodName]
		if type(fn) == "function" then
			local ok, value = pcall(fn, searchBox)
			if ok and type(value) == "string" then
				return value
			end
		end
	end

	return runtime.pickerSearchText or ""
end

local function SyncPickerSearchBoxText(text, clearWhenEmpty)
	-- Synchronizes the native editbox through the same setter family used by the Save set input.
	local value = tostring(text or "")
	local searchBox = runtime.pickerSearchBox
	if searchBox == nil then
		return
	end

	runtime.pickerSearchTextEventSuppressed = true
	SafeMethod(searchBox, "SetText", value)
	SafeMethod(searchBox, "SetInputText", value)
	SafeMethod(searchBox, "SetEditText", value)
	SafeMethod(searchBox, "SetDisplayText", value)
	SafeMethod(searchBox, "SetString", value)
	if clearWhenEmpty == true and value == "" then
		SafeMethod(searchBox, "ClearText")
		SafeMethod(searchBox, "ClearInputText")
		SafeMethod(searchBox, "ClearEditText")
	end
	runtime.pickerSearchTextEventSuppressed = false
end

local function ApplyPickerSearchText(nextSearchText, syncSearchBox)
	-- Applies new search text to picker, updates state, resets scroll, syncs box if needed, and refreshes picker.
	local text = tostring(nextSearchText or "")
	if text == runtime.pickerSearchText then
		return
	end
	runtime.pickerSearchText = text
	runtime.pickerScrollIndex = 1
	if syncSearchBox then
		SyncPickerSearchBoxText(text, false)
	end
	runtime.UpdatePicker()
end

function runtime.PollPickerSearchBox()
	-- Polls the picker search box for current text and applies it if changed.
	local text = ReadPickerSearchBoxText()
	if text ~= nil then
		ApplyPickerSearchText(text, false)
	end
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
	if runtime.pickerSearchTextEventSuppressed then
		return
	end

	local argText = FirstStringArg(...)
	if argText ~= nil then
		ApplyPickerSearchText(argText, false)
	else
		runtime.PollPickerSearchBox()
	end
end

local function ActivatePickerSearchInput()
	if pickerSearchBackground ~= nil then
		pickerSearchBackground:SetColor(0.95, 0.74, 0.32, 0.46)
	end
	runtime.PollPickerSearchBox()
	SafeMethod(runtime.pickerSearchBox, "SetFocus")
	SafeMethod(runtime.pickerSearchBox, "SetFocus", true)
end

local function OnPickerSearchFocusLost()
	if pickerSearchBackground ~= nil then
		pickerSearchBackground:SetColor(0.86, 0.88, 0.82, 0.42)
	end
	runtime.PollPickerSearchBox()
end

local function OnPickerSearchMouseWheel(delta)
	-- Handles mouse wheel on picker search box by delegating to picker window.
	pickerWindow:OnMouseWheel(delta)
end

local function ClampPickerScroll()
	-- Clamps the picker scroll index to valid range based on total items and visible count.
	local maxStart = #runtime.pickerItems - CONFIG.PICKER_VISIBLE_COUNT + 1
	if maxStart < 1 then
		maxStart = 1
	end
	if runtime.pickerScrollIndex < 1 then
		runtime.pickerScrollIndex = 1
	elseif runtime.pickerScrollIndex > maxStart then
		runtime.pickerScrollIndex = maxStart
	end
end

local function SetPickerButton(button, item)
	button.itemData = item
	if item == nil then
		button.nameLabel:SetText("")
		button.countLabel:SetText("")
		runtime.SetIconDrawable(button.iconDrawable, nil)
		button.bg:SetColor(0.06, 0.06, 0.07, 0.54)
		return
	end

	button.nameLabel:SetText(CompactNameLimit(item.name, 13))
	button.countLabel:SetText("x" .. tostring(item.count))
	runtime.SetIconDrawable(button.iconDrawable, item.iconPath)
	button.bg:SetColor(0.08, 0.12, 0.16, 0.88)
end

runtime.UpdatePicker = function()
	runtime.pickerItems = runtime.BuildPickerItems(runtime.pickerSearchText)
	ClampPickerScroll()

	for visibleIndex = 1, CONFIG.PICKER_VISIBLE_COUNT do
		local button = pickerItemWidgets[visibleIndex]
		SetPickerButton(button, runtime.pickerItems[runtime.pickerScrollIndex + visibleIndex - 1])
	end

	local total = #runtime.pickerItems
	if total == 0 then
		pickerStatusLabel:SetText("0 / 0")
	else
		local firstVisible = runtime.pickerScrollIndex
		local lastVisible = runtime.pickerScrollIndex + CONFIG.PICKER_VISIBLE_COUNT - 1
		if lastVisible > total then
			lastVisible = total
		end
		pickerStatusLabel:SetText(tostring(firstVisible) .. "-" .. tostring(lastVisible) .. " / " .. tostring(total))
	end
end

function runtime.ScrollPicker(deltaItems)
	runtime.pickerScrollIndex = runtime.pickerScrollIndex + deltaItems
	ClampPickerScroll()
	runtime.UpdatePicker()
end

function pickerUpButton:OnClick()
	runtime.ScrollPicker(-CONFIG.PICKER_COLUMNS)
end
pickerUpButton:SetHandler("OnClick", pickerUpButton.OnClick)

function pickerDownButton:OnClick()
	runtime.ScrollPicker(CONFIG.PICKER_COLUMNS)
end
pickerDownButton:SetHandler("OnClick", pickerDownButton.OnClick)

local function AttachPickerSearchHandlers(searchBox)
	if searchBox == nil then
		return
	end
	SafeMethod(searchBox, "SetHandler", "OnClick", ActivatePickerSearchInput)
	SafeMethod(searchBox, "SetHandler", "OnMouseDown", ActivatePickerSearchInput)
	SafeMethod(searchBox, "SetHandler", "OnMouseUp", ActivatePickerSearchInput)
	SafeMethod(searchBox, "SetHandler", "OnLButtonDown", ActivatePickerSearchInput)
	SafeMethod(searchBox, "SetHandler", "OnLButtonUp", ActivatePickerSearchInput)
	SafeMethod(searchBox, "SetHandler", "OnLeftButtonDown", ActivatePickerSearchInput)
	SafeMethod(searchBox, "SetHandler", "OnLeftButtonUp", ActivatePickerSearchInput)
	SafeMethod(searchBox, "SetHandler", "OnDoubleClick", ActivatePickerSearchInput)
	SafeMethod(searchBox, "SetHandler", "OnDoubleClicked", ActivatePickerSearchInput)
	SafeMethod(searchBox, "SetHandler", "OnTextChanged", OnPickerSearchChanged)
	SafeMethod(searchBox, "SetHandler", "OnTextChange", OnPickerSearchChanged)
	SafeMethod(searchBox, "SetHandler", "OnEditTextChanged", OnPickerSearchChanged)
	SafeMethod(searchBox, "SetHandler", "OnChanged", OnPickerSearchChanged)
	SafeMethod(searchBox, "SetHandler", "OnEditFocusLost", OnPickerSearchFocusLost)
	SafeMethod(searchBox, "SetHandler", "OnMouseWheel", OnPickerSearchMouseWheel)
	SafeMethod(searchBox, "SetHandler", "OnWheel", OnPickerSearchMouseWheel)
end

local function ReleasePickerSearchHandlers(searchBox)
	if searchBox == nil then
		return
	end
	SafeMethod(searchBox, "ReleaseHandler", "OnClick")
	SafeMethod(searchBox, "ReleaseHandler", "OnMouseDown")
	SafeMethod(searchBox, "ReleaseHandler", "OnMouseUp")
	SafeMethod(searchBox, "ReleaseHandler", "OnLButtonDown")
	SafeMethod(searchBox, "ReleaseHandler", "OnLButtonUp")
	SafeMethod(searchBox, "ReleaseHandler", "OnLeftButtonDown")
	SafeMethod(searchBox, "ReleaseHandler", "OnLeftButtonUp")
	SafeMethod(searchBox, "ReleaseHandler", "OnDoubleClick")
	SafeMethod(searchBox, "ReleaseHandler", "OnDoubleClicked")
	SafeMethod(searchBox, "ReleaseHandler", "OnChar")
	SafeMethod(searchBox, "ReleaseHandler", "OnTextInput")
	SafeMethod(searchBox, "ReleaseHandler", "OnInput")
	SafeMethod(searchBox, "ReleaseHandler", "OnTextChanged")
	SafeMethod(searchBox, "ReleaseHandler", "OnTextChange")
	SafeMethod(searchBox, "ReleaseHandler", "OnEditTextChanged")
	SafeMethod(searchBox, "ReleaseHandler", "OnChanged")
	SafeMethod(searchBox, "ReleaseHandler", "OnEditFocusLost")
	SafeMethod(searchBox, "ReleaseHandler", "OnKeyDown")
	SafeMethod(searchBox, "ReleaseHandler", "OnRawKeyDown")
	SafeMethod(searchBox, "ReleaseHandler", "OnKeyUp")
	SafeMethod(searchBox, "ReleaseHandler", "OnRawKeyUp")
	SafeMethod(searchBox, "ReleaseHandler", "OnMouseWheel")
	SafeMethod(searchBox, "ReleaseHandler", "OnWheel")
end

AttachPickerSearchHandlers(pickerSearchBox)

runtime.RecreatePickerSearchBox = function()
	runtime.ClearPickerSearchState()

	if runtime.pickerSearchBox == nil then
		pickerSearchBox = CreatePickerSearchBox()
	else
		pickerSearchBox = runtime.pickerSearchBox
		ReleasePickerSearchHandlers(pickerSearchBox)
	end
	runtime.pickerSearchBox = pickerSearchBox
	ConfigurePickerSearchBox(pickerSearchBox)
	AttachPickerSearchHandlers(pickerSearchBox)
	runtime.ClearPickerSearchState()
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
		runtime.HideIconDrawable(itemIcon)
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
			if self.itemData == nil or runtime.pickerSlotIndex == nil then
				return
			end
			runtime.SetTrackedItem(runtime.pickerSlotIndex, self.itemData)
			runtime.ClosePicker()
			runtime.UpdateRows()
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
	runtime.isPickerOpen = false
	runtime.ClearPickerSearchState()
	runtime.HidePickerSearchBox()
end
pickerWindow:SetHandler("OnHide", pickerWindow.OnHide)

function pickerWindow:OnMouseWheel(delta)
	-- Handles the OnMouseWheel event for the picker window. Scrolls the picker items up or down based on wheel delta.
	local amount = tonumber(delta) or 0
	if amount > 0 then
		runtime.ScrollPicker(-CONFIG.PICKER_COLUMNS)
	else
		runtime.ScrollPicker(CONFIG.PICKER_COLUMNS)
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
	runtime.SavePickerWindowPosition(self)
end
pickerWindow:SetHandler("OnDragStop", pickerWindow.OnDragStop)

