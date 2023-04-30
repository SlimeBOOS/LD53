local Tiled = {}

local LAYER_TYPE_TILELAYER = 1
local LAYER_TYPE_OBJECTGROUP = 2

local FLIPPED_HORIZONTALLY_FLAG  = 0x80000000
local FLIPPED_VERTICALLY_FLAG    = 0x40000000
local FLIPPED_DIAGONALLY_FLAG    = 0x20000000

local TextureAtlas = require("lib.rta")

local function mask_high_gid_bits(gid)
	local flip_x = false
	local flip_y = false
	local flip_d = false

	if gid >= FLIPPED_HORIZONTALLY_FLAG then
		flip_x = true
		gid = gid - FLIPPED_HORIZONTALLY_FLAG
	end

	if gid >= FLIPPED_VERTICALLY_FLAG then
		flip_y = true
		gid = gid - FLIPPED_VERTICALLY_FLAG
	end

	if gid >= FLIPPED_DIAGONALLY_FLAG then
		flip_d = true
		gid = gid - FLIPPED_DIAGONALLY_FLAG
	end

	return gid, flip_x, flip_y, flip_d
end

local function loadTileset(filename)
	local lua_chunk = assert(love.filesystem.load(filename))
	local _, tiled_tileset = assert(pcall(lua_chunk))
	assert(tiled_tileset.version == "1.9", ("Tiled incompatible with version '%s', please use '1.9'"):format(tiled_tileset.version))

	local tileset = {}
	tileset.tilewidth = tiled_tileset.tilewidth
	tileset.tileheight = tiled_tileset.tileheight
	tileset.tiles = {}
	for _, tile in ipairs(tiled_tileset.tiles) do
		table.insert(tileset.tiles, {
			width = tile.width,
			height = tile.height,
			id = tile.id,
			image = love.graphics.newImage(tile.image),
			properties = tile.properties
		})
	end

	return tileset
end

local Map = {}
Map.__index = Map

local function transformToIsometric(tileX, tileY, tileW, tileH)
	local x = tileX   * tileW/2 - tileY * tileH
	local y = tileX/2 * tileW/2 + tileY * tileH/2
	return x, y
end

local function renderLayerChunk(tiles, atlas, spriteBatch, chunk, tileWidth, tileHeight)
	for tile_y=0, chunk.height-1 do
		for tile_x=0, chunk.width-1 do
			local tile = chunk.data[tile_y * chunk.width  + tile_x + 1]
			if tile > 0 then
				tile = mask_high_gid_bits(tile)
				local quad = atlas.quads[tile]
				local x, y = transformToIsometric(tile_x, tile_y, tileWidth, tileHeight)
				spriteBatch:add(quad, x, y - tiles[tile].height + tileHeight)
			end
		end
	end
end

function Map.new(map)
	local self = setmetatable({}, Map)
	assert(map.version == "1.9", ("Tiled incompatible with version '%s', please use '1.9'"):format(map.version))
	self.orientation = map.orientation
	self.renderOrder = map.renderorder
	self.staggerAxis = map.staggeraxis
	self.staggerIndex = map.staggerindex
	self.tileWidth = map.tilewidth
	self.tileHeight = map.tileheight

	self.atlas = TextureAtlas.newDynamicSize();
	self.atlas:setFilter("nearest")

	self.tiles = {}
	for _, tileset in ipairs(map.tilesets) do
		local loaded_tileset = loadTileset(tileset.filename)
		for _, tile in ipairs(loaded_tileset.tiles) do
			local id = tile.id + tileset.firstgid
			self.atlas:add(tile.image, id)
			self.tiles[id] = {
				width = tile.width,
				height = tile.height,
				properties = tile.properties
			}
		end
	end

	self.atlas:hardBake()
	collectgarbage("collect")

	self.layers = {}
	for _, layer in ipairs(map.layers) do
		local newLayer = {
			name = layer.name,
			visible = layer.visible,
			offsetX = layer.offsetx or 0,
			offsetY = layer.offsety or 0,
			properties = layer.properties
		}

		if layer.type == "tilelayer" then
			newLayer.type = LAYER_TYPE_TILELAYER
			newLayer.chunks = {}
			for _, chunk in ipairs(layer.chunks) do
				local spriteBatch = love.graphics.newSpriteBatch(self.atlas.image)
				renderLayerChunk(self.tiles, self.atlas, spriteBatch, chunk, self.tileWidth, self.tileHeight)
				table.insert(newLayer.chunks, {
					spriteBatch = spriteBatch,
					x = chunk.x,
					y = chunk.y,
					width = chunk.width,
					height = chunk.height,
					tiles = chunk.data
				})
			end
		elseif layer.type == "objectgroup" then
			newLayer.type = LAYER_TYPE_OBJECTGROUP
			newLayer.objects = layer.objects
		end

		table.insert(self.layers, newLayer)
		::continue::
	end

	return self
end

local function drawTileLayer(layer, tileWidth, tileHeight)
	if not layer.visible then return end

	for _, chunk in ipairs(layer.chunks) do
		local chunkWidth = chunk.width*tileWidth
		local chunkHeight = chunk.height*tileHeight

		local x, y = transformToIsometric(chunk.x/16, chunk.y/16, chunkWidth, chunkHeight)
		love.graphics.draw(chunk.spriteBatch, x + layer.offsetX, y + layer.offsetY)
	end
end

function Map:fromIsometricSpace(x, y)
	local newX = x   - y
	local newY = x/2 + y/2
	return newX + self.tileWidth/2, newY
end

function Map:toIsometricSpace(x, y)
	x = x - self.tileWidth/2
	local newX =  x/2 + y
	local newY = -x/2 + y
	return newX, newY
end

function Map:toTileCoords(x, y)
	local x, y = self:toIsometricSpace(x, y)
	return x/self.tileHeight + 0.5, y/self.tileHeight - 0.5
end

function Map:fromTileCoords(tileX, tileY)
	return self:fromIsometricSpace((tileX - 0.5) * self.tileHeight, (tileY + 0.5) * self.tileHeight)
end

local function getChunkAt(chunks, tileX, tileY)
	for _, chunk in ipairs(chunks) do
		if (chunk.x <= tileX and tileX < chunk.x + chunk.width) and
			(chunk.y <= tileY and tileY < chunk.y + chunk.height) then
			return chunk
		end
	end
end

function Map:getTileAt(layerName, tileX, tileY)
	local layer = self:getLayer(layerName)
	if not layer then return end

	local chunk = getChunkAt(layer.chunks, tileX, tileY)
	local tile = chunk.tiles[(tileY - chunk.y) * chunk.width + (tileX - chunk.x) + 1]
	return self.tiles[tile]
end

function Map:drawTileAt(tileX, tileY)
	local x, y = self:fromTileCoords(tileX, tileY)

	for _, layer in ipairs(self.layers) do
		if layer.type == LAYER_TYPE_TILELAYER then
			local chunk = getChunkAt(layer.chunks, tileX, tileY)
			if chunk then
				local tile = chunk.tiles[(tileY - chunk.y) * chunk.width + (tileX - chunk.x) + 1]
				if tile > 0 then
					tile = mask_high_gid_bits(tile)
					love.graphics.draw(self.atlas.image,
						self.atlas.quads[tile],
						x + layer.offsetX,
						y - self.tiles[tile].height + self.tileHeight + layer.offsetY
					)
				end
			end
		end
	end
end

function Map:draw(fromLayer)
	fromLayer = fromLayer or 1
	for idx=fromLayer, #self.layers-1 do
		self:drawLayer(self.layers[idx])
	end
end

function Map:drawLayer(layer)
	if layer.type == LAYER_TYPE_TILELAYER then
		drawTileLayer(layer, self.tileWidth, self.tileHeight)
	end
end

function Map:getLayer(name)
	for _, layer in ipairs(self.layers) do
		if layer.name == name then
			return layer
		end
	end
end

function Tiled.loadFromLuaFile(filename)
	local lua_chunk = assert(love.filesystem.load(filename))
	local _, map = assert(pcall(lua_chunk))
	return Map.new(map)
end

return Tiled
