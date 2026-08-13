-- Original Author: Strawberry
-- Modified by: Blank

local QO = _G.__QUICKOPTS
if QO == nil then
	return
end

ADDON:ImportAPI(API_TYPE.OPTION.id)
ADDON:ImportAPI(API_TYPE.CHAT.id)

local COLOR_ALL = { 0.348, 0.609, 0.370, 1 }
local COLOR_MINE = { 0.9, 0.333, 0.333, 1 }

local toggleButton = nil
local lastMode = nil

-- Returns 0 (All), 1 (Mine), or nil when the live game option is not readable yet.
local function ReadPortalMode()
	if X2Option == nil or type(X2Option.GetOptionItemValue) ~= "function" then
		return nil
	end
	local ok, value = pcall(function()
		return X2Option:GetOptionItemValue(OIT_AUTO_USE_ONLY_MY_PORTAL)
	end)
	if not ok then
		return nil
	end
	local number = tonumber(value)
	if number == 0 then
		return 0
	end
	if number == 1 then
		return 1
	end
	return nil
end

local function Refresh()
	if toggleButton == nil then
		return false
	end
	local mode = ReadPortalMode()
	if mode == nil then
		return false
	end
	-- Skip paint when the game value still matches what we already showed.
	if mode == lastMode then
		return true
	end
	lastMode = mode
	if mode == 1 then
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

	toggleButton = layout.parent:CreateChildWidget("button", "quickOptsPersonalPortalButton", 0, true)
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
		local mode = ReadPortalMode()
		if mode == nil or X2Option == nil then
			return
		end
		if mode == 1 then
			X2Option:SetItemFloatValue(OIT_AUTO_USE_ONLY_MY_PORTAL, 0)
			X2Chat:DispatchChatMessage(CMF_SYSTEM, "Using ALL portals.")
		else
			X2Option:SetItemFloatValue(OIT_AUTO_USE_ONLY_MY_PORTAL, 1)
			X2Chat:DispatchChatMessage(CMF_SYSTEM, "Using ONLY YOUR portals.")
		end
		Refresh()
	end
	toggleButton:SetHandler("OnClick", toggleButton.OnClick)
	Refresh()
end

QO.RegisterModule({
	id = "personal_portal",
	title = "Personal Portal",
	Attach = Attach,
	Refresh = Refresh,
})
