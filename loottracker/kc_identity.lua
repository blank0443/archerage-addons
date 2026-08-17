-- Kill counter module (toc-ordered; uses LT + Analysis + runtime).
local LT = _G.__LOOT_TRACKER
local runtime = _G.__LOOT_KILL_COUNTER_RUNTIME
local Analysis = _G.__LOOT_KILL_COUNTER_ANALYSIS
local C = LT and LT.KC
if LT == nil or runtime == nil or Analysis == nil or C == nil then
	return
end

local SafeCall = LT.SafeCall
local SafeNumber = LT.SafeNumber
local SafeCallValues = LT.SafeCallValues
local Trim = LT.Trim
local NormalizeName = LT.NormalizeName
local IsValidName = LT.IsValidName
local NamesMatch = LT.NamesMatch
local NormalizeDt = LT.NormalizeDt
local Now = LT.Now
local SaveData = LT.SaveData
local LoadData = LT.LoadData
local GetWidgetPosition = LT.GetWidgetPosition
local SaveWidgetPosition = LT.SaveWidgetPosition
local LoadPosition = LT.LoadPosition
local ClampWindowScale = LT.ClampWindowScale
local RoundScaled = LT.RoundScaled
local SetWidgetFontSize = LT.SetWidgetFontSize
local AnchorWidgetAtPosition = LT.AnchorWidgetAtPosition

local SAVE_KEY = C.SAVE_KEY
local SETTINGS_SAVE_KEY = C.SETTINGS_SAVE_KEY
local HISTORY_SAVE_KEY = C.HISTORY_SAVE_KEY
local WINDOW_POSITION_KEY = C.WINDOW_POSITION_KEY
local WINDOW_SIZE_KEY = C.WINDOW_SIZE_KEY
local VIEW_WINDOW_POSITION_KEY = C.VIEW_WINDOW_POSITION_KEY
local WINDOW_WIDTH = C.WINDOW_WIDTH
local WINDOW_HEIGHT = C.WINDOW_HEIGHT
local MIN_WINDOW_WIDTH = C.MIN_WINDOW_WIDTH
local MIN_WINDOW_HEIGHT = C.MIN_WINDOW_HEIGHT
local VIEW_WINDOW_WIDTH = C.VIEW_WINDOW_WIDTH
local VIEW_WINDOW_HEIGHT = C.VIEW_WINDOW_HEIGHT
local VIEW_ROW_TOP = C.VIEW_ROW_TOP
local VIEW_ROW_HEIGHT = C.VIEW_ROW_HEIGHT
local VIEW_CONTENT_ROW_COUNT = C.VIEW_CONTENT_ROW_COUNT
local VIEW_SEGMENT_CHAR_WIDTH = C.VIEW_SEGMENT_CHAR_WIDTH
local MONEY_GOLD_COLOR = C.MONEY_GOLD_COLOR
local MONEY_SILVER_COLOR = C.MONEY_SILVER_COLOR
local MONEY_COPPER_COLOR = C.MONEY_COPPER_COLOR
local MONEY_LABEL_COLOR = C.MONEY_LABEL_COLOR
local BAG_KIND = C.BAG_KIND
local MAX_BAG_SLOTS = C.MAX_BAG_SLOTS
local PADDING = C.PADDING
local ROW_TOP = C.ROW_TOP
local ROW_HEIGHT = C.ROW_HEIGHT
local PAGE_SIZE = C.PAGE_SIZE
local CORNER_HANDLE_SIZE = C.CORNER_HANDLE_SIZE
local RESIZE_GRIP_LINE_ALPHA = C.RESIZE_GRIP_LINE_ALPHA
local RESIZE_GRIP_HOVER_ALPHA = C.RESIZE_GRIP_HOVER_ALPHA
local RESIZE_GRIP_LINE_LENGTH = C.RESIZE_GRIP_LINE_LENGTH
local RESIZE_GRIP_LINE_THICKNESS = C.RESIZE_GRIP_LINE_THICKNESS
local RESIZE_GRIP_INSET = C.RESIZE_GRIP_INSET
local MIN_WINDOW_SCALE = C.MIN_WINDOW_SCALE
local MAX_WINDOW_SCALE = C.MAX_WINDOW_SCALE
local DAMAGE_RECENT_SECONDS = C.DAMAGE_RECENT_SECONDS
local TARGET_CACHE_SECONDS = C.TARGET_CACHE_SECONDS
local LOOT_ATTRIBUTION_SECONDS = C.LOOT_ATTRIBUTION_SECONDS
local EXP_ATTRIBUTION_SECONDS = C.EXP_ATTRIBUTION_SECONDS
local PLAYER_COMBAT_EXIT_GRACE = C.PLAYER_COMBAT_EXIT_GRACE
local EXP_COMBAT_LOG_TIMEOUT = C.EXP_COMBAT_LOG_TIMEOUT
local PENDING_CAPTURE_DEDUPE_SECONDS = C.PENDING_CAPTURE_DEDUPE_SECONDS
local MONEY_EVENT_DEDUPE_SECONDS = C.MONEY_EVENT_DEDUPE_SECONDS
local MAX_PENDING_HITS_PER_TARGET = C.MAX_PENDING_HITS_PER_TARGET
local MAX_PENDING_HITS_TOTAL = C.MAX_PENDING_HITS_TOTAL
local ZONE_GROUP_NAMES = C.ZONE_GROUP_NAMES
local PROJECTILE_CAPTURE_REASONS = C.PROJECTILE_CAPTURE_REASONS
local FULL_HEALTH_CAPTURE_REASONS = C.FULL_HEALTH_CAPTURE_REASONS
local DAMAGE_CATEGORY_ORDER = C.DAMAGE_CATEGORY_ORDER

function Analysis.SafeUnitName(unit)
	local ok, name = SafeCall(X2Unit, "UnitName", unit)
	if not ok or type(name) ~= "string" then
		return nil
	end
	name = Trim(name)
	if name == "" then
		return nil
	end
	return name
end

function Analysis.NormalizeUnitId(unitId)
	local text = Trim(tostring(unitId or ""))
	if text == "" or text == "0" or NormalizeName(text) == "nil" then
		return nil
	end
	return text
end

function Analysis.GetCurrentTargetUnitId()
	local ok, unitId = SafeCall(X2Unit, "GetTargetUnitId")
	unitId = ok and Analysis.NormalizeUnitId(unitId) or nil
	if unitId ~= nil then
		return unitId
	end

	ok, unitId = SafeCall(X2Unit, "GetUnitId", "target")
	unitId = ok and Analysis.NormalizeUnitId(unitId) or nil
	if unitId ~= nil then
		return unitId
	end
	return nil
end

function Analysis.BuildTargetKey(unitId, targetName)
	unitId = Analysis.NormalizeUnitId(unitId)
	if unitId ~= nil then
		return "id:" .. unitId
	end
	if IsValidName(targetName) then
		return NormalizeName(targetName)
	end
	return nil
end

function Analysis.IsUnitTargetKey(targetKey)
	return type(targetKey) == "string" and string.sub(targetKey, 1, 3) == "id:"
end

function Analysis.GetLocalPlayerUnitId()
	local ok, unitId = SafeCall(X2Unit, "GetUnitId", "player")
	unitId = ok and Analysis.NormalizeUnitId(unitId) or nil
	return unitId
end

function Analysis.IsLocalPlayerUnitId(unitId)
	unitId = Analysis.NormalizeUnitId(unitId)
	if unitId == nil then
		return false
	end
	if unitId == "player" then
		return true
	end
	return unitId == Analysis.GetLocalPlayerUnitId()
end

function Analysis.GetUnitInfoById(unitId)
	unitId = Analysis.NormalizeUnitId(unitId)
	if unitId == nil then
		return nil
	end
	local ok, unitInfo = SafeCall(X2Unit, "GetUnitInfoById", unitId)
	if ok and type(unitInfo) == "table" then
		return unitInfo
	end
	return nil
end

function Analysis.GetUnitNameById(unitId, unitInfo)
	if type(unitInfo) == "table" and IsValidName(unitInfo.name) then
		return Trim(unitInfo.name)
	end
	unitId = Analysis.NormalizeUnitId(unitId)
	if unitId == nil then
		return nil
	end
	local ok, unitName = SafeCall(X2Unit, "GetUnitNameById", unitId)
	if ok and IsValidName(unitName) then
		return Trim(unitName)
	end
	return nil
end

function Analysis.SafeUnitValue(methodName, unit)
	local ok, value = SafeCall(X2Unit, methodName, unit)
	if not ok then
		return nil
	end
	if type(value) == "table" then
		value = value.current or value.health or value.hp or value.value or value[1]
	end
	return tonumber(value)
end

function Analysis.GetLocalPlayerName()
	if IsValidName(runtime.localPlayerName) then
		return runtime.localPlayerName
	end

	local name = Analysis.SafeUnitName("player")
	if name ~= nil then
		runtime.localPlayerName = name
		return runtime.localPlayerName
	end

	local ok, worldName = SafeCall(X2Unit, "UnitNameWithWorld", "player")
	if ok and IsValidName(worldName) then
		runtime.localPlayerName = Trim(worldName)
		return runtime.localPlayerName
	end

	return nil
end

function Analysis.StripWorldSuffix(name)
	name = Trim(name or "")
	local atPos = string.find(name, "@", 1, true)
	if atPos ~= nil then
		return Trim(string.sub(name, 1, atPos - 1))
	end
	return name
end

function Analysis.IsLocalPlayerName(value)
	if not IsValidName(value) then
		return false
	end
	value = Analysis.StripWorldSuffix(value)
	if NormalizeName(value) == "you" then
		return true
	end
	return NamesMatch(value, Analysis.StripWorldSuffix(Analysis.GetLocalPlayerName()))
end

function Analysis.GetPlayerNameKey(name)
	name = Analysis.StripWorldSuffix(name)
	local key = NormalizeName(name)
	if key == "" or key == "unknown" then
		return nil
	end
	return key
end

function Analysis.RememberAllyPlayerName(name)
	local key = Analysis.GetPlayerNameKey(name)
	if key ~= nil then
		runtime.allyPlayerNames[key] = true
	end
end

function Analysis.RememberAllyPlayerToken(unitToken)
	if X2Unit == nil then
		return
	end
	local ok, unitName = SafeCall(X2Unit, "UnitName", unitToken)
	if ok and IsValidName(unitName) then
		Analysis.RememberAllyPlayerName(unitName)
	end
	ok, unitName = SafeCall(X2Unit, "UnitNameWithWorld", unitToken)
	if ok and IsValidName(unitName) then
		Analysis.RememberAllyPlayerName(unitName)
	end
end

function Analysis.RefreshAllyPlayerNames()
	runtime.allyPlayerNames = {}
	Analysis.RememberAllyPlayerName(Analysis.GetLocalPlayerName())
	if X2Team ~= nil then
		for teamIndex = 0, 2 do
			for memberIndex = 1, 50 do
				local ok, memberName = SafeCall(X2Team, "GetTeamMemberName", teamIndex, memberIndex)
				if ok and IsValidName(memberName) then
					Analysis.RememberAllyPlayerName(memberName)
				end
			end
		end
	end
	for memberIndex = 1, 50 do
		Analysis.RememberAllyPlayerToken("team_1_" .. tostring(memberIndex))
		Analysis.RememberAllyPlayerToken("team" .. tostring(memberIndex))
		Analysis.RememberAllyPlayerToken("team_" .. tostring(memberIndex))
		Analysis.RememberAllyPlayerToken("team_2_" .. tostring(memberIndex))
	end
	runtime.allyPlayerNamesUpdatedAt = os.clock and os.clock() or 0
end

function Analysis.IsAlliedPlayerName(name)
	if Analysis.IsLocalPlayerName(name) then
		return true
	end
	local key = Analysis.GetPlayerNameKey(name)
	if key == nil then
		return false
	end
	local now = os.clock and os.clock() or 0
	if type(runtime.allyPlayerNames) ~= "table" or now - (tonumber(runtime.allyPlayerNamesUpdatedAt) or 0) > 2 then
		Analysis.RefreshAllyPlayerNames()
	end
	return runtime.allyPlayerNames[key] == true
end

function Analysis.IsNpcExpTarget(unitId, targetName)
	if not IsValidName(targetName) or Analysis.IsLocalPlayerName(targetName) or Analysis.IsAlliedPlayerName(targetName) then
		return false
	end
	local unitInfo = Analysis.GetUnitInfoById(unitId)
	if type(unitInfo) == "table" and unitInfo.type == "character" then
		return false
	end
	return true
end

function Analysis.MarkPlayerDeathCounterName(name)
	local key = Analysis.GetPlayerNameKey(name)
	if key ~= nil then
		runtime.playerDeathCounterNames[key] = true
	end
end

function Analysis.IsPlayerDeathCounterName(name)
	if Analysis.IsLocalPlayerName(name) then
		return true
	end
	local key = Analysis.GetPlayerNameKey(name)
	return key ~= nil and runtime.playerDeathCounterNames[key] == true
end

function Analysis.ResolveAlliedPlayerDeathName(value)
	if type(value) ~= "string" then
		return nil
	end
	local text = Trim(value)
	if text == "" then
		return nil
	end
	if text == "player" or Analysis.IsAlliedPlayerName(text) then
		return text
	end
	if X2Unit ~= nil then
		local ok, unitName = SafeCall(X2Unit, "UnitName", text)
		if ok and Analysis.IsAlliedPlayerName(unitName) then
			return unitName
		end
		ok, unitName = SafeCall(X2Unit, "UnitNameWithWorld", text)
		if ok and Analysis.IsAlliedPlayerName(unitName) then
			return unitName
		end
	end
	return nil
end

function Analysis.NormalizeLocationPart(value)
	local text = Trim(value)
	if text == "" or NormalizeName(text) == "unknown" then
		return ""
	end
	return text
end

function Analysis.GetZoneGroupLocationText()
	local ok, zoneGroup = SafeCall(X2Unit, "GetCurrentZoneGroup")
	if not ok then
		return ""
	end
	return Analysis.NormalizeLocationPart(ZONE_GROUP_NAMES[tonumber(zoneGroup)])
end

function Analysis.GetCurrentLocationText()
	local zone = ""
	local subZone = ""
	local ok, value = SafeCall(X2World, "GetZoneText")
	if ok then
		zone = Analysis.NormalizeLocationPart(value)
	end
	ok, value = SafeCall(X2World, "GetSubZoneText")
	if ok then
		subZone = Analysis.NormalizeLocationPart(value)
	end

	local region = zone
	if region == "" then
		region = Analysis.GetZoneGroupLocationText()
	end

	if region ~= "" and subZone ~= "" and NormalizeName(region) ~= NormalizeName(subZone) then
		return region .. " (" .. subZone .. ")"
	end
	if region ~= "" then
		return region
	end
	return subZone
end

function Analysis.HasRuntimeSessionKills()
	for _, count in pairs(runtime.sessionKillCounts) do
		count = tonumber(count)
		if count ~= nil and count > 0 then
			return true
		end
	end
	return false
end

-- Keep the latest non-empty zone in runtime memory so portal/loading saves use
-- the zone the session took place in, not the destination after loading.
function Analysis.CaptureCurrentSessionLocation(force)
	local location = Analysis.GetCurrentLocationText()
	if location ~= "" then
		if force or not Analysis.HasRuntimeSessionKills() or not IsValidName(runtime.sessionLocationText) then
			runtime.sessionLocationText = location
		end
		return runtime.sessionLocationText
	end
	return runtime.sessionLocationText
end

function Analysis.CaptureSessionActivityLocation()
	local location = Analysis.GetCurrentLocationText()
	if location ~= "" then
		-- Activity events can arrive while the client is already resolving the
		-- destination zone. Once kills exist, keep the farming zone we captured
		-- earlier so history names do not switch to the arrival location.
		if not Analysis.HasRuntimeSessionKills() or not IsValidName(runtime.sessionLocationText) then
			runtime.sessionLocationText = location
		end
		return runtime.sessionLocationText
	end
	return runtime.sessionLocationText
end

function Analysis.CaptureLoadingStartLocation()
	local location = runtime.sessionLocationText
	if not IsValidName(location) and not Analysis.HasRuntimeSessionKills() then
		location = Analysis.GetCurrentLocationText()
	end
	if IsValidName(location) then
		runtime.loadingStartLocationText = location
	end
	return runtime.loadingStartLocationText
end

function Analysis.GetHistorySessionLocation()
	if IsValidName(runtime.loadingStartLocationText) then
		return runtime.loadingStartLocationText
	end
	if IsValidName(runtime.sessionLocationText) then
		return runtime.sessionLocationText
	end
	if runtime.gameLoadingStarted then
		return nil
	end
	local location = Analysis.GetCurrentLocationText()
	if location ~= "" then
		return location
	end
	return nil
end

function Analysis.GetCurrentDateText()
	if os == nil or type(os.date) ~= "function" then
		return nil
	end

	local ok, dateParts = pcall(os.date, "*t")
	if ok and type(dateParts) == "table" then
		local month = tonumber(dateParts.month)
		local day = tonumber(dateParts.day)
		local year = tonumber(dateParts.year)
		if month ~= nil and day ~= nil and year ~= nil then
			return tostring(month) .. "/" .. tostring(day) .. "/" .. tostring(year)
		end
	end

	ok, dateParts = pcall(os.date, "%m/%d/%Y")
	if ok and type(dateParts) == "string" then
		local month, day, year = string.match(dateParts, "^(%d+)/(%d+)/(%d+)$")
		month = tonumber(month)
		day = tonumber(day)
		year = tonumber(year)
		if month ~= nil and day ~= nil and year ~= nil then
			return tostring(month) .. "/" .. tostring(day) .. "/" .. tostring(year)
		end
	end

	return nil

end

