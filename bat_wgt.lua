local gears = require "gears"
local wibox = require "wibox"

local _M = {}

function _M.new(bat)
	local wgt = setmetatable({
		bat = "/sys/class/power_supply/" .. bat,
		widget = wibox.widget{
			{
				min_value = 0,
				max_value = 100,
				value     = 0,
				paddings  = 0,
				margins   = {
					top = 5,
					bottom = 5,
				},
				border_width = 1,
				forced_width = 50,
				forced_height = 10,
				border_color = "#689d6a",
				color = "#689d6a",
				id = "pb",
				widget = wibox.widget.progressbar,
			},
			{
				id = "tb",
				text = "100%",
				widget = wibox.widget.textbox,
			},
			layout = wibox.layout.stack,
			set_battery = function(self, val)
				self.pb.value = val
				self.tb.text = val .. "%"
			end,
		}
	}, { __index = _M })

	gears.timer{
		timeout   = 10,
		call_now  = true,
		autostart = true,
		callback  = function()
			wgt:update()
		end
	}
	wgt:update()
	return wgt.widget

end

function _M:update()
	local cap, err = io.open(self.bat .. "/capacity")
	if not cap then
		return
	end
	self.widget:set_battery(tonumber(cap:read()) or 0)
	cap:close()
end


return _M
