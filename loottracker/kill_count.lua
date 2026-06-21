if API_TYPE == nil then
	return
end

ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)

ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.PLAYER.id)
ADDON:ImportAPI(API_TYPE.BAG.id)
ADDON:ImportAPI(API_TYPE.WORLD.id)
ADDON:ImportAPI(API_TYPE.MAP.id)

local SAVE_KEY = "lootKillCounterKills"
local SETTINGS_SAVE_KEY = "lootKillCounterSettings"
local HISTORY_SAVE_KEY = "lootKillCounterHistory"
local WINDOW_POSITION_KEY = "lootKillCounterWindowPosition"
local WINDOW_SIZE_KEY = "lootKillCounterWindowSize"
local VIEW_WINDOW_POSITION_KEY = "lootKillCounterViewWindowPosition"
local WINDOW_WIDTH = 286
local WINDOW_HEIGHT = 272
local MIN_WINDOW_WIDTH = 270
local MIN_WINDOW_HEIGHT = 250
local VIEW_WINDOW_WIDTH = 440
local VIEW_WINDOW_HEIGHT = 560
local VIEW_ROW_TOP = 76
local VIEW_ROW_HEIGHT = 15
local VIEW_CONTENT_ROW_COUNT = 31
local BAG_KIND = 1
local MAX_BAG_SLOTS = 150
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
local LOOT_ATTRIBUTION_SECONDS = 20
local EXP_ATTRIBUTION_SECONDS = 8
local COMBAT_IDLE_TIMEOUT = 6
local PLAYER_COMBAT_EXIT_GRACE = 1.5
local PENDING_CAPTURE_DEDUPE_SECONDS = 0.35
local MAX_PENDING_HITS_PER_TARGET = 4
local MAX_PENDING_HITS_TOTAL = 20
local ZONE_GROUP_NAMES = {
	[1] = "Gweonid Forest",
	[2] = "Marianople",
	[3] = "Dewstone Plains",
	[4] = "Solis Headlands",
	[5] = "Solzreed Peninsula",
	[6] = "Lilyut Hills",
	[7] = "Arcum Iris",
	[8] = "Two Crowns",
	[9] = "Mahadevi",
	[10] = "Airain Rock",
	[11] = "Falcorth Plains",
	[12] = "Villanelle",
	[13] = "Sunbite Wilds",
	[14] = "Windscour Savannah",
	[15] = "Perinoor Ruins",
	[16] = "Rookborne Basin",
	[17] = "Ynystere",
	[18] = "White Arden",
	[19] = "Karkasse Ridgelands",
	[20] = "Cinderstone Moor",
	[21] = "Aubre Cradle",
	[22] = "Halcyona",
	[23] = "Hasla",
	[24] = "Tigerspine Mountains",
	[25] = "Silent Forest",
	[26] = "Hellswamp",
	[27] = "Sanddeep",
	[28] = "The Wastes",
	[29] = "Libertia Sea",
	[30] = "Castaway Strait",
	[31] = "Drill Camp",
	[32] = "Dreadnought",
	[33] = "Heedmar",
	[34] = "Nuimari",
	[36] = "Arcadian Sea",
	[39] = "Halcyona Gulf",
	[40] = "Feuille Sound",
	[41] = "Forbidden Sea",
	[42] = "Forbidden Shore",
	[43] = "Marcala",
	[44] = "Calmlands",
	[45] = "Burnt Castle Armory",
	[46] = "Hadir Farm",
	[47] = "Palace Cellar",
	[48] = "Saltswept Atoll",
	[49] = "Mirage Isle",
	[50] = "Sharpwind Mines",
	[51] = "Howling Abyss",
	[52] = "Kroloal Cradle",
	[53] = "Violent Maelstrom Arena",
	[54] = "Exeloch",
	[55] = "Serpentis",
	[56] = "Sungold Fields",
	[57] = "Golden Ruins",
	[58] = "Greater Howling Abyss",
	[59] = "Sunspeck Sea",
	[60] = "Stormraw Sound",
	[61] = "Diamond Shores",
	[62] = "Sea of Drowned Love",
	[63] = "Reedwind",
	[64] = "Lesser Sea of Drowned Love",
	[65] = "Verdant Skychamber",
	[66] = "Lesser Serpentis",
	[67] = "Introspect Path",
	[68] = "Lucius's Dream",
	[69] = "Evening Botanica",
	[70] = "Encyclopedia Room",
	[71] = "Libris Garden",
	[72] = "Screaming Archives",
	[73] = "Screening Hall",
	[74] = "Frozen Study",
	[75] = "Deranged Bookroom",
	[76] = "Corner Reading Room",
	[77] = "Gladiator Arena",
	[78] = "Mistmerrow",
	[79] = "Miroir Tundra",
	[80] = "Shattered Sea",
	[81] = "New Arena",
	[82] = "Epherium",
	[83] = "Greater Hadir Farm",
	[84] = "Greater Burnt Castle Armory",
	[85] = "Heart of Ayanad",
	[86] = "Greater Palace Cellar",
	[87] = "Greater Sharpwind Mines",
	[88] = "Greater Kroloal Cradle",
	[89] = "Mistsong Summit",
	[90] = "Arena",
	[91] = "Decisive Arena",
	[92] = "Free-For-All Arena",
	[93] = "Ahnimar",
	[94] = "Ancient Ezna",
	[95] = "Boiling Sea",
	[96] = "Sylvina Caldera",
	[97] = "Bloodsalt Bay",
	[98] = "Queen's Chamber",
	[99] = "Rokhala Mountains",
	[100] = "Queen's Chamber",
	[101] = "Burnt Castle Cellar",
	[102] = "Aegis Island",
	[103] = "Whalesong Harbor",
	[104] = "Whaleswell Straits",
	[105] = "Ipnysh Sanctuary",
	[106] = "Snowball Arena",
	[107] = "Western Hiram Mountains",
	[108] = "Golden Plains Battle",
	[109] = "Golden Plains Battle",
	[110] = "Eastern Hiram Mountains",
	[111] = "Screening Hall (Disabled)",
	[112] = "Frozen Study (Disabled)",
	[113] = "Deranged Bookroom (Disabled)",
	[114] = "Corner Reading Room (Disabled)",
	[115] = "Heart of Ayanad (Disabled)",
	[116] = "Unused",
	[117] = "Verdant Skychamber (Disabled)",
	[118] = "Evening Botanica (Disabled)",
	[119] = "Constellation Breakroom (Disabled)",
	[120] = "Abyssal Library",
	[121] = "Red Dragon's Keep",
	[122] = "The Fall of Hiram City",
	[125] = "Noryette Challenge",
	[126] = "Mistsong Banquet",
	[127] = "Naval Survival Game (test)",
	[129] = "Stillwater Gulf",
	[130] = "Hereafter Rebellion",
	[131] = "Battle of Mistmerrow",
	[132] = "Kadum",
	[133] = "Garden of the Gods",
	[134] = "Gatekeeper Hall",
	[135] = "Dairy Cow Dreamland",
	[136] = "Circle of Authority",
	[137] = "Delphinad Mirage",
	[138] = "Test Arena",
	[139] = "Mysthrane Gorge",
	[140] = "Ipnya Ridge",
	[141] = "Skyfin War",
	[142] = "Queen's Altar",
	[143] = "Event Arena",
	[144] = "Guild House",
	[145] = "Unused",
	[146] = "Black Thorn Prison",
	[147] = "Great Prairie of the West",
	[148] = "Greater Serpentis",
	[149] = "Squid Game Event Arena",
	[150] = "Dimensional Boundary Defense Raid",
	[151] = "Ahnimar Event Arena",
	[152] = "Goldleaf Forest",
	[153] = "Make a Splash",
	[154] = "Nightmare Burnt Castle Armory",
	[155] = "Crossroads Arena",
	[156] = "Noryette Arena",
	[158] = "Island of Abundance",
	[159] = "Golden Plains Battle",
}
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
	if previousRuntime.viewWindow ~= nil then
		previousRuntime.viewWindow:Show(false)
	end
	if previousRuntime.killMapWindow ~= nil then
		previousRuntime.killMapWindow:Show(false)
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
	sessionKillCounts = {},
	damageDealtByUnit = {},
	damageTakenByUnit = {},
	damageBySkill = {},
	damageByCategory = {},
	damageByElement = {},
	healBySkill = {},
	missesBySkill = {},
	energizeBySkill = {},
	damageTakenBySource = {},
	healReceivedBySource = {},
	damageByTarget = {},
	sessionKillLocations = {},
	playerCombatStats = {},
	debuffHistory = {},
	activeDebuffsOnPlayer = {},
	nextDebuffEventId = 1,
	itemDropsByUnit = {},
	expByUnit = {},
	totalDamageDealt = 0,
	totalDamageTaken = 0,
	totalDroppedItems = 0,
	totalExpGained = 0,
	totalManaSpent = 0,
	lastPlayerMana = nil,
	lastExpSnapshot = nil,
	localPlayerName = nil,
	combatActive = false,
	combatStart = nil,
	lastCombatActivity = nil,
	totalKillTime = 0,
	lastDamage = nil,
	lastDamageTaken = nil,
	lastBagSnapshot = nil,
	pendingBagSyncUntil = nil,
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
	autoOpenCounterWindow = false,
	rows = {},
	viewContentRows = {},
	resizeHandles = {},
	historySessions = {},
	nextHistorySessionIndex = 1,
	historyPage = 1,
	gameLoadingStarted = false,
	debuffSyncElapsed = 0,
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
Analysis.DEBUFF_HISTORY_LIMIT = 50
Analysis.DEBUFF_VIEW_LIMIT = 5
Analysis.SESSION_SAVE_INTERVAL_SECONDS = 5
Analysis.SESSION_SAVE_EVENT_BATCH = 30
Analysis.KILL_LOCATION_LIMIT = 400
Analysis.KILL_MAP_HOTSPOT_LIMIT = 12
Analysis.KILL_MAP_HOTSPOT_CELL_SIZE = 54
Analysis.KILL_MAP_EFFECT_LIMIT = 18
Analysis.KILL_MAP_ROUTE_EFFECT_LIMIT = 8
Analysis.KILL_MAP_EFFECT_RETRY_SECONDS = 0.25
Analysis.KILL_MAP_EFFECT_RETRY_LIMIT = 12

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

local function SafeCallValues(target, methodName, ...)
	if target == nil or type(target[methodName]) ~= "function" then
		return false
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

local function GetLocalPlayerName()
	if IsValidName(runtime.localPlayerName) then
		return runtime.localPlayerName
	end

	local name = SafeUnitName("player")
	if name ~= nil then
		runtime.localPlayerName = name
		return runtime.localPlayerName
	end

	local ok, worldName = SafeCall(X2Unit, "UnitNameWithWorld", "player")
	if ok and IsValidName(worldName) then
		runtime.localPlayerName = Trim(worldName)
		return runtime.localPlayerName
	end

	return nil
end

local function StripWorldSuffix(name)
	name = Trim(name or "")
	local atPos = string.find(name, "@", 1, true)
	if atPos ~= nil then
		return Trim(string.sub(name, 1, atPos - 1))
	end
	return name
end

local function IsLocalPlayerName(value)
	if not IsValidName(value) then
		return false
	end
	value = StripWorldSuffix(value)
	if NormalizeName(value) == "you" then
		return true
	end
	return NamesMatch(value, StripWorldSuffix(GetLocalPlayerName()))
end

local function NormalizeLocationPart(value)
	local text = Trim(value)
	if text == "" or NormalizeName(text) == "unknown" then
		return ""
	end
	return text
end

local function GetZoneGroupLocationText()
	local ok, zoneGroup = SafeCall(X2Unit, "GetCurrentZoneGroup")
	if not ok then
		return ""
	end
	return NormalizeLocationPart(ZONE_GROUP_NAMES[tonumber(zoneGroup)])
end

local function GetCurrentLocationText()
	local zone = ""
	local subZone = ""
	local ok, value = SafeCall(X2World, "GetZoneText")
	if ok then
		zone = NormalizeLocationPart(value)
	end
	ok, value = SafeCall(X2World, "GetSubZoneText")
	if ok then
		subZone = NormalizeLocationPart(value)
	end

	local region = zone
	if region == "" then
		region = GetZoneGroupLocationText()
	end

	if region ~= "" and subZone ~= "" and NormalizeName(region) ~= NormalizeName(subZone) then
		return region .. " (" .. subZone .. ")"
	end
	if region ~= "" then
		return region
	end
	return subZone
end

local function HasRuntimeSessionKills()
	for _, count in pairs(runtime.sessionKillCounts) do
		count = tonumber(count)
		if count ~= nil and count > 0 then
			return true
		end
	end
	return false
end

-- Keep the latest non-empty zone in runtime memory so portal/loading saves use
-- the zone the session took place in, not the destination after loading.
local function CaptureCurrentSessionLocation(force)
	local location = GetCurrentLocationText()
	if location ~= "" then
		if force or not HasRuntimeSessionKills() or not IsValidName(runtime.sessionLocationText) then
			runtime.sessionLocationText = location
		end
		return runtime.sessionLocationText
	end
	return runtime.sessionLocationText
end

local function CaptureSessionActivityLocation()
	local location = GetCurrentLocationText()
	if location ~= "" then
		-- Activity events can arrive while the client is already resolving the
		-- destination zone. Once kills exist, keep the farming zone we captured
		-- earlier so history names do not switch to the arrival location.
		if not HasRuntimeSessionKills() or not IsValidName(runtime.sessionLocationText) then
			runtime.sessionLocationText = location
		end
		return runtime.sessionLocationText
	end
	return runtime.sessionLocationText
end

local function CaptureLoadingStartLocation()
	local location = runtime.sessionLocationText
	if not IsValidName(location) and not HasRuntimeSessionKills() then
		location = GetCurrentLocationText()
	end
	if IsValidName(location) then
		runtime.loadingStartLocationText = location
	end
	return runtime.loadingStartLocationText
end

local function GetHistorySessionLocation()
	if IsValidName(runtime.loadingStartLocationText) then
		return runtime.loadingStartLocationText
	end
	if IsValidName(runtime.sessionLocationText) then
		return runtime.sessionLocationText
	end
	if runtime.gameLoadingStarted then
		return nil
	end
	local location = GetCurrentLocationText()
	if location ~= "" then
		return location
	end
	return nil
end

local function GetCurrentDateText()
	if os == nil or type(os.date) ~= "function" then
		return nil
	end

	local ok, dateParts = pcall(os.date, "*t")
	if ok and type(dateParts) == "table" then
		local month = tonumber(dateParts.month)
		local day = tonumber(dateParts.day)
		local year = tonumber(dateParts.year)
		if month ~= nil and day ~= nil and year ~= nil then
			return tostring(month) .. "/" .. tostring(day) .. "/" .. tostring(year)
		end
	end

	ok, dateParts = pcall(os.date, "%m/%d/%Y")
	if ok and type(dateParts) == "string" then
		local month, day, year = string.match(dateParts, "^(%d+)/(%d+)/(%d+)$")
		month = tonumber(month)
		day = tonumber(day)
		year = tonumber(year)
		if month ~= nil and day ~= nil and year ~= nil then
			return tostring(month) .. "/" .. tostring(day) .. "/" .. tostring(year)
		end
	end

	return nil
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

local function SaveCounterSettings()
	SaveData(SETTINGS_SAVE_KEY, {
		autoOpenCounterWindow = runtime.autoOpenCounterWindow == true,
	})
end

local function LoadCounterSettings()
	local data = LoadData(SETTINGS_SAVE_KEY)
	if type(data) ~= "table" then
		return
	end
	runtime.autoOpenCounterWindow = data.autoOpenCounterWindow == true
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
	if type(data.healReceivedBySource) == "table" then
		runtime.healReceivedBySource = data.healReceivedBySource
	end
	if type(data.damageByTarget) == "table" then
		runtime.damageByTarget = data.damageByTarget
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
	if type(data.expByUnit) == "table" then
		runtime.expByUnit = data.expByUnit
	end
	runtime.totalDamageDealt = tonumber(data.totalDamageDealt) or runtime.totalDamageDealt
	runtime.totalDamageTaken = tonumber(data.totalDamageTaken) or runtime.totalDamageTaken
	runtime.totalDroppedItems = tonumber(data.totalDroppedItems) or runtime.totalDroppedItems
	runtime.totalExpGained = tonumber(data.totalExpGained) or runtime.totalExpGained
	runtime.totalManaSpent = tonumber(data.totalManaSpent) or runtime.totalManaSpent
	runtime.totalKillTime = tonumber(data.totalKillTime) or runtime.totalKillTime
	if type(data.lastDamage) == "table" then
		runtime.lastDamage = data.lastDamage
	end
	if type(data.lastDamageTaken) == "table" then
		runtime.lastDamageTaken = data.lastDamageTaken
	end
	if type(data.debuffHistory) == "table" then
		runtime.debuffHistory = data.debuffHistory
	end
	if type(data.activeDebuffsOnPlayer) == "table" then
		runtime.activeDebuffsOnPlayer = data.activeDebuffsOnPlayer
	end
	runtime.nextDebuffEventId = tonumber(data.nextDebuffEventId) or runtime.nextDebuffEventId or 1
	if IsValidName(data.sessionLocationText) then
		runtime.sessionLocationText = tostring(data.sessionLocationText)
	end
	if IsValidName(data.loadingStartLocationText) then
		runtime.loadingStartLocationText = tostring(data.loadingStartLocationText)
	end
	if Analysis.TrimDebuffHistory ~= nil then
		Analysis.TrimDebuffHistory()
	end
	if Analysis.RebuildDamageCategories ~= nil then
		Analysis.RebuildDamageCategories()
	end
end

local function SaveKillCounts()
	SaveData(SAVE_KEY, {
		kills = runtime.killCounts,
		killerCounts = runtime.killerCounts,
		lastKill = runtime.lastKill,
		sessionKillCounts = runtime.sessionKillCounts,
		damageDealtByUnit = runtime.damageDealtByUnit,
		damageTakenByUnit = runtime.damageTakenByUnit,
		damageBySkill = runtime.damageBySkill,
		damageByCategory = runtime.damageByCategory,
		damageByElement = runtime.damageByElement,
		healBySkill = runtime.healBySkill,
		missesBySkill = runtime.missesBySkill,
		energizeBySkill = runtime.energizeBySkill,
		damageTakenBySource = runtime.damageTakenBySource,
		healReceivedBySource = runtime.healReceivedBySource,
		damageByTarget = runtime.damageByTarget,
		sessionKillLocations = runtime.sessionKillLocations,
		playerCombatStats = runtime.playerCombatStats,
		itemDropsByUnit = runtime.itemDropsByUnit,
		expByUnit = runtime.expByUnit,
		totalDamageDealt = runtime.totalDamageDealt,
		totalDamageTaken = runtime.totalDamageTaken,
		totalDroppedItems = runtime.totalDroppedItems,
		totalExpGained = runtime.totalExpGained,
		totalManaSpent = runtime.totalManaSpent,
		totalKillTime = runtime.totalKillTime,
		lastDamage = runtime.lastDamage,
		lastDamageTaken = runtime.lastDamageTaken,
		debuffHistory = runtime.debuffHistory,
		activeDebuffsOnPlayer = runtime.activeDebuffsOnPlayer,
		nextDebuffEventId = runtime.nextDebuffEventId,
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
		if pendingEvents < Analysis.SESSION_SAVE_EVENT_BATCH and elapsed < Analysis.SESSION_SAVE_INTERVAL_SECONDS then
			return
		end
	end
	SaveKillCounts()
end

function Analysis.MarkSessionDataSavePending()
	runtime.savePending = true
	runtime.pendingSaveEvents = (tonumber(runtime.pendingSaveEvents) or 0) + 1
	if runtime.pendingSaveEvents >= Analysis.SESSION_SAVE_EVENT_BATCH then
		Analysis.FlushSessionDataSave(true)
	end
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
	for _, point in ipairs(points) do
		local normalized = Analysis.NormalizeKillLocation(point)
		if normalized ~= nil then
			copied[#copied + 1] = normalized
		end
	end
	return copied
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

	point.time = RefreshClock()
	point.mobName = Trim(mobName)
	point.killerName = Trim(killerName)
	point.location = CaptureSessionActivityLocation() or ""
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

local function LoadSessionHistory()
	local data = LoadData(HISTORY_SAVE_KEY)
	if type(data) ~= "table" then
		return
	end

	local sessions = data.sessions or data
	local maxIndex = 0
	if type(sessions) == "table" then
		for _, session in ipairs(sessions) do
			if type(session) == "table" then
				local name = Trim(session.name or "")
				if name == "" then
					name = "S" .. tostring(#runtime.historySessions + 1)
				end
				local sessionIndex = tonumber(string.match(name, "^S(%d+)"))
				if sessionIndex ~= nil and sessionIndex > maxIndex then
					maxIndex = sessionIndex
				end

				local normalizedLines = {}
				if type(session.lines) == "table" then
					for _, line in ipairs(session.lines) do
						if type(line) == "table" then
							normalizedLines[#normalizedLines + 1] = {
								kind = tostring(line.kind or "metric"),
								text = tostring(line.text or ""),
							}
						end
					end
				end

				runtime.historySessions[#runtime.historySessions + 1] = {
					name = name,
					location = tostring(session.location or ""),
					date = tostring(session.date or ""),
					summary = tostring(session.summary or ""),
					createdAt = tonumber(session.createdAt) or 0,
					lines = normalizedLines,
					killLocations = Analysis.CopyKillLocations(session.killLocations),
				}
			end
		end
	end

	local nextIndex = tonumber(data.nextIndex)
	if nextIndex == nil or nextIndex <= maxIndex then
		nextIndex = maxIndex + 1
	end
	if nextIndex < 1 then
		nextIndex = #runtime.historySessions + 1
	end
	runtime.nextHistorySessionIndex = nextIndex
end

local function SaveSessionHistory()
	SaveData(HISTORY_SAVE_KEY, {
		nextIndex = runtime.nextHistorySessionIndex,
		sessions = runtime.historySessions,
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
local UpdateViewWindow
local RemovePendingTargetHitsByKey
local RefreshViewWindowIfVisible
local SaveCurrentSessionToHistory

local function ClearSessionHistory()
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
	SaveSessionHistory()
	if UpdateViewWindow ~= nil and runtime.viewMode == "history" then
		UpdateViewWindow()
	end
end

function Analysis.FormatAmount(value)
	value = math.floor((tonumber(value) or 0) + 0.5)
	return tostring(value)
end

function Analysis.FormatDuration(seconds)
	seconds = math.floor((tonumber(seconds) or 0) + 0.5)
	if seconds < 60 then
		return tostring(seconds) .. "s"
	end
	local minutes = math.floor(seconds / 60)
	local remainder = seconds - (minutes * 60)
	if minutes < 60 then
		return tostring(minutes) .. "m " .. tostring(remainder) .. "s"
	end
	local hours = math.floor(minutes / 60)
	minutes = minutes - (hours * 60)
	return tostring(hours) .. "h " .. tostring(minutes) .. "m"
end

function Analysis.TruncateText(value, maxLength)
	local text = tostring(value or "")
	maxLength = tonumber(maxLength) or 0
	if maxLength <= 0 or string.len(text) <= maxLength then
		return text
	end
	if maxLength <= 3 then
		return string.sub(text, 1, maxLength)
	end
	return string.sub(text, 1, maxLength - 3) .. "..."
end

function Analysis.AddAmount(target, key, amount)
	if key == nil or key == "" then
		key = "Unknown"
	end
	amount = tonumber(amount) or 0
	if amount <= 0 then
		return
	end
	target[key] = (tonumber(target[key]) or 0) + amount
end

function Analysis.NormalizePositiveAmount(value)
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

Analysis.DAMAGE_CATEGORY_ORDER = { "Melee", "Spell", "Ranged", "Environmental", "Other" }

function Analysis.FormatDamage(value)
	local amount = math.floor(tonumber(value) or 0)
	if amount >= 1000000 then
		return string.format("%.1fM", amount / 1000000)
	end
	if amount >= 1000 then
		return string.format("%.1fK", amount / 1000)
	end
	return tostring(amount)
end

function Analysis.FormatDps(value)
	local dps = tonumber(value) or 0
	if dps <= 0 then
		return "0"
	end
	if dps >= 1000000 then
		return string.format("%.1fM", dps / 1000000)
	end
	if dps >= 1000 then
		return string.format("%.1fK", dps / 1000)
	end
	if dps >= 100 then
		return tostring(math.floor(dps + 0.5))
	end
	return string.format("%.1f", dps)
end

function Analysis.FormatPercent(part, total)
	part = tonumber(part) or 0
	total = tonumber(total) or 0
	if total <= 0 or part <= 0 then
		return "0%"
	end
	return string.format("%.1f%%", (part / total) * 100)
end

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
	if not IsLocalPlayerName(sourceName) or not IsValidName(targetName) then
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
	Analysis.TrackDamageElement(damageType, damageAmount)
	Analysis.IncrementPlayerStat("totalHits", 1)
	Analysis.UpdateExtremeStat("largestHit", damageAmount)
	runtime.damageByCategory[category] = (tonumber(runtime.damageByCategory[category]) or 0) + damageAmount
	runtime.damageByTarget[Trim(targetName)] = (tonumber(runtime.damageByTarget[Trim(targetName)]) or 0) + damageAmount
end

function Analysis.RecordHeal(sourceName, eventType, abilityId, abilityName, healAmount)
	if not IsLocalPlayerName(sourceName) then
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
	Analysis.IncrementPlayerStat("totalHealingHits", 1)
	Analysis.UpdateExtremeStat("largestHeal", healAmount)
end

function Analysis.RecordMiss(sourceName, eventType, abilityId, abilityName)
	if not IsLocalPlayerName(sourceName) then
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
	Analysis.IncrementPlayerStat("totalMisses", 1)
	if category == "Melee" then
		Analysis.IncrementPlayerStat("meleeMisses", 1)
	else
		Analysis.IncrementPlayerStat("spellMisses", 1)
	end
end

function Analysis.RecordEnergize(sourceName, eventType, abilityId, abilityName, amount)
	if not IsLocalPlayerName(sourceName) then
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
		time = RefreshClock(),
	}
	Analysis.IncrementPlayerStat("totalDamageTaken", damageAmount)
end

function Analysis.RecordHealReceived(sourceName, healAmount)
	sourceName = Trim(sourceName or "Unknown")
	if sourceName == "" then
		sourceName = "Unknown"
	end
	runtime.healReceivedBySource[sourceName] =
		(tonumber(runtime.healReceivedBySource[sourceName]) or 0) + healAmount
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

function Analysis.ParseGameCombatAuraResult(msg)
	if type(msg) ~= "table" or _G == nil or type(_G.ParseCombatMessage) ~= "function" then
		return nil
	end
	local ok, result = pcall(
		_G.ParseCombatMessage,
		msg.eventType,
		msg.abilityId,
		msg.abilityName,
		msg.damageType,
		msg.effectType,
		msg.isActive,
		msg.arg10,
		msg.arg11,
		msg.arg12,
		msg.arg13
	)
	if ok and type(result) == "table" then
		return result
	end
	return nil
end

function Analysis.NormalizeDebuffDurationSeconds(timeLeft, timeUnit)
	timeLeft = tonumber(timeLeft)
	if timeLeft == nil or timeLeft <= 0 then
		return nil
	end
	if timeUnit == "sec" then
		return timeLeft
	end
	return timeLeft / 1000
end

function Analysis.FormatDebuffDurationSeconds(seconds)
	seconds = tonumber(seconds)
	if seconds == nil or seconds <= 0 then
		return "unknown"
	end
	if seconds >= 3600 then
		return string.format("%.1fh", seconds / 3600)
	end
	if seconds >= 60 then
		return string.format("%.1fm", seconds / 60)
	end
	return string.format("%.1fs", seconds)
end

function Analysis.ExtractDebuffEffectsFromTooltip(tooltip)
	if type(tooltip) ~= "table" then
		return ""
	end

	local parts = {}
	local description = Trim(tooltip.description or tooltip.effectDescription or "")
	if description ~= "" then
		parts[#parts + 1] = description
	end

	if type(tooltip.modifier) == "table" then
		local modifierCount = math.min(#tooltip.modifier, 4)
		for index = 1, modifierCount do
			local modifier = tooltip.modifier[index]
			if type(modifier) == "table" then
				local modifierName = Trim(modifier.name or "")
				local modifierValue = modifier.value
				if modifierName ~= "" and modifierValue ~= nil then
					parts[#parts + 1] = modifierName .. " " .. tostring(modifierValue)
				end
			end
		end
	end

	return table.concat(parts, "; ")
end

function Analysis.GetDebuffBuffId(debuffInfo)
	if type(debuffInfo) ~= "table" then
		return nil
	end
	return debuffInfo.buff_id or debuffInfo.buffId or debuffInfo.id
end

function Analysis.GetDebuffDisplayNameFromInfo(debuffInfo)
	if type(debuffInfo) ~= "table" then
		return ""
	end
	return Trim(debuffInfo.name or debuffInfo.title or debuffInfo.buff_name or "")
end

function Analysis.GetDebuffStorageKey(entry)
	if type(entry) ~= "table" then
		return nil
	end
	if entry.buffId ~= nil then
		return "id:" .. tostring(entry.buffId)
	end
	local name = Trim(entry.name or "")
	if name ~= "" then
		return "name:" .. NormalizeName(name)
	end
	return nil
end

function Analysis.GetDebuffStorageKeyFromInfo(debuffInfo)
	if type(debuffInfo) ~= "table" then
		return nil
	end
	local buffId = Analysis.GetDebuffBuffId(debuffInfo)
	if buffId ~= nil then
		return "id:" .. tostring(buffId)
	end
	local name = Analysis.GetDebuffDisplayNameFromInfo(debuffInfo)
	if name ~= "" then
		return "name:" .. NormalizeName(name)
	end
	return nil
end

function Analysis.FindDebuffHistoryEntry(storageKey, activeOnly)
	for index = #runtime.debuffHistory, 1, -1 do
		local entry = runtime.debuffHistory[index]
		if type(entry) == "table" and Analysis.GetDebuffStorageKey(entry) == storageKey then
			if activeOnly ~= true or entry.active == true then
				return entry, index
			end
		end
	end
	return nil, nil
end

function Analysis.TrimDebuffHistory()
	while #runtime.debuffHistory > Analysis.DEBUFF_HISTORY_LIMIT do
		table.remove(runtime.debuffHistory, 1)
	end
end

function Analysis.FindPlayerDebuffSnapshot(spellName, buffId)
	if X2Unit == nil then
		return nil
	end

	local okCount, debuffCount = SafeCall(X2Unit, "UnitDeBuffCount", "player")
	debuffCount = okCount and tonumber(debuffCount) or 0
	if debuffCount <= 0 then
		return nil
	end

	spellName = NormalizeName(spellName)
	local numericBuffId = tonumber(buffId)

	for index = 1, debuffCount do
		local okInfo, debuffInfo = SafeCall(X2Unit, "UnitDeBuff", "player", index)
		if okInfo and type(debuffInfo) == "table" then
			local matches = false
			if numericBuffId ~= nil and tonumber(Analysis.GetDebuffBuffId(debuffInfo)) == numericBuffId then
				matches = true
			elseif spellName ~= "" then
				local debuffName = NormalizeName(Analysis.GetDebuffDisplayNameFromInfo(debuffInfo))
				if debuffName ~= "" and debuffName == spellName then
					matches = true
				end
			end

			if matches then
				local okTooltip, tooltip = SafeCall(X2Unit, "UnitDeBuffTooltip", "player", index)
				return {
					index = index,
					info = debuffInfo,
					tooltip = okTooltip and tooltip or nil,
				}
			end
		end
	end

	return nil
end

function Analysis.ResolveDebuffSourceName()
	if type(runtime.lastDamageTaken) == "table" then
		local sourceName = Trim(runtime.lastDamageTaken.sourceName or "")
		local takenAt = tonumber(runtime.lastDamageTaken.time) or 0
		if sourceName ~= "" and RefreshClock() - takenAt <= 12 then
			return sourceName
		end
	end

	if type(runtime.lastDamage) == "table" and IsLocalPlayerName(runtime.lastDamage.targetName) then
		local sourceName = Trim(runtime.lastDamage.sourceName or "")
		if sourceName ~= "" and not IsLocalPlayerName(sourceName) then
			return sourceName
		end
	end

	local targetName = SafeUnitName("target")
	if IsValidName(targetName) and not IsLocalPlayerName(targetName) then
		return Trim(targetName)
	end

	return "Unknown"
end

function Analysis.ResolveDebuffDisplayName(msg, auraResult)
	if type(auraResult) == "table" then
		local spellName = Trim(auraResult.spellName or "")
		if spellName ~= "" then
			return spellName
		end
	end
	if type(msg) == "table" then
		local abilityName = Trim(msg.abilityName or "")
		if abilityName ~= "" then
			return abilityName
		end
		return Analysis.NormalizeAbilityName(msg.abilityName, msg.eventType, msg.abilityId)
	end
	return "Unknown Debuff"
end

function Analysis.IsPlayerDebuffAura(auraResult)
	if type(auraResult) ~= "table" then
		return true
	end
	local auraType = Trim(tostring(auraResult.auraType or ""))
	return auraType == "" or auraType == "DEBUFF"
end

function Analysis.IsLocalPlayerTarget(msg)
	if type(msg) ~= "table" then
		return false
	end
	if IsLocalPlayerName(msg.targetName) then
		return true
	end
	return Trim(tostring(msg.unitId or "")) == "player"
end

function Analysis.CreateDebuffHistoryEntry(msg, auraResult, snapshot)
	local now = RefreshClock()
	local debuffName = Analysis.ResolveDebuffDisplayName(msg, auraResult)
	local sourceName = Trim((msg and msg.sourceName) or "Unknown")
	if sourceName == "" then
		sourceName = "Unknown"
	end

	local buffId = nil
	local stacks = 1
	local durationSec = nil
	local effects = ""

	if type(snapshot) == "table" and type(snapshot.info) == "table" then
		buffId = snapshot.info.buff_id or snapshot.info.buffId or snapshot.info.id
		stacks = tonumber(snapshot.info.stack or snapshot.info.stacks) or 1
		durationSec = Analysis.NormalizeDebuffDurationSeconds(
			snapshot.info.timeLeft or snapshot.info.time_left,
			snapshot.info.timeUnit or snapshot.info.time_unit
		)
		effects = Analysis.ExtractDebuffEffectsFromTooltip(snapshot.tooltip)
	end

	if type(auraResult) == "table" then
		if buffId == nil and auraResult.buffId ~= nil then
			buffId = auraResult.buffId
		end
		if buffId == nil and auraResult.spellId ~= nil then
			buffId = auraResult.spellId
		end
		if tonumber(auraResult.stack) ~= nil then
			stacks = tonumber(auraResult.stack)
		end
		if durationSec == nil then
			durationSec = Analysis.NormalizeDebuffDurationSeconds(
				auraResult.duration or auraResult.timeLeft,
				auraResult.timeUnit
			)
		end
	end

	local entry = {
		id = runtime.nextDebuffEventId,
		name = debuffName,
		source = sourceName,
		buffId = buffId,
		appliedAt = now,
		removedAt = nil,
		durationSec = durationSec,
		actualDurationSec = nil,
		stacks = stacks,
		effects = effects,
		refreshCount = 0,
		active = true,
		applyCount = 1,
	}
	runtime.nextDebuffEventId = runtime.nextDebuffEventId + 1
	runtime.debuffHistory[#runtime.debuffHistory + 1] = entry

	local storageKey = Analysis.GetDebuffStorageKey(entry)
	if storageKey ~= nil then
		runtime.activeDebuffsOnPlayer[storageKey] = entry.id
	end

	Analysis.IncrementPlayerStat("totalDebuffsApplied", 1)
	Analysis.TrimDebuffHistory()
	return entry
end

function Analysis.CreateDebuffHistoryEntryFromUnit(debuffInfo, tooltip, sourceName)
	if type(debuffInfo) ~= "table" then
		return nil
	end

	local debuffName = Analysis.GetDebuffDisplayNameFromInfo(debuffInfo)
	if debuffName == "" then
		debuffName = "Unknown Debuff"
	end

	sourceName = Trim(sourceName or "Unknown")
	if sourceName == "" then
		sourceName = "Unknown"
	end

	local entry = {
		id = runtime.nextDebuffEventId,
		name = debuffName,
		source = sourceName,
		buffId = Analysis.GetDebuffBuffId(debuffInfo),
		appliedAt = RefreshClock(),
		removedAt = nil,
		durationSec = Analysis.NormalizeDebuffDurationSeconds(
			debuffInfo.timeLeft or debuffInfo.time_left,
			debuffInfo.timeUnit or debuffInfo.time_unit
		),
		actualDurationSec = nil,
		stacks = tonumber(debuffInfo.stack or debuffInfo.stacks) or 1,
		effects = Analysis.ExtractDebuffEffectsFromTooltip(tooltip),
		refreshCount = 0,
		active = true,
		applyCount = 1,
	}
	runtime.nextDebuffEventId = runtime.nextDebuffEventId + 1
	runtime.debuffHistory[#runtime.debuffHistory + 1] = entry

	local storageKey = Analysis.GetDebuffStorageKey(entry)
	if storageKey ~= nil then
		runtime.activeDebuffsOnPlayer[storageKey] = entry.id
	end

	Analysis.TouchKillCombatActivity()
	Analysis.IncrementPlayerStat("totalDebuffsApplied", 1)
	Analysis.TrimDebuffHistory()
	return entry
end

function Analysis.RecordPlayerDebuffApplied(msg, auraResult)
	if not Analysis.IsPlayerDebuffAura(auraResult) then
		return false
	end

	Analysis.TouchKillCombatActivity()
	local debuffName = Analysis.ResolveDebuffDisplayName(msg, auraResult)
	local buffId = nil
	if type(auraResult) == "table" then
		buffId = auraResult.buffId or auraResult.spellId
	end

	local snapshot = Analysis.FindPlayerDebuffSnapshot(debuffName, buffId)
	Analysis.CreateDebuffHistoryEntry(msg, auraResult, snapshot)
	return true
end

function Analysis.RecordPlayerDebuffRefresh(msg, auraResult, isDose)
	if not Analysis.IsPlayerDebuffAura(auraResult) then
		return false
	end

	Analysis.TouchKillCombatActivity()
	local debuffName = Analysis.ResolveDebuffDisplayName(msg, auraResult)
	local buffId = nil
	if type(auraResult) == "table" then
		buffId = auraResult.buffId or auraResult.spellId
	end

	local snapshot = Analysis.FindPlayerDebuffSnapshot(debuffName, buffId)
	local storageKey = nil
	if buffId ~= nil then
		storageKey = "id:" .. tostring(buffId)
	else
		storageKey = "name:" .. NormalizeName(debuffName)
	end

	local entry = select(1, Analysis.FindDebuffHistoryEntry(storageKey, true))
	if entry == nil then
		Analysis.CreateDebuffHistoryEntry(msg, auraResult, snapshot)
		return true
	end

	entry.refreshCount = (tonumber(entry.refreshCount) or 0) + 1
	if isDose then
		entry.applyCount = (tonumber(entry.applyCount) or 0) + 1
	end
	if type(snapshot) == "table" and type(snapshot.info) == "table" then
		entry.stacks = tonumber(snapshot.info.stack or snapshot.info.stacks) or entry.stacks
		entry.durationSec = Analysis.NormalizeDebuffDurationSeconds(
			snapshot.info.timeLeft or snapshot.info.time_left,
			snapshot.info.timeUnit or snapshot.info.time_unit
		) or entry.durationSec
		local effects = Analysis.ExtractDebuffEffectsFromTooltip(snapshot.tooltip)
		if effects ~= "" then
			entry.effects = effects
		end
	elseif type(auraResult) == "table" and tonumber(auraResult.stack) ~= nil then
		entry.stacks = tonumber(auraResult.stack)
	end

	return true
end

function Analysis.RecordPlayerDebuffRemoved(msg, auraResult)
	local debuffName = Analysis.ResolveDebuffDisplayName(msg, auraResult)
	local buffId = nil
	if type(auraResult) == "table" then
		buffId = auraResult.buffId or auraResult.spellId
	end

	local storageKey = nil
	if buffId ~= nil then
		storageKey = "id:" .. tostring(buffId)
	else
		storageKey = "name:" .. NormalizeName(debuffName)
	end

	local entry = select(1, Analysis.FindDebuffHistoryEntry(storageKey, true))
	if entry == nil and not Analysis.IsPlayerDebuffAura(auraResult) then
		return false
	end

	Analysis.TouchKillCombatActivity()
	local now = RefreshClock()
	if entry ~= nil then
		entry.active = false
		entry.removedAt = now
		local appliedAt = tonumber(entry.appliedAt) or now
		entry.actualDurationSec = now - appliedAt
		runtime.activeDebuffsOnPlayer[storageKey] = nil
	else
		runtime.debuffHistory[#runtime.debuffHistory + 1] = {
			id = runtime.nextDebuffEventId,
			name = debuffName,
			source = Trim((msg and msg.sourceName) or "Unknown"),
			buffId = buffId,
			appliedAt = nil,
			removedAt = now,
			durationSec = nil,
			actualDurationSec = nil,
			stacks = tonumber(auraResult and auraResult.stack) or 1,
			effects = "",
			refreshCount = 0,
			active = false,
			applyCount = 0,
		}
		runtime.nextDebuffEventId = runtime.nextDebuffEventId + 1
		Analysis.TrimDebuffHistory()
	end

	Analysis.IncrementPlayerStat("totalDebuffsRemoved", 1)
	return true
end

function Analysis.HandlePlayerDebuffAuraMessage(msg, auraKind, auraResult)
	if auraKind == "aura_applied" then
		return Analysis.RecordPlayerDebuffApplied(msg, auraResult)
	end
	if auraKind == "aura_dose" then
		return Analysis.RecordPlayerDebuffRefresh(msg, auraResult, true)
	end
	if auraKind == "aura_refresh" then
		return Analysis.RecordPlayerDebuffRefresh(msg, auraResult, false)
	end
	if auraKind == "aura_removed" then
		return Analysis.RecordPlayerDebuffRemoved(msg, auraResult)
	end
	return false
end

function Analysis.SyncActivePlayerDebuffsFromUnit()
	if X2Unit == nil then
		return false
	end

	local okCount, debuffCount = SafeCall(X2Unit, "UnitDeBuffCount", "player")
	debuffCount = okCount and tonumber(debuffCount) or 0
	local seenKeys = {}
	local changed = false

	for index = 1, debuffCount do
		local okInfo, debuffInfo = SafeCall(X2Unit, "UnitDeBuff", "player", index)
		if okInfo and type(debuffInfo) == "table" then
			local storageKey = Analysis.GetDebuffStorageKeyFromInfo(debuffInfo)
			if storageKey ~= nil then
				seenKeys[storageKey] = true
				local okTooltip, tooltip = SafeCall(X2Unit, "UnitDeBuffTooltip", "player", index)
				local entry = select(1, Analysis.FindDebuffHistoryEntry(storageKey, true))
				if entry == nil then
					Analysis.CreateDebuffHistoryEntryFromUnit(
						debuffInfo,
						okTooltip and tooltip or nil,
						Analysis.ResolveDebuffSourceName()
					)
					changed = true
				else
					local nextStacks = tonumber(debuffInfo.stack or debuffInfo.stacks) or entry.stacks
					local nextDuration = Analysis.NormalizeDebuffDurationSeconds(
						debuffInfo.timeLeft or debuffInfo.time_left,
						debuffInfo.timeUnit or debuffInfo.time_unit
					) or entry.durationSec
					if nextStacks ~= entry.stacks or nextDuration ~= entry.durationSec then
						changed = true
					end
					entry.stacks = nextStacks
					entry.durationSec = nextDuration
					if okTooltip then
						local effects = Analysis.ExtractDebuffEffectsFromTooltip(tooltip)
						if effects ~= "" and effects ~= entry.effects then
							entry.effects = effects
							changed = true
						end
					end
				end
			end
		end
	end

	for storageKey, entryId in pairs(runtime.activeDebuffsOnPlayer) do
		if seenKeys[storageKey] ~= true then
			local entry = select(1, Analysis.FindDebuffHistoryEntry(storageKey, true))
			if entry ~= nil and entry.id == entryId then
				entry.active = false
				entry.removedAt = RefreshClock()
				local appliedAt = tonumber(entry.appliedAt) or RefreshClock()
				entry.actualDurationSec = RefreshClock() - appliedAt
				changed = true
			end
			runtime.activeDebuffsOnPlayer[storageKey] = nil
		end
	end

	if changed then
		Analysis.MarkSessionDataSavePending()
	end
	return changed
end

function Analysis.CountActivePlayerDebuffs()
	local count = 0
	for _, entryId in pairs(runtime.activeDebuffsOnPlayer) do
		if entryId ~= nil then
			count = count + 1
		end
	end
	return count
end

function Analysis.FormatDebuffAnalysisLine(entry, includeRemaining)
	if type(entry) ~= "table" then
		return "  Unknown debuff"
	end

	local durationText
	if includeRemaining == true and entry.active == true then
		durationText = "left " .. Analysis.FormatDebuffDurationSeconds(entry.durationSec)
	elseif entry.actualDurationSec ~= nil then
		durationText = "lasted " .. Analysis.FormatDebuffDurationSeconds(entry.actualDurationSec)
	elseif entry.durationSec ~= nil then
		durationText = "for " .. Analysis.FormatDebuffDurationSeconds(entry.durationSec)
	else
		durationText = "duration unknown"
	end

	local stackText = ""
	local stacks = tonumber(entry.stacks) or 0
	if stacks > 1 then
		stackText = " x" .. tostring(stacks)
	end

	local applyText = ""
	local applyCount = tonumber(entry.applyCount) or 0
	if applyCount > 1 then
		applyText = " (" .. tostring(applyCount) .. " applies)"
	end

	local refreshText = ""
	local refreshCount = tonumber(entry.refreshCount) or 0
	if refreshCount > 0 then
		refreshText = " refreshed " .. tostring(refreshCount) .. "x"
	end

	local effectText = ""
	if Trim(entry.effects or "") ~= "" then
		effectText = " | " .. Analysis.TruncateText(entry.effects, 36)
	end

	return string.format(
		"  %-16s %-12s %s%s%s%s%s",
		Analysis.TruncateText(entry.name or "Unknown", 16),
		Analysis.TruncateText(entry.source or "Unknown", 12),
		durationText,
		stackText,
		applyText,
		refreshText,
		effectText
	)
end

function Analysis.AddDebuffEffectDetailLine(lines, entry)
	local effects = Trim((entry and entry.effects) or "")
	if effects == "" or string.len(effects) <= 36 then
		return
	end
	Analysis.AddViewLine(lines, "metric", "    Effect: " .. Analysis.TruncateText(effects, 72))
end

function Analysis.RecordDpsReviewCombatMessage(msg)
	if type(msg) ~= "table" then
		return false
	end
	local auraKind = Analysis.GetCombatAuraEventKind(msg.eventType)
	if auraKind ~= nil then
		if Analysis.IsLocalPlayerTarget(msg) then
			local auraResult = Analysis.ParseGameCombatAuraResult(msg)
			local recordedAura = Analysis.HandlePlayerDebuffAuraMessage(msg, auraKind, auraResult)
			if recordedAura then
				Analysis.MarkSessionDataSavePending()
				if RefreshViewWindowIfVisible ~= nil then
					RefreshViewWindowIfVisible()
				end
			end
			return recordedAura
		end
		return false
	end
	if msg.sourceName == "" or msg.targetName == "" then
		return false
	end
	local eventKind = Analysis.GetCombatEventKind(msg.eventType)
	local amount = Analysis.GetEffectAmount(eventKind, msg.eventType, msg.abilityId, msg.effectType)
	local recorded = false
	if eventKind == "damage" and amount ~= nil then
		runtime.lastDamage = {
			sourceName = msg.sourceName,
			targetName = msg.targetName,
			amount = amount,
			time = RefreshClock(),
		}
		if IsLocalPlayerName(msg.sourceName) then
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
		if IsLocalPlayerName(msg.targetName) and not IsLocalPlayerName(msg.sourceName) then
			Analysis.RecordDamageTaken(msg.sourceName, amount)
			recorded = true
		end
	elseif eventKind == "heal" and amount ~= nil then
		if IsLocalPlayerName(msg.sourceName) then
			Analysis.RecordHeal(msg.sourceName, msg.eventType, msg.abilityId, msg.abilityName, amount)
			recorded = true
		end
		if IsLocalPlayerName(msg.targetName) and not IsLocalPlayerName(msg.sourceName) then
			Analysis.RecordHealReceived(msg.sourceName, amount)
			recorded = true
		end
	elseif eventKind == "miss" then
		Analysis.RecordMiss(msg.sourceName, msg.eventType, msg.abilityId, msg.abilityName)
		recorded = IsLocalPlayerName(msg.sourceName)
	elseif eventKind == "energize" and amount ~= nil then
		Analysis.RecordEnergize(msg.sourceName, msg.eventType, msg.abilityId, msg.abilityName, amount)
		recorded = IsLocalPlayerName(msg.sourceName)
	end
	if recorded then
		Analysis.TouchKillCombatActivity()
		Analysis.MarkSessionDataSavePending()
	end
	if recorded and RefreshViewWindowIfVisible ~= nil then
		RefreshViewWindowIfVisible()
	end
	return recorded
end

function Analysis.IsPlayerInCombat()
	local ok, value = SafeCall(X2Player, "PlayerInCombat")
	if ok and value == true then
		return true
	end
	ok, value = SafeCall(X2Unit, "UnitCombatState", "player")
	return ok and value == true
end

function Analysis.GetKillCombatDuration(now)
	local total = tonumber(runtime.totalKillTime) or 0
	if runtime.combatActive and runtime.combatStart ~= nil then
		total = total + ((now or RefreshClock()) - runtime.combatStart)
	end
	if total < 0 then
		return 0
	end
	return total
end

function Analysis.BeginKillCombatSession(now)
	now = now or RefreshClock()
	runtime.combatActive = true
	runtime.combatStart = now
	runtime.lastCombatActivity = now
end

function Analysis.EndKillCombatSession(now)
	if not runtime.combatActive then
		return
	end
	now = now or RefreshClock()
	if runtime.combatStart ~= nil and now > runtime.combatStart then
		runtime.totalKillTime = (tonumber(runtime.totalKillTime) or 0) + (now - runtime.combatStart)
	end
	runtime.combatActive = false
	runtime.combatStart = nil
	runtime.lastCombatActivity = nil
	Analysis.FlushSessionDataSave(true)
	if RefreshViewWindowIfVisible ~= nil then
		RefreshViewWindowIfVisible()
	end
end

function Analysis.TouchKillCombatActivity(now)
	now = now or RefreshClock()
	if not runtime.combatActive then
		Analysis.BeginKillCombatSession(now)
		return
	end
	runtime.lastCombatActivity = now
end

function Analysis.EvaluateKillCombatEnd(now)
	if not runtime.combatActive then
		return
	end
	now = now or RefreshClock()
	local lastActivity = tonumber(runtime.lastCombatActivity)
	if lastActivity == nil then
		Analysis.EndKillCombatSession(now)
		return
	end
	local idle = now - lastActivity
	if idle >= COMBAT_IDLE_TIMEOUT then
		Analysis.EndKillCombatSession(now)
		return
	end
	if not Analysis.IsPlayerInCombat() and idle >= PLAYER_COMBAT_EXIT_GRACE then
		Analysis.EndKillCombatSession(now)
	end
end

function Analysis.GetRecentMobName(maxAge)
	-- Loot and EXP events do not expose a stable killed-unit id, so this report attributes them to the recent kill/current target.
	local now = RefreshClock()
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

function Analysis.RecordDroppedItem(mobName, itemName, count)
	if not IsValidName(itemName) then
		return
	end
	if not IsValidName(mobName) then
		mobName = "Unknown"
	else
		mobName = Trim(mobName)
	end
	itemName = Trim(itemName)
	count = math.floor((tonumber(count) or 1) + 0.5)
	if count < 1 then
		count = 1
	end
	if runtime.itemDropsByUnit[mobName] == nil then
		runtime.itemDropsByUnit[mobName] = {}
	end
	runtime.itemDropsByUnit[mobName][itemName] =
		(tonumber(runtime.itemDropsByUnit[mobName][itemName]) or 0) + count
	runtime.totalDroppedItems = (tonumber(runtime.totalDroppedItems) or 0) + count
	Analysis.MarkSessionDataSavePending()
	if RefreshViewWindowIfVisible ~= nil then
		RefreshViewWindowIfVisible()
	end
end

Analysis.LOOT_ITEM_TABLE_FIELDS = {
	"item",
	"itemInfo",
	"item_info",
	"lootItem",
	"loot_item",
	"itemData",
	"item_data",
	"info",
}

Analysis.LOOT_ITEM_NAME_FIELDS = {
	"name",
	"itemName",
	"item_name",
	"item_name_text",
}

Analysis.LOOT_ITEM_COUNT_FIELDS = {
	"stackCount",
	"stack_count",
	"itemCount",
	"item_count",
	"quantity",
	"amount",
	"count",
	"stack",
}

function Analysis.ExtractFieldString(source, fields)
	for _, fieldName in ipairs(fields) do
		local value = source[fieldName]
		if type(value) == "string" and Trim(value) ~= "" then
			return Trim(value)
		end
	end
	return nil
end

function Analysis.ExtractFieldNumber(source, fields)
	for _, fieldName in ipairs(fields) do
		local value = tonumber(source[fieldName])
		if value ~= nil and value >= 0 then
			return value
		end
	end
	return nil
end

function Analysis.ExtractLootItemFromTable(source, depth)
	if type(source) ~= "table" or (tonumber(depth) or 0) > 3 then
		return nil
	end

	local itemName = Analysis.ExtractFieldString(source, Analysis.LOOT_ITEM_NAME_FIELDS)
	if itemName ~= nil then
		return {
			name = itemName,
			count = Analysis.ExtractFieldNumber(source, Analysis.LOOT_ITEM_COUNT_FIELDS) or 1,
		}
	end

	for _, fieldName in ipairs(Analysis.LOOT_ITEM_TABLE_FIELDS) do
		local item = Analysis.ExtractLootItemFromTable(source[fieldName], (tonumber(depth) or 0) + 1)
		if item ~= nil then
			if item.count == nil then
				item.count = Analysis.ExtractFieldNumber(source, Analysis.LOOT_ITEM_COUNT_FIELDS) or 1
			end
			return item
		end
	end

	for _, value in pairs(source) do
		if type(value) == "table" then
			local item = Analysis.ExtractLootItemFromTable(value, (tonumber(depth) or 0) + 1)
			if item ~= nil then
				return item
			end
		end
	end
	return nil
end

function Analysis.ReadBagItem(posInBag)
	local ok, item = SafeCall(X2Bag, "GetBagItemInfo", BAG_KIND, posInBag)
	if ok then
		return item
	end
	return nil
end

function Analysis.BuildBagSnapshot()
	if X2Bag == nil or type(X2Bag.GetBagItemInfo) ~= "function" then
		return nil
	end

	local snapshot = {}
	for posInBag = 1, MAX_BAG_SLOTS do
		local bagItem = Analysis.ReadBagItem(posInBag)
		local item = Analysis.ExtractLootItemFromTable(bagItem, 0)
		if item ~= nil and IsValidName(item.name) then
			local count = math.floor((tonumber(item.count) or 1) + 0.5)
			if count < 1 then
				count = 1
			end
			local itemName = Trim(item.name)
			snapshot[itemName] = (tonumber(snapshot[itemName]) or 0) + count
		end
	end
	return snapshot
end

function Analysis.SyncBagDrops(baselineOnly)
	local snapshot = Analysis.BuildBagSnapshot()
	if snapshot == nil then
		return false
	end

	local recorded = false
	if not baselineOnly and runtime.lastBagSnapshot ~= nil then
		local mobName = Analysis.GetRecentMobName(LOOT_ATTRIBUTION_SECONDS)
		for itemName, count in pairs(snapshot) do
			local previousCount = tonumber(runtime.lastBagSnapshot[itemName]) or 0
			local gained = (tonumber(count) or 0) - previousCount
			if gained > 0 then
				Analysis.RecordDroppedItem(mobName, itemName, gained)
				recorded = true
			end
		end
	end

	runtime.lastBagSnapshot = snapshot
	return recorded
end

function Analysis.ScheduleBagDropSync()
	runtime.pendingBagSyncUntil = RefreshClock() + 3
	Analysis.SyncBagDrops(false)
end

function Analysis.RecordLootFromEventPayload(...)
	local item = nil
	local stringValues = {}
	local countCandidate = nil
	for index = 1, select("#", ...) do
		local value = select(index, ...)
		if type(value) == "table" and item == nil then
			item = Analysis.ExtractLootItemFromTable(value, 0)
		elseif type(value) == "string" and Trim(value) ~= "" then
			stringValues[#stringValues + 1] = Trim(value)
		elseif type(value) == "number" then
			local numberValue = tonumber(value)
			if countCandidate == nil and numberValue ~= nil and numberValue > 0 and numberValue <= 999 then
				countCandidate = numberValue
			end
		end
	end

	if item == nil and #stringValues > 0 then
		item = {
			name = stringValues[#stringValues],
			count = countCandidate or 1,
		}
	end
	if item == nil or not IsValidName(item.name) then
		return false
	end
	Analysis.RecordDroppedItem(Analysis.GetRecentMobName(LOOT_ATTRIBUTION_SECONDS), item.name, item.count)
	return true
end

function Analysis.HandleLootAcquisitionEvent(...)
	local recordedFromBag = Analysis.SyncBagDrops(false)
	local recordedFromPayload = false
	if not recordedFromBag then
		recordedFromPayload = Analysis.RecordLootFromEventPayload(...)
	end
	if recordedFromBag or recordedFromPayload then
		runtime.pendingBagSyncUntil = nil
		Analysis.SyncBagDrops(true)
	else
		Analysis.ScheduleBagDropSync()
	end
end

function Analysis.AttributeExpGain(amount)
	amount = math.floor((tonumber(amount) or 0) + 0.5)
	if amount <= 0 then
		return false
	end
	runtime.totalExpGained = (tonumber(runtime.totalExpGained) or 0) + amount
	Analysis.AddAmount(runtime.expByUnit, Analysis.GetRecentMobName(EXP_ATTRIBUTION_SECONDS), amount)
	Analysis.MarkSessionDataSavePending()
	if RefreshViewWindowIfVisible ~= nil then
		RefreshViewWindowIfVisible()
	end
	return true
end

Analysis.EXP_CURRENT_FIELDS = {
	"current",
	"cur",
	"currentExp",
	"curExp",
	"exp",
	"value",
	"now",
}

Analysis.EXP_MAX_FIELDS = {
	"max",
	"maximum",
	"maxExp",
	"nextExp",
	"requiredExp",
	"requireExp",
	"total",
}

Analysis.EXP_LEVEL_FIELDS = {
	"level",
	"lv",
	"playerLevel",
}

function Analysis.BuildExpSnapshot(firstValue, secondValue, thirdValue)
	local snapshot = {
		current = nil,
		max = nil,
		level = nil,
	}
	if type(firstValue) == "table" then
		snapshot.current = Analysis.ExtractFieldNumber(firstValue, Analysis.EXP_CURRENT_FIELDS) or tonumber(firstValue[1])
		snapshot.max = Analysis.ExtractFieldNumber(firstValue, Analysis.EXP_MAX_FIELDS) or tonumber(firstValue[2])
		snapshot.level = Analysis.ExtractFieldNumber(firstValue, Analysis.EXP_LEVEL_FIELDS) or tonumber(firstValue[3])
	else
		snapshot.current = tonumber(firstValue)
		snapshot.max = tonumber(secondValue)
		snapshot.level = tonumber(thirdValue)
	end
	if snapshot.current == nil then
		return nil
	end
	return snapshot
end

function Analysis.ReadExpSnapshot()
	local ok, firstValue, secondValue, thirdValue = SafeCallValues(X2Player, "GetExpInfo")
	if not ok and _G ~= nil and type(_G.GetExpInfo) == "function" then
		ok, firstValue, secondValue, thirdValue = pcall(_G.GetExpInfo)
	end
	if not ok then
		return nil
	end
	return Analysis.BuildExpSnapshot(firstValue, secondValue, thirdValue)
end

function Analysis.SyncExpGained()
	local snapshot = Analysis.ReadExpSnapshot()
	if snapshot == nil then
		return false
	end

	local last = runtime.lastExpSnapshot
	local recorded = false
	if last ~= nil and tonumber(last.current) ~= nil then
		local gained = nil
		if snapshot.level ~= nil and last.level ~= nil and snapshot.level > last.level then
			gained = 0
			if last.max ~= nil and last.max >= last.current then
				gained = gained + (last.max - last.current)
			end
			gained = gained + snapshot.current
		elseif snapshot.current >= last.current then
			gained = snapshot.current - last.current
		end
		if gained ~= nil and gained > 0 then
			recorded = Analysis.AttributeExpGain(gained) or recorded
		end
	end
	runtime.lastExpSnapshot = snapshot
	return recorded
end

Analysis.EXP_DELTA_FIELDS = {
	"delta",
	"diff",
	"change",
	"changedExp",
	"changed_exp",
	"expDelta",
	"exp_delta",
	"expDiff",
	"exp_diff",
	"gainExp",
	"gain_exp",
	"gainedExp",
	"gained_exp",
	"addExp",
	"add_exp",
	"addedExp",
	"added_exp",
	"amount",
}

function Analysis.ExtractExpDeltaFromTable(source, depth)
	if type(source) ~= "table" or (tonumber(depth) or 0) > 3 then
		return nil
	end

	local amount = Analysis.ExtractFieldNumber(source, Analysis.EXP_DELTA_FIELDS)
	if amount ~= nil and amount > 0 then
		return amount
	end

	for _, value in pairs(source) do
		if type(value) == "table" then
			amount = Analysis.ExtractExpDeltaFromTable(value, (tonumber(depth) or 0) + 1)
			if amount ~= nil then
				return amount
			end
		end
	end
	return nil
end

function Analysis.ExtractExpDeltaFromEvent(...)
	local numbers = {}
	for index = 1, select("#", ...) do
		local value = select(index, ...)
		if type(value) == "table" then
			local amount = Analysis.ExtractExpDeltaFromTable(value, 0)
			if amount ~= nil then
				return amount
			end
		elseif type(value) == "number" then
			numbers[#numbers + 1] = value
		end
	end

	if #numbers == 1 and numbers[1] > 0 then
		return numbers[1]
	end
	return nil
end

function Analysis.HandleExpChangedEvent(...)
	if Analysis.SyncExpGained() then
		return
	end

	local amount = Analysis.ExtractExpDeltaFromEvent(...)
	if amount ~= nil then
		Analysis.AttributeExpGain(amount)
	end
end

function Analysis.SyncManaSpent()
	local mana = SafeUnitValue("UnitMana", "player")
	if mana == nil then
		return
	end
	local lastMana = tonumber(runtime.lastPlayerMana)
	if lastMana ~= nil and mana < lastMana then
		runtime.totalManaSpent = (tonumber(runtime.totalManaSpent) or 0) + (lastMana - mana)
		Analysis.MarkSessionDataSavePending()
		if RefreshViewWindowIfVisible ~= nil then
			RefreshViewWindowIfVisible()
		end
	end
	runtime.lastPlayerMana = mana
end

function Analysis.SyncSessionResourceSnapshots()
	Analysis.SyncManaSpent()
	Analysis.SyncExpGained()
end

function Analysis.RecordSessionDamage(sourceName, targetName, damageAmount)
	damageAmount = Analysis.NormalizePositiveAmount(damageAmount)
	if damageAmount == nil then
		return
	end

	local sourceIsPlayer = IsLocalPlayerName(sourceName)
	local targetIsPlayer = IsLocalPlayerName(targetName)
	local recorded = false
	if sourceIsPlayer and not targetIsPlayer and IsValidName(targetName) then
		targetName = Trim(targetName)
		Analysis.AddAmount(runtime.damageDealtByUnit, targetName, damageAmount)
		runtime.totalDamageDealt = (tonumber(runtime.totalDamageDealt) or 0) + damageAmount
		Analysis.TouchKillCombatActivity()
		recorded = true
	end
	if targetIsPlayer and not sourceIsPlayer and IsValidName(sourceName) then
		sourceName = Trim(sourceName)
		Analysis.AddAmount(runtime.damageTakenByUnit, sourceName, damageAmount)
		runtime.totalDamageTaken = (tonumber(runtime.totalDamageTaken) or 0) + damageAmount
		Analysis.TouchKillCombatActivity()
		recorded = true
	end
	if recorded then
		Analysis.MarkSessionDataSavePending()
	end
	if recorded and RefreshViewWindowIfVisible ~= nil then
		RefreshViewWindowIfVisible()
	end
end

function Analysis.ClearSessionStats()
	runtime.sessionKillCounts = {}
	runtime.damageDealtByUnit = {}
	runtime.damageTakenByUnit = {}
	runtime.damageBySkill = {}
	runtime.damageByCategory = {}
	runtime.damageByElement = {}
	runtime.healBySkill = {}
	runtime.missesBySkill = {}
	runtime.energizeBySkill = {}
	runtime.damageTakenBySource = {}
	runtime.healReceivedBySource = {}
	runtime.damageByTarget = {}
	runtime.sessionKillLocations = {}
	runtime.playerCombatStats = {}
	runtime.itemDropsByUnit = {}
	runtime.expByUnit = {}
	runtime.totalDamageDealt = 0
	runtime.totalDamageTaken = 0
	runtime.totalDroppedItems = 0
	runtime.totalExpGained = 0
	runtime.totalManaSpent = 0
	runtime.totalKillTime = 0
	runtime.combatActive = false
	runtime.combatStart = nil
	runtime.lastCombatActivity = nil
	runtime.sessionLocationText = nil
	runtime.loadingStartLocationText = nil
	runtime.locationRefreshElapsed = 0
	runtime.lastBagSnapshot = nil
	runtime.pendingBagSyncUntil = nil
	runtime.localPlayerName = nil
	runtime.lastPlayerMana = nil
	runtime.lastExpSnapshot = nil
	runtime.lastDamage = nil
	runtime.lastDamageTaken = nil
	runtime.debuffHistory = {}
	runtime.activeDebuffsOnPlayer = {}
	runtime.nextDebuffEventId = 1
	runtime.debuffSyncElapsed = 0
	runtime.savePending = false
	runtime.pendingSaveEvents = 0
	runtime.saveElapsed = 0
	Analysis.SyncSessionResourceSnapshots()
	Analysis.SyncBagDrops(true)
	if RefreshViewWindowIfVisible ~= nil then
		RefreshViewWindowIfVisible()
	end
end

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

	CaptureSessionActivityLocation()
	runtime.killCounts[mobName] = (tonumber(runtime.killCounts[mobName]) or 0) + 1
	runtime.sessionKillCounts[mobName] = (tonumber(runtime.sessionKillCounts[mobName]) or 0) + 1
	Analysis.RecordKillLocation(mobName, killerName)
	if runtime.killerCounts[mobName] == nil then
		runtime.killerCounts[mobName] = {}
	end
	runtime.killerCounts[mobName][killerName] = (tonumber(runtime.killerCounts[mobName][killerName]) or 0) + 1
	runtime.lastKill = {
		mobName = mobName,
		killerName = killerName,
		count = runtime.killCounts[mobName],
		time = RefreshClock(),
	}
	SaveKillCounts()

	if runtime.autoOpenCounterWindow == true and type(runtime.ShowCounterWindow) == "function" then
		runtime:ShowCounterWindow()
	elseif UpdateCounterWindow ~= nil then
		UpdateCounterWindow()
	end
	if RefreshViewWindowIfVisible ~= nil then
		RefreshViewWindowIfVisible()
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
	local msg = Analysis.ParseCombatMessage(...)
	Analysis.RecordDpsReviewCombatMessage(msg)
	local eventType = msg.eventType
	local sourceName = msg.sourceName
	local targetName = msg.targetName
	local damageAmount = GetCombatDamageAmount(eventType, msg.abilityId, msg.effectType)
	if sourceName == "" or targetName == "" then
		return
	end
	if damageAmount == nil then
		return
	end

	Analysis.RecordSessionDamage(sourceName, targetName, damageAmount)
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
	Analysis.ClearSessionStats()
	SaveKillCounts()
	if UpdateCounterWindow ~= nil then
		UpdateCounterWindow()
	end
end

LoadSessionHistory()
LoadKillCounts()
LoadCounterSettings()
Analysis.SyncSessionResourceSnapshots()
Analysis.SyncBagDrops(true)

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

local historyButton = counterWindow:CreateChildWidget("button", "lootKillCounterHistoryButton", 0, true)
historyButton:SetStyle("text_default")
historyButton:SetText("History")
historyButton:SetExtent(64, 20)
historyButton:AddAnchor("TOPRIGHT", counterWindow, -PADDING - 36, 9)

local autoButton = counterWindow:CreateChildWidget("button", "lootKillCounterAutoButton", 0, true)
autoButton:SetStyle("text_default")
autoButton:SetText("Auto: Off")
autoButton:SetExtent(62, 20)
autoButton:AddAnchor("TOPRIGHT", counterWindow, -PADDING - 104, 9)

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
clearButton:SetExtent(48, 22)
clearButton:AddAnchor("BOTTOMLEFT", counterWindow, PADDING, -PADDING)

local viewButton = counterWindow:CreateChildWidget("button", "lootKillCounterViewButton", 0, true)
viewButton:SetStyle("text_default")
viewButton:SetText("View")
viewButton:SetExtent(48, 22)
viewButton:AddAnchor("BOTTOMLEFT", counterWindow, PADDING + 52, -PADDING)

local prevButton = counterWindow:CreateChildWidget("button", "lootKillCounterPrevButton", 0, true)
prevButton:SetStyle("text_default")
prevButton:SetText("Prev")
prevButton:SetExtent(48, 22)
prevButton:AddAnchor("BOTTOMRIGHT", counterWindow, -122, -PADDING)

local nextButton = counterWindow:CreateChildWidget("button", "lootKillCounterNextButton", 0, true)
nextButton:SetStyle("text_default")
nextButton:SetText("Next")
nextButton:SetExtent(48, 22)
nextButton:AddAnchor("BOTTOMRIGHT", counterWindow, -PADDING, -PADDING)

local pageLabel = counterWindow:CreateChildWidget("label", "lootKillCounterPageLabel", 0, true)
pageLabel:SetText("")
pageLabel:SetExtent(38, 20)
pageLabel.style:SetAlign(ALIGN_CENTER)
pageLabel.style:SetFontSize(10)
pageLabel.style:SetColor(0.84, 0.84, 0.84, 1)
pageLabel.style:SetOutline(true)
pageLabel:AddAnchor("BOTTOMRIGHT", counterWindow, -67, -PADDING - 1)

local PositionCounterResizeHandles
local ShowCounterWindowButtons
local ApplyResizeGripVisualScale
local UpdateAutoOpenButton

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
	local historyWidth = RoundScaled(64, scale)
	local autoWidth = RoundScaled(62, scale)
	local historyGap = RoundScaled(4, scale)
	local autoGap = RoundScaled(4, scale)
	local titleHeight = RoundScaled(24, scale)
	local statusHeight = RoundScaled(20, scale)
	local buttonHeight = RoundScaled(22, scale)
	local clearWidth = RoundScaled(48, scale)
	local viewWidth = RoundScaled(48, scale)
	local pageWidth = RoundScaled(38, scale)
	local pageHeight = RoundScaled(20, scale)
	local navWidth = RoundScaled(48, scale)
	local navGap = RoundScaled(4, scale)
	local titleWidth = width - (padding * 3) - closeWidth - historyWidth - historyGap - autoWidth - autoGap
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

	historyButton:SetExtent(historyWidth, closeHeight)
	historyButton:RemoveAllAnchors()
	historyButton:AddAnchor("TOPRIGHT", counterWindow, -(padding + closeWidth + historyGap), padding - 1)
	SetWidgetFontSize(historyButton, RoundScaled(11, scale))

	autoButton:SetExtent(autoWidth, closeHeight)
	autoButton:RemoveAllAnchors()
	autoButton:AddAnchor(
		"TOPRIGHT",
		counterWindow,
		-(padding + closeWidth + historyGap + historyWidth + autoGap),
		padding - 1
	)
	SetWidgetFontSize(autoButton, RoundScaled(11, scale))
	if UpdateAutoOpenButton ~= nil then
		UpdateAutoOpenButton()
	end

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

	viewButton:SetExtent(viewWidth, buttonHeight)
	viewButton:RemoveAllAnchors()
	viewButton:AddAnchor("BOTTOMLEFT", counterWindow, padding + clearWidth + navGap, -padding)
	SetWidgetFontSize(viewButton, RoundScaled(11, scale))

	nextButton:SetExtent(navWidth, buttonHeight)
	nextButton:RemoveAllAnchors()
	nextButton:AddAnchor("BOTTOMRIGHT", counterWindow, -padding, -padding)
	SetWidgetFontSize(nextButton, RoundScaled(11, scale))

	prevButton:SetExtent(navWidth, buttonHeight)
	prevButton:RemoveAllAnchors()
	local prevLeft = padding + clearWidth + navGap + viewWidth + navGap
	local rightGroupWidth = navWidth + navGap + pageWidth + navGap + navWidth
	local rightGroupLeft = width - padding - rightGroupWidth
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
	historyButton:Show(visible)
	autoButton:Show(visible)
	clearButton:Show(visible)
	viewButton:Show(visible)
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
EnableCounterWindowDrag(historyButton)
EnableCounterWindowDrag(autoButton)
EnableCounterWindowDrag(clearButton)
EnableCounterWindowDrag(viewButton)
EnableCounterWindowDrag(prevButton)
EnableCounterWindowDrag(nextButton)
for index = 1, PAGE_SIZE do
	EnableCounterWindowDrag(runtime.rows[index])
end

EnableCounterWindowHover(titleLabel)
EnableCounterWindowHover(statusLabel)
EnableCounterWindowHover(pageLabel)
EnableCounterWindowHover(closeButton)
EnableCounterWindowHover(historyButton)
EnableCounterWindowHover(autoButton)
EnableCounterWindowHover(clearButton)
EnableCounterWindowHover(viewButton)
EnableCounterWindowHover(prevButton)
EnableCounterWindowHover(nextButton)
for index = 1, PAGE_SIZE do
	EnableCounterWindowHover(runtime.rows[index])
end
HideCounterWindowButtons()

UpdateAutoOpenButton = function()
	if runtime.autoOpenCounterWindow == true then
		autoButton:SetText("Auto: On")
	else
		autoButton:SetText("Auto: Off")
	end
end
UpdateAutoOpenButton()

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

function Analysis.GetSessionKillTotal()
	local total = 0
	for _, count in pairs(runtime.sessionKillCounts) do
		count = tonumber(count)
		if count ~= nil and count > 0 then
			total = total + math.floor(count)
		end
	end
	return total
end

function Analysis.AddReportName(names, seen, name)
	if not IsValidName(name) then
		return
	end
	name = Trim(name)
	if seen[name] then
		return
	end
	seen[name] = true
	names[#names + 1] = name
end

function Analysis.BuildSortedReportUnitNames()
	local names = {}
	local seen = {}
	for name in pairs(runtime.sessionKillCounts) do
		Analysis.AddReportName(names, seen, name)
	end
	for name in pairs(runtime.damageDealtByUnit) do
		Analysis.AddReportName(names, seen, name)
	end
	for name in pairs(runtime.damageTakenByUnit) do
		Analysis.AddReportName(names, seen, name)
	end
	for name in pairs(runtime.itemDropsByUnit) do
		Analysis.AddReportName(names, seen, name)
	end
	for name in pairs(runtime.expByUnit) do
		Analysis.AddReportName(names, seen, name)
	end
	table.sort(names, function(left, right)
		local leftKills = tonumber(runtime.sessionKillCounts[left]) or 0
		local rightKills = tonumber(runtime.sessionKillCounts[right]) or 0
		if leftKills ~= rightKills then
			return leftKills > rightKills
		end
		local leftDamage = tonumber(runtime.damageDealtByUnit[left]) or 0
		local rightDamage = tonumber(runtime.damageDealtByUnit[right]) or 0
		if leftDamage ~= rightDamage then
			return leftDamage > rightDamage
		end
		local leftTaken = tonumber(runtime.damageTakenByUnit[left]) or 0
		local rightTaken = tonumber(runtime.damageTakenByUnit[right]) or 0
		if leftTaken ~= rightTaken then
			return leftTaken > rightTaken
		end
		return string.lower(left) < string.lower(right)
	end)
	return names
end

function Analysis.BuildSortedDropNames(drops)
	local names = {}
	if type(drops) ~= "table" then
		return names
	end
	for itemName, count in pairs(drops) do
		if IsValidName(itemName) and tonumber(count) ~= nil and tonumber(count) > 0 then
			names[#names + 1] = itemName
		end
	end
	table.sort(names, function(left, right)
		local leftCount = tonumber(drops[left]) or 0
		local rightCount = tonumber(drops[right]) or 0
		if leftCount ~= rightCount then
			return leftCount > rightCount
		end
		return string.lower(left) < string.lower(right)
	end)
	return names
end

function Analysis.BuildDropSummary(mobName, maxItems)
	local drops = runtime.itemDropsByUnit[mobName]
	local dropNames = Analysis.BuildSortedDropNames(drops)
	if #dropNames == 0 then
		return ""
	end
	maxItems = tonumber(maxItems) or 4
	local parts = {}
	for index, itemName in ipairs(dropNames) do
		if index > maxItems then
			parts[#parts + 1] = "+" .. tostring(#dropNames - maxItems) .. " more"
			break
		end
		parts[#parts + 1] = itemName .. " x" .. Analysis.FormatAmount(drops[itemName])
	end
	return table.concat(parts, ", ")
end

function Analysis.BuildSortedAmountKeys(amountsByKey)
	local keys = {}
	if type(amountsByKey) ~= "table" then
		return keys
	end
	for key, amount in pairs(amountsByKey) do
		if tonumber(amount) ~= nil and tonumber(amount) > 0 then
			keys[#keys + 1] = key
		end
	end
	table.sort(keys, function(left, right)
		local leftAmount = tonumber(amountsByKey[left]) or 0
		local rightAmount = tonumber(amountsByKey[right]) or 0
		if leftAmount ~= rightAmount then
			return leftAmount > rightAmount
		end
		return string.lower(tostring(left)) < string.lower(tostring(right))
	end)
	return keys
end

function Analysis.InferSkillCategory(skillKey, entry)
	if type(entry) == "table" then
		local category = Trim(entry.category or "")
		if category ~= "" then
			return category
		end
	end
	skillKey = tostring(skillKey or "")
	local separator = string.find(skillKey, "::", 1, true)
	if separator ~= nil then
		return string.sub(skillKey, 1, separator - 1)
	end
	if skillKey == "Melee Attack" or skillKey == "Melee" then
		return "Melee"
	end
	return "Spell"
end

function Analysis.RebuildDamageCategories()
	runtime.damageByCategory = {}
	for skillKey, entry in pairs(runtime.damageBySkill) do
		if type(entry) == "table" then
			local damageAmount = tonumber(entry.damage) or 0
			if damageAmount > 0 then
				local category = Analysis.InferSkillCategory(skillKey, entry)
				entry.category = category
				runtime.damageByCategory[category] =
					(tonumber(runtime.damageByCategory[category]) or 0) + damageAmount
			end
		end
	end
end

function Analysis.EnsureDamageCategories()
	if type(runtime.damageByCategory) ~= "table" then
		runtime.damageByCategory = {}
	end
	for _, amount in pairs(runtime.damageByCategory) do
		if tonumber(amount) ~= nil and tonumber(amount) > 0 then
			return
		end
	end
	Analysis.RebuildDamageCategories()
end

function Analysis.BuildSortedCategories()
	local categories = {}
	local seen = {}
	Analysis.EnsureDamageCategories()
	for _, categoryName in ipairs(Analysis.DAMAGE_CATEGORY_ORDER) do
		local amount = tonumber(runtime.damageByCategory[categoryName]) or 0
		if amount > 0 then
			categories[#categories + 1] = categoryName
			seen[categoryName] = true
		end
	end
	for categoryName, amount in pairs(runtime.damageByCategory) do
		if not seen[categoryName] and tonumber(amount) ~= nil and tonumber(amount) > 0 then
			categories[#categories + 1] = categoryName
		end
	end
	return categories
end

function Analysis.BuildSortedEntryKeys(tableData, amountField)
	local amountsByKey = {}
	if type(tableData) ~= "table" then
		return amountsByKey
	end
	for entryKey, entry in pairs(tableData) do
		if type(entry) == "table" then
			local amount = tonumber(entry[amountField]) or 0
			if amount > 0 then
				amountsByKey[entryKey] = amount
			end
		end
	end
	return Analysis.BuildSortedAmountKeys(amountsByKey)
end

function Analysis.GetPlayerDamageTotal()
	local total = 0
	for _, entry in pairs(runtime.damageBySkill) do
		if type(entry) == "table" then
			local amount = tonumber(entry.damage)
			if amount ~= nil and amount > 0 then
				total = total + math.floor(amount)
			end
		end
	end
	if total > 0 then
		return total
	end
	return math.floor((tonumber(runtime.totalDamageDealt) or 0) + 0.5)
end

function Analysis.GetPlayerHealTotal()
	local total = 0
	for _, entry in pairs(runtime.healBySkill) do
		if type(entry) == "table" then
			local amount = tonumber(entry.amount)
			if amount ~= nil and amount > 0 then
				total = total + math.floor(amount)
			end
		end
	end
	return total
end

function Analysis.GetPlayerDps(totalDamage)
	totalDamage = tonumber(totalDamage) or Analysis.GetPlayerDamageTotal()
	local duration = Analysis.GetKillCombatDuration(RefreshClock())
	if duration <= 0 then
		return 0
	end
	return totalDamage / duration
end

function Analysis.CleanAbilityDisplayName(skillKey, entry)
	local displayName = Trim((entry and entry.name) or skillKey or "")
	local separator = string.find(displayName, "::", 1, true)
	if separator ~= nil then
		displayName = Trim(string.sub(displayName, separator + 2))
	end
	separator = string.find(skillKey or "", "::", 1, true)
	if displayName == "" and separator ~= nil then
		displayName = Trim(string.sub(skillKey, separator + 2))
	end
	if displayName == "" then
		displayName = "Unknown"
	end
	return displayName
end

function Analysis.FormatSkillAnalysisLine(name, amount, hits, percentText)
	hits = tonumber(hits) or 0
	local average = 0
	if hits > 0 then
		average = (tonumber(amount) or 0) / hits
	end
	return string.format(
		"  %-18s %8s %4d %6s %5s",
		Analysis.TruncateText(name, 18),
		Analysis.FormatDamage(amount),
		hits,
		Analysis.FormatDamage(average),
		percentText
	)
end

function Analysis.FormatSimpleAmountLine(name, amount, percentText)
	return string.format(
		"  %-22s %10s  (%s)",
		Analysis.TruncateText(name, 22),
		Analysis.FormatDamage(amount),
		percentText
	)
end

function Analysis.BuildCompactBreakdown(amountsByKey, total, maxItems)
	local keys = Analysis.BuildSortedAmountKeys(amountsByKey)
	local parts = {}
	maxItems = tonumber(maxItems) or 4
	for index, key in ipairs(keys) do
		if index > maxItems then
			parts[#parts + 1] = "+" .. tostring(#keys - maxItems) .. " more"
			break
		end
		local amount = tonumber(amountsByKey[key]) or 0
		parts[#parts + 1] = tostring(key) .. " " .. Analysis.FormatPercent(amount, total)
	end
	return table.concat(parts, ", ")
end

function Analysis.AppendCombatReviewLines(lines)
	local stats = Analysis.EnsurePlayerCombatStats()
	local totalDamage = Analysis.GetPlayerDamageTotal()
	local totalHealing = Analysis.GetPlayerHealTotal()
	local hits = tonumber(stats.totalHits) or 0
	local misses = tonumber(stats.totalMisses) or 0
	local damageTaken = tonumber(stats.totalDamageTaken) or 0
	local healingReceived = tonumber(stats.totalHealingReceived) or 0
	local debuffHistoryCount = #(runtime.debuffHistory or {})
	local activeDebuffCount = Analysis.CountActivePlayerDebuffs()
	if damageTaken < (tonumber(runtime.totalDamageTaken) or 0) then
		damageTaken = tonumber(runtime.totalDamageTaken) or 0
	end
	local energizeKeys = Analysis.BuildSortedEntryKeys(runtime.energizeBySkill, "amount")
	if totalDamage <= 0
		and totalHealing <= 0
		and misses <= 0
		and damageTaken <= 0
		and healingReceived <= 0
		and debuffHistoryCount <= 0
		and activeDebuffCount <= 0
		and #energizeKeys == 0
	then
		return true
	end

	local duration = Analysis.GetKillCombatDuration(RefreshClock())
	Analysis.AddViewLine(lines, "spacer", "")
	Analysis.AddViewLine(lines, "header", "Combat Review")
	if totalDamage > 0 then
		Analysis.AddViewLine(
			lines,
			"damage",
			"  DPS "
				.. Analysis.FormatDps(Analysis.GetPlayerDps(totalDamage))
				.. " | Hits "
				.. tostring(hits)
				.. " | Avg "
				.. Analysis.FormatDamage(hits > 0 and (totalDamage / hits) or 0)
				.. " | Max "
				.. Analysis.FormatDamage(stats.largestHit or 0)
		)
	end
	if totalHealing > 0 then
		local healHits = tonumber(stats.totalHealingHits) or 0
		local hps = 0
		if duration > 0 then
			hps = totalHealing / duration
		end
		Analysis.AddViewLine(
			lines,
			"heal",
			"  Healing "
				.. Analysis.FormatDamage(totalHealing)
				.. " | HPS "
				.. Analysis.FormatDps(hps)
				.. " | Casts "
				.. tostring(healHits)
				.. " | Max "
				.. Analysis.FormatDamage(stats.largestHeal or 0)
		)
	end
	if misses > 0 or damageTaken > 0 or healingReceived > 0 then
		Analysis.AddViewLine(
			lines,
			misses > 0 and "warning" or "metric",
			"  Misses "
				.. tostring(misses)
				.. " | Taken "
				.. Analysis.FormatDamage(damageTaken)
				.. " | Healed by others "
				.. Analysis.FormatDamage(healingReceived)
			)
	end
	if debuffHistoryCount > 0 or activeDebuffCount > 0 then
		local debuffsApplied = tonumber(stats.totalDebuffsApplied) or debuffHistoryCount
		Analysis.AddViewLine(
			lines,
			"debuff",
			"  Debuffs "
				.. tostring(debuffsApplied)
				.. " applied"
				.. (activeDebuffCount > 0 and (" | " .. tostring(activeDebuffCount) .. " active") or "")
				.. (debuffHistoryCount > activeDebuffCount and (" | " .. tostring(debuffHistoryCount - activeDebuffCount) .. " ended") or "")
		)
	end

	local categoryText = Analysis.BuildCompactBreakdown(runtime.damageByCategory, totalDamage, 4)
	if categoryText ~= "" then
		Analysis.AddViewLine(lines, "category", Analysis.TruncateText("  Sources: " .. categoryText, 100))
	end

	local skillKeys = Analysis.BuildSortedEntryKeys(runtime.damageBySkill, "damage")
	if #skillKeys > 0 then
		Analysis.AddViewLine(lines, "header", "Damage by Skill")
		Analysis.AddViewLine(lines, "metric", "  Ability               Damage Hits    Avg Share")
		for skillIndex, skillKey in ipairs(skillKeys) do
			if skillIndex > 5 then
				Analysis.AddViewLine(lines, "metric", "  ... +" .. tostring(#skillKeys - 5) .. " more damage skills")
				break
			end
			local entry = runtime.damageBySkill[skillKey] or {}
			local damage = tonumber(entry.damage) or 0
			local displayName = Analysis.CleanAbilityDisplayName(skillKey, entry)
			local missCount = tonumber((runtime.missesBySkill[skillKey] or {}).count) or 0
			if missCount > 0 then
				displayName = displayName .. " (" .. tostring(missCount) .. " miss)"
			end
			Analysis.AddViewLine(
				lines,
				"skill",
				Analysis.FormatSkillAnalysisLine(
					displayName,
					damage,
					tonumber(entry.hits) or 0,
					Analysis.FormatPercent(damage, totalDamage)
				)
			)
		end
	end

	local healKeys = Analysis.BuildSortedEntryKeys(runtime.healBySkill, "amount")
	if #healKeys > 0 then
		Analysis.AddViewLine(lines, "header", "Healing by Skill")
		for healIndex, skillKey in ipairs(healKeys) do
			if healIndex > 3 then
				Analysis.AddViewLine(lines, "metric", "  ... +" .. tostring(#healKeys - 3) .. " more heals")
				break
			end
			local entry = runtime.healBySkill[skillKey] or {}
			local amount = tonumber(entry.amount) or 0
			Analysis.AddViewLine(
				lines,
				"heal",
				Analysis.FormatSkillAnalysisLine(
					Analysis.CleanAbilityDisplayName(skillKey, entry),
					amount,
					tonumber(entry.hits) or 0,
					Analysis.FormatPercent(amount, totalHealing)
				)
			)
		end
	end

	if #energizeKeys > 0 then
		Analysis.AddViewLine(lines, "header", "Resource Energize")
		for energizeIndex, skillKey in ipairs(energizeKeys) do
			if energizeIndex > 3 then
				break
			end
			local entry = runtime.energizeBySkill[skillKey] or {}
			Analysis.AddViewLine(
				lines,
				"metric",
				Analysis.FormatSimpleAmountLine(
					Analysis.CleanAbilityDisplayName(skillKey, entry),
					tonumber(entry.amount) or 0,
					tostring(tonumber(entry.hits) or 0) .. " events"
				)
			)
		end
	end

	if debuffHistoryCount > 0 or activeDebuffCount > 0 then
		Analysis.AddViewLine(lines, "header", "Debuffs on You")
		Analysis.AddViewLine(lines, "metric", "  Debuff            Source       Duration / Effect")

		local activeShown = 0
		if activeDebuffCount > 0 then
			Analysis.AddViewLine(lines, "metric", "  Active:")
			for storageKey, entryId in pairs(runtime.activeDebuffsOnPlayer) do
				if activeShown >= Analysis.DEBUFF_VIEW_LIMIT then
					break
				end
				local entry = select(1, Analysis.FindDebuffHistoryEntry(storageKey, true))
				if entry ~= nil and entry.id == entryId then
					Analysis.AddViewLine(lines, "debuff", Analysis.FormatDebuffAnalysisLine(entry, true))
					Analysis.AddDebuffEffectDetailLine(lines, entry)
					activeShown = activeShown + 1
				end
			end
		end

		local historyShown = 0
		local endedCount = 0
		for index = #runtime.debuffHistory, 1, -1 do
			local entry = runtime.debuffHistory[index]
			if type(entry) == "table" and entry.active ~= true then
				endedCount = endedCount + 1
			end
		end
		if endedCount > 0 then
			if activeShown > 0 then
				Analysis.AddViewLine(lines, "spacer", "")
			end
			Analysis.AddViewLine(lines, "metric", "  Recently Ended:")
			for index = #runtime.debuffHistory, 1, -1 do
				if historyShown >= Analysis.DEBUFF_VIEW_LIMIT then
					break
				end
				local entry = runtime.debuffHistory[index]
				if type(entry) == "table" and entry.active ~= true then
					Analysis.AddViewLine(lines, "warning", Analysis.FormatDebuffAnalysisLine(entry, false))
					Analysis.AddDebuffEffectDetailLine(lines, entry)
					historyShown = historyShown + 1
				end
			end
		end

		if activeShown + historyShown < activeDebuffCount + endedCount then
			Analysis.AddViewLine(lines, "metric", "  ... additional debuff events not shown")
		end
	end
	return true
end

Analysis.VIEW_LINE_COLORS = {
	header = { 0.95, 0.92, 0.82, 1 },
	metric = { 0.82, 0.88, 0.96, 1 },
	mana = { 0.36, 0.62, 1.0, 1 },
	session_kills = { 1.0, 0.58, 0.20, 1 },
	damage = { 1.0, 0.78, 0.22, 1 },
	exp = { 1.0, 0.55, 0.82, 1 },
	items = { 0.78, 0.80, 0.84, 1 },
	time = { 0.72, 0.52, 1.0, 1 },
	damage_taken = { 1.0, 0.30, 0.28, 1 },
	category = { 0.85, 0.78, 0.65, 1 },
	skill = { 1, 1, 1, 1 },
	heal = { 0.55, 0.95, 0.75, 1 },
	debuff = { 0.92, 0.55, 0.82, 1 },
	target = { 0.92, 0.92, 0.92, 1 },
	unit = { 1, 1, 1, 1 },
	drop = { 0.78, 0.80, 0.84, 1 },
	warning = { 1, 0.52, 0.48, 1 },
	spacer = { 0.5, 0.5, 0.5, 0 },
}

function Analysis.ApplyViewLineStyle(label, kind)
	if label == nil or label.style == nil then
		return
	end
	local colors = Analysis.VIEW_LINE_COLORS[kind] or Analysis.VIEW_LINE_COLORS.unit
	label.style:SetColor(colors[1], colors[2], colors[3], colors[4])
	label.style:SetFontSize(kind == "header" and 10 or 9)
end

function Analysis.AddViewLine(lines, kind, text)
	if #lines >= VIEW_CONTENT_ROW_COUNT then
		if lines.overflowShown ~= true then
			lines[VIEW_CONTENT_ROW_COUNT] = { kind = "warning", text = "  ... additional session data not shown" }
			lines.overflowShown = true
		end
		return false
	end
	lines[#lines + 1] = { kind = kind, text = text }
	return true
end

function Analysis.BuildViewDisplayLines()
	local lines = {}
	local unitNames = Analysis.BuildSortedReportUnitNames()
	local sessionKills = Analysis.GetSessionKillTotal()
	local totalDamageDealt = tonumber(runtime.totalDamageDealt) or 0
	local totalDamageTaken = tonumber(runtime.totalDamageTaken) or 0
	local totalExpGained = tonumber(runtime.totalExpGained) or 0
	local totalManaSpent = tonumber(runtime.totalManaSpent) or 0
	local totalDroppedItems = tonumber(runtime.totalDroppedItems) or 0
	local totalKillTime = Analysis.GetKillCombatDuration(RefreshClock())
	local playerCombatStats = Analysis.EnsurePlayerCombatStats()
	local totalCombatDamage = Analysis.GetPlayerDamageTotal()
	local totalHealing = Analysis.GetPlayerHealTotal()
	local totalMisses = tonumber(playerCombatStats.totalMisses) or 0
	local totalHealingReceived = tonumber(playerCombatStats.totalHealingReceived) or 0
	local energizeKeys = Analysis.BuildSortedEntryKeys(runtime.energizeBySkill, "amount")
	local debuffHistoryCount = #(runtime.debuffHistory or {})
	local activeDebuffCount = Analysis.CountActivePlayerDebuffs()

	if #unitNames == 0
		and sessionKills <= 0
		and totalDamageDealt <= 0
		and totalDamageTaken <= 0
		and totalCombatDamage <= 0
		and totalHealing <= 0
		and totalMisses <= 0
		and totalHealingReceived <= 0
		and #energizeKeys == 0
		and debuffHistoryCount <= 0
		and activeDebuffCount <= 0
		and totalExpGained <= 0
		and totalManaSpent <= 0
		and totalDroppedItems <= 0
	then
		Analysis.AddViewLine(lines, "unit", "  No session data recorded yet.")
		Analysis.AddViewLine(lines, "metric", "  Kill mobs or loot items, then open View again.")
		return lines
	end

	Analysis.AddViewLine(lines, "header", "Session Totals")
	Analysis.AddViewLine(lines, "session_kills", "  Session Kills " .. Analysis.FormatAmount(sessionKills))
	Analysis.AddViewLine(lines, "time", "  Time " .. Analysis.FormatDuration(totalKillTime))
	Analysis.AddViewLine(lines, "mana", "  Mana " .. Analysis.FormatAmount(totalManaSpent))
	Analysis.AddViewLine(lines, "exp", "  EXP " .. Analysis.FormatAmount(totalExpGained))
	Analysis.AddViewLine(lines, "damage", "  Damage " .. Analysis.FormatAmount(totalDamageDealt))
	Analysis.AddViewLine(lines, "damage_taken", "  Damage Taken " .. Analysis.FormatAmount(totalDamageTaken))
	Analysis.AddViewLine(lines, "items", "  Items " .. Analysis.FormatAmount(totalDroppedItems))
	if debuffHistoryCount > 0 or activeDebuffCount > 0 then
		local debuffsApplied = tonumber(playerCombatStats.totalDebuffsApplied) or debuffHistoryCount
		Analysis.AddViewLine(
			lines,
			"debuff",
			"  Debuffs "
				.. Analysis.FormatAmount(debuffsApplied)
				.. (activeDebuffCount > 0 and (" | Active " .. Analysis.FormatAmount(activeDebuffCount)) or "")
		)
	end
	Analysis.AppendCombatReviewLines(lines)
	Analysis.AddViewLine(lines, "spacer", "")
	Analysis.AddViewLine(lines, "header", "Units")

	for _, mobName in ipairs(unitNames) do
		local unitLine = "  "
			.. mobName
			.. ": kills "
			.. Analysis.FormatAmount(runtime.sessionKillCounts[mobName])
			.. " | dealt "
			.. Analysis.FormatAmount(runtime.damageDealtByUnit[mobName])
			.. " | taken "
			.. Analysis.FormatAmount(runtime.damageTakenByUnit[mobName])
			.. " | exp "
			.. Analysis.FormatAmount(runtime.expByUnit[mobName])
		if not Analysis.AddViewLine(lines, "unit", Analysis.TruncateText(unitLine, 100)) then
			return lines
		end

		local dropSummary = Analysis.BuildDropSummary(mobName, 4)
		if dropSummary ~= "" then
			if not Analysis.AddViewLine(lines, "drop", Analysis.TruncateText("    drops: " .. dropSummary, 100)) then
				return lines
			end
		end
	end
	return lines
end

function Analysis.HasCurrentSessionData()
	local stats = Analysis.EnsurePlayerCombatStats()
	local energizeKeys = Analysis.BuildSortedEntryKeys(runtime.energizeBySkill, "amount")
	return Analysis.GetSessionKillTotal() > 0
		or (tonumber(runtime.totalDamageDealt) or 0) > 0
		or (tonumber(runtime.totalDamageTaken) or 0) > 0
		or Analysis.GetPlayerDamageTotal() > 0
		or Analysis.GetPlayerHealTotal() > 0
		or (tonumber(stats.totalMisses) or 0) > 0
		or (tonumber(stats.totalHealingReceived) or 0) > 0
		or (tonumber(stats.totalDebuffsApplied) or 0) > 0
		or #(runtime.debuffHistory or {}) > 0
		or next(runtime.activeDebuffsOnPlayer or {}) ~= nil
		or #energizeKeys > 0
		or (tonumber(runtime.totalDroppedItems) or 0) > 0
		or (tonumber(runtime.totalExpGained) or 0) > 0
		or (tonumber(runtime.totalManaSpent) or 0) > 0
end

function Analysis.HasSessionKills()
	return Analysis.GetSessionKillTotal() > 0
end

local function BuildCurrentSessionSummary()
	return "Session Kills "
		.. Analysis.FormatAmount(Analysis.GetSessionKillTotal())
		.. " | Damage "
		.. Analysis.FormatAmount(runtime.totalDamageDealt)
		.. " | EXP "
		.. Analysis.FormatAmount(runtime.totalExpGained)
		.. " | Debuffs "
		.. Analysis.FormatAmount(tonumber(Analysis.EnsurePlayerCombatStats().totalDebuffsApplied) or #(runtime.debuffHistory or {}))
		.. " | Locations "
		.. Analysis.FormatAmount(#(runtime.sessionKillLocations or {}))
end

local function CopyViewLines(lines)
	local copied = {}
	if type(lines) ~= "table" then
		return copied
	end
	for _, line in ipairs(lines) do
		if type(line) == "table" then
			copied[#copied + 1] = {
				kind = tostring(line.kind or "metric"),
				text = tostring(line.text or ""),
			}
		end
	end
	return copied
end

SaveCurrentSessionToHistory = function()
	if not Analysis.HasCurrentSessionData() then
		return false
	end

	Analysis.SyncSessionResourceSnapshots()
	Analysis.SyncActivePlayerDebuffsFromUnit()
	local ok, lines = pcall(Analysis.BuildViewDisplayLines)
	if not ok or type(lines) ~= "table" then
		lines = {
			{ kind = "warning", text = "  Failed to build saved session details." },
			{ kind = "metric", text = "  " .. Analysis.TruncateText(tostring(lines), 90) },
		}
	end

	local sessionName = "S" .. tostring(runtime.nextHistorySessionIndex)
	local sessionLocation = GetHistorySessionLocation()
	if IsValidName(sessionLocation) then
		sessionName = sessionName .. " " .. sessionLocation
	end
	local sessionDate = GetCurrentDateText()
	if IsValidName(sessionDate) then
		sessionName = sessionName .. " " .. sessionDate
	end
	local killLocations = Analysis.CopyKillLocations(runtime.sessionKillLocations)
	runtime.nextHistorySessionIndex = runtime.nextHistorySessionIndex + 1
	runtime.historySessions[#runtime.historySessions + 1] = {
		name = sessionName,
		location = sessionLocation or "",
		date = sessionDate or "",
		summary = BuildCurrentSessionSummary(),
		createdAt = RefreshClock(),
		lines = CopyViewLines(lines),
		killLocations = killLocations,
	}
	runtime.historyPage = 1
	SaveSessionHistory()
	return true
end

function Analysis.AddHistoryLine(lines, kind, text, sessionIndex)
	lines[#lines + 1] = { kind = kind, text = text, sessionIndex = sessionIndex }
end

function Analysis.BuildAllHistoryDisplayLines()
	local lines = {}
	if #runtime.historySessions == 0 then
		Analysis.AddHistoryLine(lines, "unit", "  No saved sessions yet.")
		Analysis.AddHistoryLine(lines, "metric", "  Sessions are saved after a loading screen finishes.")
		return lines
	end

	for sessionIndex = #runtime.historySessions, 1, -1 do
		local session = runtime.historySessions[sessionIndex]
		if type(session) == "table" then
			Analysis.AddHistoryLine(lines, "header", tostring(session.name or ("S" .. tostring(sessionIndex))), sessionIndex)
			Analysis.AddHistoryLine(lines, "metric", "  " .. Analysis.TruncateText(session.summary or "", 100), sessionIndex)
			if #(session.killLocations or {}) > 0 then
				Analysis.AddHistoryLine(
					lines,
					"time",
					"  Kill map: " .. Analysis.FormatAmount(#session.killLocations) .. " recorded kill locations",
					sessionIndex
				)
			end

			local shown = 0
			if type(session.lines) == "table" then
				for _, line in ipairs(session.lines) do
					local text = tostring(line.text or "")
					if text ~= "" and line.kind ~= "spacer" and line.kind ~= "header" then
						Analysis.AddHistoryLine(lines, line.kind or "metric", Analysis.TruncateText("  " .. Trim(text), 100), sessionIndex)
						shown = shown + 1
						if shown >= 2 then
							break
						end
					end
				end
			end
			Analysis.AddHistoryLine(lines, "spacer", "")
		end
	end
	return lines
end

function Analysis.GetHistoryPageInfo(allLines)
	local totalRows = #allLines
	local totalPages = math.ceil(totalRows / VIEW_CONTENT_ROW_COUNT)
	if totalPages < 1 then
		totalPages = 1
	end
	if runtime.historyPage < 1 then
		runtime.historyPage = 1
	elseif runtime.historyPage > totalPages then
		runtime.historyPage = totalPages
	end
	return runtime.historyPage, totalPages
end

function Analysis.BuildHistoryDisplayLines()
	local allLines = Analysis.BuildAllHistoryDisplayLines()
	local page, totalPages = Analysis.GetHistoryPageInfo(allLines)
	local startIndex = ((page - 1) * VIEW_CONTENT_ROW_COUNT) + 1
	local lines = {}
	for rowIndex = 1, VIEW_CONTENT_ROW_COUNT do
		local line = allLines[startIndex + rowIndex - 1]
		if line == nil then
			break
		end
		lines[#lines + 1] = line
	end
	return lines, page, totalPages
end

function Analysis.GetHistorySession(sessionIndex)
	sessionIndex = tonumber(sessionIndex)
	if sessionIndex == nil then
		return nil
	end
	return runtime.historySessions[sessionIndex]
end

function Analysis.HideKillMapObject(object)
	if object == nil then
		return
	end
	SafeCall(object, "SetVisible", false)
	SafeCall(object, "Show", false)
end

function Analysis.TrackKillMapObject(object)
	if object ~= nil then
		runtime.killMapObjects[#runtime.killMapObjects + 1] = object
	end
	return object
end

function Analysis.GetWorldMapContent()
	local mapEdit = _G.LootMapEdit
	if type(mapEdit) == "table" and type(mapEdit.GetWorldMapContent) == "function" then
		return mapEdit:GetWorldMapContent()
	end
	if ADDON == nil or type(ADDON.GetContent) ~= "function" or UIC_WORLDMAP == nil then
		return nil
	end
	local ok, content = SafeCall(ADDON, "GetContent", UIC_WORLDMAP)
	if ok then
		return content
	end
	return nil
end

function Analysis.ClearWorldMapKillEffects()
	local mapWidget = Analysis.GetWorldMapContent()
	if mapWidget == nil then
		return false
	end
	for index = 1, Analysis.KILL_MAP_EFFECT_LIMIT do
		SafeCall(mapWidget, "ShowSkillMapEffect", 0, 0, 0, 0, index)
	end
	return true
end

function Analysis.ClearKillMapObjects()
	for _, object in ipairs(runtime.killMapObjects or {}) do
		Analysis.HideKillMapObject(object)
	end
	runtime.killMapObjects = {}
	runtime.killMapWidget = nil
	runtime.killMapPathLine = nil
	Analysis.ClearWorldMapKillEffects()
end

function Analysis.GetKillLocationMapCoordinates(point)
	if type(point) ~= "table" then
		return nil, nil, nil
	end
	local x = tonumber(point.worldX)
	local y = tonumber(point.worldY)
	local z = tonumber(point.worldZ)
	if (x == nil or y == nil) and tostring(point.coordinateSource or "") ~= "local" then
		x = tonumber(point.x)
		y = tonumber(point.y)
		z = tonumber(point.z)
	end
	if x == nil or y == nil then
		return nil, nil, nil
	end
	return x, y, tonumber(z) or 0
end

function Analysis.GetKillLocationBounds(points)
	local bounds = nil
	for _, point in ipairs(points or {}) do
		local x, y = Analysis.GetKillLocationMapCoordinates(point)
		if x ~= nil and y ~= nil then
			if bounds == nil then
				bounds = { minX = x, maxX = x, minY = y, maxY = y, count = 1 }
			else
				if x < bounds.minX then
					bounds.minX = x
				end
				if x > bounds.maxX then
					bounds.maxX = x
				end
				if y < bounds.minY then
					bounds.minY = y
				end
				if y > bounds.maxY then
					bounds.maxY = y
				end
				bounds.count = bounds.count + 1
			end
		end
	end
	return bounds
end

function Analysis.GetSessionMapAnchor(session)
	local locations = Analysis.CopyKillLocations(session and session.killLocations)
	local sumX = 0
	local sumY = 0
	local sumZ = 0
	local count = 0
	local zoneCounts = {}
	local bestZoneGroup = tonumber(session and session.zoneGroup)
	local bestZoneCount = 0

	for _, point in ipairs(locations) do
		local zoneGroup = tonumber(point.zoneGroup)
		if zoneGroup ~= nil then
			local key = tostring(zoneGroup)
			zoneCounts[key] = (tonumber(zoneCounts[key]) or 0) + 1
			if zoneCounts[key] > bestZoneCount then
				bestZoneCount = zoneCounts[key]
				bestZoneGroup = zoneGroup
			end
		end
		local x, y, z = Analysis.GetKillLocationMapCoordinates(point)
		if x ~= nil and y ~= nil then
			sumX = sumX + x
			sumY = sumY + y
			sumZ = sumZ + (tonumber(z) or 0)
			count = count + 1
		end
	end

	if bestZoneGroup == nil then
		return nil, locations
	end
	if count <= 0 then
		return {
			zoneGroup = bestZoneGroup,
			x = 0,
			y = 0,
			z = 0,
			count = 0,
		}, locations
	end
	return {
		zoneGroup = bestZoneGroup,
		x = sumX / count,
		y = sumY / count,
		z = sumZ / count,
		count = count,
	}, locations
end

function Analysis.BuildKillRouteSamples(points, maxCount)
	local samples = {}
	local candidates = {}
	for _, point in ipairs(points or {}) do
		local x, y, z = Analysis.GetKillLocationMapCoordinates(point)
		if x ~= nil and y ~= nil then
			candidates[#candidates + 1] = {
				x = x,
				y = y,
				z = z,
			}
		end
	end

	maxCount = math.max(1, tonumber(maxCount) or Analysis.KILL_MAP_ROUTE_EFFECT_LIMIT)
	if #candidates <= maxCount then
		return candidates
	end
	if maxCount == 1 then
		return { candidates[#candidates] }
	end

	local step = (#candidates - 1) / (maxCount - 1)
	local lastIndex = 0
	for sampleIndex = 1, maxCount do
		local candidateIndex = math.floor(1 + ((sampleIndex - 1) * step) + 0.5)
		if candidateIndex <= lastIndex then
			candidateIndex = lastIndex + 1
		end
		if candidateIndex > #candidates then
			candidateIndex = #candidates
		end
		samples[#samples + 1] = candidates[candidateIndex]
		lastIndex = candidateIndex
	end
	return samples
end

-- The built-in map APIs consume world coordinates. Clustering in that same
-- coordinate space keeps hotspot circles anchored to the real session map.
function Analysis.BuildKillHotspots(points, maxCount)
	local cells = {}
	local bounds = Analysis.GetKillLocationBounds(points)
	local cellSize = tonumber(Analysis.KILL_MAP_HOTSPOT_CELL_SIZE) or 54
	if bounds ~= nil then
		local span = math.max(bounds.maxX - bounds.minX, bounds.maxY - bounds.minY)
		if span > 0 then
			cellSize = math.max(cellSize, span / 12)
		end
	end
	for _, point in ipairs(points or {}) do
		local x, y, z = Analysis.GetKillLocationMapCoordinates(point)
		if x ~= nil and y ~= nil then
			local cellX = math.floor(x / cellSize)
			local cellY = math.floor(y / cellSize)
			local key = tostring(cellX) .. ":" .. tostring(cellY)
			local cell = cells[key]
			if cell == nil then
				cell = { count = 0, sumX = 0, sumY = 0, sumZ = 0 }
				cells[key] = cell
			end
			cell.count = cell.count + 1
			cell.sumX = cell.sumX + x
			cell.sumY = cell.sumY + y
			cell.sumZ = cell.sumZ + (tonumber(z) or 0)
		end
	end

	local hotspots = {}
	for _, cell in pairs(cells) do
		if cell.count > 0 then
			local radius = math.max(18, (cellSize * 0.55) + math.min(cellSize, cell.count * 4))
			hotspots[#hotspots + 1] = {
				x = cell.sumX / cell.count,
				y = cell.sumY / cell.count,
				z = cell.sumZ / cell.count,
				count = cell.count,
				radius = radius,
			}
		end
	end
	table.sort(hotspots, function(left, right)
		if left.count ~= right.count then
			return left.count > right.count
		end
		return left.radius > right.radius
	end)
	maxCount = math.max(0, tonumber(maxCount) or Analysis.KILL_MAP_HOTSPOT_LIMIT)
	while #hotspots > maxCount do
		table.remove(hotspots)
	end
	return hotspots
end

function Analysis.OpenKillSessionWorldMap(session)
	local anchor = Analysis.GetSessionMapAnchor(session)
	if anchor == nil then
		return false, false
	end
	local ok = SafeCall(X2Map, "ShowWorldmapLocation", anchor.zoneGroup, anchor.x, anchor.y, anchor.z)
	return ok == true, (tonumber(anchor.count) or 0) > 0
end

function Analysis.RenderKillMapSession(session)
	local mapEdit = _G.LootMapEdit
	if type(mapEdit) ~= "table" or type(mapEdit.MarkWorldArea) ~= "function" then
		return false
	end
	local mapWidget = Analysis.GetWorldMapContent()
	if mapWidget == nil then
		return false
	end
	local locations = Analysis.CopyKillLocations(session and session.killLocations)
	if #locations == 0 then
		return false
	end

	Analysis.ClearWorldMapKillEffects()
	local effectIndex = 1
	local routeLimit = math.min(Analysis.KILL_MAP_ROUTE_EFFECT_LIMIT, Analysis.KILL_MAP_EFFECT_LIMIT)
	local routeSamples = Analysis.BuildKillRouteSamples(locations, routeLimit)
	for _, sample in ipairs(routeSamples) do
		if effectIndex > Analysis.KILL_MAP_EFFECT_LIMIT then
			return true
		end
		mapEdit:MarkWorldArea(mapWidget, sample.x, sample.y, sample.z, 18, effectIndex, {})
		effectIndex = effectIndex + 1
	end

	local hotspotLimit = Analysis.KILL_MAP_EFFECT_LIMIT - effectIndex + 1
	local hotspots = Analysis.BuildKillHotspots(locations, math.min(Analysis.KILL_MAP_HOTSPOT_LIMIT, hotspotLimit))
	for _, hotspot in ipairs(hotspots) do
		if effectIndex > Analysis.KILL_MAP_EFFECT_LIMIT then
			return true
		end
		mapEdit:MarkWorldArea(mapWidget, hotspot.x, hotspot.y, hotspot.z, hotspot.radius, effectIndex, {})
		effectIndex = effectIndex + 1
	end
	return true
end

function Analysis.ScheduleKillMapOverlay(session)
	runtime.pendingKillMapSession = session
	runtime.killMapOverlayElapsed = Analysis.KILL_MAP_EFFECT_RETRY_SECONDS
	runtime.killMapOverlayAttempts = 0
end

function Analysis.UpdatePendingKillMapOverlay(elapsed)
	if runtime.pendingKillMapSession == nil then
		return
	end
	runtime.killMapOverlayElapsed = (tonumber(runtime.killMapOverlayElapsed) or 0) + (tonumber(elapsed) or 0)
	if runtime.killMapOverlayElapsed < Analysis.KILL_MAP_EFFECT_RETRY_SECONDS then
		return
	end
	runtime.killMapOverlayElapsed = 0
	runtime.killMapOverlayAttempts = (tonumber(runtime.killMapOverlayAttempts) or 0) + 1
	if Analysis.RenderKillMapSession(runtime.pendingKillMapSession) or runtime.killMapOverlayAttempts >= Analysis.KILL_MAP_EFFECT_RETRY_LIMIT then
		runtime.pendingKillMapSession = nil
	end
end

local viewWindowX, viewWindowY = LoadPosition(VIEW_WINDOW_POSITION_KEY, 720, 318)
local viewWindow = CreateEmptyWindow("lootKillCounterViewWindow", "UIParent")
runtime.viewWindow = viewWindow
viewWindow:SetExtent(VIEW_WINDOW_WIDTH, VIEW_WINDOW_HEIGHT)
viewWindow:AddAnchor("TOPLEFT", "UIParent", viewWindowX, viewWindowY)
viewWindow:EnableDrag(true)
viewWindow:Clickable(true)
viewWindow:Show(false)

local viewBackground = viewWindow:CreateColorDrawable(0, 0, 0, 0.72, "background")
viewBackground:AddAnchor("TOPLEFT", viewWindow, 0, 0)
viewBackground:AddAnchor("BOTTOMRIGHT", viewWindow, 0, 0)

local viewTitleLabel = viewWindow:CreateChildWidget("label", "lootKillCounterViewTitle", 0, true)
runtime.viewTitleLabel = viewTitleLabel
viewTitleLabel:SetText("Kill Session Analysis")
viewTitleLabel:SetExtent(VIEW_WINDOW_WIDTH - (PADDING * 2) - 220, 24)
viewTitleLabel.style:SetAlign(ALIGN_LEFT)
viewTitleLabel.style:SetFontSize(13)
viewTitleLabel.style:SetColor(0.95, 0.92, 0.82, 1)
viewTitleLabel.style:SetOutline(true)
viewTitleLabel:AddAnchor("TOPLEFT", viewWindow, PADDING, 10)

local viewCloseButton = viewWindow:CreateChildWidget("button", "lootKillCounterViewCloseButton", 0, true)
runtime.viewCloseButton = viewCloseButton
viewCloseButton:SetStyle("text_default")
viewCloseButton:SetText("X")
viewCloseButton:SetExtent(32, 20)
viewCloseButton:AddAnchor("TOPRIGHT", viewWindow, -PADDING, 9)

local historyClearButton = viewWindow:CreateChildWidget("button", "lootKillCounterHistoryClearButton", 0, true)
historyClearButton:SetStyle("text_default")
historyClearButton:SetText("Clear")
historyClearButton:SetExtent(48, 20)
historyClearButton:AddAnchor("TOPRIGHT", viewWindow, -PADDING - 36, 9)

local historyNextButton = viewWindow:CreateChildWidget("button", "lootKillCounterHistoryNextButton", 0, true)
historyNextButton:SetStyle("text_default")
historyNextButton:SetText("Next")
historyNextButton:SetExtent(44, 20)
historyNextButton:AddAnchor("TOPRIGHT", viewWindow, -PADDING - 88, 9)

local historyPageLabel = viewWindow:CreateChildWidget("label", "lootKillCounterHistoryPageLabel", 0, true)
historyPageLabel:SetText("")
historyPageLabel:SetExtent(44, 20)
historyPageLabel.style:SetAlign(ALIGN_CENTER)
historyPageLabel.style:SetFontSize(10)
historyPageLabel.style:SetColor(0.84, 0.84, 0.84, 1)
historyPageLabel.style:SetOutline(true)
historyPageLabel:AddAnchor("TOPRIGHT", viewWindow, -PADDING - 136, 10)

local historyPrevButton = viewWindow:CreateChildWidget("button", "lootKillCounterHistoryPrevButton", 0, true)
historyPrevButton:SetStyle("text_default")
historyPrevButton:SetText("Prev")
historyPrevButton:SetExtent(44, 20)
historyPrevButton:AddAnchor("TOPRIGHT", viewWindow, -PADDING - 184, 9)

local viewSummaryLabel = viewWindow:CreateChildWidget("label", "lootKillCounterViewSummary", 0, true)
runtime.viewSummaryLabel = viewSummaryLabel
viewSummaryLabel:SetText("")
viewSummaryLabel:SetExtent(VIEW_WINDOW_WIDTH - (PADDING * 2), 36)
viewSummaryLabel.style:SetAlign(ALIGN_LEFT)
viewSummaryLabel.style:SetFontSize(10)
viewSummaryLabel.style:SetColor(0.78, 0.84, 0.92, 1)
viewSummaryLabel.style:SetOutline(true)
viewSummaryLabel:AddAnchor("TOPLEFT", viewWindow, PADDING, 34)

for index = 1, VIEW_CONTENT_ROW_COUNT do
	local row = viewWindow:CreateChildWidget("label", "lootKillCounterViewRow" .. tostring(index), 0, true)
	row:SetText("")
	row:SetExtent(VIEW_WINDOW_WIDTH - (PADDING * 2), VIEW_ROW_HEIGHT)
	row.style:SetAlign(ALIGN_LEFT)
	row.style:SetFontSize(9)
	row.style:SetColor(1, 1, 1, 1)
	row.style:SetOutline(true)
	row:AddAnchor("TOPLEFT", viewWindow, PADDING, VIEW_ROW_TOP + ((index - 1) * VIEW_ROW_HEIGHT))
	SafeCall(row, "EnablePick", true)
	SafeCall(row, "Clickable", true)
	function row:OnClick()
		if runtime.viewMode == "history" and self.historySessionIndex ~= nil then
			runtime:ShowKillMapSession(self.historySessionIndex)
		end
	end
	row:SetHandler("OnClick", row.OnClick)
	runtime.viewContentRows[index] = row
end

local function SetHistoryViewControlsVisible(visible, hasPages)
	historyClearButton:Show(visible and #runtime.historySessions > 0)
	historyPrevButton:Show(visible and hasPages == true)
	historyPageLabel:Show(visible and hasPages == true)
	historyNextButton:Show(visible and hasPages == true)
end
SetHistoryViewControlsVisible(false, false)

UpdateViewWindow = function()
	if runtime.viewSummaryLabel == nil then
		return
	end
	if runtime.viewMode == "history" then
		runtime.viewTitleLabel:SetText("Kill Session History")
		runtime.viewTitleLabel:SetExtent(VIEW_WINDOW_WIDTH - (PADDING * 2) - 220, 24)
		local latest = runtime.historySessions[#runtime.historySessions]
		local summaryText = tostring(#runtime.historySessions) .. " saved sessions"
		if type(latest) == "table" and latest.name ~= nil then
			summaryText = summaryText .. " | Latest " .. tostring(latest.name)
		end
		runtime.viewSummaryLabel:SetText(summaryText)
		local historyLines, page, totalPages = Analysis.BuildHistoryDisplayLines()
		local hasPages = totalPages > 1
		historyPageLabel:SetText(tostring(page) .. "/" .. tostring(totalPages))
		SetHistoryViewControlsVisible(true, hasPages)
		for rowIndex = 1, VIEW_CONTENT_ROW_COUNT do
			local row = runtime.viewContentRows[rowIndex]
			if row ~= nil then
				local line = historyLines[rowIndex]
				if line == nil then
					row:SetText("")
					row.historySessionIndex = nil
				else
					Analysis.ApplyViewLineStyle(row, line.kind)
					row:SetText(tostring(line.text or ""))
					row.historySessionIndex = line.sessionIndex
				end
			end
		end
		return
	end

	SetHistoryViewControlsVisible(false, false)
	runtime.viewTitleLabel:SetText("Kill Session Analysis")
	runtime.viewTitleLabel:SetExtent(VIEW_WINDOW_WIDTH - (PADDING * 2) - 36, 24)
	local playerName = GetLocalPlayerName() or "You"
	local summaryText = playerName .. " current session"
	local location = CaptureCurrentSessionLocation()
	if IsValidName(location) then
		summaryText = summaryText .. " | " .. location
	end
	runtime.viewSummaryLabel:SetText(Analysis.TruncateText(summaryText, 120))

	local lines = Analysis.BuildViewDisplayLines()
	for rowIndex = 1, VIEW_CONTENT_ROW_COUNT do
		local row = runtime.viewContentRows[rowIndex]
		if row ~= nil then
			local line = lines[rowIndex]
			row.historySessionIndex = nil
			if line == nil then
				row:SetText("")
			else
				Analysis.ApplyViewLineStyle(row, line.kind)
				row:SetText(tostring(line.text or ""))
			end
		end
	end
end

RefreshViewWindowIfVisible = function()
	if runtime.viewWindow == nil or UpdateViewWindow == nil then
		return
	end
	local ok, visible = SafeCall(runtime.viewWindow, "IsVisible")
	if ok and visible then
		UpdateViewWindow()
	end
end

function runtime:ShowViewWindow()
	runtime.viewMode = "current"
	Analysis.SyncSessionResourceSnapshots()
	if UpdateViewWindow ~= nil then
		UpdateViewWindow()
	end
	viewWindow:Show(true)
	SafeCall(viewWindow, "CorrectOffsetByScreen")
	SafeCall(viewWindow, "Raise")
end

function runtime:ShowHistoryWindow()
	runtime.viewMode = "history"
	runtime.historyPage = 1
	if UpdateViewWindow ~= nil then
		UpdateViewWindow()
	end
	viewWindow:Show(true)
	SafeCall(viewWindow, "CorrectOffsetByScreen")
	SafeCall(viewWindow, "Raise")
end

function viewButton:OnClick()
	if WasCounterWindowDragged(self) then
		return
	end
	runtime:ShowViewWindow()
end
viewButton:SetHandler("OnClick", viewButton.OnClick)

function historyButton:OnClick()
	if WasCounterWindowDragged(self) then
		return
	end
	runtime:ShowHistoryWindow()
end
historyButton:SetHandler("OnClick", historyButton.OnClick)

function autoButton:OnClick()
	if WasCounterWindowDragged(self) then
		return
	end
	runtime.autoOpenCounterWindow = not runtime.autoOpenCounterWindow
	UpdateAutoOpenButton()
	SaveCounterSettings()
end
autoButton:SetHandler("OnClick", autoButton.OnClick)

function viewCloseButton:OnClick()
	viewWindow:Show(false)
end
viewCloseButton:SetHandler("OnClick", viewCloseButton.OnClick)

function historyClearButton:OnClick()
	ClearSessionHistory()
end
historyClearButton:SetHandler("OnClick", historyClearButton.OnClick)

function historyPrevButton:OnClick()
	runtime.historyPage = runtime.historyPage - 1
	if UpdateViewWindow ~= nil then
		UpdateViewWindow()
	end
end
historyPrevButton:SetHandler("OnClick", historyPrevButton.OnClick)

function historyNextButton:OnClick()
	runtime.historyPage = runtime.historyPage + 1
	if UpdateViewWindow ~= nil then
		UpdateViewWindow()
	end
end
historyNextButton:SetHandler("OnClick", historyNextButton.OnClick)

function viewWindow:OnDragStart()
	self:StartMoving()
end
viewWindow:SetHandler("OnDragStart", viewWindow.OnDragStart)

function viewWindow:OnDragStop()
	self:StopMovingOrSizing()
	SaveWidgetPosition(self, VIEW_WINDOW_POSITION_KEY)
end
viewWindow:SetHandler("OnDragStop", viewWindow.OnDragStop)

function runtime:ShowKillMapSession(sessionIndex)
	local session = Analysis.GetHistorySession(sessionIndex)
	if type(session) ~= "table" then
		return
	end
	runtime.killMapSessionIndex = tonumber(sessionIndex)
	runtime.pendingKillMapSession = nil
	Analysis.ClearKillMapObjects()
	local opened, hasMapCoordinates = Analysis.OpenKillSessionWorldMap(session)
	if opened and hasMapCoordinates then
		Analysis.ScheduleKillMapOverlay(session)
	end
end

local eventWindow = CreateEmptyWindow("lootKillCounterEventWindow", "UIParent")
runtime.eventWindow = eventWindow
eventWindow:Show(false)

function eventWindow:OnEvent(event, ...)
	if not runtime.active then
		return
	end
	RefreshClock()
	if event == "ENTERED_LOADING" then
		CaptureLoadingStartLocation()
		runtime.gameLoadingStarted = true
		return
	end
	if event == "LEFT_LOADING" then
		if runtime.gameLoadingStarted then
			SaveCurrentSessionToHistory()
			ClearKillCounts()
		end
		runtime.gameLoadingStarted = false
		CaptureCurrentSessionLocation()
		return
	end
	if not runtime.gameLoadingStarted then
		CaptureCurrentSessionLocation()
	end
	if event == "UNIT_COMBAT_STATE_CHANGED" then
		Analysis.EvaluateKillCombatEnd(RefreshClock())
		return
	end
	if event == "DEBUFF_UPDATE" then
		CaptureSessionActivityLocation()
		if Analysis.SyncActivePlayerDebuffsFromUnit() then
			RefreshViewWindowIfVisible()
		end
		return
	end
	if event == "COMBAT_MSG" then
		CaptureSessionActivityLocation()
		UpdateCurrentTarget(true)
		HandleCombatMessage(...)
		return
	end
	if event == "ITEM_ACQUISITION_BY_LOOT" then
		CaptureSessionActivityLocation()
		Analysis.HandleLootAcquisitionEvent(...)
		return
	end
	if event == "LOOT_BAG_CHANGED" then
		Analysis.ScheduleBagDropSync()
		return
	end
	if event == "LOOT_BAG_CLOSE" then
		runtime.pendingBagSyncUntil = nil
		Analysis.SyncBagDrops(true)
		return
	end
	if event == "EXP_CHANGED" then
		CaptureSessionActivityLocation()
		Analysis.HandleExpChangedEvent(...)
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
	if event == "ENTERED_WORLD" or event == "UPDATE_ZONE_LEVEL_INFO" then
		return
	end
	UpdateCurrentTarget()
end
eventWindow:SetHandler("OnEvent", eventWindow.OnEvent)

eventWindow:RegisterEvent("COMBAT_MSG")
eventWindow:RegisterEvent("ITEM_ACQUISITION_BY_LOOT")
eventWindow:RegisterEvent("LOOT_BAG_CHANGED")
eventWindow:RegisterEvent("LOOT_BAG_CLOSE")
eventWindow:RegisterEvent("EXP_CHANGED")
eventWindow:RegisterEvent("SPELLCAST_START")
eventWindow:RegisterEvent("SPELLCAST_SUCCEEDED")
eventWindow:RegisterEvent("UNIT_COMBAT_STATE_CHANGED")
eventWindow:RegisterEvent("DEBUFF_UPDATE")
eventWindow:RegisterEvent("TARGET_CHANGED")
eventWindow:RegisterEvent("TARGET_TO_TARGET_CHANGED")
eventWindow:RegisterEvent("AGGRO_METER_CLEARED")
eventWindow:RegisterEvent("ENTERED_LOADING")
eventWindow:RegisterEvent("LEFT_LOADING")
eventWindow:RegisterEvent("ENTERED_WORLD")
eventWindow:RegisterEvent("UPDATE_ZONE_LEVEL_INFO")

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
			CaptureCurrentSessionLocation()
		end
	end
	Analysis.UpdatePendingKillMapOverlay(locationTickElapsed)
	runtime.debuffSyncElapsed = (tonumber(runtime.debuffSyncElapsed) or 0) + locationTickElapsed
	if runtime.debuffSyncElapsed >= 1 then
		runtime.debuffSyncElapsed = 0
		if Analysis.SyncActivePlayerDebuffsFromUnit() then
			RefreshViewWindowIfVisible()
		end
	end
	Analysis.SyncSessionResourceSnapshots()
	if runtime.pendingBagSyncUntil ~= nil then
		Analysis.SyncBagDrops(false)
		if now >= runtime.pendingBagSyncUntil then
			runtime.pendingBagSyncUntil = nil
		end
	end
	Analysis.EvaluateKillCombatEnd(now)
	PruneTargetSnapshots()
	PrunePendingTargetHits()
	UpdateCurrentTarget()
end
eventWindow:SetHandler("OnUpdate", eventWindow.OnUpdate)

UpdateCounterWindow()
