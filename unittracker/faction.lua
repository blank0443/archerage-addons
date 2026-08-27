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


function runtime.faction.Normalize(value)
	local text = string.lower(Trim(tostring(value or "")))
	if text == "" or text == "nil" or text == "table" or text == "userdata" then
		return ""
	end
	-- Numeric faction ids → resolve via name API when possible.
	local asNumber = tonumber(text)
	if asNumber ~= nil and X2Unit ~= nil then
		local ok, byId = SafeCall(X2Unit, "GetTopLevelFactionNameById", asNumber)
		if ok and Trim(tostring(byId or "")) ~= "" then
			text = string.lower(Trim(tostring(byId)))
		end
	end
	if string.find(text, "pirate", 1, true) ~= nil
		or string.find(text, "pirat", 1, true) ~= nil
		or string.find(text, "freeboot", 1, true) ~= nil
		or string.find(text, "corsair", 1, true) ~= nil
		or string.find(text, "growlgate", 1, true) ~= nil
		or string.find(text, "outlaw", 1, true) ~= nil
	then
		return "pirate"
	end
	-- Nation / alliance / race-subfaction labels → three camps.
	-- Do NOT match bare "west"/"east": "West Ishvaran" is Haranya, not Nuia.
	if string.find(text, "nuia", 1, true) ~= nil
		or string.find(text, "nuian", 1, true) ~= nil
		or string.find(text, "dreamwalker", 1, true) ~= nil
		or string.find(text, "queen's crown", 1, true) ~= nil
		or string.find(text, "queens crown", 1, true) ~= nil
		or string.find(text, "andelph", 1, true) ~= nil
		or string.find(text, "western", 1, true) ~= nil
		or text == "nui"
	then
		return "nuia"
	end
	if string.find(text, "haranya", 1, true) ~= nil
		or string.find(text, "harihara", 1, true) ~= nil
		or string.find(text, "harani", 1, true) ~= nil
		or string.find(text, "ishvaran", 1, true) ~= nil
		or string.find(text, "wandering wind", 1, true) ~= nil
		or string.find(text, "repentant", 1, true) ~= nil
		or string.find(text, "ferre", 1, true) ~= nil
		or string.find(text, "firran", 1, true) ~= nil
		or string.find(text, "warborn", 1, true) ~= nil
		or string.find(text, "eastern", 1, true) ~= nil
	then
		return "haranya"
	end
	return ""
end

-- Pull a faction label out of unit-info tables (string, number, or nested table).
function runtime.faction.ExtractRaw(source)
	if source == nil then
		return ""
	end
	local sourceType = type(source)
	if sourceType == "string" or sourceType == "number" then
		local text = Trim(tostring(source))
		if text == "" or text == "nil" then
			return ""
		end
		return text
	end
	if sourceType ~= "table" then
		return ""
	end
	local candidates = {
		source.faction,
		source.factionName,
		source.faction_name,
		source.topLevelFaction,
		source.topLevelFactionName,
		source.factionId,
	}
	-- UnitInfo tables also have character id/name; only treat id/key as faction
	-- on nested faction objects (no type/name/expedition fields).
	local looksLikeUnit = source.type ~= nil
		or source.name ~= nil
		or source.expeditionName ~= nil
		or source.guildName ~= nil
	if not looksLikeUnit then
		candidates[#candidates + 1] = source.id
		candidates[#candidates + 1] = source.key
	end
	for index = 1, #candidates do
		local text = runtime.faction.ExtractRaw(candidates[index])
		if text ~= "" then
			return text
		end
	end
	return ""
end

function runtime.faction.ResolveCampFromRaw(raw)
	raw = Trim(tostring(raw or ""))
	if raw == "" or raw == "nil" then
		return ""
	end
	if runtime.faction.IsKnownPirateRaw(raw) then
		return "pirate"
	end
	local camp = runtime.faction.Normalize(raw)
	if camp ~= "" then
		return camp
	end
	local id = tonumber(raw)
	if id == nil then
		return ""
	end
	if X2Unit ~= nil then
		local ok, name = SafeCall(X2Unit, "GetTopLevelFactionNameById", id)
		if ok then
			if runtime.faction.IsKnownPirateRaw(name) then
				return "pirate"
			end
			camp = runtime.faction.Normalize(name)
			if camp ~= "" then
				return camp
			end
		end
	end
	if X2Faction ~= nil then
		local okTop, topFaction = SafeCall(X2Faction, "GetTopLevelFaction", id)
		if okTop then
			local topRaw = runtime.faction.ExtractRaw(topFaction)
			if topRaw ~= "" then
				if runtime.faction.IsKnownPirateRaw(topRaw) then
					return "pirate"
				end
				camp = runtime.faction.Normalize(topRaw)
				if camp ~= "" then
					return camp
				end
			end
		end
		local ok, name = SafeCall(X2Faction, "GetFactionName", id, true)
		if ok then
			if runtime.faction.IsKnownPirateRaw(name) then
				return "pirate"
			end
			camp = runtime.faction.Normalize(name)
			if camp ~= "" then
				return camp
			end
		end
		ok, name = SafeCall(X2Faction, "GetFactionName", id, false)
		if ok then
			if runtime.faction.IsKnownPirateRaw(name) then
				return "pirate"
			end
			camp = runtime.faction.Normalize(name)
			if camp ~= "" then
				return camp
			end
		end
	end
	return ""
end

function runtime.faction.LoadPirateRaws()
	local saved = LoadData(persist.PIRATE_FACTION_KEY)
	runtime.pirateFactionRaws = {}
	runtime.pirateFactionLoaded = true
	if type(saved) ~= "table" then
		return
	end
	local list = saved.raws or saved
	if type(list) ~= "table" then
		return
	end
	local purged = false
	for index = 1, #list do
		local key = runtime.faction.RawKey(list[index])
		-- Drop relationship labels previously learned by mistake (e.g. "hostile").
		if key ~= "" and not runtime.faction.IsRelationshipFactionLabel(key) then
			runtime.pirateFactionRaws[key] = true
		elseif key ~= "" then
			purged = true
		end
	end
	if purged then
		runtime.faction.SavePirateRaws()
	end
end

function runtime.faction.SavePirateRaws()
	local raws = {}
	for key in pairs(runtime.pirateFactionRaws or {}) do
		raws[#raws + 1] = key
	end
	SaveData(persist.PIRATE_FACTION_KEY, { raws = raws })
end

function runtime.faction.IsKnownPirateRaw(value)
	local key = runtime.faction.RawKey(value)
	if key == "" then
		return false
	end
	if runtime.pirateFactionLoaded ~= true then
		runtime.faction.LoadPirateRaws()
	end
	return runtime.pirateFactionRaws[key] == true
end

function runtime.faction.RememberPirateRaw(value)
	local key = runtime.faction.RawKey(value)
	if key == "" or key == "pirate" or key == "nuia" or key == "haranya" then
		return false
	end
	-- Never persist relationship strings as pirate camps.
	if runtime.faction.IsRelationshipFactionLabel(key) then
		return false
	end
	if runtime.pirateFactionLoaded ~= true then
		runtime.faction.LoadPirateRaws()
	end
	if runtime.pirateFactionRaws[key] == true then
		return false
	end
	runtime.pirateFactionRaws[key] = true
	runtime.faction.SavePirateRaws()
	return true
end

-- Capture live target faction id/name signatures when the user marks Pirate via F.
function runtime.faction.RememberPirateFromTarget()
	local read = runtime.faction.ReadUnitFaction("target")
	if read.raw ~= "" then
		runtime.faction.RememberPirateRaw(read.raw)
	end
	if X2Unit ~= nil then
		local okId, factionId = SafeCall(X2Unit, "GetTopLevelFactionId", "target")
		if okId and factionId ~= nil then
			runtime.faction.RememberPirateRaw(factionId)
			local okName, factionName = SafeCall(X2Unit, "GetTopLevelFactionNameById", factionId)
			if okName then
				runtime.faction.RememberPirateRaw(factionName)
			end
		end
		local okTop, topName = SafeCall(X2Unit, "GetTopLevelFactionName", "target")
		if okTop then
			runtime.faction.RememberPirateRaw(topName)
		end
		local okFaction, factionName = SafeCall(X2Unit, "GetFactionName", "target")
		if okFaction then
			runtime.faction.RememberPirateRaw(factionName)
		end
	end
end

function runtime.faction.RawKey(value)
	local text = Trim(tostring(value or ""))
	if text == "" or text == "nil" then
		return ""
	end
	return string.lower(text)
end

-- UnitInfo.faction is often a relationship label ("hostile"/"friendly"), not a camp.
-- Never learn those as pirate signatures — that would paint every opposite player pink.
function runtime.faction.IsRelationshipFactionLabel(value)
	local key = runtime.faction.RawKey(value)
	if key == "" then
		return false
	end
	if key == "hostile"
		or key == "friendly"
		or key == "neutral"
		or key == "enemy"
		or key == "ally"
		or key == "war"
		or key == "peace"
		or key == "same"
		or key == "opposite"
	then
		return true
	end
	if string.find(key, "ur_", 1, true) == 1
		or string.find(key, "nr_", 1, true) == 1
		or string.find(key, "mst_", 1, true) == 1
	then
		return true
	end
	return runtime.faction.ParseRelationship(value) ~= nil
end

function runtime.faction.GetLocalRaw()
	return runtime.faction.RawKey(runtime.localPlayerFactionRaw)
end

function runtime.faction.GetLocalCamp()
	local camp = runtime.faction.Normalize(runtime.localPlayerFaction)
	if camp ~= "" then
		return camp
	end
	return runtime.faction.Normalize(runtime.localPlayerFactionRaw)
end

function runtime.faction.GetEntryCamp(entry)
	if type(entry) ~= "table" then
		return ""
	end
	local camp = runtime.faction.Normalize(entry.faction)
	if camp ~= "" then
		return camp
	end
	return runtime.faction.Normalize(entry.factionRaw or entry.factionName)
end

function runtime.faction.GetEntry(entry)
	return runtime.faction.GetEntryCamp(entry)
end

function runtime.faction.GetSnap(entry)
	if type(entry) ~= "table" then
		return { key = "", raw = "", sameFaction = nil, manual = false }
	end
	return {
		key = runtime.faction.GetEntryCamp(entry),
		raw = runtime.faction.RawKey(entry.factionRaw),
		sameFaction = entry.sameFaction,
		manual = entry.factionManual == true,
	}
end

function runtime.faction.SetEntry(entry, snap)
	if type(entry) ~= "table" then
		return false
	end
	if type(snap) ~= "table" then
		snap = { key = runtime.faction.Normalize(snap) }
	end
	-- Manual Note-UI picks win until the next manual pick.
	if entry.factionManual == true and snap.manual ~= true then
		return false
	end

	local changed = false
	local key = runtime.faction.Normalize(snap.key or snap.faction)
	local raw = Trim(tostring(snap.raw or snap.factionRaw or ""))
	if key == "" and raw ~= "" then
		key = runtime.faction.Normalize(raw)
	end
	if key ~= "" and entry.faction ~= key then
		entry.faction = key
		changed = true
	end
	if raw ~= "" then
		local rawKey = runtime.faction.RawKey(raw)
		if runtime.faction.RawKey(entry.factionRaw) ~= rawKey then
			entry.factionRaw = raw
			changed = true
		end
	end
	if snap.sameFaction == true and entry.sameFaction ~= true then
		entry.sameFaction = true
		changed = true
	elseif snap.sameFaction == false and entry.sameFaction ~= false then
		entry.sameFaction = false
		changed = true
	end
	if snap.manual == true and entry.factionManual ~= true then
		entry.factionManual = true
		changed = true
	end
	return changed
end

-- Manual F colors: Nuia=green, Haranya=red, Pirate=pink (not live camp detection).
function runtime.faction.SameFactionForManualCamp(camp)
	camp = runtime.faction.Normalize(camp)
	if camp == "nuia" then
		return true
	end
	if camp == "haranya" or camp == "pirate" then
		return false
	end
	return nil
end

function runtime.faction.StampEntryManual(entry, camp, sameFaction)
	if type(entry) ~= "table" then
		return false
	end
	camp = runtime.faction.Normalize(camp)
	if camp ~= "nuia" and camp ~= "haranya" and camp ~= "pirate" then
		return false
	end
	local changed = false
	if entry.faction ~= camp then
		entry.faction = camp
		changed = true
	end
	if entry.factionRaw ~= camp then
		entry.factionRaw = camp
		changed = true
	end
	if entry.factionManual ~= true then
		entry.factionManual = true
		changed = true
	end
	if sameFaction == true then
		if entry.sameFaction ~= true then
			entry.sameFaction = true
			changed = true
		end
	elseif sameFaction == false then
		if entry.sameFaction ~= false then
			entry.sameFaction = false
			changed = true
		end
	end
	return changed
end

function runtime.faction.GuildKey(value)
	return runtime.faction.RawKey(value)
end

function runtime.faction.LoadGuildFactions()
	local saved = LoadData(persist.GUILD_FACTION_KEY)
	runtime.guildFactions = {}
	runtime.guildFactionsLoaded = true
	if type(saved) ~= "table" then
		return
	end
	local source = saved.guilds or saved
	if type(source) ~= "table" then
		return
	end
	for guild, info in pairs(source) do
		local key = runtime.faction.GuildKey(guild)
		if key ~= "" and type(info) == "table" then
			local camp = runtime.faction.Normalize(info.camp or info.faction or info.key)
			if camp == "nuia" or camp == "haranya" or camp == "pirate" then
				runtime.guildFactions[key] = {
					camp = camp,
					sameFaction = runtime.faction.SameFactionForManualCamp(camp),
				}
			end
		end
	end
end

function runtime.faction.SaveGuildFactions()
	local guilds = {}
	for key, info in pairs(runtime.guildFactions or {}) do
		if type(info) == "table" and info.camp ~= nil then
			guilds[key] = {
				camp = info.camp,
				sameFaction = info.sameFaction == true,
			}
		end
	end
	SaveData(persist.GUILD_FACTION_KEY, { guilds = guilds })
end

function runtime.faction.EnsureGuildFactions()
	if runtime.guildFactionsLoaded ~= true then
		runtime.faction.LoadGuildFactions()
	end
end

function runtime.faction.GetGuildFaction(guild)
	runtime.faction.EnsureGuildFactions()
	local key = runtime.faction.GuildKey(guild)
	if key == "" then
		return nil
	end
	return runtime.guildFactions[key]
end

function runtime.faction.RememberGuildFaction(guild, camp)
	camp = runtime.faction.Normalize(camp)
	local key = runtime.faction.GuildKey(guild)
	if key == "" or (camp ~= "nuia" and camp ~= "haranya" and camp ~= "pirate") then
		return false
	end
	runtime.faction.EnsureGuildFactions()
	local sameFaction = runtime.faction.SameFactionForManualCamp(camp)
	local existing = runtime.guildFactions[key]
	if type(existing) == "table"
		and existing.camp == camp
		and existing.sameFaction == sameFaction
	then
		return false
	end
	runtime.guildFactions[key] = {
		camp = camp,
		sameFaction = sameFaction,
	}
	runtime.faction.SaveGuildFactions()
	return true
end

function runtime.faction.ApplyGuildFactionToEntry(entry)
	if type(entry) ~= "table" then
		return false
	end
	if entry.factionManual == true then
		return false
	end
	local hint = runtime.faction.GetGuildFaction(GetEntryGuild(entry))
	if hint == nil or hint.camp == nil then
		return false
	end
	return runtime.faction.StampEntryManual(entry, hint.camp, hint.sameFaction)
end

function runtime.faction.ApplyGuildFactionToLists(guild, camp, sameFaction)
	local key = runtime.faction.GuildKey(guild)
	camp = runtime.faction.Normalize(camp)
	if key == "" or (camp ~= "nuia" and camp ~= "haranya" and camp ~= "pirate") then
		return 0
	end
	if sameFaction == nil then
		sameFaction = runtime.faction.SameFactionForManualCamp(camp)
	end
	local count = 0
	local function applyList(list)
		if type(list) ~= "table" then
			return
		end
		for _, entry in pairs(list) do
			if type(entry) == "table" and runtime.faction.GuildKey(GetEntryGuild(entry)) == key then
				if runtime.faction.StampEntryManual(entry, camp, sameFaction) then
					count = count + 1
				elseif entry.factionManual == true and entry.faction == camp then
					-- Already stamped; still counts as covered.
				end
			end
		end
	end
	applyList(runtime.friendly)
	applyList(runtime.hostile)
	return count
end

-- After list load: merge manual entry stamps into the guild map, then paint guild mates.
function runtime.faction.OnListsLoaded()
	runtime.faction.EnsureGuildFactions()
	local function harvest(list)
		if type(list) ~= "table" then
			return
		end
		for _, entry in pairs(list) do
			if type(entry) == "table" and entry.factionManual == true then
				local camp = runtime.faction.GetEntryCamp(entry)
				local guild = GetEntryGuild(entry)
				if camp ~= "" and guild ~= "" then
					runtime.faction.RememberGuildFaction(guild, camp)
				end
			end
		end
	end
	harvest(runtime.friendly)
	harvest(runtime.hostile)

	local function paint(list)
		if type(list) ~= "table" then
			return
		end
		for _, entry in pairs(list) do
			runtime.faction.ApplyGuildFactionToEntry(entry)
		end
	end
	paint(runtime.friendly)
	paint(runtime.hostile)
end

-- Allowed path: GetUnitId + GetUnitInfoById; name APIs behind pcall as fallback.
function runtime.faction.ReadUnitFaction(unit)
	local result = { raw = "", camp = "" }
	unit = Trim(tostring(unit or ""))
	if unit == "" or X2Unit == nil then
		return result
	end

	local unitId = nil
	if unit == "player" or unit == "target" then
		local ok, id = SafeCall(X2Unit, "GetUnitId", unit)
		if ok and IsValidName(id) then
			unitId = tostring(id)
		end
		if unitId == nil and unit == "target" then
			local okTarget, targetId = SafeCall(X2Unit, "GetTargetUnitId")
			if okTarget and IsValidName(targetId) then
				unitId = tostring(targetId)
			end
		end
	else
		unitId = NormalizeUnitId(unit) or unit
	end

	if unitId ~= nil and unitId ~= "" then
		local unitInfo = GetUnitInfoById(unitId)
		if type(unitInfo) == "table" and (unitInfo.type == nil or unitInfo.type == "character") then
			local raw = runtime.faction.ExtractRaw(unitInfo)
			if raw == "" and unitInfo.faction ~= nil then
				raw = Trim(tostring(unitInfo.faction))
				if raw == "nil" then
					raw = ""
				end
			end
			if raw ~= "" then
				result.raw = raw
				result.camp = runtime.faction.ResolveCampFromRaw(raw)
			end
			-- Race implies starting continent, not pirate status — only use when
			-- no faction string was present at all.
			if result.camp == "" and result.raw == "" then
				local raceCamp = runtime.faction.CampFromRace(unitInfo.race or unitInfo.raceId or unitInfo.race_id)
				if raceCamp ~= "" then
					result.camp = raceCamp
				end
			end
		end
	end

	if result.camp == "" then
		local okName, factionName = SafeCall(X2Unit, "GetTopLevelFactionName", unit)
		if okName then
			local raw = runtime.faction.ExtractRaw(factionName)
			if raw ~= "" then
				result.raw = raw
				result.camp = runtime.faction.Normalize(raw)
			end
		end
	end
	if result.camp == "" then
		local okName, factionName = SafeCall(X2Unit, "GetFactionName", unit)
		if okName then
			local raw = runtime.faction.ExtractRaw(factionName)
			if raw ~= "" then
				result.raw = raw
				result.camp = runtime.faction.Normalize(raw)
			end
		end
	end
	if result.camp == "" then
		local okId, factionId = SafeCall(X2Unit, "GetTopLevelFactionId", unit)
		if okId and factionId ~= nil then
			local raw = runtime.faction.ExtractRaw(factionId)
			if raw ~= "" then
				result.raw = raw
				result.camp = runtime.faction.Normalize(raw)
			end
		end
	end
	if result.camp == "" then
		local okInfo, unitInfo = SafeCall(X2Unit, "UnitInfo", unit)
		if okInfo and type(unitInfo) == "table" then
			local raw = runtime.faction.ExtractRaw(unitInfo)
			if raw ~= "" then
				result.raw = raw
				result.camp = runtime.faction.Normalize(raw)
			end
		end
	end

	return result
end

function runtime.faction.CaptureLocal()
	if runtime.pirateFactionLoaded ~= true then
		runtime.faction.LoadPirateRaws()
	end
	local read = runtime.faction.ReadUnitFaction("player")
	local raw = read.raw
	local camp = read.camp

	local saved = LoadData(persist.LOCAL_FACTION_KEY)
	if type(saved) == "table" then
		if raw == "" then
			raw = Trim(tostring(saved.raw or saved.factionRaw or ""))
		end
		if camp == "" then
			camp = runtime.faction.Normalize(saved.key or saved.faction or raw)
		end
	elseif type(saved) == "string" and raw == "" then
		raw = Trim(saved)
		camp = runtime.faction.Normalize(raw)
	end

	if raw ~= "" then
		runtime.localPlayerFactionRaw = raw
	end
	-- Only freeze retries once we have a usable camp (nuia/haranya/pirate).
	if camp == "" then
		runtime.localFactionReady = false
		return false
	end

	runtime.localPlayerFaction = camp
	runtime.localFactionReady = true
	SaveData(persist.LOCAL_FACTION_KEY, {
		raw = runtime.localPlayerFactionRaw or raw,
		key = camp,
	})
	return true
end

function runtime.faction.EnsureLocal()
	if runtime.faction.GetLocalCamp() == "" then
		runtime.localFactionReady = false
		runtime.faction.CaptureLocal()
	end
	return runtime.faction.GetLocalCamp(), runtime.faction.GetLocalRaw()
end

function runtime.faction.RememberLocalCamp(camp)
	camp = runtime.faction.Normalize(camp)
	if camp ~= "nuia" and camp ~= "haranya" then
		return false
	end
	if runtime.faction.GetLocalCamp() == camp then
		return false
	end
	runtime.localPlayerFaction = camp
	runtime.localFactionReady = true
	SaveData(persist.LOCAL_FACTION_KEY, {
		raw = runtime.localPlayerFactionRaw or "",
		key = camp,
	})
	return true
end

function runtime.faction.Relate(camp, raw)
	camp = runtime.faction.Normalize(camp)
	raw = runtime.faction.RawKey(raw)
	local localCamp, localRaw = runtime.faction.EnsureLocal()

	local rawCamp = ""
	if raw ~= "" then
		rawCamp = runtime.faction.Normalize(raw)
		if camp == "" then
			camp = rawCamp
		end
	end

	if camp == "pirate" or rawCamp == "pirate" then
		return false
	end
	if raw ~= "" and localRaw ~= "" and raw == localRaw then
		-- Exact UnitInfo.faction string match = same faction (how green works today).
		if camp == "nuia" or camp == "haranya" then
			runtime.faction.RememberLocalCamp(camp)
		end
		return true
	end

	-- EnsureLocal may leave localCamp blank while localRaw still normalizes.
	if localCamp == "" and localRaw ~= "" then
		localCamp = runtime.faction.Normalize(localRaw)
	end

	if camp ~= "" and localCamp ~= "" then
		if camp == localCamp and (camp == "nuia" or camp == "haranya") then
			runtime.faction.RememberLocalCamp(camp)
		end
		return camp == localCamp
	end

	local localRawCamp = ""
	if localRaw ~= "" then
		localRawCamp = runtime.faction.Normalize(localRaw)
	end
	if rawCamp ~= "" and localRawCamp ~= "" then
		return rawCamp == localRawCamp
	end

	-- Same-faction green uses exact raw equality. A different non-empty faction
	-- string from UnitInfo is opposite/pirate even when it never normalizes.
	if raw ~= "" and localRaw ~= "" and raw ~= localRaw then
		return false
	end
	return nil
end

-- Allowed relationship APIs (pcall): used when camp strings are missing for enemies.
function runtime.faction.ParseRelationship(value)
	if value == nil then
		return nil
	end
	if value == true then
		return true
	end
	if value == false then
		return false
	end
	-- X2 unit/nation relationship enums (globals from the client).
	if UR_FRIENDLY ~= nil and value == UR_FRIENDLY then
		return true
	end
	if UR_HOSTILE ~= nil and value == UR_HOSTILE then
		return false
	end
	if NR_FRIENDLY ~= nil and value == NR_FRIENDLY then
		return true
	end
	if NR_HOSTILE ~= nil and value == NR_HOSTILE then
		return false
	end
	if NR_WAR ~= nil and value == NR_WAR then
		return false
	end
	if MST_FRIENDLY ~= nil and value == MST_FRIENDLY then
		return true
	end
	if MST_HOSTILE ~= nil and value == MST_HOSTILE then
		return false
	end
	if UR_NEUTRAL ~= nil and value == UR_NEUTRAL then
		return nil
	end

	local text = string.lower(Trim(tostring(value)))
	if text == "" or text == "nil" then
		return nil
	end
	if text == "ur_friendly" or text == "nr_friendly" or text == "mst_friendly" then
		return true
	end
	if text == "ur_hostile" or text == "nr_hostile" or text == "mst_hostile" or text == "nr_war" then
		return false
	end
	if string.find(text, "friend", 1, true) ~= nil
		or string.find(text, "ally", 1, true) ~= nil
		or string.find(text, "same", 1, true) ~= nil
		or string.find(text, "peace", 1, true) ~= nil
	then
		return true
	end
	if string.find(text, "hostile", 1, true) ~= nil
		or string.find(text, "enemy", 1, true) ~= nil
		or string.find(text, "foe", 1, true) ~= nil
		or string.find(text, "opposite", 1, true) ~= nil
		or string.find(text, "attack", 1, true) ~= nil
	then
		return false
	end
	return nil
end

function runtime.faction.ReadTargetRelationship()
	if X2Unit == nil then
		return nil
	end
	local okFaction, factionRel = SafeCall(X2Unit, "GetTargetFactionRelationship")
	if okFaction then
		local parsed = runtime.faction.ParseRelationship(factionRel)
		if parsed ~= nil then
			return parsed
		end
	end
	local okCombat, combatRel = SafeCall(X2Unit, "GetTargetCombatRelationship")
	if okCombat then
		local parsed = runtime.faction.ParseRelationship(combatRel)
		if parsed ~= nil then
			return parsed
		end
	end
	local okStr, combatStr = SafeCall(X2Unit, "GetCombatRelationshipStr", "target")
	if okStr then
		local parsed = runtime.faction.ParseRelationship(combatStr)
		if parsed ~= nil then
			return parsed
		end
	end
	-- Compare top-level faction ids (not-allowed; pcall).
	local okPlayerId, playerFactionId = SafeCall(X2Unit, "GetTopLevelFactionId", "player")
	local okTargetId, targetFactionId = SafeCall(X2Unit, "GetTopLevelFactionId", "target")
	if okPlayerId and okTargetId and playerFactionId ~= nil and targetFactionId ~= nil then
		if tostring(playerFactionId) == tostring(targetFactionId) then
			return true
		end
		if X2Faction ~= nil then
			local okState, state = SafeCall(X2Faction, "GetInterFactionState", playerFactionId, targetFactionId)
			if okState then
				local parsed = runtime.faction.ParseRelationship(state)
				if parsed ~= nil then
					return parsed
				end
			end
		end
		return false
	end
	-- Aggressive-hostile flag (not-allowed; pcall). True ⇒ treat as opposite for coloring.
	local okAgg, aggressive = SafeCall(X2Unit, "UnitIsAggressiveHostile", "target")
	if okAgg and aggressive == true then
		return false
	end
	-- Fallback: compare live UnitInfo faction fields (works when names never normalize).
	local okPlayer, playerInfo = SafeCall(X2Unit, "UnitInfo", "player")
	local okTarget, targetInfo = SafeCall(X2Unit, "UnitInfo", "target")
	if okPlayer and okTarget and type(playerInfo) == "table" and type(targetInfo) == "table" then
		local playerRaw = runtime.faction.RawKey(runtime.faction.ExtractRaw(playerInfo))
		if playerRaw == "" and playerInfo.faction ~= nil then
			playerRaw = runtime.faction.RawKey(playerInfo.faction)
		end
		local targetRaw = runtime.faction.RawKey(runtime.faction.ExtractRaw(targetInfo))
		if targetRaw == "" and targetInfo.faction ~= nil then
			targetRaw = runtime.faction.RawKey(targetInfo.faction)
		end
		if playerRaw ~= "" and targetRaw ~= "" then
			if playerRaw == targetRaw then
				return true
			end
			local playerCamp = runtime.faction.ResolveCampFromRaw(playerRaw)
			local targetCamp = runtime.faction.ResolveCampFromRaw(targetRaw)
			if playerCamp ~= "" and targetCamp ~= "" then
				return playerCamp == targetCamp
			end
			return false
		end
	end
	return nil
end

-- When we know local camp and the target is opposite but unlabeled, stamp the other nation.
function runtime.faction.InferOppositeCamp(localCamp)
	localCamp = runtime.faction.Normalize(localCamp)
	if localCamp == "nuia" then
		return "haranya"
	end
	if localCamp == "haranya" then
		return "nuia"
	end
	return ""
end

-- Race → camp when faction strings are blank (common for opposite-faction targets).
function runtime.faction.CampFromRace(value)
	if value == nil then
		return ""
	end
	-- Prefer client race globals when the dump exposes them.
	if RACE_NUIAN ~= nil and (value == RACE_NUIAN or value == RACE_ELF or value == RACE_DWARF or value == RACE_FAIRY) then
		return "nuia"
	end
	if RACE_HARIHARAN ~= nil and (
		value == RACE_HARIHARAN or value == RACE_FERRE or value == RACE_WARBORN or value == RACE_RETURNED
	) then
		return "haranya"
	end

	local text = string.lower(Trim(tostring(value)))
	if text == "" or text == "nil" then
		return ""
	end
	if text == "nuian" or text == "elf" or text == "dwarf" or text == "fairy"
		or text == "race_nuian" or text == "race_elf" or text == "race_dwarf" or text == "race_fairy"
	then
		return "nuia"
	end
	if text == "hariharan" or text == "harani" or text == "ferre" or text == "firran"
		or text == "warborn" or text == "returned"
		or text == "race_hariharan" or text == "race_ferre" or text == "race_warborn" or text == "race_returned"
	then
		return "haranya"
	end
	return ""
end

function runtime.faction.GetSelected()
	local raw = ""
	local same = nil

	local unitId = nil
	local okId, id = SafeCall(X2Unit, "GetUnitId", "target")
	if okId and IsValidName(id) then
		unitId = tostring(id)
	end
	if unitId == nil then
		local okTarget, targetId = SafeCall(X2Unit, "GetTargetUnitId")
		if okTarget and IsValidName(targetId) then
			unitId = tostring(targetId)
		end
	end

	-- Live coloring uses UnitInfo.faction relationship strings only
	-- (friendly → green, hostile → red). No camp/race auto-detection.
	if unitId ~= nil then
		local byId = GetUnitInfoById(unitId)
		if type(byId) == "table" and (byId.type == nil or byId.type == "character") then
			if byId.faction ~= nil then
				raw = Trim(tostring(byId.faction))
				if raw == "nil" then
					raw = ""
				end
				if raw ~= "" then
					same = runtime.faction.ParseRelationship(raw)
				end
			end
		end
	end

	if same == nil then
		same = runtime.faction.ReadTargetRelationship()
	end

	if raw == "" or same == nil then
		local okInfo, unitInfo = SafeCall(X2Unit, "UnitInfo", "target")
		if okInfo and type(unitInfo) == "table" then
			if raw == "" and unitInfo.faction ~= nil then
				raw = Trim(tostring(unitInfo.faction))
				if raw == "nil" then
					raw = ""
				end
			end
			if same == nil and raw ~= "" then
				same = runtime.faction.ParseRelationship(raw)
			end
		end
	end

	if raw == "" and same == nil then
		return { key = "", raw = "", sameFaction = nil }, false
	end

	return {
		key = "",
		raw = raw,
		sameFaction = same,
	}, true
end

function runtime.faction.NameColor(entry, key)
	local camp = ""
	local sameFaction = nil
	local manual = type(entry) == "table" and entry.factionManual == true

	if type(entry) == "table" then
		camp = runtime.faction.GetEntryCamp(entry)
		if entry.sameFaction == true or entry.sameFaction == 1 or entry.sameFaction == "1" then
			sameFaction = true
		elseif entry.sameFaction == false or entry.sameFaction == 0 or entry.sameFaction == "0" then
			sameFaction = false
		end
		-- Guild mates inherit a prior F pick even if this row was never stamped yet.
		if not manual then
			local hint = runtime.faction.GetGuildFaction(GetEntryGuild(entry))
			if hint ~= nil and hint.camp ~= nil then
				camp = runtime.faction.Normalize(hint.camp)
				sameFaction = hint.sameFaction
				manual = true
			end
		end
	end

	-- Manual / guild F stamp: Nuia green, Haranya red, Pirate pink.
	if manual then
		if camp == "pirate" then
			return LIST_COLORS.pirate
		end
		if camp == "nuia" then
			return LIST_COLORS.sameFaction
		end
		if camp == "haranya" then
			return LIST_COLORS.hostile
		end
	end

	-- Live selected target: friendly/hostile relationship string.
	local record = runtime.currentTarget
	if record ~= nil and key ~= nil and record.key == key and type(record.faction) == "table" then
		if record.faction.sameFaction == true then
			return LIST_COLORS.sameFaction
		end
		if record.faction.sameFaction == false then
			return LIST_COLORS.hostile
		end
	end

	-- Previously observed relationship on the saved entry.
	if sameFaction == true then
		return LIST_COLORS.sameFaction
	end
	if sameFaction == false then
		return LIST_COLORS.hostile
	end
	return LIST_COLORS.unknown
end

function runtime.faction.DisplayName(camp)
	camp = runtime.faction.Normalize(camp)
	if camp == "nuia" then
		return "Nuia"
	end
	if camp == "haranya" then
		return "Haranya"
	end
	if camp == "pirate" then
		return "Pirate"
	end
	return ""
end

function runtime.faction.SetManual(key, camp)
	key = Trim(tostring(key or ""))
	camp = runtime.faction.Normalize(camp)
	if key == "" or (camp ~= "nuia" and camp ~= "haranya" and camp ~= "pirate") then
		return false
	end
	local entry = runtime.friendly[key] or runtime.hostile[key]
	if type(entry) ~= "table" then
		return false
	end

	local same = runtime.faction.SameFactionForManualCamp(camp)
	runtime.faction.StampEntryManual(entry, camp, same)

	-- Same guild ⇒ same faction: propagate F color to all listed guild mates.
	local guild = GetEntryGuild(entry)
	if guild ~= "" then
		runtime.faction.RememberGuildFaction(guild, camp)
		runtime.faction.ApplyGuildFactionToLists(guild, camp, same)
	end

	-- Keep live target snap aligned so the open Note UI target does not re-orange the row.
	local record = runtime.currentTarget
	if record ~= nil and record.key == key then
		record.faction = {
			key = camp,
			raw = camp,
			sameFaction = same,
		}
		record.factionKnown = true
	end

	UT.SaveLists(true)
	return true
end
