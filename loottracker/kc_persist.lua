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

function Analysis.PersistHistoryData(key, value)
	local previous = nil
	local loadOk, loaded = pcall(function()
		return ADDON:LoadData(key)
	end)
	if loadOk then
		previous = loaded
	end

	local function RestorePrevious()
		if previous ~= nil then
			pcall(function()
				ADDON:ClearData(key)
				ADDON:SaveData(key, previous)
			end)
		else
			pcall(function()
				ADDON:ClearData(key)
			end)
		end
	end

	local saveOk = pcall(function()
		ADDON:ClearData(key)
		ADDON:SaveData(key, value)
	end)
	if not saveOk then
		RestorePrevious()
		return false
	end

	-- Accept the write only after a proven load-back; otherwise restore the prior payload.
	if not Analysis.HistorySaveRoundTrips(key, value) then
		RestorePrevious()
		return false
	end
	return true
end

function Analysis.ClampWindowSize(width, height)
	width = tonumber(width) or WINDOW_WIDTH
	height = tonumber(height) or WINDOW_HEIGHT
	if width < MIN_WINDOW_WIDTH then
		width = MIN_WINDOW_WIDTH
	end
	if height < MIN_WINDOW_HEIGHT then
		height = MIN_WINDOW_HEIGHT
	end
	return math.floor(width + 0.5), math.floor(height + 0.5)
end

local function RoundScaled(value, scale)
	local scaled = math.floor((value * scale) + 0.5)
	if scaled < 1 then
		return 1
	end
	return scaled
end

local function SetWidgetFontSize(widget, size)
	if widget ~= nil and widget.style ~= nil and type(widget.style.SetFontSize) == "function" then
		widget.style:SetFontSize(size)
	end
end

function Analysis.LoadWindowSize()
	local data = LoadData(WINDOW_SIZE_KEY)
	if type(data) == "table" then
		return Analysis.ClampWindowSize(data.width, data.height)
	end
	return WINDOW_WIDTH, WINDOW_HEIGHT
end

function Analysis.SaveCounterSettings()
	SaveData(SETTINGS_SAVE_KEY, {
		autoOpenCounterWindow = runtime.autoOpenCounterWindow == true,
	})
end

function Analysis.LoadCounterSettings()
	local data = LoadData(SETTINGS_SAVE_KEY)
	if type(data) ~= "table" then
		return
	end
	runtime.autoOpenCounterWindow = data.autoOpenCounterWindow == true
end

function Analysis.LoadKillCounts()
	local data = LoadData(SAVE_KEY)
	if type(data) ~= "table" then
		return
	end

	local kills = data.kills or data.killCounts or data
	if type(kills) == "table" then
		for name, count in pairs(kills) do
			local mobName = Trim(name)
			local killCount = tonumber(count)
			if mobName ~= "" and killCount ~= nil and killCount > 0 then
				runtime.killCounts[mobName] = math.floor(killCount)
			end
		end
	end

	if type(data.killerCounts) == "table" then
		for mobName, killers in pairs(data.killerCounts) do
			local normalizedMobName = Trim(mobName)
			if normalizedMobName ~= "" and type(killers) == "table" then
				runtime.killerCounts[normalizedMobName] = {}
				for killerName, count in pairs(killers) do
					local normalizedKillerName = Trim(killerName)
					local killCount = tonumber(count)
					if normalizedKillerName ~= "" and killCount ~= nil and killCount > 0 then
						runtime.killerCounts[normalizedMobName][normalizedKillerName] = math.floor(killCount)
					end
				end
			end
		end
	end

	runtime.playerDeathCounterNames = {}
	if type(data.playerDeathCounterNames) == "table" then
		for name, value in pairs(data.playerDeathCounterNames) do
			if value == true then
				Analysis.MarkPlayerDeathCounterName(name)
			elseif type(value) == "string" then
				Analysis.MarkPlayerDeathCounterName(value)
			end
		end
	end

	if type(data.lastKill) == "table" then
		runtime.lastKill = data.lastKill
	end
	if type(data.sessionKillCounts) == "table" then
		runtime.sessionKillCounts = data.sessionKillCounts
	end
	if type(data.damageDealtByUnit) == "table" then
		runtime.damageDealtByUnit = data.damageDealtByUnit
	end
	if type(data.damageTakenByUnit) == "table" then
		runtime.damageTakenByUnit = data.damageTakenByUnit
	end
	if type(data.damageBySkill) == "table" then
		runtime.damageBySkill = data.damageBySkill
	end
	if type(data.skillUsageByName) == "table" then
		runtime.skillUsageByName = data.skillUsageByName
	end
	if type(data.damageByCategory) == "table" then
		runtime.damageByCategory = data.damageByCategory
	end
	if type(data.damageByElement) == "table" then
		runtime.damageByElement = data.damageByElement
	end
	if type(data.healBySkill) == "table" then
		runtime.healBySkill = data.healBySkill
	end
	if type(data.missesBySkill) == "table" then
		runtime.missesBySkill = data.missesBySkill
	end
	if type(data.energizeBySkill) == "table" then
		runtime.energizeBySkill = data.energizeBySkill
	end
	if type(data.damageTakenBySource) == "table" then
		runtime.damageTakenBySource = data.damageTakenBySource
	end
	if type(data.sessionKillLocations) == "table" then
		runtime.sessionKillLocations = Analysis.CopyKillLocations(data.sessionKillLocations)
	end
	if type(data.playerCombatStats) == "table" then
		runtime.playerCombatStats = data.playerCombatStats
	end
	if type(data.itemDropsByUnit) == "table" then
		runtime.itemDropsByUnit = data.itemDropsByUnit
	end
	if type(data.sessionLootItems) == "table" then
		runtime.sessionLootItems = Analysis.NormalizeLootItems(data.sessionLootItems)
	end
	Analysis.EnsureSessionLootItems()
	if type(data.expByUnit) == "table" then
		runtime.expByUnit = data.expByUnit
	end
	if type(data.recentKillExpValues) == "table" then
		runtime.recentKillExpValues = Analysis.NormalizeRecentKillExpValues(data.recentKillExpValues)
	end
	runtime.totalDamageDealt = tonumber(data.totalDamageDealt) or runtime.totalDamageDealt
	runtime.totalDamageTaken = tonumber(data.totalDamageTaken) or runtime.totalDamageTaken
	runtime.totalDroppedItems = Analysis.GetLootItemTotal(runtime.sessionLootItems)
	runtime.totalExpGained = tonumber(data.totalExpGained) or runtime.totalExpGained
	runtime.totalGoldEarned = tonumber(data.totalGoldEarned) or runtime.totalGoldEarned
	runtime.totalManaSpent = tonumber(data.totalManaSpent) or runtime.totalManaSpent
	runtime.totalKillTime = tonumber(data.totalKillTime) or runtime.totalKillTime
	runtime.sessionStartTime = tonumber(data.sessionStartTime) or runtime.sessionStartTime
	if type(data.lastDamageTaken) == "table" then
		runtime.lastDamageTaken = data.lastDamageTaken
	end
	if IsValidName(data.sessionLocationText) then
		runtime.sessionLocationText = tostring(data.sessionLocationText)
	end
	if IsValidName(data.loadingStartLocationText) then
		runtime.loadingStartLocationText = tostring(data.loadingStartLocationText)
	end
	Analysis.EnsureSessionStartTime(Analysis.RefreshClock())
	if Analysis.RebuildDamageCategories ~= nil then
		Analysis.RebuildDamageCategories()
	end
end

function Analysis.SaveKillCounts()
	SaveData(SAVE_KEY, {
		kills = runtime.killCounts,
		killerCounts = runtime.killerCounts,
		playerDeathCounterNames = runtime.playerDeathCounterNames,
		lastKill = runtime.lastKill,
		sessionKillCounts = runtime.sessionKillCounts,
		damageDealtByUnit = runtime.damageDealtByUnit,
		damageTakenByUnit = runtime.damageTakenByUnit,
		damageBySkill = runtime.damageBySkill,
		skillUsageByName = runtime.skillUsageByName,
		damageByCategory = runtime.damageByCategory,
		damageByElement = runtime.damageByElement,
		healBySkill = runtime.healBySkill,
		missesBySkill = runtime.missesBySkill,
		energizeBySkill = runtime.energizeBySkill,
		damageTakenBySource = runtime.damageTakenBySource,
		sessionKillLocations = runtime.sessionKillLocations,
		playerCombatStats = runtime.playerCombatStats,
		itemDropsByUnit = runtime.itemDropsByUnit,
		sessionLootItems = runtime.sessionLootItems,
		expByUnit = runtime.expByUnit,
		recentKillExpValues = runtime.recentKillExpValues,
		totalDamageDealt = runtime.totalDamageDealt,
		totalDamageTaken = runtime.totalDamageTaken,
		totalDroppedItems = runtime.totalDroppedItems,
		totalExpGained = runtime.totalExpGained,
		totalGoldEarned = runtime.totalGoldEarned,
		totalManaSpent = runtime.totalManaSpent,
		totalKillTime = runtime.totalKillTime,
		sessionStartTime = Analysis.EnsureSessionStartTime(Analysis.RefreshClock()),
		lastDamageTaken = runtime.lastDamageTaken,
		sessionLocationText = runtime.sessionLocationText,
		loadingStartLocationText = runtime.loadingStartLocationText,
	})
	runtime.savePending = false
	runtime.pendingSaveEvents = 0
	runtime.saveElapsed = 0
end

function Analysis.FlushSessionDataSave(force)
	if runtime.savePending ~= true and force ~= true then
		return
	end
	if force ~= true then
		local pendingEvents = tonumber(runtime.pendingSaveEvents) or 0
		local elapsed = tonumber(runtime.saveElapsed) or 0
		if pendingEvents < Analysis.SESSION_SAVE_EVENT_BATCH or elapsed < Analysis.SESSION_SAVE_INTERVAL_SECONDS then
			return
		end
	end
	Analysis.SaveKillCounts()
end

function Analysis.MarkSessionDataSavePending()
	runtime.savePending = true
	runtime.pendingSaveEvents = (tonumber(runtime.pendingSaveEvents) or 0) + 1
end

function Analysis.RoundCoordinate(value)
	value = tonumber(value)
	if value == nil then
		return nil
	end
	return math.floor((value * 100) + 0.5) / 100
end

function Analysis.ReadCoordinateFromTable(point)
	if type(point) ~= "table" then
		return nil, nil, nil
	end
	local x = point.x or point.worldX or point.coordX or point[1]
	local y = point.y or point.worldY or point.coordY or point[2]
	local z = point.z or point.worldZ or point.coordZ or point[3]
	return tonumber(x), tonumber(y), tonumber(z)
end

function Analysis.NormalizeKillLocation(point)
	local x, y, z = Analysis.ReadCoordinateFromTable(point)
	if x == nil or y == nil then
		return nil
	end
	local coordinateSource = tostring(point.coordinateSource or "player")
	local normalized = {
		x = Analysis.RoundCoordinate(x),
		y = Analysis.RoundCoordinate(y),
		z = Analysis.RoundCoordinate(z) or 0,
		time = tonumber(point.time) or 0,
		mobName = tostring(point.mobName or ""),
		killerName = tostring(point.killerName or ""),
		location = tostring(point.location or ""),
		zoneGroup = tonumber(point.zoneGroup),
		coordinateSource = coordinateSource,
	}

	local worldX = tonumber(point.worldX)
	local worldY = tonumber(point.worldY)
	local worldZ = tonumber(point.worldZ)
	if (worldX == nil or worldY == nil) and coordinateSource == "world" then
		worldX = x
		worldY = y
		worldZ = z
	end
	if worldX ~= nil and worldY ~= nil then
		normalized.worldX = Analysis.RoundCoordinate(worldX)
		normalized.worldY = Analysis.RoundCoordinate(worldY)
		normalized.worldZ = Analysis.RoundCoordinate(worldZ) or 0
	end

	local localX = tonumber(point.localX)
	local localY = tonumber(point.localY)
	local localZ = tonumber(point.localZ)
	if (localX == nil or localY == nil) and coordinateSource == "local" then
		localX = x
		localY = y
		localZ = z
	end
	if localX ~= nil and localY ~= nil then
		normalized.localX = Analysis.RoundCoordinate(localX)
		normalized.localY = Analysis.RoundCoordinate(localY)
		normalized.localZ = Analysis.RoundCoordinate(localZ) or 0
	end

	return normalized
end

function Analysis.CopyKillLocations(points)
	local copied = {}
	if type(points) ~= "table" then
		return copied
	end
	local sourcePoints = Analysis.CollectIndexedTableEntries(points)
	for _, point in ipairs(sourcePoints) do
		local normalized = Analysis.NormalizeKillLocation(point)
		if normalized ~= nil then
			copied[#copied + 1] = normalized
		end
	end
	return copied
end

function Analysis.NormalizeRecentKillExpValues(values)
	local normalized = {}
	if type(values) ~= "table" then
		return normalized
	end

	for _, entry in ipairs(values) do
		if type(entry) == "table" then
			local exp = tonumber(entry.exp)
			if exp ~= nil then
				exp = math.max(0, math.floor(exp + 0.5))
			end
			normalized[#normalized + 1] = {
				mobName = tostring(entry.mobName or ""),
				time = tonumber(entry.time) or 0,
				exp = exp,
				pending = entry.pending == true and exp == nil,
			}
		elseif tonumber(entry) ~= nil then
			normalized[#normalized + 1] = {
				mobName = "",
				time = 0,
				exp = math.max(0, math.floor(tonumber(entry) + 0.5)),
				pending = false,
			}
		end
	end

	while #normalized > Analysis.RECENT_KILL_EXP_LIMIT do
		table.remove(normalized, 1)
	end
	return normalized
end

function Analysis.AddRecentKillExpEntry(mobName)
	local entries = runtime.recentKillExpValues
	if type(entries) ~= "table" then
		entries = {}
		runtime.recentKillExpValues = entries
	end
	entries[#entries + 1] = {
		mobName = Trim(mobName or ""),
		time = Analysis.RefreshClock(),
		exp = nil,
		pending = true,
	}
	while #entries > Analysis.RECENT_KILL_EXP_LIMIT do
		table.remove(entries, 1)
	end
end

function Analysis.ApplyExpToRecentKill(amount)
	amount = math.floor((tonumber(amount) or 0) + 0.5)
	if amount <= 0 or type(runtime.recentKillExpValues) ~= "table" then
		return false
	end

	local now = Analysis.RefreshClock()
	local targetEntry = nil
	for index = #runtime.recentKillExpValues, 1, -1 do
		local entry = runtime.recentKillExpValues[index]
		if type(entry) == "table"
			and entry.pending == true
			and now - (tonumber(entry.time) or 0) <= EXP_ATTRIBUTION_SECONDS
		then
			targetEntry = entry
			break
		end
	end
	if targetEntry == nil then
		for index = #runtime.recentKillExpValues, 1, -1 do
			local entry = runtime.recentKillExpValues[index]
			if type(entry) == "table" and now - (tonumber(entry.time) or 0) <= EXP_ATTRIBUTION_SECONDS then
				targetEntry = entry
				break
			end
		end
	end
	if targetEntry == nil then
		return false
	end

	targetEntry.exp = (tonumber(targetEntry.exp) or 0) + amount
	targetEntry.pending = false
	return true
end

function Analysis.GetTotalAverageExpPerKill()
	local kills = Analysis.GetSessionKillTotal()
	if kills <= 0 then
		return 0
	end
	return (tonumber(runtime.totalExpGained) or 0) / kills
end

-- AEK uses the last five completed kill EXP records once enough kills exist.
-- During EXP event delay or on older saves, it falls back to total session EXP
-- divided by total session kills.
function Analysis.GetAverageExpPerKill(now)
	now = now or Analysis.RefreshClock()
	local sessionKills = Analysis.GetSessionKillTotal()
	if sessionKills <= 0 then
		return 0
	end
	if sessionKills < Analysis.AEK_KILL_WINDOW then
		return Analysis.GetTotalAverageExpPerKill()
	end

	local values = {}
	for index = #(runtime.recentKillExpValues or {}), 1, -1 do
		local entry = runtime.recentKillExpValues[index]
		if type(entry) == "table" then
			local exp = tonumber(entry.exp)
			if exp ~= nil then
				values[#values + 1] = exp
			elseif now - (tonumber(entry.time) or 0) >= EXP_ATTRIBUTION_SECONDS then
				values[#values + 1] = 0
			else
				return Analysis.GetTotalAverageExpPerKill()
			end
			if #values >= Analysis.AEK_KILL_WINDOW then
				break
			end
		end
	end

	if #values < Analysis.AEK_KILL_WINDOW then
		return Analysis.GetTotalAverageExpPerKill()
	end
	local total = 0
	for _, exp in ipairs(values) do
		total = total + exp
	end
	return total / Analysis.AEK_KILL_WINDOW
end

function Analysis.GetDistanceLocationCoordinates(point)
	if type(point) ~= "table" then
		return nil, nil, nil, nil
	end
	local x = tonumber(point.localX)
	local y = tonumber(point.localY)
	local source = "local"
	if x == nil or y == nil then
		x = tonumber(point.worldX)
		y = tonumber(point.worldY)
		source = "world"
	end
	if x == nil or y == nil then
		x = tonumber(point.x)
		y = tonumber(point.y)
		source = tostring(point.coordinateSource or "player")
	end
	if x == nil or y == nil then
		return nil, nil, nil, nil
	end
	return x, y, source, tonumber(point.zoneGroup)
end

-- Distance uses cardinal movement between recorded kill points. Zone/source
-- changes are skipped so teleports and incompatible coordinate systems do not
-- inflate the traveled total.
function Analysis.GetDistanceTraveledFromLocations(points)
	local total = 0
	local lastX = nil
	local lastY = nil
	local lastSource = nil
	local lastZoneGroup = nil

	for _, point in ipairs(points or {}) do
		local x, y, source, zoneGroup = Analysis.GetDistanceLocationCoordinates(point)
		if x ~= nil and y ~= nil then
			if lastX ~= nil
				and lastSource == source
				and (lastZoneGroup == nil or zoneGroup == nil or lastZoneGroup == zoneGroup)
			then
				total = total + math.abs(x - lastX) + math.abs(y - lastY)
			end
			lastX = x
			lastY = y
			lastSource = source
			lastZoneGroup = zoneGroup
		end
	end

	return total
end

function Analysis.GetSessionDistanceTraveled()
	return Analysis.GetDistanceTraveledFromLocations(runtime.sessionKillLocations)
end

function Analysis.GetSavedSessionKillTotal(session)
	if type(session) ~= "table" then
		return 0
	end
	local savedTotal = tonumber(session.killTotal or session.sessionKillTotal or session.sessionKills)
	if savedTotal ~= nil and savedTotal > 0 then
		return math.floor(savedTotal)
	end
	if type(session.killCounts) == "table" then
		local total = 0
		for _, count in pairs(session.killCounts) do
			count = tonumber(count)
			if count ~= nil and count > 0 then
				total = total + math.floor(count)
			end
		end
		if total > 0 then
			return total
		end
	end
	local summary = tostring(session.summary or "")
	local summaryKills = tonumber(string.match(summary, "Session Kills%s+(%d+)"))
	if summaryKills ~= nil and summaryKills > 0 then
		return math.floor(summaryKills)
	end
	local locations = Analysis.CopyKillLocations(session.killLocations)
	return #locations
end

function Analysis.ReadPositionValues(ok, coordinateSource, x, y, z)
	if not ok then
		return nil
	end
	if type(x) == "table" then
		x, y, z = Analysis.ReadCoordinateFromTable(x)
	end
	x = tonumber(x)
	y = tonumber(y)
	z = tonumber(z) or 0
	if x == nil or y == nil then
		return nil
	end
	return {
		x = x,
		y = y,
		z = z,
		coordinateSource = coordinateSource,
	}
end

function Analysis.GetPlayerKillPosition()
	local ok, x, y, z = SafeCallValues(X2Unit, "GetUnitWorldPositionByTarget", "player", false)
	local worldPoint = Analysis.ReadPositionValues(ok, "world", x, y, z)

	ok, x, y, z = SafeCallValues(X2Unit, "GetUnitWorldPositionByTarget", "player", true)
	local localPoint = Analysis.ReadPositionValues(ok, "local", x, y, z)

	if worldPoint ~= nil then
		worldPoint.worldX = worldPoint.x
		worldPoint.worldY = worldPoint.y
		worldPoint.worldZ = worldPoint.z
		if localPoint ~= nil then
			worldPoint.localX = localPoint.x
			worldPoint.localY = localPoint.y
			worldPoint.localZ = localPoint.z
		end
		return worldPoint
	end
	if localPoint ~= nil then
		localPoint.localX = localPoint.x
		localPoint.localY = localPoint.y
		localPoint.localZ = localPoint.z
	end
	return localPoint
end

function Analysis.RecordKillLocation(mobName, killerName)
	local point = Analysis.GetPlayerKillPosition()
	if point == nil then
		return false
	end

	point.time = Analysis.RefreshClock()
	point.mobName = Trim(mobName)
	point.killerName = Trim(killerName)
	point.location = Analysis.CaptureSessionActivityLocation() or ""
	local ok, zoneGroup = SafeCall(X2Unit, "GetCurrentZoneGroup")
	if ok then
		point.zoneGroup = tonumber(zoneGroup)
	end
	runtime.sessionKillLocations[#runtime.sessionKillLocations + 1] = Analysis.NormalizeKillLocation(point)
	while #runtime.sessionKillLocations > Analysis.KILL_LOCATION_LIMIT do
		table.remove(runtime.sessionKillLocations, 1)
	end
	return true
end

function Analysis.BuildHistorySessionStorageKey(name, createdAt, summary)
	name = Trim(name or "")
	local createdAtText = tostring(tonumber(createdAt) or 0)
	summary = tostring(summary or "")
	if name == "" and createdAtText == "0" and summary == "" then
		return nil
	end
	return name .. "|" .. createdAtText .. "|" .. summary
end

function Analysis.GetHistorySessionStorageKey(session)
	if type(session) ~= "table" then
		return nil
	end
	return Analysis.BuildHistorySessionStorageKey(session.name, session.createdAt, session.summary)
end

-- ADDON SaveData/LoadData often returns array rows with string keys; ipairs alone would skip them.
function Analysis.CollectIndexedTableEntries(source)
	local entries = {}
	if type(source) ~= "table" then
		return entries
	end

	for _, value in ipairs(source) do
		entries[#entries + 1] = value
	end
	if #entries > 0 then
		return entries
	end

	local keyed = {}
	for key, value in pairs(source) do
		local index = tonumber(key)
		if index ~= nil and index >= 1 and value ~= nil then
			keyed[#keyed + 1] = {
				index = math.floor(index),
				value = value,
			}
		end
	end
	table.sort(keyed, function(left, right)
		return left.index < right.index
	end)
	for _, item in ipairs(keyed) do
		entries[#entries + 1] = item.value
	end

	if #entries > 0 then
		return entries
	end

	-- Last resort: unordered table values that look like session/row objects.
	for key, value in pairs(source) do
		if type(value) == "table" and key ~= "sessions" and key ~= "nextIndex" and key ~= "savedAt" then
			entries[#entries + 1] = value
		end
	end
	return entries
end

function Analysis.SavedHistoryPayloadHasSessions(data)
	return Analysis.CountSavedHistorySessions(data) > 0
end

-- Count sessions that AppendSavedHistoryData would accept, so shrink checks match merge rules.
function Analysis.CountSavedHistorySessions(data)
	if type(data) ~= "table" then
		return 0
	end
	local sessions = data.sessions or data
	if type(sessions) ~= "table" then
		return 0
	end
	local count = 0
	local entries = Analysis.CollectIndexedTableEntries(sessions)
	for _, session in ipairs(entries) do
		if type(session) == "table" then
			local killTotal = Analysis.GetSavedSessionKillTotal(session)
			local lineEntries = Analysis.CollectIndexedTableEntries(session.lines)
			local hasLines = #lineEntries > 0
			local hasSummary = Trim(session.summary or "") ~= ""
			if killTotal > 0 or hasLines or hasSummary then
				count = count + 1
			end
		end
	end
	return count
end

function Analysis.GetDiskHistorySessionCount()
	local primaryCount = Analysis.CountSavedHistorySessions(LoadData(HISTORY_SAVE_KEY))
	local backupCount = Analysis.CountSavedHistorySessions(LoadData(Analysis.HISTORY_BACKUP_SAVE_KEY))
	if primaryCount > backupCount then
		return primaryCount
	end
	return backupCount
end

-- Idempotent disk→memory merge via LoadSessionHistory seen-key dedupe.
function Analysis.EnsureHistoryMergedFromDisk()
	Analysis.LoadSessionHistory()
end

function Analysis.GetHistorySessionNameIndex(name)
	name = Trim(name or "")
	return tonumber(string.match(name, "^S(%d+)"))
end

-- Next S# must be above every existing history name; never reuse an index still present in the list.
function Analysis.ResolveNextHistorySessionIndex(minimumNext)
	local maxIndex = 0
	for _, session in ipairs(runtime.historySessions or {}) do
		if type(session) == "table" then
			local sessionIndex = Analysis.GetHistorySessionNameIndex(session.name)
			if sessionIndex ~= nil and sessionIndex > maxIndex then
				maxIndex = sessionIndex
			end
		end
	end

	local nextIndex = math.max(maxIndex + 1, tonumber(minimumNext) or 0, tonumber(runtime.nextHistorySessionIndex) or 0)
	if nextIndex < 1 then
		nextIndex = 1
	end
	runtime.nextHistorySessionIndex = nextIndex
	return nextIndex
end

function Analysis.MarkLoadedHistorySessions(seen)
	for _, session in ipairs(runtime.historySessions or {}) do
		local key = Analysis.GetHistorySessionStorageKey(session)
		if key ~= nil then
			seen[key] = true
		end
	end
end

-- Merge saved history rows into memory instead of replacing the visible list.
-- This lets the backup save repair the primary save and prevents UI refreshes
-- from dropping sessions that are already listed in the History window.
function Analysis.AppendSavedHistoryData(data, seen)
	if type(data) ~= "table" then
		return 0, nil
	end

	local sessions = data.sessions or data
	local maxIndex = 0
	local appended = 0
	if type(sessions) == "table" then
		local sessionList = Analysis.CollectIndexedTableEntries(sessions)
		for sourceIndex, session in ipairs(sessionList) do
			if type(session) == "table" then
				local name = Trim(session.name or "")
				if name == "" then
					name = "S" .. tostring(sourceIndex)
				end
				local sessionIndex = Analysis.GetHistorySessionNameIndex(name)
				if sessionIndex ~= nil and sessionIndex > maxIndex then
					maxIndex = sessionIndex
				end

				local sessionKey = Analysis.BuildHistorySessionStorageKey(name, session.createdAt, session.summary)
				if sessionKey == nil then
					sessionKey = "fallback|" .. name .. "|" .. tostring(#runtime.historySessions + appended + 1)
				end

				-- Keep any session that still has identifiable kill data after load/deserialization.
				local killTotal = Analysis.GetSavedSessionKillTotal(session)
				local lineEntries = Analysis.CollectIndexedTableEntries(session.lines)
				local hasLines = #lineEntries > 0
				local hasSummary = Trim(session.summary or "") ~= ""
				if seen[sessionKey] ~= true and (killTotal > 0 or hasLines or hasSummary) then
					local normalizedLines = {}
					for _, line in ipairs(lineEntries) do
						if type(line) == "table" then
							normalizedLines[#normalizedLines + 1] = {
								kind = tostring(line.kind or "metric"),
								text = tostring(line.text or ""),
							}
						end
					end

					local killLocations = Analysis.CopyKillLocations(session.killLocations)
					if killTotal <= 0 then
						killTotal = #killLocations
					end
					runtime.historySessions[#runtime.historySessions + 1] = {
						name = name,
						location = tostring(session.location or ""),
						date = tostring(session.date or ""),
						summary = tostring(session.summary or ""),
						killTotal = killTotal,
						createdAt = tonumber(session.createdAt) or 0,
						sessionElapsedSeconds = tonumber(session.sessionElapsedSeconds) or 0,
						killTimeSeconds = tonumber(session.killTimeSeconds) or 0,
						distanceTraveled = tonumber(session.distanceTraveled) or Analysis.GetDistanceTraveledFromLocations(killLocations),
						killsPerMinute = tonumber(session.killsPerMinute) or 0,
						expPerMinute = tonumber(session.expPerMinute) or 0,
						averageExpPerKill = tonumber(session.averageExpPerKill) or 0,
						lines = normalizedLines,
						killLocations = killLocations,
					}
					seen[sessionKey] = true
					appended = appended + 1
				end
			end
		end
	end

	return maxIndex, tonumber(data.nextIndex), appended
end

function Analysis.LoadSessionHistory()
	local seen = {}
	Analysis.MarkLoadedHistorySessions(seen)
	local primaryData = LoadData(HISTORY_SAVE_KEY)
	local backupData = LoadData(Analysis.HISTORY_BACKUP_SAVE_KEY)
	local primaryMaxIndex, primaryNextIndex = Analysis.AppendSavedHistoryData(primaryData, seen)
	local backupMaxIndex, backupNextIndex = Analysis.AppendSavedHistoryData(backupData, seen)
	local savedNextIndex = math.max(
		tonumber(primaryNextIndex) or 0,
		tonumber(backupNextIndex) or 0,
		(tonumber(primaryMaxIndex) or 0) + 1,
		(tonumber(backupMaxIndex) or 0) + 1
	)
	-- Finalize from in-memory names too, so a failed/partial disk load cannot reset the counter.
	Analysis.ResolveNextHistorySessionIndex(savedNextIndex)
end

-- Deep-copy sessions for disk so live UI mutations cannot corrupt an in-flight save payload.
function Analysis.CopyHistorySessionForStorage(session)
	if type(session) ~= "table" then
		return nil
	end
	local lines = {}
	if type(session.lines) == "table" then
		for _, line in ipairs(session.lines) do
			if type(line) == "table" then
				lines[#lines + 1] = {
					kind = tostring(line.kind or "metric"),
					text = tostring(line.text or ""),
				}
			end
		end
	end
	return {
		name = tostring(session.name or ""),
		location = tostring(session.location or ""),
		date = tostring(session.date or ""),
		summary = tostring(session.summary or ""),
		killTotal = Analysis.GetSavedSessionKillTotal(session),
		createdAt = tonumber(session.createdAt) or 0,
		sessionElapsedSeconds = tonumber(session.sessionElapsedSeconds) or 0,
		killTimeSeconds = tonumber(session.killTimeSeconds) or 0,
		distanceTraveled = tonumber(session.distanceTraveled) or 0,
		killsPerMinute = tonumber(session.killsPerMinute) or 0,
		expPerMinute = tonumber(session.expPerMinute) or 0,
		averageExpPerKill = tonumber(session.averageExpPerKill) or 0,
		lines = lines,
		killLocations = Analysis.CopyKillLocations(session.killLocations),
	}
end

function Analysis.BuildSessionHistorySavePayload(options)
	options = options or {}
	local includeDetails = options.includeDetails ~= false
	local sessions = {}
	for index, session in ipairs(runtime.historySessions or {}) do
		local copied = Analysis.CopyHistorySessionForStorage(session)
		if copied ~= nil then
			if not includeDetails then
				-- Slim fallback when full nested payloads fail to round-trip through ADDON:SaveData.
				copied.lines = {}
				copied.killLocations = {}
			end
			sessions[#sessions + 1] = copied
		end
	end
	return {
		nextIndex = runtime.nextHistorySessionIndex,
		sessions = sessions,
		savedAt = Analysis.GetPersistentTimestamp(),
	}
end

function Analysis.HistorySaveRoundTrips(key, payload)
	local loaded = LoadData(key)
	if #(payload.sessions or {}) == 0 then
		return type(loaded) == "table"
	end
	return Analysis.SavedHistoryPayloadHasSessions(loaded)
end

function Analysis.SaveSessionHistory(allowEmpty)
	allowEmpty = allowEmpty == true
	-- Non-intentional saves must start from a full disk merge so memory cannot overwrite a larger history.
	if not allowEmpty then
		Analysis.EnsureHistoryMergedFromDisk()
	end
	local payload = Analysis.BuildSessionHistorySavePayload()
	if #(payload.sessions or {}) == 0 and not allowEmpty then
		local primaryData = LoadData(HISTORY_SAVE_KEY)
		local backupData = LoadData(Analysis.HISTORY_BACKUP_SAVE_KEY)
		if Analysis.SavedHistoryPayloadHasSessions(primaryData)
			or Analysis.SavedHistoryPayloadHasSessions(backupData)
		then
			-- Memory is empty but disk still has sessions: reload and never write an empty wipe.
			Analysis.LoadSessionHistory()
			payload = Analysis.BuildSessionHistorySavePayload()
			if #(payload.sessions or {}) == 0 then
				return false
			end
		else
			return true
		end
	end

	-- Refuse accidental shrinks unless Clear/Delete passed allowEmpty.
	if not allowEmpty then
		local diskCount = Analysis.GetDiskHistorySessionCount()
		local memoryCount = #(payload.sessions or {})
		if diskCount > memoryCount then
			Analysis.EnsureHistoryMergedFromDisk()
			payload = Analysis.BuildSessionHistorySavePayload()
			memoryCount = #(payload.sessions or {})
			if diskCount > memoryCount then
				return false
			end
		end
	end

	local function PersistPayload(nextPayload)
		-- Backup first so a primary write failure still leaves a durable copy.
		-- PersistHistoryData validates round-trip and restores that key on failure.
		local backupOk = Analysis.PersistHistoryData(Analysis.HISTORY_BACKUP_SAVE_KEY, nextPayload)
		local primaryOk = Analysis.PersistHistoryData(HISTORY_SAVE_KEY, nextPayload)
		if not primaryOk and backupOk then
			primaryOk = Analysis.PersistHistoryData(HISTORY_SAVE_KEY, nextPayload)
		end
		return primaryOk or backupOk
	end

	if PersistPayload(payload) then
		return true
	end

	-- Retry without heavy nested detail so session summaries still survive across restarts.
	if #(payload.sessions or {}) > 0 then
		local slimPayload = Analysis.BuildSessionHistorySavePayload({ includeDetails = false })
		if PersistPayload(slimPayload) then
			return true
		end
	end
	return allowEmpty and PersistPayload(payload) or false
end

-- Carry in-memory history across addon UI refresh, then merge disk primary/backup.
-- Do not eagerly rewrite disk on read unless primary is missing and memory/backup still have sessions.
function Analysis.RestoreAndPersistSessionHistory(previous)
	if previous ~= nil and type(previous.historySessions) == "table" then
		-- Direct carry: avoid AppendSavedHistoryData drop filters on live previous sessions.
		runtime.historySessions = previous.historySessions
		Analysis.ResolveNextHistorySessionIndex(previous.nextHistorySessionIndex)
	end
	Analysis.LoadSessionHistory()
	local primaryData = LoadData(HISTORY_SAVE_KEY)
	if #runtime.historySessions > 0 and not Analysis.SavedHistoryPayloadHasSessions(primaryData) then
		Analysis.SaveSessionHistory(false)
	end
end

function Analysis.ClearSessionHistory()
	Analysis.EnsureHistoryMergedFromDisk()
	if runtime.HideHistoryClearConfirm ~= nil then
		runtime:HideHistoryClearConfirm()
	end
	runtime.historySessions = {}
	runtime.nextHistorySessionIndex = 1
	runtime.historyPage = 1
	runtime.killMapSessionIndex = nil
	runtime.pendingKillMapSession = nil
	runtime.killMapOverlayElapsed = 0
	runtime.killMapOverlayAttempts = 0
	if Analysis.ClearKillMapObjects ~= nil then
		Analysis.ClearKillMapObjects()
	end
	-- Intentional wipe: clear stored keys, then write an empty payload to both slots.
	pcall(function()
		ADDON:ClearData(HISTORY_SAVE_KEY)
		ADDON:ClearData(Analysis.HISTORY_BACKUP_SAVE_KEY)
	end)
	Analysis.SaveSessionHistory(true)
	if Analysis.UpdateViewWindow ~= nil and runtime.viewMode == "history" then
		Analysis.UpdateViewWindow()
	end
end

function Analysis.DeleteHistorySession(sessionIndex)
	Analysis.EnsureHistoryMergedFromDisk()
	sessionIndex = math.floor(tonumber(sessionIndex) or 0)
	if sessionIndex < 1 or runtime.historySessions[sessionIndex] == nil then
		return false
	end

	if runtime.HideHistoryClearConfirm ~= nil then
		runtime:HideHistoryClearConfirm()
	end

	table.remove(runtime.historySessions, sessionIndex)

	-- Keep map overlay index aligned after the array shift.
	local mapIndex = tonumber(runtime.killMapSessionIndex)
	if mapIndex == sessionIndex then
		runtime.killMapSessionIndex = nil
		runtime.pendingKillMapSession = nil
		runtime.killMapOverlayElapsed = 0
		runtime.killMapOverlayAttempts = 0
		if Analysis.ClearKillMapObjects ~= nil then
			Analysis.ClearKillMapObjects()
		end
	elseif mapIndex ~= nil and mapIndex > sessionIndex then
		runtime.killMapSessionIndex = mapIndex - 1
	end

	Analysis.SaveSessionHistory(true)
	if Analysis.UpdateViewWindow ~= nil and runtime.viewMode == "history" then
		Analysis.UpdateViewWindow()
	end
	return true
end

