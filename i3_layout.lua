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

-----------------------------------------
local function place_client(c)
  --log("WA", je(c.workarea))
  if not c.geometry then return end
  c:geometry(c.workarea)
end

local function arrange_parent(p)
  for i=1, #p.layout_clients do
    local c = p.layout_clients[i]
    if c.layout_clients and #c.layout_clients > 0 then
      arrange_parent(c)
    else
      place_client(c)
    end
  end
end


local function arrange(s)
  if not s.layout_clients then return end
  local cls = s.layout_clients
  for i=1, #cls do
    local c = cls[i]
    if c.layout_clients and #c.layout_clients > 0 then
      arrange_parent(c)
    else
      place_client(c)
    end
  end
end

-------------------------------------
function _M.new_client(c, f)
  local s = awful.screen.focused()
  if not s.layout_clients then s.layout_clients = {} end
  awful.client.focus.history.previous() -- awesome moves the focus before calling arrange
  local focused = f or client.focus

  -- if the client is the only one, screen is set as parent
  if #s.clients == 1 then
    local wa = s.workarea
    c.workarea = {
      width = wa.width,
      height = wa.height,
      x = wa.x,
      y = wa.y,
    }
    c.parent = s
    s.orientation = s.orientation or settings.orientation
    client.focus = c
    table.insert(s.layout_clients, c)
    return
  end
 
  -- should always be true if there's more than one client
  if focused then
    local p
    if settings.split_parent then
      p = focused.parent
    else
      p = {
        workarea = focused.workarea,
        layout_clients = {focused},
        orientation = settings.orientation,
        parent = focused.parent
      }
      for i,v in ipairs(focused.parent.layout_clients) do
        if v == focused then
          focused.parent.layout_clients[i] = p
          break
        end
      end
      focused.parent = p
    end

    c.parent = p
    table.insert(p.layout_clients, c)
    --local p = focused.parent or s
    if p.orientation == "h" then
      local w = p.workarea.width / #p.layout_clients
      for i,c in ipairs(p.layout_clients) do
        c.workarea = {
          x = p.workarea.x + (i-1) * w,
          y = p.workarea.y,
          height = p.workarea.height,
          width = w
        }
      end
    elseif p.orientation == "v" then
      local h = p.workarea.height / #p.layout_clients
      for i,c in ipairs(p.layout_clients) do
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
end
local move_to_parent
local function _resize_parent(p, w, h)
  log("RESIZE:", w, h)
  local wd = w / #p.layout_clients
  local hd = h / #p.layout_clients
  local sx = p.workarea.x
  local sy = p.workarea.y
  for i,c in ipairs(p.layout_clients) do
    local _wa = c.workarea
    log("WA_pre", je(_wa))
    if p.orientation == "h" then
      _wa.width = _wa.width + wd
      _wa.x = sx
      _wa.y = sy
      _wa.height = p.workarea.height
      sx = sx + _wa.width
    else
      _wa.height = _wa.height + hd
      _wa.y = sy
      _wa.x = sx
      _wa.width = p.workarea.width
      sy = sy + _wa.height
    end
    if c.layout_clients and #c.layout_clients > 0 then
      _resize_parent(c, wd, hd)
    end
    log("WA"..i, je(_wa))
  end
end

-- removes the client from the parent
local function _remove_client(c) 
  local p = c.parent
  local w = c.workarea.width
  local h = c.workarea.height
  table.remove(p.layout_clients, _get_idx(c, p.layout_clients))
  _resize_parent(p, w, h)
  if #p.layout_clients == 0 and p ~= awful.screen.focused() then
    _remove_client(p)
  end
end

-- adds client to the parent
local function _add_client(c, p)
  log("ADDING CLIENT")
  local cls = p.layout_clients
  local _w = p.workarea.width
  local _h = p.workarea.height
  if #cls > 0 then
    _w = _w / #cls
    _h = _h / #cls
  end
  table.insert(cls, c)
  c.parent = p
  if p.orientation == "h" then
    _resize_parent(p, -1*_w, 0)
  else
    _resize_parent(p, 0, -1*_h)
  end
end


function move_to_parent(c, np)
  _remove_client(c)
  _add_client(c,np)
  arrange(awful.screen.focused())
end

function _M.del_client(c)
  log("DEL CLIENT")
  local p = c.parent
  local cls = p.layout_clients
  _remove_client(c)
  if #cls == 0 then
    if p.parent then
      --move_to_parent(cls[1], p.parent)
    end
    if p ~= awful.screen.focused() then
      _M.del_client(p)
    end
  end
end

local function find_dir(dir)
  local s = awful.screen.focused()
  local c = client.focus
  local clients = s.clients

  local x = c.workarea.x
  local y = c.workarea.y
  local w = c.workarea.width
  local h = c.workarea.height

  if dir == "W" then
    for i,v in ipairs(clients) do
      if v.workarea.x + v.workarea.width == x then
        return v
      end
    end
  elseif dir == "E" then
    for i,v in ipairs(clients) do
      if v.workarea.x == x + w then
        return v
      end
    end
  elseif dir == "N" then
    for i,v in ipairs(clients) do
      if v.workarea.y + v.workarea.height == y then
        return v
      end
    end
  elseif dir == "S" then
    for i,v in ipairs(clients) do
      if v.workarea.y == y + h then
        return v
      end
    end
  end
end

function _M.move_focus(dir)
  local c = find_dir(dir)
  if c then
    client.focus = c
  end
end

function _M.move_client(dir)
  log("MOVE CLIENT")
  local c = client.focus
  local n = find_dir(dir)
  if not n then return end

  if n.parent == c.parent then -- move idx
    local cls = c.parent.layout_clients
    local c_idx, n_idx
    for i,v in ipairs(cls) do
      if v == c then c_idx = i
      elseif v == n then n_idx = i end
    end
    cls[c_idx] = n
    cls[n_idx] = c
    local x0, y0
    if c_idx < n_idx then
      if c.parent.orientation == "h" then
        x0 = c.workarea.x
        n.workarea.x = x0
        c.workarea.x = x0 + n.workarea.width
      else
        y0 = c.workarea.y
        n.workarea.y = y0
        c.workarea.y = y0 + n.workarea.height
      end
    else
      if c.parent.orientation == "h" then
        x0 = n.workarea.x
        c.workarea.x = x0
        n.workarea.x = x0 + c.workarea.width
      else
        y0 = n.workarea.y
        c.workarea.y = y0
        n.workarea.y = y0 + c.workarea.height
      end
    end
    place_client(c)
    place_client(n)
  else
    if c.parent.parent then
      move_to_parent(c, c.parent.parent)
    end
  end
end

--function _M.split(o)
  --if o ~= "v" and o ~= "h" then 
    --print("Layout.split invalid orientation " .. o)
  --end
  --local s = awful.screen.focused()
  --local f = client.focus
  --if not f then
    --s.orientation = o
    --return
  --end
  --local parent = f.parent
  --settings.split_parent = true
  ----parent.orientation = orientation
  --local new_parent = {
    --workarea = f.workarea,
    --layout_clients = {},
    --orientation = o,
    --parent = f.parent
  --}
  --move_to_parent(f, new_parent)
  ----_remove_client(f)
  --log("REMOVED")
  --_add_client(new_parent, parent)
  ----_add_client(f, new_parent)
  ----for i,v in ipairs(parent.layout_clients) do
    ----if v == f then
      ----parent.layout_clients[i] = new_parent
      ----break
    ----end
  ----end
  ----f.parent = new_parent
  ----arrange(s)
--end

function _M.split(orientation)
  if orientation ~= "v" and orientation ~= "h" then 
    print("Layout.split invalid orientation " .. orientation)
  end
  local s = awful.screen.focused()
  local focused = client.focus
  if not focused then
    log("_M.split() -- THIS IS NOT SUPPOSED TO HAPPEN")
    s.orientation = orientation
    return
  end
  local parent = focused.parent
  settings.split_parent = true
  --parent.orientation = orientation
  local new_parent = {
    workarea = focused.workarea,
    layout_clients = {focused} ,
    orientation = orientation,
    parent = focused.parent
  }
  for i,v in ipairs(parent.layout_clients) do
    if v == focused then
      parent.layout_clients[i] = new_parent
      break
    end
  end
  focused.parent = new_parent
  arrange(s)
end

--TODO recurse children
function _M.toggle_orientation()
  local s = awful.screen.focused()
  local focused = client.focus
  local p = focused.parent
  if p.orientation == "h" then 
    p.orientation = "v"
    local h = p.workarea.height / #p.layout_clients
    for i,c in ipairs(p.layout_clients) do
      c.workarea = {
        x = p.workarea.x,
        y = p.workarea.y + (i-1) * h,
        height = h,
        width = p.workarea.width
      }
    end
  elseif p.orientation == "v" then
    p.orientation = "h"
    local w = p.workarea.width / #p.layout_clients
    for i,c in ipairs(p.layout_clients) do
      c.workarea = {
        x = p.workarea.x + (i-1) * w,
        y = p.workarea.y,
        height = p.workarea.height,
        width = w
      }
    end
  end
  arrange(s)
end

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

local function f(p)
  -- workarea, layout_clients, orientation
  log("DHWUAHD")
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
      _M.new_client(c, client)
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

--_M.restore()

return _M
