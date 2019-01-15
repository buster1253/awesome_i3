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
local insert = table.insert
local remove = table.remove

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
  --log("_get_idx: no result")
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
  log("arrange")
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

local function _resize_parent(p, w, h, ignore)
  log("resize_parent", "w" ..w, "h" .. h)
  local cls = p.layout_clients
  local clsc = #p.layout_clients
  local o = p.orientation
  local wd, hd
  if ignore then
    wd = w / (clsc - 1)
    hd = h / (clsc - 1)
  else
    wd = w / clsc
    hd = h / clsc
  end

  local sx = p.workarea.x
  local sy = p.workarea.y

  for i,c in ipairs(p.layout_clients) do
    local _wa = c.workarea
    if i == ignore then
      _wa.x = sx
      _wa.y = sy
      if p.orientation == "h" then sx = sx + _wa.width
      else sy = sy + _wa.height end
    else
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
      log("wa" .. i, je(_wa))
      if c.layout_clients and #c.layout_clients > 0 then
        if o == "h" then
          _resize_parent(c, wd, 0)
        else
          _resize_parent(c, 0, hd)
        end
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

local function _add_client(c, p, pos)
  if not p.layout_clients or not p.workarea then
    local s_wa = p.screen.workarea
    p.layout_clients = {}
    p.workarea = {
      x = s_wa.x,
      y = s_wa.y,
      width = s_wa.width,
      height = s_wa.height
    }
    p.orientation = "h"
  end

  local cls = p.layout_clients
  pos = pos or #cls + 1
  local w = p.workarea.width
  local h = p.workarea.height
  local o = p.orientation
  local wd, hd, width, height

  if pos > 1 then
    insert(cls, pos, c)
    wd = w / #cls 
    hd = h / #cls
    width  = w / #cls
    height = h / #cls
  else
    insert(cls, c)
    wd = w
    hd = h
    width  = w
    height = h
  end

  c.workarea = {
    x = 0, -- TODO set to parent x and y
    y = 0,
    width = ((o == "h" and width) or w),
    height = ((o == "h" and h) or (height)),
  }

  c.parent = p
  if p.orientation == "h" then
    _resize_parent(p, -1*wd, 0, pos)
  elseif p.orientation == "v" then
    _resize_parent(p, 0, -1*hd, pos)
  else log("add_client: bad orientation: " .. (p.orientation or "")) end
  client.focus = c
end


local function elder_tag(c)
  while c.parent do c = c.parent end
  return c
end
-- removes the client from the parent
local function remove_client(c) 
  local p = c.parent
  local w = c.workarea.width
  local h = c.workarea.height
  local idx = _get_idx(c, p.layout_clients)

  remove(p.layout_clients, idx)
  if #p.layout_clients == 1 and p ~= awful.screen.focused().selected_tag then
    local pos = _get_idx(p, p.parent.layout_clients)
    local cl = p.layout_clients[1]
    cl.workarea = p.workarea
    p.parent.layout_clients[pos] = cl
    cl.parent = p.parent
  else
    _resize_parent(p, w, h)
  end
  arrange(elder_tag(p))
  awful.client.focus.history.previous()
end

function move_to_parent(c, np, pos)
  remove_client(c)
  _add_client(c, np, pos)
  arrange(awful.screen.focused().selected_tag)
end

function _M.change_screen(t, s)
  t.workarea = s.workarea
end

function _M.add_client(c, f, t)
  local s = awful.screen.focused()
  if t and t.layout_clients and t.workarea then
    s.selected_tag.focused = client.focus
    s = t.screen
  else
    t = s.selected_tag
    awful.client.focus.history.previous() -- focus is already on new client
  end

  if not c.workarea then
    c.workarea = {x=0,y=0,height=0,width=0}
  end

  f = f or client.focus
  local p, pos
  if t.layout_clients and t.workarea and f and f.parent then
    p = f.parent
    pos = (_get_idx(f, p.layout_clients) or 0) + 1
    if #t.layout_clients == 0 then
      t.workarea = s.workarea
    end
  else
    pos = 1
    t.layout_clients = t.layout_clients or {}
    t.workarea = t.workarea or s.workarea
    p = t
  end

  p.orientation = p.orientation or settings.orientation
  _add_client(c, p, pos)
  --client.focus = c -- move to workspaces
end

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
  local s = awful.screen.focused()
  local c = client.focus
  local clients = s.clients

  local x,y,w,h = c.workarea.x, c.workarea.y, 
                  c.workarea.width, c.workarea.height

  local p1, p2, c1, c2
  if dir == "E" or dir == "W" then
    p1, p2 = y, y+h
  else
    p1, p2 = x, x+w
  end

  local e1, e2, d
  local best, shared, best_shared = nil, 0, 0
  for i,v in ipairs(clients) do
    if dir == "W" then
      d = (v.workarea.x + v.workarea.width) - x
      c1 = v.workarea.y
      c2 = c1 + v.workarea.height
    elseif dir == "E" then
      d = v.workarea.x - (x + w)
      c1 = v.workarea.y
      c2 = c1 + v.workarea.height
    elseif dir == "N" then
      d = (v.workarea.y + v.workarea.height) - y
      c1 = v.workarea.x
      c2 = c1 + v.workarea.height
    elseif dir == "S" then
      d = v.workarea.y - (y + h)
      c1 = v.workarea.x
      c2 = c1 + v.workarea.height
    end
    if -20 < d and d < 20 then
      shared = c1 and c2 and shared_border(p1,p2,c1,c2) or 0
      if shared > best_shared then
        best = v
        best_shared = shared
      end
    end
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

  if p.orientation == "h" then
    if dir == "E" then
      if c_idx < #cls then
        local n = cls[c_idx + 1]
        if n.layout_clients then
          move_to_parent(c, n)
        else
          swap_clients(c, n, cls)
          place_client(c)
          place_client(n)
        end
      elseif p.parent then
        move_to_parent(c, p.parent, p_idx + 1) 
      else
        log("unhandeled move")
      end

    elseif dir == "W" then
      if c_idx > 1 then
        local n = cls[c_idx - 1]
        if n.layout_clients then
          move_to_parent(c, n)
        else
          swap_clients(c, n, cls)
          place_client(c)
          place_client(n)
        end
      elseif p.parent then
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
          place_client(c)
          place_client(n)
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
          place_client(c)
          place_client(n)
        end
      elseif p.parent then
        move_to_parent(c, p.parent, p_idx)
      end

    elseif dir == "E" and p_idx then
      move_to_parent(c, p.parent, p_idx + 1)
    elseif dir == "W" and p_idx then
      move_to_parent(c, p.parent, p_idx)
    end

  else
    log("unknown orientation: " .. p.orientation)
  end
end


--function _M.move_client(dir)
  --log("move_client: "..dir)
  --local c = client.focus
  --local n = find_dir(dir)
  --local p = c.parent

  --if not n then 
    --return log("no n")
  --end -- TODO check if screen in dir
  --log("found n")

  --if p == n.parent then -- move inside 
    --local cls = p.layout_clients
    --swap_clients(c, n, cls)
    --place_client(c)
    --place_client(n)
  --elseif p.parent then
    --local pos = _get_idx(p, p.parent.layout_clients)
    --if dir == "E" or dir == "S" then
      --pos = pos + 1
    --end
    --move_to_parent(c, p.parent, pos)
  --else 
    --local tmp_p = n.parent.parent
    --while tmp_p do
      --if _get_idx(c, tmp_p.layout_clients) then
        --break
      --else
        --tmp_p = tmp_p.parent
      --end
    --end

    --log("else condition")
  --end
--end

function _M.split(orientation)
  if orientation ~= "v" and orientation ~= "h" then 
    print("Layout.split invalid orientation " .. orientation)
  end

  local s = awful.screen.focused()
  local t = s.selected_tag

  local focused = client.focus
  if not focused then
    s.orientation = orientation
    return
  end

  local parent = focused.parent
  settings.split_parent = true
  --parent.orientation = orientation
  local f_wa = focused.workarea
  local new_parent = {
    workarea = {
      x = f_wa.x,
      y = f_wa.y,
      height = f_wa.height,
      width = f_wa.width,
    },
    layout_clients = {focused} ,
    orientation = orientation,
    parent = focused.parent
  }

  parent.layout_clients[_get_idx(focused, parent.layout_clients)] = new_parent
  focused.parent = new_parent
  --arrange(elder_tag(parent))
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

function _M.focus(t)
  log("focus: ".. t.name)
  client.focus = t.focused
  arrange(t)
end

local function new_client(c)
  _M.add_client(c)
  arrange(c.screen.selected_tag)
end

local function del_client(c)
  log("del_client")
  _M.remove_client(c)
  --arrange(c.screen.selected_tag)
end

local function arrange_tag(t)
  arrange(t)
end

capi.tag.connect_signal("property::master_width_factor", function() log("master_width_factor")end)
capi.tag.connect_signal("property::master_count", function() log("master_count")end)
capi.tag.connect_signal("property::column_count", function() log("column_count")end)
capi.tag.connect_signal("property::layout", arrange_tag)
capi.tag.connect_signal("property::windowfact", function() log("windowfact")end)
capi.tag.connect_signal("property::selected", arrange_tag)
capi.tag.connect_signal("property::activated", arrange_tag)
capi.tag.connect_signal("property::useless_gap", function() log("useless_gap")end)
capi.tag.connect_signal("property::master_fill_policy", function() log("master_fill_policy")end)
capi.tag.connect_signal("tagged",  arrange)
capi.tag.connect_signal("untagged", arrange)

--capi.client.connect_signal("request::geometry", function(c, cont, ad)
  --note{text="Connect"}
--end)
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

_M.remove_client = remove_client
_M.move_to_parent = move_to_parent
--_M.restore()

return _M
