local capi = {
	client = client,
	screen = screen,
	tag = tag
}

local tag = require "awful.tag"
local je = require "cjson".encode
local awful = require "awful"
local nau = require "naughty"
local note = nau.notify
local insert = table.insert
local remove = table.remove


local function log(hdr, ...)
	print("\n=============", hdr, "============")
	print(...)
	print("================================\n")
end

local _M = {
	name = "i3",
}

local settings = {
	orientation = "h",
	split_parent = true
}

local function _get_idx(c, a)
	for i,v in ipairs(a) do
		if v == c then return i end
	end
end

local function _get_tag(c)
	while c.parent do c = c.parent end
	return c
end

-----------------------------------------
local function place_client(c)
	log("WA", "x: ", c.workarea.x, "y: ", c.workarea.y, "width: ", c.workarea.width, "height: ", c.workarea.height)
	if not c.geometry then log("no geometry") return end
	c:geometry(c.workarea)
end

local function arrange(p)
	if not p.layout_clients then return end

	for i,c in ipairs(p.layout_clients) do
		if c.layout_clients and #c.layout_clients > 0 then
			arrange(c)
		else
			place_client(c)
		end
	end
end

local function _resize_parent(p, w, h, ignore)
	local cls = p.layout_clients
	local o   = p.orientation
	local div = ignore and (#cls - 1) or #cls
	local wd  = w / div
	local hd  = h / div
	local sx  = p.workarea.x
	local sy  = p.workarea.y
	local wa  = p.workarea

	for i, c in ipairs(cls) do
		local _wa = c.workarea
		if i == ignore then
			_wa.x = sx
			_wa.y = sy
			if p.orientation == "h" then
				sx = sx + _wa.width
			else
				sy = sy + _wa.height
			end
		else
			_wa.width  = o == "h" and _wa.width + wd or wa.width
			_wa.height = o == "h" and wa.height or _wa.height + hd
			_wa.x = sx
			_wa.y = sy
			sx = o == "h" and sx + _wa.width or sx
			sy = o == "h" and sy or sy + _wa.height

			if c.layout_clients and #c.layout_clients > 0 then
				_resize_parent(c, o == "h" and wd or 0, o == "h" and 0 or hd)
			end
		end
	end

	local t = 0
	for i,v in ipairs(p.layout_clients) do
		if p.orientation == "h" then
			t = t + v.workarea.width
		else
			t = t + v.workarea.height
		end
	end

	if p.orientation == "h" then
		if t ~= p.workarea.width then
			log("FAIL")
		end
	end
end

local function remove_client(c)
	local p    = c.parent
	local w, h = c.workarea.width, c.workarea.height
	local cls  = p.layout_clients

	remove(cls, _get_idx(c, cls))

	if #cls == 1 and p ~= _get_tag(p) then
		c = p.layout_clients[1]
		c.workarea = p.workarea
		p.parent.layout_clients[_get_idx(p, p.parent.layout_clients)] = c
		c.parent = p.parent
	else
		_resize_parent(p, w, h)
	end
end

local function _add_client(c, p, pos)
	if not p.layout_clients or not p.workarea then
		p.layout_clients = {}
		p.orientation = settings.orientation
		p.workarea = {}
		for k,v in pairs(p.screen.workarea) do
			p.workarea[k] = v
		end
	end

	local cls  = p.layout_clients
	local wa   = p.workarea
	local clsc = (#cls > 0 and #cls or 0) + 1

	local o      = p.orientation
	local w, h   = wa.width, wa.height
	local wd, hd = w / clsc, h / clsc
	local width, height  = w / clsc, h / clsc

	c.workarea = {
		x = wa.x,
		y = wa.y,
		width  = (o == "h" and width) or w,
		height = (o == "h" and h)     or height,
	}

	c.parent = p
	pos      = pos or clsc
	insert(cls, pos, c)

	if p.orientation == "h" then
		_resize_parent(p, -1*wd, 0, pos)
	elseif p.orientation == "v" then
		_resize_parent(p, 0, -1*hd, pos)
	end
end

local function move_to_parent(c, np, pos)
	remove_client(c)
	_add_client(c, np, pos)
	arrange(awful.screen.focused().selected_tag)
end

local function add_client(c, f, t)
	if c.type == "dialog" then -- popups
		return
	end

	if not t.layout_clients or not t.workarea then
		t.layout_clients = {}
	end
	if #t.layout_clients == 0 then
		t.workarea = t.screen.workarea
	end


	f = f or client.focus
	local p = f and _get_tag(f) == t and f.parent or t
	local pos = (_get_idx(f, p.layout_clients) or #p.layout_clients) + 1

	p.orientation = p.orientation or settings.orientation
	_add_client(c, p, pos)
end

_M.add_client = add_client

-- shared pixels between two clients
local function shared_border(p1,p2,c1,c2)
	if c2 < p1 or c1 > p2 then
		return 0
	else
		if c1 < p1 then c1 = p1 end
		if c2 > p2 then c2 = p2 end
		return (c2 - c1)
	end
end

local function find_dir(dir)
	local c = client.focus
	if not c then
		return
	end
	local clients = _get_tag(c):clients()

	local x,y,w,h = c.workarea.x, c.workarea.y,
	                c.workarea.width, c.workarea.height

	local p1, p2, c1, c2
	if dir == "E" or dir == "W" then
		p1, p2 = y, y+h
	else
		p1, p2 = x, x+w
	end

	local c1, c2, d
	local best, shared, best_shared = nil, 0, 0
	local _wa
	for i,v in ipairs(clients) do
		_wa = v.workarea
		if dir == "W" or dir == "E" then
			d = dir == "W" and (_wa.x + _wa.width) - x or _wa.x - (x + w)
			c1 = v.workarea.y
			c2 = c1 + v.workarea.height
		elseif dir == "N" or dir == "S" then
			d = dir == "N" and (_wa.y + _wa.height) - y or _wa.y - (y + h)
			c1 = v.workarea.x
			c2 = c1 + v.workarea.width
		end

		if -20 < d and d < 20 then
			shared = c1 and c2 and shared_border(p1,p2,c1,c2) or 0
			if shared > best_shared then
				best = v
				best_shared = shared
			end
		end
	end
	if not best then
		dir = dir == "W" and "left" or dir == "E" and "right"
			or dir == "N" and "up" or dir == "S" and "down"
		awful.screen.focus_bydirection(dir, _get_tag(c).screen)
	end
	return best
end

function _M.move_focus(dir)
	local c = find_dir(dir)
	if c then client.focus = c
	else log("no client") end
end

local function swap_clients(c1, c2, arr)
	local idx1, idx2
	for i,v in ipairs(arr) do
		if v == c1 then idx1 = i
		elseif v == c2 then idx2 = i end
	end
	arr[idx1] = c2
	arr[idx2] = c1

	local tmp = c1.workarea

	c1.workarea = c2.workarea
	c2.workarea = tmp

	place_client(c1)
	place_client(c2)
end

function _M.move_client(dir)
	local c = client.focus
	local p = c.parent
	local cls = p.layout_clients

	local c_idx = _get_idx(c, cls)
	local p_idx
	if p.parent then
		p_idx = _get_idx(p, p.parent.layout_clients)
	end

	--prevents empty parents
	--fix so that client is moved aswell
	if #p.layout_clients == 1 and p_idx then
		p.parent.layout_clients[p_idx] = c
		c.parent = p.parent

		p = p.parent
		if p.parent then
			p_idx = _get_idx(p, p.parent.layout_clients)
		else
			p_idx = nil
		end
	end


	if p.orientation == "h" then
		if dir == "E" then
			if c_idx < #cls then
				local n = cls[c_idx + 1]
				if n.layout_clients then
					move_to_parent(c, n)
				else
					swap_clients(c, n, cls)
				end
			elseif p.parent then
				move_to_parent(c, p.parent, p_idx + 1)
			else
				log("unhandeled move")
			end

		elseif dir == "W" then
			log("moving west")
			if c_idx > 1 then
				local n = cls[c_idx - 1]
				if n.layout_clients then
					move_to_parent(c, n)
				else
					swap_clients(c, n, cls)
				end
			elseif p.parent then
				log("moving to parent")
				move_to_parent(c, p.parent, p_idx)
			end
		elseif dir == "S" and p_idx then
			move_to_parent(c, p.parent, p_idx + 1)
		elseif dir == "N" and p_idx then
			move_to_parent(c, p.parent, p_idx)
		end

	elseif p.orientation == "v" then
		if dir == "S" then
			if c_idx < #cls then
				local n = cls[c_idx + 1]
				if n.layout_clients then
					move_to_parent(c, n)
				else
					swap_clients(c, n, cls)
				end
			elseif p.parent then
				move_to_parent(c, p.parent, p_idx + 1)
			end

		elseif dir == "N" then
			if c_idx > 1 then
				local n = cls[c_idx - 1]
				if n.layout_clients then
					move_to_parent(c, n)
				else
					swap_clients(c, n, cls)
				end
			elseif p.parent then
				move_to_parent(c, p.parent, p_idx)
			end

		elseif dir == "E" and p_idx then
			move_to_parent(c, p.parent, p_idx + 1)
		elseif dir == "W" and p_idx then
			log("moving to parent. idx: ", p_idx)
			move_to_parent(c, p.parent, p_idx)
		end

	else
		log("unknown orientation: " .. p.orientation)
	end
end


function _M.split(orientation)
	if orientation ~= "v" and orientation ~= "h" then
		print("Layout.split invalid orientation " .. orientation)
	end

	local focused = client.focus
	if not focused then
		awful.screen.focused().selected_tag.orientation = orientation
		return
	end

	local p = focused.parent
	--settings.split_parent = true
	--parent.orientation = orientation
	local wa = focused.workarea
	local new_parent = {
		workarea = {
			x = wa.x,
			y = wa.y,
			height = wa.height,
			width = wa.width,
		},
		layout_clients = {focused} ,
		orientation = orientation,
		parent = p
	}

	p.layout_clients[_get_idx(focused, p.layout_clients)] = new_parent
	focused.parent = new_parent
	--arrange(_get_tag(parent))
end

function _M.toggle_orientation()
	local c = client.focus
	if not c then
		return
	end

	local p = c.parent
	local o = p.orientation

	if o == "h" then
		p.orientation = "v"
		local h = p.workarea.height / #p.layout_clients
		for i, c in ipairs(p.layout_clients) do
			local wd = p.workarea.width - c.workarea.width
			local hd = h - c.workarea.height
			c.workarea = {
				x = p.workarea.x,
				y = p.workarea.y + (i-1) * h,
				height = h,
				width = p.workarea.width
			}
			if c.layout_clients and #c.layout_clients > 0 then
				_resize_parent(c, wd, hd)
			end
		end

	elseif o == "v" then
		p.orientation = "h"
		local w = p.workarea.width / #p.layout_clients
		for i,c in ipairs(p.layout_clients) do
			local wd = w - c.workarea.width
			local hd = p.workarea.height - c.workarea.height
			c.workarea = {
				x = p.workarea.x + (i-1) * w,
				y = p.workarea.y,
				height = p.workarea.height,
				width = w
			}
			if c.layout_clients and #c.layout_clients > 0 then
				_resize_parent(c, wd, hd)
			end
		end
	end
	arrange(_get_tag(p))
end


local function del_client(c)
	_M.remove_client(c)
end

capi.tag.connect_signal("property::master_width_factor", function() log("master_width_factor")end)
capi.tag.connect_signal("property::master_count", function() log("master_count")end)
capi.tag.connect_signal("property::column_count", function() log("column_count")end)
capi.tag.connect_signal("property::layout", arrange)
capi.tag.connect_signal("property::windowfact", function() log("windowfact")end)
--capi.tag.connect_signal("property::selected", arrange)
capi.tag.connect_signal("property::activated", arrange)
capi.tag.connect_signal("property::useless_gap", function() log("useless_gap")end)
capi.tag.connect_signal("property::master_fill_policy", function() log("master_fill_policy")end)

capi.tag.connect_signal("tagged",
	function(t, c)
		add_client(c, nil, t)
		log("TagName: ", t.name)
		arrange(_get_tag(c))
	end)

capi.tag.connect_signal("untagged",
	function(t, c)
		local old_t = _get_tag(c)
		del_client(c)
		arrange(old_t)
	end)
--capi.tag.connect_signal("tagged",  new_client)
--capi.tag.connect_signal("untagged", del_client)

--capi.client.connect_signal("request::geometry", function(c, cont, ad)
--note{text="Connect"}
--end)
capi.client.connect_signal("manage",
	function(c)
		log("Manage")
		arrange(_get_tag(c))
		client.focus = c
	end)
capi.client.connect_signal("unmanage", function(c) arrange(_get_tag(c)) return end)
capi.screen.connect_signal("property::workarea", function() return end)
--capi.screen.connect_signal("removed",
--function(s)
--for i,t in ipairs(s.tags) do
--t.screen = screen.primary
--t.workarea = t.screen.workarea
--end
--end)



_M.arrange = arrange

local function recurse_clients(t, p)
	for _,c in ipairs(p.layout_clients) do
		local cl = { workarea = c.workarea }
		t[tostring(c.pid)] = cl
		if c.layout_clients and #c.layout_clients > 0 then
			cl.clients = {}
			recurse_clients(cl.clients, c)
		end
	end
end

function _M.serialize()
	local state = {}

	for s in screen do
		_s = {}
		state[s.index] = _s

		for _,t in ipairs(s.tags) do
			_t = {}
			_s[t.name] = _t

			_t.clients = {}
			recurse_clients(_t.clients, t)
		end
	end

	print(require "cjson".encode(state))
end

--[[
local function f(p)
	-- workarea, layout_clients, orientation
	if not p.workarea then log("NO WA")
	elseif not p.orientation then log("NO ORI")
	elseif not p.layout_clients then log("NO clients") end
	local s = {
		workarea = p.workarea,
		orientation = p.orientation or settings.orientation,
		layout_clients = {}
	}
	if not p.layout_clients then return s end
	for i,v in ipairs(p.layout_clients) do
		s.layout_clients[i] = f(v)
	end
	return s
end

local function serialize_parent(p)
	local s = {
		workarea = p.workarea,
		orientation = p.orientation or settings.orientation,
	}
	if p.layout_clients and #p.layout_clients > 0 then
		s.layout_clients = p.layout_clients
		for i,v in ipairs(p.layout_clients) do

		end
	end
end

function _M.serialize()
	local file = io.open("/tmp/layout_serial.lua", "w")
	local s = awful.screen.focused()
	local ser = f(s)
	log("ser", je(ser))

	local serialized =  {}

	file:write(je(ser))
	file:close()

end

local jd = require "cjson".decode
local function r(client)
	for _,c in ipairs(client.layout_clients) do
		if c.layout_clients and #c.layout_clients > 0 then
			r(c)
		else
			log("ADDING CLIENT")
			_M.add_client(c, client)
		end
	end
end


function _M.restore()
	-- get table from file
	local file = io.open("/tmp/layout_serial.lua", "r")
	local t = jd(file:read("*a"))
	local s = awful.screen.focused()
	log("TABLE", je(t))
	r(s)
	--for i,c in ipairs(s.layout_clients) do
	--local o = t[c.pid]
	--c.workarea = o.workarea
	--c.orientation = o.orientation
	--c.parent = t[o.parent_pid]
	--end
end

--]]
_M.remove_client = remove_client
_M.move_to_parent = move_to_parent
--_M.restore()

return _M
