# Quick Opts

A compact settings panel for ArcheRage. Toggle common game options from one window instead of digging through the in-game Options UI.


![Quick Opts UI](https://raw.githubusercontent.com/blank0443/addon_assets/main/quickopts/ui_window.png)


## Features

- ESC menu button (**Quick Opts**, guide icon) to show or hide the window
- Drag to reposition; position and visibility are saved
- Close with the **X** in the top-right corner
- Rows always display the live game setting, including changes made in the in-game Options window
- Each setting is its own file. Missing or broken files do not take down the rest of the panel

## Settings

| Row | What it does |
| --- | --- |
| **Personal Portal** | Use only your portals (**Mine**) or any portal (**All**) |
| **Mount Own** | Mount only your mounts (**Mine**) or allow any mounts (**All**) |
| **Auto Target** | Enable or disable auto-selecting a target when using skills |
| **Gear Status** | Set gear privacy to **Public** or **Private** |
| **Skill Queue** | Cycle skill queue: **Disabled**, **Limited** (no combo), **Full** |

Click a row button to cycle or toggle that option. Chat confirms the change when the option defines a chat line.

## Usage

1. Install the `globals` folder (required).
2. Enable **quickopts** on the character select Player UI screen.
3. Open the panel from the ESC menu, or restore it if it was left visible.
4. Click a setting to change it. The same values stay in sync if you change them in the game Options UI.

## Adding or removing a setting

`ui.lua` is only the hub. It does not name individual settings. Rows appear when a file calls `QO.RegisterOption`.

The client only runs Lua files listed in `toc.g`. That is why a new file still needs **one line in `toc.g` after `ui.lua`**. Do not edit `ui.lua`.

### Remove a setting

1. Delete the `.lua` file (for example `skillqueue.lua`).
2. Remove that filename from `toc.g`.

The window still opens. Only that row is gone.

If you delete the file but leave it listed in `toc.g`, the client may refuse to load the whole addon. Remove the file name in `toc.g` whenever you remove a file.

### Add a setting

1. Copy the template below into a new `quickopts/*.lua` file.
2. Add the filename to `toc.g` after `ui.lua`.
3. Reload the addon.

```lua
local QO = _G.__QUICKOPTS
if QO == nil then
	return
end

ADDON:ImportAPI(API_TYPE.OPTION.id)

QO.RegisterOption({
	id = "auto_target",
	title = "Name for the button",
	optionType = OIT_AUTO_ENEMY_TARGETING,
	states = {
		{ value = 0, text = "Off", color = { 0.9, 0.333, 0.333, 1 }, chat = "Auto Target disabled." },
		{ value = 1, text = "On", color = { 0.348, 0.609, 0.370, 1 }, chat = "Auto Target enabled." },
	},
})
```


`optionType` the `X2Option.optionType` which represents the setting. Ex: `OIT_OPTION_ITEM_MOUNT_ONLY_MY_PET` represents **Mount my mount only** setting

Optional fields:

- `optionName` — fallback when `GetOptionItemValueByName` is needed (Skill Queue uses this).
- `read()` / `write(value)` — custom accessors if the option is not a single `OIT_` id.
- `chat` on a state — system chat line after cycling **to** that state.

`id` must be unique. `states` are cycled in order. Colors are `{ r, g, b, a }`.
