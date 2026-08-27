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

settings.ON_COLOR = LIST_COLORS.friendly
settings.OFF_COLOR = LIST_COLORS.hostile

function settings.CoerceBool(value, default)
	if value == nil then
		return default ~= false
	end
	return value == true
end

function settings.Save()
	SaveData(persist.SETTINGS_KEY, {
		autoOpenDamage = runtime.settings.autoOpenDamage == true,
		autoOpenListedTarget = runtime.settings.autoOpenListedTarget == true,
	})
end

function settings.Load()
	runtime.settings.autoOpenDamage = true
	runtime.settings.autoOpenListedTarget = true
	local data = LoadData(persist.SETTINGS_KEY)
	if type(data) ~= "table" then
		return
	end
	runtime.settings.autoOpenDamage = settings.CoerceBool(data.autoOpenDamage, true)
	runtime.settings.autoOpenListedTarget = settings.CoerceBool(data.autoOpenListedTarget, true)
end

function settings.IsAutoOpenDamage()
	return runtime.settings.autoOpenDamage == true
end

function settings.IsAutoOpenListedTarget()
	return runtime.settings.autoOpenListedTarget == true
end

function settings.ButtonLabel(key)
	local on = runtime.settings[key] == true
	if key == "autoOpenDamage" then
		if on then
			return "Dmg popup: On"
		end
		return "Dmg popup: Off"
	end
	if on then
		return "List popup: On"
	end
	return "List popup: Off"
end

function settings.RefreshButtons()
	local optsWindow = runtime.optsWindow
	if optsWindow == nil then
		return
	end

	local function Paint(button, key)
		if button == nil then
			return
		end
		button:SetText(settings.ButtonLabel(key))
		local color = settings.OFF_COLOR
		if runtime.settings[key] == true then
			color = settings.ON_COLOR
		end
		SafeCall(button, "SetTextColor", color[1], color[2], color[3], color[4])
	end

	Paint(optsWindow.damagePopupButton, "autoOpenDamage")
	Paint(optsWindow.listPopupButton, "autoOpenListedTarget")
end

function settings.Toggle(key)
	if key ~= "autoOpenDamage" and key ~= "autoOpenListedTarget" then
		return
	end
	runtime.settings[key] = runtime.settings[key] ~= true
	settings.Save()
	settings.RefreshButtons()
end
