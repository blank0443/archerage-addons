if API_TYPE == nil then
	return
end

ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)

ADDON:ImportAPI(API_TYPE.UNIT.id)

local SAVE_KEY = "lootKillCounterKills"
local WINDOW_POSITION_KEY = "lootKillCounterWindowPosition"
local WINDOW_SIZE_KEY = "lootKillCounterWindowSize"
local WINDOW_WIDTH = 286
local WINDOW_HEIGHT = 272
local MIN_WINDOW_WIDTH = 230
local MIN_WINDOW_HEIGHT = 250
local PADDING = 10
local ROW_TOP = 48
local ROW_HEIGHT = 20
local PAGE_SIZE = 8
local CORNER_HANDLE_SIZE = 18
local RESIZE_GRIP_LINE_ALPHA = 0
local RESIZE_GRIP_HOVER_ALPHA = 0.65
local RESIZE_GRIP_LINE_LENGTH = 9
local RESIZE_GRIP_LINE_THICKNESS = 2
local RESIZE_GRIP_INSET = 5
local MIN_WINDOW_SCALE = 0.85
local MAX_WINDOW_SCALE = 1.35
local DAMAGE_RECENT_SECONDS = 20
local TARGET_CACHE_SECONDS = 12
local PENDING_CAPTURE_DEDUPE_SECONDS = 0.35
local MAX_PENDING_HITS_PER_TARGET = 4
local MAX_PENDING_HITS_TOTAL = 20
local PROJECTILE_CAPTURE_REASONS = {
	SPELLCAST_START = true,
	SPELLCAST_SUCCEEDED = true,
	target_switch = true,
}
local FULL_HEALTH_CAPTURE_REASONS = {
	SPELLCAST_START = true,
	SPELLCAST_SUCCEEDED = true,
	target_switch = true,
}

local previousRuntime = _G.__LOOT_KILL_COUNTER_RUNTIME
if previousRuntime ~= nil then
	previousRuntime.active = false
	if previousRuntime.eventWindow ~= nil then
		previousRuntime.eventWindow:Show(false)
	end
	if previousRuntime.counterWindow ~= nil then
		previousRuntime.counterWindow:Show(false)
	end
	if previousRuntime.launchButton ~= nil then
		previousRuntime.launchButton:Show(false)
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
	recentDamageByTarget = {},
	targetSnapshotsByName = {},
	pendingTargetHitsByKey = {},
	currentTargetName = nil,
	currentTargetKey = nil,
	currentTargetHealth = nil,
	currentTargetMaxHealth = nil,
	currentTargetTargetName = nil,
	currentTargetWasAlive = false,
	currentTargetDeathCounted = false,
	lastKill = nil,
	rows = {},
	resizeHandles = {},
}
_G.__LOOT_KILL_COUNTER_RUNTIME = runtime

local function Now()
	if os ~= nil and type(os.clock) == "function" then
		local ok, value = pcall(os.clock)
		if ok and tonumber(value) ~= nil then
			return tonumber(value)
		end
	end
	return tonumber(runtime.clock) or 0
end

local function RefreshClock()
	local now = Now()
	if runtime.clock == nil or now > runtime.clock then
		runtime.clock = now
	end
	return runtime.clock
end

local function SafeCall(target, methodName, ...)
	if target == nil or type(target[methodName]) ~= "function" then
		return false, nil
	end
	return pcall(target[methodName], target, ...)
end

local function Trim(value)
	local text = tostring(value or "")
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	return text
end

local function NormalizeName(value)
	local text = string.lower(Trim(value))
	text = string.gsub(text, "%s+", " ")
	return text
end

local function NormalizeTrimmedName(value)
	local text = string.lower(value)
	text = string.gsub(text, "%s+", " ")
	return text
end

local function IsValidName(value)
	return type(value) == "string" and Trim(value) ~= ""
end

local function NamesMatch(left, right)
	if not IsValidName(left) or not IsValidName(right) then
		return false
	end
	return NormalizeName(left) == NormalizeName(right)
end

local function NormalizeDt(dt)
	local value = tonumber(dt) or 0
	if value > 10 then
		value = value / 1000
	end
	return value
end

local function SafeUnitName(unit)
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

local function SafeUnitValue(methodName, unit)
	local ok, value = SafeCall(X2Unit, methodName, unit)
	if not ok then
		return nil
	end
	if type(value) == "table" then
		value = value.current or value.health or value.hp or value.value or value[1]
	end
	return tonumber(value)
end

local function SaveData(key, value)
	pcall(function()
		ADDON:ClearData(key)
		ADDON:SaveData(key, value)
	end)
end

local function LoadData(key)
	local ok, data = pcall(function()
		return ADDON:LoadData(key)
	end)
	if ok then
		return data
	end
	return nil
end

local function GetWidgetPosition(widget)
	if widget == nil then
		return nil, nil
	end
	local ok, offsetX, offsetY = pcall(function()
		return widget:GetOffset()
	end)
	if not ok then
		return nil, nil
	end
	local uiScale = 1.0
	local okScale, scale = pcall(function()
		return UIParent:GetUIScale()
	end)
	if okScale and tonumber(scale) ~= nil then
		uiScale = tonumber(scale)
	end
	return math.floor((offsetX * uiScale) + 0.5), math.floor((offsetY * uiScale) + 0.5)
end

local function SaveWidgetPosition(widget, key)
	local x, y = GetWidgetPosition(widget)
	if x == nil or y == nil then
		return
	end
	SaveData(key, { x = x, y = y })
end

local function LoadPosition(key, defaultX, defaultY)
	local data = LoadData(key)
	if type(data) == "table" and data.x ~= nil and data.y ~= nil then
		return tonumber(data.x) or defaultX, tonumber(data.y) or defaultY
	end
	return defaultX, defaultY
end

local function ClampWindowSize(width, height)
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

local function ClampWindowScale(scale)
	scale = tonumber(scale) or 1
	if scale < MIN_WINDOW_SCALE then
		return MIN_WINDOW_SCALE
	end
	if scale > MAX_WINDOW_SCALE then
		return MAX_WINDOW_SCALE
	end
	return scale
end

local function SetWidgetFontSize(widget, size)
	if widget ~= nil and widget.style ~= nil and type(widget.style.SetFontSize) == "function" then
		widget.style:SetFontSize(size)
	end
end

local function LoadWindowSize()
	local data = LoadData(WINDOW_SIZE_KEY)
	if type(data) == "table" then
		return ClampWindowSize(data.width, data.height)
	end
	return WINDOW_WIDTH, WINDOW_HEIGHT
end

local function AnchorWidgetAtPosition(widget, x, y)
	if widget == nil then
		return
	end
	SafeCall(widget, "RemoveAllAnchors")
	widget:AddAnchor("TOPLEFT", "UIParent", math.floor((tonumber(x) or 0) + 0.5), math.floor((tonumber(y) or 0) + 0.5))
end

local function LoadKillCounts()
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

	if type(data.lastKill) == "table" then
		runtime.lastKill = data.lastKill
	end
end

local function SaveKillCounts()
	SaveData(SAVE_KEY, {
		kills = runtime.killCounts,
		killerCounts = runtime.killerCounts,
		lastKill = runtime.lastKill,
	})
end

local function GetTotalKillCount()
	local total = 0
	for _, count in pairs(runtime.killCounts) do
		count = tonumber(count)
		if count ~= nil and count > 0 then
			total = total + math.floor(count)
		end
	end
	return total
end

local function BuildSortedMobNames()
	local names = {}
	for mobName, count in pairs(runtime.killCounts) do
		if tonumber(count) ~= nil and tonumber(count) > 0 then
			names[#names + 1] = mobName
		end
	end
	table.sort(names, function(left, right)
		local leftCount = runtime.killCounts[left] or 0
		local rightCount = runtime.killCounts[right] or 0
		if leftCount ~= rightCount then
			return leftCount > rightCount
		end
		return string.lower(left) < string.lower(right)
	end)
	return names
end

local function GetTotalPages(totalRows)
	local pages = math.ceil(totalRows / PAGE_SIZE)
	if pages < 1 then
		return 1
	end
	return pages
end

local function ClampCurrentPage(totalRows)
	local totalPages = GetTotalPages(totalRows)
	if runtime.currentPage < 1 then
		runtime.currentPage = 1
	elseif runtime.currentPage > totalPages then
		runtime.currentPage = totalPages
	end
	return totalPages
end

local UpdateCounterWindow
local RemovePendingTargetHitsByKey

local function CountKill(mobName, killerName)
	if not IsValidName(mobName) then
		return
	end

	mobName = Trim(mobName)
	if not IsValidName(killerName) then
		killerName = "Unknown"
	else
		killerName = Trim(killerName)
	end

	runtime.killCounts[mobName] = (tonumber(runtime.killCounts[mobName]) or 0) + 1
	if runtime.killerCounts[mobName] == nil then
		runtime.killerCounts[mobName] = {}
	end
	runtime.killerCounts[mobName][killerName] = (tonumber(runtime.killerCounts[mobName][killerName]) or 0) + 1
	runtime.lastKill = {
		mobName = mobName,
		killerName = killerName,
		count = runtime.killCounts[mobName],
	}
	SaveKillCounts()

	if UpdateCounterWindow ~= nil then
		UpdateCounterWindow()
	end
end

local function CountSnapshotKill(snapshot, mobName, killerName)
	local now = RefreshClock()
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
	if RemovePendingTargetHitsByKey ~= nil then
		RemovePendingTargetHitsByKey(mobKey)
	end

	CountKill(mobName, killerName)
end

local function FindKillerForTarget(targetName)
	local now = RefreshClock()
	local targetKey = NormalizeName(targetName)
	local damage = runtime.recentDamageByTarget[targetKey]
	if damage ~= nil and now - damage.time <= DAMAGE_RECENT_SECONDS then
		return damage.sourceName
	end

	if IsValidName(runtime.currentTargetTargetName) then
		return runtime.currentTargetTargetName
	end

	return SafeUnitName("player") or "Unknown"
end

local function GetTargetSnapshotByKey(targetKey)
	if targetKey == nil or targetKey == "" then
		return nil
	end

	local snapshot = runtime.targetSnapshotsByName[targetKey]
	if snapshot ~= nil and RefreshClock() - (tonumber(snapshot.lastSeenTime) or 0) > TARGET_CACHE_SECONDS then
		runtime.targetSnapshotsByName[targetKey] = nil
		return nil
	end
	return snapshot
end

local function GetEntryAge(entry, now)
	return (now or RefreshClock()) - (tonumber(entry.updatedTime) or tonumber(entry.capturedTime) or 0)
end

local function IsPendingEntryFresh(entry, now)
	return entry ~= nil and not entry.counted and GetEntryAge(entry, now) <= TARGET_CACHE_SECONDS
end

local function PrunePendingEntriesForKey(targetKey, now)
	local entries = runtime.pendingTargetHitsByKey[targetKey]
	if entries == nil then
		return nil
	end

	now = now or RefreshClock()
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

RemovePendingTargetHitsByKey = function(targetKey)
	if targetKey == nil or targetKey == "" then
		return
	end
	runtime.pendingTargetHitsByKey[targetKey] = nil
end

local function CountPendingEntries()
	local now = RefreshClock()
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

	local now = RefreshClock()
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

local function CountPendingTargetKill(entry, sourceName)
	if entry == nil or entry.counted then
		return false
	end

	local now = RefreshClock()
	entry.counted = true
	entry.remainingHealth = 0
	entry.updatedTime = now
	MarkSnapshotCountedByKey(entry.key)
	if RemovePendingTargetHitsByKey ~= nil then
		RemovePendingTargetHitsByKey(entry.key)
	end
	CountKill(entry.displayName, sourceName)
	return true
end

local function PrunePendingTargetHits()
	local now = RefreshClock()
	for key in pairs(runtime.pendingTargetHitsByKey) do
		PrunePendingEntriesForKey(key, now)
	end
end

local function CapturePendingTargetHit(snapshot, reason)
	if snapshot == nil or snapshot.key == nil or not IsValidName(snapshot.displayName) then
		return nil
	end

	local now = RefreshClock()
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
			entry.wasDamagedWhenCaptured = entry.wasDamagedWhenCaptured or wasDamaged
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
		wasDamagedWhenCaptured = wasDamaged,
		expectedSourceName = SafeUnitName("player"),
	}
	table.insert(entries, 1, entry)
	while #entries > MAX_PENDING_HITS_PER_TARGET do
		table.remove(entries)
	end
	TrimPendingEntryTotal()
	return entry
end

local function CaptureCurrentTarget(reason)
	if runtime.currentTargetKey == nil then
		return nil
	end

	return CapturePendingTargetHit(GetTargetSnapshotByKey(runtime.currentTargetKey), reason)
end

local function MarkPendingTargetSwitched(targetKey)
	if targetKey == nil or targetKey == "" then
		return
	end

	local now = RefreshClock()
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

local function UpdateTargetSnapshot(targetName, health, maxHealth, targetTargetName)
	if type(targetName) ~= "string" or health == nil then
		return nil
	end

	local displayName = Trim(targetName)
	if displayName == "" then
		return nil
	end

	local key = NormalizeTrimmedName(displayName)
	local now = RefreshClock()
	local snapshot = runtime.targetSnapshotsByName[key]
	local expired = snapshot ~= nil and now - (tonumber(snapshot.lastSeenTime) or 0) > TARGET_CACHE_SECONDS
	if snapshot == nil or expired or (health > 0 and snapshot.deathCounted) then
		snapshot = {
			key = key,
		}
		runtime.targetSnapshotsByName[key] = snapshot
	end

	snapshot.key = key
	snapshot.displayName = displayName
	snapshot.lastObservedHealth = health
	snapshot.maxHealth = maxHealth
	snapshot.lastTargetTargetName = targetTargetName
	snapshot.lastSeenTime = now
	snapshot.wasDamagedWhenSelected = maxHealth ~= nil and maxHealth > 0 and health > 0 and health < maxHealth

	if health > 0 then
		snapshot.estimatedHealth = health
		snapshot.deathCounted = false
	elseif snapshot.estimatedHealth == nil or snapshot.estimatedHealth > health then
		snapshot.estimatedHealth = health
	end

	return snapshot
end

local function PruneTargetSnapshots()
	local now = RefreshClock()
	for key, snapshot in pairs(runtime.targetSnapshotsByName) do
		if now - (tonumber(snapshot.lastSeenTime) or 0) > TARGET_CACHE_SECONDS then
			runtime.targetSnapshotsByName[key] = nil
		end
	end
end

local function UpdateCurrentTarget(suppressDirectCount)
	local targetName = SafeUnitName("target")
	local targetKey = nil
	if targetName ~= nil then
		targetKey = NormalizeTrimmedName(targetName)
	end
	local targetTargetName = SafeUnitName("targettarget")
	local health = SafeUnitValue("UnitHealth", "target")
	local maxHealth = SafeUnitValue("UnitMaxHealth", "target")
	local snapshot = UpdateTargetSnapshot(targetName, health, maxHealth, targetTargetName)
	CapturePendingTargetHit(snapshot, "target_poll")

	if targetKey ~= runtime.currentTargetKey then
		runtime.currentTargetName = targetName
		runtime.currentTargetKey = targetKey
		runtime.currentTargetHealth = health
		runtime.currentTargetMaxHealth = maxHealth
		runtime.currentTargetTargetName = targetTargetName
		runtime.currentTargetWasAlive = health == nil or health > 0
		runtime.currentTargetDeathCounted = snapshot ~= nil and snapshot.deathCounted or false
		return
	end

	runtime.currentTargetHealth = health
	runtime.currentTargetMaxHealth = maxHealth
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
		CountSnapshotKill(snapshot, targetName, FindKillerForTarget(targetName))
	end
end

local function IsDamageCombatEvent(eventType)
	return type(eventType) == "string" and string.find(eventType, "DAMAGE", 1, true) ~= nil
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

local function GetCombatDamageAmount(eventType, abilityId, effectType)
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

	local now = RefreshClock()
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
		return CountPendingTargetKill(bestLethalEntry, sourceName)
	end

	if bestDamageEntry == nil then
		return false
	end

	bestDamageEntry.remainingHealth = (tonumber(bestDamageEntry.remainingHealth) or 0) - damage
	bestDamageEntry.updatedTime = now
	if bestDamageEntry.remainingHealth <= 0 then
		return CountPendingTargetKill(bestDamageEntry, sourceName)
	end
	return true
end

local function ApplyDamageToSnapshot(snapshot, mobName, sourceName, damage, requireDamagedSelection)
	if snapshot == nil or snapshot.deathCounted then
		return false
	end
	if requireDamagedSelection and not snapshot.wasDamagedWhenSelected then
		return false
	end

	local remainingHealth = GetSnapshotRemainingHealth(snapshot)
	if remainingHealth == nil or remainingHealth <= 0 then
		return false
	end

	local now = RefreshClock()
	snapshot.estimatedHealth = remainingHealth - damage
	snapshot.lastSeenTime = now
	if damage >= remainingHealth or snapshot.estimatedHealth <= 0 then
		CountSnapshotKill(snapshot, mobName, sourceName)
		return true
	end
	return false
end

local function TryCountLethalDamage(targetName, targetKey, sourceName, damageAmount)
	local damage = NormalizeDamageAmount(damageAmount)
	if damage == nil then
		return
	end

	if TryCountPendingDamage(targetName, targetKey, sourceName, damage) then
		return
	end

	local snapshot = GetTargetSnapshotByKey(targetKey)
	if ApplyDamageToSnapshot(snapshot, targetName, sourceName, damage, false) then
		return
	end
end

local function HandleCombatMessage(...)
	local now = RefreshClock()
	local eventType = select(2, ...)
	local sourceName = Trim(select(3, ...))
	local targetName = Trim(select(4, ...))
	local damageAmount = GetCombatDamageAmount(eventType, select(5, ...), select(8, ...))
	if sourceName == "" or targetName == "" then
		return
	end
	if damageAmount == nil then
		return
	end

	local targetKey = NormalizeTrimmedName(targetName)
	runtime.recentDamageByTarget[targetKey] = {
		sourceName = sourceName,
		targetName = targetName,
		eventType = eventType,
		amount = damageAmount,
		time = now,
	}
	TryCountLethalDamage(targetName, targetKey, sourceName, damageAmount)
end

local function IsPlayerSpellcast(...)
	local argCount = select("#", ...)
	for index = 1, argCount do
		if select(index, ...) == "player" then
			return true
		end
	end
	return false
end

local function HandleSpellcastEvent(event, ...)
	if not IsPlayerSpellcast(...) then
		return
	end
	UpdateCurrentTarget(true)
	CaptureCurrentTarget(event)
end

local function ClearKillCounts()
	runtime.killCounts = {}
	runtime.killerCounts = {}
	runtime.lastKill = nil
	runtime.currentPage = 1
	runtime.recentDamageByTarget = {}
	runtime.targetSnapshotsByName = {}
	runtime.pendingTargetHitsByKey = {}
	runtime.currentTargetKey = nil
	runtime.currentTargetDeathCounted = false
	SaveKillCounts()
	if UpdateCounterWindow ~= nil then
		UpdateCounterWindow()
	end
end

LoadKillCounts()

local windowX, windowY = LoadPosition(WINDOW_POSITION_KEY, 420, 318)
local windowWidth, windowHeight = LoadWindowSize()
local counterWindow = CreateEmptyWindow("lootKillCounterWindow", "UIParent")
runtime.counterWindow = counterWindow
counterWindow:SetExtent(windowWidth, windowHeight)
counterWindow:AddAnchor("TOPLEFT", "UIParent", windowX, windowY)
counterWindow:EnableDrag(true)
counterWindow:Clickable(true)
counterWindow:Show(false)

local background = counterWindow:CreateColorDrawable(0, 0, 0, 0.68, "background")
background:AddAnchor("TOPLEFT", counterWindow, 0, 0)
background:AddAnchor("BOTTOMRIGHT", counterWindow, 0, 0)

local titleLabel = counterWindow:CreateChildWidget("label", "lootKillCounterTitle", 0, true)
titleLabel:SetText("Kill Counter: 0")
titleLabel:SetExtent(220, 24)
titleLabel.style:SetAlign(ALIGN_LEFT)
titleLabel.style:SetFontSize(13)
titleLabel.style:SetColor(0.95, 0.92, 0.82, 1)
titleLabel.style:SetOutline(true)
titleLabel:AddAnchor("TOPLEFT", counterWindow, PADDING, 10)
SafeCall(titleLabel, "EnableDrag", true)

local closeButton = counterWindow:CreateChildWidget("button", "lootKillCounterCloseButton", 0, true)
closeButton:SetStyle("text_default")
closeButton:SetText("X")
closeButton:SetExtent(32, 20)
closeButton:AddAnchor("TOPRIGHT", counterWindow, -PADDING, 9)

local statusLabel = counterWindow:CreateChildWidget("label", "lootKillCounterStatus", 0, true)
statusLabel:SetText("")
statusLabel:SetExtent(WINDOW_WIDTH - (PADDING * 2), 20)
statusLabel.style:SetAlign(ALIGN_LEFT)
statusLabel.style:SetFontSize(10)
statusLabel.style:SetColor(0.78, 0.84, 0.92, 1)
statusLabel.style:SetOutline(true)
statusLabel:AddAnchor("TOPLEFT", counterWindow, PADDING, 30)

for index = 1, PAGE_SIZE do
	local row = counterWindow:CreateChildWidget("label", "lootKillCounterRow" .. tostring(index), 0, true)
	row:SetText("")
	row:SetExtent(WINDOW_WIDTH - (PADDING * 2), ROW_HEIGHT)
	row.style:SetAlign(ALIGN_LEFT)
	row.style:SetFontSize(12)
	row.style:SetColor(1, 1, 1, 1)
	row.style:SetOutline(true)
	row:AddAnchor("TOPLEFT", counterWindow, PADDING, ROW_TOP + ((index - 1) * ROW_HEIGHT))
	runtime.rows[index] = row
end

local clearButton = counterWindow:CreateChildWidget("button", "lootKillCounterClearButton", 0, true)
clearButton:SetStyle("text_default")
clearButton:SetText("Clear")
clearButton:SetExtent(70, 22)
clearButton:AddAnchor("BOTTOMLEFT", counterWindow, PADDING, -PADDING)

local prevButton = counterWindow:CreateChildWidget("button", "lootKillCounterPrevButton", 0, true)
prevButton:SetStyle("text_default")
prevButton:SetText("Prev")
prevButton:SetExtent(56, 22)
prevButton:AddAnchor("BOTTOMRIGHT", counterWindow, -122, -PADDING)

local nextButton = counterWindow:CreateChildWidget("button", "lootKillCounterNextButton", 0, true)
nextButton:SetStyle("text_default")
nextButton:SetText("Next")
nextButton:SetExtent(56, 22)
nextButton:AddAnchor("BOTTOMRIGHT", counterWindow, -PADDING, -PADDING)

local pageLabel = counterWindow:CreateChildWidget("label", "lootKillCounterPageLabel", 0, true)
pageLabel:SetText("")
pageLabel:SetExtent(58, 20)
pageLabel.style:SetAlign(ALIGN_CENTER)
pageLabel.style:SetFontSize(10)
pageLabel.style:SetColor(0.84, 0.84, 0.84, 1)
pageLabel.style:SetOutline(true)
pageLabel:AddAnchor("BOTTOMRIGHT", counterWindow, -67, -PADDING - 1)

local PositionCounterResizeHandles
local ShowCounterWindowButtons
local ApplyResizeGripVisualScale

local function GetCounterWindowScale()
	local widthScale = counterWindow:GetWidth() / WINDOW_WIDTH
	local heightScale = counterWindow:GetHeight() / WINDOW_HEIGHT
	local scale = widthScale
	if heightScale < scale then
		scale = heightScale
	end
	return ClampWindowScale(scale)
end

local function ApplyCounterWindowLayout()
	local width = counterWindow:GetWidth()
	local scale = GetCounterWindowScale()
	local padding = RoundScaled(PADDING, scale)
	local rowTop = RoundScaled(ROW_TOP, scale)
	local rowHeight = RoundScaled(ROW_HEIGHT, scale)
	local handleSize = RoundScaled(CORNER_HANDLE_SIZE, scale)
	local contentWidth = width - (padding * 2)
	if contentWidth < 1 then
		contentWidth = 1
	end

	local closeWidth = RoundScaled(32, scale)
	local closeHeight = RoundScaled(20, scale)
	local titleHeight = RoundScaled(24, scale)
	local statusHeight = RoundScaled(20, scale)
	local buttonHeight = RoundScaled(22, scale)
	local clearWidth = RoundScaled(70, scale)
	local pageWidth = RoundScaled(58, scale)
	local pageHeight = RoundScaled(20, scale)
	local navWidth = RoundScaled(56, scale)
	local navGap = RoundScaled(10, scale)
	local titleWidth = width - (padding * 3) - closeWidth
	if titleWidth < 80 then
		titleWidth = 80
	end

	titleLabel:RemoveAllAnchors()
	titleLabel:AddAnchor("TOPLEFT", counterWindow, padding, padding)
	titleLabel:SetExtent(titleWidth, titleHeight)
	SetWidgetFontSize(titleLabel, RoundScaled(13, scale))

	closeButton:SetExtent(closeWidth, closeHeight)
	closeButton:RemoveAllAnchors()
	closeButton:AddAnchor("TOPRIGHT", counterWindow, -padding, padding - 1)
	SetWidgetFontSize(closeButton, RoundScaled(11, scale))

	statusLabel:RemoveAllAnchors()
	statusLabel:AddAnchor("TOPLEFT", counterWindow, padding, RoundScaled(30, scale))
	statusLabel:SetExtent(contentWidth, statusHeight)
	SetWidgetFontSize(statusLabel, RoundScaled(10, scale))

	for index = 1, PAGE_SIZE do
		local row = runtime.rows[index]
		row:RemoveAllAnchors()
		row:AddAnchor("TOPLEFT", counterWindow, padding, rowTop + ((index - 1) * rowHeight))
		row:SetExtent(contentWidth, rowHeight)
		SetWidgetFontSize(row, RoundScaled(12, scale))
	end

	clearButton:SetExtent(clearWidth, buttonHeight)
	clearButton:RemoveAllAnchors()
	clearButton:AddAnchor("BOTTOMLEFT", counterWindow, padding, -padding)
	SetWidgetFontSize(clearButton, RoundScaled(11, scale))

	nextButton:SetExtent(navWidth, buttonHeight)
	nextButton:RemoveAllAnchors()
	nextButton:AddAnchor("BOTTOMRIGHT", counterWindow, -padding, -padding)
	SetWidgetFontSize(nextButton, RoundScaled(11, scale))

	prevButton:SetExtent(navWidth, buttonHeight)
	prevButton:RemoveAllAnchors()
	local prevLeft = padding + clearWidth + navGap
	local rightGroupLeft = width - padding - navWidth - navGap - pageWidth
	if prevLeft + navWidth + navGap < rightGroupLeft then
		prevButton:AddAnchor("BOTTOMLEFT", counterWindow, prevLeft, -padding)
	else
		prevButton:AddAnchor("BOTTOMRIGHT", counterWindow, -(padding + navWidth + navGap + pageWidth + navGap), -padding)
	end
	SetWidgetFontSize(prevButton, RoundScaled(11, scale))

	pageLabel:SetExtent(pageWidth, pageHeight)
	pageLabel:RemoveAllAnchors()
	pageLabel:AddAnchor("BOTTOMRIGHT", counterWindow, -(padding + navWidth + navGap), -padding - 1)
	SetWidgetFontSize(pageLabel, RoundScaled(10, scale))

	for _, handle in ipairs(runtime.resizeHandles) do
		if handle ~= nil then
			handle:SetExtent(handleSize, handleSize)
			if ApplyResizeGripVisualScale ~= nil then
				ApplyResizeGripVisualScale(handle, scale)
			end
		end
	end

	if PositionCounterResizeHandles ~= nil then
		PositionCounterResizeHandles()
	end
end

local function SaveCounterWindowSize()
	local width, height = ClampWindowSize(counterWindow:GetWidth(), counterWindow:GetHeight())
	SaveData(WINDOW_SIZE_KEY, { width = width, height = height })
end

local function ApplyCounterWindowGeometry(x, y, width, height, shouldSave)
	width, height = ClampWindowSize(width, height)
	AnchorWidgetAtPosition(counterWindow, x, y)
	counterWindow:SetExtent(width, height)
	ApplyCounterWindowLayout()
	if shouldSave then
		SaveWidgetPosition(counterWindow, WINDOW_POSITION_KEY)
		SaveCounterWindowSize()
	end
end

PositionCounterResizeHandles = function()
	local x, y = GetWidgetPosition(counterWindow)
	if x == nil or y == nil then
		return
	end

	local width = counterWindow:GetWidth()
	local height = counterWindow:GetHeight()
	local handleSize = RoundScaled(CORNER_HANDLE_SIZE, GetCounterWindowScale())
	for _, handle in ipairs(runtime.resizeHandles) do
		if handle ~= nil and not handle.isResizing then
			local handleX = x
			local handleY = y
			if not handle.resizeFromLeft then
				handleX = x + width - handleSize
			end
			if not handle.resizeFromTop then
				handleY = y + height - handleSize
			end
			AnchorWidgetAtPosition(handle, handleX, handleY)
			SafeCall(handle, "Raise")
		end
	end
end

local function SetCounterResizeHandlesVisible(visible)
	for _, handle in ipairs(runtime.resizeHandles) do
		if handle ~= nil then
			handle:Show(visible)
			if visible then
				SafeCall(handle, "Raise")
			end
		end
	end
end

local function ClampResizeGeometry(data, x, y, width, height)
	if width < MIN_WINDOW_WIDTH then
		if data.resizeFromLeft then
			x = data.startX + data.startWidth - MIN_WINDOW_WIDTH
		end
		width = MIN_WINDOW_WIDTH
	end

	if height < MIN_WINDOW_HEIGHT then
		if data.resizeFromTop then
			y = data.startY + data.startHeight - MIN_WINDOW_HEIGHT
		end
		height = MIN_WINDOW_HEIGHT
	end

	return x, y, width, height
end

local function ComputeResizeGeometry(handle)
	local data = handle.resizeDrag
	if data == nil then
		return nil
	end

	local handleX, handleY = GetWidgetPosition(handle)
	if handleX == nil or handleY == nil then
		return nil
	end

	local deltaX = handleX - data.handleStartX
	local deltaY = handleY - data.handleStartY
	local x = data.startX
	local y = data.startY
	local width = data.startWidth
	local height = data.startHeight

	if data.resizeFromLeft then
		x = data.startX + deltaX
		width = data.startWidth - deltaX
	else
		width = data.startWidth + deltaX
	end

	if data.resizeFromTop then
		y = data.startY + deltaY
		height = data.startHeight - deltaY
	else
		height = data.startHeight + deltaY
	end

	return ClampResizeGeometry(data, x, y, width, height)
end

local function UpdateResizeFromHandle(handle)
	local x, y, width, height = ComputeResizeGeometry(handle)
	if x ~= nil then
		ApplyCounterWindowGeometry(x, y, width, height, false)
	end
end

local function SetResizeGripAlpha(handle, alpha)
	if handle == nil or handle.gripLines == nil then
		return
	end
	for _, line in ipairs(handle.gripLines) do
		SafeCall(line, "SetColor", 1, 1, 1, alpha)
	end
end

local function AddResizeGripLine(handle, x, y, width, height)
	local line = handle:CreateColorDrawable(1, 1, 1, RESIZE_GRIP_LINE_ALPHA, "background")
	line:SetExtent(width, height)
	line:AddAnchor("TOPLEFT", handle, x, y)
	handle.gripLines[#handle.gripLines + 1] = line
end

local function CreateResizeGripVisuals(handle)
	handle.gripLines = {}

	local horizontalX
	local verticalX
	if handle.resizeFromLeft then
		horizontalX = RESIZE_GRIP_INSET
		verticalX = RESIZE_GRIP_INSET
	else
		horizontalX = CORNER_HANDLE_SIZE - RESIZE_GRIP_INSET - RESIZE_GRIP_LINE_LENGTH
		verticalX = CORNER_HANDLE_SIZE - RESIZE_GRIP_INSET - RESIZE_GRIP_LINE_THICKNESS
	end

	local horizontalY
	local verticalY
	if handle.resizeFromTop then
		horizontalY = RESIZE_GRIP_INSET
		verticalY = RESIZE_GRIP_INSET
	else
		horizontalY = CORNER_HANDLE_SIZE - RESIZE_GRIP_INSET - RESIZE_GRIP_LINE_THICKNESS
		verticalY = CORNER_HANDLE_SIZE - RESIZE_GRIP_INSET - RESIZE_GRIP_LINE_LENGTH
	end

	AddResizeGripLine(handle, horizontalX, horizontalY, RESIZE_GRIP_LINE_LENGTH, RESIZE_GRIP_LINE_THICKNESS)
	AddResizeGripLine(handle, verticalX, verticalY, RESIZE_GRIP_LINE_THICKNESS, RESIZE_GRIP_LINE_LENGTH)
end

ApplyResizeGripVisualScale = function(handle, scale)
	if handle == nil or handle.gripLines == nil then
		return
	end

	local handleSize = RoundScaled(CORNER_HANDLE_SIZE, scale)
	local lineLength = RoundScaled(RESIZE_GRIP_LINE_LENGTH, scale)
	local lineThickness = RoundScaled(RESIZE_GRIP_LINE_THICKNESS, scale)
	local inset = RoundScaled(RESIZE_GRIP_INSET, scale)

	local horizontalX
	local verticalX
	if handle.resizeFromLeft then
		horizontalX = inset
		verticalX = inset
	else
		horizontalX = handleSize - inset - lineLength
		verticalX = handleSize - inset - lineThickness
	end

	local horizontalY
	local verticalY
	if handle.resizeFromTop then
		horizontalY = inset
		verticalY = inset
	else
		horizontalY = handleSize - inset - lineThickness
		verticalY = handleSize - inset - lineLength
	end

	if handle.gripLines[1] ~= nil then
		handle.gripLines[1]:RemoveAllAnchors()
		handle.gripLines[1]:SetExtent(lineLength, lineThickness)
		handle.gripLines[1]:AddAnchor("TOPLEFT", handle, horizontalX, horizontalY)
	end
	if handle.gripLines[2] ~= nil then
		handle.gripLines[2]:RemoveAllAnchors()
		handle.gripLines[2]:SetExtent(lineThickness, lineLength)
		handle.gripLines[2]:AddAnchor("TOPLEFT", handle, verticalX, verticalY)
	end
end

local function CreateCounterResizeHandle(name, anchor)
	local handle = counterWindow:CreateChildWidget("button", name, 0, true)
	handle:SetText("")
	handle:SetExtent(CORNER_HANDLE_SIZE, CORNER_HANDLE_SIZE)
	handle:EnableDrag(true)
	handle:Clickable(true)
	handle.resizeFromLeft = string.find(anchor, "LEFT", 1, true) ~= nil
	handle.resizeFromTop = string.find(anchor, "TOP", 1, true) ~= nil
	handle:Show(false)
	CreateResizeGripVisuals(handle)

	function handle:OnEnter()
		ShowCounterWindowButtons()
		SetResizeGripAlpha(self, RESIZE_GRIP_HOVER_ALPHA)
	end
	handle:SetHandler("OnEnter", handle.OnEnter)

	function handle:OnLeave()
		if not self.isResizing then
			SetResizeGripAlpha(self, RESIZE_GRIP_LINE_ALPHA)
		end
	end
	handle:SetHandler("OnLeave", handle.OnLeave)

	function handle:OnDragStart()
		local startX, startY = GetWidgetPosition(counterWindow)
		local handleStartX, handleStartY = GetWidgetPosition(self)
		if startX == nil or startY == nil or handleStartX == nil or handleStartY == nil then
			return
		end

		self.resizeDrag = {
			startX = startX,
			startY = startY,
			startWidth = counterWindow:GetWidth(),
			startHeight = counterWindow:GetHeight(),
			handleStartX = handleStartX,
			handleStartY = handleStartY,
			resizeFromLeft = self.resizeFromLeft,
			resizeFromTop = self.resizeFromTop,
		}
		self.isResizing = true
		SetResizeGripAlpha(self, RESIZE_GRIP_HOVER_ALPHA)
		ShowCounterWindowButtons()
		self:StartMoving()
	end
	handle:SetHandler("OnDragStart", handle.OnDragStart)

	function handle:OnUpdate()
		if self.isResizing then
			UpdateResizeFromHandle(self)
		end
	end
	handle:SetHandler("OnUpdate", handle.OnUpdate)

	function handle:OnDragStop()
		self:StopMovingOrSizing()
		local x, y, width, height = ComputeResizeGeometry(self)
		if x ~= nil then
			ApplyCounterWindowGeometry(x, y, width, height, true)
		end
		self.resizeDrag = nil
		self.isResizing = false
		SetResizeGripAlpha(self, RESIZE_GRIP_LINE_ALPHA)
		PositionCounterResizeHandles()
	end
	handle:SetHandler("OnDragStop", handle.OnDragStop)

	return handle
end

local counterWindowButtonsVisible

local function SetCounterWindowButtonsVisible(visible)
	if counterWindowButtonsVisible == visible then
		return
	end
	counterWindowButtonsVisible = visible
	closeButton:Show(visible)
	clearButton:Show(visible)
	prevButton:Show(visible)
	nextButton:Show(visible)
end

ShowCounterWindowButtons = function()
	SetCounterWindowButtonsVisible(true)
end

local function HideCounterWindowButtons()
	SetCounterWindowButtonsVisible(false)
end

local function EnableCounterWindowHover(surface)
	if surface == nil or type(surface.SetHandler) ~= "function" then
		return
	end
	surface:SetHandler("OnEnter", ShowCounterWindowButtons)
end

local function StartCounterWindowDrag(surface)
	local now = RefreshClock()
	if surface ~= nil then
		surface.counterDragSuppressUntil = now + 0.5
	end
	counterWindow:StartMoving()
	return true
end

local function StopCounterWindowDrag(surface)
	local now = RefreshClock()
	if surface ~= nil then
		surface.counterDragSuppressUntil = now + 0.5
	end
	counterWindow:StopMovingOrSizing()
	SaveWidgetPosition(counterWindow, WINDOW_POSITION_KEY)
	PositionCounterResizeHandles()
	return true
end

local function WasCounterWindowDragged(surface)
	local now = RefreshClock()
	if surface == nil or surface.counterDragSuppressUntil == nil then
		return false
	end
	if now <= surface.counterDragSuppressUntil then
		surface.counterDragSuppressUntil = nil
		return true
	end
	surface.counterDragSuppressUntil = nil
	return false
end

local function EnableCounterWindowDrag(surface)
	if surface == nil then
		return
	end
	SafeCall(surface, "Clickable", true)
	SafeCall(surface, "EnableDrag", true)
	surface:SetHandler("OnDragStart", StartCounterWindowDrag)
	surface:SetHandler("OnDragStop", StopCounterWindowDrag)
end

runtime.resizeHandles = {
	CreateCounterResizeHandle("lootKillCounterResizeTopLeft", "TOPLEFT"),
	CreateCounterResizeHandle("lootKillCounterResizeTopRight", "TOPRIGHT"),
	CreateCounterResizeHandle("lootKillCounterResizeBottomLeft", "BOTTOMLEFT"),
	CreateCounterResizeHandle("lootKillCounterResizeBottomRight", "BOTTOMRIGHT"),
}
ApplyCounterWindowLayout()
SetCounterResizeHandlesVisible(false)

EnableCounterWindowDrag(titleLabel)
EnableCounterWindowDrag(statusLabel)
EnableCounterWindowDrag(pageLabel)
EnableCounterWindowDrag(closeButton)
EnableCounterWindowDrag(clearButton)
EnableCounterWindowDrag(prevButton)
EnableCounterWindowDrag(nextButton)
for index = 1, PAGE_SIZE do
	EnableCounterWindowDrag(runtime.rows[index])
end

EnableCounterWindowHover(titleLabel)
EnableCounterWindowHover(statusLabel)
EnableCounterWindowHover(pageLabel)
EnableCounterWindowHover(closeButton)
EnableCounterWindowHover(clearButton)
EnableCounterWindowHover(prevButton)
EnableCounterWindowHover(nextButton)
for index = 1, PAGE_SIZE do
	EnableCounterWindowHover(runtime.rows[index])
end
HideCounterWindowButtons()

UpdateCounterWindow = function()
	local names = BuildSortedMobNames()
	local totalPages = ClampCurrentPage(#names)
	local startIndex = ((runtime.currentPage - 1) * PAGE_SIZE) + 1

	titleLabel:SetText("Kill Counter: " .. tostring(GetTotalKillCount()))

	if runtime.lastKill ~= nil and runtime.lastKill.mobName ~= nil then
		statusLabel:SetText("Last: " .. tostring(runtime.lastKill.killerName or "Unknown") .. " -> " .. tostring(runtime.lastKill.mobName))
	else
		statusLabel:SetText("No kills tracked")
	end

	for rowIndex = 1, PAGE_SIZE do
		local mobName = names[startIndex + rowIndex - 1]
		local row = runtime.rows[rowIndex]
		if mobName == nil then
			row:SetText("")
		else
			row:SetText(mobName .. ": " .. tostring(runtime.killCounts[mobName] or 0))
		end
	end

	pageLabel:SetText(tostring(runtime.currentPage) .. "/" .. tostring(totalPages))
end

function runtime:ShowCounterWindow()
	HideCounterWindowButtons()
	counterWindow:Show(true)
	SetCounterResizeHandlesVisible(true)
	PositionCounterResizeHandles()
	UpdateCounterWindow()
end

function counterWindow:OnDragStart()
	self:StartMoving()
end
counterWindow:SetHandler("OnDragStart", counterWindow.OnDragStart)

function counterWindow:OnDragStop()
	self:StopMovingOrSizing()
	SaveWidgetPosition(self, WINDOW_POSITION_KEY)
	PositionCounterResizeHandles()
end
counterWindow:SetHandler("OnDragStop", counterWindow.OnDragStop)

function counterWindow:OnEnter()
	ShowCounterWindowButtons()
end
counterWindow:SetHandler("OnEnter", counterWindow.OnEnter)

function counterWindow:OnLeave()
	HideCounterWindowButtons()
end
counterWindow:SetHandler("OnLeave", counterWindow.OnLeave)

function closeButton:OnClick()
	if WasCounterWindowDragged(self) then
		return
	end
	SetCounterResizeHandlesVisible(false)
	counterWindow:Show(false)
end
closeButton:SetHandler("OnClick", closeButton.OnClick)

function clearButton:OnClick()
	if WasCounterWindowDragged(self) then
		return
	end
	ClearKillCounts()
end
clearButton:SetHandler("OnClick", clearButton.OnClick)

function prevButton:OnClick()
	if WasCounterWindowDragged(self) then
		return
	end
	runtime.currentPage = runtime.currentPage - 1
	UpdateCounterWindow()
end
prevButton:SetHandler("OnClick", prevButton.OnClick)

function nextButton:OnClick()
	if WasCounterWindowDragged(self) then
		return
	end
	runtime.currentPage = runtime.currentPage + 1
	UpdateCounterWindow()
end
nextButton:SetHandler("OnClick", nextButton.OnClick)

local eventWindow = CreateEmptyWindow("lootKillCounterEventWindow", "UIParent")
runtime.eventWindow = eventWindow
eventWindow:Show(false)

function eventWindow:OnEvent(event, ...)
	if not runtime.active then
		return
	end
	RefreshClock()
	if event == "COMBAT_MSG" then
		UpdateCurrentTarget(true)
		HandleCombatMessage(...)
		return
	end
	if event == "SPELLCAST_START" or event == "SPELLCAST_SUCCEEDED" then
		HandleSpellcastEvent(event, ...)
		return
	end
	if event == "TARGET_CHANGED" then
		CaptureCurrentTarget("target_switch")
		MarkPendingTargetSwitched(runtime.currentTargetKey)
		runtime.currentTargetKey = nil
		runtime.currentTargetName = nil
		runtime.currentTargetDeathCounted = false
	end
	UpdateCurrentTarget()
end
eventWindow:SetHandler("OnEvent", eventWindow.OnEvent)

eventWindow:RegisterEvent("COMBAT_MSG")
eventWindow:RegisterEvent("SPELLCAST_START")
eventWindow:RegisterEvent("SPELLCAST_SUCCEEDED")
eventWindow:RegisterEvent("TARGET_CHANGED")
eventWindow:RegisterEvent("TARGET_TO_TARGET_CHANGED")
eventWindow:RegisterEvent("AGGRO_METER_CLEARED")

function eventWindow:OnUpdate(dt)
	if not runtime.active then
		return
	end

	local now = RefreshClock()
	local delta = NormalizeDt(dt)
	if delta <= 0 and runtime.lastUpdateTime ~= nil then
		delta = now - runtime.lastUpdateTime
	end
	runtime.lastUpdateTime = now
	runtime.updateElapsed = runtime.updateElapsed + delta
	if runtime.updateElapsed < 0.15 then
		return
	end
	runtime.updateElapsed = 0
	PruneTargetSnapshots()
	PrunePendingTargetHits()
	UpdateCurrentTarget()
end
eventWindow:SetHandler("OnUpdate", eventWindow.OnUpdate)

UpdateCounterWindow()
