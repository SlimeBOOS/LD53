local lerp = require("lib.lume").lerp
local vivid = require("lib.vivid")

return function (target_hue, amount, r, g, b)
	local h, s, l = vivid.RGBtoHSL(r, g, b)
	h = lerp(h, target_hue, amount)
	return vivid.HSLtoRGB(h, s, l)
end
