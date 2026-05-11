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
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)

ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.TEAM.id)

local previousRuntime = _G.__CHOTKEYS_RAID_ORG_RUNTIME
if previousRuntime ~= nil then
	previousRuntime.active = false
	if previousRuntime.raidFrameWindow ~= nil then
		previousRuntime.raidFrameWindow:Show(false)
	end
	if previousRuntime.overlayRoot ~= nil then
		previousRuntime.overlayRoot:Show(false)
	end
	if previousRuntime.raidOrgButton ~= nil then
		previousRuntime.raidOrgButton:Show(false)
	end
end

local runtime = {
	active = true,
	raidOrgButton = nil,
	raidFrameWindow = nil,
	overlayRoot = nil,
}
_G.__CHOTKEYS_RAID_ORG_RUNTIME = runtime

local raidFrameWindow
local overlayRoot

local function Log(msg)
	X2Chat:DispatchChatMessage(CMF_SYSTEM, "[raid_org] " .. tostring(msg))
end

local function FormatProbeValue(value)
	local t = type(value)
	if t == "nil" then
		return "nil"
	end
	if t == "number" then
		return tostring(math.floor(value * 100 + 0.5) / 100)
	end
	if t == "boolean" then
		return value and "true" or "false"
	end
	if t == "string" then
		local s = value
		if string.len(s) > 36 then
			s = string.sub(s, 1, 33) .. "..."
		end
		return "\"" .. s .. "\""
	end
	return "<" .. t .. ">"
end

local function ProbeMethodCall(target, methodName, arg)
	local fn = target[methodName]
	if type(fn) ~= "function" then
		return false, nil, nil
	end

	local ok = false
	local r1, r2, r3, r4 = nil, nil, nil, nil
	if arg ~= nil then
		ok, r1, r2, r3, r4 = pcall(function()
			return fn(target, arg)
		end)
	else
		ok, r1, r2, r3, r4 = pcall(function()
			return fn(target)
		end)
	end

	if not ok then
		return true, false, nil
	end

	local resultText = FormatProbeValue(r1)
	if r2 ~= nil then
		resultText = resultText .. ", " .. FormatProbeValue(r2)
	end
	if r3 ~= nil then
		resultText = resultText .. ", " .. FormatProbeValue(r3)
	end
	if r4 ~= nil then
		resultText = resultText .. ", " .. FormatProbeValue(r4)
	end
	return true, true, resultText
end

local function ProbeRaidFrameGeometryExposure(reason)
	local methodNames = {
		"GetExtent",
		"GetWidth",
		"GetHeight",
		"GetOffset",
		"GetAnchor",
		"GetAnchors",
		"GetRect",
		"GetBounds",
		"GetScreenPosition",
		"GetLeft",
		"GetTop",
		"GetRight",
		"GetBottom",
		"GetWidget",
		"FindWidget",
		"GetChildWidget",
		"GetChildById",
		"GetChildByName",
	}

	local candidates = {}
	local seenLabels = {}
	local function AddCandidate(label, target)
		if target == nil then
			return
		end
		if type(target) ~= "table" and type(target) ~= "userdata" then
			return
		end
		if seenLabels[label] then
			return
		end
		seenLabels[label] = true
		candidates[#candidates + 1] = { label = label, target = target }
	end

	AddCandidate("UIParent", UIParent)
	AddCandidate("raidFrameWindow", raidFrameWindow)
	AddCandidate("overlayRoot", overlayRoot)

	for key, value in pairs(_G) do
		if (type(value) == "table" or type(value) == "userdata") and type(key) == "string" then
			local lowered = string.lower(key)
			if string.find(lowered, "raid", 1, true)
				or string.find(lowered, "party", 1, true)
				or string.find(lowered, "team", 1, true)
				or string.find(lowered, "frame", 1, true) then
				AddCandidate(key, value)
			end
		end
	end

	Log("probe start: " .. tostring(reason or "manual") .. ", candidates=" .. tostring(#candidates))

	local emitted = 0
	local maxEmit = 80
	for _, candidate in ipairs(candidates) do
		for _, methodName in ipairs(methodNames) do
			local exists, okCall, resultText = ProbeMethodCall(candidate.target, methodName, nil)
			if exists then
				if okCall then
					Log(candidate.label .. "." .. methodName .. "() => " .. tostring(resultText))
				else
					local existsWithArg, okWithArg, argResult = ProbeMethodCall(candidate.target, methodName, 1)
					if existsWithArg and okWithArg then
						Log(candidate.label .. "." .. methodName .. "(1) => " .. tostring(argResult))
					else
						Log(candidate.label .. "." .. methodName .. " exists (call failed)")
					end
				end
				emitted = emitted + 1
				if emitted >= maxEmit then
					Log("probe truncated at " .. tostring(maxEmit) .. " lines")
					Log("probe end")
					return
				end
			end
		end
	end

	Log("probe end")
end

local function NormalizeIdentity(value)
	if value == nil then
		return nil
	end

	local s = tostring(value)
	s = string.gsub(s, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	if s == "" then
		return nil
	end

	local lowered = string.lower(s)
	if lowered == "nil" or lowered == "none" then
		return nil
	end

	return lowered
end

local function ToNumber(value)
	if type(value) == "number" then
		return value
	end
	if type(value) == "string" then
		return tonumber(value)
	end
	return nil
end

local function SafeUnitName(unitType)
	local ok, name = pcall(function()
		return X2Unit:UnitName(unitType)
	end)
	if not ok then
		return nil
	end

	local normalized = NormalizeIdentity(name)
	if normalized == nil then
		return nil
	end

	return tostring(name)
end

local function GetUnitNameByToken(token)
	local name = SafeUnitName(token)
	if name ~= nil then
		return name
	end

	local first = string.sub(token, 1, 1)
	local rest = string.sub(token, 2)
	local alt = string.upper(first) .. rest
	return SafeUnitName(alt)
end

local function TryReadUnitHealth(unitToken)
	if unitToken == nil then
		return nil
	end

	local token = tostring(unitToken)
	local okCur, curRaw = pcall(function()
		return X2Unit:UnitHealth(token)
	end)
	local okMax, maxRaw = pcall(function()
		return X2Unit:UnitMaxHealth(token)
	end)

	local cur = okCur and ToNumber(curRaw) or nil
	local max = okMax and ToNumber(maxRaw) or nil
	if cur ~= nil and max ~= nil and max > 0 then
		local ratio = cur / max
		if ratio < 0 then
			ratio = 0
		end
		if ratio > 1 then
			ratio = 1
		end
		return ratio, cur, max
	end

	local okInfo, infoA, infoB = pcall(function()
		return X2Unit:UnitHealthInfo(token)
	end)
	if not okInfo then
		return nil
	end

	local infoCur = ToNumber(infoA)
	local infoMax = ToNumber(infoB)
	if infoCur ~= nil and infoMax ~= nil and infoMax > 0 then
		local ratio = infoCur / infoMax
		if ratio < 0 then
			ratio = 0
		end
		if ratio > 1 then
			ratio = 1
		end
		return ratio, infoCur, infoMax
	end

	if type(infoA) == "table" then
		local tableCur = ToNumber(infoA.current)
			or ToNumber(infoA.cur)
			or ToNumber(infoA.hp)
			or ToNumber(infoA.curHp)
			or ToNumber(infoA.cur_hp)
		local tableMax = ToNumber(infoA.max)
			or ToNumber(infoA.maxHp)
			or ToNumber(infoA.max_hp)
		if tableCur ~= nil and tableMax ~= nil and tableMax > 0 then
			local ratio = tableCur / tableMax
			if ratio < 0 then
				ratio = 0
			end
			if ratio > 1 then
				ratio = 1
			end
			return ratio, tableCur, tableMax
		end
	end

	return nil
end

local function TryReadUnitDistance(unitToken)
	if unitToken == nil then
		return nil
	end

	local ok, distanceValue = pcall(function()
		return X2Unit:UnitDistance(tostring(unitToken))
	end)
	if not ok then
		return nil
	end

	if type(distanceValue) == "number" then
		return distanceValue
	end

	if type(distanceValue) == "table" then
		local d = ToNumber(distanceValue.distance)
		if d ~= nil then
			return d
		end
	end

	return nil
end

local CLICK_METHODS = {
	"EnablePick",
	"SetEnablePick",
	"SetPickable",
	"EnableMouse",
	"SetMouseEnabled",
	"EnableInput",
	"SetInputEnabled",
	"EnableHitTest",
	"SetHitTestEnabled",
}

local clickThroughSupportState = "unknown"

local function TryCallBoolMethod(target, methodName, value)
	if target == nil then
		return false
	end

	local fn = target[methodName]
	if type(fn) ~= "function" then
		return false
	end

	local ok = pcall(function()
		fn(target, value)
	end)
	if ok then
		return true
	end

	ok = pcall(function()
		fn(target, value and 1 or 0)
	end)
	if ok then
		return true
	end

	return false
end

local function SetWidgetClickThrough(target, shouldClickThrough)
	local wantsPickEnabled = not shouldClickThrough
	for _, methodName in ipairs(CLICK_METHODS) do
		if TryCallBoolMethod(target, methodName, wantsPickEnabled) then
			if clickThroughSupportState ~= "supported" then
				clickThroughSupportState = "supported"
				Log("Click-through control supported via " .. tostring(methodName))
			end
			return true
		end
	end

	if clickThroughSupportState == "unknown" then
		clickThroughSupportState = "unsupported"
		Log("Click-through control unsupported on this client build")
	end

	return false
end

local function TrySetWidgetEnabled(target, shouldEnable)
	if target == nil then
		return false
	end
	local fn = target.Enable
	if type(fn) ~= "function" then
		return false
	end
	local ok = pcall(function()
		fn(target, shouldEnable)
	end)
	return ok
end

local function ForceDisablePick(target)
	if target == nil then
		return false
	end

	local fn = target.EnablePick
	if type(fn) == "function" then
		local ok = pcall(function()
			fn(target, false)
		end)
		if ok then
			return true
		end
	end

	SetWidgetClickThrough(target, true)
	return false
end

local function TryRaiseWidget(target)
	if target == nil then
		return false
	end
	local fn = target.Raise
	if type(fn) ~= "function" then
		return false
	end
	return pcall(function()
		fn(target)
	end)
end

local function ApplySlotClickMode(slot, shouldClickThrough)
	if slot == nil then
		return
	end

	-- Keep text overlays from ever consuming clicks.
	if slot.nameLabel ~= nil then
		TrySetWidgetEnabled(slot.nameLabel, false)
		ForceDisablePick(slot.nameLabel)
	end
	if slot.distanceLabel ~= nil then
		TrySetWidgetEnabled(slot.distanceLabel, false)
		ForceDisablePick(slot.distanceLabel)
	end

	-- Always pass-through for overlay-only interaction model.
	TrySetWidgetEnabled(slot, false)
	ForceDisablePick(slot)
end

local function EnsureSlotClickThrough(slot)
	if slot == nil or slot.clickThroughApplied then
		return
	end
	ApplySlotClickMode(slot, true)
	slot.clickThroughApplied = true
end

local function ApplyOverlayWindowPassThrough(windowTarget)
	-- Let clicks pass to the game's raid frame below this overlay.
	if windowTarget == nil then
		return
	end
	TrySetWidgetEnabled(windowTarget, false)
	ForceDisablePick(windowTarget)
end

local overlayPassThroughApplied = false
local function EnsureOverlayPassThrough()
	if overlayPassThroughApplied then
		return
	end
	ApplyOverlayWindowPassThrough(overlayRoot)
	overlayPassThroughApplied = true
end

local function EnforceOverlayZOrder()
	-- Keep visual layer above game raid UI even after other widgets are clicked.
	TryRaiseWidget(overlayRoot)
	TryRaiseWidget(raidFrameWindow)
end

local PARTY_SIZE = 5
local MAX_GROUPS = 10
local MAX_MEMBERS = PARTY_SIZE * MAX_GROUPS
local FRAME_COLUMNS = 5
local FRAME_GROUP_ROWS = math.ceil(MAX_GROUPS / FRAME_COLUMNS)

local SLOT_WIDTH = 68
local SLOT_HEIGHT = 32
local SLOT_GAP_X = 2
local SLOT_GAP_Y = 1
local GROUP_GAP_Y = 28
local MIN_SLOT_WIDTH = 54
local MIN_SLOT_HEIGHT = 22
local MIN_GROUP_GAP_Y = 10

local FRAME_PADDING_X = 8
local FRAME_PADDING_TOP = 46
local FRAME_PADDING_BOTTOM = 8
local FRAME_WIDTH = FRAME_PADDING_X * 2 + FRAME_COLUMNS * SLOT_WIDTH + (FRAME_COLUMNS - 1) * SLOT_GAP_X

local GROUP_BLOCK_HEIGHT = PARTY_SIZE * SLOT_HEIGHT + (PARTY_SIZE - 1) * SLOT_GAP_Y
local FRAME_HEIGHT = FRAME_PADDING_TOP
	+ FRAME_PADDING_BOTTOM
	+ FRAME_GROUP_ROWS * GROUP_BLOCK_HEIGHT
	+ (FRAME_GROUP_ROWS - 1) * GROUP_GAP_Y

local UPDATE_INTERVAL = 0.14
local TOKEN_REMAP_INTERVAL = 1.0
local FLASH_INTERVAL = 0.16
local DEBUG_GEOMETRY_PROBE = false

local HP_FLASH_START = 0.55
local HP_FLASH_STOP = 0.68
local HP_WARN = 0.82

local CLICK_THROUGH_DISTANCE = 34

local COLOR_HEALTHY = { 0.24, 0.55, 0.88, 0.78 }
local COLOR_WARN = { 0.86, 0.70, 0.22, 0.72 }
local COLOR_BLOCKED = { 0.22, 0.22, 0.22, 0.66 }
local COLOR_DEAD = { 0.35, 0.11, 0.11, 0.74 }
local ROLE_COLOR_MAP = {
	healer = {
		fill = { 0.95, 0.44, 0.74, 0.78 }, -- pink
		bg = { 0.38, 0.16, 0.31, 0.72 },
	},
	defense = {
		fill = { 0.32, 0.78, 0.36, 0.78 }, -- green
		bg = { 0.14, 0.30, 0.14, 0.72 },
	},
	melee = {
		fill = { 0.90, 0.29, 0.24, 0.78 }, -- red
		bg = { 0.33, 0.13, 0.11, 0.72 },
	},
	ranged = {
		fill = { 0.64, 0.38, 0.95, 0.78 }, -- purple
		bg = { 0.24, 0.13, 0.36, 0.72 },
	},
	mage = {
		fill = { 0.64, 0.38, 0.95, 0.78 }, -- purple
		bg = { 0.24, 0.13, 0.36, 0.72 },
	},
	support = {
		fill = { 0.68, 0.52, 0.90, 0.78 }, -- violet
		bg = { 0.24, 0.18, 0.33, 0.72 },
	},
	unknown = {
		fill = COLOR_HEALTHY,
		bg = { 0.10, 0.10, 0.12, 0.72 },
	},
}
local ROLE_NUMBER_KEY_MAP = {
	[0] = "unknown",
	[1] = "defense",
	[2] = "healer",
	[3] = "melee",
	[4] = "ranged",
}
local FLASH_COLORS = {
	{ 0.98, 0.18, 0.18, 0.82 },
	{ 0.95, 0.52, 0.12, 0.82 },
	{ 0.96, 0.20, 0.72, 0.82 },
}

local function ApplyColor(drawable, rgba)
	if drawable == nil or rgba == nil then
		return
	end
	drawable:SetColor(rgba[1], rgba[2], rgba[3], rgba[4])
end

local function ApplyCachedColor(owner, cacheKey, drawable, rgba)
	if owner == nil or drawable == nil or rgba == nil then
		return
	end
	if owner[cacheKey] == rgba then
		return
	end
	owner[cacheKey] = rgba
	ApplyColor(drawable, rgba)
end

local function SetCachedText(owner, cacheKey, label, value)
	if owner == nil or label == nil then
		return
	end
	local nextValue = value or ""
	if owner[cacheKey] == nextValue then
		return
	end
	owner[cacheKey] = nextValue
	label:SetText(nextValue)
end

local function SetCachedVisible(widget, visible)
	if widget == nil then
		return
	end
	local nextVisible = visible and true or false
	if widget.lastVisible == nextVisible then
		return
	end
	widget.lastVisible = nextVisible
	widget:Show(nextVisible)
end

local function SetCachedHpFillExtent(slot, fillWidth, fillHeight)
	if slot == nil or slot.hpFill == nil then
		return
	end
	if slot.lastHpFillWidth == fillWidth and slot.lastHpFillHeight == fillHeight then
		return
	end
	slot.lastHpFillWidth = fillWidth
	slot.lastHpFillHeight = fillHeight
	slot.hpFill:SetExtent(fillWidth, fillHeight)
end

local function BuildHealthColor(hpRatio, isFlashing, flashColor, roleFillColor)
	if hpRatio == nil then
		return COLOR_BLOCKED
	end
	if hpRatio <= 0 then
		return COLOR_DEAD
	end
	if isFlashing and flashColor ~= nil then
		return flashColor
	end
	if roleFillColor ~= nil then
		return roleFillColor
	end
	if hpRatio <= HP_WARN then
		return COLOR_WARN
	end
	return COLOR_HEALTHY
end

local function NormalizeRoleKey(value)
	if value == nil then
		return nil
	end

	if type(value) == "number" then
		return ROLE_NUMBER_KEY_MAP[value]
	end

	local lowered = string.lower(tostring(value))
	lowered = string.gsub(lowered, "^%s+", "")
	lowered = string.gsub(lowered, "%s+$", "")
	if lowered == "" then
		return nil
	end

	if string.find(lowered, "blue", 1, true) or string.find(lowered, "none", 1, true) then
		return "unknown"
	end

	local numericValue = tonumber(lowered)
	if numericValue ~= nil then
		return ROLE_NUMBER_KEY_MAP[numericValue]
	end

	if string.find(lowered, "heal", 1, true) or string.find(lowered, "love", 1, true) then
		return "healer"
	end
	if string.find(lowered, "tank", 1, true)
		or string.find(lowered, "def", 1, true)
		or string.find(lowered, "guard", 1, true) then
		return "defense"
	end
	if string.find(lowered, "arch", 1, true)
		or string.find(lowered, "range", 1, true)
		or string.find(lowered, "wild", 1, true)
		or string.find(lowered, "gun", 1, true)
		or string.find(lowered, "bow", 1, true)
		or string.find(lowered, "mage", 1, true)
		or string.find(lowered, "magic", 1, true)
		or string.find(lowered, "sorc", 1, true)
		or string.find(lowered, "maled", 1, true) then
		return "ranged"
	end
	if string.find(lowered, "melee", 1, true)
		or string.find(lowered, "fight", 1, true)
		or string.find(lowered, "swift", 1, true)
		or string.find(lowered, "assassin", 1, true)
		or string.find(lowered, "dps", 1, true) then
		return "melee"
	end
	if string.find(lowered, "support", 1, true)
		or string.find(lowered, "song", 1, true)
		or string.find(lowered, "romance", 1, true)
		or string.find(lowered, "buff", 1, true) then
		return "support"
	end

	return nil
end

local function NormalizeFirstRoleKey(...)
	for index = 1, select("#", ...) do
		local normalized = NormalizeRoleKey(select(index, ...))
		if normalized ~= nil then
			return normalized
		end
	end
	return nil
end

local function ResolveRolePalette(roleKey)
	if roleKey ~= nil then
		local palette = ROLE_COLOR_MAP[roleKey]
		if palette ~= nil then
			return palette
		end
	end
	return ROLE_COLOR_MAP.unknown
end

local ROLE_METHOD_CANDIDATES_RAID = {
	"GetTeamMemberRole",
	"GetMemberRole",
	"GetRaidMemberRole",
	"GetRole",
	"GetRoleByIndex",
}
local ROLE_METHOD_CANDIDATES_CO_RAID = {
	"GetCoRaidMemberRole",
	"GetJointMemberRole",
	"GetJointTeamMemberRole",
	"GetRaidMemberRole",
	"GetTeamMemberRole",
	"GetMemberRole",
	"GetRole",
	"GetRoleByIndex",
}
local DIRECT_TEAM_INFO_PAIRS_RAID = {
	{ count = "GetTeamMemberCount", info = "GetTeamMemberInfo" },
	{ count = "GetMemberCount", info = "GetMemberInfo" },
	{ count = "GetRaidMemberCount", info = "GetRaidMemberInfo" },
}
local DIRECT_TEAM_INFO_PAIRS_CO_RAID = {
	{ count = "GetCoRaidMemberCount", info = "GetCoRaidMemberInfo" },
	{ count = "GetJointMemberCount", info = "GetJointMemberInfo" },
	{ count = "GetJointTeamMemberCount", info = "GetJointTeamMemberInfo" },
}
local SUBGROUP_TEAM_INFO_PAIRS = {
	{ count = "GetTeamMemberCountByIndex", info = "GetTeamMemberInfoByIndex" },
	{ count = "GetRaidMemberCountByIndex", info = "GetRaidMemberInfoByIndex" },
	{ count = "GetCoRaidMemberCountByIndex", info = "GetCoRaidMemberInfoByIndex" },
	{ count = "GetJointMemberCountByIndex", info = "GetJointMemberInfoByIndex" },
	{ count = "GetJointTeamMemberCountByIndex", info = "GetJointTeamMemberInfoByIndex" },
	{ count = "GetMemberCountByTeam", info = "GetMemberInfoByTeam" },
}

local function HasX2TeamMethod(methodName)
	return X2Team[methodName] ~= nil and type(X2Team[methodName]) == "function"
end

local function AreaToTeamIndex(area)
	if area == "co_raid" then
		return 2
	end
	return 1
end

local function TryNormalizeRoleCall(methodName, arg1, arg2)
	local fn = X2Team[methodName]
	if type(fn) ~= "function" then
		return nil
	end

	local ok = false
	local roleValue1, roleValue2, roleValue3, roleValue4 = nil, nil, nil, nil
	if arg2 ~= nil then
		ok, roleValue1, roleValue2, roleValue3, roleValue4 = pcall(function()
			return fn(X2Team, arg1, arg2)
		end)
	elseif arg1 ~= nil then
		ok, roleValue1, roleValue2, roleValue3, roleValue4 = pcall(function()
			return fn(X2Team, arg1)
		end)
	else
		ok, roleValue1, roleValue2, roleValue3, roleValue4 = pcall(function()
			return fn(X2Team)
		end)
	end

	if not ok then
		return nil
	end
	return NormalizeFirstRoleKey(roleValue1, roleValue2, roleValue3, roleValue4)
end

local function TryReadRoleByMemberIndex(area, memberIndex)
	memberIndex = ToNumber(memberIndex)
	if memberIndex == nil or memberIndex <= 0 then
		return nil
	end

	local roleMethodCandidates = ROLE_METHOD_CANDIDATES_RAID
	if area == "co_raid" then
		roleMethodCandidates = ROLE_METHOD_CANDIDATES_CO_RAID
	end

	local teamIndex = AreaToTeamIndex(area)
	for _, methodName in ipairs(roleMethodCandidates) do
		if methodName == "GetRole" and teamIndex ~= nil then
			local normalized = TryNormalizeRoleCall(methodName, teamIndex, memberIndex)
			if normalized ~= nil then
				return normalized
			end
		end

		local normalized = TryNormalizeRoleCall(methodName, memberIndex)
		if normalized ~= nil then
			return normalized
		end
	end

	return nil
end

local function TryReadRoleByMemberName(area, name)
	if name == nil or type(name) ~= "string" or name == "" then
		return nil
	end
	if not HasX2TeamMethod("GetMemberIndexByName") or not HasX2TeamMethod("GetRole") then
		return nil
	end

	local okIndex, memberIndex = pcall(function()
		return X2Team:GetMemberIndexByName(name)
	end)
	memberIndex = okIndex and ToNumber(memberIndex) or nil
	if memberIndex == nil or memberIndex <= 0 then
		return nil
	end

	return TryReadRoleByMemberIndex(area, memberIndex)
end

local function DistanceText(distance)
	if distance == nil then
		return ""
	end
	if distance < 0 then
		distance = 0
	end
	return string.format("%.1fm", math.floor(distance * 10 + 0.5) / 10)
end

local activeMemberArea = "raid"
local coRaidFallbackLogState = {
	mode = nil,
	count = 0,
}
local coRaidFallbackCandidateTokensByFlatIndex = nil

local function GetMemberTokenForArea(area, flatIndex)
	if flatIndex == nil then
		return nil, nil
	end

	if area == "co_raid" then
		local indexedToken = "team_2_" .. tostring(flatIndex)
		local indexedName = GetUnitNameByToken(indexedToken)
		if indexedName ~= nil then
			return indexedToken, indexedName
		end
		return nil, nil
	end

	local indexedToken = "team_1_" .. tostring(flatIndex)
	local indexedName = GetUnitNameByToken(indexedToken)
	if indexedName ~= nil then
		return indexedToken, indexedName
	end

	local legacyToken = "team" .. tostring(flatIndex)
	local legacyName = GetUnitNameByToken(legacyToken)
	if legacyName ~= nil then
		return legacyToken, legacyName
	end

	return nil, nil
end

local function GetCoRaidFallbackCandidateTokensByFlatIndex()
	if coRaidFallbackCandidateTokensByFlatIndex ~= nil then
		return coRaidFallbackCandidateTokensByFlatIndex
	end

	coRaidFallbackCandidateTokensByFlatIndex = {}
	for flatIndex = 1, MAX_MEMBERS do
		local groupIndex = math.floor((flatIndex - 1) / PARTY_SIZE) + 1
		local memberIndex = ((flatIndex - 1) % PARTY_SIZE) + 1

		coRaidFallbackCandidateTokensByFlatIndex[flatIndex] = {
			"team_2_" .. tostring(flatIndex),
			"team_2_" .. string.format("%02d", flatIndex),
			"team_2_" .. string.format("%03d", flatIndex),
			"team2_" .. tostring(flatIndex),
			"joint_" .. tostring(flatIndex),
			"team_2_" .. tostring(groupIndex) .. "_" .. tostring(memberIndex),
			"team_2_" .. string.format("%02d_%02d", groupIndex, memberIndex),
			"team_2_" .. tostring(groupIndex) .. "-" .. tostring(memberIndex),
			"joint_" .. tostring(groupIndex) .. "_" .. tostring(memberIndex),
		}
	end

	return coRaidFallbackCandidateTokensByFlatIndex
end

local function BuildCoRaidFallbackTokenList()
	local entries = {}
	local seenIdentities = {}
	local seenTokens = {}
	local candidateTokensByFlatIndex = GetCoRaidFallbackCandidateTokensByFlatIndex()

	for flatIndex = 1, MAX_MEMBERS do
		local candidateTokens = candidateTokensByFlatIndex[flatIndex]
		for _, token in ipairs(candidateTokens) do
			if not seenTokens[token] then
				seenTokens[token] = true
				local name = GetUnitNameByToken(token)
				local identity = NormalizeIdentity(name)
				if identity ~= nil and not seenIdentities[identity] then
					seenIdentities[identity] = true
					entries[#entries + 1] = {
						token = token,
						name = name,
						identity = identity,
					}
				end
			end
		end
	end

	return entries
end

local function ExtractRoleFromTeamMemberInfo(info)
	if type(info) ~= "table" then
		return nil
	end

	local candidateFieldNames = {
		"role",
		"teamRole",
		"team_role",
		"teamRoleId",
		"team_role_id",
		"raidRole",
		"raid_role",
		"memberRole",
		"member_role",
		"selectedRole",
		"selected_role",
		"duty",
		"combatRole",
		"combat_role",
		"combatRoleId",
		"combat_role_id",
		"classRole",
		"class_role",
		"archetype",
		"roleType",
		"role_type",
		"roleId",
		"role_id",
		"roleIndex",
		"role_index",
	}

	for _, fieldName in ipairs(candidateFieldNames) do
		local normalized = NormalizeRoleKey(info[fieldName])
		if normalized ~= nil then
			return normalized
		end
	end

	return nil
end

local function ExtractRoleFromTeamMemberInfoValues(...)
	for index = 1, select("#", ...) do
		local value = select(index, ...)
		local roleKey = nil
		if type(value) == "table" then
			roleKey = ExtractRoleFromTeamMemberInfo(value)
		else
			roleKey = NormalizeRoleKey(value)
		end
		if roleKey ~= nil then
			return roleKey
		end
	end
	return nil
end

local function ExtractDisplayFromTeamMemberInfo(info, index)
	if info == nil then
		return nil
	end

	if type(info) == "string" then
		return tostring(info)
	end
	if type(info) ~= "table" then
		return tostring(info)
	end

	local display = info.name or info.charName or info.memberName or info.nickname or info.nickName
	if display == nil then
		display = info.unitName or info.characterName
	end
	if display == nil and index ~= nil then
		display = "team" .. tostring(index)
	end
	return display
end

local function BuildTeamApiSnapshot(area)
	local ordered = {}
	local seen = {}
	local roleMap = {}

	local function AddFromInfo(info, index, ...)
		local display = ExtractDisplayFromTeamMemberInfo(info, index)
		local identity = NormalizeIdentity(display)
		local roleKey = ExtractRoleFromTeamMemberInfo(info)
		if roleKey == nil then
			roleKey = ExtractRoleFromTeamMemberInfoValues(...)
		end
		if identity ~= nil and roleKey ~= nil then
			roleMap[identity] = roleKey
		end
		if identity == nil or seen[identity] then
			return
		end
		seen[identity] = true
		ordered[#ordered + 1] = {
			identity = identity,
			name = tostring(display),
			role = roleKey,
		}
	end

	local function TryPair(countMethod, infoMethod, groupArg)
		if not HasX2TeamMethod(countMethod) or not HasX2TeamMethod(infoMethod) then
			return
		end

		local okCount, count = pcall(function()
			if groupArg ~= nil then
				return X2Team[countMethod](X2Team, groupArg)
			end
			return X2Team[countMethod](X2Team)
		end)
		if not okCount or type(count) ~= "number" or count <= 0 then
			return
		end

		for i = 1, count do
			local okInfo, info1, info2, info3, info4, info5 = pcall(function()
				if groupArg ~= nil then
					return X2Team[infoMethod](X2Team, groupArg, i)
				end
				return X2Team[infoMethod](X2Team, i)
			end)
			if okInfo then
				AddFromInfo(info1, i, info2, info3, info4, info5)
			end
		end
	end

	local directPairs = DIRECT_TEAM_INFO_PAIRS_RAID
	if area == "co_raid" then
		directPairs = DIRECT_TEAM_INFO_PAIRS_CO_RAID
	end

	for _, pair in ipairs(directPairs) do
		TryPair(pair.count, pair.info, nil)
	end

	for _, pair in ipairs(SUBGROUP_TEAM_INFO_PAIRS) do
		for groupIndex = 1, 10 do
			TryPair(pair.count, pair.info, groupIndex)
		end
	end

	return {
		ordered = ordered,
		roleMap = roleMap,
	}
end

local function BuildAreaTokenList(area)
	local tokenList = {}
	local teamSnapshot = BuildTeamApiSnapshot(area)
	local roleMap = teamSnapshot.roleMap
	local ordered = teamSnapshot.ordered
	local orderedRoleMap = {}
	for i = 1, #ordered do
		local member = ordered[i]
		if member ~= nil and member.identity ~= nil and member.role ~= nil and orderedRoleMap[member.identity] == nil then
			orderedRoleMap[member.identity] = member.role
		end
	end

	local foundCount = 0

	for flatIndex = 1, MAX_MEMBERS do
		local token, name = GetMemberTokenForArea(area, flatIndex)
		if token ~= nil then
			local identity = NormalizeIdentity(name)
			if name ~= nil then
				local roleKey = TryReadRoleByMemberIndex(area, flatIndex)
				if identity ~= nil then
					roleKey = roleKey or roleMap[identity]
				end
				if roleKey == nil and identity ~= nil then
					roleKey = orderedRoleMap[identity]
				end
				if roleKey == nil then
					roleKey = TryReadRoleByMemberName(area, name)
				end

				tokenList[flatIndex] = {
					token = token,
					name = name,
					identity = identity,
					role = roleKey,
				}
				foundCount = foundCount + 1
			end
		end
	end

	if area == "co_raid" and foundCount == 0 then
		local fallbackEntries = BuildCoRaidFallbackTokenList()
		if #fallbackEntries > 0 then
			if coRaidFallbackLogState.mode ~= "used" or coRaidFallbackLogState.count ~= #fallbackEntries then
				Log("co-raid fallback token resolver used: " .. tostring(#fallbackEntries) .. " members")
			end
			coRaidFallbackLogState.mode = "used"
			coRaidFallbackLogState.count = #fallbackEntries
			for i = 1, #fallbackEntries do
				local identity = fallbackEntries[i].identity
				tokenList[i] = fallbackEntries[i]
				tokenList[i].role = TryReadRoleByMemberIndex(area, i)
					or roleMap[identity]
					or orderedRoleMap[identity]
					or TryReadRoleByMemberName(area, fallbackEntries[i].name)
			end
		else
			if coRaidFallbackLogState.mode ~= "empty" then
				Log("co-raid fallback found no member tokens")
			end
			coRaidFallbackLogState.mode = "empty"
			coRaidFallbackLogState.count = 0
		end
	elseif area == "co_raid" then
		coRaidFallbackLogState.mode = nil
		coRaidFallbackLogState.count = 0
	end

	return tokenList
end

local raidOrgButton = CreateSimpleButton("Raid Org", 620, -115)
runtime.raidOrgButton = raidOrgButton

raidFrameWindow = CreateEmptyWindow("raidOrgOverlayWindow", "UIParent")
runtime.raidFrameWindow = raidFrameWindow
raidFrameWindow:SetExtent(CONTROL_WIDTH, CONTROL_HEIGHT_COMPACT)
raidFrameWindow:AddAnchor("TOPLEFT", "UIParent", 50, 150)
raidFrameWindow:SetCloseOnEscape(false)
raidFrameWindow:EnableDrag(true)
raidFrameWindow:Show(false)

overlayRoot = CreateEmptyWindow("raidOrgVisualRoot", "UIParent")
runtime.overlayRoot = overlayRoot
overlayRoot:SetExtent(1, 1)
overlayRoot:AddAnchor("TOPLEFT", "UIParent", 0, 0)
overlayRoot:Show(false)

local MIN_FRAME_WIDTH = FRAME_WIDTH
local MIN_FRAME_HEIGHT = FRAME_HEIGHT
local RESIZE_BORDER = 10
local isResizingWindow = false
local resizeSupportState = "unknown"
local OVERLAY_BASE_X = 50
local OVERLAY_BASE_Y = 220
local OVERLAY_CONTROL_OFFSET_X = 0
local OVERLAY_CONTROL_OFFSET_Y = 0
local overlayLayoutWidth = FRAME_WIDTH
local overlayLayoutHeight = FRAME_HEIGHT
local currentSlotWidth = SLOT_WIDTH
local currentSlotHeight = SLOT_HEIGHT
local currentGroupGapY = GROUP_GAP_Y
local lastLayoutWidth = nil
local lastLayoutHeight = nil
local ReflowRaidLayout
local isWindowLocked = false
local areControlsVisible = true
local calibrationModeEnabled = false
local calibrationStep = 2
local CALIBRATION_DATA_KEY = "raid_org_calibration_v1"
local CALIBRATION_LAYOUT_VERSION = 2
local CONTROL_WIDTH = 372
local CONTROL_HEIGHT_COMPACT = 28
local CONTROL_HEIGHT_CALIB = 100
local CONTROL_HEIGHT_MINIMAL = 28
local CONTROL_TO_BOX_GAP = 0
local boxWidthAdjust = 0
local boxHeightAdjust = 0

local SaveCalibrationSettings
local ApplyCalibrationDelta
local SetCalibrationModeEnabled
local ApplyControlStripVisibility

local function GetVisibleControlStripHeight()
	if areControlsVisible and calibrationModeEnabled then
		return CONTROL_HEIGHT_CALIB
	end
	if areControlsVisible then
		return CONTROL_HEIGHT_COMPACT
	end
	return CONTROL_HEIGHT_MINIMAL
end

local function SyncOverlayBaseToControlWindow()
	local okOffset, offsetX, offsetY = pcall(function()
		return raidFrameWindow:GetOffset()
	end)
	if not okOffset or type(offsetX) ~= "number" or type(offsetY) ~= "number" then
		return
	end

	local uiScale = UIParent:GetUIScale() or 1.0
	local normalizedX = offsetX * uiScale
	local normalizedY = offsetY * uiScale

	local controlHeight = GetVisibleControlStripHeight()

	local newBaseX = math.floor(normalizedX + OVERLAY_CONTROL_OFFSET_X + 0.5)
	local newBaseY =
		math.floor(normalizedY + controlHeight - FRAME_PADDING_TOP + CONTROL_TO_BOX_GAP + OVERLAY_CONTROL_OFFSET_Y + 0.5)
	if newBaseX ~= OVERLAY_BASE_X or newBaseY ~= OVERLAY_BASE_Y then
		OVERLAY_BASE_X = newBaseX
		OVERLAY_BASE_Y = newBaseY
		lastLayoutWidth = nil
		lastLayoutHeight = nil
	end
end

local function ComputeMinFrameWidth()
	return FRAME_PADDING_X * 2 + FRAME_COLUMNS * MIN_SLOT_WIDTH + (FRAME_COLUMNS - 1) * SLOT_GAP_X
end

local function ComputeMinFrameHeight()
	local minGroupBlockHeight = PARTY_SIZE * MIN_SLOT_HEIGHT + (PARTY_SIZE - 1) * SLOT_GAP_Y
	return FRAME_PADDING_TOP
		+ FRAME_PADDING_BOTTOM
		+ FRAME_GROUP_ROWS * minGroupBlockHeight
		+ (FRAME_GROUP_ROWS - 1) * MIN_GROUP_GAP_Y
end

MIN_FRAME_WIDTH = ComputeMinFrameWidth()
MIN_FRAME_HEIGHT = ComputeMinFrameHeight()

local function ClampCalibrationDimensions()
	if overlayLayoutWidth < MIN_FRAME_WIDTH then
		overlayLayoutWidth = MIN_FRAME_WIDTH
	end
	if overlayLayoutHeight < MIN_FRAME_HEIGHT then
		overlayLayoutHeight = MIN_FRAME_HEIGHT
	end
end

local function LoadCalibrationSettings()
	local saved = ADDON:LoadData(CALIBRATION_DATA_KEY)
	if type(saved) ~= "table" then
		return
	end

	local savedVersion = tonumber(saved.layoutVersion)
	local offsetX = tonumber(saved.offsetX)
	local offsetY = tonumber(saved.offsetY)
	local width = tonumber(saved.width)
	local height = tonumber(saved.height)
	local step = tonumber(saved.step)
	local boxWidth = tonumber(saved.boxWidthAdjust)
	local boxHeight = tonumber(saved.boxHeightAdjust)

	if offsetX ~= nil then
		OVERLAY_CONTROL_OFFSET_X = math.floor(offsetX + 0.5)
	end
	if offsetY ~= nil and savedVersion == CALIBRATION_LAYOUT_VERSION then
		OVERLAY_CONTROL_OFFSET_Y = math.floor(offsetY + 0.5)
	end
	if width ~= nil then
		overlayLayoutWidth = math.floor(width + 0.5)
	end
	if height ~= nil then
		overlayLayoutHeight = math.floor(height + 0.5)
	end
	if step ~= nil and step >= 1 then
		calibrationStep = math.floor(step + 0.5)
	end
	if boxWidth ~= nil then
		boxWidthAdjust = math.floor(boxWidth + 0.5)
	end
	if boxHeight ~= nil then
		boxHeightAdjust = math.floor(boxHeight + 0.5)
	end

	ClampCalibrationDimensions()
	lastLayoutWidth = nil
	lastLayoutHeight = nil
end

SaveCalibrationSettings = function()
	local payload = {
		layoutVersion = CALIBRATION_LAYOUT_VERSION,
		offsetX = OVERLAY_CONTROL_OFFSET_X,
		offsetY = OVERLAY_CONTROL_OFFSET_Y,
		width = overlayLayoutWidth,
		height = overlayLayoutHeight,
		step = calibrationStep,
		boxWidthAdjust = boxWidthAdjust,
		boxHeightAdjust = boxHeightAdjust,
	}
	ADDON:ClearData(CALIBRATION_DATA_KEY)
	ADDON:SaveData(CALIBRATION_DATA_KEY, payload)
end

LoadCalibrationSettings()

local function ReadWindowExtent(window)
	if window == nil then
		return nil, nil
	end

	local okExtent, width, height = pcall(function()
		return window:GetExtent()
	end)
	if okExtent and type(width) == "number" and type(height) == "number" then
		return width, height
	end

	local okWidth, widthValue = pcall(function()
		return window:GetWidth()
	end)
	local okHeight, heightValue = pcall(function()
		return window:GetHeight()
	end)
	if okWidth and okHeight and type(widthValue) == "number" and type(heightValue) == "number" then
		return widthValue, heightValue
	end

	return nil, nil
end

local function TryStartWindowSizing(window, edgeToken)
	if window == nil then
		return false
	end

	local methods = {
		{ "StartSizing", edgeToken },
		{ "StartSizing" },
		{ "StartResize", edgeToken },
		{ "StartResize" },
	}

	for _, attempt in ipairs(methods) do
		local methodName = attempt[1]
		local arg = attempt[2]
		local fn = window[methodName]
		if type(fn) == "function" then
			local ok = false
			if arg ~= nil then
				ok = pcall(function()
					fn(window, arg)
				end)
			else
				ok = pcall(function()
					fn(window)
				end)
			end
			if ok then
				if resizeSupportState ~= "supported" then
					resizeSupportState = "supported"
					Log("edge-resize supported via " .. tostring(methodName))
				end
				return true
			end
		end
	end

	if resizeSupportState == "unknown" then
		resizeSupportState = "unsupported"
		Log("edge-resize is unsupported on this client build")
	end

	return false
end

local function ClampWindowToMinimum(window)
	if window == nil then
		return
	end

	local width = nil
	local height = nil
	local okExtent, w, h = pcall(function()
		return window:GetExtent()
	end)
	if okExtent and type(w) == "number" and type(h) == "number" then
		width = w
		height = h
	end

	if width == nil or height == nil then
		local okWidth, widthValue = pcall(function()
			return window:GetWidth()
		end)
		local okHeight, heightValue = pcall(function()
			return window:GetHeight()
		end)
		if okWidth and type(widthValue) == "number" then
			width = widthValue
		end
		if okHeight and type(heightValue) == "number" then
			height = heightValue
		end
	end

	if width == nil or height == nil then
		return
	end

	local clampedWidth = width
	local clampedHeight = height
	if clampedWidth < MIN_FRAME_WIDTH then
		clampedWidth = MIN_FRAME_WIDTH
	end
	if clampedHeight < MIN_FRAME_HEIGHT then
		clampedHeight = MIN_FRAME_HEIGHT
	end

	if clampedWidth ~= width or clampedHeight ~= height then
		window:SetExtent(clampedWidth, clampedHeight)
	end
end

function raidFrameWindow:OnDragStart()
	if isWindowLocked then
		return
	end
	self:StartMoving()
end
raidFrameWindow:SetHandler("OnDragStart", raidFrameWindow.OnDragStart)

function raidFrameWindow:OnDragStop()
	self:StopMovingOrSizing()
	if isResizingWindow then
		ClampWindowToMinimum(self)
		lastLayoutWidth = nil
		lastLayoutHeight = nil
		isResizingWindow = false
	end
	SyncOverlayBaseToControlWindow()
	if overlayRoot:IsVisible() then
		ReflowRaidLayout(true)
		UpdateAllSlots()
	end
end
raidFrameWindow:SetHandler("OnDragStop", raidFrameWindow.OnDragStop)

function raidFrameWindow:OnHide()
	overlayRoot:Show(false)
end
raidFrameWindow:SetHandler("OnHide", raidFrameWindow.OnHide)

local function CreateResizeGrip(name, anchorPoint, x, y, width, height, edgeToken)
	local grip = raidFrameWindow:CreateChildWidget("button", name, 0, true)
	grip:SetStyle("text_default")
	grip:SetText("")
	grip:SetExtent(width, height)
	grip:AddAnchor(anchorPoint, raidFrameWindow, x, y)
	grip:EnableDrag(true)

	local shade = grip:CreateColorDrawable(1, 1, 1, 0.02, "overlay")
	shade:AddAnchor("TOPLEFT", grip, 0, 0)
	shade:SetExtent(width, height)
	grip.shade = shade

	function grip:OnDragStart()
		if TryStartWindowSizing(raidFrameWindow, edgeToken) then
			isResizingWindow = true
		end
	end
	grip:SetHandler("OnDragStart", grip.OnDragStart)

	function grip:OnDragStop()
		raidFrameWindow:StopMovingOrSizing()
		if isResizingWindow then
			ClampWindowToMinimum(raidFrameWindow)
			lastLayoutWidth = nil
			lastLayoutHeight = nil
			isResizingWindow = false
		end
	end
	grip:SetHandler("OnDragStop", grip.OnDragStop)

	function grip:OnEnter()
		if self.shade ~= nil then
			self.shade:SetColor(1, 1, 1, 0.10)
		end
	end
	grip:SetHandler("OnEnter", grip.OnEnter)

	function grip:OnLeave()
		if self.shade ~= nil then
			self.shade:SetColor(1, 1, 1, 0.02)
		end
	end
	grip:SetHandler("OnLeave", grip.OnLeave)

	return grip
end

local resizeRightGrip = CreateResizeGrip("raidOrgResizeRightGrip", "TOPRIGHT", 0, 0, RESIZE_BORDER, FRAME_HEIGHT, "RIGHT")
local resizeBottomGrip = CreateResizeGrip("raidOrgResizeBottomGrip", "BOTTOMLEFT", 0, 0, FRAME_WIDTH, RESIZE_BORDER, "BOTTOM")
local resizeCornerGrip = CreateResizeGrip(
	"raidOrgResizeCornerGrip",
	"BOTTOMRIGHT",
	0,
	0,
	RESIZE_BORDER + 4,
	RESIZE_BORDER + 4,
	"BOTTOMRIGHT"
)
resizeRightGrip:Show(false)
resizeBottomGrip:Show(false)
resizeCornerGrip:Show(false)
TrySetWidgetEnabled(resizeRightGrip, false)
TrySetWidgetEnabled(resizeBottomGrip, false)
TrySetWidgetEnabled(resizeCornerGrip, false)
ForceDisablePick(resizeRightGrip)
ForceDisablePick(resizeBottomGrip)
ForceDisablePick(resizeCornerGrip)

local titleLabel = raidFrameWindow:CreateChildWidget("label", "raidOrgTitleLabel", 0, true)
titleLabel:SetText("Raid Org")
titleLabel.style:SetAlign(ALIGN_LEFT)
titleLabel.style:SetFontSize(11)
titleLabel:AddAnchor("TOPLEFT", raidFrameWindow, 6, 5)

local statusLabel = raidFrameWindow:CreateChildWidget("label", "raidOrgStatusLabel", 0, true)
statusLabel:SetText(
	"Raid | HP flash <=55%, stop >=68%, click-through <="
		.. tostring(CLICK_THROUGH_DISTANCE)
		.. "m, blank >"
		.. tostring(CLICK_THROUGH_DISTANCE)
		.. "m"
)
statusLabel.style:SetAlign(ALIGN_CENTER)
statusLabel.style:SetFontSize(9)
statusLabel:AddAnchor("TOP", raidFrameWindow, 0, 50)

local raidTabButton = raidFrameWindow:CreateChildWidget("button", "raidOrgRaidTabButton", 0, true)
raidTabButton:SetStyle("text_default")
raidTabButton:SetText("Raid")
raidTabButton:SetExtent(46, 20)
raidTabButton:AddAnchor("TOPLEFT", raidFrameWindow, 70, 4)

local coRaidTabButton = raidFrameWindow:CreateChildWidget("button", "raidOrgCoRaidTabButton", 0, true)
coRaidTabButton:SetStyle("text_default")
coRaidTabButton:SetText("Co-Raid")
coRaidTabButton:SetExtent(58, 20)
coRaidTabButton:AddAnchor("TOPLEFT", raidFrameWindow, 120, 4)

local refreshButton = raidFrameWindow:CreateChildWidget("button", "raidOrgRefreshButton", 0, true)
refreshButton:SetStyle("text_default")
refreshButton:SetText("Refresh")
refreshButton:SetExtent(60, 20)
refreshButton:AddAnchor("TOPLEFT", raidFrameWindow, 6, 4)

local lockButton = raidFrameWindow:CreateChildWidget("button", "raidOrgLockButton", 0, true)
lockButton:SetStyle("text_default")
lockButton:SetText("Lock")
lockButton:SetExtent(60, 20)
lockButton:AddAnchor("TOPLEFT", raidFrameWindow, 182, 4)

local closeButton = raidFrameWindow:CreateChildWidget("button", "raidOrgCloseButton", 0, true)
closeButton:SetStyle("text_default")
closeButton:SetText("X")
closeButton:SetExtent(22, 20)
closeButton:AddAnchor("TOPRIGHT", raidFrameWindow, -6, 4)

local calibrationToggleButton = raidFrameWindow:CreateChildWidget("button", "raidOrgCalibrationToggleButton", 0, true)
calibrationToggleButton:SetStyle("text_default")
calibrationToggleButton:SetText("Cal")
calibrationToggleButton:SetExtent(44, 20)
calibrationToggleButton:AddAnchor("TOPLEFT", raidFrameWindow, 246, 4)

local controlsToggleButton = raidFrameWindow:CreateChildWidget("button", "raidOrgControlsToggleButton", 0, true)
controlsToggleButton:SetStyle("text_default")
controlsToggleButton:SetText("Hide UI")
controlsToggleButton:SetExtent(64, 20)
controlsToggleButton:AddAnchor("TOPRIGHT", raidFrameWindow, -32, 4)

local calibrationButtons = {}
local function CreateCalibrationButton(id, text, xOffset, yOffset)
	local button = raidFrameWindow:CreateChildWidget("button", id, 0, true)
	button:SetStyle("text_default")
	button:SetText(text)
	button:SetExtent(30, 18)
	button:AddAnchor("TOPLEFT", raidFrameWindow, xOffset, yOffset or 72)
	button:Show(false)
	calibrationButtons[#calibrationButtons + 1] = button
	return button
end

local calXMinusButton = CreateCalibrationButton("raidOrgCalXMinusButton", "X-", 6, 30)
local calXPlusButton = CreateCalibrationButton("raidOrgCalXPlusButton", "X+", 38, 30)
local calYMinusButton = CreateCalibrationButton("raidOrgCalYMinusButton", "Y-", 70, 30)
local calYPlusButton = CreateCalibrationButton("raidOrgCalYPlusButton", "Y+", 102, 30)
local calWMinusButton = CreateCalibrationButton("raidOrgCalWMinusButton", "W-", 134, 30)
local calWPlusButton = CreateCalibrationButton("raidOrgCalWPlusButton", "W+", 166, 30)
local calHMinusButton = CreateCalibrationButton("raidOrgCalHMinusButton", "H-", 198, 30)
local calHPlusButton = CreateCalibrationButton("raidOrgCalHPlusButton", "H+", 230, 30)
local calStepButton = CreateCalibrationButton("raidOrgCalStepButton", "S2", 262, 30)
local calBXMinusButton = CreateCalibrationButton("raidOrgCalBXMinusButton", "BX-", 70, 52)
local calBXPlusButton = CreateCalibrationButton("raidOrgCalBXPlusButton", "BX+", 102, 52)
local calBYMinusButton = CreateCalibrationButton("raidOrgCalBYMinusButton", "BY-", 134, 52)
local calBYPlusButton = CreateCalibrationButton("raidOrgCalBYPlusButton", "BY+", 166, 52)

local function ApplyWindowLockState()
	raidFrameWindow:EnableDrag(not isWindowLocked)
	TrySetWidgetEnabled(closeButton, not isWindowLocked)
	if isWindowLocked then
		lockButton:SetText("Unlock")
	else
		lockButton:SetText("Lock")
	end
end

ApplyControlStripVisibility = function()
	local showControls = areControlsVisible
	refreshButton:Show(showControls)
	raidTabButton:Show(showControls)
	coRaidTabButton:Show(showControls)
	lockButton:Show(showControls)
	calibrationToggleButton:Show(showControls)

	local showCalibrationButtons = showControls and calibrationModeEnabled
	for i = 1, #calibrationButtons do
		calibrationButtons[i]:Show(showCalibrationButtons)
	end

	if showControls then
		titleLabel:Show(false)
		if calibrationModeEnabled then
			raidFrameWindow:SetExtent(CONTROL_WIDTH, CONTROL_HEIGHT_CALIB)
			statusLabel:Show(false)
		else
			raidFrameWindow:SetExtent(CONTROL_WIDTH, CONTROL_HEIGHT_COMPACT)
			statusLabel:Show(false)
		end
		controlsToggleButton:SetText("Hide UI")
	else
		titleLabel:Show(true)
		raidFrameWindow:SetExtent(CONTROL_WIDTH, CONTROL_HEIGHT_MINIMAL)
		statusLabel:Show(false)
		controlsToggleButton:SetText("Show UI")
	end
	SyncOverlayBaseToControlWindow()
end

local function ApplyBoxCalibrationDelta(deltaWidth, deltaHeight)
	boxWidthAdjust = boxWidthAdjust + (deltaWidth or 0)
	boxHeightAdjust = boxHeightAdjust + (deltaHeight or 0)
	SaveCalibrationSettings()
	lastLayoutWidth = nil
	lastLayoutHeight = nil
	if overlayRoot:IsVisible() then
		ReflowRaidLayout(true)
		UpdateAllSlots()
	end
end

ApplyCalibrationDelta = function(deltaOffsetX, deltaOffsetY, deltaWidth, deltaHeight)
	OVERLAY_CONTROL_OFFSET_X = OVERLAY_CONTROL_OFFSET_X + (deltaOffsetX or 0)
	OVERLAY_CONTROL_OFFSET_Y = OVERLAY_CONTROL_OFFSET_Y + (deltaOffsetY or 0)
	overlayLayoutWidth = overlayLayoutWidth + (deltaWidth or 0)
	overlayLayoutHeight = overlayLayoutHeight + (deltaHeight or 0)
	ClampCalibrationDimensions()
	SaveCalibrationSettings()
	SyncOverlayBaseToControlWindow()
	lastLayoutWidth = nil
	lastLayoutHeight = nil
	if overlayRoot:IsVisible() then
		ReflowRaidLayout(true)
		UpdateAllSlots()
	end
end

SetCalibrationModeEnabled = function(enabled)
	calibrationModeEnabled = enabled and true or false
	if calibrationModeEnabled then
		calibrationToggleButton:SetText("Cal On")
	else
		calibrationToggleButton:SetText("Cal")
	end
	ApplyControlStripVisibility()
end

function closeButton:OnClick()
	if isWindowLocked then
		return
	end
	raidFrameWindow:Show(false)
	overlayRoot:Show(false)
end
closeButton:SetHandler("OnClick", closeButton.OnClick)

function lockButton:OnClick()
	isWindowLocked = not isWindowLocked
	ApplyWindowLockState()
	if isWindowLocked then
		Log("window locked")
	else
		Log("window unlocked")
	end
end
lockButton:SetHandler("OnClick", lockButton.OnClick)

function calibrationToggleButton:OnClick()
	SetCalibrationModeEnabled(not calibrationModeEnabled)
end
calibrationToggleButton:SetHandler("OnClick", calibrationToggleButton.OnClick)

function controlsToggleButton:OnClick()
	areControlsVisible = not areControlsVisible
	ApplyControlStripVisibility()
end
controlsToggleButton:SetHandler("OnClick", controlsToggleButton.OnClick)

function calXMinusButton:OnClick()
	ApplyCalibrationDelta(-calibrationStep, 0, 0, 0)
end
calXMinusButton:SetHandler("OnClick", calXMinusButton.OnClick)

function calXPlusButton:OnClick()
	ApplyCalibrationDelta(calibrationStep, 0, 0, 0)
end
calXPlusButton:SetHandler("OnClick", calXPlusButton.OnClick)

function calYMinusButton:OnClick()
	ApplyCalibrationDelta(0, -calibrationStep, 0, 0)
end
calYMinusButton:SetHandler("OnClick", calYMinusButton.OnClick)

function calYPlusButton:OnClick()
	ApplyCalibrationDelta(0, calibrationStep, 0, 0)
end
calYPlusButton:SetHandler("OnClick", calYPlusButton.OnClick)

function calWMinusButton:OnClick()
	ApplyCalibrationDelta(0, 0, -calibrationStep, 0)
end
calWMinusButton:SetHandler("OnClick", calWMinusButton.OnClick)

function calWPlusButton:OnClick()
	ApplyCalibrationDelta(0, 0, calibrationStep, 0)
end
calWPlusButton:SetHandler("OnClick", calWPlusButton.OnClick)

function calHMinusButton:OnClick()
	ApplyCalibrationDelta(0, 0, 0, -calibrationStep)
end
calHMinusButton:SetHandler("OnClick", calHMinusButton.OnClick)

function calHPlusButton:OnClick()
	ApplyCalibrationDelta(0, 0, 0, calibrationStep)
end
calHPlusButton:SetHandler("OnClick", calHPlusButton.OnClick)

function calBXMinusButton:OnClick()
	ApplyBoxCalibrationDelta(-calibrationStep, 0)
end
calBXMinusButton:SetHandler("OnClick", calBXMinusButton.OnClick)

function calBXPlusButton:OnClick()
	ApplyBoxCalibrationDelta(calibrationStep, 0)
end
calBXPlusButton:SetHandler("OnClick", calBXPlusButton.OnClick)

function calBYMinusButton:OnClick()
	ApplyBoxCalibrationDelta(0, -calibrationStep)
end
calBYMinusButton:SetHandler("OnClick", calBYMinusButton.OnClick)

function calBYPlusButton:OnClick()
	ApplyBoxCalibrationDelta(0, calibrationStep)
end
calBYPlusButton:SetHandler("OnClick", calBYPlusButton.OnClick)

function calStepButton:OnClick()
	if calibrationStep == 1 then
		calibrationStep = 2
	elseif calibrationStep == 2 then
		calibrationStep = 5
	else
		calibrationStep = 1
	end
	calStepButton:SetText("S" .. tostring(calibrationStep))
	SaveCalibrationSettings()
end
calStepButton:SetHandler("OnClick", calStepButton.OnClick)

calStepButton:SetText("S" .. tostring(calibrationStep))
ApplyWindowLockState()
SetCalibrationModeEnabled(false)
ApplyControlStripVisibility()

local slotWidgets = {}
local groupHeaderLabels = {}
local slotByFlatIndex = {}

for groupIndex = 1, MAX_GROUPS do
	local groupCol = (groupIndex - 1) % FRAME_COLUMNS
	local groupRow = math.floor((groupIndex - 1) / FRAME_COLUMNS)
	local groupBaseX = FRAME_PADDING_X + groupCol * (SLOT_WIDTH + SLOT_GAP_X)
	local groupBaseY = FRAME_PADDING_TOP + groupRow * (GROUP_BLOCK_HEIGHT + GROUP_GAP_Y)

	local groupLabel = overlayRoot:CreateChildWidget("label", "raidOrgGroupLabel" .. tostring(groupIndex), 0, true)
	groupLabel:SetText(tostring(groupIndex))
	groupLabel.style:SetAlign(ALIGN_LEFT)
	groupLabel.style:SetFontSize(12)
	groupLabel.style:SetColor(0.95, 0.9, 0.72, 1)
	groupLabel.style:SetOutline(true)
	groupLabel:AddAnchor("TOPLEFT", "UIParent", OVERLAY_BASE_X + groupBaseX + 1, OVERLAY_BASE_Y + groupBaseY - 14)
	groupHeaderLabels[groupIndex] = groupLabel

	for memberIndex = 1, PARTY_SIZE do
		local flatIndex = (groupIndex - 1) * PARTY_SIZE + memberIndex
		local slot = overlayRoot:CreateChildWidget("label", "raidOrgSlot" .. tostring(flatIndex), 0, true)
		slot:SetText("")
		slot:SetExtent(SLOT_WIDTH, SLOT_HEIGHT)

		slot:AddAnchor(
			"TOPLEFT",
			"UIParent",
			OVERLAY_BASE_X + groupBaseX,
			OVERLAY_BASE_Y + groupBaseY + (memberIndex - 1) * (SLOT_HEIGHT + SLOT_GAP_Y)
		)
		slot:Show(false)
		slot.lastVisible = false
		slot.token = nil
		slot.flatIndex = flatIndex
		slot.groupIndex = groupIndex
		slot.memberIndex = memberIndex
		slot.memberIdentity = nil
		slot.memberRole = nil
		slot.isFlashing = false
		slot.clickThroughApplied = false

		local bg = slot:CreateColorDrawable(0.10, 0.10, 0.12, 0.92, "background")
		bg:AddAnchor("TOPLEFT", slot, 0, 0)
		bg:SetExtent(SLOT_WIDTH, SLOT_HEIGHT)
		slot.bg = bg

		local hpFill = slot:CreateColorDrawable(COLOR_HEALTHY[1], COLOR_HEALTHY[2], COLOR_HEALTHY[3], COLOR_HEALTHY[4], "artwork")
		hpFill:AddAnchor("TOPLEFT", slot, 0, 0)
		hpFill:SetExtent(SLOT_WIDTH, SLOT_HEIGHT)
		slot.hpFill = hpFill

		local highlight = slot:CreateColorDrawable(1, 1, 1, 0.06, "overlay")
		highlight:AddAnchor("TOPLEFT", slot, 0, 0)
		highlight:SetExtent(SLOT_WIDTH, 9)
		slot.highlight = highlight

		local distanceLabel = slot:CreateChildWidget("label", "raidOrgDistanceLabel" .. tostring(flatIndex), 0, true)
		distanceLabel:SetText("")
		distanceLabel.style:SetAlign(ALIGN_LEFT)
		distanceLabel.style:SetFontSize(11)
		distanceLabel.style:SetColor(0.96, 0.96, 0.96, 1)
		distanceLabel.style:SetOutline(true)
		distanceLabel:AddAnchor("BOTTOMLEFT", slot, 4, -2)
		slot.distanceLabel = distanceLabel
		TrySetWidgetEnabled(distanceLabel, false)
		ForceDisablePick(distanceLabel)

		local nameLabel = slot:CreateChildWidget("label", "raidOrgNameLabel" .. tostring(flatIndex), 0, true)
		nameLabel:SetText("")
		nameLabel.style:SetAlign(ALIGN_LEFT)
		nameLabel.style:SetFontSize(11)
		nameLabel.style:SetColor(0.98, 0.98, 0.98, 1)
		nameLabel.style:SetOutline(true)
		nameLabel:AddAnchor("TOPLEFT", slot, 4, 3)
		slot.nameLabel = nameLabel
		TrySetWidgetEnabled(nameLabel, false)
		ForceDisablePick(nameLabel)

		EnsureSlotClickThrough(slot)

		slotWidgets[#slotWidgets + 1] = slot
		slotByFlatIndex[flatIndex] = slot
	end
end

ReflowRaidLayout = function(force)
	local width = overlayLayoutWidth
	local height = overlayLayoutHeight

	if not force and lastLayoutWidth == width and lastLayoutHeight == height then
		return
	end

	local previousSlotWidth = currentSlotWidth
	lastLayoutWidth = width
	lastLayoutHeight = height

	local contentWidth = width - FRAME_PADDING_X * 2
	if contentWidth < FRAME_COLUMNS * MIN_SLOT_WIDTH + (FRAME_COLUMNS - 1) * SLOT_GAP_X then
		contentWidth = FRAME_COLUMNS * MIN_SLOT_WIDTH + (FRAME_COLUMNS - 1) * SLOT_GAP_X
	end

	local rawSlotWidth = (contentWidth - (FRAME_COLUMNS - 1) * SLOT_GAP_X) / FRAME_COLUMNS
	local computedSlotWidth = math.floor(rawSlotWidth + 0.5)
	computedSlotWidth = computedSlotWidth + boxWidthAdjust
	if computedSlotWidth < MIN_SLOT_WIDTH then
		computedSlotWidth = MIN_SLOT_WIDTH
	end

	local contentHeight = height - FRAME_PADDING_TOP - FRAME_PADDING_BOTTOM
	local minContentHeight = FRAME_GROUP_ROWS * (PARTY_SIZE * MIN_SLOT_HEIGHT + (PARTY_SIZE - 1) * SLOT_GAP_Y)
		+ (FRAME_GROUP_ROWS - 1) * MIN_GROUP_GAP_Y
	if contentHeight < minContentHeight then
		contentHeight = minContentHeight
	end

	local ratioHeight = math.floor((computedSlotWidth * SLOT_HEIGHT / SLOT_WIDTH) + 0.5)
	local maxSlotHeightByContent = math.floor(
		(contentHeight - (FRAME_GROUP_ROWS - 1) * MIN_GROUP_GAP_Y - FRAME_GROUP_ROWS * (PARTY_SIZE - 1) * SLOT_GAP_Y)
			/ (FRAME_GROUP_ROWS * PARTY_SIZE)
	)
	if maxSlotHeightByContent < MIN_SLOT_HEIGHT then
		maxSlotHeightByContent = MIN_SLOT_HEIGHT
	end

	local computedSlotHeight = ratioHeight
	computedSlotHeight = computedSlotHeight + boxHeightAdjust
	if computedSlotHeight < MIN_SLOT_HEIGHT then
		computedSlotHeight = MIN_SLOT_HEIGHT
	end
	if computedSlotHeight > maxSlotHeightByContent then
		computedSlotHeight = maxSlotHeightByContent
	end

	local groupBlockHeight = PARTY_SIZE * computedSlotHeight + (PARTY_SIZE - 1) * SLOT_GAP_Y
	local computedGroupGapY = math.floor(
		(contentHeight - FRAME_GROUP_ROWS * groupBlockHeight) / math.max(1, FRAME_GROUP_ROWS - 1) + 0.5
	)
	if FRAME_GROUP_ROWS <= 1 then
		computedGroupGapY = 0
	elseif computedGroupGapY < MIN_GROUP_GAP_Y then
		computedGroupGapY = MIN_GROUP_GAP_Y
	end

	currentSlotWidth = computedSlotWidth
	currentSlotHeight = computedSlotHeight
	currentGroupGapY = computedGroupGapY

	for groupIndex = 1, MAX_GROUPS do
		local groupCol = (groupIndex - 1) % FRAME_COLUMNS
		local groupRow = math.floor((groupIndex - 1) / FRAME_COLUMNS)
		local groupBaseX = FRAME_PADDING_X + groupCol * (currentSlotWidth + SLOT_GAP_X)
		local groupBaseY = FRAME_PADDING_TOP
			+ groupRow * (PARTY_SIZE * currentSlotHeight + (PARTY_SIZE - 1) * SLOT_GAP_Y + currentGroupGapY)

		local groupLabel = groupHeaderLabels[groupIndex]
		if groupLabel ~= nil then
			groupLabel:RemoveAllAnchors()
			groupLabel:AddAnchor("TOPLEFT", "UIParent", OVERLAY_BASE_X + groupBaseX + 1, OVERLAY_BASE_Y + groupBaseY - 14)
		end

		for memberIndex = 1, PARTY_SIZE do
			local flatIndex = (groupIndex - 1) * PARTY_SIZE + memberIndex
			local slot = slotByFlatIndex[flatIndex]
			if slot ~= nil then
				slot:SetExtent(currentSlotWidth, currentSlotHeight)
				slot:RemoveAllAnchors()
				slot:AddAnchor(
					"TOPLEFT",
					"UIParent",
					OVERLAY_BASE_X + groupBaseX,
					OVERLAY_BASE_Y + groupBaseY + (memberIndex - 1) * (currentSlotHeight + SLOT_GAP_Y)
				)

				if slot.bg ~= nil then
					slot.bg:SetExtent(currentSlotWidth, currentSlotHeight)
				end
				if slot.hpFill ~= nil then
					local fillWidth = 1
					local oldFillWidth = slot.lastHpFillWidth
					if type(oldFillWidth) == "number" and oldFillWidth > 0 and previousSlotWidth > 0 then
						local oldRatio = oldFillWidth / previousSlotWidth
						if oldRatio < 0 then
							oldRatio = 0
						end
						if oldRatio > 1 then
							oldRatio = 1
						end
						fillWidth = math.floor(currentSlotWidth * oldRatio + 0.5)
					end
					if fillWidth < 1 then
						fillWidth = 1
					end
					SetCachedHpFillExtent(slot, fillWidth, currentSlotHeight)
				end
				if slot.highlight ~= nil then
					local highlightHeight = math.floor(currentSlotHeight * 0.26 + 0.5)
					if highlightHeight < 7 then
						highlightHeight = 7
					end
					slot.highlight:SetExtent(currentSlotWidth, highlightHeight)
				end

				if slot.nameLabel ~= nil then
					slot.nameLabel:RemoveAllAnchors()
					slot.nameLabel:AddAnchor("TOPLEFT", slot, 4, 3)
				end
				if slot.distanceLabel ~= nil then
					slot.distanceLabel:RemoveAllAnchors()
					slot.distanceLabel:AddAnchor("BOTTOMLEFT", slot, 4, -2)
				end
			end
		end
	end
end

local function RefreshMemberTokens()
	local areaTokenList = BuildAreaTokenList(activeMemberArea)
	for i = 1, #slotWidgets do
		local slot = slotWidgets[i]
		slot.token = nil
		slot.memberIdentity = nil
		slot.memberRole = nil
		local entry = areaTokenList[slot.flatIndex]
		if entry ~= nil then
			slot.token = entry.token
			slot.memberIdentity = entry.identity
			slot.memberRole = entry.role
		end
	end
end

local function ResolveSlotHealth(slot)
	if slot == nil then
		return nil, nil, nil
	end

	if slot.token ~= nil then
		local ratio, cur, max = TryReadUnitHealth(slot.token)
		if ratio ~= nil then
			return ratio, cur, max
		end
	end

	return nil, nil, nil
end

local function ResolveSlotDistance(slot)
	if slot == nil then
		return nil
	end

	if slot.token ~= nil then
		local distance = TryReadUnitDistance(slot.token)
		if distance ~= nil then
			return distance
		end
	end

	return nil
end

local function SetSlotVisualState(slot, hpColor, hpRatio, nameText, distanceText, bgColor, nameColor)
	if slot == nil then
		return
	end

	if bgColor ~= nil and slot.bg ~= nil then
		ApplyCachedColor(slot, "lastBgColor", slot.bg, bgColor)
	end
	ApplyCachedColor(slot, "lastHpColor", slot.hpFill, hpColor)
	local fillRatio = hpRatio
	if fillRatio == nil then
		fillRatio = 0
	end
	if fillRatio < 0 then
		fillRatio = 0
	end
	if fillRatio > 1 then
		fillRatio = 1
	end
	local fillWidth = math.floor(currentSlotWidth * fillRatio + 0.5)
	if fillWidth < 1 then
		fillWidth = 1
	end
	SetCachedHpFillExtent(slot, fillWidth, currentSlotHeight)
	SetCachedText(slot, "lastNameText", slot.nameLabel, nameText)
	if nameColor ~= nil and slot.nameLabel ~= nil and slot.nameLabel.style ~= nil then
		if slot.lastNameColor ~= nameColor then
			slot.lastNameColor = nameColor
			slot.nameLabel.style:SetColor(nameColor[1], nameColor[2], nameColor[3], 1)
		end
	end
	SetCachedText(slot, "lastDistanceText", slot.distanceLabel, distanceText)
	SetCachedVisible(slot, true)
end

local flashTimer = 0
local flashIndex = 1
local updateAccumulator = 0
local tokenRemapAccumulator = 0

local function UpdateOneSlot(slot)
	if slot == nil or slot.token == nil then
		if slot ~= nil then
			SetCachedVisible(slot, false)
		end
		return
	end

	local name = GetUnitNameByToken(slot.token)
	if name == nil then
		slot.memberIdentity = nil
		slot.isFlashing = false
		SetCachedHpFillExtent(slot, 1, currentSlotHeight)
		SetCachedText(slot, "lastNameText", slot.nameLabel, "")
		SetCachedText(slot, "lastDistanceText", slot.distanceLabel, "")
		EnsureSlotClickThrough(slot)
		SetCachedVisible(slot, false)
		return
	end

	slot.memberIdentity = NormalizeIdentity(name)
	local currentRole = TryReadRoleByMemberIndex(activeMemberArea, slot.flatIndex)
	if currentRole == nil then
		currentRole = TryReadRoleByMemberName(activeMemberArea, name)
	end
	if currentRole ~= nil then
		slot.memberRole = currentRole
	end
	local rolePalette = ResolveRolePalette(slot.memberRole)

	local distance = ResolveSlotDistance(slot)
	local isInClickThroughRange = distance ~= nil and distance <= CLICK_THROUGH_DISTANCE
	if not isInClickThroughRange then
		slot.isFlashing = false
		ApplyCachedColor(slot, "lastBgColor", slot.bg, rolePalette.bg)
		ApplyCachedColor(slot, "lastHpColor", slot.hpFill, COLOR_BLOCKED)
		SetCachedHpFillExtent(slot, currentSlotWidth, currentSlotHeight)
		SetCachedText(slot, "lastNameText", slot.nameLabel, "")
		SetCachedText(slot, "lastDistanceText", slot.distanceLabel, "")
		SetCachedVisible(slot, true)
		EnsureSlotClickThrough(slot)
		return
	end

	local hpRatio = nil
	local hpCurrent = nil
	local hpMax = nil
	hpRatio, hpCurrent, hpMax = ResolveSlotHealth(slot)
	EnsureSlotClickThrough(slot)

	if hpRatio == nil then
		SetSlotVisualState(slot, rolePalette.fill, 1, name, DistanceText(distance), rolePalette.bg, rolePalette.fill)
		return
	end

	if hpCurrent ~= nil and hpMax ~= nil and hpMax > 0 and hpCurrent <= 0 then
		slot.isFlashing = false
		SetSlotVisualState(slot, COLOR_DEAD, 1, name, DistanceText(distance), rolePalette.bg, rolePalette.fill)
	else
		if hpRatio <= HP_FLASH_START then
			slot.isFlashing = true
		elseif hpRatio >= HP_FLASH_STOP then
			slot.isFlashing = false
		end

		local flashColor = nil
		if slot.isFlashing then
			flashColor = FLASH_COLORS[flashIndex]
		end
		local colorToUse = BuildHealthColor(hpRatio, slot.isFlashing, flashColor, rolePalette.fill)
		SetSlotVisualState(slot, colorToUse, hpRatio, name, DistanceText(distance), rolePalette.bg, rolePalette.fill)
	end

end

local function UpdateAllSlots()
	local visibleCount = 0
	for i = 1, #slotWidgets do
		UpdateOneSlot(slotWidgets[i])
		if slotWidgets[i].lastVisible then
			visibleCount = visibleCount + 1
		end
	end

	local viewName = activeMemberArea == "co_raid" and "Co-Raid" or "Raid"
	local statusText = viewName
		.. " | Members: "
		.. tostring(visibleCount)
		.. " | HP flash <=55%, stop >=68%, click-through <= "
		.. tostring(CLICK_THROUGH_DISTANCE)
		.. "m, blank >"
		.. tostring(CLICK_THROUGH_DISTANCE)
		.. "m"
	SetCachedText(runtime, "lastStatusText", statusLabel, statusText)
end

local function SyncResizeGripExtents()
	local width, height = ReadWindowExtent(raidFrameWindow)
	if width == nil or height == nil then
		return
	end

	local rightHeight = height
	local bottomWidth = width
	if rightHeight < 20 then
		rightHeight = 20
	end
	if bottomWidth < 20 then
		bottomWidth = 20
	end

	resizeRightGrip:SetExtent(RESIZE_BORDER, rightHeight)
	resizeBottomGrip:SetExtent(bottomWidth, RESIZE_BORDER)
end

local function ActivateOverlay()
	EnsureOverlayPassThrough()
	SyncOverlayBaseToControlWindow()
	ReflowRaidLayout(true)
	SyncResizeGripExtents()
	overlayRoot:Show(true)
	EnforceOverlayZOrder()
	RefreshMemberTokens()
	UpdateAllSlots()
end

function raidTabButton:OnClick()
	activeMemberArea = "raid"
	RefreshMemberTokens()
	UpdateAllSlots()
end
raidTabButton:SetHandler("OnClick", raidTabButton.OnClick)

function coRaidTabButton:OnClick()
	activeMemberArea = "co_raid"
	RefreshMemberTokens()
	UpdateAllSlots()
end
coRaidTabButton:SetHandler("OnClick", coRaidTabButton.OnClick)

function refreshButton:OnClick()
	RefreshMemberTokens()
	UpdateAllSlots()
	if DEBUG_GEOMETRY_PROBE then
		ProbeRaidFrameGeometryExposure("refresh")
	end
	Log("manual refresh")
end
refreshButton:SetHandler("OnClick", refreshButton.OnClick)

function raidOrgButton:OnClick()
	local willOpen = not overlayRoot:IsVisible()
	raidFrameWindow:Show(willOpen)
	overlayRoot:Show(willOpen)
	if willOpen then
		ActivateOverlay()
	end
end
raidOrgButton:SetHandler("OnClick", raidOrgButton.OnClick)

function raidFrameWindow:OnUpdate(dt)
	if not runtime.active then
		self:Show(false)
		overlayRoot:Show(false)
		return
	end

	if not overlayRoot:IsVisible() then
		updateAccumulator = 0
		tokenRemapAccumulator = 0
		flashTimer = 0
		return
	end

	local delta = dt or 0
	flashTimer = flashTimer + delta
	if flashTimer >= FLASH_INTERVAL then
		flashTimer = 0
		flashIndex = flashIndex + 1
		if flashIndex > #FLASH_COLORS then
			flashIndex = 1
		end
	end

	updateAccumulator = updateAccumulator + delta
	tokenRemapAccumulator = tokenRemapAccumulator + delta
	if tokenRemapAccumulator >= TOKEN_REMAP_INTERVAL then
		tokenRemapAccumulator = 0
		RefreshMemberTokens()
		updateAccumulator = UPDATE_INTERVAL
	end
	if updateAccumulator < UPDATE_INTERVAL then
		EnforceOverlayZOrder()
		SyncOverlayBaseToControlWindow()
		ReflowRaidLayout(false)
		SyncResizeGripExtents()
		return
	end
	updateAccumulator = 0

	EnforceOverlayZOrder()
	SyncOverlayBaseToControlWindow()
	ReflowRaidLayout(false)
	SyncResizeGripExtents()
	UpdateAllSlots()
end
raidFrameWindow:SetHandler("OnUpdate", raidFrameWindow.OnUpdate)

local function HandleTeamChanged(...)
	if not runtime.active then
		return
	end

	RefreshMemberTokens()
	if overlayRoot:IsVisible() then
		UpdateAllSlots()
	end
end

UIParent:SetEventHandler(UIEVENT_TYPE.TEAM_MEMBERS_CHANGED, HandleTeamChanged)
UIParent:SetEventHandler(UIEVENT_TYPE.TEAM_MEMBER_DISCONNECTED, HandleTeamChanged)
UIParent:SetEventHandler(UIEVENT_TYPE.TEAM_MEMBER_UNIT_ID_CHANGED, HandleTeamChanged)
UIParent:SetEventHandler(UIEVENT_TYPE.TEAM_ROLE_CHANGED, HandleTeamChanged)
UIParent:SetEventHandler(UIEVENT_TYPE.TEAM_JOINTED, HandleTeamChanged)
UIParent:SetEventHandler(UIEVENT_TYPE.TEAM_JOINT_RESPONSE, HandleTeamChanged)
UIParent:SetEventHandler(UIEVENT_TYPE.TEAM_JOINT_TARGET, HandleTeamChanged)
UIParent:SetEventHandler(UIEVENT_TYPE.TEAM_JOINT_CHAT, HandleTeamChanged)
UIParent:SetEventHandler(UIEVENT_TYPE.TEAM_JOINT_BREAK, HandleTeamChanged)
UIParent:SetEventHandler(UIEVENT_TYPE.TEAM_JOINT_BROKEN, HandleTeamChanged)

if DEBUG_GEOMETRY_PROBE then
	ProbeRaidFrameGeometryExposure("startup")
end
Log("loaded")
