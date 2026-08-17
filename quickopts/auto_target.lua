local QO = _G.__QUICKOPTS
if QO == nil then
	return
end

ADDON:ImportAPI(API_TYPE.OPTION.id)

QO.RegisterOption({
	id = "auto_target",
	title = "Auto Target",
	optionType = OIT_AUTO_ENEMY_TARGETING,
	optionName = "auto_enemy_targeting",
	states = {
		{ value = 0, text = "Off", color = { 0.9, 0.333, 0.333, 1 }, chat = "Auto Target disabled." },
		{ value = 1, text = "On", color = { 0.348, 0.609, 0.370, 1 }, chat = "Auto Target enabled." },
	},
})
