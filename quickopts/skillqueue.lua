local QO = _G.__QUICKOPTS
if QO == nil then
	return
end

ADDON:ImportAPI(API_TYPE.OPTION.id)

local OPTION_NAME = "OPTION_CUSTOM_SKILL_QUEUE"

-- custom_skill_queue: 0 disable, 1 enable except combo (Limited), 2 enable to all (Full).
local MODE_DISABLED = 0
local MODE_LIMITED = 1
local MODE_FULL = 2
local MODE_INFO = {
	[MODE_DISABLED] = {
		text = "Disabled",
		color = { 0.9, 0.333, 0.333, 1 },
	},
	[MODE_LIMITED] = {
		text = "Limited",
		color = { 0.95, 0.58, 0.18, 1 },
	},
	[MODE_FULL] = {
		text = "Full",
		color = { 0.348, 0.609, 0.370, 1 },
	},
}

local toggleButton = nil
local lastMode = nil

local function GetOptionType()
	if OIT_OPTION_CUSTOM_SKILL_QUEUE ~= nil then
		return OIT_OPTION_CUSTOM_SKILL_QUEUE
	end
	return nil
end

local function ReadOptionValue()
	if X2Option == nil then
		return nil
	end

	local optionType = GetOptionType()
	if optionType ~= nil and type(X2Option.GetOptionItemValue) == "function" then
		local ok, value = pcall(function()
			return X2Option:GetOptionItemValue(optionType)
		end)
		if ok then
			return value
		end
	end

	if type(X2Option.GetOptionItemValueByName) == "function" then
		local ok, value = pcall(function()
			return X2Option:GetOptionItemValueByName(OPTION_NAME)
		end)
		if ok then
			return value
		end
	end

	return nil
end

local function WriteOptionValue(mode)
	if X2Option == nil then
		return false
	end

	local value = tonumber(mode) or MODE_DISABLED
	local optionType = GetOptionType()
	if optionType ~= nil and type(X2Option.SetItemFloatValue) == "function" then
		local ok = pcall(function()
			X2Option:SetItemFloatValue(optionType, value)
		end)
		if ok then
			return true
		end
	end

	if type(X2Option.SetItemFloatValueByName) == "function" then
		local ok = pcall(function()
			X2Option:SetItemFloatValueByName(OPTION_NAME, value)
		end)
		if ok then
			return true
		end
	end

	return false
end

local function GetSkillQueueMode()
	local number = tonumber(ReadOptionValue())
	if number == MODE_DISABLED or number == MODE_LIMITED or number == MODE_FULL then
		return number
	end
	return nil
end

local function Refresh()
	if toggleButton == nil then
		return false
	end
	local mode = GetSkillQueueMode()
	if mode == nil then
		return false
	end
	local info = MODE_INFO[mode]
	if info == nil then
		return false
	end
	-- Skip paint when the game value still matches what we already showed.
	if mode == lastMode then
		return true
	end
	lastMode = mode
	toggleButton:SetText(info.text)
	QO.SetButtonTextColor(toggleButton, info.color)
	return true
end

local function CycleSkillQueueMode()
	local current = GetSkillQueueMode()
	if current == nil then
		return
	end
	local nextMode = current + 1
	if nextMode > MODE_FULL then
		nextMode = MODE_DISABLED
	end
	WriteOptionValue(nextMode)
	Refresh()
end

local function Attach(layout)
	if layout == nil or layout.parent == nil then
		return
	end

	toggleButton = layout.parent:CreateChildWidget("button", "quickOptsSkillQueueButton", 0, true)
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
		CycleSkillQueueMode()
	end
	toggleButton:SetHandler("OnClick", toggleButton.OnClick)
	Refresh()
end

QO.RegisterModule({
	id = "skillqueue",
	title = "Skill Queue",
	Attach = Attach,
	Refresh = Refresh,
})
