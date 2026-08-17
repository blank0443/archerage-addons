if API_TYPE == nil then
	return
end

ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.WORLD_MAP)

ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.PLAYER.id)
ADDON:ImportAPI(API_TYPE.BAG.id)
ADDON:ImportAPI(API_TYPE.WORLD.id)
ADDON:ImportAPI(API_TYPE.MAP.id)
if API_TYPE.TEAM ~= nil then
	ADDON:ImportAPI(API_TYPE.TEAM.id)
end
if API_TYPE.UTIL ~= nil then
	ADDON:ImportAPI(API_TYPE.UTIL.id)
end

local LT = _G.__LOOT_TRACKER
local C = LT and LT.KC
if LT == nil or C == nil then
	return
end
local Trim = LT.Trim
local NormalizeName = LT.NormalizeName
local IsValidName = LT.IsValidName
local Now = LT.Now

local previousRuntime = _G.__LOOT_KILL_COUNTER_RUNTIME
if previousRuntime ~= nil then
	previousRuntime.active = false
	if previousRuntime.eventWindow ~= nil then
		previousRuntime.eventWindow:Show(false)
	end
	if previousRuntime.counterWindow ~= nil then
		previousRuntime.counterWindow:Show(false)
	end
	if previousRuntime.viewWindow ~= nil then
		previousRuntime.viewWindow:Show(false)
	end
	if type(previousRuntime.killMapObjects) == "table" then
		for _, object in ipairs(previousRuntime.killMapObjects) do
			if object ~= nil then
				pcall(function()
					object:SetVisible(false)
				end)
				pcall(function()
					object:Show(false)
				end)
			end
		end
	end
	if previousRuntime.resizeHandles ~= nil then
		for _, handle in ipairs(previousRuntime.resizeHandles) do
			if handle ~= nil then
				handle:Show(false)
			end
		end
	end
end

local runtime = {
	active = true,
	clock = 0,
	lastUpdateTime = nil,
	updateElapsed = 0,
	currentPage = 1,
	killCounts = {},
	killerCounts = {},
	sessionKillCounts = {},
	damageDealtByUnit = {},
	damageTakenByUnit = {},
	damageBySkill = {},
	skillUsageByName = {},
	damageByCategory = {},
	damageByElement = {},
	healBySkill = {},
	missesBySkill = {},
	energizeBySkill = {},
	damageTakenBySource = {},
	sessionKillLocations = {},
	playerCombatStats = {},
	itemDropsByUnit = {},
	sessionLootItems = {},
	expByUnit = {},
	recentKillExpValues = {},
	totalDamageDealt = 0,
	totalDamageTaken = 0,
	totalDroppedItems = 0,
	totalExpGained = 0,
	totalGoldEarned = 0,
	totalManaSpent = 0,
	lastPlayerMana = nil,
	lastMoneySnapshot = nil,
	lastMoneyEarnedAmount = nil,
	lastMoneyEarnedTime = nil,
	lastMoneyEarnedSource = nil,
	playerMoneyHandlerRegistered = false,
	localPlayerName = nil,
	combatActive = false,
	combatStart = nil,
	lastCombatActivity = nil,
	lastCombatLogTime = nil,
	lastCombatLogMobName = nil,
	lastCombatLogSourceName = nil,
	playerInCombat = false,
	combatExitSince = nil,
	totalKillTime = 0,
	sessionStartTime = nil,
	lastDamageTaken = nil,
	lastBagSnapshot = nil,
	pendingBagSyncUntil = nil,
	recentDamageByTarget = {},
	targetSnapshotsByName = {},
	pendingTargetHitsByKey = {},
	recentNpcDeathTimes = {},
	expKillCandidates = {},
	currentTargetName = nil,
	currentTargetKey = nil,
	currentTargetTargetName = nil,
	currentTargetWasAlive = false,
	currentTargetDeathCounted = false,
	localPlayerWasAlive = true,
	localPlayerDeathCounted = false,
	localPlayerLastHealth = nil,
	allyPlayerNames = {},
	allyPlayerNamesUpdatedAt = 0,
	playerDeathCounterNames = {},
	recentPlayerDeathTimes = {},
	lastKill = nil,
	autoOpenCounterWindow = false,
	rows = {},
	viewContentRows = {},
	resizeHandles = {},
	historySessions = {},
	nextHistorySessionIndex = 1,
	historyPage = 1,
	gameLoadingStarted = false,
	targetRefreshElapsed = 0,
	targetRefreshDirty = false,
	savePending = false,
	pendingSaveEvents = 0,
	saveElapsed = 0,
	sessionLocationText = nil,
	loadingStartLocationText = nil,
	locationRefreshElapsed = 0,
	viewMode = "current",
	killMapObjects = {},
	killMapSessionIndex = nil,
	pendingKillMapSession = nil,
	killMapOverlayElapsed = 0,
	killMapOverlayAttempts = 0,
}
_G.__LOOT_KILL_COUNTER_RUNTIME = runtime
local Analysis = _G.__LOOT_KILL_COUNTER_ANALYSIS or {}
_G.__LOOT_KILL_COUNTER_ANALYSIS = Analysis
LT.previousKillCounterRuntime = previousRuntime
Analysis.SESSION_SAVE_INTERVAL_SECONDS = 10
Analysis.SESSION_SAVE_EVENT_BATCH = 100
Analysis.TARGET_REFRESH_INTERVAL_SECONDS = 0.5
Analysis.KILL_LOCATION_LIMIT = 400
Analysis.HISTORY_BACKUP_SAVE_KEY = "lootKillCounterHistoryBackup"
Analysis.HISTORY_TEXT_WRAP_CHARS = math.max(32, math.floor((C.VIEW_WINDOW_WIDTH - (C.PADDING * 2)) / C.VIEW_SEGMENT_CHAR_WIDTH) - 2)
Analysis.RECENT_KILL_EXP_LIMIT = 20
Analysis.AEK_KILL_WINDOW = 5
Analysis.PLAYER_DEATH_DEDUPE_SECONDS = 5
Analysis.NPC_DEATH_EVENT_DEDUPE_SECONDS = 3
Analysis.EXP_KILL_CANDIDATE_SECONDS = 10
Analysis.EXP_KILL_CANDIDATE_LIMIT = 30
Analysis.KILL_MAP_COMMON_COORD_TOLERANCE = 54
Analysis.KILL_MAP_COMMON_MARKER_RADIUS = 24
Analysis.KILL_MAP_EFFECT_LIMIT = 18
Analysis.KILL_MAP_EFFECT_RETRY_SECONDS = 0.25
Analysis.KILL_MAP_EFFECT_RETRY_LIMIT = 12

function Analysis.RefreshClock()
	local now = LT.Now()
	if runtime.clock == nil or now > runtime.clock then
		runtime.clock = now
	end
	return runtime.clock
end

function Analysis.GetPersistentTimestamp()
	if os ~= nil and type(os.time) == "function" then
		local ok, value = pcall(os.time)
		value = ok and tonumber(value) or nil
		if value ~= nil and value > 0 then
			return math.floor(value)
		end
	end
	return Analysis.RefreshClock()
end

function Analysis.EnsureSessionStartTime(now)
	now = now or Analysis.RefreshClock()
	local startTime = tonumber(runtime.sessionStartTime)
	if startTime == nil or startTime <= 0 or startTime > now then
		startTime = now
		runtime.sessionStartTime = startTime
	end
	return startTime
end

function Analysis.GetSessionElapsedSeconds(now)
	now = now or Analysis.RefreshClock()
	local startTime = Analysis.EnsureSessionStartTime(now)
	local elapsed = now - startTime
	if elapsed < 0 then
		return 0
	end
	return elapsed
end
function Analysis.NormalizeLootCount(count)
	count = math.floor((tonumber(count) or 1) + 0.5)
	if count < 1 then
		count = 1
	end
	return count
end

function Analysis.IsCurrencyLootItemName(itemName)
	if not IsValidName(itemName) then
		return false
	end
	local name = NormalizeName(itemName)
	if name == "gold" or name == "silver" or name == "copper" or name == "money" then
		return true
	end
	if Analysis.ParseMoneyCopper ~= nil and Analysis.ParseMoneyCopper(itemName) ~= nil then
		return true
	end
	return false
end

function Analysis.AddLootAmount(amountsByItem, itemName, count)
	if type(amountsByItem) ~= "table" or not IsValidName(itemName) then
		return false
	end
	itemName = Trim(itemName)
	if Analysis.IsCurrencyLootItemName(itemName) then
		return false
	end
	count = Analysis.NormalizeLootCount(count)
	amountsByItem[itemName] = (tonumber(amountsByItem[itemName]) or 0) + count
	return true
end

function Analysis.BuildSessionLootItemsFromUnitDrops(itemDropsByUnit)
	local lootItems = {}
	if type(itemDropsByUnit) ~= "table" then
		return lootItems
	end
	for _, drops in pairs(itemDropsByUnit) do
		if type(drops) == "table" then
			for itemName, count in pairs(drops) do
				if IsValidName(itemName) and tonumber(count) ~= nil and tonumber(count) > 0 then
					Analysis.AddLootAmount(lootItems, itemName, count)
				end
			end
		end
	end
	return lootItems
end

function Analysis.NormalizeLootItems(lootItems)
	local normalized = {}
	if type(lootItems) ~= "table" then
		return normalized
	end
	for itemName, count in pairs(lootItems) do
		if IsValidName(itemName) and tonumber(count) ~= nil and tonumber(count) > 0 then
			Analysis.AddLootAmount(normalized, itemName, count)
		end
	end
	return normalized
end

function Analysis.GetLootItemTotal(lootItems)
	local total = 0
	if type(lootItems) ~= "table" then
		return total
	end
	for itemName, count in pairs(lootItems) do
		count = tonumber(count)
		if IsValidName(itemName) and not Analysis.IsCurrencyLootItemName(itemName) and count ~= nil and count > 0 then
			total = total + math.floor(count)
		end
	end
	return total
end

function Analysis.MergeLootItemMaximums(target, source)
	if type(target) ~= "table" or type(source) ~= "table" then
		return false
	end
	local changed = false
	for itemName, count in pairs(source) do
		count = tonumber(count)
		if IsValidName(itemName) and not Analysis.IsCurrencyLootItemName(itemName) and count ~= nil and count > 0 then
			itemName = Trim(itemName)
			if count > (tonumber(target[itemName]) or 0) then
				target[itemName] = Analysis.NormalizeLootCount(count)
				changed = true
			end
		end
	end
	return changed
end

function Analysis.EnsureSessionLootItems()
	if type(runtime.sessionLootItems) ~= "table" then
		runtime.sessionLootItems = {}
	end
	local rebuilt = Analysis.BuildSessionLootItemsFromUnitDrops(runtime.itemDropsByUnit)
	if Analysis.GetLootItemTotal(rebuilt) > 0 then
		Analysis.MergeLootItemMaximums(runtime.sessionLootItems, rebuilt)
	end
	return runtime.sessionLootItems
end
