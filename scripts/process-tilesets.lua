local serpent = require("serpent") -- Assumes that 'serpent' was installed using luarocks

local IMAGE_DIRECTORY = "src/resources/images"

local function does_file_exist(file)
	local f = io.open(file, "r")
	if f then
		f:close()
		return true
	else
		return false
	end
end

local function copy_file(src, dest)
	print("copy", src, dest)
	local src_file = io.open(src, "rb")
	if not src_file then return end

	local contents = src_file:read("*a")
	src_file:close()

	local dest_file = io.open(dest, "wb")
	if not dest_file then return end
	dest_file:write(contents)
	dest_file:close()
end

local function write_table_to_file(filename, t)
	local f = io.open(filename, "w")
	if not f then return end
	f:write("return ")
	f:write(serpent.block(t, { comment = false }))
	f:close()
end

local function find_value(t, value)
	for k, v in ipairs(t) do
		if v == value then
			return k
		end
	end
end

local function insert_to_set(t, value)
	if find_value(t, value) == nil then
		table.insert(t, value)
	end
end

local function get_used_ids(map)
	local ids = {}
	local tilesets = {}
	for _, layer in ipairs(map.layers) do
		if layer.type == "tilelayer" then
			for _, chunk in ipairs(layer.chunks) do
				for _, tile in ipairs(chunk.data) do
					insert_to_set(ids, tile)
				end
			end
		end
	end
	return ids, tilesets
end

local function get_tileset_by_filename(filename, tilesets)
	for _, tileset in ipairs(tilesets) do
		if filename:match("/([^/]+)%.lua$") == tileset.name then
			return tileset
		end
	end
end

local function main(map_filename, ...)
	local map = loadfile(map_filename)()
	local used_ids = get_used_ids(map)
	local tileset_filenames = { ... }

	for _, filename in ipairs(tileset_filenames) do
		local tileset = get_tileset_by_filename(filename, map.tilesets)
		if not tileset then
			os.remove(filename)
			goto continue
		end

		local tileset_obj = loadfile(filename)()

		-- Remove unused tiles
		for idx=#tileset_obj.tiles, 1, -1 do
			local id = tileset_obj.tiles[idx].id + tileset.firstgid
			if not find_value(used_ids, id) then
				table.remove(tileset_obj.tiles, idx)
				tileset_obj.tilecount = tileset_obj.tilecount - 1
			end
		end

		-- Copy tile images to "src/resources/images"
		local tileset_dir = filename:match("^(.+)/[^/]+$")
		for _, tile in ipairs(tileset_obj.tiles) do
			local name = tile.image:match("/([^/]+)$")
			local target_location = IMAGE_DIRECTORY .. "/" .. name
			if not does_file_exist(target_location) then
				copy_file(tileset_dir .. "/" .. tile.image, target_location)
			end
			tile.image = target_location:match("^[^/]+/(.+)$")
		end

		-- update tileset filename in map
		tileset.filename = filename:match("^[^/]+/(.+)$")

		write_table_to_file(filename, tileset_obj)
		::continue::
	end

	write_table_to_file(map_filename, map)

	return 0
end

return main(...)
