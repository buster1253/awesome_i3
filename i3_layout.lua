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
  log("_get_idx: no result")
  return 0
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
  log("_resize_parent", "w: " .. w, "h: " .. h)
  local wd = w / #p.layout_clients
  local hd = h / #p.layout_clients
  local sx = p.workarea.x
  local sy = p.workarea.y
  log("clients:" .. #p.layout_clients)
  log("wd:" .. wd .. " hd: " .. hd)

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
      if c.layout_clients and #c.layout_clients > 0 then
        _resize_parent(c, wd, hd)
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
-- adds client to the parent
--[[
Client:
 - workarea
 - parent
--]]
local function _add_client(c, p, pos)
  local cls = p.layout_clients
  pos = pos or #cls
  local w = p.workarea.width
  local h = p.workarea.height
  local o = p.orientation

  if pos > 0 then
    log("greater than 0")
    wd = w / #cls
    hd = h / #cls
    insert(cls, pos, c)
    width = wd
    height = hd
  else
    wd = w
    hd = h
    insert(cls, c)
    width  = w
    height = h
  end

  local wa = p.workarea
  c.workarea = {
    x = 0,
    y = 0,
    width = ((o == "h" and width) or w),
    --height = ((o == "h" and h) or (height)),
    --width = 200, 
    height = 100,
  }
  log("workarea", je(c.workarea))
  log("wd" .. wd .. " hd: " ..hd)
  c.parent = p
  if p.orientation == "h" then
    _resize_parent(p, -1*wd, 0, pos + 1)
  elseif p.orientation == "v" then
    _resize_parent(p, 0, -1*hd, pos + 1)
  else log("add_client: bad orientation: " .. (p.orientation or "")) end
end


local function elder_tag(c)
  while c.parent do c = c.parent end
  return c
end
-- removes the client from the parent
local function remove_client(c) 
  log("remove_client")
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
  --arrange(elder_tag(p))
end

function move_to_parent(c, np, pos)
  remove_client(c)
  _add_client(c, np, pos)
  arrange(awful.screen.focused().selected_tag)
end

-------------------------------------
function _M.new_client(...)
  log("new_client() is deprecated use add_client()")
  _M.add_client(...)
end

function _M.add_client(c, f, t)
  local s = awful.screen.focused()
  if t then
    s.selected_tag.focused = client.focus
    s = t.screen
  else
    t = s.selected_tag
    awful.client.focus.history.previous() -- focus is already on new client
  end

  if not c.workarea then
    c.workarea = {x=0,y=0,height=0,width=0}
  end

  --if not t.layout_clients then t.layout_clients = {} end
  --if not t.workarea then t.workarea = s.workarea end
  f = f or client.focus
  local p
  if t.layout_clients and t.workarea and f and f.parent then
    p = f.parent
  else
    t.layout_clients = t.layout_clients or {}
    t.workarea = t.workarea or s.workarea
    p = t
  end

  p.orientation = p.orientation or settings.orientation
  _add_client(c, p, pos)
  client.focus = c -- move to workspaces




  --if #t.layout_clients == 0 then -- first client: tag is parent
    --log("fresh tag")
    --local wa = t.workarea
    --c.workarea = {
      --width = wa.width,
      --height = wa.height,
      --x = wa.x,
      --y = wa.y,
    --}
    --c.parent = t
    --t.orientation = t.orientation or settings.orientation
    --insert(t.layout_clients, c)
    --client.focus = c
    --return
  --else
    --local focused = f or client.focus
    --local p
    --if not focused then
      --p = t
    --elseif settings.split_parent then 
      --p = focused.parent
      --if not p then log("no parent") end
    --else
      --p = {
        --workarea = focused.workarea,
        --layout_clients = {focused},
        --orientation = settings.orientation,
        --parent = focused.parent
      --}

      --local f_idx = _get_idx(focused, focused.parent.layout_clients)
      --focused.parent.layout_clients[f_idx] = p
      --focused.parent = p
    --end

    --c.parent = p
    --insert(p.layout_clients, c)
    --if p.orientation == "h" then
      --local w = p.workarea.width / #p.layout_clients
      --for i,c in ipairs(p.layout_clients) do
        --c.workarea = {
          --x = p.workarea.x + (i-1) * w,
          --y = p.workarea.y,
          --height = p.workarea.height,
          --width = w
        --}
      --end
    --elseif p.orientation == "v" then
      --local h = p.workarea.height / #p.layout_clients
      --for i,c in ipairs(p.layout_clients) do
        --c.workarea = {
          --x = p.workarea.x,
          --y = p.workarea.y + (i-1) * h,
          --height = h,
          --width = p.workarea.width
        --}
      --end
    --end
  --end
  --client.focus = c
end
-- DOING: 
--   add optional tag argument
--function _M.add_client(c, f, t)
  --local s = awful.screen.focused()
  --if t then
    --s.selected_tag.focused = client.focus
    --s = t.screen
  --else
    --t = s.selected_tag
    --awful.client.focus.history.previous() -- focus is already on new client
  --end

  --if not t.layout_clients then t.layout_clients = {} end
  --if not t.workarea then t.workarea = s.workarea end
  --f = f or client.focus
  --if t.layout_clients and t.workarea and f then
    --parent = f.parent
  --else

  --if #t.layout_clients == 0 then -- first client: tag is parent
    --log("fresh tag")
    --local wa = t.workarea
    --c.workarea = {
      --width = wa.width,
      --height = wa.height,
      --x = wa.x,
      --y = wa.y,
    --}
    --c.parent = t
    --t.orientation = t.orientation or settings.orientation
    --insert(t.layout_clients, c)
    --client.focus = c
    --return
  --else
    --local focused = f or client.focus
    --local p
    --if not focused then
      --p = t
    --elseif settings.split_parent then 
      --p = focused.parent
      --if not p then log("no parent") end
    --else
      --p = {
        --workarea = focused.workarea,
        --layout_clients = {focused},
        --orientation = settings.orientation,
        --parent = focused.parent
      --}

      --local f_idx = _get_idx(focused, focused.parent.layout_clients)
      --focused.parent.layout_clients[f_idx] = p
      --focused.parent = p
    --end

    --c.parent = p
    --insert(p.layout_clients, c)
    --if p.orientation == "h" then
      --local w = p.workarea.width / #p.layout_clients
      --for i,c in ipairs(p.layout_clients) do
        --c.workarea = {
          --x = p.workarea.x + (i-1) * w,
          --y = p.workarea.y,
          --height = p.workarea.height,
          --width = w
        --}
      --end
    --elseif p.orientation == "v" then
      --local h = p.workarea.height / #p.layout_clients
      --for i,c in ipairs(p.layout_clients) do
        --c.workarea = {
          --x = p.workarea.x,
          --y = p.workarea.y + (i-1) * h,
          --height = h,
          --width = p.workarea.width
        --}
      --end
    --end
  --end
  --client.focus = c
--end




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
      c2 = c1 + v.workarea.width
    elseif dir == "N" then
      d = (v.workarea.y + v.workarea.height) - y
      c1 = v.workarea.x
      c2 = c1 + v.workarea.height
    elseif dir == "S" then
      d = v.workarea.y - (y + h)
      c1 = v.workarea.x
      c2 = c1 + v.workarea.height
    end
    if -10 < d and d < 10 then
      log("points", p1, p2, c1, c2)
      shared = c1 and c2 and shared_border(p1,p2,c1,c2) or 0
      log("shared: " .. shared)
      if shared > best_shared then
        log("best"..shared)
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
  local n = find_dir(dir)
  local p = c.parent

  if not n then return end -- TODO check if screen in dir

  if n.parent == c.parent then -- move inside 
    local cls = p.layout_clients
    swap_clients(c, n, cls)
    place_client(c)
    place_client(n)
  else
    if p.parent then
      local pos = _get_idx(p, p.parent.layout_clients)
      if dir == "E" or dir == "S" then
        pos = pos + 1
      end
      move_to_parent(c, c.parent.parent, pos)
    end
  end
end

function _M.del_client(c)
  log("[DEPRECATED] i3_layout: del_client() is deprecated use remove_client()")
  remove_client(c)
end

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
capi.tag.connect_signal("tagged",  arrange_tag)
capi.tag.connect_signal("untagged", arrange_tag)

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

_M.remove_client = remove_client
_M.move_to_parent = move_to_parent
--_M.restore()

return _M
