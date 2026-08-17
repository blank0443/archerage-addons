-- Shared bag item extractors + ReadBagItem.
local LT = _G.__LOOT_TRACKER
if LT == nil or LT.C == nil then
	return
end
local C = LT.C
local Trim = LT.Trim
local NormalizeName = LT.NormalizeName

function LT.ExtractItemName(item)
	if type(item) ~= "table" then
		return nil
	end
	return item.name or item.itemName or item.item_name
end

function LT.ExtractItemGrade(item)
	if type(item) ~= "table" then
		return nil
	end
	return item.grade or item.itemGrade or item.item_grade
end

function LT.ExtractItemIconCacheKey(item)
	if type(item) ~= "table" then
		return nil
	end

	for _, fieldName in ipairs(C.ITEM_ID_FIELD_NAMES) do
		local value = item[fieldName]
		if type(value) == "string" or type(value) == "number" then
			local text = Trim(value)
			if text ~= "" then
				return text
			end
		end
	end
	return nil
end

function LT.ExtractIconPathValue(value, depth)
	if value == nil then
		return nil
	end

	if type(value) == "string" then
		local text = Trim(value)
		if text ~= "" then
			return text
		end
		return nil
	end

	if type(value) ~= "table" or (depth or 0) > 2 then
		return nil
	end

	for _, fieldName in ipairs(C.ICON_FIELD_NAMES) do
		local nested = LT.ExtractIconPathValue(value[fieldName], (depth or 0) + 1)
		if nested ~= nil then
			return nested
		end
	end

	return nil
end

function LT.ExtractItemIconPath(item)
	if type(item) ~= "table" then
		return nil
	end

	for _, fieldName in ipairs(C.ICON_FIELD_NAMES) do
		local value = item[fieldName]
		if type(value) == "string" then
			local text = Trim(value)
			if text ~= "" then
				return text
			end
		end
	end

	return LT.ExtractIconPathValue(item, 0)
end

function LT.ExtractItemCount(item)
	if type(item) ~= "table" then
		return 1
	end

	for _, fieldName in ipairs(C.COUNT_FIELD_NAMES) do
		local value = tonumber(item[fieldName])
		if value ~= nil and value > 0 then
			return value
		end
	end

	return 1
end

function LT.BuildItemKey(name, grade, iconPath)
	local normalizedName = NormalizeName(name)
	if normalizedName == "" then
		return nil
	end

	return normalizedName .. "|" .. tostring(grade or "") .. "|" .. tostring(iconPath or "")
end

function LT.ReadBagItem(posInBag)
	if X2Bag == nil or type(X2Bag.GetBagItemInfo) ~= "function" then
		return nil
	end
	local ok, item = pcall(X2Bag.GetBagItemInfo, X2Bag, C.BAG_KIND, posInBag)
	if ok then
		return item
	end
	return nil
end
