local QO = _G.__QUICKOPTS
if QO == nil then
	return
end

ADDON:ImportAPI(API_TYPE.OPTION.id)

-- custom_skill_queue: 0 disable, 1 enable except combo (Limited), 2 enable to all (Full).
QO.RegisterOption({
	id = "skillqueue",
	title = "Skill Queue",
	optionType = OIT_OPTION_CUSTOM_SKILL_QUEUE,
	optionName = "OPTION_CUSTOM_SKILL_QUEUE",
	states = {
		{ value = 0, text = "Disabled", color = { 0.9, 0.333, 0.333, 1 } },
		{ value = 1, text = "Limited", color = { 0.95, 0.58, 0.18, 1 } },
		{ value = 2, text = "Full", color = { 0.348, 0.609, 0.370, 1 } },
	},
})
