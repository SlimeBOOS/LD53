local vivid = require("lib.vivid")
local hueShift = require("helpers.hue-shift")
local BLUE_HUE = 240/360

return function(r, g, b)
	return hueShift(BLUE_HUE, 0.08, vivid.desaturate(0.1, vivid.darken(0.1, r, g, b)))
end

