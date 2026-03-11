extends Node2D

var city_map: CityMap

func _draw() -> void:
	if city_map == null:
		return
	for y in range(city_map.grid.size()):
		for x in range(city_map.grid[y].size()):
			var t := int(city_map.grid[y][x])
			var color := _color_for_tile(t)
			draw_rect(Rect2(Vector2(x, y) * 32.0, Vector2(32, 32)), color)

func _color_for_tile(tile_type: int) -> Color:
	match tile_type:
		CityMap.TileType.ROAD:
			return Color("3d3d3d")
		CityMap.TileType.PAVEMENT:
			return Color("a0a0a0")
		CityMap.TileType.BUILDING:
			return Color("a0522d")
		CityMap.TileType.PARK:
			return Color("2e5e1e")
		CityMap.TileType.WATER:
			return Color("1a3a5c")
		CityMap.TileType.ALLEY:
			return Color("6e6e6e")
		_:
			return Color.DIM_GRAY
