local GameOver = {}
local Tiled = require("lib.tiled")
local slicy = require("lib.slicy")

local default_font = love.graphics.newFont("resources/MontserratMedium.ttf", 32)
local grey_box = assert(slicy.load("resources/grey_box.9.png"))

function GameOver:init()
	self.map = Tiled.loadFromLuaFile("resources/world.lua")
end

function GameOver:enter(_, score)
	self.score = score
end

function GameOver:keypressed()
	love.event.quit()
end

function GameOver:draw()
	love.graphics.setColor(1, 1, 1, 1)

	love.graphics.push()
	love.graphics.translate(600, 150)
	self.map:draw()
	love.graphics.pop()

	love.graphics.setFont(default_font)
	love.graphics.push()
	local screenW, screenH = love.graphics.getDimensions()
	love.graphics.translate(screenW/3, screenH/2 - 50)
	grey_box:draw(-20, -10, 580, 110)
	love.graphics.setColor(rgb(20, 20, 20))
	love.graphics.print("Time ran out! Try again next time")
	love.graphics.print(("You completed %d orders"):format(self.score), 0, 50)

	love.graphics.setColor(1, 1, 1)
	grey_box:draw(-20, -10 + 120, 400, 60)
	love.graphics.setColor(rgb(20, 20, 20))
	love.graphics.print("Press any key to quit", 0, 120)
	love.graphics.pop()
end

return GameOver
