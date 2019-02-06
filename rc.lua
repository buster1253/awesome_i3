-- Standard awesome library
--------------------------------------------------------------------------------
local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful") -- Theme handling library

require("awful.autofocus")

local naughty = require("naughty") -- Notification library
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup").widget

-- Enable hotkeys help widget for VIM and other apps
-- when client with a matching name is opened:
require("awful.hotkeys_popup.keys")

-- I3 tag handler
local workspace = require "workspace"

--local battery_widget = require "battery_widget"

if awesome.startup_errors then
	naughty.notify({ preset = naughty.config.presets.critical,
	title = "Oops, there were errors during startup!",
	text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
	local in_error = false
	awesome.connect_signal("debug::error", function (err)
		-- Make sure we don't go into an endless error loop
		if in_error then return end
		in_error = true

		naughty.notify({ preset = naughty.config.presets.critical,
		title = "Oops, an error happened!",
		text = tostring(err) })
		in_error = false
	end)
end
-- }}}

beautiful.init("~/.config/awesome/themes/theme.lua") -- set theme
terminal = "terminology"
editor = os.getenv("EDITOR") or "vim"

modkey = "Mod4" -- win button

-- Create a launcher widget and a main menu
mainmenu = awful.menu{
	items = {
		{ "lock", "light-locker-command -l"},
		{ "restart", awesome.restart },
		{ "suspend", "systemctl suspend" },
		{ "quit", function() awesome.quit() end}
	}
}

textclock = wibox.widget.textclock()

local function set_wallpaper(s)
	-- Wallpaper
	if beautiful.wallpaper then
		local wallpaper = beautiful.wallpaper
		-- If wallpaper is a function, call it with the screen
		if type(wallpaper) == "function" then
			wallpaper = wallpaper(s)
		end
		gears.wallpaper.maximized(wallpaper, s, true)
	end
end


-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
screen.connect_signal("property::geometry", set_wallpaper)
tag.connect_signal("request::screen", function(t)
	--log("please give me screen" .. t.name)
	print("==============================================")
	print("please give me screen" .. t.name)
	print("primary: ", screen.primary.index)
	print("==============================================")
	workspace:move_tag_to_screen(t, screen.primary)
end)

local bat_wgt = require "widgets/bat_wgt".new("BAT0")
local net_wgt = require "widgets/net_wgt".new("wlp61s0", 1)

awful.screen.connect_for_each_screen(function(s)
	-- Wallpaper
	set_wallpaper(s)

	-- Create a promptbox for each screen
	s.mypromptbox = awful.widget.prompt()
	-- taglist widget
	s.taglist = awful.widget.taglist(s, awful.widget.taglist.filter.all,
	taglist_buttons)

	-- display current workspace
	s.wsname = wibox.widget.textbox("")

	-- Create the wibox
	s.wibar = awful.wibar({ position = "top", screen = s })

	-- Add widgets to the wibox
	s.wibar:setup {
		layout = wibox.layout.align.horizontal,
		{ -- Left widgets
			layout = wibox.layout.fixed.horizontal,
			s.wsname,
			s.taglist,
			s.mypromptbox,
		},
		s.mytasklist, -- Middle widget
		{ -- Right widgets
			layout = wibox.layout.fixed.horizontal,
			net_wgt,
			bat_wgt,
			textclock,
			wibox.widget.systray(),
		},
	}
end)

workspace:swap_ws(1) -- default workspace

require "keybindings"

-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
	{
		-- All clients will match this rule.
		rule = {},
		properties = {
			border_width = beautiful.border_width,
			border_color = beautiful.border_normal,
			focus = awful.client.focus.filter,
			raise = true,
			size_hints_honor = false,
			keys = clientkeys,
			buttons = clientbuttons,
			screen = awful.screen.preferred,
			placement = awful.placement.no_overlap+awful.placement.no_offscreen
		}
	},

	-- Floating clients.
	{
		rule_any = {
			instance = {
				"DTA",  -- Firefox addon DownThemAll.
				"copyq",  -- Includes session name in class.
			},
			class = {
				"Arandr",
				"Gpick",
				"Kruler",
				"MessageWin",  -- kalarm.
				"Sxiv",
				"Wpa_gui",
				"pinentry",
				"veromix",
				"xtightvncviewer"
			},

			name = {
				"Event Tester",  -- xev.
			},
			role = {
				"AlarmWindow",  -- Thunderbird's calendar.
				"pop-up",       -- e.g. Google Chrome's (detached) Developer Tools.
			}
		},
		properties = { floating = true }
	},

	-- Add titlebars to normal clients and dialogs
	{
		rule_any = {
			type = { "normal", "dialog" }
		},
		properties = { titlebars_enabled = true }
	},
	-- Set Firefox to always map on the tag named "2" on screen 1.
	--{
	--rule = { class = "Firefox" },
	--properties = { screen = 1, tag = "2" }
	--},
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c)
	-- Set the windows at the slave,
	-- i.e. put it at the end of others instead of setting it master.
	-- if not awesome.startup then awful.client.setslave(c) end

	if awesome.startup and
		not c.size_hints.user_position
		and not c.size_hints.program_position then
		-- Prevent clients from being unreachable after screen count changes.
		awful.placement.no_offscreen(c)
	end
end)

-- titlebar is per client
local titlebar_style = {
	size = 20,
	bg_focus = beautiful.bg_focus,
	fg_focus  = beautiful.fg_focus,
	bg_normal = beautiful.bg_normal,
	fg_normal = beautiful.fg_normal,
	font = beautiful.font
}

-- Add a titlebar if titlebars_enabled is set to true in the rules.
client.connect_signal("request::titlebars", function(c)
	-- buttons for the titlebar
	local buttons = gears.table.join(
	awful.button({ }, 1, function()
		client.focus = c
		c:raise()
		awful.mouse.client.move(c)
	end),
	awful.button({ }, 3, function()
		client.focus = c
		c:raise()
		awful.mouse.client.resize(c)
	end)
	)

	awful.titlebar(c,titlebar_style) : setup {
		{ -- Left
		--awful.titlebar.widget.iconwidget(c), -- show process icon
		buttons = buttons,
		layout  = wibox.layout.fixed.horizontal
	},
	{ -- Middle
	{ -- Title
	align  = "center",
	widget = awful.titlebar.widget.titlewidget(c)
},
buttons = buttons,
layout  = wibox.layout.flex.horizontal
		},
		{ -- Right
		awful.titlebar.widget.floatingbutton (c),
		awful.titlebar.widget.maximizedbutton(c),
		awful.titlebar.widget.stickybutton   (c),
		awful.titlebar.widget.ontopbutton    (c),
		awful.titlebar.widget.closebutton    (c),
		layout = wibox.layout.fixed.horizontal()
	},
	layout = wibox.layout.align.horizontal
}
end)

-- Enable sloppy focus, so that focus follows mouse.
client.connect_signal("mouse::enter", function(c)
	if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
		and awful.client.focus.filter(c) then
		client.focus = c
	end
end)

client.connect_signal("focus",
function(c) --c.border_color = beautiful.border_focus
end)
client.connect_signal("unfocus",
function(c) c.border_color = beautiful.border_normal
end)
-- }}}
naughty.suspend()
--awful.titlebar.hide()
