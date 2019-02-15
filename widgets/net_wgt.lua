local gears = require "gears"
local wibox = require "wibox"

local format = string.format
local sizes = {"B", "K", "M", "G"}

local _M = {}

local function update(self)
	local f, err = io.popen("cat /proc/net/dev | grep "
		.. self.dev .. " | tr -s \" \" | cut -d \" \" -f 2")

	if not f then
		return
	end

	local down = f:read()
	f:close()

	if not self.download then
		self.download = down
		self.wgt:set_download(0)
		return
	end

	local change = down - self.download

	self.wgt:set_download(change / self.rate)

	self.download = down
end

function _M.new(dev, rate)
	local wgt = setmetatable({
		dev  = dev,
		rate = rate,
		wgt  = wibox.widget{
			{
				id     = "tb",
				text   = "",
				widget = wibox.widget.textbox,
			},
			layout  = wibox.layout.align.horizontal,

			set_download = function(self, down)
				local size = 1
				while down > 1000 do
					size = size + 1
					down = down / 1000
				end

				self.tb.text = format("%.0f %s/s", down, sizes[size])
			end
		},
	}, {})

	gears.timer{
		timeout   = rate,
		call_now  = true,
		autostart = true,
		callback  = function()
			update(wgt)
		end
	}

	update(wgt)
	return wgt.wgt
end

return _M
