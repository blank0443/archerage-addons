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

-- Available unit fields for export / aligned save (edit EXPORT_FIELDS to change):
--   name     - player display name
--   unitId   - session unit id (empty after relog / zone change)
--   datetime - when the entry was added (stored as addedAt)
--   location - coords + zone captured when added (table in SaveData; text in export)
--   guild    - expedition / guild name
--   faction  - resolved camp: nuia, haranya, or pirate
--   note     - free-text note from the Note UI
listSave.EXPORT_FIELDS = {
	"name",
	"unitId",
	"datetime",
	"note",
	"location",
	"guild",
	"faction"
}

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

local function GetCurrentDateTimeText()
	if type(os) == "table" and type(os.date) == "function" then
		local ok, value = pcall(os.date, "%Y-%m-%d %H:%M:%S")
		if ok and type(value) == "string" and value ~= "" then
			return value
		end
	end

	local ok, timeTable = SafeCall(UIParent, "GetServerTimeTable")
	if ok and type(timeTable) == "table" then
		local year = tonumber(timeTable.year)
		local month = tonumber(timeTable.month)
		local day = tonumber(timeTable.day)
		local hour = tonumber(timeTable.hour) or 0
		local minute = tonumber(timeTable.minute) or 0
		local second = tonumber(timeTable.second) or 0
		if year ~= nil and month ~= nil and day ~= nil then
			return string.format("%04d-%02d-%02d %02d:%02d:%02d", year, month, day, hour, minute, second)
		end
	end

	return ""
end

local function ClearUnitIdKey(unitId, key)
	unitId = NormalizeUnitId(unitId)
	if unitId ~= nil and runtime.unitIdKeys[unitId] == key then
		runtime.unitIdKeys[unitId] = nil
	end
end

local function BindUnitIdKey(unitId, key)
	unitId = NormalizeUnitId(unitId)
	if unitId == nil or key == nil or key == "" then
		return
	end

	-- One unitId maps to one list key; drop a stale reverse mapping if needed.
	local previousKey = runtime.unitIdKeys[unitId]
	if previousKey ~= nil and previousKey ~= key then
		local previousEntry = runtime.friendly[previousKey] or runtime.hostile[previousKey]
		if type(previousEntry) == "table" and NormalizeUnitId(previousEntry.unitId) == unitId then
			previousEntry.unitId = nil
		end
	end
	runtime.unitIdKeys[unitId] = key
end

-- Membership: name key first, then unitId when the name is missing (rename / stale key).
local function FindTrackedEntry(nameKey, unitId)
	if nameKey ~= nil and nameKey ~= "" then
		if runtime.friendly[nameKey] ~= nil then
			return "friendly", nameKey, runtime.friendly[nameKey]
		end
		if runtime.hostile[nameKey] ~= nil then
			return "hostile", nameKey, runtime.hostile[nameKey]
		end
	end

	unitId = NormalizeUnitId(unitId)
	if unitId == nil then
		return nil, nil, nil
	end

	local key = runtime.unitIdKeys[unitId]
	if key == nil or key == "" then
		return nil, nil, nil
	end
	if runtime.friendly[key] ~= nil then
		return "friendly", key, runtime.friendly[key]
	end
	if runtime.hostile[key] ~= nil then
		return "hostile", key, runtime.hostile[key]
	end

	runtime.unitIdKeys[unitId] = nil
	return nil, nil, nil
end

local function MigrateTrackedKey(oldKey, newKey)
	if oldKey == nil or newKey == nil or oldKey == "" or newKey == "" or oldKey == newKey then
		return
	end

	if runtime.notes[oldKey] ~= nil and runtime.notes[newKey] == nil then
		runtime.notes[newKey] = runtime.notes[oldKey]
	end
	runtime.notes[oldKey] = nil

	if runtime.noteTargetKey == oldKey then
		runtime.noteTargetKey = newKey
	end
	if runtime.lastMarkedKey == oldKey then
		runtime.lastMarkedKey = newKey
	end

	local attempts = runtime.markerWriteAttempts
	if type(attempts) == "table" and attempts[oldKey] ~= nil then
		if attempts[newKey] == nil then
			attempts[newKey] = attempts[oldKey]
		end
		attempts[oldKey] = nil
	end

	local markerIndex = runtime.markersByKey[oldKey]
	if markerIndex ~= nil then
		runtime.markersByKey[oldKey] = nil
		if runtime.markersByKey[newKey] == nil then
			runtime.markersByKey[newKey] = markerIndex
			if runtime.keysByMarker[markerIndex] == oldKey then
				runtime.keysByMarker[markerIndex] = newKey
			end
		elseif runtime.keysByMarker[markerIndex] == oldKey then
			runtime.keysByMarker[markerIndex] = nil
		end
	end
end

local function AddOrderedEntry(list, order, key, name, unitId, addedAt)
	if key == nil or key == "" then
		return
	end
	if list[key] == nil then
		table.insert(order, key)
	end

	local entry = list[key]
	if type(entry) ~= "table" then
		entry = {}
		list[key] = entry
	end
	entry.name = name

	local previousUnitId = GetEntryUnitId(entry)
	unitId = NormalizeUnitId(unitId)
	if previousUnitId ~= nil and previousUnitId ~= unitId then
		ClearUnitIdKey(previousUnitId, key)
	end
	entry.unitId = unitId
	if unitId ~= nil then
		BindUnitIdKey(unitId, key)
	end

	-- Keep the original add timestamp; only stamp newly created or legacy entries.
	if GetEntryAddedAt(entry) == nil then
		addedAt = Trim(tostring(addedAt or ""))
		if addedAt == "" then
			addedAt = GetCurrentDateTimeText()
		end
		if addedAt ~= "" then
			entry.addedAt = addedAt
		end
	end
end

local function RemoveOrderedEntry(list, order, key)
	if key == nil or key == "" or list[key] == nil then
		return
	end

	ClearUnitIdKey(GetEntryUnitId(list[key]), key)
	list[key] = nil
	for index = #order, 1, -1 do
		if order[index] == key then
			table.remove(order, index)
		end
	end
end

-- Coerce persisted sameFaction (bool or 0/1) for load; false booleans can break SaveData.
local function CoerceSavedSameFaction(value)
	if value == true or value == 1 or value == "1" then
		return true
	end
	if value == false or value == 0 or value == "0" then
		return false
	end
	return nil
end

local function LoadSavedEntry(keyOrIndex, entry, list, order)
	local key = nil
	local name = nil
	local note = nil
	local addedAt = nil

	if type(entry) == "table" then
		name = Trim(entry.name or entry.displayName or entry.identity)
		-- Canonicalize with StripWorldSuffix so Name and Name@World share one key.
		key = GetPlayerNameKey(entry.key or entry.identity or name) or ""
		note = entry.note or entry.notes or entry[3]
		addedAt = entry.addedAt or entry.added or entry.dateAdded
	elseif type(keyOrIndex) == "number" then
		name = Trim(entry)
		key = GetPlayerNameKey(name) or ""
	else
		name = Trim(entry)
		key = GetPlayerNameKey(keyOrIndex) or GetPlayerNameKey(name) or ""
	end

	if key ~= "" and name ~= "" then
		-- Skip persisted unitIds: they go stale across zones/sessions and can
		-- remap an unrelated target onto a saved entry via unitIdKeys.
		AddOrderedEntry(list, order, key, name, nil, addedAt)
		if note ~= nil then
			runtime.notes[key] = NormalizeNoteText(note)
		end
		if type(entry) == "table" then
			local guild = entry.guild or entry.expeditionName or entry.guildName
			if guild ~= nil then
				SetEntryGuild(list[key], guild)
			end
			if entry.faction ~= nil or entry.factionName ~= nil or entry.factionRaw ~= nil
				or entry.sameFaction ~= nil or entry.factionManual == true
			then
				runtime.faction.SetEntry(list[key], {
					key = entry.faction or entry.factionName,
					raw = entry.factionRaw or entry.faction,
					sameFaction = CoerceSavedSameFaction(entry.sameFaction),
					manual = entry.factionManual == true,
				})
			end
			if type(entry.location) == "table" and list[key] ~= nil then
				local location = runtime.map.Normalize(entry.location)
				if location ~= nil then
					list[key].location = location
				end
			end
		end
	end
end

-- Unit ids are session-local. Drop reverse maps and live entry ids so a recycled
-- id cannot migrate another player's list membership / notes / location.
local function ClearSessionUnitIds()
	runtime.unitIdKeys = {}
	for _, key in ipairs(runtime.friendlyOrder) do
		local entry = runtime.friendly[key]
		if type(entry) == "table" then
			entry.unitId = nil
		end
	end
	for _, key in ipairs(runtime.hostileOrder) do
		local entry = runtime.hostile[key]
		if type(entry) == "table" then
			entry.unitId = nil
		end
	end
end

local function LoadSavedList(source, list, order)
	if type(source) ~= "table" then
		return
	end

	-- Saved lists are arrays in current builds, but this also accepts old map-style data.
	if #source > 0 then
		for index = 1, #source do
			LoadSavedEntry(index, source[index], list, order)
		end
		return
	end

	for keyOrIndex, entry in pairs(source) do
		LoadSavedEntry(keyOrIndex, entry, list, order)
	end
end

local function LoadLists()
	local data = LoadData(persist.SAVE_KEY)
	if type(data) ~= "table" then
		return
	end

	-- Fresh load into empty tables (boot path); avoid appending onto stale order.
	runtime.friendly = {}
	runtime.hostile = {}
	runtime.friendlyOrder = {}
	runtime.hostileOrder = {}
	runtime.notes = {}
	runtime.unitIdKeys = {}

	LoadSavedList(data.friendly or data.friendlyList, runtime.friendly, runtime.friendlyOrder)
	LoadSavedList(data.hostile or data.hostileList, runtime.hostile, runtime.hostileOrder)
	-- Rebuild guild→F-color map and paint guild mates that lack a manual stamp.
	if runtime.faction.OnListsLoaded ~= nil then
		runtime.faction.OnListsLoaded()
	end
end

-- Camp string for save/export: only manual / stored camp (no auto invent).
local function GetSavedFactionCamp(entry)
	return runtime.faction.GetEntryCamp(entry)
end

-- String values written to the export file (one getter per EXPORT_FIELDS name).
local exportFieldGetters = {
	name = function(entry, key)
		return Trim(tostring(GetEntryName(entry) or ""))
	end,
	unitId = function(entry, key)
		return GetEntryUnitId(entry) or ""
	end,
	datetime = function(entry, key)
		return GetEntryAddedAt(entry) or ""
	end,
	location = function(entry, key)
		return runtime.map.FormatExportCoordinates(entry)
	end,
	guild = function(entry, key)
		return GetEntryGuild(entry)
	end,
	faction = function(entry, key)
		return GetSavedFactionCamp(entry)
	end,
	note = function(entry, key)
		return NormalizeNoteText(runtime.notes[key] or "")
	end,
}

local function GetExportFieldValue(field, entry, key)
	local getter = exportFieldGetters[field]
	if getter == nil then
		return ""
	end
	return tostring(getter(entry, key) or "")
end

local function BuildExportHeaderLine()
	local parts = {}
	local fields = listSave.EXPORT_FIELDS or {}
	for index = 1, #fields do
		parts[index] = tostring(fields[index])
	end
	return "# " .. table.concat(parts, "\t")
end

local function ApplyExportFieldsToSavedEntry(savedEntry, entry, key)
	local fields = listSave.EXPORT_FIELDS or {}
	for index = 1, #fields do
		local field = fields[index]
		if field == "datetime" then
			savedEntry.addedAt = GetExportFieldValue(field, entry, key)
		elseif field == "location" then
			local location = runtime.map.GetEntryLocation(entry)
			if location ~= nil then
				savedEntry.location = location
			end
		elseif field == "note" then
			savedEntry.note = GetExportFieldValue(field, entry, key)
		elseif field == "name" or field == "unitId" or field == "guild" or field == "faction" then
			savedEntry[field] = GetExportFieldValue(field, entry, key)
		end
	end
end

local function BuildSavedList(list, order)
	local saved = {}
	for _, key in ipairs(order) do
		if list[key] ~= nil then
			local name = GetEntryName(list[key])
			if name ~= nil and Trim(tostring(name)) ~= "" then
				local entry = list[key]
				local savedEntry = {
					key = key,
				}
				-- Columns from EXPORT_FIELDS; note always kept for the Note UI even if omitted from export.
				ApplyExportFieldsToSavedEntry(savedEntry, entry, key)
				if savedEntry.note == nil then
					savedEntry.note = NormalizeNoteText(runtime.notes[key] or "")
				end
				if savedEntry.name == nil or savedEntry.name == "" then
					savedEntry.name = name
				end

				local factionSnap = runtime.faction.GetSnap(entry)
				if factionSnap.raw ~= "" then
					savedEntry.factionRaw = factionSnap.raw
				end
				-- Use 1/0 so opposite-faction survives reload without a false boolean in the blob.
				if factionSnap.sameFaction == true or factionSnap.sameFaction == 1 then
					savedEntry.sameFaction = 1
				elseif factionSnap.sameFaction == false or factionSnap.sameFaction == 0 then
					savedEntry.sameFaction = 0
				end
				if factionSnap.manual == true then
					savedEntry.factionManual = true
				end
				-- Back-fill in-memory camp when save resolved one from sameFaction.
				if savedEntry.faction ~= nil and savedEntry.faction ~= ""
					and runtime.faction.GetEntryCamp(entry) == ""
				then
					runtime.faction.SetEntry(entry, {
						key = savedEntry.faction,
						raw = factionSnap.raw,
						sameFaction = CoerceSavedSameFaction(savedEntry.sameFaction),
						manual = factionSnap.manual == true,
					})
				end
				table.insert(saved, savedEntry)
			end
		end
	end
	return saved
end

local function PersistLists()
	SaveData(persist.SAVE_KEY, {
		friendly = BuildSavedList(runtime.friendly, runtime.friendlyOrder),
		hostile = BuildSavedList(runtime.hostile, runtime.hostileOrder),
	})
	runtime.listsSavePending = false
	runtime.lastListsSaveAt = Now()
end

local function SaveLists(immediate)
	if immediate == false then
		runtime.listsSavePending = true
		return
	end
	PersistLists()
end

-- Debounced save + timed cache prune (one table to stay under Lua 5.1 local limit).
function listSave.FlushNow()
	if not runtime.listsSavePending then
		return
	end
	PersistLists()
end

function listSave.FlushPending()
	if not runtime.listsSavePending then
		return
	end
	if Now() - (runtime.lastListsSaveAt or 0) < timing.LIST_SAVE_DEBOUNCE_SECONDS then
		return
	end
	listSave.FlushNow()
end

function listSave.MaybePruneSourceCaches()
	MaybePruneSourceCaches()
end

local function EscapeFileField(value)
	local text = tostring(value or "")
	text = string.gsub(text, "\\", "\\\\")
	text = string.gsub(text, "\t", "\\t")
	text = string.gsub(text, "\r", "\\r")
	text = string.gsub(text, "\n", "\\n")
	return text
end

local function GetCurrentDateText()
	if type(os) == "table" and type(os.date) == "function" then
		local ok, value = pcall(os.date, "%Y-%m-%d")
		if ok and type(value) == "string" and value ~= "" then
			return value
		end
	end

	local ok, timeTable = SafeCall(UIParent, "GetServerTimeTable")
	if ok and type(timeTable) == "table" then
		local year = tonumber(timeTable.year)
		local month = tonumber(timeTable.month)
		local day = tonumber(timeTable.day)
		if year ~= nil and month ~= nil and day ~= nil then
			return string.format("%04d-%02d-%02d", year, month, day)
		end
	end

	return "unknown-date"
end

local function AddUniquePath(paths, path)
	if path == nil or path == "" then
		return
	end

	local normalizedPath = string.gsub(tostring(path), "\\", "/")
	for _, existingPath in ipairs(paths) do
		if existingPath == normalizedPath then
			return
		end
	end
	table.insert(paths, normalizedPath)
end

local function GetAddonSourceDirectory()
	if type(debug) ~= "table" or type(debug.getinfo) ~= "function" then
		return nil
	end

	local ok, info = pcall(debug.getinfo, 1, "S")
	if not ok or type(info) ~= "table" or type(info.source) ~= "string" then
		return nil
	end

	local source = info.source
	if string.sub(source, 1, 1) == "@" then
		source = string.sub(source, 2)
	end
	source = string.gsub(source, "\\", "/")

	local directory = string.match(source, "^(.*)/[^/]+$")
	if directory == nil or directory == "" then
		return nil
	end
	-- Relative sources resolve against the game CWD (install folder) — reject those.
	local looksAbsolute = string.match(directory, "^[A-Za-z]:") ~= nil
		or string.sub(directory, 1, 1) == "/"
		or string.find(directory, "Documents/ArcheRage/Addon", 1, true) ~= nil
	if not looksAbsolute then
		return nil
	end
	return directory
end

local function GetUserProfileDirectory()
	if type(os) ~= "table" or type(os.getenv) ~= "function" then
		return nil
	end
	local ok, value = pcall(os.getenv, "USERPROFILE")
	if ok and value ~= nil and Trim(tostring(value)) ~= "" then
		return string.gsub(Trim(tostring(value)), "\\", "/")
	end
	ok, value = pcall(os.getenv, "HOME")
	if ok and value ~= nil and Trim(tostring(value)) ~= "" then
		return string.gsub(Trim(tostring(value)), "\\", "/")
	end
	return nil
end

local function TryOpenFile(path, mode)
	if type(io) ~= "table" or type(io.open) ~= "function" then
		return nil, "io.open unavailable"
	end

	local ok, file, errorMessage = pcall(io.open, path, mode)
	if ok and file ~= nil then
		return file, nil
	end
	if ok then
		return nil, errorMessage
	end
	return nil, file
end

local function BuildExportFilePaths(fileName)
	local paths = {}
	-- Prefer the real addon folder under Documents, never the game install CWD.
	local profile = GetUserProfileDirectory()
	if profile ~= nil then
		AddUniquePath(paths, profile .. "/Documents/ArcheRage/Addon/unittacker/" .. fileName)
	end
	local sourceDirectory = GetAddonSourceDirectory()
	if sourceDirectory ~= nil then
		AddUniquePath(paths, sourceDirectory .. "/" .. fileName)
	end
	AddUniquePath(paths, "../Documents/ArcheRage/Addon/unittacker/" .. fileName)
	AddUniquePath(paths, "../../Documents/ArcheRage/Addon/unittacker/" .. fileName)
	-- Last-resort relatives (still under Addon/unittacker, not game root).
	AddUniquePath(paths, "Documents/ArcheRage/Addon/unittacker/" .. fileName)
	AddUniquePath(paths, "unittacker/" .. fileName)
	return paths
end

function listSave.UnescapeFileField(value)
	local text = tostring(value or "")
	local out = {}
	local index = 1
	local length = string.len(text)
	while index <= length do
		local ch = string.sub(text, index, index)
		if ch == "\\" and index < length then
			local nextCh = string.sub(text, index + 1, index + 1)
			if nextCh == "n" then
				table.insert(out, "\n")
			elseif nextCh == "t" then
				table.insert(out, "\t")
			elseif nextCh == "r" then
				table.insert(out, "\r")
			elseif nextCh == "\\" then
				table.insert(out, "\\")
			else
				table.insert(out, nextCh)
			end
			index = index + 2
		else
			table.insert(out, ch)
			index = index + 1
		end
	end
	return table.concat(out)
end

function listSave.CountLoadedEntries()
	return #runtime.friendlyOrder + #runtime.hostileOrder
end

function listSave.ParseExportLocation(text)
	text = Trim(text)
	if text == "" then
		return nil
	end
	local coords = text
	local zoneGroup = nil
	local coordsPart, zonePart = string.match(text, "^(.-)%s*|%s*[Zz]one%s+(%-?%d+)%s*$")
	if coordsPart ~= nil then
		coords = coordsPart
		zoneGroup = tonumber(zonePart)
	end
	local x, y, z = string.match(coords, "^%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)")
	if x == nil then
		x, y = string.match(coords, "^%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)")
	end
	if x == nil or y == nil then
		return nil
	end
	return runtime.map.Normalize({
		x = tonumber(x),
		y = tonumber(y),
		z = tonumber(z) or 0,
		zoneGroup = zoneGroup,
	})
end

function listSave.SplitExportFields(line)
	local fields = {}
	local rest = tostring(line or "")
	while true do
		local tabAt = string.find(rest, "\t", 1, true)
		if tabAt == nil then
			table.insert(fields, listSave.UnescapeFileField(rest))
			break
		end
		table.insert(fields, listSave.UnescapeFileField(string.sub(rest, 1, tabAt - 1)))
		rest = string.sub(rest, tabAt + 1)
	end
	return fields
end

function listSave.ReadFirstExistingFile(fileName)
	for _, path in ipairs(BuildExportFilePaths(fileName)) do
		local file = TryOpenFile(path, "r")
		if file ~= nil then
			local ok, content = pcall(function()
				local text = file:read("*a")
				file:close()
				return text
			end)
			if not ok then
				pcall(function()
					file:close()
				end)
			elseif type(content) == "string" and Trim(content) ~= "" then
				return content, path
			end
		end
	end
	return nil, nil
end

function listSave.ImportExportContent(content)
	if type(content) ~= "string" or content == "" then
		return 0
	end

	local section = nil
	local imported = 0
	for line in string.gmatch(content .. "\n", "(.-)\n") do
		line = string.gsub(line, "\r$", "")
		local trimmed = Trim(line)
		if trimmed ~= "" and string.sub(trimmed, 1, 1) ~= "#" then
			local sectionName = string.match(trimmed, "^%[(.-)%]$")
			if sectionName ~= nil then
				local lower = string.lower(sectionName)
				if lower == "friendly" then
					section = "friendly"
				elseif lower == "hostile" then
					section = "hostile"
				else
					section = nil
				end
			elseif section ~= nil then
				local fields = listSave.SplitExportFields(line)
				local name = Trim(fields[1] or "")
				if name ~= "" then
					local entry = {}
					-- Legacy rows: name, unitId, datetime, note, location, guild, faction
					local legacyLocation = listSave.ParseExportLocation(fields[5] or "")
					local newLocation = listSave.ParseExportLocation(fields[4] or "")
					if legacyLocation ~= nil and newLocation == nil then
						entry.name = name
						entry.unitId = fields[2]
						entry.addedAt = fields[3]
						entry.note = fields[4]
						entry.guild = fields[6]
						entry.faction = fields[7]
						entry.location = legacyLocation
					else
						-- Current rows follow listSave.EXPORT_FIELDS order.
						local exportFields = listSave.EXPORT_FIELDS or {}
						for index = 1, #exportFields do
							local field = exportFields[index]
							local value = fields[index]
							if field == "datetime" then
								entry.addedAt = value
							elseif field == "location" then
								local location = listSave.ParseExportLocation(value or "")
								if location ~= nil then
									entry.location = location
								end
							elseif field == "note" then
								entry.note = value
							elseif field == "name" or field == "unitId" or field == "guild" or field == "faction" then
								entry[field] = value
							end
						end
						if entry.name == nil or entry.name == "" then
							entry.name = name
						end
					end
					local list = runtime.hostile
					local order = runtime.hostileOrder
					if section == "friendly" then
						list = runtime.friendly
						order = runtime.friendlyOrder
					end
					local before = listSave.CountLoadedEntries()
					LoadSavedEntry(nil, entry, list, order)
					if listSave.CountLoadedEntries() > before then
						imported = imported + 1
					end
				end
			end
		end
	end
	return imported
end

function listSave.TryImportRecovery()
	local candidates = {
		"export_unit_tracker_2026-08-01.txt",
		"export_unit_tracker_2026-07-27.txt",
		"export_unit_tracker_2026-07-21.txt",
	}
	local dateText = string.gsub(tostring(GetCurrentDateText()), "[^%w%-_]", "-")
	table.insert(candidates, 1, "export_unit_tracker_" .. dateText .. ".txt")

	for _, fileName in ipairs(candidates) do
		local content, path = listSave.ReadFirstExistingFile(fileName)
		if content ~= nil then
			local imported = listSave.ImportExportContent(content)
			if imported > 0 then
				return imported, path
			end
		end
	end
	return 0, nil
end

function listSave.FinishImportRecovery(imported, path)
	if imported == nil or imported <= 0 then
		return false
	end
	SaveLists(true)
	SaveData(persist.IMPORT_DONE_KEY, true)
	runtime.listsImportRetryAt = nil
	if DispatchExportStatus ~= nil then
		DispatchExportStatus(
			"[Unit Tracker] Restored " .. tostring(imported) .. " entries from " .. tostring(path) .. "."
		)
	end
	return true
end

-- SaveData is per-addon. Empty unittacker saves can still restore from a file export.
function listSave.LoadListsWithRecovery()
	LoadLists()
	if listSave.CountLoadedEntries() > 0 then
		return
	end
	if LoadData(persist.IMPORT_DONE_KEY) == true then
		return
	end

	local imported, path = listSave.TryImportRecovery()
	if listSave.FinishImportRecovery(imported, path) then
		return
	end

	-- A same-session export file may appear shortly after boot; retry briefly.
	runtime.listsImportRetries = 0
	runtime.listsImportRetryAt = Now() + 2
end

function listSave.MaybeRetryImportRecovery()
	if runtime.listsImportRetryAt == nil then
		return
	end
	if Now() < runtime.listsImportRetryAt then
		return
	end
	runtime.listsImportRetryAt = nil
	if listSave.CountLoadedEntries() > 0 or LoadData(persist.IMPORT_DONE_KEY) == true then
		return
	end

	local imported, path = listSave.TryImportRecovery()
	if listSave.FinishImportRecovery(imported, path) then
		return
	end

	runtime.listsImportRetries = (runtime.listsImportRetries or 0) + 1
	if runtime.listsImportRetries < 8 then
		runtime.listsImportRetryAt = Now() + 2
	end
end

function listSave.ExportFileExists(fileName)
	for _, path in ipairs(BuildExportFilePaths(fileName)) do
		local file = TryOpenFile(path, "r")
		if file ~= nil then
			pcall(function()
				file:close()
			end)
			return true
		end
	end
	return false
end

function listSave.GetExportEpochText()
	if type(os) == "table" and type(os.time) == "function" then
		local ok, value = pcall(os.time)
		if ok and tonumber(value) ~= nil then
			return tostring(math.floor(tonumber(value)))
		end
	end
	return tostring(math.floor((Now() * 1000) + 0.5))
end

-- Dated export name; if that file already exists today, append unix epoch.
function listSave.BuildExportFileName()
	local dateText = string.gsub(tostring(GetCurrentDateText()), "[^%w%-_]", "-")
	local fileName = "export_unit_tracker_" .. dateText .. ".txt"
	if listSave.ExportFileExists(fileName) then
		fileName = "export_unit_tracker_" .. dateText .. "_" .. listSave.GetExportEpochText() .. ".txt"
	end
	return fileName
end

local function WriteExportSection(file, sectionTitle, list, order)
	file:write("[")
	file:write(sectionTitle)
	file:write("]\n")
	local fields = listSave.EXPORT_FIELDS or {}
	for _, key in ipairs(order) do
		local entry = list[key]
		local name = GetEntryName(entry)
		if name ~= nil then
			for index = 1, #fields do
				if index > 1 then
					file:write("\t")
				end
				file:write(EscapeFileField(GetExportFieldValue(fields[index], entry, key)))
			end
			file:write("\n")
		end
	end
	file:write("\n")
end

local function WriteExportFile(fileName)
	local lastError = nil
	for _, path in ipairs(BuildExportFilePaths(fileName)) do
		local file, openError = TryOpenFile(path, "w")
		if file ~= nil then
			local ok, writeError = pcall(function()
				file:write("# Unit Tracker Export - ")
				file:write(GetCurrentDateText())
				file:write("\n")
				file:write(BuildExportHeaderLine())
				file:write("\n\n")
				WriteExportSection(file, "Friendly", runtime.friendly, runtime.friendlyOrder)
				WriteExportSection(file, "Hostile", runtime.hostile, runtime.hostileOrder)
				if type(file.flush) == "function" then
					file:flush()
				end
				file:close()
			end)
			if ok then
				return true, path, nil
			end
			pcall(function()
				file:close()
			end)
			lastError = tostring(writeError or "write failed")
		else
			lastError = tostring(openError or "open failed")
		end
	end
	return false, nil, lastError
end

local function DispatchExportStatus(message)
	if X2Chat ~= nil and type(X2Chat.DispatchChatMessage) == "function" then
		pcall(X2Chat.DispatchChatMessage, X2Chat, CMF_SYSTEM, tostring(message or ""))
	end
end

local function ExportPlayerLists()
	local exported, path, exportError = WriteExportFile(listSave.BuildExportFileName())
	if exported then
		DispatchExportStatus("[Unit Tracker] Exported to " .. tostring(path) .. ".")
		if listSave.ShowExportNotify ~= nil then
			listSave.ShowExportNotify("Export successful.", path)
		end
	else
		local message = "[Unit Tracker] Export failed."
		if exportError ~= nil and tostring(exportError) ~= "" then
			message = message .. " " .. tostring(exportError)
		end
		DispatchExportStatus(message)
	end
end

local function GetCurrentTargetUnitId()
	local okTarget, targetUnitId = SafeCall(X2Unit, "GetTargetUnitId")
	if okTarget and IsValidName(targetUnitId) then
		return tostring(targetUnitId)
	end

	local okUnit, unitId = SafeCall(X2Unit, "GetUnitId", "target")
	if okUnit and IsValidName(unitId) then
		return tostring(unitId)
	end

	return nil
end

-- Guild/expedition name from the selected target.
-- Second return is true only when character info was confirmed (empty then means unguilded).
-- Prefer allowed GetUnitInfoById; UnitInfo is not-allowed and used only as pcall fallback.
local function GetSelectedTargetGuildName()
	local unitId = GetCurrentTargetUnitId()
	if unitId ~= nil then
		local byId = GetUnitInfoById(unitId)
		if type(byId) == "table" and byId.type == "character" then
			return Trim(tostring(byId.expeditionName or byId.guildName or byId.guild or "")), true
		end
	end

	local okInfo, unitInfo = SafeCall(X2Unit, "UnitInfo", "target")
	if okInfo and type(unitInfo) == "table" and unitInfo.type == "character" then
		return Trim(tostring(unitInfo.expeditionName or unitInfo.guildName or unitInfo.guild or "")), true
	end
	return "", false
end

local function GetTargetRecord()
	local okWorld, worldName = SafeCall(X2Unit, "UnitNameWithWorld", "target")
	local okName, name = SafeCall(X2Unit, "UnitName", "target")

	local displayName = nil
	if okWorld and IsValidName(worldName) then
		displayName = Trim(worldName)
	elseif okName and IsValidName(name) then
		displayName = Trim(name)
	end

	if displayName == nil or displayName == "" then
		return nil
	end

	local key = GetPlayerNameKey(displayName)
	if key == nil then
		return nil
	end

	local guild, guildKnown = GetSelectedTargetGuildName()
	local faction, factionKnown = runtime.faction.GetSelected()
	return {
		key = key,
		name = displayName,
		unitId = GetCurrentTargetUnitId(),
		guild = guild,
		guildKnown = guildKnown == true,
		faction = faction,
		factionKnown = factionKnown == true,
	}
end

local function GetTrackedKeyForRecord(record)
	if record == nil then
		return nil
	end
	local _, trackedKey = FindTrackedEntry(record.key, record.unitId)
	return trackedKey
end

local function IsHostileMarker(markerIndex)
	markerIndex = tonumber(markerIndex)
	if markerIndex == markerCfg.HOSTILE_MARKER_INDEX then
		return true
	end
	for _, numberedMarker in ipairs(markerCfg.NUMBERED_HOSTILE_MARKERS) do
		if markerIndex == numberedMarker then
			return true
		end
	end
	return false
end

local function GetCurrentTargetMarker()
	local okCurrent, currentMarker = SafeCall(X2Unit, "GetOverHeadMarker", "target")
	if okCurrent then
		return tonumber(currentMarker)
	end
	return nil
end

local function SameUnitId(left, right)
	return IsValidName(left) and IsValidName(right) and tostring(left) == tostring(right)
end

local function IsMarkerAvailable(markerIndex, targetUnitId)
	local ok, markerUnitId = SafeCall(X2Unit, "GetOverHeadMarkerUnitId", markerIndex)
	if not ok or not IsValidName(markerUnitId) then
		return true
	end
	return SameUnitId(markerUnitId, targetUnitId)
end

-- Use X first, then 1-9. When every slot is taken, recycle X onto the new target.
-- Re-scan availability at most once per timing.MARK_RETRY_SECONDS per target.
local function ChooseHostileMarker(record)
	local cache = runtime.markerScanCache
	local now = Now()
	local unitId = NormalizeUnitId(record.unitId)
	if cache.key == record.key
		and cache.unitId == unitId
		and (now - (cache.at or 0)) < timing.MARK_RETRY_SECONDS
	then
		return cache.index, cache.shouldWrite
	end

	local currentMarker = GetCurrentTargetMarker()
	if IsHostileMarker(currentMarker) then
		cache.key = record.key
		cache.unitId = unitId
		cache.index = currentMarker
		cache.shouldWrite = false
		cache.at = now
		return currentMarker, false
	end

	local markerIndex = markerCfg.HOSTILE_MARKER_INDEX
	if IsMarkerAvailable(markerCfg.HOSTILE_MARKER_INDEX, record.unitId) then
		markerIndex = markerCfg.HOSTILE_MARKER_INDEX
	else
		markerIndex = nil
		for _, numberedMarker in ipairs(markerCfg.NUMBERED_HOSTILE_MARKERS) do
			if IsMarkerAvailable(numberedMarker, record.unitId) then
				markerIndex = numberedMarker
				break
			end
		end
		if markerIndex == nil then
			markerIndex = markerCfg.HOSTILE_MARKER_INDEX
		end
	end

	cache.key = record.key
	cache.unitId = unitId
	cache.index = markerIndex
	cache.shouldWrite = true
	cache.at = now
	return markerIndex, true
end

local function ForgetMarkerForKey(key)
	local markerIndex = runtime.markersByKey[key]
	if markerIndex ~= nil then
		runtime.keysByMarker[markerIndex] = nil
	end
	runtime.markersByKey[key] = nil
end

local function RememberMarkerForKey(key, markerIndex)
	ForgetMarkerForKey(key)

	local previousKey = runtime.keysByMarker[markerIndex]
	if previousKey ~= nil and previousKey ~= key then
		runtime.markersByKey[previousKey] = nil
	end

	runtime.markersByKey[key] = markerIndex
	runtime.keysByMarker[markerIndex] = key
end

local function ApplyHostileTargetMarker()
	local record = runtime.currentTarget
	if record == nil then
		return
	end
	local listName, trackedKey = FindTrackedEntry(record.key, record.unitId)
	if listName ~= "hostile" or trackedKey == nil then
		return
	end

	-- Cap SetOverHeadMarker tries per player; cleared on ENTERED_WORLD.
	local attempts = runtime.markerWriteAttempts
	if type(attempts) ~= "table" then
		attempts = {}
		runtime.markerWriteAttempts = attempts
	end
	if (tonumber(attempts[trackedKey]) or 0) >= 3 then
		return
	end

	local markerIndex, shouldWrite = ChooseHostileMarker(record)
	if markerIndex == nil then
		return
	end

	local now = Now()
	if not shouldWrite then
		runtime.lastMarkedKey = trackedKey
		runtime.lastMarkedMarker = markerIndex
		runtime.lastMarkTime = now
		return
	end

	-- Native marker writes have a cooldown, so target polling only writes when the chosen mark changes or the retry gap has elapsed.
	if runtime.lastMarkedKey == trackedKey
		and runtime.lastMarkedMarker == markerIndex
		and (now - runtime.lastMarkTime) < timing.MARK_RETRY_SECONDS
	then
		return
	end
	if (now - runtime.lastMarkerWriteTime) < timing.MARK_RETRY_SECONDS then
		return
	end

	local ok = SafeCall(X2Unit, "SetOverHeadMarker", "target", markerIndex)
	attempts[trackedKey] = (tonumber(attempts[trackedKey]) or 0) + 1
	runtime.lastMarkedKey = trackedKey
	runtime.lastMarkedMarker = markerIndex
	runtime.lastMarkTime = now
	runtime.lastMarkerWriteTime = now
	if ok then
		RememberMarkerForKey(trackedKey, markerIndex)
	end
end

local function ClearOwnedHostileMarker(record)
	if record == nil then
		return
	end

	local _, trackedKey = FindTrackedEntry(record.key, record.unitId)
	trackedKey = trackedKey or record.key
	local ownedMarker = runtime.markersByKey[trackedKey]
	if ownedMarker == nil and record.key ~= trackedKey then
		ownedMarker = runtime.markersByKey[record.key]
		if ownedMarker ~= nil then
			trackedKey = record.key
		end
	end
	if ownedMarker == nil then
		return
	end

	-- Avoid RemoveAllOverHeadMarker; only try clearing the mark this addon assigned to the selected target.
	local currentMarker = GetCurrentTargetMarker()
	if tonumber(currentMarker) == tonumber(ownedMarker) then
		SafeCall(X2Unit, "SetOverHeadMarker", "target", 0)
	end

	ForgetMarkerForKey(trackedKey)
	if runtime.lastMarkedKey == trackedKey or runtime.lastMarkedKey == record.key then
		runtime.lastMarkedKey = nil
		runtime.lastMarkedMarker = nil
		runtime.lastMarkTime = 0
	end
end

local function SyncTrackedEntryForRecord(record)
	if record == nil then
		return nil, nil
	end

	local listName, trackedKey, entry = FindTrackedEntry(record.key, record.unitId)
	if listName == nil or trackedKey == nil then
		return nil, nil
	end

	local list = listName == "friendly" and runtime.friendly or runtime.hostile
	local order = listName == "friendly" and runtime.friendlyOrder or runtime.hostileOrder
	local changed = false

	if trackedKey ~= record.key then
		local markerIndex = runtime.markersByKey[trackedKey]
		local preservedAddedAt = GetEntryAddedAt(entry)
		local preservedLocation = runtime.map.GetEntryLocation(entry)
		local preservedFaction = runtime.faction.GetSnap(entry)
		RemoveOrderedEntry(list, order, trackedKey)
		MigrateTrackedKey(trackedKey, record.key)
		AddOrderedEntry(list, order, record.key, record.name, record.unitId, preservedAddedAt)
		if preservedLocation ~= nil and list[record.key] ~= nil then
			list[record.key].location = preservedLocation
		end
		if list[record.key] ~= nil then
			runtime.faction.SetEntry(list[record.key], preservedFaction)
		end
		if markerIndex ~= nil then
			RememberMarkerForKey(record.key, markerIndex)
		end
		trackedKey = record.key
		changed = true
	else
		local previousName = GetEntryName(entry)
		local previousUnitId = GetEntryUnitId(entry)
		local nextUnitId = NormalizeUnitId(record.unitId) or previousUnitId
		if previousName ~= record.name or previousUnitId ~= nextUnitId then
			AddOrderedEntry(list, order, trackedKey, record.name, nextUnitId, GetEntryAddedAt(entry))
			changed = previousName ~= record.name or previousUnitId ~= GetEntryUnitId(list[trackedKey])
		end
	end

	-- Keep list guild in sync with the live selected target (including unguilded).
	-- Only write when character UnitInfo confirmed the guild field, so unknown
	-- reads cannot wipe a previously saved guild name.
	if record.guildKnown and SetEntryGuild(list[trackedKey], record.guild) then
		changed = true
	end
	-- Guild with a prior F pick: inherit that color for newly observed guild mates.
	if list[trackedKey] ~= nil and runtime.faction.ApplyGuildFactionToEntry(list[trackedKey]) then
		changed = true
	end
	-- Always stamp live relationship onto the saved entry when anything was learned.
	if record.factionKnown and type(record.faction) == "table" and list[trackedKey] ~= nil then
		local entry = list[trackedKey]
		-- Manual F picks (including guild inheritance) are sticky until the user picks again.
		if entry.factionManual ~= true then
			local beforeSame = entry.sameFaction
			runtime.faction.SetEntry(entry, {
				raw = record.faction.raw,
				sameFaction = record.faction.sameFaction,
			})
			local afterSame = entry.sameFaction
			if beforeSame ~= afterSame or entry.factionRaw ~= nil then
				changed = true
			end
		end
	end

	if changed then
		SaveLists(true)
		if runtime.RefreshViewList ~= nil then
			runtime.RefreshViewList()
		elseif UT.UpdateViewWindow ~= nil
			and runtime.viewWindow ~= nil
			and runtime.viewWindow:IsVisible()
		then
			UT.UpdateViewWindow()
		end
	end
	return listName, trackedKey
end

local function RefreshTargetState()
	local record = GetTargetRecord()
	local prevKey = runtime.lastRefreshTargetKey
	local prevUnitId = runtime.lastRefreshTargetUnitId
	local prevListName = runtime.lastRefreshListName
	local prevNote = runtime.lastRefreshNote or ""

	runtime.currentTarget = record

	local listName = nil
	if record ~= nil then
		listName = select(1, SyncTrackedEntryForRecord(record))
	end

	local targetKey = record and record.key or nil
	local targetUnitId = record and NormalizeUnitId(record.unitId) or nil
	local trackedKey = record and GetTrackedKeyForRecord(record) or nil
	local note = trackedKey and NormalizeNoteText(runtime.notes[trackedKey] or "") or ""

	local targetChanged = targetKey ~= prevKey or targetUnitId ~= prevUnitId
	local listChanged = listName ~= prevListName
	local noteChanged = note ~= prevNote

	if targetChanged or listChanged or noteChanged then
		if UT.UpdateWindowText ~= nil then
			UT.UpdateWindowText()
		end
	end

	if (targetChanged or listChanged)
		and UT.UpdateViewWindow ~= nil
		and runtime.viewWindow ~= nil
		and runtime.viewWindow:IsVisible()
	then
		UT.UpdateViewWindow()
	end

	-- Listed target (friendly or hostile): open the main tracker for notes/context.
	if settings.IsAutoOpenListedTarget()
		and listName ~= nil
		and (targetChanged or listChanged)
		and runtime.window ~= nil
		and not runtime.window:IsVisible()
	then
		runtime.window:Show(true)
	end

	if targetChanged or listChanged then
		runtime.markerScanCache.at = 0
		if record ~= nil and listName ~= "hostile" then
			ClearOwnedHostileMarker(record)
		else
			ApplyHostileTargetMarker()
		end
	elseif listName == "hostile" and record ~= nil then
		-- Retry marker writes on the same target (capped per player in ApplyHostileTargetMarker).
		if (Now() - (runtime.lastMarkerWriteTime or 0)) >= timing.MARK_RETRY_SECONDS then
			ApplyHostileTargetMarker()
		end
	end

	runtime.lastRefreshTargetKey = targetKey
	runtime.lastRefreshTargetUnitId = targetUnitId
	runtime.lastRefreshListName = listName
	runtime.lastRefreshNote = note
end

local function AddCurrentTargetToList(listName)
	local record = GetTargetRecord()
	if record == nil then
		RefreshTargetState()
		return false
	end

	-- Friendly/hostile lists are player-only; reject NPCs and unconfirmed targets.
	if not IsSelectedTargetPlayerCharacter(record.unitId) then
		RefreshTargetState()
		return false
	end

	local existingList, existingKey = FindTrackedEntry(record.key, record.unitId)
	local preservedAddedAt = nil
	local preservedLocation = nil
	local preservedFaction = { key = "", sameFaction = nil }
	if existingKey ~= nil then
		local existingEntry = runtime.friendly[existingKey] or runtime.hostile[existingKey]
		preservedAddedAt = GetEntryAddedAt(existingEntry)
		preservedLocation = runtime.map.GetEntryLocation(existingEntry)
		preservedFaction = runtime.faction.GetSnap(existingEntry)
	end
	-- Capture location only for new entries or moves between lists, not re-adds.
	local shouldCaptureLocation = existingKey == nil or existingList ~= listName
	if existingList == "friendly" and existingKey ~= nil then
		if existingKey ~= record.key then
			MigrateTrackedKey(existingKey, record.key)
		end
		RemoveOrderedEntry(runtime.friendly, runtime.friendlyOrder, existingKey)
	elseif existingList == "hostile" and existingKey ~= nil then
		local markerIndex = runtime.markersByKey[existingKey]
		if listName ~= "hostile" then
			-- Clear the visual marker while ownership is still known.
			ClearOwnedHostileMarker(record)
		end
		if existingKey ~= record.key then
			MigrateTrackedKey(existingKey, record.key)
		end
		RemoveOrderedEntry(runtime.hostile, runtime.hostileOrder, existingKey)
		if listName == "hostile" and markerIndex ~= nil and existingKey ~= record.key then
			RememberMarkerForKey(record.key, markerIndex)
		end
	end

	if listName == "friendly" then
		AddOrderedEntry(runtime.friendly, runtime.friendlyOrder, record.key, record.name, record.unitId, preservedAddedAt)
		ClearOwnedHostileMarker(record)
	elseif listName == "hostile" then
		AddOrderedEntry(runtime.hostile, runtime.hostileOrder, record.key, record.name, record.unitId, preservedAddedAt)
	end

	-- Stamp local-player coordinates when newly added or moved between lists.
	local addedEntry = runtime.friendly[record.key] or runtime.hostile[record.key]
	if addedEntry ~= nil then
		if record.guildKnown then
			SetEntryGuild(addedEntry, record.guild)
		end
		-- Prefer prior manual F on this row, then guild F stamp, then live relationship.
		if preservedFaction.manual == true then
			runtime.faction.SetEntry(addedEntry, preservedFaction)
		elseif runtime.faction.ApplyGuildFactionToEntry(addedEntry) then
			-- Guild inheritance applied.
		elseif record.factionKnown then
			runtime.faction.SetEntry(addedEntry, {
				raw = record.faction.raw,
				sameFaction = record.faction.sameFaction,
			})
			if record.faction.sameFaction == true then
				addedEntry.sameFaction = true
			elseif record.faction.sameFaction == false then
				addedEntry.sameFaction = false
			end
		else
			runtime.faction.SetEntry(addedEntry, preservedFaction)
		end
		if shouldCaptureLocation then
			local location = runtime.map.CaptureLocalPlayer()
			if location ~= nil then
				addedEntry.location = location
			elseif preservedLocation ~= nil then
				addedEntry.location = preservedLocation
			end
		elseif preservedLocation ~= nil then
			addedEntry.location = preservedLocation
		end
	end

	SaveLists(true)
	RefreshTargetState()
	if UT.UpdateViewWindow ~= nil then
		UT.UpdateViewWindow()
	end
	if runtime.noteWindow ~= nil and runtime.noteWindow:IsVisible() and runtime.noteTargetKey == record.key then
		runtime.map.RefreshNoteMapButton()
	end
	return true
end

-- Typed name on the main window: no live target required; later select enriches casing/guild/unitId.
local function AddManualNameToList(listName, typedName)
	if listName ~= "friendly" and listName ~= "hostile" then
		return false
	end

	local displayName = Trim(tostring(typedName or ""))
	if displayName == "" or IsLocalPlayerName(displayName) then
		return false
	end

	local key = GetPlayerNameKey(displayName)
	if key == nil then
		return false
	end

	local existingList, existingKey = FindTrackedEntry(key, nil)
	local preservedAddedAt = nil
	local preservedLocation = nil
	local preservedFaction = { key = "", sameFaction = nil }
	if existingKey ~= nil then
		local existingEntry = runtime.friendly[existingKey] or runtime.hostile[existingKey]
		preservedAddedAt = GetEntryAddedAt(existingEntry)
		preservedLocation = runtime.map.GetEntryLocation(existingEntry)
		preservedFaction = runtime.faction.GetSnap(existingEntry)
	end

	if existingList == "friendly" and existingKey ~= nil then
		if existingKey ~= key then
			MigrateTrackedKey(existingKey, key)
		end
		RemoveOrderedEntry(runtime.friendly, runtime.friendlyOrder, existingKey)
	elseif existingList == "hostile" and existingKey ~= nil then
		local markerIndex = runtime.markersByKey[existingKey]
		if listName ~= "hostile" then
			-- No live target for manual add; drop ownership without a SetOverHeadMarker clear.
			ForgetMarkerForKey(existingKey)
		end
		if existingKey ~= key then
			MigrateTrackedKey(existingKey, key)
		end
		RemoveOrderedEntry(runtime.hostile, runtime.hostileOrder, existingKey)
		if listName == "hostile" and markerIndex ~= nil and existingKey ~= key then
			RememberMarkerForKey(key, markerIndex)
		end
	end

	if listName == "friendly" then
		AddOrderedEntry(runtime.friendly, runtime.friendlyOrder, key, displayName, nil, preservedAddedAt)
	elseif listName == "hostile" then
		AddOrderedEntry(runtime.hostile, runtime.hostileOrder, key, displayName, nil, preservedAddedAt)
	end

	local addedEntry = runtime.friendly[key] or runtime.hostile[key]
	if addedEntry ~= nil then
		runtime.faction.SetEntry(addedEntry, preservedFaction)
		if preservedLocation ~= nil then
			addedEntry.location = preservedLocation
		end
	end

	SaveLists(true)
	if runtime.addNameState ~= nil then
		SetEditBoxText(runtime.addNameState, "", true)
	end
	runtime.addNameText = ""
	RefreshTargetState()
	if UT.UpdateViewWindow ~= nil then
		UT.UpdateViewWindow()
	end
	return true
end

local function RemoveNameFromList(listName, key)
	if key == nil or key == "" then
		return
	end

	runtime.removeConfirm = nil

	if listName == "friendly" then
		RemoveOrderedEntry(runtime.friendly, runtime.friendlyOrder, key)
	elseif listName == "hostile" then
		-- Resolve current-target ownership before RemoveOrderedEntry clears unitIdKeys.
		local record = runtime.currentTarget or GetTargetRecord()
		local recordUnitId = record ~= nil and NormalizeUnitId(record.unitId) or nil
		local isCurrentTarget = record ~= nil and (
			record.key == key
			or (recordUnitId ~= nil and runtime.unitIdKeys[recordUnitId] == key)
		)
		if isCurrentTarget then
			ClearOwnedHostileMarker(record)
		else
			ForgetMarkerForKey(key)
		end
		RemoveOrderedEntry(runtime.hostile, runtime.hostileOrder, key)
	end

	if runtime.friendly[key] == nil and runtime.hostile[key] == nil then
		runtime.notes[key] = nil
		if runtime.noteTargetKey == key then
			runtime.noteTargetKey = nil
			if runtime.noteWindow ~= nil then
				runtime.noteWindow:Show(false)
			end
		end
	end

	SaveLists(true)
	RefreshTargetState()
	if UT.UpdateViewWindow ~= nil then
		UT.UpdateViewWindow()
	end
end

local function IsRemoveConfirmPending(listName, key)
	local pending = runtime.removeConfirm
	return pending ~= nil and pending.listName == listName and pending.key == key
end

local function ClearRemoveConfirm()
	if runtime.removeConfirm == nil then
		return
	end
	runtime.removeConfirm = nil
	if UT.UpdateViewWindow ~= nil then
		UT.UpdateViewWindow()
	end
	if UT.RefreshNoteRemoveConfirm ~= nil then
		UT.RefreshNoteRemoveConfirm()
	end
	local noteWindow = runtime.noteWindow
	if noteWindow ~= nil and noteWindow.statusLabel ~= nil and noteWindow:IsVisible() then
		noteWindow.statusLabel:SetText("")
	end
end

local function BeginRemoveConfirm(listName, key)
	if listName == nil or key == nil or key == "" then
		return
	end
	runtime.noteFactionPicker = false
	runtime.removeConfirm = {
		listName = listName,
		key = key,
	}
	if UT.UpdateViewWindow ~= nil then
		UT.UpdateViewWindow()
	end
	if UT.RefreshNoteRemoveConfirm ~= nil then
		UT.RefreshNoteRemoveConfirm()
	end
end

function listSave.ShowExportNotify(message, path, opts)
	if type(opts) ~= "table" then
		opts = {}
	end
	local width = tonumber(opts.width) or 420
	local height = tonumber(opts.height) or 54
	local holdSeconds = tonumber(opts.holdSeconds) or 4
	local window = runtime.exportNotifyWindow
	if window == nil then
		window = CreateEmptyWindow("unitTrackerExportNotify", "UIParent")
		runtime.exportNotifyWindow = window
		window:SetExtent(width, height)
		window:AddAnchor("TOP", "UIParent", 0, 120)
		window:Clickable(false)
		window:Show(false)

		local background = window:CreateColorDrawable(0, 0, 0, 0.82, "background")
		background:AddAnchor("TOPLEFT", window, 0, 0)
		background:AddAnchor("BOTTOMRIGHT", window, 0, 0)

		window.messageLabel = CreateLabel(
			window,
			"unitTrackerExportNotifyLabel",
			"",
			width - 16,
			18,
			8,
			6,
			12,
			{ 0.72, 0.95, 0.55, 1 }
		)
		if window.messageLabel.style ~= nil then
			window.messageLabel.style:SetAlign(ALIGN_CENTER)
		end

		window.pathLabel = CreateLabel(
			window,
			"unitTrackerExportNotifyPath",
			"",
			width - 16,
			height - 34,
			8,
			28,
			10,
			{ 0.78, 0.84, 0.92, 1 }
		)
		if window.pathLabel.style ~= nil then
			window.pathLabel.style:SetAlign(ALIGN_CENTER)
		end
	else
		window:SetExtent(width, height)
		if window.messageLabel ~= nil then
			window.messageLabel:SetExtent(width - 16, 18)
		end
		if window.pathLabel ~= nil then
			window.pathLabel:SetExtent(width - 16, math.max(18, height - 34))
		end
	end

	window.messageLabel:SetText(tostring(message or "Export successful."))
	if window.pathLabel ~= nil then
		window.pathLabel:SetText(tostring(path or ""))
	end
	window:Show(true)
	runtime.exportNotifyHideAt = Now() + holdSeconds
end

function listSave.UpdateExportNotify()
	local hideAt = tonumber(runtime.exportNotifyHideAt) or 0
	if hideAt <= 0 then
		return
	end
	if Now() < hideAt then
		return
	end
	runtime.exportNotifyHideAt = 0
	if runtime.exportNotifyWindow ~= nil then
		runtime.exportNotifyWindow:Show(false)
	end
end

UT.GetCurrentDateTimeText = GetCurrentDateTimeText
UT.ClearUnitIdKey = ClearUnitIdKey
UT.BindUnitIdKey = BindUnitIdKey
UT.FindTrackedEntry = FindTrackedEntry
UT.MigrateTrackedKey = MigrateTrackedKey
UT.AddOrderedEntry = AddOrderedEntry
UT.RemoveOrderedEntry = RemoveOrderedEntry
UT.LoadSavedEntry = LoadSavedEntry
UT.ClearSessionUnitIds = ClearSessionUnitIds
UT.LoadSavedList = LoadSavedList
UT.LoadLists = LoadLists
UT.BuildSavedList = BuildSavedList
UT.PersistLists = PersistLists
UT.SaveLists = SaveLists
UT.EscapeFileField = EscapeFileField
UT.GetCurrentDateText = GetCurrentDateText
UT.AddUniquePath = AddUniquePath
UT.GetAddonSourceDirectory = GetAddonSourceDirectory
UT.TryOpenFile = TryOpenFile
UT.BuildExportFilePaths = BuildExportFilePaths
UT.WriteExportSection = WriteExportSection
UT.WriteExportFile = WriteExportFile
UT.ExportPlayerLists = ExportPlayerLists
UT.GetCurrentTargetUnitId = GetCurrentTargetUnitId
UT.GetSelectedTargetGuildName = GetSelectedTargetGuildName
UT.GetTargetRecord = GetTargetRecord
UT.DispatchExportStatus = DispatchExportStatus
UT.GetTrackedKeyForRecord = GetTrackedKeyForRecord
UT.IsHostileMarker = IsHostileMarker
UT.GetCurrentTargetMarker = GetCurrentTargetMarker
UT.SameUnitId = SameUnitId
UT.IsMarkerAvailable = IsMarkerAvailable
UT.ChooseHostileMarker = ChooseHostileMarker
UT.ForgetMarkerForKey = ForgetMarkerForKey
UT.RememberMarkerForKey = RememberMarkerForKey
UT.ApplyHostileTargetMarker = ApplyHostileTargetMarker
UT.ClearOwnedHostileMarker = ClearOwnedHostileMarker
UT.SyncTrackedEntryForRecord = SyncTrackedEntryForRecord
UT.RefreshTargetState = RefreshTargetState
UT.AddCurrentTargetToList = AddCurrentTargetToList
UT.AddManualNameToList = AddManualNameToList
UT.RemoveNameFromList = RemoveNameFromList
UT.IsRemoveConfirmPending = IsRemoveConfirmPending
UT.ClearRemoveConfirm = ClearRemoveConfirm
UT.BeginRemoveConfirm = BeginRemoveConfirm

runtime.RefreshViewList = function()
	if UT.UpdateViewWindow ~= nil then
		UT.UpdateViewWindow()
	end
end
