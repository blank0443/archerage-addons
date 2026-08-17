-- Shared loottracker helpers (Trim/SafeCall/clock/positions).
local LT = _G.__LOOT_TRACKER
if LT == nil then
	return
end
local C = LT.C

function LT.SafeCall(target, methodName, ...)
	if target == nil or type(target[methodName]) ~= "function" then
		return false, nil
	end
	return pcall(target[methodName], target, ...)
end

-- Tracker historically used SafeMethod; keep both names.
function LT.SafeMethod(target, methodName, ...)
	if target == nil then
		return false
	end
	local fn = target[methodName]
	if type(fn) ~= "function" then
		return false
	end
	return pcall(fn, target, ...)
end

function LT.SafeNumber(value, fallback)
	local number = tonumber(value)
	if number == nil then
		return fallback
	end
	return number
end

function LT.SafeCallValues(target, methodName, ...)
	if target == nil or type(target[methodName]) ~= "function" then
		return false
	end
	return pcall(target[methodName], target, ...)
end

function LT.Trim(value)
	local text = tostring(value or "")
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	return text
end

function LT.NormalizeName(value)
	local text = string.lower(LT.Trim(value))
	text = string.gsub(text, "%s+", " ")
	return text
end

function LT.IsValidName(value)
	return type(value) == "string" and LT.Trim(value) ~= ""
end

function LT.NamesMatch(left, right)
	if not LT.IsValidName(left) or not LT.IsValidName(right) then
		return false
	end
	return LT.NormalizeName(left) == LT.NormalizeName(right)
end

function LT.NormalizeDt(dt)
	local value = tonumber(dt) or 0
	if value > 10 then
		value = value / 1000
	end
	return value
end

function LT.IsRightMouseButton(mouseButton)
	local buttonText = tostring(mouseButton or "")
	return buttonText == "RightButton" or buttonText == "right" or buttonText == "RIGHT" or buttonText == "2"
end

function LT.Now()
	if os ~= nil and type(os.clock) == "function" then
		local ok, value = pcall(os.clock)
		if ok and tonumber(value) ~= nil then
			return tonumber(value)
		end
	end
	return 0
end

-- Alias used by tracker code paths.
LT.CurrentClock = LT.Now

function LT.CompactNameLimit(value, limit)
	local text = tostring(value or "")
	limit = tonumber(limit) or 0
	if limit < 1 or string.len(text) <= limit then
		return text
	end
	if limit <= 3 then
		return string.sub(text, 1, limit)
	end
	return string.sub(text, 1, limit - 3) .. "..."
end

function LT.SaveData(key, value)
	pcall(function()
		ADDON:ClearData(key)
		ADDON:SaveData(key, value)
	end)
end

function LT.LoadData(key)
	local ok, data = pcall(function()
		return ADDON:LoadData(key)
	end)
	if ok then
		return data
	end
	return nil
end

function LT.GetWidgetPosition(widget)
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

-- Tracker prefers effective/screen offset when available (drag lag).
function LT.GetWidgetSavedPosition(widget)
	if widget == nil then
		return nil, nil
	end

	if type(widget.GetEffectiveOffset) == "function" then
		local okEffective, effectiveX, effectiveY = pcall(widget.GetEffectiveOffset, widget)
		if okEffective and effectiveX ~= nil and effectiveY ~= nil then
			return math.floor((effectiveX or 0) + 0.5), math.floor((effectiveY or 0) + 0.5)
		end
	end

	local ok, offsetX, offsetY = pcall(function()
		return widget:GetOffset()
	end)
	if not ok or offsetX == nil or offsetY == nil then
		return nil, nil
	end

	return math.floor((offsetX or 0) + 0.5), math.floor((offsetY or 0) + 0.5)
end

function LT.SaveWidgetPosition(widget, key)
	local x, y = LT.GetWidgetPosition(widget)
	if x == nil or y == nil then
		return
	end
	LT.SaveData(key, { x = x, y = y })
end

function LT.SaveWidgetSavedPosition(widget, key)
	if widget == nil or key == nil then
		return
	end

	local x, y = LT.GetWidgetSavedPosition(widget)
	if x == nil or y == nil then
		return
	end

	pcall(function()
		ADDON:ClearData(key)
		ADDON:SaveData(key, {
			x = x,
			y = y,
			version = 2,
		})
	end)
end

function LT.LoadPosition(key, defaultX, defaultY)
	local data = LT.LoadData(key)
	if type(data) == "table" and data.x ~= nil and data.y ~= nil then
		return tonumber(data.x) or defaultX, tonumber(data.y) or defaultY
	end
	return defaultX, defaultY
end

function LT.LoadSavedPosition(key, defaultX, defaultY)
	local ok, data = pcall(function()
		return ADDON:LoadData(key)
	end)
	if ok and type(data) == "table" and data.x ~= nil and data.y ~= nil then
		return tonumber(data.x) or defaultX, tonumber(data.y) or defaultY, true
	end
	return defaultX, defaultY, false
end

function LT.ClampWindowScale(scale)
	scale = tonumber(scale) or 1
	if scale < C.MIN_WINDOW_SCALE then
		return C.MIN_WINDOW_SCALE
	end
	if scale > C.MAX_WINDOW_SCALE then
		return C.MAX_WINDOW_SCALE
	end
	return scale
end

function LT.RoundScaled(value, scale)
	local scaled = math.floor((value * scale) + 0.5)
	if scaled < 1 then
		return 1
	end
	return scaled
end

function LT.SetWidgetFontSize(widget, size)
	if widget ~= nil and widget.style ~= nil and type(widget.style.SetFontSize) == "function" then
		widget.style:SetFontSize(size)
	end
end

function LT.AnchorWidgetAtPosition(widget, x, y)
	if widget == nil then
		return
	end
	LT.SafeCall(widget, "RemoveAllAnchors")
	widget:AddAnchor("TOPLEFT", "UIParent", math.floor((tonumber(x) or 0) + 0.5), math.floor((tonumber(y) or 0) + 0.5))
end
