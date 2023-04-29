local ScreenScaler = require("ScreenScaler")
local Gamestate = require("lib.hump.gamestate")
Vec = require("lib.brinevector")
pprint = require("lib.pprint")

function rgb(r, g, b)
	return { r/255, g/255, b/255, 1 }
end

ScreenScaler.setVirtualDimensions(1280, 720)

function love.load()
	love.math.setRandomSeed(love.timer.getTime())
	math.randomseed(love.timer.getTime())

	Gamestate.switch(require("states.main"))
	Gamestate.registerEvents()
end
