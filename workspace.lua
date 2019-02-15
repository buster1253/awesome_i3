local awful = require "awful"
local gears = require "gears"
local nau = require "naughty"
local wibox = require "wibox"
--local i3_layout = require "i3_layout"

local _M = {}

local function get_position(tag_name, tags, screen_id)
	local j = 0
	for i=1, 9 do
		local tag = tags[i]
		if tag and tag.activated and tag.screen.index == screen_id then
			j = j + 1
			if tag.name == tag_name then return j end
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

workspaces = {
	workspace = {
		tags
	}
}

function _M:new_ws(name)
	local ws = {}
	self.workspaces[name] = ws

	for s in screen do
		local t = awful.tag.add(s.index, {screen=s, layout=i3_layout})
		ws[s.index] = t
		t.activated = false
	end
	return ws
end

function _M:swap_ws(name)
	name = string.lower(tostring(name))
	local next_ws = self.workspaces[name] or self:new_ws(name)

	--for s in screen do
		--log("s.index: " .. s.index)
		--if s.wsname then
			--s.wsname:set_markup_silently(tostring(name))
		--end
	--end

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
			--t:clients(t:clients())
			t.activated = true
			awful.screen.focus(t.screen)
			t:view_only()
		end
	end
end

function _M:view_tag(i)
	i = tonumber(i)
	local tags = self.workspaces[self.current]
	local tag = tags[i]
	local c_screen = awful.screen.focused()
	local n_screen = tag and tag.screen or c_screen
	local c_tag = c_screen.selected_tag
	local c = client.focus

	c_tag.focused = c
	if tag then
		if tag.name == c_tag.name then return end
		if not tag.activated then
			tag.screen = c_screen
			--i3_layout.change_screen(tag, c_screen)
		end
		awful.screen.focus(tag.screen)
		tag.activated = true
	else  -- create the tag and move to current screen
		tag = awful.tag.add(i,{screen=c_screen, layout=layout})
		tags[i] = tag
	end
	tag.index = get_position(tag.name, tags, c_screen.index)
	tag:view_only()
	--client.focus = tag.focused
	if n_screen.index == c_screen.index
		and self:count_tags(c_screen.index) > 1
		and #c_tag:clients() < 1 then
		c_tag.activated = false
	end
end

function _M:move_client_to_tag(i, c)
	i = tonumber(i)
	if client.focus then
		local tags = self.workspaces[self.current]
		local tag  = tags[i]
		local c    = c or client.focus
		local c_screen = awful.screen.focused()
		local c_tag = c_screen.selected_tag

		if tag then -- move client to tag
			if tag.name == c_tag.name then return end
			tag.activated = true
			c:move_to_screen(tag.screen)
			c:move_to_tag(tag)
		else -- create tag and move client
			tag = awful.tag.add(i,{screen=c_screen,layout=layout})
			tags[i] = tag
			c:move_to_tag(tag)
		end
		--i3_layout.move_to_parent(c, tag)
		-- keep the current screen in focus
		c_tag:view_only()
		awful.screen.focus(c_screen)
		--i3_layout.focus(c_tag)
	end
end

function _M:count_tags(screen_id)
	local c = 0
	for _,t in pairs(self.workspaces[self.current]) do
		if t.screen.index == screen_id then c = c + 1 end
	end
	return c
end

function _M:remove_screen(s)
	for _, ws in pairs(self.workspaces) do
		for _, tag in pairs(ws.tags) do
			if tag.screen == s then
				tag.screen = screen.primary
			end
		end
	end
end

function _M:move_tag_to_screen(t, s)
	-- assign tag to new screen
	-- move tag workarea to screen workarea
	local c_tag = s.selected_tag
	t.screen = s
	if c_tag then
		c_tag:view_only()
	end
	--s.selected_tag:view_only()
	--awful.screen.focus(s)
end

function _M:new_screen(s)
	for name,ws in pairs(self.workspaces) do
		local t = ws[s.index]
		if t then
			self:move_tag_to_screen(t, s)
			t:view_only()
		else
			local tag = awful.tag.add(s.index,{screen=s,layout=layout})
			ws[s.index] = tag
			tag.activated = true
			tag:view_only()
		end

		if s.wsname then
			s.wsname:set_markup_silently(tostring(name))
		end
	end
end

function _M:assign_tag(s, tag)
	for _,ws in pairs(self.workspaces[self.current]) do
		if ws[tag] then
			t.screen = s
		else
			self:view_tag(tag) -- TODO not this
		end
	end
end

return _M.init()
