local QO = _G.__QUICKOPTS
if QO == nil then
	return
end

ADDON:ImportAPI(API_TYPE.OPTION.id)
ADDON:ImportAPI(API_TYPE.CHAT.id)

-- OIT_OPTION_CHARACTER_PRIVACY_STATUS: 0 public, 1 private.
local MODE_PUBLIC = 0
local MODE_PRIVATE = 1
local COLOR_PUBLIC = { 0.348, 0.609, 0.370, 1 }
local COLOR_PRIVATE = { 0.9, 0.333, 0.333, 1 }

local toggleButton = nil
local lastMode = nil

local function ReadPrivacyStatus()
	if X2Option == nil or type(X2Option.GetOptionItemValue) ~= "function" then
		return nil
	end
	local ok, value = pcall(function()
		return X2Option:GetOptionItemValue(OIT_OPTION_CHARACTER_PRIVACY_STATUS)
	end)
	if not ok then
		return nil
	end
	local number = tonumber(value)
	if number == MODE_PUBLIC or number == MODE_PRIVATE then
		return number
	end
	return nil
end

local function WritePrivacyStatus(mode)
	if X2Option == nil or type(X2Option.SetItemFloatValue) ~= "function" then
		return false
	end
	local value = tonumber(mode) or MODE_PRIVATE
	local ok = pcall(function()
		X2Option:SetItemFloatValue(OIT_OPTION_CHARACTER_PRIVACY_STATUS, value)
	end)
	return ok == true
end

local function Refresh()
	if toggleButton == nil then
		return false
	end
	local mode = ReadPrivacyStatus()
	if mode == nil then
		return false
	end
	-- Skip paint when the game value still matches what we already showed.
	if mode == lastMode then
		return true
	end
	lastMode = mode
	if mode == MODE_PRIVATE then
		toggleButton:SetText("Private")
		QO.SetButtonTextColor(toggleButton, COLOR_PRIVATE)
	else
		toggleButton:SetText("Public")
		QO.SetButtonTextColor(toggleButton, COLOR_PUBLIC)
	end
	return true
end

local function Attach(layout)
	if layout == nil or layout.parent == nil then
		return
	end

	toggleButton = layout.parent:CreateChildWidget("button", "quickOptsGearStatusButton", 0, true)
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
		local mode = ReadPrivacyStatus()
		if mode == nil then
			return
		end
		if mode == MODE_PRIVATE then
			WritePrivacyStatus(MODE_PUBLIC)
			X2Chat:DispatchChatMessage(CMF_SYSTEM, "Gear status set to PUBLIC.")
		else
			WritePrivacyStatus(MODE_PRIVATE)
			X2Chat:DispatchChatMessage(CMF_SYSTEM, "Gear status set to PRIVATE.")
		end
		Refresh()
	end
	toggleButton:SetHandler("OnClick", toggleButton.OnClick)
	Refresh()
end

QO.RegisterModule({
	id = "gear_status",
	title = "Gear Status",
	Attach = Attach,
	Refresh = Refresh,
})
