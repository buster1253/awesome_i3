
local capi = {
  client = client,
  screen = screen,
  tag = tag
}

local tag = require "awful.tag"
--local client = require "awful.client"
local je = require "cjson".encode
local awful = require "awful"
local nau = require "naughty"
local note = nau.notify
local parent = require "layout_parent"

local function log(msg)
  if type(msg) ~= "table" then
    msg = {text=msg}
  end
  io.write(je(msg) .. "\n")
end




-- REQUIERED
  --log("HISTORY???", awful.client.focus.history.is_enabled())




local function table_length(t) 
	local c = 0
	for _,v in pairs(t) do
		if v then c = c +1 end
	end
	return c
end

local function log(hdr, ...)
  print("\n=============", hdr, "============")
  print(...)
  print("================================\n")
end

--- MODULE

local tags = {}

local _M = {
  name = "i3",
  orientation = "v",
}

local function add_child(cur, new)
  local cg = cur.geometries
  local ng = new.geometries
  if _M.orientation == "v" then
    local nw = cg.width / 2
    cg.width = nw
    ng.width = nw
    ng.x = cg.x + nw
    ng.y = cg.y
    ng.height = cg.height
  else
    local nh = cg.height / 2
    cg.height = nh
    ng.height = nh
    ng.x = ch.x
    ng.y = cg.y + nh
    ng.width  = cg.width
  end
end

--[[
Special cases:
- first client -> c == screen

--]]

local settings = {
  orientation = "v",
  split_parent = false
}

local was = {}

function _M.new_client(c)
  local t = awful.screen.focused().selected_tag
  local s = t.screen
  awful.client.focus.history.previous() -- awesome moves the focus before calling arrange
  local focused = client.focus


  -- if the client is the only one, screen is set as parent
  if #s.clients < 2 then
    local wa = s.workarea
    c.workarea = {
    --c.workarea = {
      width = wa.width,
      height = wa.height,
      x = wa.x,
      y = wa.y
    }
    c.parent = s
    s.orientation = settings.orientation
    client.focus = c
    c:raise()
    return
  end
 
  -- should always be true if there's more than one client
  if focused then
    local p
    if settings.split_parent then
      p = focused.parent or s
    else
      p = {
        workarea = focused.workarea,
        clients = {focused, c},
        orientation = settings.orientation
      }
      focused.parent = p
    end
    c.parent = p
    
    --local p = focused.parent or s
    if p.orientation == "v" then
      log("width", p.workarea.width)
      local w = p.workarea.width / #p.clients
      for i,c in ipairs(p.clients) do
        c.workarea = {
          x = p.workarea.x + (i-1) * w,
          y = p.workarea.y,
          height = p.workarea.height,
          width = w
        }
      end
    elseif p.orientation == "h" then
      local h = p.workarea.height / #p.clients
      for i,c in ipairs(p.clients) do
        c.workarea = {
          x = p.workarea.x,
          y = p.workarea.y + (i-1) * h,
          height = h,
          width = p.workarea.width
        }
      end
    end
  end
  client.focus = c
  c:raise()
end

function _M.del_client(c)
  print("\n===============DEL===================\n")
  local p = c.parent 
  local o = p.orientation
  local w,h = 0,0
  if o == "v" then
    w = c.workarea.width / (#p.clients) 
  elseif o == "h" then
    h = c.workarea.height / (#p.clients)
  else
    log("MISSING ORIENTATION")
  end

  
  local lx = p.workarea.x
  local ly = p.workarea.y
  local ww = p.workarea.width
  
  for i,cl in ipairs(p.clients) do
    print(i)
    if c == cl then
      table.remove(p.clients, i)
    else
      cl.workarea.x = lx
      cl.workarea.width = cl.workarea.width + w
      cl.workarea.y = ly
      cl.workarea.height = cl.workarea.height + h

      if o == "v" then lx = lx + cl.workarea.width end
      if o == "h" then ly = ly + cl.workarea.height end
      log("WA", je(cl.workarea))
    end
  end
end

local function arrange_parent(p)
  for i=1, #c.clients do
    local c = c.clients[i]
    if c.clients and #c.clients > 0 then
      arrange_parent(c)
    else
      place_client(c)
    end

  end
end

local function place_client(c)
  c:geometry(c.workarea)
end

local function arrange(s)
  local wa  = s.workarea
  local cls = s.clients
  for i=1, #cls do
    local c = cls[i]
    if c.clients and #c.clients > 0 then
      -- client is parent
      arrange_parent(c)
    else
      place_client(c)
    end
  end
end

function _M.toggle_orientation()
  local t = awful.screen.focused().selected_tag
  local s = t.screen
  local focused = client.focus
  local p = focused.parent
  if p.orientation == "v" then 
    p.orientation = "h"
    local h = p.workarea.height / #p.clients
    for i,c in ipairs(p.clients) do
      c.workarea = {
        x = p.workarea.x,
        y = p.workarea.y + (i-1) * h,
        height = h,
        width = p.workarea.width
      }
    end
  elseif p.orientation == "h" then
    p.orientation = "v"
    local w = p.workarea.width / #p.clients
    for i,c in ipairs(p.clients) do
      c.workarea = {
        x = p.workarea.x + (i-1) * w,
        y = p.workarea.y,
        height = p.workarea.height,
        width = w
      }
    end
  end
  for k,v in pairs(s.geometry) do
    print(k)
  end
  log("GEO", s.geometry)
  arrange(s)
end

--local function arrange(s, g)
  --local workarea = s.workarea   -- space to work with
  --local clients = s.clients           -- clients to place
  --local g = g or s.geometries        -- 

  --local num_clients = #clients  -- the amount of clients
  --log("NUM_CLIENTS", num_clients)
  --if num_clients > 1 then
    --for i=1, num_clients do
      --local c = clients[i]
      --if c.clients and #c.clients > 0 then -- client is parent
        --arrange(c, g)
      --end
    --end
  --else
    --log("X", s.geometries.x)
    --g[s] = s.geometries
  --end
--end

--]]



--local function arrange(p) 
  --local wa = p.workarea
  --local cls = p.clients
  --if not p.geometries then
    --return
  --end
  --if #cls > 0 then
    --local t = awful.screen.focused().selected_tag
    --local tag = tags[t] 
    --local w = wa.width / (#cls)

    --print(table_length(tag.clients), "===================")
    --for k,c in pairs(tag.clients) do
      --print("=================",c.x)
    --end
    --for k,c in ipairs(cls) do
      --local g = {
        --width = w,
        --height = wa.height,
        --x= wa.width - (k*w),
        --y = wa.y
      --}
      --p.geometries[c] = g
    --end
  --end
--end


local function new_client(c)
  _M.new_client(c)
  arrange(c.screen)
end

local function del_client(c)
  _M.del_client(c)
  arrange(c.screen)
end

local function arrange_tag(t) 
  arrange(t.screen)
end


--capi.tag.connect_signal("property::master_width_factor", log_shit)
--capi.tag.connect_signal("property::master_count", log_shit)
--capi.tag.connect_signal("property::column_count", log_shit)
--capi.tag.connect_signal("property::layout", log_shit)
--capi.tag.connect_signal("property::windowfact", log_shit)
--capi.tag.connect_signal("property::selected", log_shit)
--capi.tag.connect_signal("property::activated", log_shit)
--capi.tag.connect_signal("property::useless_gap", log_shit)
--capi.tag.connect_signal("property::master_fill_policy", log_shit)
capi.tag.connect_signal("tagged", arrange_tag)

capi.client.connect_signal("request::geometry", function(c, cont, ad)
  note{text="Connect"}
end)
capi.client.connect_signal("manage", new_client)
capi.client.connect_signal("unmanage", del_client)
capi.screen.connect_signal("property::workarea", function() return end)


_M.arrange = arrange


return _M
