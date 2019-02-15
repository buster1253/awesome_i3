# Features

- workspaces
- i3_layout

## Requirements
- lua_cjson
- [bolt](https://github.com/gicmo/bolt) (Optional) for thunderbolt presets

## Usage

```lua
local workspace = require "workspaces"
```

To have the current workspace name displayed on the screen add a textbox widget
to the screens named `wsname`.

```lua
s.wsname = wibox.widget.textbox("")
```

finally after the screen.connect_for_each_screen initialize to the default ws
by swapping to it

```lua
workspace:swap_ws(1) -- default/initial workspace
```

## Change workspace:

```lua
awful.prompt.run {
	prompt       = '<b>Workspace: </b>',
	text         = '',
	bg_cursor    = '#ff0000',
	textbox      = awful.screen.focused().mypromptbox.widget,
	exe_callback = function(input)
		if not input or #input == 0 then return end
		workspace:swap_ws(input)
	end
}
```


# Commands

command | description
--------|------------
list_ws()| displays current workspaces using naughtify
view_tag(i)| Goto or create tag i
move_client_to_tag(i)| Moves focused client to tag i


# Thunderbolt dock

requirements: [bolt](https://github.com/gicmo/bolt)

in rc.lua add:

```lua
thunderbolt = {
	uuid = {
		output = {
			mode = "1920x1080",
			pos = "0x0"
		}
	}
}
```

# TODO

- Write actual documentation
- Global tag: shared between all workspaces
- serializing: keep setup post reload
	- make serialization work for clients without a pid
