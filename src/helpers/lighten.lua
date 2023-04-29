local vivid = require("lib.vivid")
local hueShift = require("helpers.hue-shift")
local YELLOW_HUE = 60/360

return function(r, g, b)
	return hueShift(YELLOW_HUE, 0.05, vivid.saturate(0.1, vivid.lighten(0.1, r, g, b)))
end

