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

function Analysis.RecordDroppedItem(mobName, itemName, count)
	if not IsValidName(itemName) then
		return false
	end
	itemName = Trim(itemName)
	if Analysis.IsCurrencyLootItemName(itemName) then
		return false
	end
	if not IsValidName(mobName) then
		mobName = "Unknown"
	else
		mobName = Trim(mobName)
	end
	count = Analysis.NormalizeLootCount(count)
	if runtime.itemDropsByUnit[mobName] == nil then
		runtime.itemDropsByUnit[mobName] = {}
	end
	if type(runtime.sessionLootItems) ~= "table" then
		runtime.sessionLootItems = {}
	end
	if not Analysis.AddLootAmount(runtime.itemDropsByUnit[mobName], itemName, count) then
		return false
	end
	if not Analysis.AddLootAmount(runtime.sessionLootItems, itemName, count) then
		return false
	end
	runtime.totalDroppedItems = (tonumber(runtime.totalDroppedItems) or 0) + count
	Analysis.MarkSessionDataSavePending()
	if Analysis.RefreshViewWindowIfVisible ~= nil then
		Analysis.RefreshViewWindowIfVisible()
	end
	return true
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
	return LT.ReadBagItem(posInBag)
end

function Analysis.BuildBagSnapshot()
	if X2Bag == nil or type(X2Bag.GetBagItemInfo) ~= "function" then
		return nil
	end

	local snapshot = {}
	for posInBag = 1, MAX_BAG_SLOTS do
		local bagItem = Analysis.ReadBagItem(posInBag)
		local item = Analysis.ExtractLootItemFromTable(bagItem, 0)
		if item ~= nil and IsValidName(item.name) and not Analysis.IsCurrencyLootItemName(item.name) then
			local count = Analysis.NormalizeLootCount(item.count)
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
			if gained > 0 and Analysis.RecordDroppedItem(mobName, itemName, gained) then
				recorded = true
			end
		end
	end

	runtime.lastBagSnapshot = snapshot
	return recorded
end

function Analysis.ScheduleBagDropSync()
	runtime.pendingBagSyncUntil = Analysis.RefreshClock() + 3
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
	return Analysis.RecordDroppedItem(Analysis.GetRecentMobName(LOOT_ATTRIBUTION_SECONDS), item.name, item.count)
end

function Analysis.HandleLootAcquisitionEvent(...)
	local hasBagBaseline = type(runtime.lastBagSnapshot) == "table"
	local recordedFromBag = false
	local recordedFromPayload = false
	if hasBagBaseline then
		recordedFromBag = Analysis.SyncBagDrops(false)
	end
	if not recordedFromBag then
		recordedFromPayload = Analysis.RecordLootFromEventPayload(...)
	end
	if recordedFromBag or recordedFromPayload then
		runtime.pendingBagSyncUntil = nil
		Analysis.SyncBagDrops(true)
	else
		if hasBagBaseline then
			Analysis.ScheduleBagDropSync()
		else
			Analysis.SyncBagDrops(true)
		end
	end
end

function Analysis.SplitMoneyCopper(copper)
	copper = math.floor((tonumber(copper) or 0) + 0.5)
	if copper < 0 then
		copper = 0
	end
	local gold = math.floor(copper / 10000)
	copper = copper - (gold * 10000)
	local silver = math.floor(copper / 100)
	copper = copper - (silver * 100)
	return gold, silver, copper
end

function Analysis.FormatMoneyCopper(copper)
	local gold, silver, copperPart = Analysis.SplitMoneyCopper(copper)
	return "Gold " .. tostring(gold) .. "g " .. tostring(silver) .. "s " .. tostring(copperPart) .. "c"
end

function Analysis.BuildMoneyLineSegments(copper)
	local gold, silver, copperPart = Analysis.SplitMoneyCopper(copper)
	return {
		{ text = "  Gold ", color = MONEY_LABEL_COLOR },
		{ text = tostring(gold) .. "g ", color = MONEY_GOLD_COLOR },
		{ text = tostring(silver) .. "s ", color = MONEY_SILVER_COLOR },
		{ text = tostring(copperPart) .. "c", color = MONEY_COPPER_COLOR },
	}
end

local function AddMoneyPatternMatches(text, pattern, multiplier)
	local total = 0
	local matched = false
	for amountText in string.gmatch(text, pattern) do
		local amount = tonumber(amountText)
		if amount ~= nil then
			total = total + (amount * multiplier)
			matched = true
		end
	end
	return total, matched
end

local function MinPositive(...)
	local result = nil
	for index = 1, select("#", ...) do
		local rawValue = select(index, ...)
		if rawValue ~= nil then
			local value = tonumber(rawValue)
			if value ~= nil and (result == nil or value < result) then
				result = value
			end
		end
	end
	return result
end

-- Accept raw copper strings, "1g 2s 3c", and label-first text such as "Gold 1 Silver 2".
function Analysis.ParseMoneyCopper(value)
	if type(value) == "number" then
		return math.floor(value + 0.5)
	end

	local text = Trim(value)
	if text == "" then
		return nil
	end
	text = string.gsub(text, ",", "")
	local direct = tonumber(text)
	if direct ~= nil then
		return math.floor(direct + 0.5)
	end

	local lower = string.lower(text)
	local total = 0
	local matched = false
	local hasShortUnits = string.find(lower, "[%d%.]+%s*[gsc]%f[%A]") ~= nil
	if not hasShortUnits
		and (string.find(lower, "gold", 1, true) ~= nil
			or string.find(lower, "silver", 1, true) ~= nil
			or string.find(lower, "copper", 1, true) ~= nil)
	then
		local firstCurrency = MinPositive(
			string.find(lower, "gold", 1, true),
			string.find(lower, "silver", 1, true),
			string.find(lower, "copper", 1, true)
		)
		local firstNumber = string.find(lower, "%d")
		local added, ok
		if firstCurrency ~= nil and (firstNumber == nil or firstCurrency < firstNumber) then
			added, ok = AddMoneyPatternMatches(lower, "gold%D*([%d%.]+)", 10000)
			total = total + added
			matched = matched or ok
			added, ok = AddMoneyPatternMatches(lower, "silver%D*([%d%.]+)", 100)
			total = total + added
			matched = matched or ok
			added, ok = AddMoneyPatternMatches(lower, "copper%D*([%d%.]+)", 1)
			total = total + added
			matched = matched or ok
		else
			added, ok = AddMoneyPatternMatches(lower, "([%d%.]+)%s*gold", 10000)
			total = total + added
			matched = matched or ok
			added, ok = AddMoneyPatternMatches(lower, "([%d%.]+)%s*silver", 100)
			total = total + added
			matched = matched or ok
			added, ok = AddMoneyPatternMatches(lower, "([%d%.]+)%s*copper", 1)
			total = total + added
			matched = matched or ok
		end
	end
	if not matched then
		for amountText, unitText in string.gmatch(lower, "([%d%.]+)%s*([gsc])%f[%A]") do
			local amount = tonumber(amountText)
			if amount ~= nil then
				if unitText == "g" then
					total = total + (amount * 10000)
				elseif unitText == "s" then
					total = total + (amount * 100)
				else
					total = total + amount
				end
				matched = true
			end
		end
	end
	if matched then
		return math.floor(total + 0.5)
	end
	local digits = string.gsub(text, "[^%d]", "")
	if digits ~= "" then
		return tonumber(digits)
	end
	return nil
end

Analysis.MONEY_TOTAL_FIELDS = {
	"money",
	"moneyStr",
	"money_str",
	"moneyString",
	"money_string",
	"currency",
	"currencyStr",
	"currency_str",
	"amount",
	"value",
	"copper",
	"copperAmount",
	"copper_amount",
	"cooper",
}

Analysis.MONEY_GOLD_FIELDS = {
	"gold",
	"goldAmount",
	"gold_amount",
	"goldStr",
	"gold_str",
}

Analysis.MONEY_SILVER_FIELDS = {
	"silver",
	"silverAmount",
	"silver_amount",
	"silverStr",
	"silver_str",
}

Analysis.MONEY_COPPER_FIELDS = {
	"copper",
	"copperAmount",
	"copper_amount",
	"copperStr",
	"copper_str",
	"cooper",
}

function Analysis.ExtractMoneyPart(source, fields)
	for _, fieldName in ipairs(fields) do
		local value = tonumber(source[fieldName])
		if value ~= nil and value >= 0 then
			return value
		end
	end
	return nil
end

function Analysis.ExtractMoneyCopperFromTable(source, depth)
	if type(source) ~= "table" or (tonumber(depth) or 0) > 3 then
		return nil
	end

	local gold = Analysis.ExtractMoneyPart(source, Analysis.MONEY_GOLD_FIELDS)
	local silver = Analysis.ExtractMoneyPart(source, Analysis.MONEY_SILVER_FIELDS)
	local copper = Analysis.ExtractMoneyPart(source, Analysis.MONEY_COPPER_FIELDS)
	if gold ~= nil or silver ~= nil or copper ~= nil then
		return math.floor(((gold or 0) * 10000) + ((silver or 0) * 100) + (copper or 0) + 0.5)
	end

	for _, fieldName in ipairs(Analysis.MONEY_TOTAL_FIELDS) do
		local amount = Analysis.ParseMoneyCopper(source[fieldName])
		if amount ~= nil and amount > 0 then
			return amount
		end
	end

	for _, value in pairs(source) do
		if type(value) == "table" then
			local amount = Analysis.ExtractMoneyCopperFromTable(value, (tonumber(depth) or 0) + 1)
			if amount ~= nil then
				return amount
			end
		end
	end
	return nil
end

function Analysis.ExtractMoneyCopperFromEvent(...)
	local numbers = {}
	for index = 1, select("#", ...) do
		local value = select(index, ...)
		if type(value) == "table" then
			local amount = Analysis.ExtractMoneyCopperFromTable(value, 0)
			if amount ~= nil and amount > 0 then
				return amount
			end
		elseif type(value) == "string" then
			local amount = Analysis.ParseMoneyCopper(value)
			if amount ~= nil and amount > 0 then
				return amount
			end
		elseif type(value) == "number" then
			numbers[#numbers + 1] = value
		end
	end

	if #numbers == 1 and numbers[1] > 0 then
		return math.floor(numbers[1] + 0.5)
	end
	if #numbers >= 3 then
		return math.floor(((tonumber(numbers[1]) or 0) * 10000) + ((tonumber(numbers[2]) or 0) * 100) + (tonumber(numbers[3]) or 0) + 0.5)
	end
	if #numbers == 2 then
		return math.floor(((tonumber(numbers[1]) or 0) * 100) + (tonumber(numbers[2]) or 0) + 0.5)
	end
	return nil
end

function Analysis.ExtractMoneyCopperFromCombatMessage(msg)
	if type(msg) ~= "table" then
		return nil
	end
	return Analysis.ExtractMoneyCopperFromEvent(
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
end

function Analysis.RecordMoneyEarned(amount, source)
	amount = math.floor((tonumber(amount) or 0) + 0.5)
	if amount <= 0 then
		return false
	end

	local now = Analysis.RefreshClock()
	local lastAmount = tonumber(runtime.lastMoneyEarnedAmount)
	local lastTime = tonumber(runtime.lastMoneyEarnedTime)
	local lastSource = tostring(runtime.lastMoneyEarnedSource or "")
	source = tostring(source or "unknown")
	if lastAmount == amount and lastTime ~= nil and now - lastTime <= MONEY_EVENT_DEDUPE_SECONDS and source ~= lastSource then
		return false
	end

	runtime.totalGoldEarned = (tonumber(runtime.totalGoldEarned) or 0) + amount
	runtime.lastMoneyEarnedAmount = amount
	runtime.lastMoneyEarnedTime = now
	runtime.lastMoneyEarnedSource = source
	local lastMoney = tonumber(runtime.lastMoneySnapshot)
	local currentMoney = Analysis.ReadCurrentMoneyCopper()
	if lastMoney ~= nil then
		local expectedMoney = lastMoney + amount
		if currentMoney ~= nil and currentMoney > expectedMoney then
			runtime.lastMoneySnapshot = currentMoney
		else
			runtime.lastMoneySnapshot = expectedMoney
		end
	elseif currentMoney ~= nil then
		runtime.lastMoneySnapshot = currentMoney
	end
	Analysis.MarkSessionDataSavePending()
	if Analysis.RefreshViewWindowIfVisible ~= nil then
		Analysis.RefreshViewWindowIfVisible()
	end
	return true
end

function Analysis.ParseMoneyReturnValues(firstValue, secondValue, thirdValue)
	if type(firstValue) == "table" then
		local amount = Analysis.ExtractMoneyCopperFromTable(firstValue, 0)
		if amount ~= nil then
			return amount
		end
	end

	if thirdValue ~= nil then
		local gold = tonumber(firstValue)
		local silver = tonumber(secondValue)
		local copper = tonumber(thirdValue)
		if gold ~= nil and silver ~= nil and copper ~= nil and silver >= 0 and silver < 100 and copper >= 0 and copper < 100 then
			return math.floor((gold * 10000) + (silver * 100) + copper + 0.5)
		end
	end

	if secondValue ~= nil then
		local firstText = string.upper(tostring(firstValue or ""))
		if string.find(firstText, "GOLD", 1, true) ~= nil then
			local amount = Analysis.ParseMoneyCopper(secondValue)
			if amount ~= nil then
				return amount
			end
		end
	end

	return Analysis.ParseMoneyCopper(firstValue)
end

function Analysis.ReadBagCurrencyCopper()
	local ok, firstValue, secondValue, thirdValue = SafeCallValues(X2Bag, "GetCurrency")
	if not ok then
		return nil
	end
	return Analysis.ParseMoneyReturnValues(firstValue, secondValue, thirdValue)
end

function Analysis.ReadCurrentMoneyCopper()
	local bagCurrency = Analysis.ReadBagCurrencyCopper()
	if bagCurrency ~= nil then
		return bagCurrency
	end

	local ok, moneyText = SafeCall(X2Util, "GetMyMoneyString")
	if not ok and _G ~= nil and type(_G.GetMyMoneyString) == "function" then
		ok, moneyText = pcall(_G.GetMyMoneyString)
	end
	if not ok then
		return nil
	end
	return Analysis.ParseMoneyCopper(moneyText)
end

-- Track earned gold as positive balance movement only; spending resets the baseline without reducing earned total.
function Analysis.SyncMoneyEarned()
	local currentMoney = Analysis.ReadCurrentMoneyCopper()
	if currentMoney == nil then
		return false
	end

	local lastMoney = tonumber(runtime.lastMoneySnapshot)
	local recorded = false
	if lastMoney ~= nil and currentMoney > lastMoney then
		recorded = Analysis.RecordMoneyEarned(currentMoney - lastMoney, "balance")
	end
	runtime.lastMoneySnapshot = currentMoney
	return recorded
end

function Analysis.HandleMoneyAcquisitionEvent(...)
	if runtime.playerMoneyHandlerRegistered == true then
		return false
	end

	local amount = Analysis.ExtractMoneyCopperFromEvent(...)
	if amount ~= nil and Analysis.RecordMoneyEarned(amount, "loot") then
		return true
	end
	return Analysis.SyncMoneyEarned()
end

-- GrindTracker uses UIEVENT_TYPE.PLAYER_MONEY because its first argument is the
-- wallet delta in copper; count only positive movement so spending never lowers
-- the Kill Session Analysis total.
function Analysis.HandlePlayerMoneyChanged(change, changeStr)
	if runtime.active ~= true then
		return false
	end

	Analysis.RefreshClock()
	local delta = tonumber(change)
	if delta == nil and changeStr ~= nil then
		delta = Analysis.ParseMoneyCopper(changeStr)
	end
	delta = math.floor((tonumber(delta) or 0) + 0.5)
	if delta <= 0 then
		Analysis.SyncMoneyEarned()
		return false
	end

	Analysis.CaptureSessionActivityLocation()
	return Analysis.RecordMoneyEarned(delta, "player_money")
end

function Analysis.AttributeExpGain(amount)
	amount = math.floor((tonumber(amount) or 0) + 0.5)
	if amount <= 0 then
		return false
	end
	if Analysis.CountKillFromExpGain == nil then
		return false
	end
	local mobName, counted = Analysis.CountKillFromExpGain(amount)
	if counted ~= true then
		return false
	end
	runtime.totalExpGained = (tonumber(runtime.totalExpGained) or 0) + amount
	Analysis.AddAmount(runtime.expByUnit, mobName, amount)
	Analysis.MarkSessionDataSavePending()
	if Analysis.RefreshViewWindowIfVisible ~= nil then
		Analysis.RefreshViewWindowIfVisible()
	end
	return true
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
	local amount = Analysis.ExtractExpDeltaFromEvent(...)
	if amount ~= nil then
		Analysis.AttributeExpGain(amount)
	end
end

