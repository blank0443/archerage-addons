local QO = _G.__QUICKOPTS
if QO == nil then
	return
end

ADDON:ImportAPI(API_TYPE.OPTION.id)
ADDON:ImportAPI(API_TYPE.CHAT.id)

-- OIT_AUTO_ENEMY_TARGETING: 0 disabled, 1 enabled.
local MODE_OFF = 0
local MODE_ON = 1
local COLOR_OFF = { 0.9, 0.333, 0.333, 1 }
local COLOR_ON = { 0.348, 0.609, 0.370, 1 }

local toggleButton = nil
local lastMode = nil

local function ReadAutoTargetMode()
	if X2Option == nil or type(X2Option.GetOptionItemValue) ~= "function" then
		return nil
	end
	local ok, value = pcall(function()
		return X2Option:GetOptionItemValue(OIT_AUTO_ENEMY_TARGETING)
	end)
	if not ok then
		return nil
	end
	local number = tonumber(value)
	if number == MODE_OFF or number == MODE_ON then
		return number
	end
	return nil
end

local function WriteAutoTargetMode(mode)
	if X2Option == nil or type(X2Option.SetItemFloatValue) ~= "function" then
		return false
	end
	local value = tonumber(mode) or MODE_OFF
	local ok = pcall(function()
		X2Option:SetItemFloatValue(OIT_AUTO_ENEMY_TARGETING, value)
	end)
	return ok == true
end

local function Refresh()
	if toggleButton == nil then
		return false
	end
	local mode = ReadAutoTargetMode()
	if mode == nil then
		return false
	end
	-- Skip paint when the game value still matches what we already showed.
	if mode == lastMode then
		return true
	end
	lastMode = mode
	if mode == MODE_ON then
		toggleButton:SetText("On")
		QO.SetButtonTextColor(toggleButton, COLOR_ON)
	else
		toggleButton:SetText("Off")
		QO.SetButtonTextColor(toggleButton, COLOR_OFF)
	end
	return true
end

local function Attach(layout)
	if layout == nil or layout.parent == nil then
		return
	end

	toggleButton = layout.parent:CreateChildWidget("button", "quickOptsAutoTargetButton", 0, true)
	lastMode = nil
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
		local mode = ReadAutoTargetMode()
		if mode == nil then
			return
		end
		if mode == MODE_ON then
			WriteAutoTargetMode(MODE_OFF)
			X2Chat:DispatchChatMessage(CMF_SYSTEM, "Auto Target disabled.")
		else
			WriteAutoTargetMode(MODE_ON)
			X2Chat:DispatchChatMessage(CMF_SYSTEM, "Auto Target enabled.")
		end
		Refresh()
	end
	toggleButton:SetHandler("OnClick", toggleButton.OnClick)
	Refresh()
end

QO.RegisterModule({
	id = "auto_target",
	title = "Auto Target",
	Attach = Attach,
	Refresh = Refresh,
})
