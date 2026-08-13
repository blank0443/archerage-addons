local QO = _G.__QUICKOPTS
if QO == nil then
	return
end

ADDON:ImportAPI(API_TYPE.OPTION.id)
ADDON:ImportAPI(API_TYPE.CHAT.id)

-- OIT_OPTION_ITEM_MOUNT_ONLY_MY_PET: 0 any mounts, 1 only your mounts.
local MODE_ALL = 0
local MODE_MINE = 1
local COLOR_ALL = { 0.348, 0.609, 0.370, 1 }
local COLOR_MINE = { 0.9, 0.333, 0.333, 1 }

local toggleButton = nil
local lastMode = nil

local function ReadMountMode()
	if X2Option == nil or type(X2Option.GetOptionItemValue) ~= "function" then
		return nil
	end
	local ok, value = pcall(function()
		return X2Option:GetOptionItemValue(OIT_OPTION_ITEM_MOUNT_ONLY_MY_PET)
	end)
	if not ok then
		return nil
	end
	local number = tonumber(value)
	if number == MODE_ALL or number == MODE_MINE then
		return number
	end
	return nil
end

local function WriteMountMode(mode)
	if X2Option == nil or type(X2Option.SetItemFloatValue) ~= "function" then
		return false
	end
	local value = tonumber(mode) or MODE_MINE
	local ok = pcall(function()
		X2Option:SetItemFloatValue(OIT_OPTION_ITEM_MOUNT_ONLY_MY_PET, value)
	end)
	return ok == true
end

local function Refresh()
	if toggleButton == nil then
		return false
	end
	local mode = ReadMountMode()
	if mode == nil then
		return false
	end
	-- Skip paint when the game value still matches what we already showed.
	if mode == lastMode then
		return true
	end
	lastMode = mode
	if mode == MODE_MINE then
		toggleButton:SetText("Mine")
		QO.SetButtonTextColor(toggleButton, COLOR_MINE)
	else
		toggleButton:SetText("All")
		QO.SetButtonTextColor(toggleButton, COLOR_ALL)
	end
	return true
end

local function Attach(layout)
	if layout == nil or layout.parent == nil then
		return
	end

	toggleButton = layout.parent:CreateChildWidget("button", "quickOptsMountOwnButton", 0, true)
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
		local mode = ReadMountMode()
		if mode == nil then
			return
		end
		if mode == MODE_MINE then
			WriteMountMode(MODE_ALL)
			X2Chat:DispatchChatMessage(CMF_SYSTEM, "Allowing ANY mounts.")
		else
			WriteMountMode(MODE_MINE)
			X2Chat:DispatchChatMessage(CMF_SYSTEM, "Using ONLY YOUR mounts.")
		end
		Refresh()
	end
	toggleButton:SetHandler("OnClick", toggleButton.OnClick)
	Refresh()
end

QO.RegisterModule({
	id = "mount_own",
	title = "Mount Own",
	Attach = Attach,
	Refresh = Refresh,
})
