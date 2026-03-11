extends TileMap
class_name CityTileMap

const TILE_SIZE := 32

func build_from_city_map(city_map: CityMap) -> void:
	var tileset := TileSet.new()
	var source := TileSetAtlasSource.new()
	source.texture = _build_palette_texture()
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for i in range(6):
		source.create_tile(Vector2i(i, 0))
	tileset.add_source(source, 0)
	tile_set = tileset
	clear()
	for y in range(city_map.grid.size()):
		for x in range(city_map.grid[y].size()):
			var t := int(city_map.grid[y][x])
			var atlas := Vector2i(0, 0)
			match t:
				CityMap.TileType.ROAD:
					atlas = Vector2i(0, 0)
				CityMap.TileType.PAVEMENT:
					atlas = Vector2i(1, 0)
				CityMap.TileType.BUILDING:
					atlas = Vector2i(2, 0)
				CityMap.TileType.PARK:
					atlas = Vector2i(3, 0)
				CityMap.TileType.WATER:
					atlas = Vector2i(4, 0)
				CityMap.TileType.ALLEY:
					atlas = Vector2i(5, 0)
			set_cell(0, Vector2i(x, y), 0, atlas)

func _build_palette_texture() -> Texture2D:
	var colors := [
		Color("3d3d3d"), Color("a0a0a0"), Color("a0522d"),
		Color("2e5e1e"), Color("1a3a5c"), Color("6e6e6e")
	]
	var img := Image.create(TILE_SIZE * colors.size(), TILE_SIZE, false, Image.FORMAT_RGBA8)
	for i in range(colors.size()):
		for y in range(TILE_SIZE):
			for x in range(TILE_SIZE):
				img.set_pixel(i * TILE_SIZE + x, y, colors[i])
	return ImageTexture.create_from_image(img)
