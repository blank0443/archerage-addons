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

Analysis.RestoreAndPersistSessionHistory(LT.previousKillCounterRuntime)
Analysis.LoadKillCounts()
Analysis.EnsureSessionStartTime(Analysis.RefreshClock())
Analysis.LoadCounterSettings()
Analysis.SyncSessionResourceSnapshots()
Analysis.ResetLocalPlayerDeathTracking()
Analysis.SyncBagDrops(true)

local eventWindow = CreateEmptyWindow("lootKillCounterEventWindow", "UIParent")
runtime.eventWindow = eventWindow
eventWindow:Show(false)

function eventWindow:OnEvent(event, ...)
	if not runtime.active then
		return
	end
	Analysis.RefreshClock()
	if event == "ENTERED_LOADING" then
		Analysis.CaptureLoadingStartLocation()
		-- Persist current session + history before loading can interrupt addon state.
		if not runtime.gameLoadingStarted then
			Analysis.SaveCurrentSessionToHistory()
			Analysis.ClearKillCounts()
		end
		Analysis.SaveSessionHistory()
		runtime.gameLoadingStarted = true
		return
	end
	if event == "LEFT_LOADING" then
		if runtime.gameLoadingStarted then
			Analysis.SaveCurrentSessionToHistory()
			Analysis.ClearKillCounts()
		end
		Analysis.SaveSessionHistory()
		runtime.gameLoadingStarted = false
		Analysis.CaptureCurrentSessionLocation()
		return
	end
	if not runtime.gameLoadingStarted then
		Analysis.CaptureCurrentSessionLocation()
	end
	if event == "UNIT_COMBAT_STATE_CHANGED" then
		Analysis.EvaluateKillCombatEnd(Analysis.RefreshClock())
		return
	end
	if event == "UNIT_DEAD" or event == "UNIT_DEAD_NOTICE" then
		local deathName = Analysis.ExtractAlliedPlayerDeathName(...)
		if deathName ~= nil then
			Analysis.CountAlliedPlayerDeath(deathName, Analysis.ResolveLocalPlayerDeathKillerName())
		else
			Analysis.TryCountLocalPlayerDeath(Analysis.ResolveLocalPlayerDeathKillerName())
		end
		return
	end
	if event == "PLAYER_RESURRECTED" then
		Analysis.SyncLocalPlayerDeathState()
		return
	end
	if event == "COMBAT_MSG" then
		runtime.targetRefreshDirty = true
		Analysis.HandleCombatMessage(...)
		return
	end
	if event == "COMBAT_TEXT" then
		Analysis.HandleCombatTextMessage(...)
		return
	end
	if event == "ITEM_ACQUISITION_BY_LOOT" then
		Analysis.CaptureSessionActivityLocation()
		Analysis.HandleLootAcquisitionEvent(...)
		return
	end
	if event == "MONEY_ACQUISITION_BY_LOOT" then
		Analysis.CaptureSessionActivityLocation()
		Analysis.HandleMoneyAcquisitionEvent(...)
		return
	end
	if event == "LOOT_BAG_CHANGED" then
		Analysis.ScheduleBagDropSync()
		Analysis.SyncMoneyEarned()
		return
	end
	if event == "LOOT_BAG_CLOSE" then
		runtime.pendingBagSyncUntil = nil
		Analysis.SyncBagDrops(true)
		Analysis.SyncMoneyEarned()
		return
	end
	if event == "EXP_CHANGED" then
		Analysis.CaptureSessionActivityLocation()
		Analysis.HandleExpChangedEvent(...)
		return
	end
	if event == "SPELLCAST_START" or event == "SPELLCAST_SUCCEEDED" then
		Analysis.HandleSpellcastEvent(event, ...)
		return
	end
	if event == "TARGET_CHANGED" then
		Analysis.CaptureCurrentTarget("target_switch")
		Analysis.MarkPendingTargetSwitched(runtime.currentTargetKey)
		runtime.currentTargetKey = nil
		runtime.currentTargetName = nil
		runtime.currentTargetDeathCounted = false
	end
	if event == "ENTERED_WORLD" then
		Analysis.SaveSessionHistory()
		return
	end
	if event == "UPDATE_ZONE_LEVEL_INFO" then
		return
	end
	Analysis.UpdateCurrentTarget()
end
eventWindow:SetHandler("OnEvent", eventWindow.OnEvent)

eventWindow:RegisterEvent("COMBAT_MSG")
eventWindow:RegisterEvent("COMBAT_TEXT")
eventWindow:RegisterEvent("ITEM_ACQUISITION_BY_LOOT")
eventWindow:RegisterEvent("MONEY_ACQUISITION_BY_LOOT")
eventWindow:RegisterEvent("LOOT_BAG_CHANGED")
eventWindow:RegisterEvent("LOOT_BAG_CLOSE")
eventWindow:RegisterEvent("EXP_CHANGED")
eventWindow:RegisterEvent("SPELLCAST_START")
eventWindow:RegisterEvent("SPELLCAST_SUCCEEDED")
eventWindow:RegisterEvent("UNIT_COMBAT_STATE_CHANGED")
eventWindow:RegisterEvent("UNIT_DEAD")
eventWindow:RegisterEvent("UNIT_DEAD_NOTICE")
eventWindow:RegisterEvent("PLAYER_RESURRECTED")
eventWindow:RegisterEvent("TARGET_CHANGED")
eventWindow:RegisterEvent("TARGET_TO_TARGET_CHANGED")
eventWindow:RegisterEvent("AGGRO_METER_CLEARED")
eventWindow:RegisterEvent("ENTERED_LOADING")
eventWindow:RegisterEvent("LEFT_LOADING")
eventWindow:RegisterEvent("ENTERED_WORLD")
eventWindow:RegisterEvent("UPDATE_ZONE_LEVEL_INFO")

function Analysis.RegisterPlayerMoneyHandler()
	runtime.playerMoneyHandlerRegistered = false
	if UIParent == nil or UIEVENT_TYPE == nil or UIEVENT_TYPE.PLAYER_MONEY == nil then
		return false
	end
	if type(UIParent.SetEventHandler) ~= "function" then
		return false
	end

	local ok = pcall(function()
		UIParent:SetEventHandler(UIEVENT_TYPE.PLAYER_MONEY, function(change, changeStr)
			Analysis.HandlePlayerMoneyChanged(change, changeStr)
		end)
	end)
	runtime.playerMoneyHandlerRegistered = ok == true
	return runtime.playerMoneyHandlerRegistered
end

Analysis.RegisterPlayerMoneyHandler()

function eventWindow:OnUpdate(dt)
	if not runtime.active then
		return
	end

	local now = Analysis.RefreshClock()
	local delta = NormalizeDt(dt)
	if delta <= 0 and runtime.lastUpdateTime ~= nil then
		delta = now - runtime.lastUpdateTime
	end
	runtime.lastUpdateTime = now
	runtime.updateElapsed = runtime.updateElapsed + delta
	if runtime.updateElapsed < 0.15 then
		return
	end
	local locationTickElapsed = runtime.updateElapsed
	runtime.updateElapsed = 0
	if runtime.savePending == true then
		runtime.saveElapsed = (tonumber(runtime.saveElapsed) or 0) + locationTickElapsed
		Analysis.FlushSessionDataSave(false)
	end
	if not runtime.gameLoadingStarted then
		runtime.locationRefreshElapsed = (tonumber(runtime.locationRefreshElapsed) or 0) + locationTickElapsed
		if runtime.locationRefreshElapsed >= 0.5 then
			runtime.locationRefreshElapsed = 0
			Analysis.CaptureCurrentSessionLocation()
		end
	end
	Analysis.UpdatePendingKillMapOverlay(locationTickElapsed)
	Analysis.SyncSessionResourceSnapshots()
	Analysis.SyncLocalPlayerDeathState()
	if runtime.pendingBagSyncUntil ~= nil then
		Analysis.SyncBagDrops(false)
		if now >= runtime.pendingBagSyncUntil then
			runtime.pendingBagSyncUntil = nil
		end
	end
	Analysis.EvaluateKillCombatEnd(now)
	Analysis.PruneTargetSnapshots()
	Analysis.PrunePendingTargetHits()
	runtime.targetRefreshElapsed = (tonumber(runtime.targetRefreshElapsed) or 0) + locationTickElapsed
	if runtime.targetRefreshElapsed >= Analysis.TARGET_REFRESH_INTERVAL_SECONDS then
		runtime.targetRefreshElapsed = 0
		runtime.targetRefreshDirty = false
		Analysis.UpdateCurrentTarget()
	end
end
eventWindow:SetHandler("OnUpdate", eventWindow.OnUpdate)

Analysis.UpdateCounterWindow()

