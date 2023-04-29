local lume = require("lib.lume")
local Timer = require("lib.hump.timer")
local Camera = require("lib.hump.camera")
local Tiled = require("lib.tiled")
local MainState = {}

local DEBUG = false

local player_images = {
	love.graphics.newImage("resources/player-car/carRed6_008.png"),
	love.graphics.newImage("resources/player-car/carRed6_007.png"),
	love.graphics.newImage("resources/player-car/carRed6_011.png"),
	love.graphics.newImage("resources/player-car/carRed6_006.png"),
	love.graphics.newImage("resources/player-car/carRed6_005.png"),
	love.graphics.newImage("resources/player-car/carRed6_000.png"),
	love.graphics.newImage("resources/player-car/carRed6_001.png"),
	love.graphics.newImage("resources/player-car/carRed6_002.png")
}

local function boolToNumber(x)
	return x and 1 or 0
end

function MainState:init()
	self.map = Tiled.loadFromLuaFile("resources/world.lua")

	self.delivery_points = {}
	for _, obj in ipairs(self.map:getLayer("Delivery points").objects) do
		table.insert(self.delivery_points, Vec(obj.x, obj.y))
	end

	self.active_orders = {}
	self.sitting_orders = {}
	self.holding_orders = {}
	self.orders_completed = 0

	self.player = {
		pos = Vec(100, 100),
		vel = Vec(0, 0),
		move_dir = Vec(),
		look_dir = Vec(1, 0),
		brake_hold_time = 0,
		last_forward_press = -10,
		speed = 0
	}

	self:create_order()
	self:create_order()
	self:create_order()

	self.create_order_timer = Timer.every(1, function()
		self:create_order()
	end)

	self.camera = Camera(self.player.pos.x, self.player.pos.y)
end

function MainState:create_order()
	local from = 1+math.floor(love.math.random() * #self.delivery_points)
	local to = from
	while from == to do
		to = 1+math.floor(love.math.random() * #self.delivery_points)
	end

	local order = {
		from = from, to = to
	}
	table.insert(self.active_orders, order)
	table.insert(self.sitting_orders, order)
end

function MainState:player_car_controls(dt)
	local player = self.player

	local turn    = boolToNumber(love.keyboard.isDown("d")) - boolToNumber(love.keyboard.isDown("a"))
	local thrust  = boolToNumber(love.keyboard.isDown("w")) - boolToNumber(love.keyboard.isDown("s")) * 0.5
	local braking = love.keyboard.isDown("j")

	local friction = 1
	local turn_speed = math.pi
	if turn ~= 0 and thrust ~= 0 then
		friction = 0.75
	elseif turn ~= 0 then
		friction = 0.9
		turn_speed = turn_speed * 1.5
	else
		friction = 0.94
	end

	local move_angles = {
		0,
		math.pi/6.75,
		math.pi/2,
		-math.pi - math.pi/6.75,
		math.pi,
		-math.pi + math.pi/6.75,
		-math.pi/2,
		-math.pi/6.75,
	}

	if thrust == 0 and turn ~= 0 then
		player.speed = 200
		thrust = 1
	elseif thrust ~= 0 then
		player.speed = math.min(math.max(player.speed, 400) * (1 + 0.2 * dt), 800)
	else
		player.speed = 0
	end

	if thrust > 0 and turn ~= 0 and braking then
		local move_angle_idx = math.floor(player.look_dir.angle / (math.pi*2) * 8 + 0.5 + turn) % 8 + 1
		player.move_dir = Vec(1, 0):angled(move_angles[move_angle_idx])
	else
		player.look_dir = player.look_dir:rotated(turn * turn_speed * dt)
		local move_angle_idx = math.floor(player.look_dir.angle / (math.pi*2) * 8 + 0.5) % 8 + 1
		player.move_dir = Vec(1, 0):angled(move_angles[move_angle_idx])
	end

	local acc = player.move_dir * (player.speed * thrust)
	if braking then
		player.break_hold_time = player.break_hold_time + dt
		friction = 1 - (1 - friction) ^ (1+player.break_hold_time*5)
	else
		player.break_hold_time = 0
	end

	player.vel = player.vel * (1 - math.min(friction, 1)) ^ dt
	self.player.vel = self.player.vel + acc * dt
	self.player.pos = self.player.pos + self.player.vel * dt
end

function MainState:update(dt)
	Timer.update(dt)
	self:player_car_controls(dt)

	local move_speed = 2
	local target_pos = self.player.pos + self.player.vel
	local dx, dy = target_pos.x - self.camera.x, target_pos.y - self.camera.y
	self.camera:move(dx*move_speed * dt, dy*move_speed * dt)
end

function MainState:keypressed(key)
	if key == "escape" then
		love.event.quit()
	elseif key == "w" then
		local now = love.timer.getTime()
		local diff = now - self.player.last_forward_press
		self.player.last_forward_press = now
		local braking = love.keyboard.isDown("j")
		if diff <= 0.5 and self.player.vel.length < 80 and not braking then
			self.player.vel = self.player.move_dir * 200
		end
	elseif key == "k" then
		local picked_up_orders = {}
		for _, order in ipairs(self.sitting_orders) do
			local point = self.delivery_points[order.from]
			if (point - self.player.pos).length < 100 then
				table.insert(picked_up_orders, order)
			end
		end

		for _, order in ipairs(picked_up_orders) do
			lume.remove(self.sitting_orders, order)
			table.insert(self.holding_orders, order)
		end

		local dropped_orders = {}
		for _, order in ipairs(self.holding_orders) do
			local point = self.delivery_points[order.to]
			if (point - self.player.pos).length < 100 then
				table.insert(dropped_orders, order)
			end
		end
		for _, order in ipairs(dropped_orders) do
			lume.remove(self.active_orders, order)
			lume.remove(self.holding_orders, order)
		end
		self.orders_completed = self.orders_completed  + #dropped_orders
	end
end

function MainState:draw()
	local pos = self.player.pos
	local look_dir = self.player.look_dir
	local size = Vec(30, 30)

	self.camera:attach(nil, nil, nil, nil, true)
	love.graphics.setColor(1, 1, 1, 1)
	self.map:draw()
	love.graphics.circle("fill", 0, 0, 5)

	love.graphics.push()
		love.graphics.translate(pos.x, pos.y)
		if DEBUG then
			love.graphics.push()
			love.graphics.rotate(look_dir.angle)
			love.graphics.rectangle("fill", -size.x/2, -size.y/2, size.x, size.y)
			love.graphics.line(0, 0, 30, 0)
			love.graphics.pop()

			local move_dir = self.player.move_dir
			love.graphics.push()
			love.graphics.rotate(move_dir.angle)
			love.graphics.setColor(rgb(150, 20, 20))
			love.graphics.line(0, 0, 30, 0)
			love.graphics.pop()
		end

		love.graphics.setColor(1, 1, 1, 1)
		local rotation_count = #player_images
		local image_idx = math.floor((look_dir.angle / (2*math.pi) * rotation_count) + 0.5) % rotation_count + 1
		local player_image = player_images[image_idx]
		local image_width, image_height = player_image:getDimensions()
		love.graphics.draw(player_image, -image_width/2, -image_height/2)
	love.graphics.pop()

	love.graphics.setColor(rgb(20, 200, 200))
	for _, point in ipairs(self.delivery_points) do
		love.graphics.circle("fill", point.x, point.y, 20)
	end

	love.graphics.setColor(rgb(20, 100, 100))
	for i = 0, #self.holding_orders - 1 do
		love.graphics.circle("fill", pos.x + i * 12, pos.y - 30, 5)
	end

	do
		local deliveries_per_point = {}
		for _, order in ipairs(self.sitting_orders) do
			deliveries_per_point[order.from] = deliveries_per_point[order.from] or {}
			deliveries_per_point[order.to] = deliveries_per_point[order.to] or {}

			table.insert(deliveries_per_point[order.from], order)
		end
		love.graphics.setColor(rgb(20, 100, 100))
		for point_idx, orders in pairs(deliveries_per_point) do
			local pos = self.delivery_points[point_idx]
			for i = 0, #orders - 1 do
				love.graphics.circle("fill", pos.x + i * 12, pos.y - 30, 5)
			end
		end
	end

	do
		local deliveries_per_point = {}
		for _, order in ipairs(self.holding_orders) do
			deliveries_per_point[order.from] = deliveries_per_point[order.from] or {}
			deliveries_per_point[order.to] = deliveries_per_point[order.to] or {}

			table.insert(deliveries_per_point[order.to], order)
		end
		love.graphics.setColor(rgb(100, 20, 100))
		for point_idx, orders in pairs(deliveries_per_point) do
			local pos = self.delivery_points[point_idx]
			for i = 0, #orders - 1 do
				love.graphics.circle("fill", pos.x + i * 12, pos.y - 45, 5)
			end
		end
	end
	self.camera:detach()

	love.graphics.setColor(rgb(255, 255, 255))
	love.graphics.setNewFont(30)
	love.graphics.print(tostring(self.orders_completed), 10, 10)
	love.graphics.print(("%f"):format(self.player.vel.length), 10, 40)
end

return MainState
