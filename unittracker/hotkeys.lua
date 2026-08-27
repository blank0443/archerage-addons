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

hotkeys.ACTION_FRIENDLY = "UNIT_TRACKER_ADD_FRIENDLY"
hotkeys.ACTION_HOSTILE = "UNIT_TRACKER_ADD_HOSTILE"

function hotkeys.GetActionName(listName)
	if listName == "friendly" then
		return hotkeys.ACTION_FRIENDLY
	end
	if listName == "hostile" then
		return hotkeys.ACTION_HOSTILE
	end
	return nil
end

function hotkeys.NormalizeKeyName(key)
	key = Trim(tostring(key or ""))
	if key == "" then
		return ""
	end
	key = string.upper(key)
	if key == "CONTROL" or key == "LCTRL" or key == "RCTRL" then
		return "CTRL"
	end
	if key == "LSHIFT" or key == "RSHIFT" then
		return "SHIFT"
	end
	if key == "LALT" or key == "RALT" or key == "MENU" then
		return "ALT"
	end
	-- Grave/tilde (`~) — OnKeyDown often reports "`"; X2 expects OEM_3.
	if key == "`" or key == "~" or key == "GRAVE" or key == "GRAVEACCENT"
		or key == "BACKTICK" or key == "BACKQUOTE" or key == "OEM3" or key == "OEM_3"
	then
		return "OEM_3"
	end
	if string.match(key, "^NUMPAD(%d)$") then
		return "NUMBER" .. string.match(key, "^NUMPAD(%d)$")
	end
	if key == "NUMPADPLUS" or key == "NUMPAD+" then
		return "NUMBER+"
	end
	if key == "NUMPADMINUS" or key == "NUMPAD-" then
		return "NUMBER-"
	end
	if key == "NUMPADMULTIPLY" or key == "NUMPAD*" then
		return "NUMBER*"
	end
	if key == "NUMPADDIVIDE" or key == "NUMPAD/" then
		return "NUMBER/"
	end
	return key
end

function hotkeys.IsModifierOnly(key)
	key = hotkeys.NormalizeKeyName(key)
	return key == "SHIFT" or key == "CTRL" or key == "ALT" or key == "CONTROL"
end

function hotkeys.IsModifierDown(methodName)
	local ok, value = SafeCall(X2Input, methodName)
	return ok and value == true
end

function hotkeys.BuildCapturedString(key)
	key = hotkeys.NormalizeKeyName(key)
	if key == "" or hotkeys.IsModifierOnly(key) then
		return nil
	end
	if key == "ESCAPE" or key == "ESC" then
		return "ESCAPE"
	end

	-- Match combatcloset: at most one modifier prefix (Ctrl/Shift/Alt).
	local modifier = nil
	if hotkeys.IsModifierDown("IsControlKeyDown") then
		modifier = "Ctrl"
	elseif hotkeys.IsModifierDown("IsShiftKeyDown") then
		modifier = "Shift"
	elseif hotkeys.IsModifierDown("IsAltKeyDown") then
		modifier = "Alt"
	end

	if modifier ~= nil then
		return modifier .. "-" .. key
	end
	return key
end

-- Display-friendly label for saved API binding strings.
function hotkeys.DisplayBinding(binding)
	binding = Trim(tostring(binding or ""))
	if binding == "" then
		return ""
	end
	binding = string.gsub(binding, "OEM_3", "`")
	return binding
end

-- Match combatcloset: SetBindingUiEvent is the primary path.
-- If the engine does not confirm the bind, fall back to BindingToOption → set → SaveHotKey → OptionToBinding.
function hotkeys.ApplyEngineBinding(actionName, binding)
	if actionName == nil or X2Hotkey == nil or type(X2Hotkey.SetBindingUiEvent) ~= "function" then
		return false, "X2Hotkey unavailable"
	end
	binding = Trim(tostring(binding or ""))

	local ok, err = pcall(function()
		X2Hotkey:SetBindingUiEvent(actionName, binding)
	end)
	if not ok then
		return false, err
	end

	-- Clearing: no need for option-stage fallback.
	if binding == "" then
		return true, nil
	end

	local confirmed = Trim(tostring(hotkeys.ReadEngineBinding(actionName) or ""))
	if confirmed ~= "" then
		return true, nil
	end

	-- Fallback path (options UI transaction) when direct UI-event bind did not stick.
	if type(X2Hotkey.BindingToOption) == "function" then
		pcall(function()
			X2Hotkey:BindingToOption()
		end)
	end
	pcall(function()
		X2Hotkey:SetBindingUiEvent(actionName, binding)
	end)
	if type(X2Hotkey.SetOptionBindingUiEvent) == "function" then
		pcall(function()
			X2Hotkey:SetOptionBindingUiEvent(actionName, binding)
		end)
	end
	if type(X2Hotkey.SaveHotKey) == "function" then
		pcall(function()
			X2Hotkey:SaveHotKey()
		end)
	end
	if type(X2Hotkey.OptionToBinding) == "function" then
		pcall(function()
			X2Hotkey:OptionToBinding()
		end)
	end

	return true, nil
end

function hotkeys.ReadEngineBinding(actionName)
	if actionName == nil or X2Hotkey == nil or type(X2Hotkey.GetBindingUiEvent) ~= "function" then
		return nil
	end
	local ok, value = pcall(function()
		return X2Hotkey:GetBindingUiEvent(actionName, 0)
	end)
	if ok then
		return value
	end
	ok, value = pcall(function()
		return X2Hotkey:GetBindingUiEvent(actionName, 1)
	end)
	if ok then
		return value
	end
	return nil
end

function hotkeys.UnregisterList(listName)
	local actionName = hotkeys.GetActionName(listName)
	if actionName == nil then
		return
	end

	-- Mark inactive first so any HOTKEY_ACTION that still fires is ignored
	-- (same idea as combatcloset clearing set.HotkeyAction).
	if runtime.hotkeysActive == nil then
		runtime.hotkeysActive = {}
	end
	runtime.hotkeysActive[listName] = nil

	hotkeys.ApplyEngineBinding(actionName, "")
end

function hotkeys.RegisterList(listName)
	local actionName = hotkeys.GetActionName(listName)
	if actionName == nil then
		return false
	end
	local binding = Trim(tostring(runtime.hotkeys[listName] or ""))
	if binding == "" then
		hotkeys.UnregisterList(listName)
		return false
	end
	if runtime.hotkeysActive == nil then
		runtime.hotkeysActive = {}
	end
	runtime.hotkeysActive[listName] = actionName

	local ok, err = hotkeys.ApplyEngineBinding(actionName, binding)
	if not ok then
		-- Keep active so a later ENTERED_WORLD re-register can recover; report failure.
		if UT.DispatchExportStatus ~= nil then
			UT.DispatchExportStatus(
				"[Unit Tracker] Failed to bind " .. listName .. " (" .. tostring(err) .. ")."
			)
		end
		return false
	end
	return true
end

function hotkeys.RegisterAll()
	hotkeys.RegisterList("friendly")
	hotkeys.RegisterList("hostile")
end

function hotkeys.Save()
	SaveData(persist.HOTKEY_SAVE_KEY, {
		friendly = runtime.hotkeys.friendly or "",
		hostile = runtime.hotkeys.hostile or "",
	})
end

function hotkeys.Load()
	runtime.hotkeys.friendly = ""
	runtime.hotkeys.hostile = ""
	runtime.hotkeysActive = {
		friendly = nil,
		hostile = nil,
	}
	local data = LoadData(persist.HOTKEY_SAVE_KEY)
	if type(data) ~= "table" then
		return
	end
	-- Migrate older saves that stored literal "`" instead of OEM_3.
	local function MigrateBinding(value)
		value = Trim(tostring(value or ""))
		value = string.gsub(value, "`", "OEM_3")
		value = string.gsub(value, "~", "OEM_3")
		return value
	end
	runtime.hotkeys.friendly = MigrateBinding(data.friendly)
	runtime.hotkeys.hostile = MigrateBinding(data.hostile)
end

function hotkeys.ButtonLabel(listName)
	local title = listName == "friendly" and "Friendly" or "Hostile"
	if runtime.hotkeyCapture == listName then
		return "Press key..."
	end
	local binding = Trim(tostring(runtime.hotkeys[listName] or ""))
	if binding ~= "" then
		return title .. " [" .. hotkeys.DisplayBinding(binding) .. "]"
	end
	return title
end

function hotkeys.RefreshButtons()
	local optsWindow = runtime.optsWindow
	if optsWindow == nil then
		return
	end
	if optsWindow.friendlyHotkeyButton ~= nil then
		optsWindow.friendlyHotkeyButton:SetText(hotkeys.ButtonLabel("friendly"))
		SafeCall(
			optsWindow.friendlyHotkeyButton,
			"SetTextColor",
			LIST_COLORS.friendly[1],
			LIST_COLORS.friendly[2],
			LIST_COLORS.friendly[3],
			LIST_COLORS.friendly[4]
		)
	end
	if optsWindow.hostileHotkeyButton ~= nil then
		optsWindow.hostileHotkeyButton:SetText(hotkeys.ButtonLabel("hostile"))
		SafeCall(
			optsWindow.hostileHotkeyButton,
			"SetTextColor",
			LIST_COLORS.hostile[1],
			LIST_COLORS.hostile[2],
			LIST_COLORS.hostile[3],
			LIST_COLORS.hostile[4]
		)
	end
end


function hotkeys.CancelCapture()
	if runtime.hotkeyCapture == nil then
		return
	end
	runtime.hotkeyCapture = nil
	if runtime.hotkeyCaptureInput ~= nil then
		SafeCall(runtime.hotkeyCaptureInput, "SetFocus", false)
	end
	hotkeys.RefreshButtons()
end

function hotkeys.Assign(listName, binding)
	binding = Trim(tostring(binding or ""))
	if listName ~= "friendly" and listName ~= "hostile" then
		return
	end

	if binding ~= "" then
		if listName == "friendly" and runtime.hotkeys.hostile == binding then
			runtime.hotkeys.hostile = ""
			hotkeys.UnregisterList("hostile")
		elseif listName == "hostile" and runtime.hotkeys.friendly == binding then
			runtime.hotkeys.friendly = ""
			hotkeys.UnregisterList("friendly")
		end
	end

	runtime.hotkeys[listName] = binding
	if binding == "" then
		hotkeys.UnregisterList(listName)
	else
		local registered = hotkeys.RegisterList(listName)
		-- If OEM_3 form failed to stick, retry with literal grave character.
		if registered and string.find(binding, "OEM_3", 1, true) ~= nil then
			local actionName = hotkeys.GetActionName(listName)
			local engineValue = Trim(tostring(hotkeys.ReadEngineBinding(actionName) or ""))
			if engineValue == "" then
				local alt = string.gsub(binding, "OEM_3", "`")
				runtime.hotkeys[listName] = alt
				hotkeys.RegisterList(listName)
				binding = alt
			end
		end
	end
	hotkeys.Save()
	hotkeys.RefreshButtons()

	local title = listName == "friendly" and "Friendly" or "Hostile"
	if binding == "" then
		UT.DispatchExportStatus("[Unit Tracker] " .. title .. " hotkey cleared.")
	else
		local actionName = hotkeys.GetActionName(listName)
		local engineValue = Trim(tostring(hotkeys.ReadEngineBinding(actionName) or ""))
		local display = hotkeys.DisplayBinding(binding)
		if engineValue ~= "" then
			UT.DispatchExportStatus(
				"[Unit Tracker] " .. title .. " hotkey set to " .. display
					.. " (engine: " .. hotkeys.DisplayBinding(engineValue) .. ")."
			)
		else
			UT.DispatchExportStatus(
				"[Unit Tracker] " .. title .. " hotkey saved as " .. display
					.. " but engine did not confirm the bind. Try F5/F6 instead of Ctrl-`."
			)
		end
	end
end

function hotkeys.BeginCapture(listName)
	if listName ~= "friendly" and listName ~= "hostile" then
		return
	end
	runtime.hotkeyCapture = listName
	hotkeys.RefreshButtons()
	if runtime.hotkeyCaptureInput ~= nil then
		SafeCall(runtime.hotkeyCaptureInput, "ClearText")
		SafeCall(runtime.hotkeyCaptureInput, "SetText", "")
		SafeCall(runtime.hotkeyCaptureInput, "SetFocus", true)
		SafeCall(runtime.hotkeyCaptureInput, "SetFocus")
	end
	UT.DispatchExportStatus("[Unit Tracker] Press a key for " .. listName .. " (Esc to cancel).")
end

function hotkeys.HandleCaptureKey(key)
	if runtime.hotkeyCapture == nil then
		return false
	end

	local binding = hotkeys.BuildCapturedString(key)
	if binding == nil then
		return true
	end
	if binding == "ESCAPE" then
		hotkeys.CancelCapture()
		UT.DispatchExportStatus("[Unit Tracker] Hotkey capture cancelled.")
		return true
	end

	local listName = runtime.hotkeyCapture
	runtime.hotkeyCapture = nil
	if runtime.hotkeyCaptureInput ~= nil then
		SafeCall(runtime.hotkeyCaptureInput, "SetFocus", false)
	end
	hotkeys.Assign(listName, binding)
	return true
end

function hotkeys.OnAction(...)
	local arg1, arg2, arg3 = ...
	local actionName = nil
	local isReleased = nil
	-- Engine may pass (actionName, isReleased) or (self, actionName, isReleased).
	if type(arg1) == "string" then
		actionName = arg1
		isReleased = arg2
	elseif type(arg2) == "string" then
		actionName = arg2
		isReleased = arg3
	else
		return
	end

	if isReleased == true then
		return
	end
	if runtime.hotkeyCapture ~= nil then
		return
	end

	-- Ignore engine events unless this action is still active (cleared via X).
	local active = runtime.hotkeysActive
	if type(active) ~= "table" then
		return
	end
	if actionName == hotkeys.ACTION_FRIENDLY
		and active.friendly == hotkeys.ACTION_FRIENDLY
		and Trim(tostring(runtime.hotkeys.friendly or "")) ~= ""
	then
		if UT.AddCurrentTargetToList("friendly") and runtime.window ~= nil then
			runtime.window:Show(true)
		end
	elseif actionName == hotkeys.ACTION_HOSTILE
		and active.hostile == hotkeys.ACTION_HOSTILE
		and Trim(tostring(runtime.hotkeys.hostile or "")) ~= ""
	then
		if UT.AddCurrentTargetToList("hostile") and runtime.window ~= nil then
			runtime.window:Show(true)
		end
	end
end
