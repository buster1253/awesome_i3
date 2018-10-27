local gears = require "gears"
local awful = require "awful"
local naughty = require "naughty"


-- TODO overwrite the adding of tags using a module function
local _tags = {} 

local function table_length(t) 
	local c = 0
	for _ in pairs(t) do
		if _ then c = c +1 end
	end
	return c
end

local _M = {}

function _M.add_tag(screen, tag_num) 
	local t = _tags[tag_num] or {
				name = screen.index, 
				screen = screen,
				selected = true,
				layout = awful.layout.layouts[1]
			}
	t = awful.tag.add(t.name, t)
	_tags[screen.index] = t
end

local function get_position(tag_name) 
	for i,tag in ipairs(_tags) do
		if tag.name == tag_name then return i end
	end
	return math.huge
end

function _M.view_tag(i)
	-- get the globally uniqe tag:
	local tag = _tags[i]
	if tag and tag.activated then -- move to tag & screen
		local curr_screen = awful.screen.focused()
		local curr_tag = curr_screen.selected_tag
		--local new_screen = awful.tag.getscreen(tag)
		local new_screen = tag.screen
		awful.screen.focus(new_screen)
		tag:view_only()

		-- don't remove the tag if it's the only one remove
		if new_screen.index == curr_screen.index 
			and #curr_screen.tags > 1 
			and table_length(curr_tag:clients()) < 1 then
			--awful.tag.viewtoggle(tag)
			--tag.activated = false
			curr_tag:delete()
		end
	--elseif tag and not tag.activated then
		--tag.activated = true
		--tag:view_only()
	else  -- create the tag and move to current screen
		local s = awful.screen.focused()
		local t = awful.tag.add(i,{screen=s, layout=awful.layout.layouts[1]})
		awful.tag.setlayout(awful.layout.layouts[1], t)
		_tags[i] = t
		-- get_position is used so that named tags may be used in the future
		for ti,tag in ipairs(s.tags) do
			if get_position(tag.name) > i then
				awful.tag.move(ti, t)
			end
		end
		t:view_only()
	end
end

		--if table_length(curr_tag:clients()) < 1 then
			--curr_tag:delete()
		--end
function _M.move_client_to_tag(i)
	if client.focus then
		local tag = _tags[i]
		local c	  = client.focus
		local curr_screen = awful.screen.focused()
		local curr_tag = curr_screen.selected_tag

		if tag and tag.activated then -- move client to tag
			c:move_to_screen(awful.tag.getscreen(tag))
			c:move_to_tag(tag)
			curr_tag:view_only()
		else -- create tag and move client
			local s = awful.screen.focused()
			local t = awful.tag.add(i,{screen=s})
			_tags[i] = t
			c:move_to_tag(t)
		end
		-- keep the current screen in focus
		curr_tag:view_only()
		awful.screen.focus(curr_screen)
	end
end


return _M
