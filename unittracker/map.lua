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

-- Location capture / map open helpers live on runtime.map (avoids a new top-level local).
-- Pattern mirrors loottracker/kill_count.lua: GetUnitWorldPositionByTarget + ShowWorldmapLocation + ShowSkillMapEffect.
runtime.map = {
	BUTTON_SIZE = 24,
	MARKER_RADIUS = 24,
	RETRY_SECONDS = 0.25,
	RETRY_LIMIT = 12,
}

function runtime.map.SafeCallValues(target, methodName, ...)
	if target == nil or type(target[methodName]) ~= "function" then
		return false
	end
	return pcall(target[methodName], target, ...)
end

function runtime.map.RoundCoordinate(value)
	value = tonumber(value)
	if value == nil then
		return nil
	end
	return math.floor((value * 100) + 0.5) / 100
end

function runtime.map.ReadCoordinateFromTable(point)
	if type(point) ~= "table" then
		return nil, nil, nil
	end
	local x = point.x or point.worldX or point.coordX or point[1]
	local y = point.y or point.worldY or point.coordY or point[2]
	local z = point.z or point.worldZ or point.coordZ or point[3]
	return tonumber(x), tonumber(y), tonumber(z)
end

function runtime.map.ReadPositionValues(ok, coordinateSource, x, y, z)
	if not ok then
		return nil
	end
	if type(x) == "table" then
		x, y, z = runtime.map.ReadCoordinateFromTable(x)
	end
	x = tonumber(x)
	y = tonumber(y)
	z = tonumber(z) or 0
	if x == nil or y == nil then
		return nil
	end
	return {
		x = runtime.map.RoundCoordinate(x),
		y = runtime.map.RoundCoordinate(y),
		z = runtime.map.RoundCoordinate(z) or 0,
		coordinateSource = coordinateSource,
	}
end

function runtime.map.Normalize(point)
	local x, y, z = runtime.map.ReadCoordinateFromTable(point)
	if x == nil or y == nil then
		return nil
	end
	local coordinateSource = tostring(point.coordinateSource or "player")
	local normalized = {
		x = runtime.map.RoundCoordinate(x),
		y = runtime.map.RoundCoordinate(y),
		z = runtime.map.RoundCoordinate(z) or 0,
		zoneGroup = tonumber(point.zoneGroup),
		coordinateSource = coordinateSource,
	}

	local worldX = tonumber(point.worldX)
	local worldY = tonumber(point.worldY)
	local worldZ = tonumber(point.worldZ)
	if (worldX == nil or worldY == nil) and coordinateSource == "world" then
		worldX, worldY, worldZ = x, y, z
	end
	if worldX ~= nil and worldY ~= nil then
		normalized.worldX = runtime.map.RoundCoordinate(worldX)
		normalized.worldY = runtime.map.RoundCoordinate(worldY)
		normalized.worldZ = runtime.map.RoundCoordinate(worldZ) or 0
	end

	local localX = tonumber(point.localX)
	local localY = tonumber(point.localY)
	local localZ = tonumber(point.localZ)
	if (localX == nil or localY == nil) and coordinateSource == "local" then
		localX, localY, localZ = x, y, z
	end
	if localX ~= nil and localY ~= nil then
		normalized.localX = runtime.map.RoundCoordinate(localX)
		normalized.localY = runtime.map.RoundCoordinate(localY)
		normalized.localZ = runtime.map.RoundCoordinate(localZ) or 0
	end

	return normalized
end

function runtime.map.GetEntryLocation(entry)
	if type(entry) ~= "table" or type(entry.location) ~= "table" then
		return nil
	end
	return runtime.map.Normalize(entry.location)
end

function runtime.map.CaptureLocalPlayer()
	local ok, x, y, z = runtime.map.SafeCallValues(X2Unit, "GetUnitWorldPositionByTarget", "player", false)
	local worldPoint = runtime.map.ReadPositionValues(ok, "world", x, y, z)

	ok, x, y, z = runtime.map.SafeCallValues(X2Unit, "GetUnitWorldPositionByTarget", "player", true)
	local localPoint = runtime.map.ReadPositionValues(ok, "local", x, y, z)

	local point = nil
	if worldPoint ~= nil then
		worldPoint.worldX = worldPoint.x
		worldPoint.worldY = worldPoint.y
		worldPoint.worldZ = worldPoint.z
		if localPoint ~= nil then
			worldPoint.localX = localPoint.x
			worldPoint.localY = localPoint.y
			worldPoint.localZ = localPoint.z
		end
		point = worldPoint
	elseif localPoint ~= nil then
		localPoint.localX = localPoint.x
		localPoint.localY = localPoint.y
		localPoint.localZ = localPoint.z
		point = localPoint
	end

	if point == nil then
		return nil
	end

	local zoneGroup
	ok, zoneGroup = runtime.map.SafeCallValues(X2Unit, "GetCurrentZoneGroup")
	if ok then
		point.zoneGroup = tonumber(zoneGroup)
	end
	return runtime.map.Normalize(point)
end

function runtime.map.GetMapCoordinates(point)
	point = runtime.map.Normalize(point)
	if point == nil then
		return nil, nil, nil
	end
	local x = tonumber(point.worldX)
	local y = tonumber(point.worldY)
	local z = tonumber(point.worldZ)
	if (x == nil or y == nil) and tostring(point.coordinateSource or "") ~= "local" then
		x = tonumber(point.x)
		y = tonumber(point.y)
		z = tonumber(point.z)
	end
	if x == nil or y == nil then
		return nil, nil, nil
	end
	return x, y, tonumber(z) or 0
end

function runtime.map.HasCoordinates(point)
	local x, y = runtime.map.GetMapCoordinates(point)
	return x ~= nil and y ~= nil and tonumber(point and point.zoneGroup) ~= nil
end

function runtime.map.GetWorldMapContent()
	if ADDON == nil or type(ADDON.GetContent) ~= "function" or UIC_WORLDMAP == nil then
		return nil
	end
	local ok, content = SafeCall(ADDON, "GetContent", UIC_WORLDMAP)
	if ok then
		return content
	end
	return nil
end

function runtime.map.ClearMapEffects()
	local mapWidget = runtime.map.GetWorldMapContent()
	if mapWidget == nil then
		return
	end
	for index = 1, 8 do
		SafeCall(mapWidget, "ShowSkillMapEffect", 0, 0, 0, 0, index)
	end
end

function runtime.map.MarkMap(point)
	local mapWidget = runtime.map.GetWorldMapContent()
	if mapWidget == nil then
		return false
	end
	local x, y, z = runtime.map.GetMapCoordinates(point)
	if x == nil or y == nil then
		return false
	end
	runtime.map.ClearMapEffects()
	return SafeCall(
		mapWidget,
		"ShowSkillMapEffect",
		x,
		y,
		z or 0,
		runtime.map.MARKER_RADIUS,
		1
	) == true
end

function runtime.map.ScheduleOverlay(point)
	runtime.mapOverlay = runtime.mapOverlay or {}
	runtime.mapOverlay.pending = runtime.map.Normalize(point)
	runtime.mapOverlay.elapsed = runtime.map.RETRY_SECONDS
	runtime.mapOverlay.attempts = 0
end

function runtime.map.UpdatePendingOverlay(dt)
	local state = runtime.mapOverlay
	if state == nil or state.pending == nil then
		return
	end
	local delta = tonumber(dt) or 0
	if delta > 1 then
		delta = delta / 1000
	end
	state.elapsed = (tonumber(state.elapsed) or 0) + delta
	if state.elapsed < runtime.map.RETRY_SECONDS then
		return
	end
	state.elapsed = 0
	state.attempts = (tonumber(state.attempts) or 0) + 1
	if runtime.map.MarkMap(state.pending) or state.attempts >= runtime.map.RETRY_LIMIT then
		state.pending = nil
	end
end

function runtime.map.Open(point)
	point = runtime.map.Normalize(point)
	if not runtime.map.HasCoordinates(point) then
		return false
	end
	local x, y, z = runtime.map.GetMapCoordinates(point)
	local zoneGroup = tonumber(point.zoneGroup)
	if zoneGroup == nil or x == nil or y == nil or X2Map == nil then
		return false
	end
	local ok = SafeCall(X2Map, "ShowWorldmapLocation", zoneGroup, x, y, z or 0)
	if ok then
		runtime.map.ScheduleOverlay(point)
	end
	return ok == true
end

function runtime.map.RefreshNoteMapButton()
	local noteWindow = runtime.noteWindow
	if noteWindow == nil or noteWindow.mapButton == nil then
		return
	end
	local entry = runtime.friendly[runtime.noteTargetKey] or runtime.hostile[runtime.noteTargetKey]
	local hasLocation = runtime.map.HasCoordinates(runtime.map.GetEntryLocation(entry))
	noteWindow.mapButton:Enable(hasLocation)
end

function runtime.map.OpenNoteTargetLocation()
	local entry = runtime.friendly[runtime.noteTargetKey] or runtime.hostile[runtime.noteTargetKey]
	local point = runtime.map.GetEntryLocation(entry)
	-- No saved coordinates: do not open the world map.
	if not runtime.map.HasCoordinates(point) then
		runtime.map.RefreshNoteMapButton()
		return false
	end
	return runtime.map.Open(point)
end

function runtime.map.FormatExportCoordinates(entry)
	local point = runtime.map.GetEntryLocation(entry)
	if point == nil then
		return ""
	end
	local x, y, z = runtime.map.GetMapCoordinates(point)
	if x == nil or y == nil then
		x = tonumber(point.x)
		y = tonumber(point.y)
		z = tonumber(point.z) or 0
	end
	if x == nil or y == nil then
		return ""
	end
	local text = tostring(x) .. ", " .. tostring(y) .. ", " .. tostring(z or 0)
	local zoneGroup = tonumber(point.zoneGroup)
	if zoneGroup ~= nil then
		text = text .. " | zone " .. tostring(zoneGroup)
	end
	return text
end
