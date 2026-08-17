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

function Analysis.GetLocalPlayerCounterName(fallback)
	local playerName = Analysis.GetLocalPlayerName()
	if IsValidName(playerName) then
		return Analysis.StripWorldSuffix(playerName)
	end
	if IsValidName(fallback) and NormalizeName(fallback) ~= "you" then
		return Analysis.StripWorldSuffix(fallback)
	end
	return "You"
end

function Analysis.ApplyCounterRowStyle(row, mobName)
	if row == nil or row.style == nil then
		return
	end
	if mobName ~= nil and Analysis.IsPlayerDeathCounterName(mobName) then
		row.style:SetColor(1, 0.25, 0.25, 1)
	else
		row.style:SetColor(1, 1, 1, 1)
	end
end

function Analysis.ResolveLocalPlayerDeathKillerName(fallback)
	if IsValidName(fallback) and not Analysis.IsLocalPlayerName(fallback) then
		return Trim(fallback)
	end
	if type(runtime.lastDamageTaken) == "table" then
		local sourceName = Trim(runtime.lastDamageTaken.sourceName or "")
		local takenAt = tonumber(runtime.lastDamageTaken.time) or 0
		if sourceName ~= "" and not Analysis.IsLocalPlayerName(sourceName) and Analysis.RefreshClock() - takenAt <= 12 then
			return sourceName
		end
	end
	return "Unknown"
end

-- Player deaths can arrive through a death event, a combat death message, or
-- health polling. Track alive/dead state so the same death only increments once.
function Analysis.ResetLocalPlayerDeathTracking()
	local health = Analysis.SafeUnitValue("UnitHealth", "player")
	runtime.localPlayerLastHealth = health
	runtime.localPlayerWasAlive = health == nil or health > 0
	runtime.localPlayerDeathCounted = health ~= nil and health <= 0
end

function Analysis.SyncLocalPlayerDeathState()
	local health = Analysis.SafeUnitValue("UnitHealth", "player")
	if health == nil then
		return nil
	end
	runtime.localPlayerLastHealth = health
	if health > 0 then
		runtime.localPlayerWasAlive = true
		runtime.localPlayerDeathCounted = false
	else
		if runtime.localPlayerWasAlive == true and runtime.localPlayerDeathCounted ~= true then
			Analysis.CountLocalPlayerDeath(Analysis.ResolveLocalPlayerDeathKillerName())
		else
			runtime.localPlayerWasAlive = false
		end
	end
	return health
end

function Analysis.ExtractAlliedPlayerDeathName(...)
	for index = 1, select("#", ...) do
		local value = select(index, ...)
		if type(value) == "string" then
			local name = Analysis.ResolveAlliedPlayerDeathName(value)
			if name ~= nil then
				return name
			end
		elseif type(value) == "table" then
			local name = Analysis.ExtractAlliedPlayerDeathName(
				value.unit,
				value.unitId,
				value.unitName,
				value.name,
				value.deadName,
				value.deadUnitName,
				value.targetName
			)
			if name ~= nil then
				return name
			end
		end
	end
	return nil
end

function Analysis.ClearSessionStats()
	runtime.sessionKillCounts = {}
	runtime.damageDealtByUnit = {}
	runtime.damageTakenByUnit = {}
	runtime.damageBySkill = {}
	runtime.skillUsageByName = {}
	runtime.damageByCategory = {}
	runtime.damageByElement = {}
	runtime.healBySkill = {}
	runtime.missesBySkill = {}
	runtime.energizeBySkill = {}
	runtime.damageTakenBySource = {}
	runtime.sessionKillLocations = {}
	runtime.playerCombatStats = {}
	runtime.itemDropsByUnit = {}
	runtime.sessionLootItems = {}
	runtime.expByUnit = {}
	runtime.recentKillExpValues = {}
	runtime.totalDamageDealt = 0
	runtime.totalDamageTaken = 0
	runtime.totalDroppedItems = 0
	runtime.totalExpGained = 0
	runtime.totalGoldEarned = 0
	runtime.totalManaSpent = 0
	runtime.totalKillTime = 0
	runtime.sessionStartTime = Analysis.RefreshClock()
	runtime.combatActive = false
	runtime.combatStart = nil
	runtime.lastCombatActivity = nil
	runtime.playerInCombat = false
	runtime.combatExitSince = nil
	runtime.lastCombatLogTime = nil
	runtime.lastCombatLogMobName = nil
	runtime.lastCombatLogSourceName = nil
	runtime.sessionLocationText = nil
	runtime.loadingStartLocationText = nil
	runtime.locationRefreshElapsed = 0
	runtime.lastBagSnapshot = nil
	runtime.pendingBagSyncUntil = nil
	runtime.localPlayerName = nil
	runtime.recentPlayerDeathTimes = {}
	runtime.recentNpcDeathTimes = {}
	runtime.expKillCandidates = {}
	Analysis.ResetLocalPlayerDeathTracking()
	runtime.lastPlayerMana = nil
	runtime.lastMoneySnapshot = nil
	runtime.lastMoneyEarnedAmount = nil
	runtime.lastMoneyEarnedTime = nil
	runtime.lastMoneyEarnedSource = nil
	runtime.lastDamageTaken = nil
	runtime.savePending = false
	runtime.pendingSaveEvents = 0
	runtime.saveElapsed = 0
	Analysis.SyncSessionResourceSnapshots()
	Analysis.SyncBagDrops(true)
	if Analysis.RefreshViewWindowIfVisible ~= nil then
		Analysis.RefreshViewWindowIfVisible()
	end
end

function Analysis.CountKill(mobName, killerName)
	if not IsValidName(mobName) then
		return
	end

	mobName = Trim(mobName)
	if not IsValidName(killerName) then
		killerName = "Unknown"
	else
		killerName = Trim(killerName)
	end

	Analysis.CaptureSessionActivityLocation()
	runtime.killCounts[mobName] = (tonumber(runtime.killCounts[mobName]) or 0) + 1
	runtime.sessionKillCounts[mobName] = (tonumber(runtime.sessionKillCounts[mobName]) or 0) + 1
	Analysis.AddRecentKillExpEntry(mobName)
	Analysis.RecordKillLocation(mobName, killerName)
	if runtime.killerCounts[mobName] == nil then
		runtime.killerCounts[mobName] = {}
	end
	runtime.killerCounts[mobName][killerName] = (tonumber(runtime.killerCounts[mobName][killerName]) or 0) + 1
	runtime.lastKill = {
		mobName = mobName,
		killerName = killerName,
		count = runtime.killCounts[mobName],
		time = Analysis.RefreshClock(),
	}
	Analysis.SaveKillCounts()

	if runtime.autoOpenCounterWindow == true and type(runtime.ShowCounterWindow) == "function" then
		runtime:ShowCounterWindow()
	elseif Analysis.UpdateCounterWindow ~= nil then
		Analysis.UpdateCounterWindow()
	end
	if Analysis.RefreshViewWindowIfVisible ~= nil then
		Analysis.RefreshViewWindowIfVisible()
	end
end

function Analysis.CountLocalPlayerDeath(killerName)
	if runtime.localPlayerDeathCounted == true then
		return false
	end
	runtime.localPlayerDeathCounted = true
	runtime.localPlayerWasAlive = false
	runtime.localPlayerLastHealth = 0
	local playerName = Analysis.GetLocalPlayerCounterName()
	Analysis.MarkPlayerDeathCounterName(playerName)
	Analysis.CountKill(playerName, Analysis.ResolveLocalPlayerDeathKillerName(killerName))
	return true
end

function Analysis.CountAlliedPlayerDeath(playerName, killerName)
	if not IsValidName(playerName) then
		return false
	end
	if Trim(playerName) == "player" then
		return Analysis.CountLocalPlayerDeath(killerName)
	end
	if Analysis.IsLocalPlayerName(playerName) then
		return Analysis.CountLocalPlayerDeath(killerName)
	end
	if not Analysis.IsAlliedPlayerName(playerName) then
		return false
	end

	playerName = Analysis.StripWorldSuffix(playerName)
	local key = Analysis.GetPlayerNameKey(playerName)
	if key == nil then
		return false
	end
	local now = Analysis.RefreshClock()
	local lastDeathTime = tonumber(runtime.recentPlayerDeathTimes[key])
	if lastDeathTime ~= nil and now - lastDeathTime <= Analysis.PLAYER_DEATH_DEDUPE_SECONDS then
		return false
	end
	runtime.recentPlayerDeathTimes[key] = now
	Analysis.MarkPlayerDeathCounterName(playerName)
	Analysis.CountKill(playerName, IsValidName(killerName) and Trim(killerName) or "Unknown")
	return true
end

function Analysis.TryCountLocalPlayerDeath(killerName)
	if runtime.localPlayerDeathCounted == true then
		return false
	end
	local health = Analysis.SafeUnitValue("UnitHealth", "player")
	if health == nil then
		return false
	end
	runtime.localPlayerLastHealth = health
	if health > 0 then
		runtime.localPlayerWasAlive = true
		return false
	end
	return Analysis.CountLocalPlayerDeath(killerName)
end

function Analysis.CountSnapshotKill(snapshot, mobName, killerName)
	local now = Analysis.RefreshClock()
	if snapshot ~= nil then
		if snapshot.deathCounted then
			return
		end
		snapshot.deathCounted = true
		snapshot.estimatedHealth = 0
		snapshot.lastSeenTime = now
		if IsValidName(snapshot.displayName) then
			mobName = snapshot.displayName
		end
	end

	local mobKey = snapshot ~= nil and snapshot.key or NormalizeName(mobName)
	if runtime.currentTargetKey ~= nil and runtime.currentTargetKey == mobKey then
		runtime.currentTargetDeathCounted = true
	end
	Analysis.MarkRecentNpcDeathKey(mobKey, now)
	if Analysis.RemovePendingTargetHitsByKey ~= nil then
		Analysis.RemovePendingTargetHitsByKey(mobKey)
	end
	if snapshot == nil or Analysis.IsNpcExpTarget(snapshot.unitId, mobName) then
		Analysis.RememberCombatLogTarget(mobName, killerName)
	end
end

function Analysis.FindKillerForTarget(targetName, targetKey)
	local now = Analysis.RefreshClock()
	local damage = targetKey ~= nil and runtime.recentDamageByTarget[targetKey] or nil
	if damage == nil then
		local nameKey = Analysis.BuildTargetKey(nil, targetName)
		damage = nameKey ~= nil and runtime.recentDamageByTarget[nameKey] or nil
	end
	if damage ~= nil and now - damage.time <= DAMAGE_RECENT_SECONDS then
		return damage.sourceName
	end

	if IsValidName(runtime.currentTargetTargetName) then
		return runtime.currentTargetTargetName
	end

	return Analysis.SafeUnitName("player") or "Unknown"
end

function Analysis.PruneRecentNpcDeathTimes(now)
	now = now or Analysis.RefreshClock()
	for targetKey, deathTime in pairs(runtime.recentNpcDeathTimes) do
		if now - (tonumber(deathTime) or 0) > Analysis.NPC_DEATH_EVENT_DEDUPE_SECONDS then
			runtime.recentNpcDeathTimes[targetKey] = nil
		end
	end
end

function Analysis.MarkRecentNpcDeathKey(targetKey, now)
	if not Analysis.IsUnitTargetKey(targetKey) then
		return
	end
	runtime.recentNpcDeathTimes[targetKey] = now or Analysis.RefreshClock()
end

function Analysis.WasRecentNpcDeathKeyCounted(targetKey, now)
	if not Analysis.IsUnitTargetKey(targetKey) then
		return false
	end
	now = now or Analysis.RefreshClock()
	local deathTime = tonumber(runtime.recentNpcDeathTimes[targetKey])
	return deathTime ~= nil and now - deathTime <= Analysis.NPC_DEATH_EVENT_DEDUPE_SECONDS
end

function Analysis.PruneExpKillCandidates(now)
	now = now or Analysis.RefreshClock()
	if type(runtime.expKillCandidates) ~= "table" then
		runtime.expKillCandidates = {}
		return
	end
	for index = #runtime.expKillCandidates, 1, -1 do
		local entry = runtime.expKillCandidates[index]
		if type(entry) ~= "table"
			or entry.used == true
			or now - (tonumber(entry.time) or 0) > Analysis.EXP_KILL_CANDIDATE_SECONDS
		then
			table.remove(runtime.expKillCandidates, index)
		end
	end
	while #runtime.expKillCandidates > Analysis.EXP_KILL_CANDIDATE_LIMIT do
		table.remove(runtime.expKillCandidates, 1)
	end
end

function Analysis.AddExpKillCandidate(targetName, targetKey, sourceName)
	if not IsValidName(targetName) or Analysis.IsLocalPlayerName(targetName) or Analysis.IsAlliedPlayerName(targetName) then
		return
	end
	if not Analysis.IsLocalPlayerName(sourceName) then
		return
	end
	if type(runtime.expKillCandidates) ~= "table" then
		runtime.expKillCandidates = {}
	end
	local now = Analysis.RefreshClock()
	Analysis.PruneExpKillCandidates(now)
	for _, entry in ipairs(runtime.expKillCandidates) do
		if type(entry) == "table"
			and targetKey ~= nil
			and entry.targetKey == targetKey
			and entry.used ~= true
		then
			entry.targetName = Trim(targetName)
			entry.sourceName = Trim(sourceName)
			entry.time = now
			return
		end
	end
	runtime.expKillCandidates[#runtime.expKillCandidates + 1] = {
		targetName = Trim(targetName),
		targetKey = targetKey,
		sourceName = Trim(sourceName),
		time = now,
		used = false,
	}
	Analysis.PruneExpKillCandidates(now)
end

function Analysis.TakeExpKillCandidate(now)
	now = now or Analysis.RefreshClock()
	Analysis.PruneExpKillCandidates(now)
	for index = #runtime.expKillCandidates, 1, -1 do
		local entry = runtime.expKillCandidates[index]
		if type(entry) == "table"
			and entry.used ~= true
			and IsValidName(entry.targetName)
			and now - (tonumber(entry.time) or 0) <= Analysis.EXP_KILL_CANDIDATE_SECONDS
		then
			entry.used = true
			table.remove(runtime.expKillCandidates, index)
			return entry
		end
	end
	return nil
end

local function GetTargetSnapshotByKey(targetKey)
	if targetKey == nil or targetKey == "" then
		return nil
	end

	local snapshot = runtime.targetSnapshotsByName[targetKey]
	if snapshot ~= nil and Analysis.RefreshClock() - (tonumber(snapshot.lastSeenTime) or 0) > TARGET_CACHE_SECONDS then
		runtime.targetSnapshotsByName[targetKey] = nil
		return nil
	end
	return snapshot
end

local function GetEntryAge(entry, now)
	return (now or Analysis.RefreshClock()) - (tonumber(entry.updatedTime) or tonumber(entry.capturedTime) or 0)
end

local function IsPendingEntryFresh(entry, now)
	return entry ~= nil and not entry.counted and GetEntryAge(entry, now) <= TARGET_CACHE_SECONDS
end

local function PrunePendingEntriesForKey(targetKey, now)
	local entries = runtime.pendingTargetHitsByKey[targetKey]
	if entries == nil then
		return nil
	end

	now = now or Analysis.RefreshClock()
	for index = #entries, 1, -1 do
		if not IsPendingEntryFresh(entries[index], now) then
			table.remove(entries, index)
		end
	end
	if #entries == 0 then
		runtime.pendingTargetHitsByKey[targetKey] = nil
		return nil
	end
	return entries
end

Analysis.RemovePendingTargetHitsByKey = function(targetKey)
	if targetKey == nil or targetKey == "" then
		return
	end
	runtime.pendingTargetHitsByKey[targetKey] = nil
end

local function CountPendingEntries()
	local now = Analysis.RefreshClock()
	local total = 0
	for key, entries in pairs(runtime.pendingTargetHitsByKey) do
		entries = PrunePendingEntriesForKey(key, now)
		if entries ~= nil then
			total = total + #entries
		end
	end
	return total
end

local function RemoveOldestPendingEntry()
	local oldestKey = nil
	local oldestIndex = nil
	local oldestTime = nil
	for key, entries in pairs(runtime.pendingTargetHitsByKey) do
		for index, entry in ipairs(entries) do
			local entryTime = tonumber(entry.updatedTime) or tonumber(entry.capturedTime) or 0
			if oldestTime == nil or entryTime < oldestTime then
				oldestTime = entryTime
				oldestKey = key
				oldestIndex = index
			end
		end
	end

	if oldestKey ~= nil and oldestIndex ~= nil then
		table.remove(runtime.pendingTargetHitsByKey[oldestKey], oldestIndex)
		if #runtime.pendingTargetHitsByKey[oldestKey] == 0 then
			runtime.pendingTargetHitsByKey[oldestKey] = nil
		end
	end
end

local function TrimPendingEntryTotal()
	while CountPendingEntries() > MAX_PENDING_HITS_TOTAL do
		RemoveOldestPendingEntry()
	end
end

local function MarkSnapshotCountedByKey(targetKey)
	if targetKey == nil or targetKey == "" then
		return
	end

	local now = Analysis.RefreshClock()
	local snapshot = runtime.targetSnapshotsByName[targetKey]
	if snapshot ~= nil then
		snapshot.deathCounted = true
		snapshot.estimatedHealth = 0
		snapshot.lastSeenTime = now
	end

	if runtime.currentTargetKey == targetKey then
		runtime.currentTargetDeathCounted = true
	end
end

function Analysis.CountPendingTargetKill(entry, sourceName)
	if entry == nil or entry.counted then
		return false
	end

	local now = Analysis.RefreshClock()
	entry.counted = true
	entry.remainingHealth = 0
	entry.updatedTime = now
	MarkSnapshotCountedByKey(entry.key)
	Analysis.MarkRecentNpcDeathKey(entry.key, now)
	if Analysis.RemovePendingTargetHitsByKey ~= nil then
		Analysis.RemovePendingTargetHitsByKey(entry.key)
	end
	if Analysis.IsNpcExpTarget(entry.unitId, entry.displayName) then
		Analysis.RememberCombatLogTarget(entry.displayName, sourceName)
	end
	return true
end

function Analysis.HasRecentCombatLogForExp(now)
	now = now or Analysis.RefreshClock()
	local lastLog = tonumber(runtime.lastCombatLogTime) or tonumber(runtime.lastCombatActivity)
	return lastLog ~= nil and now - lastLog <= EXP_COMBAT_LOG_TIMEOUT
end

-- EXP is the authoritative NPC kill signal. Recent local-player combat logs only
-- open a short attribution window so delayed quest/craft EXP does not count.
function Analysis.ResolveExpKillAttribution(now)
	now = now or Analysis.RefreshClock()
	local candidate = Analysis.TakeExpKillCandidate(now)
	if type(candidate) == "table" and IsValidName(candidate.targetName) then
		return candidate.targetName, candidate.sourceName, candidate.targetKey
	end
	if IsValidName(runtime.lastCombatLogMobName) then
		return runtime.lastCombatLogMobName, runtime.lastCombatLogSourceName, nil
	end
	if IsValidName(runtime.currentTargetName) then
		return runtime.currentTargetName, runtime.lastCombatLogSourceName, runtime.currentTargetKey
	end
	return "Unknown", runtime.lastCombatLogSourceName, nil
end

function Analysis.CountKillFromExpGain(amount)
	amount = math.floor((tonumber(amount) or 0) + 0.5)
	if amount <= 0 then
		return nil, false
	end
	local now = Analysis.RefreshClock()
	if not Analysis.HasRecentCombatLogForExp(now) then
		return nil, false
	end

	local mobName, sourceName, targetKey = Analysis.ResolveExpKillAttribution(now)
	if not IsValidName(mobName) then
		mobName = "Unknown"
	end
	if not IsValidName(sourceName) then
		sourceName = Analysis.GetLocalPlayerName() or "Unknown"
	end
	if targetKey ~= nil then
		MarkSnapshotCountedByKey(targetKey)
		if Analysis.RemovePendingTargetHitsByKey ~= nil then
			Analysis.RemovePendingTargetHitsByKey(targetKey)
		end
	end
	Analysis.CountKill(mobName, sourceName)
	Analysis.ApplyExpToRecentKill(amount)
	return mobName, true
end

function Analysis.PrunePendingTargetHits()
	local now = Analysis.RefreshClock()
	for key in pairs(runtime.pendingTargetHitsByKey) do
		PrunePendingEntriesForKey(key, now)
	end
end

local function CapturePendingTargetHit(snapshot, reason)
	if snapshot == nil or snapshot.key == nil or not IsValidName(snapshot.displayName) then
		return nil
	end

	local now = Analysis.RefreshClock()
	local health = tonumber(snapshot.lastObservedHealth) or tonumber(snapshot.estimatedHealth)
	local maxHealth = tonumber(snapshot.maxHealth)
	if health == nil or maxHealth == nil or maxHealth <= 0 or health <= 0 then
		return nil
	end
	local wasDamaged = health < maxHealth
	if not wasDamaged and not FULL_HEALTH_CAPTURE_REASONS[reason] then
		return nil
	end

	local entries = PrunePendingEntriesForKey(snapshot.key, now)
	if entries == nil then
		entries = {}
		runtime.pendingTargetHitsByKey[snapshot.key] = entries
	end

	for _, entry in ipairs(entries) do
		if not entry.counted
			and tonumber(entry.remainingHealth) == health
			and now - (tonumber(entry.capturedTime) or 0) <= PENDING_CAPTURE_DEDUPE_SECONDS
		then
			entry.displayName = snapshot.displayName
			entry.maxHealth = maxHealth
			entry.updatedTime = now
			entry.captureReason = reason
			entry.projectileCandidate = entry.projectileCandidate or PROJECTILE_CAPTURE_REASONS[reason] or false
			return entry
		end
	end

	local entry = {
		displayName = snapshot.displayName,
		key = snapshot.key,
		remainingHealth = health,
		maxHealth = maxHealth,
		capturedTime = now,
		updatedTime = now,
		counted = false,
		captureReason = reason,
		projectileCandidate = PROJECTILE_CAPTURE_REASONS[reason] or false,
		expectedSourceName = Analysis.SafeUnitName("player"),
	}
	table.insert(entries, 1, entry)
	while #entries > MAX_PENDING_HITS_PER_TARGET do
		table.remove(entries)
	end
	TrimPendingEntryTotal()
	return entry
end

function Analysis.CaptureCurrentTarget(reason)
	if runtime.currentTargetKey == nil then
		return nil
	end

	return CapturePendingTargetHit(GetTargetSnapshotByKey(runtime.currentTargetKey), reason)
end

function Analysis.MarkPendingTargetSwitched(targetKey)
	if targetKey == nil or targetKey == "" then
		return
	end

	local now = Analysis.RefreshClock()
	local entries = PrunePendingEntriesForKey(targetKey, now)
	if entries == nil then
		return
	end

	for _, entry in ipairs(entries) do
		if not entry.counted then
			entry.switchedAway = true
			entry.targetSwitchedTime = now
			entry.updatedTime = now
			entry.projectileCandidate = true
		end
	end
end

local function UpdateTargetSnapshot(targetName, health, maxHealth, targetTargetName, targetUnitId)
	if type(targetName) ~= "string" or health == nil then
		return nil
	end

	local displayName = Trim(targetName)
	if displayName == "" then
		return nil
	end

	targetUnitId = Analysis.NormalizeUnitId(targetUnitId)
	local key = Analysis.BuildTargetKey(targetUnitId, displayName)
	if key == nil then
		return nil
	end
	local now = Analysis.RefreshClock()
	local snapshot = runtime.targetSnapshotsByName[key]
	local expired = snapshot ~= nil and now - (tonumber(snapshot.lastSeenTime) or 0) > TARGET_CACHE_SECONDS
	if snapshot == nil or expired or (health > 0 and snapshot.deathCounted) then
		snapshot = {
			key = key,
		}
		runtime.targetSnapshotsByName[key] = snapshot
	end

	snapshot.key = key
	snapshot.unitId = targetUnitId
	snapshot.displayName = displayName
	snapshot.lastObservedHealth = health
	snapshot.maxHealth = maxHealth
	snapshot.lastTargetTargetName = targetTargetName
	snapshot.lastSeenTime = now

	if health > 0 then
		snapshot.estimatedHealth = health
		snapshot.deathCounted = false
	elseif snapshot.estimatedHealth == nil or snapshot.estimatedHealth > health then
		snapshot.estimatedHealth = health
	end

	return snapshot
end

function Analysis.PruneTargetSnapshots()
	local now = Analysis.RefreshClock()
	for key, snapshot in pairs(runtime.targetSnapshotsByName) do
		if now - (tonumber(snapshot.lastSeenTime) or 0) > TARGET_CACHE_SECONDS then
			runtime.targetSnapshotsByName[key] = nil
		end
	end
end

function Analysis.UpdateCurrentTarget(suppressDirectCount)
	local targetName = Analysis.SafeUnitName("target")
	local targetUnitId = Analysis.GetCurrentTargetUnitId()
	local targetKey = nil
	if targetName ~= nil then
		targetKey = Analysis.BuildTargetKey(targetUnitId, targetName)
	end
	local targetTargetName = Analysis.SafeUnitName("targettarget")
	local health = Analysis.SafeUnitValue("UnitHealth", "target")
	local maxHealth = Analysis.SafeUnitValue("UnitMaxHealth", "target")
	local snapshot = UpdateTargetSnapshot(targetName, health, maxHealth, targetTargetName, targetUnitId)
	CapturePendingTargetHit(snapshot, "target_poll")

	if targetKey ~= runtime.currentTargetKey then
		runtime.currentTargetName = targetName
		runtime.currentTargetKey = targetKey
		runtime.currentTargetTargetName = targetTargetName
		runtime.currentTargetWasAlive = health == nil or health > 0
		runtime.currentTargetDeathCounted = snapshot ~= nil and snapshot.deathCounted or false
		return
	end

	runtime.currentTargetTargetName = targetTargetName

	if targetName == nil then
		runtime.currentTargetKey = nil
		runtime.currentTargetWasAlive = false
		runtime.currentTargetDeathCounted = false
		return
	end

	if health ~= nil and health > 0 then
		runtime.currentTargetWasAlive = true
		runtime.currentTargetDeathCounted = false
	elseif health ~= nil and health <= 0 and runtime.currentTargetWasAlive and not runtime.currentTargetDeathCounted then
		if suppressDirectCount then
			return
		end
		runtime.currentTargetDeathCounted = true
		Analysis.CountSnapshotKill(snapshot, targetName, Analysis.FindKillerForTarget(targetName, targetKey))
	end
end

local function IsDamageCombatEvent(eventType)
	return type(eventType) == "string" and string.find(eventType, "DAMAGE", 1, true) ~= nil
end

function Analysis.IsCombatDeathEvent(eventType)
	eventType = tostring(eventType or "")
	return string.find(eventType, "DEAD", 1, true) ~= nil or string.find(eventType, "DIED", 1, true) ~= nil
end

local function NormalizeDamageAmount(value)
	local amount = tonumber(value)
	if amount == nil then
		return nil
	end
	amount = math.abs(amount)
	if amount <= 0 then
		return nil
	end
	return amount
end

function Analysis.GetCombatDamageAmount(eventType, abilityId, effectType)
	if not IsDamageCombatEvent(eventType) then
		return nil
	end

	if type(eventType) == "string" and string.find(eventType, "MELEE_DAMAGE", 1, true) ~= nil then
		return NormalizeDamageAmount(abilityId) or NormalizeDamageAmount(effectType)
	end
	return NormalizeDamageAmount(effectType) or NormalizeDamageAmount(abilityId)
end

local function GetSnapshotRemainingHealth(snapshot)
	if snapshot == nil then
		return nil
	end

	local estimatedHealth = tonumber(snapshot.estimatedHealth)
	local observedHealth = tonumber(snapshot.lastObservedHealth)
	if observedHealth ~= nil and observedHealth > 0 then
		if estimatedHealth == nil or estimatedHealth <= 0 or observedHealth < estimatedHealth then
			return observedHealth
		end
	end
	return estimatedHealth
end

local function GetPendingDamageMatchScore(entry, sourceName, now)
	if entry == nil then
		return nil
	end

	local capturedTime = tonumber(entry.capturedTime) or 0
	if now < capturedTime then
		return nil
	end

	local score = capturedTime
	local switchedTime = tonumber(entry.targetSwitchedTime)
	if entry.switchedAway and switchedTime ~= nil and now >= switchedTime then
		score = score + 100000
	end
	if entry.projectileCandidate then
		score = score + 50000
	end
	if entry.captureReason == "SPELLCAST_SUCCEEDED" then
		score = score + 12000
	elseif entry.captureReason == "SPELLCAST_START" then
		score = score + 11000
	elseif entry.captureReason == "target_switch" then
		score = score + 10000
	elseif entry.captureReason == "target_poll" then
		score = score + 1000
	end
	if NamesMatch(sourceName, entry.expectedSourceName) then
		score = score + 5000
	end
	return score
end

local function TryCountPendingDamage(targetName, targetKey, sourceName, damageAmount)
	local damage = NormalizeDamageAmount(damageAmount)
	if damage == nil then
		return false
	end

	local now = Analysis.RefreshClock()
	local snapshot = GetTargetSnapshotByKey(targetKey)
	if snapshot ~= nil and snapshot.deathCounted then
		return true
	end

	local entries = PrunePendingEntriesForKey(targetKey, now)
	if entries == nil then
		return false
	end

	local bestLethalEntry = nil
	local bestLethalScore = nil
	local bestDamageEntry = nil
	local bestDamageScore = nil
	for _, entry in ipairs(entries) do
		if IsPendingEntryFresh(entry, now) then
			local remainingHealth = tonumber(entry.remainingHealth)
			if remainingHealth ~= nil and remainingHealth > 0 then
				local score = GetPendingDamageMatchScore(entry, sourceName, now)
				if score ~= nil then
					if damage >= remainingHealth then
						if bestLethalScore == nil or score > bestLethalScore then
							bestLethalEntry = entry
							bestLethalScore = score
						end
					elseif bestDamageScore == nil or score > bestDamageScore then
						bestDamageEntry = entry
						bestDamageScore = score
					end
				end
			end
		end
	end

	if bestLethalEntry ~= nil then
		return Analysis.CountPendingTargetKill(bestLethalEntry, sourceName)
	end

	if bestDamageEntry == nil then
		return false
	end

	bestDamageEntry.remainingHealth = (tonumber(bestDamageEntry.remainingHealth) or 0) - damage
	bestDamageEntry.updatedTime = now
	if bestDamageEntry.remainingHealth <= 0 then
		return Analysis.CountPendingTargetKill(bestDamageEntry, sourceName)
	end
	return true
end

local function ApplyDamageToSnapshot(snapshot, mobName, sourceName, damage)
	if snapshot == nil or snapshot.deathCounted then
		return false
	end

	local remainingHealth = GetSnapshotRemainingHealth(snapshot)
	if remainingHealth == nil or remainingHealth <= 0 then
		return false
	end

	local now = Analysis.RefreshClock()
	snapshot.estimatedHealth = remainingHealth - damage
	snapshot.lastSeenTime = now
	if damage >= remainingHealth or snapshot.estimatedHealth <= 0 then
		Analysis.CountSnapshotKill(snapshot, mobName, sourceName)
		return true
	end
	return false
end

function Analysis.TryCountLethalDamage(targetName, targetKey, sourceName, damageAmount)
	local damage = NormalizeDamageAmount(damageAmount)
	if damage == nil then
		return
	end

	if TryCountPendingDamage(targetName, targetKey, sourceName, damage) then
		return
	end

	local snapshot = GetTargetSnapshotByKey(targetKey)
	if ApplyDamageToSnapshot(snapshot, targetName, sourceName, damage) then
		return
	end
end

function Analysis.GetRecentDamageRecord(targetKey, targetName, now)
	now = now or Analysis.RefreshClock()
	local damage = targetKey ~= nil and runtime.recentDamageByTarget[targetKey] or nil
	if damage ~= nil and now - (tonumber(damage.time) or 0) <= DAMAGE_RECENT_SECONDS then
		return damage
	end
	local nameKey = Analysis.BuildTargetKey(nil, targetName)
	if nameKey ~= nil and nameKey ~= targetKey then
		damage = runtime.recentDamageByTarget[nameKey]
		if damage ~= nil and now - (tonumber(damage.time) or 0) <= DAMAGE_RECENT_SECONDS then
			return damage
		end
	end
	return nil
end

function Analysis.ShouldCountNpcDeathEvent(msg, targetKey, now)
	if type(msg) ~= "table" or not IsValidName(msg.targetName) then
		return false
	end
	if Analysis.IsLocalPlayerName(msg.targetName) or Analysis.IsAlliedPlayerName(msg.targetName) then
		return false
	end
	if Analysis.IsLocalPlayerName(msg.sourceName) then
		return true
	end
	local damage = Analysis.GetRecentDamageRecord(targetKey, msg.targetName, now)
	return damage ~= nil and Analysis.IsLocalPlayerName(damage.sourceName)
end

-- NPC death combat messages improve attribution only; EXP_CHANGED is the kill-count signal.
function Analysis.CountNpcDeathFromCombatEvent(msg)
	local now = Analysis.RefreshClock()
	local targetKey = Analysis.BuildTargetKey(msg and msg.unitId, msg and msg.targetName)
	if targetKey == nil
		or not Analysis.IsNpcExpTarget(msg and msg.unitId, msg and msg.targetName)
		or not Analysis.ShouldCountNpcDeathEvent(msg, targetKey, now)
	then
		return false
	end
	MarkSnapshotCountedByKey(targetKey)
	Analysis.TouchCombatLogActivity(msg.targetName, msg.sourceName, now)
	return true
end

function Analysis.ClearKillCounts()
	runtime.killCounts = {}
	runtime.killerCounts = {}
	runtime.playerDeathCounterNames = {}
	runtime.recentPlayerDeathTimes = {}
	runtime.lastKill = nil
	runtime.currentPage = 1
	runtime.recentDamageByTarget = {}
	runtime.targetSnapshotsByName = {}
	runtime.pendingTargetHitsByKey = {}
	runtime.recentNpcDeathTimes = {}
	runtime.expKillCandidates = {}
	runtime.currentTargetKey = nil
	runtime.currentTargetDeathCounted = false
	Analysis.ClearSessionStats()
	Analysis.SaveKillCounts()
	if Analysis.UpdateCounterWindow ~= nil then
		Analysis.UpdateCounterWindow()
	end
end

