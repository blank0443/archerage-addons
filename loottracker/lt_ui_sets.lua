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
		slotCount = runtime.trackedSlotCount,
		items = {},
	}
	local itemCount = 0
	for index = 1, runtime.trackedSlotCount do
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

	local slotCount = math.floor(tonumber(setData.slotCount) or runtime.trackedSlotCount)
	if slotCount < 1 then
		slotCount = 1
	elseif slotCount > 20 then
		slotCount = 20
	end

	if self.ChangeSlotCount ~= nil and slotCount ~= runtime.trackedSlotCount then
		self:ChangeSlotCount(slotCount - runtime.trackedSlotCount, {
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

	self:SetActiveTrackedSetName(setName)
	self:SaveSlotCount()
	runtime.SaveTrackedItems()
	runtime.MarkInventoryDirty(true)
	if runtime.ApplyTrackerLayout ~= nil then
		runtime.ApplyTrackerLayout()
	end
	runtime.UpdateRows()
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
		self:SetActiveTrackedSetName(existingSetName)
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
	self:SetActiveTrackedSetName(setName)
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
		self:SetActiveTrackedSetName(nil)
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

	local defaultX, defaultY = GetWidgetSavedPosition(runtime.window)
	if defaultX == nil then
		defaultX = 600
		defaultY = 320
	else
		defaultX = defaultX + runtime.GetTrackerWindowWidth() + 8
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

