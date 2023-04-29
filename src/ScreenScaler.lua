---@diagnostic disable: duplicate-set-field, undefined-field, redundant-parameter
--- Module resposible for scaling screen and centering contents
-- while respecting ratios.
-- @module ScreenScaler
local ScreenScaler = {}
local offsetX = 0
local offsetY = 0
local scale = 1

local getRealDimensions = love.graphics.getDimensions

local function applyScaling(screenWidth, screenHeight)
	local scaleX = screenWidth  / ScreenScaler.width
	local scaleY = screenHeight / ScreenScaler.height
	scale = math.min(scaleX, scaleY)

	offsetX = (screenWidth - ScreenScaler.width * scale)/2
	offsetY = (screenHeight - ScreenScaler.height * scale)/2

    -- local max_width = available_width
    -- local max_height = available_height
    -- if self._MAX_RELATIVE_WIDTH > 0 and available_width * self._MAX_RELATIVE_WIDTH < max_width then
    --     max_width = available_width * self._MAX_RELATIVE_WIDTH
    -- end
    -- if self._MAX_RELATIVE_HEIGHT > 0 and available_height * self._MAX_RELATIVE_HEIGHT < max_height then
    --     max_height = available_height * self._MAX_RELATIVE_HEIGHT
    -- end
    -- if self._MAX_WIDTH > 0 and self._MAX_WIDTH < max_width then
    --     max_width = self._MAX_WIDTH
    -- end
    -- if self._MAX_HEIGHT > 0 and self._MAX_HEIGHT < max_height then
    --     max_height = self._MAX_HEIGHT
    -- end
    -- if max_height / max_width > self._HEIGHT / self._WIDTH then
    --     self._CANVAS_WIDTH = max_width
    --     self._CANVAS_HEIGHT = self._CANVAS_WIDTH * (self._HEIGHT / self._WIDTH)
    -- else
    --     self._CANVAS_HEIGHT = max_height
    --     self._CANVAS_WIDTH = self._CANVAS_HEIGHT * (self._WIDTH / self._HEIGHT)
    -- end
    -- self._SCALE = self._CANVAS_HEIGHT / self._HEIGHT
    -- self._OFFSET_X = self._BORDERS.l + (available_width - self._CANVAS_WIDTH) / 2
    -- self._OFFSET_Y = self._BORDERS.t + (available_height - self._CANVAS_HEIGHT) / 2
end

--- Set the "ideal" dimensions from which everything else will be scaled.
-- @tparam number w virtual width
-- @tparam number h virtual height
function ScreenScaler.setVirtualDimensions(w, h)
	assert(type(w) == "number", "Expected width to be number")
	assert(type(h) == "number", "Expected height to be number")
	ScreenScaler.width, ScreenScaler.height = nil, nil

	local screenWidth, screenHeight = love.graphics.getDimensions()

	ScreenScaler.width, ScreenScaler.height = w, h
	applyScaling(screenWidth, screenHeight)
end

--- Unsets virtual dimensions. Effectively disables scaler.
function ScreenScaler.unsetVirtualDimensions()
	ScreenScaler.width = nil
	ScreenScaler.height = nil
end

--- Get virtual dimensions.
-- @return width, height
function ScreenScaler.getVirtualDimensions()
	return ScreenScaler.width, ScreenScaler.height
end

--- Returns true if scaler is enabled.
-- @treturn boolean
function ScreenScaler.isEnabled()
	return ScreenScaler.width ~= nil
end

function ScreenScaler.getOffset()
	return offsetX, offsetY
end

-- Overwrite default love.mouse functions to return position
-- relative to scaled window
do
	local getX = love.mouse.getX
	function love.mouse.getX()
		local x = getX()
		if not ScreenScaler.isEnabled() then
			return x
		end
		return (x - offsetX) / scale
	end

	local getY = love.mouse.getY
	function love.mouse.getY()
		local y = getY()
		if not ScreenScaler.isEnabled() then
			return y
		end
		return (y - offsetY) / scale
	end

	local getPosition = love.mouse.getPosition
	function love.mouse.getPosition()
		if ScreenScaler.isEnabled() then
			local x, y = getPosition()
			return (x - offsetX) / scale, (y - offsetY) / scale
		else
			return getPosition()
		end
	end

	-- TODO: add replacements for setX, setY, setPosition
end

-- Overwrite default getDimensions, getWidth, getHeight
-- to return virtual width and height if scaler is enabled
do
	local getWidth = love.graphics.getWidth
	function love.graphics.getWidth()
		return ScreenScaler.width or getWidth()
	end

	local getHeight = love.graphics.getHeight
	function love.graphics.getHeight()
		return ScreenScaler.height or getHeight()
	end

	function love.graphics.getDimensions()
		return love.graphics.getWidth(), love.graphics.getHeight()
	end
end

-- Adjust setScissor and intersectScissor function, so that they are relative
-- to the scaled screen. By default these functions are unaffected by transformations
do
	local getScissor = love.graphics.getScissor
	function love.graphics.getScissor()
		local x, y, w, h = getScissor()
		if x and ScreenScaler.isEnabled() then
			x = (x - offsetX) / scale
			y = (y - offsetY) / scale
			w = w / scale
			h = h / scale
			return x, y, w, h
		end
	end

	local setScissor = love.graphics.setScissor
	function love.graphics.setScissor(x, y, w, h)
		if x and ScreenScaler.isEnabled() then
			setScissor(
				x * scale + offsetX,
				y * scale + offsetY,
				w * scale,
				h * scale
			)
		else
			setScissor(x, y, w, h)
		end
	end

	local intersectScissor = love.graphics.intersectScissor
	function love.graphics.intersectScissor(x, y, w, h)
		if x and ScreenScaler.isEnabled() then
			intersectScissor(
				(x - offsetX) / scale,
				(y - offsetY) / scale,
				w and w / scale,
				h and h / scale
			)
		else
			intersectScissor(x, y, w, h)
		end
	end
end

local function isInBounds(x, y)
	if not ScreenScaler.isEnabled() then return true end
	local w, h = ScreenScaler.getVirtualDimensions()
	return x >= 0 and x < w and y >= 0 and y < h
end

-- Create event proccessors for converting normal screen coordinates
-- to scaled screen coordinates
-- If the user clicked out of bounds, it will not handled
local eventPreProccessor = {}
function eventPreProccessor.mousepressed(x, y, button, istouch, presses)
	x = (x - offsetX) / scale
	y = (y - offsetY) / scale
	return isInBounds(x, y), x, y, button, istouch, presses
end

function eventPreProccessor.mousereleased(x, y, button, istouch, presses)
	x = (x - offsetX) / scale
	y = (y - offsetY) / scale
	return isInBounds(x, y), x, y, button, istouch, presses
end

function eventPreProccessor.mousemoved(x, y, dx, dy, istouch)
	x = (x - offsetX) / scale
	y = (y - offsetY) / scale
	dx, dy = dx / scale, dy / scale
	return isInBounds(x, y), x, y, dx, dy, istouch, istouch
end

function eventPreProccessor.wheelmoved(x, y)
	return isInBounds(love.mouse.getPosition()), x, y
end

-- Modify core game loop so that if scaler is enabled:
-- * resize events are not handled
-- * out of bounds mouse events are not handled
-- * all drawing operations are centered
function love.run()
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end

	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end

	local dt = 0

	-- Main loop time.
	return function()
		-- Process events.
		if love.event then
			love.event.pump()
			for name, a,b,c,d,e,f in love.event.poll() do
				if name == "quit" then
					if not love.quit or not love.quit() then
						return a or 0
					end
				end

				if ScreenScaler.isEnabled() then
					if name == "resize" then
						applyScaling(a, b)
						goto continue
					elseif eventPreProccessor[name] then
						local success
						success, a, b, c, d, e, f = eventPreProccessor[name](a, b, c, d, e, f)
						if not success then goto continue end
					end
				end
				love.handlers[name](a, b, c, d, e, f)
				::continue::
			end
		end

		-- Update dt, as we'll be passing it to update
		if love.timer then dt = love.timer.step() end

		-- Call update and draw
		if love.update then love.update(dt) end -- will pass 0 if love.timer is disabled

		if love.graphics and love.graphics.isActive() then
			love.graphics.origin()
			love.graphics.clear(love.graphics.getBackgroundColor())

			if love.draw then
				if ScreenScaler.isEnabled() then
					love.graphics.push("transform")
					love.graphics.translate(offsetX, offsetY)
					love.graphics.scale(scale)
					love.draw()
					love.graphics.pop()
				else
					love.draw()
				end
			end

			love.graphics.present()
		end

		if love.timer then love.timer.sleep(0.001) end
	end
end

return ScreenScaler
