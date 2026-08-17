local QO = _G.__QUICKOPTS
if QO == nil then
	return
end

ADDON:ImportAPI(API_TYPE.OPTION.id)

QO.RegisterOption({
	id = "mount_own",
	title = "Mount Own",
	optionType = OIT_OPTION_ITEM_MOUNT_ONLY_MY_PET,
	states = {
		{ value = 0, text = "All", color = { 0.348, 0.609, 0.370, 1 }, chat = "Allowing ANY mounts." },
		{ value = 1, text = "Mine", color = { 0.9, 0.333, 0.333, 1 }, chat = "Using ONLY YOUR mounts." },
	},
})
