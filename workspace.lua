local awful = require "awful"
local gears = require "gears"
local nau = require "naughty"
local wibox = require "wibox"

local _M = {}

local function get_position(tag_name, tags) 
	local j = 0
	for i=1, 9 do
		local tag = tags[i]
		if tag then j = j + 1 end
		if tag and tag.name == tag_name then 
			nau.notify{text="i:" .. j}
			return j 
		end
	end
	return 9 
end

local function table_length(t) 
	local c = 0
	for _ in pairs(t) do
		if _ then c = c +1 end
	end
	return c
end

local mt
local initialized = false


function _M.init()
  if initialized then return mt end
	mt = setmetatable({
		workspaces = {},
		current = 1
	}, {__index = _M})
  initialized = true
	return mt
end


function _M:list_ws()
	local s = ""
	local len = table_length(self.workspaces)
	local i = 1
	for ws,_ in pairs(self.workspaces) do
		if i == len then s = s .. ws break end
		s = s .. ws .. "<br>" 
		i = i + 1
	end
	nau.notify{text = s}
end

function _M:new_ws(name)
	local ws = {}
	self.workspaces[name] = ws

	for s in screen do
		local t = awful.tag.add(s.index, 
			{screen=s, layout=awful.layout.layouts[2]}
		)
		ws[s.index] = t
		t.activated = false
	end
	return ws
end

function _M:swap_ws(name)
	name = string.lower(tostring(name))
	local next_ws = self.workspaces[name] or self:new_ws(name)
	
	for s in screen do
		s.myworkspacename:set_markup_silently(tostring(name))
	end

	local active_ws = self.workspaces[self.current]
	if active_ws then
		for i=1, 9 do
			local t = active_ws[i]
			if t then 
				t.activated = false
			end
		end
	end

	self.current = name
	for i=1, 9 do
		local t = next_ws[i]
		if t then 
			--self:view_tag(i)
			t:clients(t:clients())
			t.activated = true
			awful.screen.focus(t.screen)
			t:view_only()
		end
	end
end


function _M:view_tag(i)
	local tags = self.workspaces[self.current]
	local tag = tags[i]
	if tag and tag.activated then -- move to tag & screen
		local curr_screen = awful.screen.focused()
		local curr_tag = curr_screen.selected_tag
		--local new_screen = awful.tag.getscreen(tag)
		local new_screen = tag.screen
		awful.screen.focus(new_screen)
		tag:view_only()
		
		--tag:clients({})
		--curr_tag:clients(clients)

		--nau.notify({ preset = nau.config.presets.critical,
				--title = "client tag",
				--text = client[1].tag })

		-- don't remove the tag if it's the only one remove
		if new_screen.index == curr_screen.index 
			and #curr_screen.tags > 1 
			and table_length(curr_tag:clients()) < 1 then
			--tag.activated = false
		end
	elseif tag and not tag.activated then
		tag.activated = true
		tag:view_only()
	else  -- create the tag and move to current screen
		local s = awful.screen.focused()
		local t = awful.tag.add(i,{screen=s, layout=awful.layout.layouts[2]})
		tags[i] = t
		-- get_position is used so that named tags may be used in the future
		awful.tag.move(get_position(t.name, tags), t)

		t:view_only()
	end
end

function _M:move_client_to_tag(i)
	local tags = self.workspaces[self.current]
	if client.focus then
		local tag = tags[i]
		local c	  = client.focus
		local curr_screen = awful.screen.focused()
		local curr_tag = curr_screen.selected_tag

		if tag and tag.activated then -- move client to tag
			c:move_to_screen(awful.tag.getscreen(tag))
			c:move_to_tag(tag)
			curr_tag:view_only()
			-- TODO if not activated
		else -- create tag and move client
			local s = awful.screen.focused()
			local t = awful.tag.add(i,{screen=s,layout=awful.layout.layouts[2]})
			tags[i] = t
			c:move_to_tag(t)
		end
		-- keep the current screen in focus
		curr_tag:view_only()
		awful.screen.focus(curr_screen)
	end
end


return _M.init()
