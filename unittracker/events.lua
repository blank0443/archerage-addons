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

local SetLabelColor = UT.SetLabelColor
local SetButtonTextColor = UT.SetButtonTextColor
local FormatNotePreview = UT.FormatNotePreview
local EstimateLabelPaintWidth = UT.EstimateLabelPaintWidth
local FitTextToLabelWidth = UT.FitTextToLabelWidth
local MeasureLabelTextWidth = UT.MeasureLabelTextWidth

listSave.LoadListsWithRecovery()
hotkeys.Load()
hotkeys.RegisterAll()
settings.Load()
runtime.faction.CaptureLocal()
UT.CreateTrackerWindow()
UT.RefreshTargetState()

if runtime.launchButton == nil then
	runtime.launchButton = CreateSimpleButton("Unit Tracker", 700, -430)
	runtime.launchButton:SetHandler("OnClick", function()
		if runtime.window ~= nil and runtime.window:IsVisible() then
			UT.HideTrackerWindow()
		else
			UT.ShowTrackerWindow()
		end
	end)
end

local eventWindow = CreateEmptyWindow("unitTrackerEventWindow", "UIParent")
runtime.eventWindow = eventWindow
-- Keep shown so HOTKEY_ACTION is delivered reliably (hidden windows can miss it).
eventWindow:SetExtent(1, 1)
eventWindow:AddAnchor("TOPLEFT", "UIParent", -100, -100)
eventWindow:Show(true)

function eventWindow:OnUpdate(dt)
	if not runtime.active or runtime.loading then
		return
	end
	listSave.UpdateExportNotify()
	runtime.map.UpdatePendingOverlay(dt)

	local delta = tonumber(dt) or 0
	if delta > 1 then
		delta = delta / 1000
	end

	runtime.updateElapsed = runtime.updateElapsed + delta
	if runtime.updateElapsed < timing.TARGET_REFRESH_SECONDS then
		return
	end
	runtime.updateElapsed = 0
	-- Local camp may be unavailable at file load; keep trying until captured.
	if not runtime.localFactionReady then
		if runtime.faction.CaptureLocal() and runtime.RefreshViewList ~= nil then
			runtime.RefreshViewList()
		end
	end
	listSave.MaybeRetryImportRecovery()
	listSave.FlushPending()
	listSave.MaybePruneSourceCaches()
	UT.RefreshTargetState()
end
eventWindow:SetHandler("OnUpdate", eventWindow.OnUpdate)

function eventWindow:OnEvent(event, ...)
	if not runtime.active then
		return
	end
	if event == "ENTERED_LOADING" then
		-- Flush pending list writes before loading can tear down the session.
		listSave.FlushNow()
		runtime.loading = true
		UT.HideTrackerWindow()
		return
	end
	if event == "LEFT_LOADING" then
		runtime.loading = false
		return
	end
	if event == "TARGET_CHANGED" or event == "ENTERED_WORLD" then
		if event == "ENTERED_WORLD" then
			-- Unit ids can change across zones; drop the cache so it re-derives.
			runtime.loading = false
			runtime.localPlayerUnitId = nil
			-- Re-capture local camp after zoning (do not wipe a known camp until replace succeeds).
			runtime.localFactionReady = false
			runtime.localPlayerFaction = ""
			runtime.localPlayerFactionRaw = ""
			runtime.faction.CaptureLocal()
			UT.ClearSessionUnitIds()
			-- Allow marker writes again after zoning/loading.
			runtime.markerWriteAttempts = {}
			listSave.FlushNow()
			hotkeys.RegisterAll()
		end
		if runtime.loading then
			return
		end
		UT.RefreshTargetState()
	elseif event == "HOTKEY_ACTION" then
		if runtime.loading then
			return
		end
		hotkeys.OnAction(...)
	elseif event == "COMBAT_MSG" then
		if not settings.IsAutoOpenDamage() then
			return
		end
		if runtime.loading then
			return
		end
		local eventType = tostring(select(2, ...) or "")
		if string.find(eventType, "DAMAGE", 1, true) == nil then
			return
		end
		local unitId = select(1, ...)
		local targetName = UT.Trim(select(4, ...) or "")
		-- Only incoming damage to the local player matters; discard everyone else's
		-- combat spam before allocating a table (cheap unit-id check first).
		if UT.Trim(tostring(unitId or "")) ~= "player" and not UT.IsLocalPlayerName(targetName) then
			return
		end
		local sourceName = UT.Trim(select(3, ...) or "")
		-- targetName may be empty when unitId already identifies the local player.
		if sourceName == "" then
			return
		end
		local msg = {
			unitId = unitId,
			eventType = eventType,
			sourceName = sourceName,
			targetName = targetName,
			abilityId = select(5, ...),
			effectType = select(8, ...),
		}
		if UT.IsIncomingPlayerDamage(msg) then
			UT.OpenTrackerWindowForIncomingDamage()
		elseif UT.IsIncomingDamageCandidate(msg) then
			UT.RememberPendingDamageSourceName(msg.sourceName)
		end
	elseif event == "COMBAT_TEXT" then
		UT.HandleCombatTextMessage(...)
	end
end
eventWindow:SetHandler("OnEvent", eventWindow.OnEvent)
eventWindow:RegisterEvent("TARGET_CHANGED")
eventWindow:RegisterEvent("ENTERED_WORLD")
eventWindow:RegisterEvent("ENTERED_LOADING")
eventWindow:RegisterEvent("LEFT_LOADING")
eventWindow:RegisterEvent("HOTKEY_ACTION")
eventWindow:RegisterEvent("COMBAT_MSG")
eventWindow:RegisterEvent("COMBAT_TEXT")