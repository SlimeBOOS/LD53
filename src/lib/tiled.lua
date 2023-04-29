local Tiled = {}

local LAYER_TYPE_TILELAYER = 1

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
			image = love.graphics.newImage(tile.image)
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
				spriteBatch:add(quad, x - tiles[tile].width/2, y - tiles[tile].height + tileHeight)
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
				height = tile.height
			}
		end
	end

	self.atlas:hardBake()
	collectgarbage("collect")

	self.layers = {}
	for _, layer in ipairs(map.layers) do
		if not layer.visible then
			goto continue
		end

		if layer.type == "tilelayer" then
			local chunks = {}
			for _, chunk in ipairs(layer.chunks) do
				local spriteBatch = love.graphics.newSpriteBatch(self.atlas.image)
				renderLayerChunk(self.tiles, self.atlas, spriteBatch, chunk, self.tileWidth, self.tileHeight)
				table.insert(chunks, {
					spriteBatch = spriteBatch,
					x = chunk.x,
					y = chunk.y,
					width = chunk.width,
					height = chunk.height
				})
			end

			table.insert(self.layers, {
				type = LAYER_TYPE_TILELAYER,
				chunks = chunks,
				visible = layer.visible
			})
		end

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
		love.graphics.draw(chunk.spriteBatch, x, y)
	end
end

function Map:draw()
	for _, layer in ipairs(self.layers) do
		if layer.type == LAYER_TYPE_TILELAYER then
			drawTileLayer(layer, self.tileWidth, self.tileHeight)
			-- love.graphics.draw(layer.spriteBatch)
		end
	end
end

function Tiled.loadFromLuaFile(filename)
	local lua_chunk = assert(love.filesystem.load(filename))
	local _, map = assert(pcall(lua_chunk))
	return Map.new(map)
end

return Tiled