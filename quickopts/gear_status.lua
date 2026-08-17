local QO = _G.__QUICKOPTS
if QO == nil then
	return
end

ADDON:ImportAPI(API_TYPE.OPTION.id)

QO.RegisterOption({
	id = "gear_status",
	title = "Gear Status",
	optionType = OIT_VISIBLEMYEQUIPINFO,
	optionName = "VisibleMyEquipInfo",
	states = {
		{ value = 1, text = "Public", color = { 0.348, 0.609, 0.370, 1 }, chat = "Gear status set to PUBLIC." },
		{ value = 2, text = "Private", color = { 0.9, 0.333, 0.333, 1 }, chat = "Gear status set to PRIVATE." },
	},
})
