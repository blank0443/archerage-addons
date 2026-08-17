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

ADDON:ImportAPI(API_TYPE.OPTION.id)
ADDON:ImportAPI(API_TYPE.CHAT.id)

local QO = _G.__QUICKOPTS or {}
_G.__QUICKOPTS = QO

local POSITION_KEY = "quickOptsWindowPosition"
local WINDOW_VISIBLE_KEY = "quickOptsWindowVisible"
local ESC_MENU_CATEGORY_ID = 5
local ESC_MENU_CONTENT_ID = 1557
local ESC_MENU_ICON_KEY = "guide"
local ESC_MENU_BUTTON_NAME = "Quick Opts"

local WINDOW_WIDTH = 220
local HEADER_HEIGHT = 22
local ROW_HEIGHT = 28
local PADDING = 8
local LABEL_WIDTH = 118
local BUTTON_WIDTH = 86
local CLOSE_BUTTON_WIDTH = 22
local CLOSE_BUTTON_HEIGHT = 18
-- Poll live X2Option values so rows track changes made in the game Options UI.
local OPTION_POLL_INTERVAL = 5.0
local OPTION_SYNC_INTERVAL = 0.2
local OPTION_SYNC_ATTEMPTS = 10

local previousRuntime = _G.__QUICKOPTS_RUNTIME
if previousRuntime == nil then
	previousRuntime = _G.__SKILLQUEUE_RUNTIME
end
if previousRuntime ~= nil then
	previousRuntime.active = false
	previousRuntime.syncPending = false
	if previousRuntime.eventWindow ~= nil then
		pcall(previousRuntime.eventWindow.SetHandler, previousRuntime.eventWindow, "OnUpdate", nil)
		pcall(previousRuntime.eventWindow.SetHandler, previousRuntime.eventWindow, "OnEvent", nil)
		previousRuntime.eventWindow:Show(false)
	end
	if previousRuntime.window ~= nil then
		previousRuntime.window:Show(false)
	end
end

local runtime = {
	active = true,
	window = nil,
	headerLabel = nil,
	closeButton = nil,
	modules = {},
	moduleById = {},
	loading = false,
	escMenuButtonRegistered = false,
	syncPending = false,
	syncElapsed = 0,
	syncAttempts = 0,
	pollElapsed = 0,
}
_G.__QUICKOPTS_RUNTIME = runtime
QO.runtime = runtime

function QO.SafeCall(target, methodName, ...)
	if target == nil or type(target[methodName]) ~= "function" then
		return false, nil
	end
	return pcall(target[methodName], target, ...)
end

function QO.SaveData(key, value)
	pcall(function()
		ADDON:ClearData(key)
		ADDON:SaveData(key, value)
	end)
end

function QO.LoadData(key)
	local ok, data = pcall(function()
		return ADDON:LoadData(key)
	end)
	if ok then
		return data
	end
	return nil
end

function QO.SetButtonTextColor(button, color)
	if button == nil or color == nil then
		return
	end

	if type(SetButtonFontOneColor) == "function" then
		pcall(SetButtonFontOneColor, button, color)
	end

	QO.SafeCall(button, "SetTextColor", color[1], color[2], color[3], color[4])
	QO.SafeCall(button, "SetHighlightTextColor", color[1], color[2], color[3], color[4])
	QO.SafeCall(button, "SetPushedTextColor", color[1], color[2], color[3], color[4])
	if button.style ~= nil and type(button.style.SetColor) == "function" then
		pcall(function()
			button.style:SetColor(color[1], color[2], color[3], color[4])
		end)
	end
end

local function LoadPosition(defaultX, defaultY)
	local data = QO.LoadData(POSITION_KEY)
	if type(data) == "table" and data.x ~= nil and data.y ~= nil then
		return tonumber(data.x) or defaultX, tonumber(data.y) or defaultY
	end
	return defaultX, defaultY
end

function QO.SaveWindowPosition()
	if runtime.window == nil then
		return
	end
	local ok, x, y = QO.SafeCall(runtime.window, "GetOffset")
	if ok and x ~= nil and y ~= nil then
		QO.SaveData(POSITION_KEY, {
			x = math.floor(x + 0.5),
			y = math.floor(y + 0.5),
		})
	end
end

local function SaveWindowVisible(visible)
	QO.SaveData(WINDOW_VISIBLE_KEY, {
		visible = visible == true,
	})
end

local function LoadWindowVisible(defaultVisible)
	local data = QO.LoadData(WINDOW_VISIBLE_KEY)
	if type(data) == "table" then
		return data.visible == true
	end
	if type(data) == "boolean" then
		return data
	end
	return defaultVisible == true
end

local function GetWindowHeight()
	-- Zero modules: header + close button only. Rows grow as files register.
	return HEADER_HEIGHT + (#runtime.modules * ROW_HEIGHT) + PADDING
end

local function ResizeWindow()
	if runtime.window == nil then
		return
	end
	runtime.window:SetExtent(WINDOW_WIDTH, GetWindowHeight())
end

local function RefreshModules()
	for i = 1, #runtime.modules do
		local module = runtime.modules[i]
		if module ~= nil and type(module.Refresh) == "function" then
			pcall(module.Refresh)
		end
	end
end

-- Options are often unread until world load; retry so rows show live game values, not placeholders.
local function StartOptionSync()
	runtime.syncPending = true
	runtime.syncElapsed = 0
	runtime.syncAttempts = 0
	runtime.pollElapsed = 0
	RefreshModules()
end

local function NormalizeDt(dt)
	local delta = tonumber(dt) or 0
	-- X2 OnUpdate often reports milliseconds; keep poll intervals in seconds.
	if delta > 1 then
		delta = delta / 1000
	end
	return delta
end

local function OnOptionPollUpdate(dt)
	if runtime.loading then
		return
	end

	local delta = NormalizeDt(dt)

	-- Fast retries right after load / show until values are readable.
	if runtime.syncPending then
		runtime.syncElapsed = runtime.syncElapsed + delta
		if runtime.syncElapsed >= OPTION_SYNC_INTERVAL then
			runtime.syncElapsed = 0
			runtime.syncAttempts = runtime.syncAttempts + 1
			RefreshModules()
			if runtime.syncAttempts >= OPTION_SYNC_ATTEMPTS then
				runtime.syncPending = false
			end
		end
		return
	end

	-- Steady poll: modules only paint when the live value differs from last painted.
	runtime.pollElapsed = runtime.pollElapsed + delta
	if runtime.pollElapsed < OPTION_POLL_INTERVAL then
		return
	end
	runtime.pollElapsed = 0
	RefreshModules()
end

local function AttachModule(module, index)
	if runtime.window == nil or module == nil or module.attached == true then
		return
	end

	local y = HEADER_HEIGHT + ((index - 1) * ROW_HEIGHT)
	local label = runtime.window:CreateChildWidget("label", "quickOptsLabel_" .. tostring(module.id), 0, true)
	label:SetText(module.title or module.id or "Option")
	label:SetExtent(LABEL_WIDTH, ROW_HEIGHT)
	label.style:SetAlign(ALIGN_LEFT)
	label.style:SetFontSize(11)
	label.style:SetColor(0.95, 0.92, 0.82, 1)
	label.style:SetOutline(true)
	label:AddAnchor("TOPLEFT", runtime.window, PADDING, y)
	QO.SafeCall(label, "EnableDrag", true)

	function label:OnDragStart()
		runtime.window:StartMoving()
	end
	label:SetHandler("OnDragStart", label.OnDragStart)

	function label:OnDragStop()
		runtime.window:StopMovingOrSizing()
		QO.SaveWindowPosition()
	end
	label:SetHandler("OnDragStop", label.OnDragStop)

	module.rowLabel = label
	module.attached = true

	if type(module.Attach) == "function" then
		pcall(module.Attach, {
			parent = runtime.window,
			y = y,
			rowHeight = ROW_HEIGHT,
			labelWidth = LABEL_WIDTH,
			buttonWidth = BUTTON_WIDTH,
			padding = PADDING,
			windowWidth = WINDOW_WIDTH,
		})
	end
	if type(module.Refresh) == "function" then
		pcall(module.Refresh)
	end
end

function QO.RegisterModule(module)
	if type(module) ~= "table" or module.id == nil then
		return false
	end
	if runtime.moduleById[module.id] ~= nil then
		return false
	end

	module.attached = false
	runtime.modules[#runtime.modules + 1] = module
	runtime.moduleById[module.id] = module

	if runtime.window ~= nil then
		pcall(AttachModule, module, #runtime.modules)
		ResizeWindow()
		StartOptionSync()
	end
	return true
end

-- Checkboxes can come back as bools/strings; Lua tonumber(true) is nil.
function QO.CoerceOptionValue(value)
	if value == true then
		return 1
	end
	if value == false then
		return 0
	end
	if type(value) == "string" then
		local lower = string.lower(value)
		if lower == "true" or lower == "on" or lower == "yes" then
			return 1
		end
		if lower == "false" or lower == "off" or lower == "no" then
			return 0
		end
	end
	local number = tonumber(value)
	if number == nil then
		return nil
	end
	local rounded = math.floor(number + 0.5)
	if math.abs(number - rounded) < 0.001 then
		return rounded
	end
	return number
end

function QO.ReadLiveOption(spec)
	if type(spec) ~= "table" then
		return nil
	end

	local function tryRaw(raw)
		local number = QO.CoerceOptionValue(raw)
		if number == nil then
			return nil
		end
		-- Unmapped type-id numbers must fall through to optionName.
		if spec.states ~= nil and QO.FindOptionStateIndex(spec.states, number) == nil then
			return nil
		end
		return number
	end

	if type(spec.read) == "function" then
		local ok, value = pcall(spec.read)
		if ok then
			return tryRaw(value)
		end
		return nil
	end
	if X2Option == nil then
		return nil
	end
	local optionType = spec.optionType
	if optionType ~= nil and type(X2Option.GetOptionItemValue) == "function" then
		local ok, value = pcall(function()
			return X2Option:GetOptionItemValue(optionType)
		end)
		if ok then
			local number = tryRaw(value)
			if number ~= nil then
				return number
			end
		end
	end
	local optionName = spec.optionName
	if optionName ~= nil and type(X2Option.GetOptionItemValueByName) == "function" then
		local ok, value = pcall(function()
			return X2Option:GetOptionItemValueByName(optionName)
		end)
		if ok then
			return tryRaw(value)
		end
	end
	return nil
end

function QO.WriteLiveOption(spec, value)
	if type(spec) ~= "table" then
		return false
	end
	if type(spec.write) == "function" then
		local ok = pcall(spec.write, value)
		return ok == true
	end
	if X2Option == nil then
		return false
	end
	local number = tonumber(value)
	if number == nil then
		return false
	end
	local optionType = spec.optionType
	if optionType ~= nil and type(X2Option.SetItemFloatValue) == "function" then
		local ok = pcall(function()
			X2Option:SetItemFloatValue(optionType, number)
		end)
		if ok then
			return true
		end
	end
	local optionName = spec.optionName
	if optionName ~= nil and type(X2Option.SetItemFloatValueByName) == "function" then
		local ok = pcall(function()
			X2Option:SetItemFloatValueByName(optionName, number)
		end)
		if ok then
			return true
		end
	end
	return false
end

function QO.FindOptionStateIndex(states, value)
	if type(states) ~= "table" then
		return nil
	end
	local number = QO.CoerceOptionValue(value)
	if number == nil then
		return nil
	end
	for i = 1, #states do
		local state = states[i]
		if state ~= nil and QO.CoerceOptionValue(state.value) == number then
			return i
		end
	end
	return nil
end

-- Hub-owned row: setting files only pass id, title, option, and states.
function QO.RegisterOption(spec)
	local ok, registered = pcall(function()
		if type(spec) ~= "table" or spec.id == nil then
			return false
		end
		if type(spec.states) ~= "table" or #spec.states < 1 then
			return false
		end
		if spec.optionType == nil and spec.optionName == nil and type(spec.read) ~= "function" then
			return false
		end

		local optionSpec = spec
		local lastValue = nil
		local toggleButton = nil

		local function Refresh()
			if toggleButton == nil then
				return false
			end
			local mode = QO.ReadLiveOption(optionSpec)
			local index = QO.FindOptionStateIndex(optionSpec.states, mode)
			if index == nil then
				return false
			end
			if mode == lastValue then
				return true
			end
			lastValue = mode
			local state = optionSpec.states[index]
			toggleButton:SetText(state.text or "")
			QO.SetButtonTextColor(toggleButton, state.color)
			return true
		end

		local function CycleOption()
			local mode = QO.ReadLiveOption(optionSpec)
			local index = QO.FindOptionStateIndex(optionSpec.states, mode)
			-- Unreadable live value: write the first state instead of no-op.
			if index == nil then
				index = 0
			end
			local nextIndex = index + 1
			if nextIndex > #optionSpec.states then
				nextIndex = 1
			end
			local nextState = optionSpec.states[nextIndex]
			if nextState == nil then
				return
			end
			QO.WriteLiveOption(optionSpec, nextState.value)
			if nextState.chat ~= nil and X2Chat ~= nil then
				pcall(function()
					X2Chat:DispatchChatMessage(CMF_SYSTEM, tostring(nextState.chat))
				end)
			end
			Refresh()
		end

		local function Attach(layout)
			if layout == nil or layout.parent == nil then
				return
			end
			toggleButton = layout.parent:CreateChildWidget(
				"button",
				"quickOptsButton_" .. tostring(optionSpec.id),
				0,
				true
			)
			lastValue = nil
			toggleButton:SetStyle("text_default")
			toggleButton:SetText("")
			toggleButton:SetExtent(layout.buttonWidth, layout.rowHeight - 4)
			toggleButton:AddAnchor(
				"TOPLEFT",
				layout.parent,
				layout.padding + layout.labelWidth + 2,
				layout.y + 2
			)
			QO.SafeCall(toggleButton, "EnableDrag", true)

			function toggleButton:OnDragStart()
				layout.parent:StartMoving()
			end
			toggleButton:SetHandler("OnDragStart", toggleButton.OnDragStart)

			function toggleButton:OnDragStop()
				layout.parent:StopMovingOrSizing()
				QO.SaveWindowPosition()
			end
			toggleButton:SetHandler("OnDragStop", toggleButton.OnDragStop)

			function toggleButton:OnClick()
				pcall(CycleOption)
			end
			toggleButton:SetHandler("OnClick", toggleButton.OnClick)
			Refresh()
		end

		return QO.RegisterModule({
			id = optionSpec.id,
			title = optionSpec.title or optionSpec.id,
			Attach = Attach,
			Refresh = Refresh,
		})
	end)

	if not ok then
		return false
	end
	return registered == true
end

function QO.LayoutModules()
	if runtime.window == nil then
		return
	end
	for i = 1, #runtime.modules do
		AttachModule(runtime.modules[i], i)
	end
	ResizeWindow()
	StartOptionSync()
end

local function IsWindowVisible()
	if runtime.window == nil then
		return false
	end
	local ok, visible = QO.SafeCall(runtime.window, "IsVisible")
	return ok and visible == true
end

local function SetWindowVisible(visible)
	if runtime.window == nil then
		return
	end
	local show = visible == true
	runtime.window:Show(show)
	SaveWindowVisible(show)
	if show then
		StartOptionSync()
	end
end

local function OpenFromEscMenu(show)
	if show == false then
		SetWindowVisible(false)
		return
	end

	-- Menu click passes nil; refresh broadcasts can pass true and should not reopen.
	if show == nil then
		if IsWindowVisible() then
			SetWindowVisible(false)
		else
			SetWindowVisible(true)
		end
	end
end

local function RegisterEscMenuButton()
	if ADDON == nil
		or type(ADDON.RegisterContentTriggerFunc) ~= "function"
		or type(ADDON.AddEscMenuButton) ~= "function"
	then
		return false
	end

	local ok = pcall(function()
		ADDON:RegisterContentTriggerFunc(ESC_MENU_CONTENT_ID, function(show)
			local currentRuntime = _G.__QUICKOPTS_RUNTIME
			if currentRuntime == nil or not currentRuntime.active or currentRuntime.window == nil then
				return
			end
			OpenFromEscMenu(show)
		end)
		-- Re-add when name or icon changed so the old Skill Queue / skill entry is replaced.
		if _G.__QUICKOPTS_ESC_MENU_BUTTON_ADDED ~= true
			or _G.__QUICKOPTS_ESC_MENU_BUTTON_NAME ~= ESC_MENU_BUTTON_NAME
			or _G.__QUICKOPTS_ESC_MENU_ICON_KEY ~= ESC_MENU_ICON_KEY
		then
			ADDON:AddEscMenuButton(
				ESC_MENU_CATEGORY_ID,
				ESC_MENU_CONTENT_ID,
				ESC_MENU_ICON_KEY,
				ESC_MENU_BUTTON_NAME
			)
			_G.__QUICKOPTS_ESC_MENU_BUTTON_NAME = ESC_MENU_BUTTON_NAME
			_G.__QUICKOPTS_ESC_MENU_ICON_KEY = ESC_MENU_ICON_KEY
			_G.__QUICKOPTS_ESC_MENU_BUTTON_ADDED = true
		end
	end)

	if ok then
		runtime.escMenuButtonRegistered = true
	end
	return ok
end

local function CreateWindow()
	local x, y = LoadPosition(40, 260)
	local window = CreateEmptyWindow("quickOptsWindow", "UIParent")
	runtime.window = window
	window:SetExtent(WINDOW_WIDTH, GetWindowHeight())
	window:AddAnchor("TOPLEFT", "UIParent", x, y)
	window:EnableDrag(true)
	window:Clickable(true)
	window:Show(false)

	local background = window:CreateColorDrawable(0, 0, 0, 0.58, "background")
	background:AddAnchor("TOPLEFT", window, 0, 0)
	background:AddAnchor("BOTTOMRIGHT", window, 0, 0)

	local headerLabel = window:CreateChildWidget("label", "quickOptsHeaderLabel", 0, true)
	runtime.headerLabel = headerLabel
	headerLabel:SetText("Quick Opts")
	headerLabel:SetExtent(WINDOW_WIDTH - (PADDING * 2) - CLOSE_BUTTON_WIDTH - 4, HEADER_HEIGHT)
	headerLabel.style:SetAlign(ALIGN_LEFT)
	headerLabel.style:SetFontSize(12)
	headerLabel.style:SetColor(0.95, 0.92, 0.82, 1)
	headerLabel.style:SetOutline(true)
	headerLabel:AddAnchor("TOPLEFT", window, PADDING, 2)
	QO.SafeCall(headerLabel, "EnableDrag", true)

	local closeButton = window:CreateChildWidget("button", "quickOptsCloseButton", 0, true)
	runtime.closeButton = closeButton
	closeButton:SetStyle("text_default")
	closeButton:SetText("X")
	closeButton:SetExtent(CLOSE_BUTTON_WIDTH, CLOSE_BUTTON_HEIGHT)
	closeButton:AddAnchor("TOPRIGHT", window, -PADDING + 2, 2)

	function closeButton:OnClick()
		SetWindowVisible(false)
	end
	closeButton:SetHandler("OnClick", closeButton.OnClick)

	function window:OnDragStart()
		self:StartMoving()
	end
	window:SetHandler("OnDragStart", window.OnDragStart)

	function window:OnDragStop()
		self:StopMovingOrSizing()
		QO.SaveWindowPosition()
	end
	window:SetHandler("OnDragStop", window.OnDragStop)

	function headerLabel:OnDragStart()
		window:StartMoving()
	end
	headerLabel:SetHandler("OnDragStart", headerLabel.OnDragStart)

	function headerLabel:OnDragStop()
		window:StopMovingOrSizing()
		QO.SaveWindowPosition()
	end
	headerLabel:SetHandler("OnDragStop", headerLabel.OnDragStop)

	return window
end

local function OnLoadingStarted()
	runtime.loading = true
	runtime.syncPending = false
	runtime.pollElapsed = 0
	if runtime.window ~= nil then
		runtime.window:Show(false)
	end
end

local function OnLoadingFinished()
	runtime.loading = false
	-- Always pull live X2Option values after load, even if the window stays hidden.
	StartOptionSync()
	if runtime.window ~= nil and LoadWindowVisible(true) then
		runtime.window:Show(true)
	end
end

CreateWindow()
SetWindowVisible(LoadWindowVisible(true))
RegisterEscMenuButton()

local eventWindow = CreateEmptyWindow("quickOptsEventWindow", "UIParent")
runtime.eventWindow = eventWindow
-- Hidden windows do not receive OnUpdate; keep a 1px off-screen window shown.
eventWindow:SetExtent(1, 1)
eventWindow:AddAnchor("TOPLEFT", "UIParent", -2000, -2000)
eventWindow:Clickable(false)
eventWindow:Show(true)

function eventWindow:OnEvent(event)
	if not runtime.active then
		return
	end
	if event == "ENTERED_LOADING" then
		OnLoadingStarted()
		return
	end
	if event == "LEFT_LOADING" or event == "ENTERED_WORLD" then
		OnLoadingFinished()
	end
end
eventWindow:SetHandler("OnEvent", eventWindow.OnEvent)
eventWindow:RegisterEvent("ENTERED_LOADING")
eventWindow:RegisterEvent("LEFT_LOADING")
eventWindow:RegisterEvent("ENTERED_WORLD")

function eventWindow:OnUpdate(dt)
	if not runtime.active then
		return
	end
	OnOptionPollUpdate(dt)
end
eventWindow:SetHandler("OnUpdate", eventWindow.OnUpdate)
