local Gamestate = require("lib.hump.gamestate")
local Tiled = require("lib.tiled")
local slicy = require("lib.slicy")
local Start = {}

local pending_order_icon = love.graphics.newImage("resources/icons/emote_circle.png")
local order_delivery_icon = love.graphics.newImage("resources/icons/emote_cash.png")

local default_font = love.graphics.newFont("resources/MontserratMedium.ttf", 32)
local grey_box = assert(slicy.load("resources/grey_box.9.png"))

function Start:init()
	self.map = Tiled.loadFromLuaFile("resources/world.lua")
end

function Start:keypressed(key)
	if key == "space" then
		love.graphics.setColor(1, 1, 1)
		Gamestate.switch(require("states.main"))
	end
end

function Start:draw()
	love.graphics.setColor(1, 1, 1, 1)

	love.graphics.push()
	love.graphics.translate(600, 150)
	self.map:draw()
	love.graphics.pop()

	love.graphics.setFont(default_font)
	love.graphics.push()
	local screenW, screenH = love.graphics.getDimensions()
	love.graphics.translate(screenW/6, screenH/2 - 150)
	grey_box:draw(-10, -10, 360, 155)
	love.graphics.setColor(rgb(20, 20, 20))
	love.graphics.print("Controls:", 0, 0)
	love.graphics.print(" Movement - WASD", 0, 32)
	love.graphics.print(" Breaking - left shift", 0, 64)
	love.graphics.print(" Pickup/drop - space", 0, 96)

	love.graphics.setColor(1, 1, 1)
	grey_box:draw(-10, 150, 870, 210)
	love.graphics.draw(pending_order_icon, 345, 150 + 32*1)
	love.graphics.draw(order_delivery_icon, 725, 150 + 32*1)
	love.graphics.setColor(rgb(20, 20, 20))
	love.graphics.print("How to play:", 0, 150)
	love.graphics.print(" Pick up deliveries at     and deposit them at   ", 0, 150 + 32*1)
	love.graphics.print(" You can at max hold 3 deliveries", 0, 150 + 32*2 + 3)
	love.graphics.print(" Make as many deliveries as possible in limited time", 0, 150 + 32*3 + 3)
	love.graphics.print(" Every delivery restores some time", 0, 150 + 32*4 + 3)
	love.graphics.print(" Orange dot shows order destination", 0, 150 + 32*5 + 3)

	love.graphics.setColor(1, 1, 1)
	grey_box:draw(-10, 380-5, 350, 50)
	love.graphics.setColor(rgb(20, 20, 20))
	love.graphics.print("Press space to start", 0, 380)
	love.graphics.pop()
end

return Start
