if API_TYPE == nil then
	ADDON:ImportAPI(8)
	X2Chat:DispatchChatMessage(
		CMF_SYSTEM,
		"Globals folder not found. Please install it at https://github.com/Schiz-n/ArcheRage-addons/tree/master/globals"
	)
	return
end

ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.EDITBOX)
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)

ADDON:ImportAPI(API_TYPE.CHAT.id)

local ADDON_KEY = "craftcal"
local WINDOW_POSITION_KEY = ADDON_KEY .. "_window_position"
local WINDOW_SIZE_KEY = ADDON_KEY .. "_window_size"
local LAUNCHER_POSITION_KEY = ADDON_KEY .. "_launcher_position"
local WINDOW_STATE_KEY = ADDON_KEY .. "_window_state"

local LAUNCHER_LABEL = "Craft Calculator"
local LAUNCHER_WIDTH = 124
local LAUNCHER_HEIGHT = 25
local DEFAULT_WINDOW_WIDTH = 460
local DEFAULT_WINDOW_HEIGHT = 560
local MIN_WINDOW_WIDTH = 380
local MIN_WINDOW_HEIGHT = 560
local RESIZE_HANDLE_SIZE = 18
local RESIZE_GRIP_LINE_LENGTH = 9
local RESIZE_GRIP_LINE_THICKNESS = 2
local RESIZE_GRIP_INSET = 5
local RESIZE_GRIP_ALPHA = 0.45
local RESIZE_GRIP_HOVER_ALPHA = 0.8
local PADDING = 10
local TITLE_HEIGHT = 24
local SEARCH_TOP = 42
local SEARCH_HEIGHT = 30
local STATUS_TOP = 78
local RESULT_TOP = 104
local RESULT_ROW_HEIGHT = 36
local RESULT_ROW_GAP = 4
local RESULT_VISIBLE_COUNT = 10
-- Probe area (dead code) removed in 2026 cleanup - reclaimed vertical space for more results
local REQUIREMENTS_WINDOW_POSITION_KEY = ADDON_KEY .. "_requirements_window_position"
local REQUIREMENTS_WINDOW_WIDTH = 560
local REQUIREMENTS_WINDOW_HEIGHT = 500
local REQUIREMENTS_QUANTITY_TOP = 82
local REQUIREMENTS_QUANTITY_HEIGHT = 28
local REQUIREMENTS_QUANTITY_LABEL_WIDTH = 70
local REQUIREMENTS_QUANTITY_BOX_WIDTH = 84
local REQUIREMENTS_COST_SUMMARY_TOP = 124
local REQUIREMENTS_ROW_TOP = 154
local REQUIREMENTS_ROW_HEIGHT = 24
local REQUIREMENTS_ICON_SIZE = 22
local COST_BOX_WIDTH = 30
local COST_BOX_HEIGHT = 18
local COST_BOX_GAP = 4
local COST_BOX_START_X = 306
local REQUIREMENTS_VISIBLE_COUNT = 14
local REQ_HEADER_HEIGHT = 58  -- space reserved for output item header area
local GOLD_COLOR = { 1, 0.78, 0.22, 1 }
local SILVER_COLOR = { 0.82, 0.9, 1, 1 }
local COPPER_COLOR = { 1, 0.5, 0.22, 1 }
local MAX_RESULTS = 80
local SEARCH_POLL_INTERVAL = 0.12
local SEARCH_MIN_LENGTH = 2

local runtime = {
	results = {},
	resultRows = {},
	requirementRows = {},
	resizeHandles = {},
	launcherButton = nil,
	closeButton = nil,
	requirementsWindow = nil,
	requirementsTitle = nil,
	requirementsStatus = nil,
	windowWidth = DEFAULT_WINDOW_WIDTH,
	windowHeight = DEFAULT_WINDOW_HEIGHT,
	selectedRecipeId = nil,
	selectedName = nil,
	searchText = "",
	lastObservedSearchText = "",
	searchPollElapsed = 0,
	searchTextEventSuppressed = false,
	searchCharHandlerActive = false,
	selectedRecipe = nil,
	targetQuantity = nil,
	quantityText = "",
	quantityTextEventSuppressed = false,
	searchAllSelected = false,
	searchNativeChanged = false,
	materialCosts = {},
	costTextEventSuppressed = false,
}
_G.__CRAFTCAL_RUNTIME = runtime

local previousRuntime = _G.__CRAFTCAL_PREVIOUS_RUNTIME
if previousRuntime ~= nil then
	if previousRuntime.window ~= nil then
		previousRuntime.window:Show(false)
	end
	if previousRuntime.launcherButton ~= nil then
		previousRuntime.launcherButton:Show(false)
	end
	if previousRuntime.requirementsWindow ~= nil then
		previousRuntime.requirementsWindow:Show(false)
	end
end
_G.__CRAFTCAL_PREVIOUS_RUNTIME = runtime

local function SafeCall(target, methodName, ...)
	if target == nil or type(target[methodName]) ~= "function" then
		return nil
	end
	return target[methodName](target, ...)
end

local function SafeMethod(target, methodName, ...)
	if target == nil then
		return false
	end
	local fn = target[methodName]
	if type(fn) ~= "function" then
		return false
	end
	return pcall(fn, target, ...)
end

local function SaveData(key, value)
	ADDON:ClearData(key)
	ADDON:SaveData(key, value)
end

local function OneLineText(value)
	local text = tostring(value or "")
	text = string.gsub(text, "[\r\n\t]", " ")
	text = string.gsub(text, "%s+", " ")
	return text
end

local function ShortText(value, limit)
	local text = OneLineText(value)
	limit = limit or 180
	if string.len(text) > limit then
		return string.sub(text, 1, limit - 3) .. "..."
	end
	return text
end

local function GetWidgetPosition(widget)
	if widget == nil or type(widget.GetOffset) ~= "function" then
		return nil, nil
	end
	local x, y = widget:GetOffset()
	local uiScale = 1
	if UIParent ~= nil and type(UIParent.GetUIScale) == "function" then
		uiScale = UIParent:GetUIScale() or 1
	end
	return (tonumber(x) or 0) * uiScale, (tonumber(y) or 0) * uiScale
end

local function SaveWidgetPosition(widget, key)
	local x, y = GetWidgetPosition(widget)
	if x ~= nil and y ~= nil then
		SaveData(key, { x = x, y = y })
	end
end

local function LoadPosition(key, fallbackX, fallbackY)
	local saved = ADDON:LoadData(key)
	if type(saved) == "table" then
		local x = tonumber(saved.x)
		local y = tonumber(saved.y)
		if x ~= nil and y ~= nil then
			return x, y
		end
	end
	return fallbackX, fallbackY
end

local function ClampWindowSize(width, height)
	width = tonumber(width) or DEFAULT_WINDOW_WIDTH
	height = tonumber(height) or DEFAULT_WINDOW_HEIGHT
	if width < MIN_WINDOW_WIDTH then
		width = MIN_WINDOW_WIDTH
	end
	if height < MIN_WINDOW_HEIGHT then
		height = MIN_WINDOW_HEIGHT
	end
	return width, height
end

local function LoadSize()
	local saved = ADDON:LoadData(WINDOW_SIZE_KEY)
	if type(saved) == "table" then
		return ClampWindowSize(saved.width, saved.height)
	end
	return DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT
end

local function SaveWidgetSize(widget)
	if widget ~= nil then
		SaveData(WINDOW_SIZE_KEY, { width = widget:GetWidth(), height = widget:GetHeight() })
	end
end

local function SaveWindowOpenState(isOpen)
	SaveData(WINDOW_STATE_KEY, { open = isOpen == true })
end

local function LoadWindowOpenState()
	local saved = ADDON:LoadData(WINDOW_STATE_KEY)
	if type(saved) == "table" and saved.open == true then
		return true
	end
	return false
end

local function AnchorWidget(widget, point, parent, x, y)
	if widget == nil then
		return
	end
	widget:RemoveAllAnchors()
	widget:AddAnchor(point, parent, x, y)
end

local function SetLabelStyle(label, align, size, r, g, b, a)
	if label == nil or label.style == nil then
		return
	end
	label.style:SetAlign(align)
	label.style:SetFontSize(size)
	label.style:SetColor(r, g, b, a)
	label.style:SetOutline(true)
end

local function HideIconDrawable(iconDrawable)
	if iconDrawable == nil then
		return
	end
	SafeMethod(iconDrawable, "SetVisible", false)
	SafeMethod(iconDrawable, "Show", false)
end

local function SetIconDrawable(iconDrawable, iconPath)
	if iconDrawable == nil then
		return
	end

	local nextIconPath = OneLineText(iconPath)
	if nextIconPath == "" then
		iconDrawable.currentIconPath = nil
		HideIconDrawable(iconDrawable)
		return
	end

	if iconDrawable.currentIconPath ~= nextIconPath then
		SafeMethod(iconDrawable, "ClearAllTextures")
		local ok = SafeMethod(iconDrawable, "AddTexture", nextIconPath)
		if not ok then
			iconDrawable.currentIconPath = nil
			HideIconDrawable(iconDrawable)
			return
		end
		iconDrawable.currentIconPath = nextIconPath
	end

	if not SafeMethod(iconDrawable, "SetVisible", true) then
		SafeMethod(iconDrawable, "Show", true)
	end
end

local folioData = CRAFTCAL_FOLIO_DATA or { recipes = {} }

local function NormalizeSearchText(value)
	local text = string.lower(OneLineText(value or ""))
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	return text
end

local function RawRecipeName(recipe)
	if type(recipe) ~= "table" then
		return ""
	end
	return OneLineText(recipe.name or recipe.itemName or "")
end

local function RecipeName(recipe)
	return RawRecipeName(recipe)
end

local cachedRecipes = nil

local function AddRecipeToList(list, seen, recipe)
	local name = RawRecipeName(recipe)
	if name == "" then
		return
	end

	local nameKey = "name:" .. NormalizeSearchText(name)
	local idKey = nil
	if recipe.id ~= nil then
		idKey = "id:" .. tostring(recipe.id)
	end
	if seen[nameKey] or (idKey ~= nil and seen[idKey]) then
		return
	end

	list[#list + 1] = recipe
	seen[nameKey] = true
	if idKey ~= nil then
		seen[idKey] = true
	end
end

local function GetRecipeList()
	if cachedRecipes ~= nil then
		return cachedRecipes
	end

	local recipes = {}
	local seen = {}
	if type(folioData) == "table" and type(folioData.recipes) == "table" then
		for _, recipe in ipairs(folioData.recipes) do
			AddRecipeToList(recipes, seen, recipe)
		end
	end
	if type(CRAFTCAL_FOLIO_INDEX) == "table" then
		for _, recipe in ipairs(CRAFTCAL_FOLIO_INDEX) do
			AddRecipeToList(recipes, seen, recipe)
		end
	end
	cachedRecipes = recipes
	return cachedRecipes
end

local function RecipeOutputQuantity(recipe)
	if type(recipe) ~= "table" then
		return 1
	end
	local value = tonumber(recipe.outputQuantity or recipe.quantity or 1)
	if value == nil or value <= 0 then
		return 1
	end
	return value
end

local function FormatQuantity(value)
	local numberValue = tonumber(value)
	if numberValue == nil then
		return tostring(value or "")
	end
	local rounded = math.floor(numberValue + 0.0001)
	if math.abs(numberValue - rounded) < 0.0001 then
		return tostring(rounded)
	end
	return string.format("%.2f", numberValue)
end

local function RecipeOutputText(recipe)
	local name = RecipeName(recipe)
	local quantity = RecipeOutputQuantity(recipe)
	if quantity > 1 then
		return name .. " x" .. FormatQuantity(quantity)
	end
	return name
end

local function RecipeHasMaterialData(recipe)
	return type(recipe) == "table" and type(recipe.materials) == "table" and #recipe.materials > 0
end

local function RecipeCanCalculate(recipe)
	return type(recipe) == "table" and recipe.craftable ~= false and RecipeHasMaterialData(recipe)
end

local function RecipeUnavailableReason(recipe)
	if type(recipe) ~= "table" then
		return "No recipe selected"
	end
	if recipe.craftable == false then
		return "No craft materials listed"
	end
	if not RecipeHasMaterialData(recipe) then
		return "No bundled recipe data"
	end
	return nil
end

local function DefaultTargetQuantity(recipe)
	return RecipeOutputQuantity(recipe)
end

local function ParseQuantityText(text)
	local value = tonumber(OneLineText(text))
	if value == nil then
		return nil
	end
	if value <= 0 or math.floor(value) ~= value then
		return nil
	end
	return value
end

local function ValidateTargetQuantity(recipe, text)
	if type(recipe) ~= "table" then
		return false, nil, "No recipe selected."
	end

	local quantity = ParseQuantityText(text)
	if quantity == nil then
		return false, nil, "Enter a positive whole number."
	end

	local outputQuantity = RecipeOutputQuantity(recipe)
	if outputQuantity > 1 and quantity % outputQuantity ~= 0 then
		return false,
			nil,
			RecipeName(recipe)
				.. " is crafted in batches of "
				.. FormatQuantity(outputQuantity)
				.. ". Use "
				.. FormatQuantity(outputQuantity)
				.. ", "
				.. FormatQuantity(outputQuantity * 2)
				.. ", "
				.. FormatQuantity(outputQuantity * 3)
				.. "..."
	end

	return true, quantity, ""
end

local function ActiveCraftMultiplier(recipe)
	if type(recipe) ~= "table" then
		return 1
	end
	local outputQuantity = RecipeOutputQuantity(recipe)
	local targetQuantity = runtime.targetQuantity or outputQuantity
	return targetQuantity / outputQuantity
end

local function FindRecipeIconPath(name)
	local needle = NormalizeSearchText(name)
	if needle == "" then
		return nil
	end
	for _, recipe in ipairs(GetRecipeList()) do
		if NormalizeSearchText(RecipeName(recipe)) == needle and recipe.iconPath ~= nil then
			return recipe.iconPath
		end
	end
	return nil
end

local function MaterialIconPath(material)
	if type(material) ~= "table" then
		return nil
	end
	return material.iconPath or FindRecipeIconPath(material.name)
end

local function RecipeMatchesQuery(recipe, queryLower)
	local nameLower = NormalizeSearchText(RecipeName(recipe))
	if nameLower ~= "" and string.find(nameLower, queryLower, 1, true) ~= nil then
		return true
	end
	if type(recipe) == "table" and type(recipe.aliases) == "table" then
		for _, alias in ipairs(recipe.aliases) do
			if string.find(NormalizeSearchText(alias), queryLower, 1, true) ~= nil then
				return true
			end
		end
	end
	return false
end

local function BuildRecipeDetail(recipe)
	local parts = {}
	if type(recipe) == "table" then
		local unavailableReason = RecipeUnavailableReason(recipe)
		if unavailableReason ~= nil then
			parts[#parts + 1] = unavailableReason
		end
		if recipe.workbench ~= nil and recipe.workbench ~= "" then
			parts[#parts + 1] = "Workbench: " .. OneLineText(recipe.workbench)
		end
		if recipe.vocation ~= nil and recipe.vocation ~= "" then
			parts[#parts + 1] = "Vocation: " .. OneLineText(recipe.vocation)
		end
		if recipe.id ~= nil then
			parts[#parts + 1] = "Recipe " .. tostring(recipe.id)
		end
	end
	if #parts == 0 then
		return "Folio recipe"
	end
	return table.concat(parts, " | ")
end

local function RefreshResults()
	for index, row in ipairs(runtime.resultRows) do
		local result = runtime.results[index]
		if result == nil then
			row.itemData = nil
			row:SetText("")
			row.nameLabel:SetText("")
			row.detailLabel:SetText("")
			row:Show(false)
		else
			row.itemData = result
			row:SetText("")
			row.nameLabel:SetText(ShortText(RecipeOutputText(result), 54))
			row.detailLabel:SetText(ShortText(BuildRecipeDetail(result), 72))
			if RecipeCanCalculate(result) then
				SetLabelStyle(row.nameLabel, ALIGN_LEFT, 11, 0.98, 0.98, 0.98, 1)
				SetLabelStyle(row.detailLabel, ALIGN_LEFT, 9, 0.74, 0.76, 0.74, 1)
			else
				SetLabelStyle(row.nameLabel, ALIGN_LEFT, 11, 1, 0.58, 0.18, 1)
				SetLabelStyle(row.detailLabel, ALIGN_LEFT, 9, 1, 0.68, 0.28, 1)
			end
			row:Show(true)
		end
	end
end

local function SetStatus(text)
	if runtime.statusLabel ~= nil then
		runtime.statusLabel:SetText(ShortText(text or "", 80))
	end
end

local function SetSelectedResult(result)
	runtime.selectedRecipeId = result and result.id or nil
	runtime.selectedName = result and RecipeName(result) or nil
	runtime.selectedRecipe = result
	if runtime.selectedLabel ~= nil then
		if result == nil then
			runtime.selectedLabel:SetText("Selected: none")
		else
			runtime.selectedLabel:SetText("Selected: " .. ShortText(RecipeName(result), 46))
		end
	end
end

local function AddResult(recipe)
	if #runtime.results >= MAX_RESULTS then
		return
	end

	if RecipeName(recipe) == "" then
		return
	end
	runtime.results[#runtime.results + 1] = recipe
end

local function StartScan(query)
	runtime.searchText = tostring(query or "")
	runtime.results = {}
	SetSelectedResult(nil)

	local queryLower = NormalizeSearchText(runtime.searchText)
	if string.len(queryLower) < SEARCH_MIN_LENGTH then
		SetStatus("Type at least " .. tostring(SEARCH_MIN_LENGTH) .. " characters to search the crafting folio")
		RefreshResults()
		return
	end

	local recipes = GetRecipeList()
	for _, recipe in ipairs(recipes) do
		if RecipeMatchesQuery(recipe, queryLower) then
			AddResult(recipe)
		end
	end

	if #recipes == 0 then
		SetStatus("No bundled Folio recipe data was loaded")
	elseif #runtime.results == 0 then
		SetStatus("No Folio recipe found for \"" .. ShortText(runtime.searchText, 32) .. "\"")
	else
		local total = #runtime.results
		local shown = math.min(total, RESULT_VISIBLE_COUNT)
		local base = tostring(total) .. " recipe(s) found"
		if total > shown then
			SetStatus(base .. "  •  showing " .. shown)
		else
			SetStatus(base)
		end
	end
	RefreshResults()
end

local function FindRecipeByName(name)
	local needle = NormalizeSearchText(name)
	if needle == "" then
		return nil
	end
	for _, recipe in ipairs(GetRecipeList()) do
		if NormalizeSearchText(RecipeName(recipe)) == needle then
			return recipe
		end
	end
	return nil
end

local function AddBaseMaterial(totals, order, materialName, quantity, iconPath, depth)
	local name = OneLineText(materialName)
	if name == "" then
		return
	end
	local count = tonumber(quantity) or 1
	local recipe = nil
	if depth < 8 then
		recipe = FindRecipeByName(name)
	end

	if recipe ~= nil and type(recipe.materials) == "table" and #recipe.materials > 0 then
		local crafted = RecipeOutputQuantity(recipe)
		local multiplier = count / crafted
		for _, material in ipairs(recipe.materials) do
			AddBaseMaterial(
				totals,
				order,
				material.name,
				(tonumber(material.quantity) or 1) * multiplier,
				MaterialIconPath(material),
				depth + 1
			)
		end
		return
	end

	local key = NormalizeSearchText(name)
	if totals[key] == nil then
		totals[key] = { name = name, quantity = 0, iconPath = iconPath or FindRecipeIconPath(name) }
		order[#order + 1] = key
	elseif totals[key].iconPath == nil and iconPath ~= nil then
		totals[key].iconPath = iconPath
	end
	totals[key].quantity = totals[key].quantity + count
end

local function AddRecipeMaterialRows(rows, recipe, craftMultiplier)
	if type(recipe.materials) ~= "table" or #recipe.materials == 0 then
		return
	end
	craftMultiplier = tonumber(craftMultiplier) or 1
	for _, material in ipairs(recipe.materials) do
		if type(material) == "table" and material.name ~= nil then
			local quantity = (tonumber(material.quantity) or 1) * craftMultiplier
			rows[#rows + 1] = {
				type = "material",
				section = "direct",
				name = OneLineText(material.name),
				requiredQuantity = quantity,
				quantity = "x" .. FormatQuantity(quantity),
				costKey = "direct:" .. NormalizeSearchText(material.name),
				iconPath = MaterialIconPath(material),
			}
		end
	end
end

local function BuildBaseMaterialRows(recipe, craftMultiplier)
	local totals = {}
	local order = {}
	if type(recipe.materials) ~= "table" then
		return {}
	end
	craftMultiplier = tonumber(craftMultiplier) or 1
	for _, material in ipairs(recipe.materials) do
		if type(material) == "table" then
			AddBaseMaterial(
				totals,
				order,
				material.name,
				(tonumber(material.quantity) or 1) * craftMultiplier,
				MaterialIconPath(material),
				0
			)
		end
	end

	local rows = {}
	for _, key in ipairs(order) do
		local material = totals[key]
		rows[#rows + 1] = {
			type = "material",
			section = "base",
			name = material.name,
			requiredQuantity = material.quantity,
			quantity = "x" .. FormatQuantity(material.quantity),
			costKey = "base:" .. NormalizeSearchText(material.name),
			iconPath = material.iconPath,
		}
	end
	return rows
end

local function BuildRecipeRequirementRows(recipe)
	if type(recipe) ~= "table" then
		return {}, "No recipe selected."
	end

	local rows = {}
	local craftMultiplier = ActiveCraftMultiplier(recipe)

	-- Header info is now handled separately in the window header.
	-- We still keep a compact line for workbench if desired.
	if recipe.workbench ~= nil and recipe.workbench ~= "" then
		rows[#rows + 1] = { type = "info", text = "Workbench: " .. OneLineText(recipe.workbench) }
	end

	if type(recipe.materials) ~= "table" or #recipe.materials == 0 then
		return rows, "No material data bundled for this Folio recipe yet."
	end

	-- Section: Direct materials
	rows[#rows + 1] = { type = "header", text = "Direct Materials" }
	AddRecipeMaterialRows(rows, recipe, craftMultiplier)

	-- Section: Base materials (raw resources)
	local baseRows = BuildBaseMaterialRows(recipe, craftMultiplier)
	if #baseRows > 0 then
		rows[#rows + 1] = { type = "header", text = "Base Materials (Raw)" }
		for _, row in ipairs(baseRows) do
			rows[#rows + 1] = row
		end
	end

	return rows, "Bundled Folio recipe data"
end

local searchGetterCandidates = {
	{ name = "GetText" },
	{ name = "GetDisplayText" },
	{ name = "GetInputText" },
	{ name = "GetString" },
	{ name = "GetEditText" },
	{ name = "GetValue", arg = "text" },
}

local function ReadEditBoxText(editBox, fallbackText)
	if editBox == nil then
		return fallbackText or ""
	end

	for _, candidate in ipairs(searchGetterCandidates) do
		local fn = editBox[candidate.name]
		if type(fn) == "function" then
			local ok, text = pcall(function()
				if candidate.arg ~= nil then
					return fn(editBox, candidate.arg)
				end
				return fn(editBox)
			end)
			if ok and type(text) == "string" then
				return text
			end
		end
	end
	return fallbackText or ""
end

local function ReadSearchBoxText()
	return ReadEditBoxText(runtime.searchBox, runtime.searchText)
end

local function SyncEditBoxText(editBox, text)
	if editBox == nil then
		return
	end
	SafeCall(editBox, "SetText", text)
	SafeCall(editBox, "SetInputText", text)
	SafeCall(editBox, "SetEditText", text)
	SafeCall(editBox, "SetDisplayText", text)
	SafeCall(editBox, "SetString", text)
end

local function SyncSearchBoxText(text)
	runtime.searchTextEventSuppressed = true
	SyncEditBoxText(runtime.searchBox, text)
	runtime.searchTextEventSuppressed = false
end

local function ApplySearchText(text, syncSearchBox)
	text = tostring(text or "")
	if text == runtime.searchText then
		return
	end
	runtime.searchAllSelected = false
	runtime.lastObservedSearchText = text
	if syncSearchBox then
		SyncSearchBoxText(text)
	end
	StartScan(text)
end

local function PollSearchBox()
	local text = ReadSearchBoxText()
	if text ~= runtime.lastObservedSearchText then
		ApplySearchText(text, false)
	end
end

local function FirstInputArg(...)
	for index = 1, select("#", ...) do
		local value = select(index, ...)
		if type(value) == "string" or type(value) == "number" then
			return value
		end
	end
	return nil
end

local function NormalizeKeyToken(value)
	if value == nil then
		return nil
	end
	local token = string.lower(tostring(value))
	token = string.gsub(token, "%s+", "")
	token = string.gsub(token, "_", "")
	token = string.gsub(token, "-", "")
	token = string.gsub(token, "%+", "")
	return token
end

local function ArgsContainControlKey(...)
	for index = 1, select("#", ...) do
		local token = NormalizeKeyToken(select(index, ...))
		if token == "ctrl"
			or token == "control"
			or token == "lctrl"
			or token == "rctrl"
			or token == "leftctrl"
			or token == "rightctrl"
			or token == "17" then
			return true
		end
	end
	return false
end

local function ArgsContainAKey(...)
	for index = 1, select("#", ...) do
		local token = NormalizeKeyToken(select(index, ...))
		if token == "a" or token == "65" then
			return true
		end
	end
	return false
end

local function IsSelectAllShortcut(...)
	for index = 1, select("#", ...) do
		local token = NormalizeKeyToken(select(index, ...))
		if token == "ctrla" or token == "controla" or token == "ctrl65" or token == "control65" then
			return true
		end
	end
	return ArgsContainControlKey(...) and ArgsContainAKey(...)
end

local function IsBackspaceOrDeleteKey(value)
	local token = NormalizeKeyToken(value)
	return token == "backspace"
		or token == "back"
		or token == "8"
		or token == "delete"
		or token == "del"
		or token == "46"
end

local function SearchCharacterFromKey(value)
	if type(value) == "number" then
		if value >= 48 and value <= 57 then
			return string.char(value)
		end
		if value >= 65 and value <= 90 then
			return string.lower(string.char(value))
		end
		if value >= 96 and value <= 105 then
			return tostring(value - 96)
		end
		if value == 32 then
			return " "
		end
		return nil
	end
	if type(value) ~= "string" or value == "" then
		return nil
	end
	if string.len(value) == 1 then
		return value
	end
	local token = NormalizeKeyToken(value)
	if token == "space" then
		return " "
	end
	if string.len(token) == 1 and string.match(token, "[%w%p]") then
		return token
	end
	return nil
end

local function DropLastCharacter(text)
	local len = string.len(text or "")
	if len <= 1 then
		return ""
	end
	return string.sub(text, 1, len - 1)
end

local function AppendSearchText(text)
	local value = tostring(text or "")
	if value == "" then
		return
	end
	if runtime.searchAllSelected then
		ApplySearchText(value, true)
	else
		ApplySearchText(runtime.searchText .. value, true)
	end
end

local function HandleSearchKey(...)
	local key = FirstInputArg(...)
	local token = NormalizeKeyToken(key)
	if IsSelectAllShortcut(...) then
		runtime.searchAllSelected = true
		SafeCall(runtime.searchBox, "SelectAll")
		return
	end

	if IsBackspaceOrDeleteKey(key) then
		if runtime.searchNativeChanged then
			runtime.searchNativeChanged = false
			runtime.searchAllSelected = false
			PollSearchBox()
			return
		end

		local actualText = ReadSearchBoxText()
		if runtime.searchAllSelected then
			ApplySearchText("", true)
		elseif actualText ~= runtime.searchText then
			ApplySearchText(actualText, false)
		else
			ApplySearchText(DropLastCharacter(runtime.searchText), true)
		end
	elseif runtime.searchNativeChanged then
		runtime.searchNativeChanged = false
		runtime.searchAllSelected = false
	elseif token == "escape" or token == "esc" or token == "27" then
		ApplySearchText("", true)
	elseif not runtime.searchCharHandlerActive then
		local character = SearchCharacterFromKey(key)
		if character ~= nil then
			AppendSearchText(character)
		else
			PollSearchBox()
		end
	else
		PollSearchBox()
	end
end

local function HandleSearchChar(...)
	local text = FirstInputArg(...)
	if text == nil then
		return
	end
	runtime.searchCharHandlerActive = true
	AppendSearchText(text)
end

local function OnSearchChanged(...)
	if runtime.searchTextEventSuppressed then
		return
	end
	local text = FirstInputArg(...)
	if type(text) == "string" then
		runtime.searchNativeChanged = true
		ApplySearchText(text, false)
	else
		PollSearchBox()
	end
end

local function AttachSearchHandlers(searchBox)
	searchBox:SetHandler("OnTextChanged", OnSearchChanged)
	searchBox:SetHandler("OnTextChange", OnSearchChanged)
	SafeCall(searchBox, "SetHandler", "OnEditTextChanged", OnSearchChanged)
	SafeCall(searchBox, "SetHandler", "OnChanged", OnSearchChanged)
	SafeCall(searchBox, "SetHandler", "OnChar", HandleSearchChar)
	SafeCall(searchBox, "SetHandler", "OnTextInput", HandleSearchChar)
	SafeCall(searchBox, "SetHandler", "OnInput", HandleSearchChar)
	SafeCall(searchBox, "SetHandler", "OnKeyUp", HandleSearchKey)
end

local function StartWindowDrag()
	if runtime.window ~= nil then
		runtime.window:StartMoving()
	end
end

local function StopWindowDrag()
	if runtime.window ~= nil then
		runtime.window:StopMovingOrSizing()
		SaveWidgetPosition(runtime.window, WINDOW_POSITION_KEY)
	end
end

local function SetResizeGripAlpha(handle, alpha)
	if handle == nil then
		return
	end
	if handle.resizeGripA ~= nil then
		handle.resizeGripA:SetColor(1, 1, 1, alpha)
	end
	if handle.resizeGripB ~= nil then
		handle.resizeGripB:SetColor(1, 1, 1, alpha)
	end
end

local function LayoutResizeGrip(handle)
	if handle == nil then
		return
	end

	local horizontalX = RESIZE_GRIP_INSET
	local verticalX = RESIZE_GRIP_INSET
	local horizontalY = RESIZE_GRIP_INSET
	local verticalY = RESIZE_GRIP_INSET
	if not handle.resizeFromLeft then
		horizontalX = RESIZE_HANDLE_SIZE - RESIZE_GRIP_INSET - RESIZE_GRIP_LINE_LENGTH
		verticalX = RESIZE_HANDLE_SIZE - RESIZE_GRIP_INSET - RESIZE_GRIP_LINE_THICKNESS
	end
	if not handle.resizeFromTop then
		horizontalY = RESIZE_HANDLE_SIZE - RESIZE_GRIP_INSET - RESIZE_GRIP_LINE_THICKNESS
		verticalY = RESIZE_HANDLE_SIZE - RESIZE_GRIP_INSET - RESIZE_GRIP_LINE_LENGTH
	end

	if handle.resizeGripA ~= nil then
		handle.resizeGripA:RemoveAllAnchors()
		handle.resizeGripA:SetExtent(RESIZE_GRIP_LINE_LENGTH, RESIZE_GRIP_LINE_THICKNESS)
		handle.resizeGripA:AddAnchor("TOPLEFT", handle, horizontalX, horizontalY)
	end
	if handle.resizeGripB ~= nil then
		handle.resizeGripB:RemoveAllAnchors()
		handle.resizeGripB:SetExtent(RESIZE_GRIP_LINE_THICKNESS, RESIZE_GRIP_LINE_LENGTH)
		handle.resizeGripB:AddAnchor("TOPLEFT", handle, verticalX, verticalY)
	end
end

local function PositionResizeHandles()
	if runtime.window == nil then
		return
	end
	for _, handle in ipairs(runtime.resizeHandles or {}) do
		if handle ~= nil and not handle.isResizing then
			handle:RemoveAllAnchors()
			handle:AddAnchor(handle.resizeAnchor, runtime.window, 0, 0)
			LayoutResizeGrip(handle)
			SafeCall(handle, "Raise")
		end
	end
end

local function LayoutWindow()
	local window = runtime.window
	if window == nil then
		return
	end

	local width, height = ClampWindowSize(runtime.windowWidth, runtime.windowHeight)
	runtime.windowWidth = width
	runtime.windowHeight = height
	window:SetExtent(width, height)

	local contentWidth = width - (PADDING * 2)
	if runtime.title ~= nil then
		runtime.title:SetExtent(contentWidth - 34, TITLE_HEIGHT)
	end
	if runtime.closeButton ~= nil then
		runtime.closeButton:SetExtent(26, 22)
	end
	if runtime.searchBorder ~= nil then
		runtime.searchBorder:SetExtent(contentWidth, SEARCH_HEIGHT)
	end
	if runtime.searchBackground ~= nil then
		runtime.searchBackground:SetExtent(contentWidth - 4, SEARCH_HEIGHT - 4)
	end
	if runtime.searchBox ~= nil then
		runtime.searchBox:SetExtent(contentWidth - 8, SEARCH_HEIGHT - 6)
	end
	if runtime.statusLabel ~= nil then
		runtime.statusLabel:SetExtent(contentWidth, 20)
	end
	if runtime.selectedLabel ~= nil then
		runtime.selectedLabel:SetExtent(contentWidth, 20)
	end

	for _, row in ipairs(runtime.resultRows or {}) do
		row:SetExtent(contentWidth, RESULT_ROW_HEIGHT)
		if row.nameLabel ~= nil then
			row.nameLabel:SetExtent(contentWidth - 10, 18)
		end
		if row.detailLabel ~= nil then
			row.detailLabel:SetExtent(contentWidth - 10, 14)
		end
	end
	PositionResizeHandles()
end

local function SaveWindowGeometry(widget)
	SaveWidgetPosition(widget, WINDOW_POSITION_KEY)
	SaveWidgetSize(widget)
end

local function ShowLauncherButton(visible)
	if runtime.launcherButton ~= nil then
		runtime.launcherButton:Show(visible == true)
	end
end

local function ShowCraftWindow(visible)
	if runtime.window ~= nil then
		runtime.window:Show(visible == true)
	end
	for _, handle in ipairs(runtime.resizeHandles or {}) do
		if handle ~= nil then
			handle:Show(visible == true)
		end
	end
end

local function RestoreCraftWindow()
	ShowCraftWindow(true)
	ShowLauncherButton(false)
	SaveWindowOpenState(true)
end

local function CollapseCraftWindow()
	if runtime.window ~= nil then
		runtime.window:StopMovingOrSizing()
		SaveWindowGeometry(runtime.window)
	end
	if runtime.requirementsWindow ~= nil then
		runtime.requirementsWindow:Show(false)
	end
	ShowCraftWindow(false)
	ShowLauncherButton(true)
	SaveWindowOpenState(false)
end

local function ApplyWindowGeometry(x, y, width, height, save)
	if runtime.window == nil then
		return
	end

	width, height = ClampWindowSize(width, height)
	runtime.windowWidth = width
	runtime.windowHeight = height
	runtime.window:RemoveAllAnchors()
	runtime.window:AddAnchor("TOPLEFT", "UIParent", x, y)
	LayoutWindow()
	if save then
		SaveWindowGeometry(runtime.window)
	end
end

local function ClampResizeGeometry(data, newX, newY, newWidth, newHeight)
	newWidth, newHeight = ClampWindowSize(newWidth, newHeight)
	if data.resizeFromLeft and newWidth == MIN_WINDOW_WIDTH then
		newX = data.startX + data.startWidth - newWidth
	end
	if data.resizeFromTop and newHeight == MIN_WINDOW_HEIGHT then
		newY = data.startY + data.startHeight - newHeight
	end
	return newX, newY, newWidth, newHeight
end

local function ComputeResizeGeometry(handle)
	local data = handle and handle.resizeDrag or nil
	if data == nil then
		return nil
	end

	local handleX, handleY = GetWidgetPosition(handle)
	if handleX == nil or handleY == nil then
		return nil
	end

	local deltaX = handleX - data.handleStartX
	local deltaY = handleY - data.handleStartY
	local newX = data.startX
	local newY = data.startY
	local newWidth = data.startWidth
	local newHeight = data.startHeight

	if data.resizeFromLeft then
		newX = data.startX + deltaX
		newWidth = data.startWidth - deltaX
	else
		newWidth = data.startWidth + deltaX
	end
	if data.resizeFromTop then
		newY = data.startY + deltaY
		newHeight = data.startHeight - deltaY
	else
		newHeight = data.startHeight + deltaY
	end
	return ClampResizeGeometry(data, newX, newY, newWidth, newHeight)
end

local function CreateResizeHandle(parent, name, anchor)
	local handle = parent:CreateChildWidget("button", name, 0, true)
	handle:SetText("")
	handle:SetExtent(RESIZE_HANDLE_SIZE, RESIZE_HANDLE_SIZE)
	handle:EnableDrag(true)
	handle:Clickable(true)
	handle.resizeAnchor = anchor
	handle.resizeFromLeft = string.find(anchor, "LEFT", 1, true) ~= nil
	handle.resizeFromTop = string.find(anchor, "TOP", 1, true) ~= nil
	handle.resizeGripA = handle:CreateColorDrawable(1, 1, 1, RESIZE_GRIP_ALPHA, "background")
	handle.resizeGripB = handle:CreateColorDrawable(1, 1, 1, RESIZE_GRIP_ALPHA, "background")
	LayoutResizeGrip(handle)
	handle:Show(false)

	function handle:OnEnter()
		SetResizeGripAlpha(self, RESIZE_GRIP_HOVER_ALPHA)
	end
	handle:SetHandler("OnEnter", handle.OnEnter)

	function handle:OnLeave()
		if not self.isResizing then
			SetResizeGripAlpha(self, RESIZE_GRIP_ALPHA)
		end
	end
	handle:SetHandler("OnLeave", handle.OnLeave)

	function handle:OnDragStart()
		local startX, startY = GetWidgetPosition(parent)
		local handleStartX, handleStartY = GetWidgetPosition(self)
		if startX == nil or startY == nil or handleStartX == nil or handleStartY == nil then
			return
		end

		self.resizeDrag = {
			startX = startX,
			startY = startY,
			startWidth = parent:GetWidth(),
			startHeight = parent:GetHeight(),
			handleStartX = handleStartX,
			handleStartY = handleStartY,
			resizeFromLeft = self.resizeFromLeft,
			resizeFromTop = self.resizeFromTop,
		}
		self.isResizing = true
		SetResizeGripAlpha(self, RESIZE_GRIP_HOVER_ALPHA)
		self:StartMoving()
	end
	handle:SetHandler("OnDragStart", handle.OnDragStart)

	function handle:OnUpdate()
		if self.isResizing then
			local x, y, width, height = ComputeResizeGeometry(self)
			if x ~= nil then
				ApplyWindowGeometry(x, y, width, height, false)
			end
		end
	end
	handle:SetHandler("OnUpdate", handle.OnUpdate)

	function handle:OnDragStop()
		self:StopMovingOrSizing()
		local x, y, width, height = ComputeResizeGeometry(self)
		if x ~= nil then
			ApplyWindowGeometry(x, y, width, height, true)
		end
		self.resizeDrag = nil
		self.isResizing = false
		SetResizeGripAlpha(self, RESIZE_GRIP_ALPHA)
		PositionResizeHandles()
	end
	handle:SetHandler("OnDragStop", handle.OnDragStop)

	return handle
end

local function AttachWindowDrag(surface)
	if surface == nil then
		return
	end
	SafeCall(surface, "EnableDrag", true)
	SafeCall(surface, "Clickable", true)
	SafeCall(surface, "EnablePick", true)
	surface:SetHandler("OnDragStart", StartWindowDrag)
	surface:SetHandler("OnDragStop", StopWindowDrag)
end

local function StartRequirementsDrag()
	if runtime.requirementsWindow ~= nil then
		runtime.requirementsWindow:StartMoving()
	end
end

local function StopRequirementsDrag()
	if runtime.requirementsWindow ~= nil then
		runtime.requirementsWindow:StopMovingOrSizing()
		SaveWidgetPosition(runtime.requirementsWindow, REQUIREMENTS_WINDOW_POSITION_KEY)
	end
end

local function AttachRequirementsDrag(surface)
	if surface == nil then
		return
	end
	SafeCall(surface, "EnableDrag", true)
	SafeCall(surface, "Clickable", true)
	SafeCall(surface, "EnablePick", true)
	surface:SetHandler("OnDragStart", StartRequirementsDrag)
	surface:SetHandler("OnDragStop", StopRequirementsDrag)
end

local function GetMaterialCostEntry(costKey)
	if costKey == nil or costKey == "" then
		return nil
	end
	if runtime.materialCosts[costKey] == nil then
		runtime.materialCosts[costKey] = { gold = "", silver = "", copper = "" }
	end
	return runtime.materialCosts[costKey]
end

local function ParseCostPart(text)
	local valueText = OneLineText(text)
	if valueText == "" then
		return 0, true
	end
	if not string.match(valueText, "^%d+$") then
		return 0, false
	end
	return tonumber(valueText) or 0, true
end

local function CostEntryToCopper(entry)
	if type(entry) ~= "table" then
		return 0, true
	end
	local gold, goldOk = ParseCostPart(entry.gold)
	local silver, silverOk = ParseCostPart(entry.silver)
	local copper, copperOk = ParseCostPart(entry.copper)
	if not goldOk or not silverOk or not copperOk then
		return 0, false
	end
	return (gold * 10000) + (silver * 100) + copper, true
end

local function SplitCurrency(copperValue)
	local copper = math.floor((tonumber(copperValue) or 0) + 0.5)
	if copper < 0 then
		copper = 0
	end
	local gold = math.floor(copper / 10000)
	local remainder = copper - (gold * 10000)
	local silver = math.floor(remainder / 100)
	local copperPart = remainder - (silver * 100)
	return gold, silver, copperPart
end

local function SetCurrencyLabelColor(label, color)
	if label == nil or color == nil then
		return
	end
	SetLabelStyle(label, ALIGN_LEFT, 9, color[1], color[2], color[3], color[4])
end

local function SetCurrencyLabels(labels, copperValue, visible)
	if labels == nil then
		return
	end

	local show = visible == true
	local gold, silver, copper = SplitCurrency(copperValue)
	if labels.gold ~= nil then
		labels.gold:SetText(show and (tostring(gold) .. "g") or "")
		labels.gold:Show(show)
		SetCurrencyLabelColor(labels.gold, GOLD_COLOR)
	end
	if labels.silver ~= nil then
		labels.silver:SetText(show and (tostring(silver) .. "s") or "")
		labels.silver:Show(show)
		SetCurrencyLabelColor(labels.silver, SILVER_COLOR)
	end
	if labels.copper ~= nil then
		labels.copper:SetText(show and (tostring(copper) .. "c") or "")
		labels.copper:Show(show)
		SetCurrencyLabelColor(labels.copper, COPPER_COLOR)
	end
end

local function ShowRowCostInputs(row, visible)
	if row == nil then
		return
	end
	for _, part in ipairs({ "gold", "silver", "copper" }) do
		local box = row.costBoxes and row.costBoxes[part] or nil
		local bg = row.costBackgrounds and row.costBackgrounds[part] or nil
		if box ~= nil then
			box:Show(visible == true)
		end
		if bg ~= nil then
			bg:Show(visible == true)
		end
	end
	SetCurrencyLabels(row.costTotalLabels, 0, visible == true)
end

local function SyncCostBoxText(box, text)
	runtime.costTextEventSuppressed = true
	SyncEditBoxText(box, text or "")
	runtime.costTextEventSuppressed = false
end

local function UpdateCostTotals()
	local directCopper = 0
	local baseCopper = 0
	local hasAnyPrice = false
	local hasInvalid = false

	for _, row in ipairs(runtime.requirementRows or {}) do
		local data = row.currentMaterialData
		if type(data) == "table" and data.type == "material" and row.costKey ~= nil then
			local entry = GetMaterialCostEntry(row.costKey)
			local unitCopper, ok = CostEntryToCopper(entry)
			local requiredQuantity = tonumber(data.requiredQuantity) or 0
			local rowCopper = unitCopper * requiredQuantity
			if not ok then
				hasInvalid = true
			elseif unitCopper > 0 and requiredQuantity > 0 then
				hasAnyPrice = true
			end

			SetCurrencyLabels(row.costTotalLabels, rowCopper, ok and unitCopper > 0 and requiredQuantity > 0)

			if ok then
				if data.section == "direct" then
					directCopper = directCopper + rowCopper
				elseif data.section == "base" then
					baseCopper = baseCopper + rowCopper
				end
			end
		elseif row.costTotalLabels ~= nil then
			SetCurrencyLabels(row.costTotalLabels, 0, false)
		end
	end

	if runtime.requirementsStatus ~= nil then
		if hasInvalid then
			runtime.requirementsStatus:SetText("Invalid cost input. Use whole numbers for gold, silver, copper.")
			SetLabelStyle(runtime.requirementsStatus, ALIGN_LEFT, 9, 1, 0.48, 0.16, 1)
			SetCurrencyLabels(runtime.directCostLabels, 0, false)
			SetCurrencyLabels(runtime.baseCostLabels, 0, false)
			if runtime.directCostTitle ~= nil then runtime.directCostTitle:Show(false) end
			if runtime.baseCostTitle ~= nil then runtime.baseCostTitle:Show(false) end
		elseif hasAnyPrice then
			runtime.requirementsStatus:SetText("Calculated from entered unit costs.")
			SetLabelStyle(runtime.requirementsStatus, ALIGN_LEFT, 9, 0.92, 0.96, 0.82, 1)
			if runtime.directCostTitle ~= nil then runtime.directCostTitle:Show(true) end
			if runtime.baseCostTitle ~= nil then runtime.baseCostTitle:Show(true) end
			SetCurrencyLabels(runtime.directCostLabels, directCopper, true)
			SetCurrencyLabels(runtime.baseCostLabels, baseCopper, true)
		else
			runtime.requirementsStatus:SetText("Enter unit cost as gold, silver, copper on material rows.")
			SetLabelStyle(runtime.requirementsStatus, ALIGN_LEFT, 9, 0.72, 0.72, 0.68, 1)
			SetCurrencyLabels(runtime.directCostLabels, 0, false)
			SetCurrencyLabels(runtime.baseCostLabels, 0, false)
			if runtime.directCostTitle ~= nil then runtime.directCostTitle:Show(false) end
			if runtime.baseCostTitle ~= nil then runtime.baseCostTitle:Show(false) end
		end
	end
end

local function ApplyCostText(row, part, text, syncBox)
	if row == nil or row.costKey == nil or part == nil then
		return
	end
	local entry = GetMaterialCostEntry(row.costKey)
	if entry == nil then
		return
	end
	entry[part] = tostring(text or "")
	if syncBox and row.costBoxes ~= nil then
		SyncCostBoxText(row.costBoxes[part], entry[part])
	end
	UpdateCostTotals()
end

local function ReadCostBoxText(box)
	local fallback = ""
	if box ~= nil and box.costRow ~= nil and box.costPart ~= nil then
		local entry = GetMaterialCostEntry(box.costRow.costKey)
		if entry ~= nil then
			fallback = entry[box.costPart] or ""
		end
	end
	return ReadEditBoxText(box, fallback)
end

local function OnCostChanged(box, ...)
	if runtime.costTextEventSuppressed then
		return
	end
	local text = FirstInputArg(...)
	if type(text) ~= "string" then
		text = ReadCostBoxText(box)
	end
	ApplyCostText(box.costRow, box.costPart, text, false)
end

local function HandleCostKey(box, ...)
	local key = FirstInputArg(...)
	if IsBackspaceOrDeleteKey(key) then
		local current = ReadCostBoxText(box)
		ApplyCostText(box.costRow, box.costPart, DropLastCharacter(current), true)
		return
	end

	local character = SearchCharacterFromKey(key)
	if character ~= nil and string.match(character, "%d") then
		local current = ReadCostBoxText(box)
		ApplyCostText(box.costRow, box.costPart, current .. character, true)
	else
		OnCostChanged(box, ...)
	end
end

local function HandleCostChar(box, ...)
	local text = FirstInputArg(...)
	if text == nil then
		return
	end
	text = tostring(text)
	if string.match(text, "^%d+$") then
		local current = ReadCostBoxText(box)
		ApplyCostText(box.costRow, box.costPart, current .. text, true)
	else
		OnCostChanged(box, ...)
	end
end

local function AttachCostHandlers(box)
	function box:OnTextChanged(...)
		OnCostChanged(self, ...)
	end
	box:SetHandler("OnTextChanged", box.OnTextChanged)
	box:SetHandler("OnTextChange", box.OnTextChanged)
	SafeCall(box, "SetHandler", "OnEditTextChanged", box.OnTextChanged)
	SafeCall(box, "SetHandler", "OnChanged", box.OnTextChanged)

	function box:OnCostChar(...)
		HandleCostChar(self, ...)
	end
	SafeCall(box, "SetHandler", "OnChar", box.OnCostChar)
	SafeCall(box, "SetHandler", "OnTextInput", box.OnCostChar)
	SafeCall(box, "SetHandler", "OnInput", box.OnCostChar)

	function box:OnCostKey(...)
		HandleCostKey(self, ...)
	end
	SafeCall(box, "SetHandler", "OnKeyUp", box.OnCostKey)
end

local function CreateCurrencyLabels(parent, namePrefix, anchorX, anchorY)
	local labels = {}
	local parts = {
		{ key = "gold", width = 42, color = GOLD_COLOR },
		{ key = "silver", width = 32, color = SILVER_COLOR },
		{ key = "copper", width = 34, color = COPPER_COLOR },
	}
	local offsetX = 0
	for _, part in ipairs(parts) do
		local label = parent:CreateChildWidget("label", namePrefix .. part.key, 0, true)
		label:SetText("")
		label:SetExtent(part.width, REQUIREMENTS_ROW_HEIGHT)
		SetLabelStyle(label, ALIGN_LEFT, 9, part.color[1], part.color[2], part.color[3], part.color[4])
		label:AddAnchor("TOPLEFT", parent, anchorX + offsetX, anchorY)
		SafeCall(label, "EnablePick", false)
		label:Show(false)
		labels[part.key] = label
		offsetX = offsetX + part.width
	end
	return labels
end

local function RefreshRequirementRows(rows, statusText)
	rows = rows or {}
	local actualCount = #rows

	for index, row in ipairs(runtime.requirementRows or {}) do
		local hasData = index <= actualCount
		local data = hasData and rows[index] or nil

		local iconPath = nil
		local nameText = ""
		local qtyText = ""
		local isHeader = false
		local isInfo = false
		local isMaterial = false

		if type(data) == "table" then
			iconPath = data.iconPath
			if data.type == "header" then
				isHeader = true
				nameText = "*  " .. (data.text or "")
			elseif data.type == "info" then
				isInfo = true
				nameText = data.text or ""
			else
				-- Normal material row
				isMaterial = data.type == "material"
				nameText = data.name or data.text or ""
				qtyText = data.quantity or ""
			end
		else
			nameText = tostring(data or "")
		end

		-- Show or hide the entire row widget
		row:Show(hasData)

		if hasData then
			row.currentMaterialData = data
			row.costKey = type(data) == "table" and data.costKey or nil

			-- Icon
			SetIconDrawable(row.iconDrawable, iconPath)

			-- Name label
			if row.nameLabel then
				row.nameLabel:SetText(nameText)

				if isHeader then
					SetLabelStyle(row.nameLabel, ALIGN_LEFT, 11, 0.96, 0.92, 0.75, 1)
				elseif isInfo then
					SetLabelStyle(row.nameLabel, ALIGN_LEFT, 10, 0.82, 0.82, 0.78, 1)
				else
					SetLabelStyle(row.nameLabel, ALIGN_LEFT, 11, 0.92, 0.92, 0.88, 1)
				end
			end

			-- Quantity label (only for real materials)
			if row.qtyLabel then
				row.qtyLabel:SetText(qtyText)
				if isHeader or isInfo then
					row.qtyLabel:SetText("")
				end
			end

			ShowRowCostInputs(row, isMaterial)
			if isMaterial and row.costKey ~= nil then
				local entry = GetMaterialCostEntry(row.costKey)
				if row.costBoxes ~= nil and entry ~= nil then
					SyncCostBoxText(row.costBoxes.gold, entry.gold)
					SyncCostBoxText(row.costBoxes.silver, entry.silver)
					SyncCostBoxText(row.costBoxes.copper, entry.copper)
				end
			end

			-- Visual treatment for header rows
			if isHeader then
				if not row.headerBg then
					row.headerBg = row:CreateColorDrawable(0.15, 0.12, 0.08, 0.6, "background")
					row.headerBg:AddAnchor("TOPLEFT", row, 0, 0)
					row.headerBg:AddAnchor("BOTTOMRIGHT", row, 0, 0)
				end
				row.headerBg:Show(true)
			else
				if row.headerBg then
					row.headerBg:Show(false)
				end
			end
		else
			-- Clean up hidden rows
			row.currentMaterialData = nil
			row.costKey = nil
			HideIconDrawable(row.iconDrawable)
			if row.nameLabel then row.nameLabel:SetText("") end
			if row.qtyLabel then row.qtyLabel:SetText("") end
			if row.headerBg then row.headerBg:Show(false) end
			ShowRowCostInputs(row, false)
			SetCurrencyLabels(row.costTotalLabels, 0, false)
		end
	end

	if actualCount == 0 and runtime.requirementsStatus ~= nil then
		SetCurrencyLabels(runtime.directCostLabels, 0, false)
		SetCurrencyLabels(runtime.baseCostLabels, 0, false)
		if runtime.directCostTitle ~= nil then runtime.directCostTitle:Show(false) end
		if runtime.baseCostTitle ~= nil then runtime.baseCostTitle:Show(false) end
		if statusText ~= nil and statusText ~= "" then
			runtime.requirementsStatus:SetText(ShortText(statusText, 96))
		else
			runtime.requirementsStatus:SetText("No material data for this recipe.")
		end
		SetLabelStyle(runtime.requirementsStatus, ALIGN_LEFT, 9, 0.72, 0.72, 0.68, 1)
	else
		UpdateCostTotals()
	end
end

local function SetQuantityStatus(text, isError)
	if runtime.quantityStatus == nil then
		return
	end
	runtime.quantityStatus:SetText(ShortText(text or "", 72))
	if isError then
		SetLabelStyle(runtime.quantityStatus, ALIGN_LEFT, 10, 1, 0.48, 0.16, 1)
	else
		SetLabelStyle(runtime.quantityStatus, ALIGN_LEFT, 10, 0.78, 0.86, 0.72, 1)
	end
end

local function UpdateRequirementHeader(recipe)
	if recipe == nil then
		if runtime.reqHeaderName then runtime.reqHeaderName:SetText("") end
		if runtime.reqHeaderWorkbench then runtime.reqHeaderWorkbench:SetText("") end
		HideIconDrawable(runtime.reqHeaderIcon)
		if runtime.reqHeaderArea then runtime.reqHeaderArea:Show(false) end
		return
	end

	if runtime.reqHeaderName then
		local targetQuantity = runtime.targetQuantity or DefaultTargetQuantity(recipe)
		runtime.reqHeaderName:SetText("[" .. FormatQuantity(targetQuantity) .. "] " .. RecipeName(recipe))
	end
	if runtime.reqHeaderWorkbench then
		local wb = (recipe.workbench and recipe.workbench ~= "") and ("Workbench: " .. recipe.workbench) or ""
		runtime.reqHeaderWorkbench:SetText(wb)
	end
	SetIconDrawable(runtime.reqHeaderIcon, recipe.iconPath)
	if runtime.reqHeaderArea then runtime.reqHeaderArea:Show(true) end
end

local function RefreshSelectedRequirements()
	local recipe = runtime.selectedRecipe
	UpdateRequirementHeader(recipe)
	local rows, statusText = BuildRecipeRequirementRows(recipe)
	RefreshRequirementRows(rows, statusText)
end

local function SyncQuantityBoxText(text)
	runtime.quantityTextEventSuppressed = true
	SyncEditBoxText(runtime.quantityBox, text)
	runtime.quantityTextEventSuppressed = false
end

local function ApplyQuantityText(text, syncQuantityBox)
	text = tostring(text or "")
	runtime.quantityText = text
	if syncQuantityBox then
		SyncQuantityBoxText(text)
	end

	local recipe = runtime.selectedRecipe
	local ok, quantity, message = ValidateTargetQuantity(recipe, text)
	if not ok then
		SetQuantityStatus(message, true)
		return
	end

	runtime.targetQuantity = quantity
	local unavailableReason = RecipeUnavailableReason(recipe)
	if unavailableReason ~= nil then
		SetQuantityStatus(unavailableReason, true)
		RefreshSelectedRequirements()
		return
	end

	local outputQuantity = RecipeOutputQuantity(recipe)
	local crafts = quantity / outputQuantity
	SetQuantityStatus(
		"Crafts: "
			.. FormatQuantity(crafts)
			.. " | Step: "
			.. FormatQuantity(outputQuantity),
		false
	)
	RefreshSelectedRequirements()
end

local function ReadQuantityBoxText()
	return ReadEditBoxText(runtime.quantityBox, runtime.quantityText)
end

local function OnQuantityChanged(...)
	if runtime.quantityTextEventSuppressed then
		return
	end
	local text = FirstInputArg(...)
	if type(text) ~= "string" then
		text = ReadQuantityBoxText()
	end
	ApplyQuantityText(text, false)
end

local function AppendQuantityText(text)
	local value = tostring(text or "")
	if value == "" then
		return
	end
	ApplyQuantityText(runtime.quantityText .. value, true)
end

local function HandleQuantityKey(...)
	local key = FirstInputArg(...)
	local token = NormalizeKeyToken(key)
	if token == "backspace" or token == "back" or token == "8" or token == "delete" or token == "del" or token == "46" then
		ApplyQuantityText(DropLastCharacter(runtime.quantityText), true)
		return
	end

	local character = SearchCharacterFromKey(key)
	if character ~= nil and string.match(character, "%d") then
		AppendQuantityText(character)
	else
		OnQuantityChanged(...)
	end
end

local function HandleQuantityChar(...)
	local text = FirstInputArg(...)
	if text == nil then
		return
	end
	text = tostring(text)
	if string.match(text, "^%d+$") then
		AppendQuantityText(text)
	else
		OnQuantityChanged(...)
	end
end

local function AttachQuantityHandlers(quantityBox)
	quantityBox:SetHandler("OnTextChanged", OnQuantityChanged)
	quantityBox:SetHandler("OnTextChange", OnQuantityChanged)
	SafeCall(quantityBox, "SetHandler", "OnEditTextChanged", OnQuantityChanged)
	SafeCall(quantityBox, "SetHandler", "OnChanged", OnQuantityChanged)
	SafeCall(quantityBox, "SetHandler", "OnChar", HandleQuantityChar)
	SafeCall(quantityBox, "SetHandler", "OnTextInput", HandleQuantityChar)
	SafeCall(quantityBox, "SetHandler", "OnInput", HandleQuantityChar)
	SafeCall(quantityBox, "SetHandler", "OnKeyUp", HandleQuantityKey)
end

local function CreateRequirementsWindow()
	if runtime.requirementsWindow ~= nil then
		return runtime.requirementsWindow
	end

	local fallbackX, fallbackY = LoadPosition(WINDOW_POSITION_KEY, 560, 320)
	local x, y = LoadPosition(REQUIREMENTS_WINDOW_POSITION_KEY, fallbackX + 34, fallbackY + 34)
	local window = CreateEmptyWindow("craftCalRequirementsWindow", "UIParent")
	window:SetExtent(REQUIREMENTS_WINDOW_WIDTH, REQUIREMENTS_WINDOW_HEIGHT)
	window:AddAnchor("TOPLEFT", "UIParent", x, y)
	window:EnableDrag(true)
	window:Clickable(true)
	window:Show(false)
	runtime.requirementsWindow = window

	local background = window:CreateColorDrawable(0, 0, 0, 0.82, "background")
	background:AddAnchor("TOPLEFT", window, 0, 0)
	background:AddAnchor("BOTTOMRIGHT", window, 0, 0)

	local title = window:CreateChildWidget("label", "craftCalRequirementsTitle", 0, true)
	title:SetText("Craft Requirements")
	title:SetExtent(REQUIREMENTS_WINDOW_WIDTH - 54, TITLE_HEIGHT)
	SetLabelStyle(title, ALIGN_LEFT, 12, 0.96, 0.92, 0.82, 1)
	title:AddAnchor("TOPLEFT", window, PADDING, 6)
	AttachRequirementsDrag(title)
	runtime.requirementsTitle = title

	local closeButton = window:CreateChildWidget("button", "craftCalRequirementsCloseButton", 0, true)
	closeButton:SetStyle("text_default")
	closeButton:SetText("X")
	closeButton:SetExtent(26, 22)
	closeButton:AddAnchor("TOPRIGHT", window, -PADDING, 5)
	function closeButton:OnClick()
		window:Show(false)
	end
	closeButton:SetHandler("OnClick", closeButton.OnClick)

	-- Crafted item header area (icon + name + workbench).
	local headerArea = window:CreateColorDrawable(0.12, 0.10, 0.07, 0.55, "artwork")
	headerArea:SetExtent(REQUIREMENTS_WINDOW_WIDTH - (PADDING * 2), 50)
	headerArea:AddAnchor("TOPLEFT", window, PADDING, 26)
	runtime.reqHeaderArea = headerArea

	-- Large icon for the output item
	local headerIcon = window:CreateIconDrawable("artwork")
	headerIcon:SetExtent(30, 30)
	headerIcon:AddAnchor("TOPLEFT", window, PADDING + 6, 29)
	HideIconDrawable(headerIcon)
	runtime.reqHeaderIcon = headerIcon

	-- Item name with quantity (e.g. "[10] Hereafter Stone")
	local headerName = window:CreateChildWidget("label", "craftCalReqHeaderName", 0, true)
	headerName:SetText("")
	SetLabelStyle(headerName, ALIGN_LEFT, 12, 0.98, 0.95, 0.85, 1)
	headerName:SetExtent(REQUIREMENTS_WINDOW_WIDTH - (PADDING * 2) - 50, 18)
	headerName:AddAnchor("TOPLEFT", window, PADDING + 42, 28)
	runtime.reqHeaderName = headerName

	-- Workbench line
	local headerWorkbench = window:CreateChildWidget("label", "craftCalReqHeaderWorkbench", 0, true)
	headerWorkbench:SetText("")
	SetLabelStyle(headerWorkbench, ALIGN_LEFT, 10, 0.78, 0.78, 0.72, 1)
	headerWorkbench:SetExtent(REQUIREMENTS_WINDOW_WIDTH - (PADDING * 2) - 50, 16)
	headerWorkbench:AddAnchor("TOPLEFT", window, PADDING + 42, 45)
	runtime.reqHeaderWorkbench = headerWorkbench

	local quantityLabel = window:CreateChildWidget("label", "craftCalReqQuantityLabel", 0, true)
	quantityLabel:SetText("Quantity")
	quantityLabel:SetExtent(REQUIREMENTS_QUANTITY_LABEL_WIDTH, REQUIREMENTS_QUANTITY_HEIGHT)
	SetLabelStyle(quantityLabel, ALIGN_LEFT, 11, 1, 0.9, 0.64, 1)
	quantityLabel:AddAnchor("TOPLEFT", window, PADDING, REQUIREMENTS_QUANTITY_TOP + 6)
	AttachRequirementsDrag(quantityLabel)

	local quantityBorder = window:CreateColorDrawable(1, 0.78, 0.32, 0.88, "artwork")
	quantityBorder:SetExtent(REQUIREMENTS_QUANTITY_BOX_WIDTH, REQUIREMENTS_QUANTITY_HEIGHT)
	quantityBorder:AddAnchor("TOPLEFT", window, PADDING + REQUIREMENTS_QUANTITY_LABEL_WIDTH, REQUIREMENTS_QUANTITY_TOP)
	runtime.quantityBorder = quantityBorder

	local quantityBackground = window:CreateColorDrawable(0.88, 0.86, 0.74, 0.96, "artwork")
	quantityBackground:SetExtent(REQUIREMENTS_QUANTITY_BOX_WIDTH - 4, REQUIREMENTS_QUANTITY_HEIGHT - 4)
	quantityBackground:AddAnchor(
		"TOPLEFT",
		window,
		PADDING + REQUIREMENTS_QUANTITY_LABEL_WIDTH + 2,
		REQUIREMENTS_QUANTITY_TOP + 2
	)
	runtime.quantityBackground = quantityBackground

	local quantityBox = window:CreateChildWidget("editbox", "craftCalReqQuantityBox", 0, true)
	quantityBox:SetExtent(REQUIREMENTS_QUANTITY_BOX_WIDTH - 8, REQUIREMENTS_QUANTITY_HEIGHT - 6)
	quantityBox:AddAnchor("TOPLEFT", window, PADDING + REQUIREMENTS_QUANTITY_LABEL_WIDTH + 4, REQUIREMENTS_QUANTITY_TOP + 3)
	quantityBox:SetText("")
	SafeCall(quantityBox, "SetMaxTextLength", 7)
	SafeCall(quantityBox, "SetInset", 8, 0, 8, 0)
	if quantityBox.style ~= nil then
		quantityBox.style:SetColor(0.02, 0.02, 0.02, 1)
		quantityBox.style:SetFontSize(14)
		quantityBox.style:SetAlign(ALIGN_LEFT)
	end
	runtime.quantityBox = quantityBox
	AttachQuantityHandlers(quantityBox)

	local quantityStatus = window:CreateChildWidget("label", "craftCalReqQuantityStatus", 0, true)
	quantityStatus:SetText("")
	quantityStatus:SetExtent(
		REQUIREMENTS_WINDOW_WIDTH - (PADDING * 2) - REQUIREMENTS_QUANTITY_LABEL_WIDTH - REQUIREMENTS_QUANTITY_BOX_WIDTH - 10,
		REQUIREMENTS_QUANTITY_HEIGHT
	)
	SetLabelStyle(quantityStatus, ALIGN_LEFT, 10, 0.78, 0.86, 0.72, 1)
	quantityStatus:AddAnchor(
		"TOPLEFT",
		window,
		PADDING + REQUIREMENTS_QUANTITY_LABEL_WIDTH + REQUIREMENTS_QUANTITY_BOX_WIDTH + 10,
		REQUIREMENTS_QUANTITY_TOP + 6
	)
	AttachRequirementsDrag(quantityStatus)
	runtime.quantityStatus = quantityStatus

	local status = window:CreateChildWidget("label", "craftCalRequirementsStatus", 0, true)
	status:SetText("")
	status:SetExtent(REQUIREMENTS_WINDOW_WIDTH - (PADDING * 2), 15)
	SetLabelStyle(status, ALIGN_LEFT, 9, 0.72, 0.72, 0.68, 1)
	status:AddAnchor("TOPLEFT", window, PADDING, REQUIREMENTS_ROW_TOP - 14)
	AttachRequirementsDrag(status)
	runtime.requirementsStatus = status

	local directTitle = window:CreateChildWidget("label", "craftCalDirectCostTitle", 0, true)
	directTitle:SetText("Direct:")
	directTitle:SetExtent(58, REQUIREMENTS_ROW_HEIGHT)
	SetLabelStyle(directTitle, ALIGN_LEFT, 10, 1, 0.92, 0.58, 1)
	directTitle:AddAnchor("TOPLEFT", window, PADDING, REQUIREMENTS_COST_SUMMARY_TOP)
	SafeCall(directTitle, "EnablePick", false)
	directTitle:Show(false)
	runtime.directCostTitle = directTitle
	runtime.directCostLabels = CreateCurrencyLabels(window, "craftCalDirectCost", PADDING + 58, REQUIREMENTS_COST_SUMMARY_TOP)

	local baseTitle = window:CreateChildWidget("label", "craftCalBaseCostTitle", 0, true)
	baseTitle:SetText("Base:")
	baseTitle:SetExtent(48, REQUIREMENTS_ROW_HEIGHT)
	SetLabelStyle(baseTitle, ALIGN_LEFT, 10, 0.72, 0.96, 1, 1)
	baseTitle:AddAnchor("TOPLEFT", window, PADDING + 270, REQUIREMENTS_COST_SUMMARY_TOP)
	SafeCall(baseTitle, "EnablePick", false)
	baseTitle:Show(false)
	runtime.baseCostTitle = baseTitle
	runtime.baseCostLabels = CreateCurrencyLabels(window, "craftCalBaseCost", PADDING + 318, REQUIREMENTS_COST_SUMMARY_TOP)

	for index = 1, REQUIREMENTS_VISIBLE_COUNT do
		local row = window:CreateChildWidget("button", "craftCalRequirementRow" .. tostring(index), 0, true)
		row:SetText("")
		row:SetExtent(REQUIREMENTS_WINDOW_WIDTH - (PADDING * 2), REQUIREMENTS_ROW_HEIGHT)
		-- Do not apply text_default style here; it causes visible empty button backgrounds.
		-- We control visibility explicitly in RefreshRequirementRows.
		row:AddAnchor("TOPLEFT", window, PADDING, REQUIREMENTS_ROW_TOP + ((index - 1) * REQUIREMENTS_ROW_HEIGHT))
		AttachRequirementsDrag(row)

		-- Icon
		local icon = row:CreateIconDrawable("artwork")
		icon:SetExtent(REQUIREMENTS_ICON_SIZE, REQUIREMENTS_ICON_SIZE)
		icon:AddAnchor("LEFT", row, 2, 1)
		HideIconDrawable(icon)
		row.iconDrawable = icon

		-- Main name label (left side)
		local nameLabel = row:CreateChildWidget("label", "craftCalReqName" .. tostring(index), 0, true)
		nameLabel:SetText("")
		SetLabelStyle(nameLabel, ALIGN_LEFT, 11, 0.92, 0.92, 0.88, 1)
		nameLabel:SetExtent(COST_BOX_START_X - REQUIREMENTS_ICON_SIZE - 82, REQUIREMENTS_ROW_HEIGHT)
		nameLabel:AddAnchor("LEFT", row, REQUIREMENTS_ICON_SIZE + 8, 0)
		SafeCall(nameLabel, "EnablePick", false)
		row.nameLabel = nameLabel

		-- Quantity label (right aligned)
		local qtyLabel = row:CreateChildWidget("label", "craftCalReqQty" .. tostring(index), 0, true)
		qtyLabel:SetText("")
		SetLabelStyle(qtyLabel, ALIGN_RIGHT, 11, 0.85, 0.92, 0.85, 1)
		qtyLabel:SetExtent(48, REQUIREMENTS_ROW_HEIGHT)
		qtyLabel:AddAnchor("LEFT", row, COST_BOX_START_X - 56, 0)
		SafeCall(qtyLabel, "EnablePick", false)
		row.qtyLabel = qtyLabel

		row.costBoxes = {}
		row.costBackgrounds = {}
		local costParts = {
			{ key = "gold", color = { 0.92, 0.72, 0.22, 0.58 } },
			{ key = "silver", color = { 0.72, 0.74, 0.78, 0.58 } },
			{ key = "copper", color = { 0.76, 0.42, 0.22, 0.58 } },
		}
		for costIndex, part in ipairs(costParts) do
			local x = COST_BOX_START_X + ((costIndex - 1) * (COST_BOX_WIDTH + COST_BOX_GAP))
			local bg = row:CreateColorDrawable(part.color[1], part.color[2], part.color[3], part.color[4], "artwork")
			bg:SetExtent(COST_BOX_WIDTH, COST_BOX_HEIGHT)
			bg:AddAnchor("LEFT", row, x, 0)
			bg:Show(false)
			row.costBackgrounds[part.key] = bg

			local box = row:CreateChildWidget("editbox", "craftCalCost" .. part.key .. tostring(index), 0, true)
			box:SetExtent(COST_BOX_WIDTH - 4, COST_BOX_HEIGHT - 2)
			box:AddAnchor("LEFT", row, x + 2, 0)
			box:SetText("")
			SafeCall(box, "SetMaxTextLength", 5)
			SafeCall(box, "SetInset", 2, 0, 2, 0)
			if box.style ~= nil then
				box.style:SetColor(0.02, 0.02, 0.02, 1)
				box.style:SetFontSize(10)
				box.style:SetAlign(ALIGN_LEFT)
			end
			box.costRow = row
			box.costPart = part.key
			box:Show(false)
			AttachCostHandlers(box)
			row.costBoxes[part.key] = box
		end

		row.costTotalLabels = CreateCurrencyLabels(
			row,
			"craftCalCostTotal" .. tostring(index),
			COST_BOX_START_X + (3 * (COST_BOX_WIDTH + COST_BOX_GAP)) + 2,
			0
		)

		runtime.requirementRows[#runtime.requirementRows + 1] = row
	end

	function window:OnDragStart()
		self:StartMoving()
	end
	window:SetHandler("OnDragStart", window.OnDragStart)

	function window:OnDragStop()
		self:StopMovingOrSizing()
		SaveWidgetPosition(self, REQUIREMENTS_WINDOW_POSITION_KEY)
	end
	window:SetHandler("OnDragStop", window.OnDragStop)

	return window
end

local function ShowRequirementsWindow(result)
	local window = CreateRequirementsWindow()
	runtime.selectedRecipe = result
	if result then
		runtime.targetQuantity = DefaultTargetQuantity(result)
		runtime.quantityText = FormatQuantity(runtime.targetQuantity)
		SyncQuantityBoxText(runtime.quantityText)
		local unavailableReason = RecipeUnavailableReason(result)
		if unavailableReason ~= nil then
			SetQuantityStatus(unavailableReason, true)
		else
			SetQuantityStatus("Crafts: 1 | Step: " .. FormatQuantity(RecipeOutputQuantity(result)), false)
		end
	else
		runtime.targetQuantity = nil
		runtime.quantityText = ""
		SyncQuantityBoxText("")
		SetQuantityStatus("", false)
	end

	if runtime.requirementsTitle ~= nil then
		runtime.requirementsTitle:SetText("Craft Requirements")
	end

	RefreshSelectedRequirements()
	window:Show(true)
	SafeCall(window, "Raise")
end

local function CreateWindow()
	local x, y = LoadPosition(WINDOW_POSITION_KEY, 560, 320)
	local width, height = LoadSize()
	runtime.windowWidth = width
	runtime.windowHeight = height
	local window = CreateEmptyWindow("craftCalWindow", "UIParent")
	window:SetExtent(width, height)
	window:AddAnchor("TOPLEFT", "UIParent", x, y)
	window:EnableDrag(true)
	window:Clickable(true)
	window:Show(false)
	runtime.window = window

	local background = window:CreateColorDrawable(0, 0, 0, 0.78, "background")
	background:AddAnchor("TOPLEFT", window, 0, 0)
	background:AddAnchor("BOTTOMRIGHT", window, 0, 0)
	runtime.background = background

	local title = window:CreateChildWidget("label", "craftCalTitle", 0, true)
	title:SetText("Craft Folio Search")
	title:SetExtent(width - (PADDING * 2) - 34, TITLE_HEIGHT)
	SetLabelStyle(title, ALIGN_LEFT, 13, 0.96, 0.92, 0.82, 1)
	title:AddAnchor("TOPLEFT", window, PADDING, 8)
	AttachWindowDrag(title)
	runtime.title = title

	local closeButton = window:CreateChildWidget("button", "craftCalCloseButton", 0, true)
	closeButton:SetStyle("text_default")
	closeButton:SetText("X")
	closeButton:SetExtent(26, 22)
	closeButton:AddAnchor("TOPRIGHT", window, -PADDING, 7)
	function closeButton:OnClick()
		CollapseCraftWindow()
	end
	closeButton:SetHandler("OnClick", closeButton.OnClick)
	runtime.closeButton = closeButton

	local searchBorder = window:CreateColorDrawable(0.96, 0.9, 0.72, 0.62, "artwork")
	searchBorder:SetExtent(width - (PADDING * 2), SEARCH_HEIGHT)
	searchBorder:AddAnchor("TOPLEFT", window, PADDING, SEARCH_TOP)
	runtime.searchBorder = searchBorder

	local searchBackground = window:CreateColorDrawable(0.86, 0.88, 0.82, 0.42, "artwork")
	searchBackground:SetExtent(width - (PADDING * 2) - 4, SEARCH_HEIGHT - 4)
	searchBackground:AddAnchor("TOPLEFT", window, PADDING + 2, SEARCH_TOP + 2)
	runtime.searchBackground = searchBackground

	local searchBox = window:CreateChildWidget("editbox", "craftCalSearchBox", 0, true)
	searchBox:SetExtent(width - (PADDING * 2) - 8, SEARCH_HEIGHT - 6)
	searchBox:AddAnchor("TOPLEFT", window, PADDING + 4, SEARCH_TOP + 3)
	searchBox:SetText("")
	SafeCall(searchBox, "SetMaxTextLength", 64)
	SafeCall(searchBox, "SetInset", 7, 0, 7, 0)
	if searchBox.style ~= nil then
		searchBox.style:SetColor(0.05, 0.06, 0.05, 1)
		searchBox.style:SetFontSize(13)
		searchBox.style:SetAlign(ALIGN_LEFT)
	end
	runtime.searchBox = searchBox
	AttachSearchHandlers(searchBox)

	local status = window:CreateChildWidget("label", "craftCalStatus", 0, true)
	status:SetText("Type at least " .. tostring(SEARCH_MIN_LENGTH) .. " characters to search the crafting folio")
	status:SetExtent(width - (PADDING * 2), 20)
	SetLabelStyle(status, ALIGN_LEFT, 11, 0.82, 0.82, 0.78, 1)
	status:AddAnchor("TOPLEFT", window, PADDING, STATUS_TOP)
	AttachWindowDrag(status)
	runtime.statusLabel = status

	for index = 1, RESULT_VISIBLE_COUNT do
		local row = window:CreateChildWidget("button", "craftCalResult" .. tostring(index), 0, true)
		row:SetStyle("text_default")
		row:SetText("")
		row:SetExtent(width - (PADDING * 2), RESULT_ROW_HEIGHT)
		row:AddAnchor("TOPLEFT", window, PADDING, RESULT_TOP + ((index - 1) * (RESULT_ROW_HEIGHT + RESULT_ROW_GAP)))
		row:Show(false)
		AttachWindowDrag(row)

		local rowBg = row:CreateColorDrawable(0.06, 0.06, 0.07, 0.54, "background")
		rowBg:AddAnchor("TOPLEFT", row, 0, 0)
		rowBg:AddAnchor("BOTTOMRIGHT", row, 0, 0)

		local nameLabel = row:CreateChildWidget("label", "craftCalResultName" .. tostring(index), 0, true)
		nameLabel:SetText("")
		nameLabel:SetExtent(width - (PADDING * 2) - 10, 18)
		SetLabelStyle(nameLabel, ALIGN_LEFT, 11, 0.98, 0.98, 0.98, 1)
		nameLabel:AddAnchor("TOPLEFT", row, 6, 3)
		SafeCall(nameLabel, "EnablePick", false)
		row.nameLabel = nameLabel

		local detailLabel = row:CreateChildWidget("label", "craftCalResultDetail" .. tostring(index), 0, true)
		detailLabel:SetText("")
		detailLabel:SetExtent(width - (PADDING * 2) - 10, 14)
		SetLabelStyle(detailLabel, ALIGN_LEFT, 9, 0.74, 0.76, 0.74, 1)
		detailLabel:AddAnchor("BOTTOMLEFT", row, 6, -3)
		SafeCall(detailLabel, "EnablePick", false)
		row.detailLabel = detailLabel

		function row:OnClick()
			if self.itemData == nil then
				return
			end
			SetSelectedResult(self.itemData)
			ShowRequirementsWindow(self.itemData)
		end
		row:SetHandler("OnClick", row.OnClick)
		runtime.resultRows[#runtime.resultRows + 1] = row
	end

	-- Selected label now sits directly below the (larger) results list
	local selectedTop = RESULT_TOP + (RESULT_VISIBLE_COUNT * (RESULT_ROW_HEIGHT + RESULT_ROW_GAP)) + 6
	local selected = window:CreateChildWidget("label", "craftCalSelected", 0, true)
	selected:SetText("Selected: none")
	selected:SetExtent(width - (PADDING * 2), 20)
	SetLabelStyle(selected, ALIGN_LEFT, 11, 0.88, 0.9, 1, 1)
	selected:AddAnchor("TOPLEFT", window, PADDING, selectedTop)
	AttachWindowDrag(selected)
	runtime.selectedLabel = selected

	function window:OnDragStart()
		self:StartMoving()
	end
	window:SetHandler("OnDragStart", window.OnDragStart)

	function window:OnDragStop()
		self:StopMovingOrSizing()
		SaveWindowGeometry(self)
	end
	window:SetHandler("OnDragStop", window.OnDragStop)

	function window:OnUpdate(dt)
		local delta = dt or 0.016
		if delta > 1 then
			delta = delta / 1000
		end
		runtime.searchPollElapsed = runtime.searchPollElapsed + delta
		if runtime.searchPollElapsed >= SEARCH_POLL_INTERVAL then
			runtime.searchPollElapsed = 0
			PollSearchBox()
		end
	end
	window:SetHandler("OnUpdate", window.OnUpdate)

	runtime.resizeHandles = {
		CreateResizeHandle(window, "craftCalResizeTopLeft", "TOPLEFT"),
		CreateResizeHandle(window, "craftCalResizeTopRight", "TOPRIGHT"),
		CreateResizeHandle(window, "craftCalResizeBottomLeft", "BOTTOMLEFT"),
		CreateResizeHandle(window, "craftCalResizeBottomRight", "BOTTOMRIGHT"),
	}
	LayoutWindow()
end

local function CreateLauncherButton()
	local x, y = LoadPosition(LAUNCHER_POSITION_KEY, 560, 320)
	local button = UIParent:CreateWidget("button", "craftCalLauncherButton", "UIParent", "")
	button:SetStyle("text_default")
	button:SetText(LAUNCHER_LABEL)
	button:SetExtent(LAUNCHER_WIDTH, LAUNCHER_HEIGHT)
	button:EnableDrag(true)
	SafeCall(button, "Clickable", true)
	button:AddAnchor("TOPLEFT", "UIParent", x, y)
	button:Show(false)

	function button:OnClick()
		RestoreCraftWindow()
	end
	button:SetHandler("OnClick", button.OnClick)

	function button:OnDragStart()
		self:StartMoving()
	end
	button:SetHandler("OnDragStart", button.OnDragStart)

	function button:OnDragStop()
		self:StopMovingOrSizing()
		SaveWidgetPosition(self, LAUNCHER_POSITION_KEY)
	end
	button:SetHandler("OnDragStop", button.OnDragStop)

	runtime.launcherButton = button
	return button
end

local function ApplyInitialVisibility()
	if LoadWindowOpenState() then
		RestoreCraftWindow()
	else
		ShowCraftWindow(false)
		ShowLauncherButton(true)
	end
end

CreateWindow()
CreateLauncherButton()
ApplyInitialVisibility()
