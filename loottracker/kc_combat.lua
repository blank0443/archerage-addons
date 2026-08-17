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

function Analysis.GetCombatEventKind(eventType)
	eventType = tostring(eventType or "")
	if string.find(eventType, "MISSED", 1, true) ~= nil or string.find(eventType, "MISS", 1, true) ~= nil then
		return "miss"
	end
	if string.find(eventType, "HEALED", 1, true) ~= nil then
		return "heal"
	end
	if string.find(eventType, "ENERGIZE", 1, true) ~= nil then
		return "energize"
	end
	if string.find(eventType, "DAMAGE", 1, true) ~= nil then
		return "damage"
	end
	return "other"
end

function Analysis.GetDamageCategory(eventType)
	eventType = tostring(eventType or "")
	if string.find(eventType, "ENVIRONMENTAL", 1, true) ~= nil then
		return "Environmental"
	end
	if string.find(eventType, "MELEE_DAMAGE", 1, true) ~= nil then
		return "Melee"
	end
	if string.find(eventType, "SPELL_DAMAGE", 1, true) ~= nil then
		return "Spell"
	end
	if string.find(eventType, "RANGE", 1, true) ~= nil then
		return "Ranged"
	end
	if string.find(eventType, "DAMAGE", 1, true) ~= nil then
		return "Other"
	end
	return "Other"
end

function Analysis.ParseCombatMessage(...)
	return {
		unitId = select(1, ...),
		eventType = tostring(select(2, ...) or ""),
		sourceName = Trim(select(3, ...) or ""),
		targetName = Trim(select(4, ...) or ""),
		abilityId = select(5, ...),
		abilityName = Trim(select(6, ...) or ""),
		damageType = select(7, ...),
		effectType = select(8, ...),
		isActive = select(9, ...),
		arg10 = select(10, ...),
		arg11 = select(11, ...),
		arg12 = select(12, ...),
		arg13 = select(13, ...),
	}
end

function Analysis.ParseCombatTextMessage(...)
	return {
		sourceUnitId = Analysis.NormalizeUnitId(select(1, ...)),
		targetUnitId = Analysis.NormalizeUnitId(select(2, ...)),
		amount = tonumber(select(3, ...)),
		hitType = Trim(tostring(select(6, ...) or "")),
	}
end

function Analysis.IsDamageCombatText(msg)
	if type(msg) ~= "table" or tonumber(msg.amount) == nil or tonumber(msg.amount) <= 0 then
		return false
	end
	return msg.hitType == "" or msg.hitType == "HIT" or msg.hitType == "CRITICAL"
end

function Analysis.NormalizeAbilityName(abilityName, eventType, abilityId)
	abilityName = Trim(abilityName or "")
	if abilityName == "HEALTH" then
		return "Melee"
	end
	if abilityName ~= "" then
		return abilityName
	end
	if string.find(tostring(eventType or ""), "MELEE", 1, true) ~= nil then
		return "Melee Attack"
	end
	local numericAbilityId = tonumber(abilityId)
	if numericAbilityId ~= nil then
		return "Spell_" .. tostring(numericAbilityId)
	end
	return "Unknown"
end

function Analysis.BuildAbilityStorageKey(prefix, eventType, abilityId, abilityName)
	return tostring(prefix or "Other") .. "::" .. Analysis.NormalizeAbilityName(abilityName, eventType, abilityId)
end

function Analysis.BuildSkillStorageKey(category, eventType, abilityId, abilityName)
	return tostring(category or "Other") .. "::" .. Analysis.NormalizeAbilityName(abilityName, eventType, abilityId)
end

function Analysis.RecordSkillUse(eventType, abilityId, abilityName, count)
	local displayName = Analysis.NormalizeAbilityName(abilityName, eventType, abilityId)
	if displayName == "" then
		displayName = "Unknown"
	end
	local entry = runtime.skillUsageByName[displayName]
	if type(entry) ~= "table" then
		entry = {
			name = displayName,
			count = 0,
		}
		runtime.skillUsageByName[displayName] = entry
	end
	entry.name = displayName
	entry.count = (tonumber(entry.count) or 0) + (tonumber(count) or 1)
end

function Analysis.GetEffectAmount(eventKind, eventType, abilityId, effectType)
	if eventKind ~= "damage" and eventKind ~= "heal" and eventKind ~= "energize" then
		return nil
	end
	if eventKind == "damage"
		and type(eventType) == "string"
		and string.find(eventType, "MELEE_DAMAGE", 1, true) ~= nil
	then
		local amount = Analysis.NormalizePositiveAmount(abilityId)
		if amount ~= nil then
			return math.floor(amount)
		end
	end
	local amount = Analysis.NormalizePositiveAmount(effectType) or Analysis.NormalizePositiveAmount(abilityId)
	if amount == nil then
		return nil
	end
	return math.floor(amount)
end

function Analysis.EnsurePlayerCombatStats()
	if type(runtime.playerCombatStats) ~= "table" then
		runtime.playerCombatStats = {}
	end
	return runtime.playerCombatStats
end

function Analysis.IncrementPlayerStat(field, amount)
	local stats = Analysis.EnsurePlayerCombatStats()
	amount = tonumber(amount) or 1
	stats[field] = (tonumber(stats[field]) or 0) + amount
end

function Analysis.UpdateExtremeStat(field, value)
	local stats = Analysis.EnsurePlayerCombatStats()
	value = tonumber(value) or 0
	if value <= 0 then
		return
	end
	local current = tonumber(stats[field]) or 0
	if value > current then
		stats[field] = value
	end
end

function Analysis.TrackDamageElement(damageType, amount)
	local elementKey = Trim(tostring(damageType or ""))
	if elementKey == "" or elementKey == "0" then
		return
	end
	runtime.damageByElement[elementKey] = (tonumber(runtime.damageByElement[elementKey]) or 0) + amount
end

function Analysis.RecordSkillDamage(sourceName, targetName, eventType, abilityId, abilityName, damageAmount, damageType)
	if not Analysis.IsLocalPlayerName(sourceName) or not IsValidName(targetName) then
		return
	end
	local category = Analysis.GetDamageCategory(eventType)
	local skillKey = Analysis.BuildSkillStorageKey(category, eventType, abilityId, abilityName)
	local displayName = Analysis.NormalizeAbilityName(abilityName, eventType, abilityId)
	local entry = runtime.damageBySkill[skillKey]
	if entry == nil then
		entry = {
			name = displayName,
			category = category,
			damage = 0,
			hits = 0,
		}
		runtime.damageBySkill[skillKey] = entry
	elseif entry.name == nil or Trim(entry.name) == "" then
		entry.name = displayName
	end
	entry.category = category
	if damageType ~= nil then
		local damageTypeText = Trim(tostring(damageType))
		if damageTypeText ~= "" and damageTypeText ~= "0" then
			entry.damageType = damageTypeText
		end
	end
	entry.damage = (tonumber(entry.damage) or 0) + damageAmount
	entry.hits = (tonumber(entry.hits) or 0) + 1
	Analysis.RecordSkillUse(eventType, abilityId, abilityName, 1)
	Analysis.TrackDamageElement(damageType, damageAmount)
	Analysis.IncrementPlayerStat("totalHits", 1)
	Analysis.UpdateExtremeStat("largestHit", damageAmount)
	runtime.damageByCategory[category] = (tonumber(runtime.damageByCategory[category]) or 0) + damageAmount
end

function Analysis.RecordHeal(sourceName, eventType, abilityId, abilityName, healAmount)
	if not Analysis.IsLocalPlayerName(sourceName) then
		return
	end
	local skillKey = Analysis.BuildAbilityStorageKey("Heal", eventType, abilityId, abilityName)
	local entry = runtime.healBySkill[skillKey]
	if entry == nil then
		entry = {
			name = Analysis.NormalizeAbilityName(abilityName, eventType, abilityId),
			amount = 0,
			hits = 0,
		}
		runtime.healBySkill[skillKey] = entry
	end
	entry.amount = (tonumber(entry.amount) or 0) + healAmount
	entry.hits = (tonumber(entry.hits) or 0) + 1
	Analysis.RecordSkillUse(eventType, abilityId, abilityName, 1)
	Analysis.IncrementPlayerStat("totalHealingHits", 1)
	Analysis.UpdateExtremeStat("largestHeal", healAmount)
end

function Analysis.RecordMiss(sourceName, eventType, abilityId, abilityName)
	if not Analysis.IsLocalPlayerName(sourceName) then
		return
	end
	local category = "Spell"
	if string.find(tostring(eventType or ""), "MELEE", 1, true) ~= nil
		or string.find(tostring(eventType or ""), "SWING", 1, true) ~= nil
	then
		category = "Melee"
	end
	local skillKey = Analysis.BuildSkillStorageKey(category, eventType, abilityId, abilityName)
	local entry = runtime.missesBySkill[skillKey]
	if entry == nil then
		entry = {
			name = Analysis.NormalizeAbilityName(abilityName, eventType, abilityId),
			category = category,
			count = 0,
		}
		runtime.missesBySkill[skillKey] = entry
	end
	entry.count = (tonumber(entry.count) or 0) + 1
	Analysis.RecordSkillUse(eventType, abilityId, abilityName, 1)
	Analysis.IncrementPlayerStat("totalMisses", 1)
	if category == "Melee" then
		Analysis.IncrementPlayerStat("meleeMisses", 1)
	else
		Analysis.IncrementPlayerStat("spellMisses", 1)
	end
end

function Analysis.RecordEnergize(sourceName, eventType, abilityId, abilityName, amount)
	if not Analysis.IsLocalPlayerName(sourceName) then
		return
	end
	local skillKey = Analysis.BuildAbilityStorageKey("Energize", eventType, abilityId, abilityName)
	local entry = runtime.energizeBySkill[skillKey]
	if entry == nil then
		entry = {
			name = Analysis.NormalizeAbilityName(abilityName, eventType, abilityId),
			amount = 0,
			hits = 0,
		}
		runtime.energizeBySkill[skillKey] = entry
	end
	entry.amount = (tonumber(entry.amount) or 0) + amount
	entry.hits = (tonumber(entry.hits) or 0) + 1
	Analysis.RecordSkillUse(eventType, abilityId, abilityName, 1)
end

function Analysis.RecordDamageTaken(sourceName, damageAmount)
	sourceName = Trim(sourceName or "Unknown")
	if sourceName == "" then
		sourceName = "Unknown"
	end
	runtime.damageTakenBySource[sourceName] =
		(tonumber(runtime.damageTakenBySource[sourceName]) or 0) + damageAmount
	runtime.lastDamageTaken = {
		sourceName = sourceName,
		time = Analysis.RefreshClock(),
	}
	Analysis.IncrementPlayerStat("totalDamageTaken", damageAmount)
end

function Analysis.RecordHealReceived(sourceName, healAmount)
	sourceName = Trim(sourceName or "Unknown")
	if sourceName == "" then
		sourceName = "Unknown"
	end
	Analysis.IncrementPlayerStat("totalHealingReceived", healAmount)
end

function Analysis.GetCombatAuraEventKind(eventType)
	eventType = tostring(eventType or "")
	if string.find(eventType, "AURA_APPLIED_DOSE", 1, true) ~= nil
		or string.find(eventType, "SPELL_AURA_APPLIED_DOSE", 1, true) ~= nil
	then
		return "aura_dose"
	end
	if string.find(eventType, "AURA_APPLIED", 1, true) ~= nil
		or string.find(eventType, "SPELL_AURA_APPLIED", 1, true) ~= nil
	then
		return "aura_applied"
	end
	if string.find(eventType, "AURA_REMOVED", 1, true) ~= nil
		or string.find(eventType, "SPELL_AURA_REMOVED", 1, true) ~= nil
	then
		return "aura_removed"
	end
	if string.find(eventType, "AURA_REFRESH", 1, true) ~= nil
		or string.find(eventType, "SPELL_AURA_REFRESH", 1, true) ~= nil
	then
		return "aura_refresh"
	end
	return nil
end

function Analysis.RecordDpsReviewCombatMessage(msg)
	if type(msg) ~= "table" then
		return false
	end
	local auraKind = Analysis.GetCombatAuraEventKind(msg.eventType)
	if auraKind ~= nil then
		return false
	end
	if msg.sourceName == "" or msg.targetName == "" then
		return false
	end
	local eventKind = Analysis.GetCombatEventKind(msg.eventType)
	local amount = Analysis.GetEffectAmount(eventKind, msg.eventType, msg.abilityId, msg.effectType)
	local recorded = false
	if eventKind == "damage" and amount ~= nil then
		if Analysis.IsLocalPlayerName(msg.sourceName) then
			Analysis.RecordSkillDamage(
				msg.sourceName,
				msg.targetName,
				msg.eventType,
				msg.abilityId,
				msg.abilityName,
				amount,
				msg.damageType
			)
			recorded = true
		end
		if Analysis.IsLocalPlayerName(msg.targetName) and not Analysis.IsLocalPlayerName(msg.sourceName) then
			Analysis.RecordDamageTaken(msg.sourceName, amount)
			recorded = true
		end
	elseif eventKind == "heal" and amount ~= nil then
		if Analysis.IsLocalPlayerName(msg.sourceName) then
			Analysis.RecordHeal(msg.sourceName, msg.eventType, msg.abilityId, msg.abilityName, amount)
			recorded = true
		end
		if Analysis.IsLocalPlayerName(msg.targetName) and not Analysis.IsLocalPlayerName(msg.sourceName) then
			Analysis.RecordHealReceived(msg.sourceName, amount)
			recorded = true
		end
	elseif eventKind == "miss" then
		Analysis.RecordMiss(msg.sourceName, msg.eventType, msg.abilityId, msg.abilityName)
		recorded = Analysis.IsLocalPlayerName(msg.sourceName)
	elseif eventKind == "energize" and amount ~= nil then
		Analysis.RecordEnergize(msg.sourceName, msg.eventType, msg.abilityId, msg.abilityName, amount)
		recorded = Analysis.IsLocalPlayerName(msg.sourceName)
	end
	if recorded then
		Analysis.MarkSessionDataSavePending()
	end
	if recorded and Analysis.RefreshViewWindowIfVisible ~= nil then
		Analysis.RefreshViewWindowIfVisible()
	end
	return recorded
end

function Analysis.GetKillCombatDuration(now)
	local total = tonumber(runtime.totalKillTime) or 0
	if runtime.combatActive and runtime.combatStart ~= nil then
		total = total + ((now or Analysis.RefreshClock()) - runtime.combatStart)
	end
	if total < 0 then
		return 0
	end
	return total
end

-- Official combat flag first; UnitCombatState is a fallback when PlayerInCombat is unavailable.
function Analysis.IsPlayerInCombat()
	local ok, value = SafeCall(X2Player, "PlayerInCombat")
	if ok and value == true then
		return true
	end
	ok, value = SafeCall(X2Unit, "UnitCombatState", "player")
	return ok and value == true
end

function Analysis.BeginKillCombatSession(now)
	now = now or Analysis.RefreshClock()
	runtime.combatActive = true
	runtime.combatStart = now
	runtime.lastCombatActivity = now
	runtime.playerInCombat = true
	runtime.combatExitSince = nil
end

function Analysis.EndKillCombatSession(now)
	if not runtime.combatActive then
		return
	end
	now = now or Analysis.RefreshClock()
	if runtime.combatStart ~= nil and now > runtime.combatStart then
		runtime.totalKillTime = (tonumber(runtime.totalKillTime) or 0) + (now - runtime.combatStart)
	end
	runtime.combatActive = false
	runtime.combatStart = nil
	runtime.playerInCombat = false
	runtime.combatExitSince = nil
	Analysis.FlushSessionDataSave(true)
	if Analysis.RefreshViewWindowIfVisible ~= nil then
		Analysis.RefreshViewWindowIfVisible()
	end
end

function Analysis.RememberCombatLogTarget(mobName, sourceName)
	if IsValidName(mobName) and not Analysis.IsLocalPlayerName(mobName) and not Analysis.IsAlliedPlayerName(mobName) then
		runtime.lastCombatLogMobName = Trim(mobName)
	end
	if IsValidName(sourceName) then
		runtime.lastCombatLogSourceName = Trim(sourceName)
	end
end

-- Combat-log activity only refreshes EXP attribution recency; it must not start Kill Time.
function Analysis.TouchKillCombatActivity(now)
	now = now or Analysis.RefreshClock()
	runtime.lastCombatActivity = now
end

function Analysis.TouchCombatLogActivity(mobName, sourceName, now)
	now = now or Analysis.RefreshClock()
	runtime.lastCombatLogTime = now
	Analysis.RememberCombatLogTarget(mobName, sourceName)
	Analysis.TouchKillCombatActivity(now)
end

-- Kill Time follows PlayerInCombat with a short exit grace to avoid flag flicker.
function Analysis.EvaluateKillCombatEnd(now)
	now = now or Analysis.RefreshClock()
	local inCombat = Analysis.IsPlayerInCombat()
	runtime.playerInCombat = inCombat

	if inCombat then
		runtime.combatExitSince = nil
		if not runtime.combatActive then
			Analysis.BeginKillCombatSession(now)
		end
		return
	end

	if not runtime.combatActive then
		runtime.combatExitSince = nil
		return
	end

	local exitSince = tonumber(runtime.combatExitSince)
	if exitSince == nil then
		runtime.combatExitSince = now
		return
	end
	if now - exitSince >= PLAYER_COMBAT_EXIT_GRACE then
		Analysis.EndKillCombatSession(now)
	end
end

function Analysis.GetRecentMobName(maxAge)
	-- Loot and EXP events do not expose a stable killed-unit id, so this report attributes them to the recent kill/current target.
	local now = Analysis.RefreshClock()
	maxAge = tonumber(maxAge) or LOOT_ATTRIBUTION_SECONDS
	if runtime.lastKill ~= nil
		and IsValidName(runtime.lastKill.mobName)
		and tonumber(runtime.lastKill.time) ~= nil
		and now - runtime.lastKill.time <= maxAge
	then
		return runtime.lastKill.mobName
	end
	if IsValidName(runtime.currentTargetName) then
		return Trim(runtime.currentTargetName)
	end
	return "Unknown"
end

function Analysis.SyncManaSpent()
	local mana = Analysis.SafeUnitValue("UnitMana", "player")
	if mana == nil then
		return
	end
	local lastMana = tonumber(runtime.lastPlayerMana)
	if lastMana ~= nil and mana < lastMana then
		runtime.totalManaSpent = (tonumber(runtime.totalManaSpent) or 0) + (lastMana - mana)
		Analysis.MarkSessionDataSavePending()
		if Analysis.RefreshViewWindowIfVisible ~= nil then
			Analysis.RefreshViewWindowIfVisible()
		end
	end
	runtime.lastPlayerMana = mana
end

function Analysis.SyncSessionResourceSnapshots()
	Analysis.SyncManaSpent()
	Analysis.SyncMoneyEarned()
end

function Analysis.RecordSessionDamage(sourceName, targetName, damageAmount)
	damageAmount = Analysis.NormalizePositiveAmount(damageAmount)
	if damageAmount == nil then
		return
	end

	local sourceIsPlayer = Analysis.IsLocalPlayerName(sourceName)
	local targetIsPlayer = Analysis.IsLocalPlayerName(targetName)
	local recorded = false
	if sourceIsPlayer and not targetIsPlayer and IsValidName(targetName) then
		targetName = Trim(targetName)
		Analysis.AddAmount(runtime.damageDealtByUnit, targetName, damageAmount)
		runtime.totalDamageDealt = (tonumber(runtime.totalDamageDealt) or 0) + damageAmount
		recorded = true
	end
	if targetIsPlayer and not sourceIsPlayer and IsValidName(sourceName) then
		sourceName = Trim(sourceName)
		Analysis.AddAmount(runtime.damageTakenByUnit, sourceName, damageAmount)
		runtime.totalDamageTaken = (tonumber(runtime.totalDamageTaken) or 0) + damageAmount
		recorded = true
	end
	if recorded then
		Analysis.MarkSessionDataSavePending()
	end
	if recorded and Analysis.RefreshViewWindowIfVisible ~= nil then
		Analysis.RefreshViewWindowIfVisible()
	end
end

function Analysis.HandleCombatTextMessage(...)
	local msg = Analysis.ParseCombatTextMessage(...)
	if not Analysis.IsDamageCombatText(msg) then
		return false
	end
	if not Analysis.IsLocalPlayerUnitId(msg.sourceUnitId) or Analysis.IsLocalPlayerUnitId(msg.targetUnitId) then
		return false
	end

	local targetInfo = Analysis.GetUnitInfoById(msg.targetUnitId)
	if type(targetInfo) == "table" and targetInfo.type == "character" then
		return false
	end
	local targetName = Analysis.GetUnitNameById(msg.targetUnitId, targetInfo)
	if not IsValidName(targetName) or Analysis.IsLocalPlayerName(targetName) or Analysis.IsAlliedPlayerName(targetName) then
		return false
	end

	local targetKey = Analysis.BuildTargetKey(msg.targetUnitId, targetName)
	if targetKey == nil then
		return false
	end
	local sourceName = Analysis.GetLocalPlayerName() or "You"
	runtime.recentDamageByTarget[targetKey] = {
		sourceName = sourceName,
		targetName = targetName,
		eventType = "COMBAT_TEXT",
		amount = tonumber(msg.amount) or 0,
		time = Analysis.RefreshClock(),
	}
	Analysis.TouchCombatLogActivity(targetName, sourceName)
	Analysis.AddExpKillCandidate(targetName, targetKey, sourceName)
	return true
end

function Analysis.HandleCombatMessage(...)
	local now = Analysis.RefreshClock()
	local msg = Analysis.ParseCombatMessage(...)
	Analysis.RecordDpsReviewCombatMessage(msg)
	local eventType = msg.eventType
	local sourceName = msg.sourceName
	local targetName = msg.targetName
	local damageAmount = Analysis.GetCombatDamageAmount(eventType, msg.abilityId, msg.effectType)
	if Analysis.IsCombatDeathEvent(eventType) then
		if Analysis.IsAlliedPlayerName(targetName) then
			Analysis.CountAlliedPlayerDeath(targetName, sourceName)
		else
			Analysis.CountNpcDeathFromCombatEvent(msg)
		end
		return
	end
	if string.find(tostring(eventType or ""), "MONEY", 1, true) ~= nil then
		if runtime.playerMoneyHandlerRegistered == true then
			return
		end

		local amount = Analysis.ExtractMoneyCopperFromCombatMessage(msg)
		if amount ~= nil then
			Analysis.RecordMoneyEarned(amount, "combat")
		else
			Analysis.SyncMoneyEarned()
		end
		return
	end
	if sourceName == "" or targetName == "" then
		return
	end
	if damageAmount == nil then
		return
	end

	Analysis.RecordSessionDamage(sourceName, targetName, damageAmount)
	if Analysis.IsLocalPlayerName(targetName) and not Analysis.IsLocalPlayerName(sourceName) then
		Analysis.TryCountLocalPlayerDeath(sourceName)
		return
	end
	local targetKey = Analysis.BuildTargetKey(msg.unitId, targetName)
	local damageRecord = {
		sourceName = sourceName,
		targetName = targetName,
		eventType = eventType,
		amount = damageAmount,
		time = now,
	}
	if targetKey ~= nil then
		runtime.recentDamageByTarget[targetKey] = damageRecord
	end
	local nameKey = Analysis.BuildTargetKey(nil, targetName)
	if nameKey ~= nil and nameKey ~= targetKey then
		runtime.recentDamageByTarget[nameKey] = damageRecord
	end
	if Analysis.IsNpcExpTarget(msg.unitId, targetName) and Analysis.IsLocalPlayerName(sourceName) then
		Analysis.TouchCombatLogActivity(targetName, sourceName, now)
		Analysis.AddExpKillCandidate(targetName, targetKey, sourceName)
	end
	Analysis.TryCountLethalDamage(targetName, targetKey, sourceName, damageAmount)
end

function Analysis.IsPlayerSpellcast(...)
	local argCount = select("#", ...)
	for index = 1, argCount do
		if select(index, ...) == "player" then
			return true
		end
	end
	return false
end

function Analysis.HandleSpellcastEvent(event, ...)
	if not Analysis.IsPlayerSpellcast(...) then
		return
	end
	Analysis.UpdateCurrentTarget(true)
	Analysis.CaptureCurrentTarget(event)
end

