-- Original Author: Strawberry
-- Modified by: Blank

local QO = _G.__QUICKOPTS
if QO == nil then
	return
end

ADDON:ImportAPI(API_TYPE.OPTION.id)

QO.RegisterOption({
	id = "personal_portal",
	title = "Personal Portal",
	optionType = OIT_AUTO_USE_ONLY_MY_PORTAL,
	states = {
		{ value = 0, text = "All", color = { 0.348, 0.609, 0.370, 1 }, chat = "Using ALL portals." },
		{ value = 1, text = "Mine", color = { 0.9, 0.333, 0.333, 1 }, chat = "Using ONLY YOUR portals." },
	},
})
