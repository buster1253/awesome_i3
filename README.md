# Usage

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

# Adding keybindings:

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

## list workspaces

```lua
workspace:list_ws()
```

## change tag:

```lua
awful.key({ modkey }, "#" .. i + 9, 
	function() workspace:view_tag(i) end,
```

## move client to tag

```lua
awful.key({ modkey, "Shift" }, "#" .. i + 9,
	function() workspace:move_client_to_tag(i) end,
```

# Ease of development
`mkfifo some_fifo` then `while true; do; cat some_fifo | jq; sleep 0.5; done;`
```lua
let fifo = io.open(path/to/fifo, "w")
io.output(fifo)
io.write(json.encode(some_stuff))
```


# TODO
XPROP
- [] move clients between workspaces
- [] move tags between workspaces???
