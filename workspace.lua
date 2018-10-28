local awful = require "awful"
local gears = require "gears"
local tags = require "tags"
local nau = require "naughty"



local _M = {}

local function get_position(tag_name, tags) 
	for i,tag in ipairs(_tags) do
		if tag and tag.name == tag_name then return i end
	end
	return math.huge
end

local function table_length(t) 
	local c = 0
	for _ in pairs(t) do
		if _ then c = c +1 end
	end
	return c
end

function _M.init()
	local ws = {}
	for s in screen do 
		local t = awful.tag.add(s.index, {screen=s,
				layout=awful.layout.layouts[2]})
		ws[s.index] = t
		t:view_only()
	end
	

	local mt = setmetatable({
		workspaces = {ws},
		current = 1
	}, {__index = _M})
	mt:swap_ws(1)
	return mt
end


function _M:add_workspace()
	local ws_number = #self.workspaces + 1
	local ws = {}

	for s in screen do
		local t = awful.tag.add(s.index, {screen=s, layout=awful.layout.layouts[2]})
		ws[s.index] = t
		t:clients({})
		t.activated = false
	end
	self.workspaces[ws_number] = ws
end

function _M:new_ws(name)
	local ws = {}
	self.workspaces[name] = ws

	for s in screen do
		local t = awful.tag.add(s.index, 
			{screen=s, layout=awful.layout.layouts[2]}
		)
		ws[s.index] = t
		t:clients({})
		t.activated = false
	end
	return ws
end

function _M:swap_ws(name)
	name = string.lower(name)
	local next_ws = self.workspaces[name] or self:new_ws(name)

	for s in screen do
		s.myworkspacename:set_markup_silently(tostring(name))
	end

	local active_ws = self.workspaces[self.current]

	for i=1, 9 do
		local t = active_ws[i]
		if t then 
			t.activated = false
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
		--for ti,tag in ipairs(s.tags) do
			--if get_position(tag.name, tags) > i then
				--awful.tag.move(ti, t)
			--end
		--end
		t:view_only()
	end
end



return _M