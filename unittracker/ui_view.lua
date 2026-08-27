local UT = _G.__UNIT_TRACKER
local runtime = _G.__UNIT_TRACKER_RUNTIME
if UT == nil or runtime == nil then
	return
end

local persist = UT.persist
local timing = UT.timing
local markerCfg = UT.markerCfg
local ui = UT.ui
local LIST_COLORS = UT.LIST_COLORS
local listSave = UT.listSave
local hotkeys = UT.hotkeys
local settings = UT.settings
local listView = UT.listView

local SafeCall = UT.SafeCall
local Trim = UT.Trim
local NormalizeName = UT.NormalizeName
local NormalizeNoteText = UT.NormalizeNoteText
local CompactText = UT.CompactText
local CreateTrackedEditBox = UT.CreateTrackedEditBox
local SetEditBoxText = UT.SetEditBoxText
local PollEditBoxText = UT.PollEditBoxText
local StripWorldSuffix = UT.StripWorldSuffix
local NamesMatch = UT.NamesMatch
local IsValidName = UT.IsValidName
local Now = UT.Now
local GetLocalPlayerName = UT.GetLocalPlayerName
local IsLocalPlayerName = UT.IsLocalPlayerName
local GetPlayerNameKey = UT.GetPlayerNameKey
local GetLocalPlayerUnitId = UT.GetLocalPlayerUnitId
local IsLocalPlayerUnitId = UT.IsLocalPlayerUnitId
local GetUnitInfoById = UT.GetUnitInfoById
local IsUnitIdPlayerCharacter = UT.IsUnitIdPlayerCharacter
local IsSelectedTargetPlayerCharacter = UT.IsSelectedTargetPlayerCharacter
local GetUnitNameById = UT.GetUnitNameById
local MaybePruneSourceCaches = UT.MaybePruneSourceCaches
local RememberRecentPlayerDamageSourceName = UT.RememberRecentPlayerDamageSourceName
local IsRecentPlayerDamageSourceName = UT.IsRecentPlayerDamageSourceName
local RememberPendingDamageSourceName = UT.RememberPendingDamageSourceName
local IsPendingDamageSourceName = UT.IsPendingDamageSourceName
local GetDamageAmount = UT.GetDamageAmount
local ParseCombatMessage = UT.ParseCombatMessage
local ParseCombatTextMessage = UT.ParseCombatTextMessage
local IsDamageCombatText = UT.IsDamageCombatText
local IsIncomingPlayerDamage = UT.IsIncomingPlayerDamage
local IsIncomingDamageCandidate = UT.IsIncomingDamageCandidate
local SaveData = UT.SaveData
local LoadData = UT.LoadData
local SaveWindowPosition = UT.SaveWindowPosition
local SaveViewWindowPosition = UT.SaveViewWindowPosition
local SaveOptsWindowPosition = UT.SaveOptsWindowPosition
local SaveNoteWindowPosition = UT.SaveNoteWindowPosition
local LoadPosition = UT.LoadPosition
local NormalizeUnitId = UT.NormalizeUnitId
local GetEntryName = UT.GetEntryName
local GetEntryUnitId = UT.GetEntryUnitId
local GetEntryAddedAt = UT.GetEntryAddedAt
local GetEntryGuild = UT.GetEntryGuild
local SetEntryGuild = UT.SetEntryGuild
local CreateLabel = UT.CreateLabel
local CreateButton = UT.CreateButton
local SetWidgetVisible = UT.SetWidgetVisible

local SetLabelColor = UT.SetLabelColor
local SetButtonTextColor = UT.SetButtonTextColor
local FormatNotePreview = UT.FormatNotePreview
local EstimateLabelPaintWidth = UT.EstimateLabelPaintWidth
local FitTextToLabelWidth = UT.FitTextToLabelWidth
local MeasureLabelTextWidth = UT.MeasureLabelTextWidth

local function EnsureViewRow(listName, index)
	local rows = runtime.viewRows[listName]
	local row = rows[index]
	if row ~= nil then
		return row
	end

	local viewWindow = runtime.viewWindow
	row = {}
	row.nameLabel = CreateLabel(
		viewWindow,
		"unitTrackerView" .. listName .. "Name" .. tostring(index),
		"",
		ui.VIEW_WINDOW_WIDTH - (ui.PADDING * 2) - ui.VIEW_ROW_ACTION_WIDTH - 4,
		20,
		ui.PADDING,
		0,
		11,
		{ 0.9, 0.9, 0.9, 1 }
	)
	SafeCall(row.nameLabel, "Clickable", true)
	SafeCall(row.nameLabel, "EnablePick", true)
	SafeCall(row.nameLabel, "EnableHitTest", true)
	SafeCall(row.nameLabel, "SetHitTestEnabled", true)
	function row.nameLabel:OnClick()
		UT.OpenNoteWindow(self.entryKey)
	end
	row.nameLabel:SetHandler("OnClick", row.nameLabel.OnClick)

	-- Separate label so guild text can stay blue while the name keeps list color.
	row.guildLabel = CreateLabel(
		viewWindow,
		"unitTrackerView" .. listName .. "Guild" .. tostring(index),
		"",
		40,
		20,
		ui.PADDING,
		0,
		11,
		LIST_COLORS.guild
	)
	row.guildLabel:Show(false)

	row.removeButton = viewWindow:CreateChildWidget(
		"button",
		"unitTrackerView" .. listName .. "Remove" .. tostring(index),
		0,
		true
	)
	row.removeButton:SetStyle("text_default")
	row.removeButton:SetText("X")
	row.removeButton:SetExtent(ui.VIEW_REMOVE_BUTTON_WIDTH, 20)

	function row.removeButton:OnClick()
		UT.BeginRemoveConfirm(self.listName, self.entryKey)
	end
	row.removeButton:SetHandler("OnClick", row.removeButton.OnClick)

	row.confirmNoButton = viewWindow:CreateChildWidget(
		"button",
		"unitTrackerView" .. listName .. "ConfirmNo" .. tostring(index),
		0,
		true
	)
	row.confirmNoButton:SetStyle("text_default")
	row.confirmNoButton:SetText("N")
	row.confirmNoButton:SetExtent(ui.VIEW_CONFIRM_BUTTON_WIDTH, 20)

	function row.confirmNoButton:OnClick()
		UT.ClearRemoveConfirm()
	end
	row.confirmNoButton:SetHandler("OnClick", row.confirmNoButton.OnClick)

	row.confirmYesButton = viewWindow:CreateChildWidget(
		"button",
		"unitTrackerView" .. listName .. "ConfirmYes" .. tostring(index),
		0,
		true
	)
	row.confirmYesButton:SetStyle("text_default")
	row.confirmYesButton:SetText("Y")
	row.confirmYesButton:SetExtent(ui.VIEW_CONFIRM_BUTTON_WIDTH, 20)

	function row.confirmYesButton:OnClick()
		UT.RemoveNameFromList(self.listName, self.entryKey)
	end
	row.confirmYesButton:SetHandler("OnClick", row.confirmYesButton.OnClick)

	rows[index] = row
	return row
end

local function PositionViewRow(row, listName, key, name, guild, y, color)
	local confirming = UT.IsRemoveConfirmPending(listName, key)
	-- Text area left of the remove/confirm buttons.
	local maxRowWidth = ui.VIEW_WINDOW_WIDTH - (ui.PADDING * 2) - ui.VIEW_ROW_ACTION_WIDTH - 4
	name = tostring(name or "")
	guild = Trim(tostring(guild or ""))

	local displayName = name
	local guildText = ""
	local nameShare = maxRowWidth
	local guildShare = 0

	if guild == "" then
		displayName = FitTextToLabelWidth(row.nameLabel, name, maxRowWidth - 2)
		nameShare = EstimateLabelPaintWidth(row.nameLabel, displayName)
		if nameShare > maxRowWidth then
			nameShare = maxRowWidth
		end
		if nameShare < 1 then
			nameShare = 1
		end
	else
		guildText = " - " .. guild
		local reserveGuild = guild
		if string.len(reserveGuild) > 4 then
			reserveGuild = string.sub(reserveGuild, 1, 4)
		end
		local reserveGuildText = " - " .. reserveGuild
		local guildReserve = EstimateLabelPaintWidth(row.guildLabel, reserveGuildText)
		if guildReserve < 1 then
			guildReserve = 1
		end
		if guildReserve > maxRowWidth then
			guildReserve = maxRowWidth
		end

		-- Name keeps leftover width; guild always keeps room for its first 4 letters.
		local nameBudget = maxRowWidth - guildReserve
		if nameBudget < 1 then
			nameBudget = 1
		end
		displayName = FitTextToLabelWidth(row.nameLabel, name, nameBudget)
		nameShare = EstimateLabelPaintWidth(row.nameLabel, displayName)
		if nameShare < 1 then
			nameShare = 1
		end
		if nameShare > nameBudget then
			nameShare = nameBudget
		end

		guildShare = maxRowWidth - nameShare
		if guildShare < guildReserve then
			guildShare = guildReserve
			nameShare = maxRowWidth - guildShare
			if nameShare < 1 then
				nameShare = 1
			end
			displayName = FitTextToLabelWidth(row.nameLabel, name, nameShare)
			nameShare = EstimateLabelPaintWidth(row.nameLabel, displayName)
			if nameShare + guildReserve > maxRowWidth then
				nameShare = maxRowWidth - guildReserve
				if nameShare < 1 then
					nameShare = 1
				end
			end
			guildShare = maxRowWidth - nameShare
		end

		if EstimateLabelPaintWidth(row.guildLabel, guildText) > guildShare then
			local fittedGuild = FitTextToLabelWidth(row.guildLabel, guildText, guildShare)
			-- Ellipsis must not eat the reserved 4 letters.
			if string.len(fittedGuild) > string.len(reserveGuildText) then
				guildText = fittedGuild
			else
				guildText = reserveGuildText
			end
		end
		guildShare = EstimateLabelPaintWidth(row.guildLabel, guildText)
		if nameShare + guildShare > maxRowWidth then
			nameShare = maxRowWidth - guildShare
			if nameShare < 1 then
				nameShare = 1
			end
			displayName = FitTextToLabelWidth(row.nameLabel, name, nameShare)
			nameShare = EstimateLabelPaintWidth(row.nameLabel, displayName)
			if nameShare + guildShare > maxRowWidth then
				nameShare = maxRowWidth - guildShare
				if nameShare < 1 then
					nameShare = 1
				end
			end
		end
		if nameShare < 1 then
			nameShare = 1
		end
		if guildShare < 1 then
			guildShare = 1
		end
	end

	row.nameLabel.entryKey = key
	row.nameLabel:SetText(displayName)
	row.nameLabel:RemoveAllAnchors()
	row.nameLabel:AddAnchor("TOPLEFT", runtime.viewWindow, ui.PADDING, y + 2)
	row.nameLabel:SetExtent(nameShare, 20)
	UT.SetLabelColor(row.nameLabel, color)
	row.nameLabel:Show(true)

	if guildText ~= "" and row.guildLabel ~= nil then
		row.guildLabel:SetText(guildText)
		row.guildLabel:RemoveAllAnchors()
		row.guildLabel:AddAnchor("TOPLEFT", runtime.viewWindow, ui.PADDING + nameShare, y + 2)
		row.guildLabel:SetExtent(guildShare, 20)
		UT.SetLabelColor(row.guildLabel, LIST_COLORS.guild)
		row.guildLabel:Show(true)
	elseif row.guildLabel ~= nil then
		row.guildLabel:SetText("")
		row.guildLabel:Show(false)
	end

	row.removeButton.listName = listName
	row.removeButton.entryKey = key
	row.removeButton:RemoveAllAnchors()
	row.removeButton:AddAnchor("TOPRIGHT", runtime.viewWindow, -ui.PADDING, y)
	row.removeButton:Show(not confirming)

	row.confirmYesButton.listName = listName
	row.confirmYesButton.entryKey = key
	row.confirmYesButton:RemoveAllAnchors()
	row.confirmYesButton:AddAnchor("TOPRIGHT", runtime.viewWindow, -ui.PADDING, y)
	row.confirmYesButton:Show(confirming)

	row.confirmNoButton:RemoveAllAnchors()
	row.confirmNoButton:AddAnchor(
		"TOPRIGHT",
		runtime.viewWindow,
		-(ui.PADDING + ui.VIEW_CONFIRM_BUTTON_WIDTH + ui.VIEW_CONFIRM_GAP),
		y
	)
	row.confirmNoButton:Show(confirming)
end

local function HideUnusedViewRows(listName, firstUnusedIndex)
	local rows = runtime.viewRows[listName]
	for index = firstUnusedIndex, #rows do
		SetWidgetVisible(rows[index].nameLabel, false)
		SetWidgetVisible(rows[index].guildLabel, false)
		SetWidgetVisible(rows[index].removeButton, false)
		SetWidgetVisible(rows[index].confirmNoButton, false)
		SetWidgetVisible(rows[index].confirmYesButton, false)
	end
end

-- Forward decl: pager OnClick is created before UpdateViewWindow is assigned.
local UpdateViewWindow

local function GetTotalPagesForCount(count)
	count = tonumber(count) or 0
	if count <= 0 then
		return 1
	end
	return math.ceil(count / ui.VIEW_ROWS_PER_PAGE)
end

local function GetSectionPage(listName)
	if listName == "friendly" then
		return tonumber(runtime.friendlyPage) or 1
	end
	return tonumber(runtime.hostilePage) or 1
end

local function SetSectionPage(listName, page)
	page = tonumber(page) or 1
	if page < 1 then
		page = 1
	end
	if listName == "friendly" then
		runtime.friendlyPage = page
	else
		runtime.hostilePage = page
	end
end

local function BuildOrderedKeys(list, order)
	local keys = {}
	for _, key in ipairs(order) do
		if list[key] ~= nil then
			table.insert(keys, key)
		end
	end
	return keys
end

local function ClampSectionPage(listName, count)
	local totalPages = GetTotalPagesForCount(count)
	local page = GetSectionPage(listName)
	if page > totalPages then
		page = totalPages
	end
	if page < 1 then
		page = 1
	end
	SetSectionPage(listName, page)
	return page, totalPages
end

local function PositionSectionPagination(pagination, y)
	if pagination == nil then
		return
	end

	local viewWindow = runtime.viewWindow
	local rightInset = ui.PADDING

	pagination.nextButton:RemoveAllAnchors()
	pagination.nextButton:AddAnchor("TOPRIGHT", viewWindow, -rightInset, y)
	pagination.nextButton:Show(true)

	rightInset = rightInset + ui.PAGE_BUTTON_WIDTH + 2
	pagination.pageLabel:RemoveAllAnchors()
	pagination.pageLabel:AddAnchor("TOPRIGHT", viewWindow, -rightInset, y + 1)
	pagination.pageLabel:Show(true)

	rightInset = rightInset + ui.PAGE_LABEL_WIDTH + 2
	pagination.prevButton:RemoveAllAnchors()
	pagination.prevButton:AddAnchor("TOPRIGHT", viewWindow, -rightInset, y)
	pagination.prevButton:Show(true)
end

local function UpdateSectionPagination(pagination, page, totalPages)
	if pagination == nil then
		return
	end

	local showPager = totalPages > 1
	pagination.pageLabel:SetText(tostring(page) .. "/" .. tostring(totalPages))
	SetWidgetVisible(pagination.prevButton, showPager)
	SetWidgetVisible(pagination.nextButton, showPager)
	SetWidgetVisible(pagination.pageLabel, showPager)
end

local function CreateSectionPagination(viewWindow, listName, prefix)
	local pagination = {}

	pagination.prevButton = viewWindow:CreateChildWidget("button", prefix .. "PrevButton", 0, true)
	pagination.prevButton:SetStyle("text_default")
	pagination.prevButton:SetText("<")
	pagination.prevButton:SetExtent(ui.PAGE_BUTTON_WIDTH, ui.PAGE_BUTTON_HEIGHT)

	pagination.pageLabel = CreateLabel(
		viewWindow,
		prefix .. "PageLabel",
		"1/1",
		ui.PAGE_LABEL_WIDTH,
		18,
		0,
		0,
		10,
		{ 0.72, 0.86, 1, 1 }
	)
	pagination.pageLabel.style:SetAlign(ALIGN_CENTER)

	pagination.nextButton = viewWindow:CreateChildWidget("button", prefix .. "NextButton", 0, true)
	pagination.nextButton:SetStyle("text_default")
	pagination.nextButton:SetText(">")
	pagination.nextButton:SetExtent(ui.PAGE_BUTTON_WIDTH, ui.PAGE_BUTTON_HEIGHT)

	-- Pager acts on whichever tab is active; total pages reflect the filtered list.
	function pagination.prevButton:OnClick()
		local activeTab = runtime.viewTab or "friendly"
		local page = GetSectionPage(activeTab)
		if page > 1 then
			SetSectionPage(activeTab, page - 1)
			UpdateViewWindow()
		end
	end
	pagination.prevButton:SetHandler("OnClick", pagination.prevButton.OnClick)

	function pagination.nextButton:OnClick()
		local activeTab = runtime.viewTab or "friendly"
		local totalPages = tonumber(runtime.viewTotalPages) or 1
		local page = GetSectionPage(activeTab)
		if page < totalPages then
			SetSectionPage(activeTab, page + 1)
			UpdateViewWindow()
		end
	end
	pagination.nextButton:SetHandler("OnClick", pagination.nextButton.OnClick)

	return pagination
end

-- Single-list "tab" view: one active list at a time, with name filter + cycling sort.
-- Kept on one table to avoid adding many top-level locals (Lua 5.1 200-local limit).
listView.ROWS_TOP = 114
listView.HEADER_Y = 90
listView.FILTER_Y = 62
listView.FILTER_HEIGHT = 24
listView.TAB_Y = 34
listView.TAB_HEIGHT = 24
listView.SORT_MODES = { "recent", "name", "notes" }
listView.SORT_LABELS = { recent = "Recent", name = "A-Z", notes = "Notes" }

function listView.GetListFor(listName)
	if listName == "hostile" then
		return runtime.hostile, runtime.hostileOrder, LIST_COLORS.hostile
	end
	return runtime.friendly, runtime.friendlyOrder, LIST_COLORS.friendly
end

function listView.HasNote(key)
	local note = runtime.notes[key]
	return type(note) == "string" and Trim(note) ~= ""
end

-- Build the display key list for a tab: insertion order, filtered by name, then sorted.
function listView.BuildKeys(listName)
	local list, order = listView.GetListFor(listName)
	local keys = BuildOrderedKeys(list, order)

	local filter = NormalizeName(runtime.viewFilter or "")
	if filter ~= "" then
		local filtered = {}
		for _, key in ipairs(keys) do
			local name = NormalizeName(UT.GetEntryName(list[key]) or "")
			if name ~= "" and string.find(name, filter, 1, true) ~= nil then
				table.insert(filtered, key)
			end
		end
		keys = filtered
	end

	-- Insertion index is a stable tiebreaker for every sort mode.
	local rank = {}
	for index, key in ipairs(keys) do
		rank[key] = index
	end

	local mode = runtime.viewSort or "recent"
	if mode == "name" then
		table.sort(keys, function(a, b)
			local na = NormalizeName(UT.GetEntryName(list[a]) or "")
			local nb = NormalizeName(UT.GetEntryName(list[b]) or "")
			if na == nb then
				return rank[a] < rank[b]
			end
			return na < nb
		end)
	elseif mode == "notes" then
		table.sort(keys, function(a, b)
			local ha = listView.HasNote(a)
			local hb = listView.HasNote(b)
			if ha ~= hb then
				return ha
			end
			return rank[a] < rank[b]
		end)
	else
		-- recent: newest first by addedAt (ISO text sorts chronologically),
		-- falling back to insertion order when timestamps are missing or equal.
		table.sort(keys, function(a, b)
			local ta = UT.GetEntryAddedAt(list[a]) or ""
			local tb = UT.GetEntryAddedAt(list[b]) or ""
			if ta == tb then
				return rank[a] > rank[b]
			end
			return ta > tb
		end)
	end

	return keys, list
end

function listView.SortButtonText()
	local mode = runtime.viewSort or "recent"
	return "Sort: " .. (listView.SORT_LABELS[mode] or "Recent")
end

function listView.CycleSort()
	local mode = runtime.viewSort or "recent"
	local nextIndex = 1
	for index, name in ipairs(listView.SORT_MODES) do
		if name == mode then
			nextIndex = index + 1
			break
		end
	end
	if nextIndex > #listView.SORT_MODES then
		nextIndex = 1
	end
	runtime.viewSort = listView.SORT_MODES[nextIndex]
end

function listView.SetTab(listName)
	if listName ~= "friendly" and listName ~= "hostile" then
		return
	end
	if runtime.viewTab == listName then
		return
	end
	runtime.viewTab = listName
	runtime.removeConfirm = nil
end

-- Update tab labels/highlight and the sort button text.
function listView.RefreshChrome()
	local viewWindow = runtime.viewWindow
	if viewWindow == nil then
		return
	end
	local activeTab = runtime.viewTab or "friendly"

	if viewWindow.friendlyTab ~= nil then
		viewWindow.friendlyTab:SetText("Friendly (" .. tostring(#runtime.friendlyOrder) .. ")")
		-- Reuse the shared RGB; only the alpha changes to dim the inactive tab.
		SafeCall(
			viewWindow.friendlyTab,
			"SetTextColor",
			LIST_COLORS.friendly[1],
			LIST_COLORS.friendly[2],
			LIST_COLORS.friendly[3],
			activeTab == "friendly" and 1 or 0.45
		)
	end
	if viewWindow.hostileTab ~= nil then
		viewWindow.hostileTab:SetText("Hostile (" .. tostring(#runtime.hostileOrder) .. ")")
		SafeCall(
			viewWindow.hostileTab,
			"SetTextColor",
			LIST_COLORS.hostile[1],
			LIST_COLORS.hostile[2],
			LIST_COLORS.hostile[3],
			activeTab == "hostile" and 1 or 0.45
		)
	end
	if viewWindow.sortButton ~= nil then
		viewWindow.sortButton:SetText(listView.SortButtonText())
	end
end

UpdateViewWindow = function()
	local viewWindow = runtime.viewWindow
	if viewWindow == nil then
		return
	end

	-- Drop a stale pending remove-confirm if its entry is gone.
	local pending = runtime.removeConfirm
	if pending ~= nil then
		local list = pending.listName == "friendly" and runtime.friendly or runtime.hostile
		if pending.key == nil or list[pending.key] == nil then
			runtime.removeConfirm = nil
		end
	end

	local listName = runtime.viewTab or "friendly"
	local keys, list = listView.BuildKeys(listName)
	local count = #keys
	local page, totalPages = ClampSectionPage(listName, count)
	runtime.viewTotalPages = totalPages
	local pageStart = ((page - 1) * ui.VIEW_ROWS_PER_PAGE) + 1

	listView.RefreshChrome()

	-- Header shows the active list name, filtered count, and pager.
	local color = select(3, listView.GetListFor(listName))
	local headerText = (listName == "friendly" and "Friendly" or "Hostile") .. " (" .. tostring(count) .. ")"
	if Trim(runtime.viewFilter or "") ~= "" then
		headerText = headerText .. "  filtered"
	end
	viewWindow.listHeader:SetText(headerText)
	UT.SetLabelColor(viewWindow.listHeader, color)
	PositionSectionPagination(viewWindow.pagination, listView.HEADER_Y)
	UpdateSectionPagination(viewWindow.pagination, page, totalPages)

	local visibleIndex = 1
	for slot = 1, ui.VIEW_ROWS_PER_PAGE do
		local keyIndex = pageStart + slot - 1
		local rowY = listView.ROWS_TOP + ((slot - 1) * ui.VIEW_ROW_HEIGHT)
		if keyIndex <= count then
			local key = keys[keyIndex]
			local row = EnsureViewRow(listName, visibleIndex)
			PositionViewRow(
				row,
				listName,
				key,
				UT.GetEntryName(list[key]),
				UT.GetEntryGuild(list[key]),
				rowY,
				runtime.faction.NameColor(list[key], key)
			)
			visibleIndex = visibleIndex + 1
		end
	end
	HideUnusedViewRows(listName, visibleIndex)

	-- Keep the inactive list's row pool fully hidden.
	HideUnusedViewRows(listName == "friendly" and "hostile" or "friendly", 1)

	viewWindow:SetExtent(ui.VIEW_WINDOW_WIDTH, ui.VIEW_HEIGHT)
end
runtime.RefreshViewList = UpdateViewWindow

local function CreateViewWindow()
	if runtime.viewWindow ~= nil then
		return runtime.viewWindow
	end

	local viewX, viewY = LoadPosition(persist.VIEW_POSITION_KEY, 710, 360)
	local viewWindow = CreateEmptyWindow("unitTrackerViewWindow", "UIParent")
	runtime.viewWindow = viewWindow
	viewWindow:SetExtent(ui.VIEW_WINDOW_WIDTH, ui.VIEW_HEIGHT)
	viewWindow:AddAnchor("TOPLEFT", "UIParent", viewX, viewY)
	viewWindow:EnableDrag(true)
	viewWindow:Clickable(true)
	viewWindow:Show(false)

	local background = viewWindow:CreateColorDrawable(0, 0, 0, 0.72, "background")
	background:AddAnchor("TOPLEFT", viewWindow, 0, 0)
	background:AddAnchor("BOTTOMRIGHT", viewWindow, 0, 0)

	viewWindow.titleLabel = CreateLabel(
		viewWindow,
		"unitTrackerViewTitle",
		"Unit Lists",
		ui.VIEW_WINDOW_WIDTH - 58,
		22,
		ui.PADDING,
		8,
		13,
		{ 0.95, 0.92, 0.82, 1 }
	)
	SafeCall(viewWindow.titleLabel, "EnableDrag", true)

	viewWindow.closeButton = viewWindow:CreateChildWidget("button", "unitTrackerViewCloseButton", 0, true)
	viewWindow.closeButton:SetStyle("text_default")
	viewWindow.closeButton:SetText("X")
	viewWindow.closeButton:SetExtent(30, 20)
	viewWindow.closeButton:AddAnchor("TOPRIGHT", viewWindow, -ui.PADDING, 8)

	-- Tab buttons switch which list is shown (only one list visible at a time).
	viewWindow.friendlyTab = viewWindow:CreateChildWidget("button", "unitTrackerViewFriendlyTab", 0, true)
	viewWindow.friendlyTab:SetStyle("text_default")
	viewWindow.friendlyTab:SetText("Friendly")
	viewWindow.friendlyTab:SetExtent(126, listView.TAB_HEIGHT)
	viewWindow.friendlyTab:AddAnchor("TOPLEFT", viewWindow, ui.PADDING, listView.TAB_Y)
	function viewWindow.friendlyTab:OnClick()
		listView.SetTab("friendly")
		UpdateViewWindow()
	end
	viewWindow.friendlyTab:SetHandler("OnClick", viewWindow.friendlyTab.OnClick)

	viewWindow.hostileTab = viewWindow:CreateChildWidget("button", "unitTrackerViewHostileTab", 0, true)
	viewWindow.hostileTab:SetStyle("text_default")
	viewWindow.hostileTab:SetText("Hostile")
	viewWindow.hostileTab:SetExtent(126, listView.TAB_HEIGHT)
	viewWindow.hostileTab:AddAnchor("TOPLEFT", viewWindow, ui.PADDING + 132, listView.TAB_Y)
	function viewWindow.hostileTab:OnClick()
		listView.SetTab("hostile")
		UpdateViewWindow()
	end
	viewWindow.hostileTab:SetHandler("OnClick", viewWindow.hostileTab.OnClick)

	-- Name filter box; changes re-layout the active list from page 1.
	local function OnFilterChanged(text)
		runtime.viewFilter = tostring(text or "")
		SetSectionPage(runtime.viewTab or "friendly", 1)
		UpdateViewWindow()
	end
	viewWindow.filterState = CreateTrackedEditBox(
		viewWindow,
		"unitTrackerViewFilter",
		ui.PADDING,
		listView.FILTER_Y,
		ui.VIEW_WINDOW_WIDTH - (ui.PADDING * 2) - 98,
		listView.FILTER_HEIGHT,
		40,
		"Filter names...",
		OnFilterChanged
	)
	runtime.viewFilterState = viewWindow.filterState

	-- Sort button cycles Recent -> A-Z -> Notes.
	viewWindow.sortButton = viewWindow:CreateChildWidget("button", "unitTrackerViewSortButton", 0, true)
	viewWindow.sortButton:SetStyle("text_default")
	viewWindow.sortButton:SetText(listView.SortButtonText())
	viewWindow.sortButton:SetExtent(92, listView.FILTER_HEIGHT)
	viewWindow.sortButton:AddAnchor("TOPRIGHT", viewWindow, -ui.PADDING, listView.FILTER_Y)
	function viewWindow.sortButton:OnClick()
		listView.CycleSort()
		UpdateViewWindow()
	end
	viewWindow.sortButton:SetHandler("OnClick", viewWindow.sortButton.OnClick)

	-- Single header row (active list name + count) sharing its row with the pager.
	viewWindow.listHeader = CreateLabel(
		viewWindow,
		"unitTrackerViewListHeader",
		"",
		ui.VIEW_WINDOW_WIDTH - 120,
		20,
		ui.PADDING,
		listView.HEADER_Y,
		12,
		{ 0.9, 0.9, 0.9, 1 }
	)
	viewWindow.pagination = CreateSectionPagination(viewWindow, "active", "unitTrackerView")

	function viewWindow:OnUpdate(dt)
		if not runtime.active then
			return
		end
		-- Poll the filter box; some editbox widgets do not fire OnTextChanged.
		runtime.viewPollElapsed = (runtime.viewPollElapsed or 0) + NormalizeDt(dt)
		if runtime.viewPollElapsed < timing.EDITBOX_POLL_SECONDS then
			return
		end
		runtime.viewPollElapsed = 0
		PollEditBoxText(runtime.viewFilterState)
	end
	viewWindow:SetHandler("OnUpdate", viewWindow.OnUpdate)

	function viewWindow:OnDragStart()
		self:StartMoving()
	end
	viewWindow:SetHandler("OnDragStart", viewWindow.OnDragStart)

	function viewWindow:OnDragStop()
		self:StopMovingOrSizing()
		SaveViewWindowPosition()
	end
	viewWindow:SetHandler("OnDragStop", viewWindow.OnDragStop)

	function viewWindow.titleLabel:OnDragStart()
		viewWindow:StartMoving()
	end
	viewWindow.titleLabel:SetHandler("OnDragStart", viewWindow.titleLabel.OnDragStart)

	function viewWindow.titleLabel:OnDragStop()
		viewWindow:StopMovingOrSizing()
		SaveViewWindowPosition()
	end
	viewWindow.titleLabel:SetHandler("OnDragStop", viewWindow.titleLabel.OnDragStop)

	function viewWindow.closeButton:OnClick()
		runtime.removeConfirm = nil
		viewWindow:Show(false)
	end
	viewWindow.closeButton:SetHandler("OnClick", viewWindow.closeButton.OnClick)

	return viewWindow
end

local function OpenViewWindow()
	local viewWindow = CreateViewWindow()
	SetEditBoxText(runtime.viewFilterState, runtime.viewFilter or "", true)
	UpdateViewWindow()
	viewWindow:Show(true)
end

UT.EnsureViewRow = EnsureViewRow
UT.PositionViewRow = PositionViewRow
UT.HideUnusedViewRows = HideUnusedViewRows
UT.GetTotalPagesForCount = GetTotalPagesForCount
UT.GetSectionPage = GetSectionPage
UT.SetSectionPage = SetSectionPage
UT.BuildOrderedKeys = BuildOrderedKeys
UT.ClampSectionPage = ClampSectionPage
UT.PositionSectionPagination = PositionSectionPagination
UT.UpdateSectionPagination = UpdateSectionPagination
UT.CreateSectionPagination = CreateSectionPagination
UT.UpdateViewWindow = UpdateViewWindow
UT.CreateViewWindow = CreateViewWindow
UT.OpenViewWindow = OpenViewWindow
