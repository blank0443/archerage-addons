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

function Analysis.FormatAmount(value)
	value = math.floor((tonumber(value) or 0) + 0.5)
	return tostring(value)
end

function Analysis.FormatCompactAmount(value)
	local amount = math.floor((tonumber(value) or 0) + 0.5)
	local absolute = math.abs(amount)
	local divisor = nil
	local suffix = ""
	if absolute >= 1000000000 then
		divisor = 1000000000
		suffix = "b"
	elseif absolute >= 1000000 then
		divisor = 1000000
		suffix = "m"
	elseif absolute >= 1000 then
		divisor = 1000
		suffix = "k"
	end
	if divisor == nil then
		return tostring(amount)
	end

	local scaled = amount / divisor
	if suffix == "k" and math.abs(scaled) >= 999.5 then
		scaled = amount / 1000000
		suffix = "m"
	elseif suffix == "m" and math.abs(scaled) >= 999.5 then
		scaled = amount / 1000000000
		suffix = "b"
	end
	local scaledAbs = math.abs(scaled)
	local text
	if scaledAbs >= 100 then
		text = string.format("%.0f", scaled)
	else
		text = string.format("%.1f", scaled)
		text = string.gsub(text, "%.0$", "")
	end
	return text .. suffix
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

function Analysis.FormatPerMinute(value)
	local rate = tonumber(value) or 0
	if rate <= 0 then
		return "0/m"
	end
	if rate >= 1000 then
		return Analysis.FormatCompactAmount(rate) .. "/m"
	end
	if rate >= 10 then
		return tostring(math.floor(rate + 0.5)) .. "/m"
	end
	return string.format("%.1f/m", rate)
end

function Analysis.FormatDistanceMeters(value)
	local meters = math.floor((tonumber(value) or 0) + 0.5)
	if meters <= 0 then
		return "0m"
	end
	return Analysis.FormatCompactAmount(meters) .. "m"
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
	return Analysis.FormatCompactAmount(amount)
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

function Analysis.GetKillsPerMinute(now)
	local elapsed = Analysis.GetSessionElapsedSeconds(now or Analysis.RefreshClock())
	if elapsed <= 0 then
		return 0
	end
	return Analysis.GetSessionKillTotal() / (elapsed / 60)
end

function Analysis.GetExpPerMinute(now)
	local elapsed = Analysis.GetSessionElapsedSeconds(now or Analysis.RefreshClock())
	if elapsed <= 0 then
		return 0
	end
	return (tonumber(runtime.totalExpGained) or 0) / (elapsed / 60)
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
		if IsValidName(itemName)
			and not Analysis.IsCurrencyLootItemName(itemName)
			and tonumber(count) ~= nil
			and tonumber(count) > 0
		then
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

function Analysis.BuildSortedSessionLootNames()
	Analysis.EnsureSessionLootItems()
	return Analysis.BuildSortedDropNames(runtime.sessionLootItems)
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
	local duration = Analysis.GetKillCombatDuration(Analysis.RefreshClock())
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

function Analysis.AddSkillUsageSnapshotAmount(snapshot, name, count)
	name = Trim(name or "")
	count = tonumber(count) or 0
	if name == "" or count <= 0 then
		return
	end
	local entry = snapshot[name]
	if type(entry) ~= "table" then
		entry = {
			name = name,
			count = 0,
		}
		snapshot[name] = entry
	end
	entry.count = (tonumber(entry.count) or 0) + count
end

-- Saved data now stores direct skill-use counts. Older sessions can still show
-- a ranking by rebuilding usage from damage/heal/miss/resource breakdowns.
function Analysis.BuildSkillUsageSnapshot()
	local snapshot = {}
	local hasDirectUsage = false
	for skillName, entry in pairs(runtime.skillUsageByName or {}) do
		if type(entry) == "table" then
			local count = tonumber(entry.count) or 0
			if count > 0 then
				Analysis.AddSkillUsageSnapshotAmount(snapshot, entry.name or skillName, count)
				hasDirectUsage = true
			end
		end
	end
	if hasDirectUsage then
		return snapshot
	end

	for skillKey, entry in pairs(runtime.damageBySkill or {}) do
		Analysis.AddSkillUsageSnapshotAmount(snapshot, Analysis.CleanAbilityDisplayName(skillKey, entry), tonumber(entry.hits) or 0)
	end
	for skillKey, entry in pairs(runtime.healBySkill or {}) do
		Analysis.AddSkillUsageSnapshotAmount(snapshot, Analysis.CleanAbilityDisplayName(skillKey, entry), tonumber(entry.hits) or 0)
	end
	for skillKey, entry in pairs(runtime.missesBySkill or {}) do
		Analysis.AddSkillUsageSnapshotAmount(snapshot, Analysis.CleanAbilityDisplayName(skillKey, entry), tonumber(entry.count) or 0)
	end
	for skillKey, entry in pairs(runtime.energizeBySkill or {}) do
		Analysis.AddSkillUsageSnapshotAmount(snapshot, Analysis.CleanAbilityDisplayName(skillKey, entry), tonumber(entry.hits) or 0)
	end
	return snapshot
end

function Analysis.BuildSortedSkillUsageKeys(snapshot)
	local amountsByKey = {}
	snapshot = snapshot or Analysis.BuildSkillUsageSnapshot()
	for skillName, entry in pairs(snapshot) do
		local count = tonumber(entry.count) or 0
		if count > 0 then
			amountsByKey[skillName] = count
		end
	end
	return Analysis.BuildSortedAmountKeys(amountsByKey)
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

function Analysis.GetLootSectionReserve(lootNames)
	local count = 0
	if type(lootNames) == "table" then
		count = #lootNames
	end
	if count <= 0 then
		return 3
	end
	count = count + 2
	if count > 12 then
		count = 12
	end
	return count
end

function Analysis.AppendSessionLootLines(lines, lootNames)
	lootNames = lootNames or Analysis.BuildSortedSessionLootNames()
	if #lines < VIEW_CONTENT_ROW_COUNT then
		Analysis.AddViewLine(lines, "spacer", "")
	end
	if not Analysis.AddViewLine(lines, "header", "Loot") then
		return false
	end
	if #lootNames == 0 then
		return Analysis.AddViewLine(lines, "drop", "  No loot recorded yet.")
	end

	local remainingRows = VIEW_CONTENT_ROW_COUNT - #lines
	local visibleItems = #lootNames
	if visibleItems > remainingRows then
		visibleItems = remainingRows - 1
	end
	if visibleItems < 0 then
		visibleItems = 0
	end
	for lootIndex = 1, visibleItems do
		local itemName = lootNames[lootIndex]
		local count = runtime.sessionLootItems[itemName]
		if not Analysis.AddViewLine(
			lines,
			"drop",
			Analysis.TruncateText("  " .. itemName .. " x" .. Analysis.FormatAmount(count), 100)
		) then
			return false
		end
	end
	if visibleItems < #lootNames then
		return Analysis.AddViewLine(lines, "drop", "  +" .. tostring(#lootNames - visibleItems) .. " more loot items")
	end
	return true
end

function Analysis.AppendCombatReviewLines(lines)
	local stats = Analysis.EnsurePlayerCombatStats()
	local totalDamage = Analysis.GetPlayerDamageTotal()
	local totalHealing = Analysis.GetPlayerHealTotal()
	local hits = tonumber(stats.totalHits) or 0
	local misses = tonumber(stats.totalMisses) or 0
	local damageTaken = tonumber(stats.totalDamageTaken) or 0
	local healingReceived = tonumber(stats.totalHealingReceived) or 0
	local skillUsageSnapshot = Analysis.BuildSkillUsageSnapshot()
	local skillUsageKeys = Analysis.BuildSortedSkillUsageKeys(skillUsageSnapshot)
	if damageTaken < (tonumber(runtime.totalDamageTaken) or 0) then
		damageTaken = tonumber(runtime.totalDamageTaken) or 0
	end
	local energizeKeys = Analysis.BuildSortedEntryKeys(runtime.energizeBySkill, "amount")
	if totalDamage <= 0
		and totalHealing <= 0
		and misses <= 0
		and damageTaken <= 0
		and healingReceived <= 0
		and #skillUsageKeys == 0
		and #energizeKeys == 0
	then
		return true
	end

	local duration = Analysis.GetKillCombatDuration(Analysis.RefreshClock())
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
	local categoryText = Analysis.BuildCompactBreakdown(runtime.damageByCategory, totalDamage, 4)
	if categoryText ~= "" then
		Analysis.AddViewLine(lines, "category", Analysis.TruncateText("  Sources: " .. categoryText, 100))
	end

	if #skillUsageKeys > 0 then
		Analysis.AddViewLine(lines, "header", "Skills Used")
		for skillIndex, skillName in ipairs(skillUsageKeys) do
			if skillIndex > 6 then
				Analysis.AddViewLine(lines, "metric", "  ... +" .. tostring(#skillUsageKeys - 6) .. " more skills")
				break
			end
			local entry = skillUsageSnapshot[skillName] or {}
			Analysis.AddViewLine(
				lines,
				"skill",
				string.format(
					"  %-24s %6s uses",
					Analysis.TruncateText(entry.name or skillName, 24),
					Analysis.FormatAmount(entry.count)
				)
			)
		end
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

	return true
end

Analysis.VIEW_LINE_COLORS = {
	header = { 0.95, 0.92, 0.82, 1 },
	metric = { 0.82, 0.88, 0.96, 1 },
	mana = { 0.36, 0.62, 1.0, 1 },
	session_kills = { 1.0, 0.58, 0.20, 1 },
	damage = { 1.0, 0.78, 0.22, 1 },
	exp = { 1.0, 0.55, 0.82, 1 },
	money = MONEY_LABEL_COLOR,
	items = { 0.78, 0.80, 0.84, 1 },
	time = { 0.72, 0.52, 1.0, 1 },
	damage_taken = { 1.0, 0.30, 0.28, 1 },
	category = { 0.85, 0.78, 0.65, 1 },
	skill = { 1, 1, 1, 1 },
	heal = { 0.55, 0.95, 0.75, 1 },
	target = { 0.92, 0.92, 0.92, 1 },
	unit = { 1, 1, 1, 1 },
	player_death = { 1, 0.25, 0.25, 1 },
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

function Analysis.AddViewLine(lines, kind, text, segments)
	local maxRows = tonumber(lines.maxRows) or VIEW_CONTENT_ROW_COUNT
	if maxRows > VIEW_CONTENT_ROW_COUNT then
		maxRows = VIEW_CONTENT_ROW_COUNT
	elseif maxRows < 1 then
		maxRows = 1
	end
	if #lines >= maxRows then
		if lines.overflowShown ~= true then
			lines[maxRows] = { kind = "warning", text = "  ... additional session data not shown" }
			lines.overflowShown = true
		end
		return false
	end
	lines[#lines + 1] = { kind = kind, text = text, segments = segments }
	return true
end

function Analysis.BuildViewDisplayLines()
	local lines = {}
	local now = Analysis.RefreshClock()
	local unitNames = Analysis.BuildSortedReportUnitNames()
	local lootNames = Analysis.BuildSortedSessionLootNames()
	local sessionKills = Analysis.GetSessionKillTotal()
	local totalDamageDealt = tonumber(runtime.totalDamageDealt) or 0
	local totalDamageTaken = tonumber(runtime.totalDamageTaken) or 0
	local totalExpGained = tonumber(runtime.totalExpGained) or 0
	local totalGoldEarned = tonumber(runtime.totalGoldEarned) or 0
	local totalManaSpent = tonumber(runtime.totalManaSpent) or 0
	local totalDroppedItems = tonumber(runtime.totalDroppedItems) or 0
	local sessionElapsed = Analysis.GetSessionElapsedSeconds(now)
	local totalKillTime = Analysis.GetKillCombatDuration(now)
	local killsPerMinute = Analysis.GetKillsPerMinute(now)
	local expPerMinute = Analysis.GetExpPerMinute(now)
	local averageExpPerKill = Analysis.GetAverageExpPerKill(now)
	local distanceTraveled = Analysis.GetSessionDistanceTraveled()
	local playerCombatStats = Analysis.EnsurePlayerCombatStats()
	local totalCombatDamage = Analysis.GetPlayerDamageTotal()
	local totalHealing = Analysis.GetPlayerHealTotal()
	local totalMisses = tonumber(playerCombatStats.totalMisses) or 0
	local totalHealingReceived = tonumber(playerCombatStats.totalHealingReceived) or 0
	local energizeKeys = Analysis.BuildSortedEntryKeys(runtime.energizeBySkill, "amount")

	if #unitNames == 0
		and sessionKills <= 0
		and totalDamageDealt <= 0
		and totalDamageTaken <= 0
		and totalCombatDamage <= 0
		and totalHealing <= 0
		and totalMisses <= 0
		and totalHealingReceived <= 0
		and #energizeKeys == 0
		and totalExpGained <= 0
		and totalGoldEarned <= 0
		and totalManaSpent <= 0
		and totalDroppedItems <= 0
		and distanceTraveled <= 0
	then
		Analysis.AddViewLine(lines, "unit", "  No session data recorded yet.")
		Analysis.AddViewLine(lines, "metric", "  Kill mobs or loot items, then open View again.")
		return lines
	end

	Analysis.AddViewLine(lines, "header", "Session Totals")
	Analysis.AddViewLine(
		lines,
		"session_kills",
		"  Session Kills " .. Analysis.FormatAmount(sessionKills) .. " | KPM " .. Analysis.FormatPerMinute(killsPerMinute)
	)
	Analysis.AddViewLine(lines, "time", "  Session Time " .. Analysis.FormatDuration(sessionElapsed))
	Analysis.AddViewLine(lines, "time", "  Kill Time " .. Analysis.FormatDuration(totalKillTime))
	Analysis.AddViewLine(lines, "metric", "  Distance " .. Analysis.FormatDistanceMeters(distanceTraveled))
	Analysis.AddViewLine(lines, "mana", "  Mana " .. Analysis.FormatAmount(totalManaSpent))
	Analysis.AddViewLine(
		lines,
		"exp",
		"  EXP " .. Analysis.FormatCompactAmount(totalExpGained) .. " | EXP/m " .. Analysis.FormatPerMinute(expPerMinute)
	)
	Analysis.AddViewLine(
		lines,
		"exp",
		"  AEK " .. Analysis.FormatCompactAmount(averageExpPerKill)
	)
	Analysis.AddViewLine(
		lines,
		"money",
		"  " .. Analysis.FormatMoneyCopper(totalGoldEarned),
		Analysis.BuildMoneyLineSegments(totalGoldEarned)
	)
	Analysis.AddViewLine(lines, "damage", "  Damage " .. Analysis.FormatCompactAmount(totalDamageDealt))
	Analysis.AddViewLine(lines, "damage_taken", "  Damage Taken " .. Analysis.FormatCompactAmount(totalDamageTaken))
	Analysis.AddViewLine(lines, "items", "  Items: " .. Analysis.FormatAmount(totalDroppedItems))
	lines.maxRows = VIEW_CONTENT_ROW_COUNT - Analysis.GetLootSectionReserve(lootNames)
	Analysis.AppendCombatReviewLines(lines)
	lines.maxRows = VIEW_CONTENT_ROW_COUNT
	Analysis.AppendSessionLootLines(lines, lootNames)
	return lines
end

function Analysis.HasSessionKills()
	return Analysis.GetSessionKillTotal() > 0
end

function Analysis.BuildCurrentSessionSummary()
	local now = Analysis.RefreshClock()
	local averageExpPerKill = Analysis.GetAverageExpPerKill(now)
	return "Session Kills "
		.. Analysis.FormatAmount(Analysis.GetSessionKillTotal())
		.. " | KPM "
		.. Analysis.FormatPerMinute(Analysis.GetKillsPerMinute(now))
		.. " | Session "
		.. Analysis.FormatDuration(Analysis.GetSessionElapsedSeconds(now))
		.. " | Kill Time "
		.. Analysis.FormatDuration(Analysis.GetKillCombatDuration(now))
		.. " | Damage "
		.. Analysis.FormatCompactAmount(runtime.totalDamageDealt)
		.. " | EXP "
		.. Analysis.FormatCompactAmount(runtime.totalExpGained)
		.. " ("
		.. Analysis.FormatPerMinute(Analysis.GetExpPerMinute(now))
		.. ")"
		.. " | Items: "
		.. Analysis.FormatAmount(runtime.totalDroppedItems)
		.. " | AEK "
		.. Analysis.FormatCompactAmount(averageExpPerKill)
		.. " | "
		.. Analysis.FormatMoneyCopper(runtime.totalGoldEarned)
		.. " | Distance "
		.. Analysis.FormatDistanceMeters(Analysis.GetSessionDistanceTraveled())
		.. " | Locations "
		.. Analysis.FormatAmount(#(runtime.sessionKillLocations or {}))
end

function Analysis.CopyViewLines(lines)
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

Analysis.SaveCurrentSessionToHistory = function()
	if not Analysis.HasSessionKills() then
		return false
	end

	Analysis.EnsureHistoryMergedFromDisk()
	Analysis.SyncSessionResourceSnapshots()
	local now = Analysis.RefreshClock()
	local averageExpPerKill = Analysis.GetAverageExpPerKill(now)
	local ok, lines = pcall(Analysis.BuildViewDisplayLines)
	if not ok or type(lines) ~= "table" then
		lines = {
			{ kind = "warning", text = "  Failed to build saved session details." },
			{ kind = "metric", text = "  " .. Analysis.TruncateText(tostring(lines), 90) },
		}
	end

	local sessionIndex = Analysis.ResolveNextHistorySessionIndex()
	local sessionName = "S" .. tostring(sessionIndex)
	local sessionLocation = Analysis.GetHistorySessionLocation()
	if IsValidName(sessionLocation) then
		sessionName = sessionName .. " " .. sessionLocation
	end
	local sessionDate = Analysis.GetCurrentDateText()
	if IsValidName(sessionDate) then
		sessionName = sessionName .. " " .. sessionDate
	end
	local killLocations = Analysis.CopyKillLocations(runtime.sessionKillLocations)
	runtime.nextHistorySessionIndex = sessionIndex + 1
	runtime.historySessions[#runtime.historySessions + 1] = {
		name = sessionName,
		location = sessionLocation or "",
		date = sessionDate or "",
		summary = Analysis.BuildCurrentSessionSummary(),
		killTotal = Analysis.GetSessionKillTotal(),
		createdAt = Analysis.GetPersistentTimestamp(),
		sessionElapsedSeconds = Analysis.GetSessionElapsedSeconds(now),
		killTimeSeconds = Analysis.GetKillCombatDuration(now),
		distanceTraveled = Analysis.GetSessionDistanceTraveled(),
		killsPerMinute = Analysis.GetKillsPerMinute(now),
		expPerMinute = Analysis.GetExpPerMinute(now),
		averageExpPerKill = averageExpPerKill,
		lines = Analysis.CopyViewLines(lines),
		killLocations = killLocations,
	}
	runtime.historyPage = 1
	Analysis.SaveSessionHistory()
	return true
end

function Analysis.AddHistoryLine(lines, kind, text, sessionIndex)
	lines[#lines + 1] = { kind = kind, text = text, sessionIndex = sessionIndex }
end

function Analysis.AddWrappedHistoryLine(lines, kind, text, sessionIndex, wrapChars, continuationPrefix)
	text = tostring(text or "")
	wrapChars = math.max(12, tonumber(wrapChars) or Analysis.HISTORY_TEXT_WRAP_CHARS)
	continuationPrefix = continuationPrefix or "    "
	if text == "" or string.len(text) <= wrapChars then
		Analysis.AddHistoryLine(lines, kind, text, sessionIndex)
		return 1
	end

	local count = 0
	local remaining = text
	local prefix = ""
	while remaining ~= "" do
		local available = wrapChars - string.len(prefix)
		if available < 12 then
			available = wrapChars
			prefix = ""
		end

		local chunk = remaining
		if string.len(chunk) > available then
			local breakAt = nil
			for index = available, 1, -1 do
				local character = string.sub(chunk, index, index)
				if character == " " or character == "\t" then
					breakAt = index
					break
				end
			end
			if breakAt ~= nil and breakAt > 1 then
				chunk = string.sub(remaining, 1, breakAt - 1)
				remaining = string.sub(remaining, breakAt + 1)
			else
				chunk = string.sub(remaining, 1, available)
				remaining = string.sub(remaining, available + 1)
			end
			remaining = string.gsub(remaining, "^%s+", "")
		else
			remaining = ""
		end

		Analysis.AddHistoryLine(lines, kind, prefix .. chunk, sessionIndex)
		count = count + 1
		prefix = continuationPrefix
	end
	return count
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
			local beforeCount = #lines
			Analysis.AddWrappedHistoryLine(
				lines,
				"header",
				tostring(session.name or ("S" .. tostring(sessionIndex))),
				sessionIndex,
				nil,
				"  "
			)
			-- Only the first name line shows the delete control (wrapped continuations stay plain).
			local firstHeaderLine = lines[beforeCount + 1]
			if firstHeaderLine ~= nil then
				firstHeaderLine.showSessionDelete = true
			end
			Analysis.AddWrappedHistoryLine(lines, "metric", "  " .. tostring(session.summary or ""), sessionIndex)
			if #(session.killLocations or {}) > 0 then
				Analysis.AddWrappedHistoryLine(
					lines,
					"time",
					"  Kill map: common area from " .. Analysis.FormatAmount(#session.killLocations) .. " recorded kill locations",
					sessionIndex
				)
			end

			local shown = 0
			if type(session.lines) == "table" then
				for _, line in ipairs(session.lines) do
					local text = tostring(line.text or "")
					if text ~= "" and line.kind ~= "spacer" and line.kind ~= "header" then
						Analysis.AddWrappedHistoryLine(lines, line.kind or "metric", "  " .. Trim(text), sessionIndex)
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
	if ADDON == nil or type(ADDON.GetContent) ~= "function" or UIC_WORLDMAP == nil then
		return nil
	end
	local ok, content = SafeCall(ADDON, "GetContent", UIC_WORLDMAP)
	if ok then
		return content
	end
	return nil
end

function Analysis.MarkWorldArea(mapWidget, x, y, z, radius, index)
	if mapWidget == nil then
		return false
	end
	return SafeCall(
		mapWidget,
		"ShowSkillMapEffect",
		SafeNumber(x, 0),
		SafeNumber(y, 0),
		SafeNumber(z, 0),
		SafeNumber(radius, 0),
		tonumber(index) or 1
	)
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

-- Groups nearby kill coordinates into fuzzy clusters, then returns the largest
-- cluster's center. This avoids requiring exact coordinate matches while still
-- identifying the area where kills were most frequently recorded.
function Analysis.BuildMostCommonKillLocation(points, zoneGroupFilter)
	local clusters = {}
	local tolerance = math.max(1, tonumber(Analysis.KILL_MAP_COMMON_COORD_TOLERANCE) or 54)
	local toleranceSq = tolerance * tolerance
	local requiredZoneGroup = tonumber(zoneGroupFilter)

	for _, point in ipairs(points or {}) do
		if requiredZoneGroup == nil or tonumber(point.zoneGroup) == requiredZoneGroup then
			local x, y, z = Analysis.GetKillLocationMapCoordinates(point)
			if x ~= nil and y ~= nil then
				local bestCluster = nil
				local bestDistanceSq = nil
				for _, cluster in ipairs(clusters) do
					local dx = x - cluster.x
					local dy = y - cluster.y
					local distanceSq = (dx * dx) + (dy * dy)
					if distanceSq <= toleranceSq and (bestDistanceSq == nil or distanceSq < bestDistanceSq) then
						bestCluster = cluster
						bestDistanceSq = distanceSq
					end
				end
				if bestCluster == nil then
					bestCluster = {
						count = 0,
						sumX = 0,
						sumY = 0,
						sumZ = 0,
						x = x,
						y = y,
						z = tonumber(z) or 0,
					}
					clusters[#clusters + 1] = bestCluster
				end
				bestCluster.count = bestCluster.count + 1
				bestCluster.sumX = bestCluster.sumX + x
				bestCluster.sumY = bestCluster.sumY + y
				bestCluster.sumZ = bestCluster.sumZ + (tonumber(z) or 0)
				bestCluster.x = bestCluster.sumX / bestCluster.count
				bestCluster.y = bestCluster.sumY / bestCluster.count
				bestCluster.z = bestCluster.sumZ / bestCluster.count
			end
		end
	end

	local bestCluster = nil
	for _, cluster in ipairs(clusters) do
		if bestCluster == nil
			or cluster.count > bestCluster.count
			or (cluster.count == bestCluster.count and cluster.x < bestCluster.x)
		then
			bestCluster = cluster
		end
	end
	if bestCluster == nil then
		return nil
	end
	return {
		x = bestCluster.x,
		y = bestCluster.y,
		z = bestCluster.z,
		count = bestCluster.count,
		radius = math.max(
			18,
			math.min(
				80,
				(tonumber(Analysis.KILL_MAP_COMMON_MARKER_RADIUS) or 24) + math.min(30, bestCluster.count * 2)
			)
		),
	}
end

function Analysis.GetSessionMapAnchor(session)
	local locations = Analysis.CopyKillLocations(session and session.killLocations)
	local zoneCounts = {}
	local bestZoneCount = 0
	local bestZoneGroup = nil

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
	end

	if bestZoneGroup == nil then
		return nil, locations
	end
	local commonLocation = Analysis.BuildMostCommonKillLocation(locations, bestZoneGroup)
	if commonLocation == nil then
		commonLocation = Analysis.BuildMostCommonKillLocation(locations)
	end
	if commonLocation ~= nil then
		return {
			zoneGroup = bestZoneGroup,
			x = commonLocation.x,
			y = commonLocation.y,
			z = commonLocation.z,
			count = commonLocation.count,
			radius = commonLocation.radius,
		}, locations
	end
	return {
		zoneGroup = bestZoneGroup,
		x = 0,
		y = 0,
		z = 0,
		count = 0,
	}, locations
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
	local mapWidget = Analysis.GetWorldMapContent()
	if mapWidget == nil then
		return false
	end
	local anchor = Analysis.GetSessionMapAnchor(session)
	if anchor == nil or (tonumber(anchor.count) or 0) <= 0 then
		return false
	end

	Analysis.ClearWorldMapKillEffects()
	return Analysis.MarkWorldArea(
		mapWidget,
		anchor.x,
		anchor.y,
		anchor.z,
		tonumber(anchor.radius) or Analysis.KILL_MAP_COMMON_MARKER_RADIUS,
		1
	)
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

