--- plugin to support tile collections for STI
-- @module tile_collections.lua
-- @author Anirudh Katoch (spopo | katoch.anirudh at gmail.com)
-- @copyright 2020
-- @license MIT/X11

local tile_collections = {
	tile_collections_LICENSE        = "MIT/X11",
	tile_collections_URL            = "https://github.com/karai17/Simple-Tiled-Implementation",
	tile_collections_VERSION        = "0.0.0.001",
	tile_collections_DESCRIPTION    = "(Partially?) Supporting tile collections for STI.",

	loadStyle = "callable",

	--- Adds support for TileCollections to the map
	hook = function(thismodule, map)
		local newTilesets = {}
		-- We're gonna hack around and convert all the tiles in a tile collections into individual tilesets
		-- Usually people use tile collections for images with different sizes which are drawn sparsely (and not as uniform tiles)
		-- We are not optimizing for performance here. Any optimization can be done in future versions of this plugin, and may even be unneeded
		for _, tileset_def in ipairs(map.tilesets) do
			if not tileset_def.image then
				--This is a tileset defined by a collection of images
				local tileset
				if tileset_def.filename then
					local loaded_file = assert(love.filesystem.load(tileset_def.filename))
					tileset = loaded_file()
				else
					tileset = tileset_def
				end

				local mt = {__index = tileset}
				for _, tile in ipairs(tileset.tiles) do
					table.insert(newTilesets, setmetatable({
						originalTileset = tileset_def,
						columns = 1,
						tilewidth = tile.width,
						tileheight = tile.height,
						imagewidth = tile.width,
						imageheight = tile.height,
						firstgid = tileset_def.firstgid+tile.id,
						image = tile.image,
						tiles = { tile }
					}, mt))
				end
			else
				table.insert(newTilesets, tileset_def)
			end
		end
		map.tilesets = newTilesets
	end
}

return setmetatable(tile_collections, {__call = tile_collections.hook})
