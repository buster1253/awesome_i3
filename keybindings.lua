local awful         = require "awful"
local gears         = require "gears"
local workspace     = require "workspace"
local hotkeys_popup = require("awful.hotkeys_popup").widget
local layout = require "i3_layout"

-- TODO move this to another module
local def = "dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify"
.." /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player."
local spotify = {
	toggle = function()
		os.execute(def.."PlayPause")
	end,
	prev = function()
		os.execute(def.."Previous")
	end,
	next = function()
		os.execute(def.."Next")
	end
}

local globalkeys = gears.table.join(
----------------------- LAYOUT ------------------------
awful.key({ modkey, "Control" }, "t", function() layout.toggle_orientation()end,
	{description = "Toggle orientation: Experimental", group = "workspaces"}),
awful.key({ modkey }, "v", function() layout.split("v") end,
	{description = "Split vertically", group = "workspaces"}),
awful.key({ modkey }, "g", function() layout.split("h") end,
	{description = "Split horizontally", group = "workspaces"}),
awful.key({ modkey }, "h", function() layout.move_focus("W") end,
	{description = "Focus left", group = "workspaces"}),
awful.key({ modkey }, "l", function() layout.move_focus("E") end,
	{description = "Focus right", group = "workspaces"}),
awful.key({ modkey }, "k", function() layout.move_focus("N") end,
	{description = "Focus up", group = "workspaces"}),
awful.key({ modkey }, "j", function() layout.move_focus("S") end,
	{description = "Focus down", group = "workspaces"}),
--awful.key({ modkey, "Shift"}, "s", function() workspace:serialize() end,
	--{description = "List workspaces", group = "workspaces"}),
awful.key({ modkey, "Shift" }, "h", function() layout.move_client("W") end,
	{description = "Move client left", group = "workspaces"}),
awful.key({ modkey, "Shift" }, "l", function() layout.move_client("E") end,
	{description = "Move client right", group = "workspaces"}),
awful.key({ modkey, "Shift" }, "k", function() layout.move_client("N") end,
	{description = "Move client up", group = "workspaces"}),
awful.key({ modkey, "Shift" }, "j", function() layout.move_client("S") end,
	{description = "Move client down", group = "workspaces"}),

awful.key({ modkey }, "a", function()
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
end,
	{description = "Select workspace", group = "workspaces"}),
awful.key({ modkey, "shift" }, "i", function() workspace:list_ws() end,
	{description = "List workspaces", group = "workspaces"}),

awful.key({ modkey }, "p", spotify.toggle,
	{description = "PlayPause toggle", group = "Spotify"}),
awful.key({ modkey, "Shift" }, "n", spotify.next,
	{description = "Next song", group = "Spotify"}),
awful.key({ modkey, "Shift" }, "p", spotify.prev,
	{description = "previous song", group = "Spotify"}),

awful.key({ modkey}, "s",		hotkeys_popup.show_help,
	{description="show help", group="awesome"}),

awful.key({ modkey}, "Left",	awful.tag.viewprev,
	{description = "view previous", group = "tag"}),

awful.key({ modkey}, "Right",	awful.tag.viewnext,
	{description = "view next", group = "tag"}),

awful.key({ modkey}, "Escape",	awful.tag.history.restore,
	{description = "go back", group = "tag"}),

awful.key({ modkey }, "w", function() mymainmenu:show() end,
	{description = "show main menu", group = "awesome"}),

-- Standard program
awful.key({ modkey }, "Return", function () awful.spawn(terminal) end,
	{description = "open a terminal", group = "launcher"}),

awful.key({ modkey, "Control" }, "r", awesome.restart,
	{description = "reload awesome", group = "awesome"}),

awful.key({ modkey, "Shift"   }, "c", awesome.quit,
	{description = "quit awesome", group = "awesome"}),


-- Prompt
awful.key({ modkey }, "r",function()awful.screen.focused().mypromptbox:run()end,
	{description = "run prompt", group = "launcher"}),

awful.key({ modkey }, "d", function() awful.spawn("rofi -show combi") end,
	{description = "run rofi", group = "launcher"}),

awful.key({ modkey }, "x",
function()
	awful.prompt.run {
		prompt       = "Run Lua code: ",
		textbox      = awful.screen.focused().mypromptbox.widget,
		exe_callback = awful.util.eval,
		history_path = awful.util.get_cache_dir() .. "/history_eval"
	}
end,
	{description = "lua execute prompt", group = "awesome"})
)

-- Swap tags
for i = 0, 9 do
	globalkeys = gears.table.join(globalkeys,
	-- View tag only.
	awful.key({ modkey }, i,
	function() if i == 0 then i = 10 end workspace:view_tag(i) end,
	{description = "view tag #"..i, group = "tag"}),

	-- Move client to tag.
	awful.key({ modkey, "Shift" }, i,
	function() if i == 0 then i = 10 end workspace:move_client_to_tag(i) end,
	{description = "move focused client to tag #"..i, group = "tag"})
	)
end

clientkeys = gears.table.join(
awful.key({ modkey }, "f",
function (c)
	c.fullscreen = not c.fullscreen
	c:raise()
end,
{description = "toggle fullscreen", group = "client"}),
awful.key({ modkey, "Shift" }, "q",function (c) c:kill() end,
{description = "close", group = "client"})
)

-- Set keys
root.keys(globalkeys)
