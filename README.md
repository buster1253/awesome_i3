# Features

- workspaces
- layout

## Requirements
- lua_cjson

## Install
```lua
-- require the module
local workspaces = require "workspaces"

-- add a textbox to each screen in screen "connect"
s.myworkspacename = wibox.widget{
	markup = "",
	widget = wibox.widget.textbox
}
-- add it somewhere ref. mod + x

-- after screen "connect" signal
workspaces.init()
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


# Usage

command | description
--------|------------
list_ws()| displays current workspaces using naughtify
view_tag(i)| Goto or create tag i
move_client_to_tag(i)| Moves focused client to tag i

# TODO
- Better neighbour detection
- Global tag: shared between all workspaces
- serializing: keep setup post reload
