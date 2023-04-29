local Gamestate = require("lib.hump.gamestate")

function love.load()
	love.math.setRandomSeed(love.timer.getTime())
	math.randomseed(love.timer.getTime())

	Gamestate.switch(require("states.main"))
	Gamestate.registerEvents()
end
