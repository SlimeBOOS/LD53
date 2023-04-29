--- Module resposible for scaling screen and centering contents
-- while respecting ratios.
-- @module ScreenScaler
local ScreenScaler = {}

--- Boolean that determines that everything out of bounds of the scaled screen
-- should be hidden by a black screen
ScreenScaler.hideOutOfBounds = true

-- This "Center" library will do most of the heavy lifting
local Center = require("lib.center")

local getRealDimensions = love.graphics.getDimensions

--- Set the "ideal" dimensions from which everything else will be scaled.
-- @tparam number w virtual width
-- @tparam number h virtual height
function ScreenScaler.setVirtualDimensions(w, h)
	assert(type(w) == "number", "Expected width to be number")
	assert(type(h) == "number", "Expected height to be number")
	ScreenScaler.width, ScreenScaler.height = nil, nil

	-- Setup library resposible for scaling the screen
	Center:setupScreen(w, h)

	ScreenScaler.width, ScreenScaler.height = w, h
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

--- Get real window dimensions.
-- @return width, height
function ScreenScaler.getRealDimensions()
	return getRealDimensions()
end

function ScreenScaler.getScale()
	return Center:getScale()
end

function ScreenScaler.getOffset()
	return Center:getOffsetX(), Center:getOffsetY()
end

--- Returns true if scaler is enabled.
-- @treturn boolean
function ScreenScaler.isEnabled()
	return ScreenScaler.width ~= nil
end

do
	local translate = love.graphics.translate
	local scale = love.graphics.scale
	local origin = love.graphics.origin

	function love.graphics.origin()
		origin()
		if Center.centered then
			local ox, oy = Center:getOffsetX(), Center:getOffsetY()
			local s = Center:getScale()
			translate(ox, oy)
			scale(s, s)
		end
	end
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
		return (x - Center:getOffsetX()) / Center:getScale()
	end

	local getY = love.mouse.getY
	function love.mouse.getY()
		local y = getY()
		if not ScreenScaler.isEnabled() then
			return y
		end
		return (y - Center:getOffsetY()) / Center:getScale()
	end

	local getPosition = love.mouse.getPosition
	function love.mouse.getPosition()
		if ScreenScaler.isEnabled() then
			return Center:toGame(getPosition())
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
	local setScissor = love.graphics.setScissor
	function love.graphics.setScissor(x, y, w, h)
		if x and ScreenScaler.isEnabled() then
			setScissor(Center:toGame(x, y, w, h))
		else
			setScissor(x, y, w, h)
		end
	end

	local intersectScissor = love.graphics.intersectScissor
	function love.graphics.intersectScissor(x, y, w, h)
		if x and ScreenScaler.isEnabled() then
			intersectScissor(Center:toGame(x, y, w, h))
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
	x, y = Center:toGame(x, y)
	return isInBounds(x, y), x, y, button, istouch, presses
end

function eventPreProccessor.mousereleased(x, y, button, istouch, presses)
	x, y = Center:toGame(x, y)
	return isInBounds(x, y), x, y, button, istouch, presses
end

function eventPreProccessor.mousemoved(x, y, dx, dy, istouch)
	local scale = Center:getScale()
	x, y = Center:toGame(x, y)
	dx, dy = dx / scale, dy / scale
	return isInBounds(x, y), x, y, dx, dy, istouch, istouch
end

function eventPreProccessor.wheelmoved(x, y)
	return isInBounds(love.mouse.getPosition()), x, y
end

local function hideOutOfBounds()
	local r, g, b, a = love.graphics.getColor()
	love.graphics.setColor(love.graphics.getBackgroundColor())
	local w, h = getRealDimensions()

	if Center._OFFSET_X ~= 0 then
		love.graphics.rectangle("fill", 0, 0, Center._OFFSET_X, h)
		love.graphics.rectangle("fill", Center._WIDTH*Center._SCALE+Center._OFFSET_X, 0, Center._OFFSET_X, h)
	end

	if Center._OFFSET_Y ~= 0 then
		love.graphics.rectangle("fill", 0, 0, w, Center._OFFSET_Y)
		love.graphics.rectangle("fill", 0, Center._HEIGHT*Center._SCALE+Center._OFFSET_Y, w, Center._OFFSET_Y)
	end

	love.graphics.setColor(r, g, b, a)
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
						Center:resize(a, b)
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
					Center:start()
					love.draw()
					Center:finish()
					if ScreenScaler.hideOutOfBounds then
						hideOutOfBounds()
					end
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
