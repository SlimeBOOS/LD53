local lume = require("lib.lume")
local Timer = require("lib.hump.timer")
local Camera = require("lib.hump.camera")
local MainState = {}

local function boolToNumber(x)
	return x and 1 or 0
end

function MainState:init()
	self.delivery_points = {
		Vec(200, 200),
		Vec(400, 200),
		Vec(600, 300),
		Vec(800, 400),
		Vec(200, 500),
		Vec(420, 600),
	}

	self.active_orders = {}
	self.sitting_orders = {}
	self.holding_orders = {}
	self.orders_completed = 0

	self.player = {
		in_car_mode = true,
		pos = Vec(100, 100),
		vel = Vec(0, 0),
		move_dir = Vec(),
		look_dir = Vec(1, 0),
		brake_hold_time = 0
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

function MainState:player_human_controls(dt)
	local PLAYER_MOVE_SPEED = 200

	local dx = boolToNumber(love.keyboard.isDown("d")) - boolToNumber(love.keyboard.isDown("a"))
	local dy = boolToNumber(love.keyboard.isDown("s")) - boolToNumber(love.keyboard.isDown("w"))
	self.player.move_dir = Vec(dx, dy).normalized
	self.player.pos = self.player.pos + self.player.move_dir * PLAYER_MOVE_SPEED * dt

	if dx ~= 0 or dy ~= 0 then
		self.player.look_dir = self.player.move_dir
	end
end

function MainState:player_car_controls(dt)
	local player = self.player

	local turn    = boolToNumber(love.keyboard.isDown("d")) - boolToNumber(love.keyboard.isDown("a"))
	local thrust  = boolToNumber(love.keyboard.isDown("w")) - boolToNumber(love.keyboard.isDown("s"))
	local braking = love.keyboard.isDown("lshift")

	local PLAYER_MOVE_SPEED = 800
	local PLAYER_TURN_SPEED = math.pi/1.2

	player.look_dir = player.look_dir:rotated(turn * PLAYER_TURN_SPEED * dt)
	player.move_dir = player.look_dir

	local friction = 1
	local speed = 0
	if turn ~= 0 and thrust ~= 0 then
		speed = PLAYER_MOVE_SPEED * math.min(thrust + (turn ~= 0 and 0.5 or 0), 1)
		friction = 0.75
	elseif turn ~= 0 then
		speed = PLAYER_MOVE_SPEED * 0.2
		friction = 0.9
	else
		speed = PLAYER_MOVE_SPEED * thrust
		friction = 0.9
	end

	local acc = player.move_dir * speed
	if braking then
		player.break_hold_time = player.break_hold_time + dt
		friction = 1 - (1 - friction) ^ (1+player.break_hold_time*5)
		print(friction)
		-- print((1 - friction), player.break_hold_time)
		-- print(math.pow((1 - friction), player.break_hold_time))
	else
		player.break_hold_time = 0
	end

	player.vel = player.vel * (1 - math.min(friction, 1)) ^ dt

	self.player.vel = self.player.vel + acc * dt
	self.player.pos = self.player.pos + self.player.vel * dt
end

function MainState:update(dt)
	Timer.update(dt)
	if self.player.in_car_mode then
		self:player_car_controls(dt)
	else
		self:player_human_controls(dt)
	end

	local move_speed = 2
	local target_pos = self.player.pos + self.player.vel
	local dx, dy = target_pos.x - self.camera.x, target_pos.y - self.camera.y
	self.camera:move(dx*move_speed * dt, dy*move_speed * dt)
end

function MainState:keypressed(key)
	if key == "escape" then
		love.event.quit()
	elseif key == "q" then
		self.player.in_car_mode = not self.player.in_car_mode
	elseif key == "e" then
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
	local look_dir_size = Vec(10, 10)

	love.graphics.setColor(rgb(255, 255, 255))
	love.graphics.setNewFont(30)
	love.graphics.print(tostring(self.orders_completed), 10, 10)
	-- love.graphics.print(tostring(self.player.vel.length), 10, 40)

	self.camera:attach()
	love.graphics.push()
		love.graphics.translate(pos.x, pos.y)
		love.graphics.rotate(look_dir.angle)
		if love.keyboard.isDown("lshift") then
			love.graphics.setColor(rgb(20, 20, 100))
		else
			love.graphics.setColor(rgb(20, 20, 200))
		end
		love.graphics.rectangle("fill", -size.x/2, -size.y/2, size.x, size.y)
		love.graphics.setColor(rgb(255, 255, 255))
		love.graphics.rectangle("fill", size.x/2-look_dir_size.x/2, -look_dir_size.y/2, look_dir_size.x, look_dir_size.y)
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
end

return MainState
