extends Node
class_name CityMap

const C := preload("res://scripts/data/game_constants.gd")

enum TileType {
	ROAD,
	PAVEMENT,
	BUILDING,
	PARK,
	WATER,
	ALLEY
}

var grid: Array = []
var pavement_cells: Array[Vector2i] = []
var road_cells: Array[Vector2i] = []
var restricted_cells: Array[Vector2i] = []

func build() -> void:
	grid.clear()
	pavement_cells.clear()
	road_cells.clear()
	restricted_cells.clear()
	for y in range(C.MAP_HEIGHT):
		grid.append([])
		for x in range(C.MAP_WIDTH):
			grid[y].append(TileType.PARK)

	_make_arterial_roads()
	_make_roundabouts()
	_make_districts()
	_make_river()
	_make_pavements_and_alleys()
	_index_cells()

func _make_arterial_roads() -> void:
	for x in range(8, C.MAP_WIDTH - 8):
		_set_rect(Vector2i(x, 44), Vector2i(1, 3), TileType.ROAD) # high street central
	for y in range(10, C.MAP_HEIGHT - 10):
		_set_rect(Vector2i(30, y), Vector2i(3, 1), TileType.ROAD)
		_set_rect(Vector2i(62, y), Vector2i(3, 1), TileType.ROAD)
	for x in range(8, C.MAP_WIDTH - 8):
		_set_rect(Vector2i(x, 72), Vector2i(1, 3), TileType.ROAD)

func _make_roundabouts() -> void:
	_draw_roundabout(Vector2i(31, 45), 4)
	_draw_roundabout(Vector2i(63, 45), 4)
	_draw_roundabout(Vector2i(63, 73), 4)

func _draw_roundabout(center: Vector2i, radius: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var d = Vector2(x - center.x, y - center.y).length()
			if d >= radius - 1.3 and d <= radius + 0.4:
				_set_cell(Vector2i(x, y), TileType.ROAD)

func _make_districts() -> void:
	# north park
	_set_rect(Vector2i(34, 6), Vector2i(28, 20), TileType.PARK)
	# west posh area: larger blocks and green
	_place_building_blocks(Rect2i(6, 28, 24, 44), 6, 6, 2)
	# east council estate: tight dense blocks
	_place_building_blocks(Rect2i(66, 24, 24, 50), 4, 4, 1)
	# south commercial/warehouse
	_place_building_blocks(Rect2i(12, 76, 76, 16), 10, 8, 2)
	# central high street shops
	_place_building_blocks(Rect2i(20, 36, 56, 8), 5, 3, 1)
	_place_building_blocks(Rect2i(20, 48, 56, 8), 5, 3, 1)

func _place_building_blocks(area: Rect2i, bw: int, bh: int, spacing: int) -> void:
	var y := area.position.y
	while y < area.end.y - bh:
		var x := area.position.x
		while x < area.end.x - bw:
			_set_rect(Vector2i(x, y), Vector2i(bw, bh), TileType.BUILDING)
			x += bw + spacing
		y += bh + spacing

func _make_river() -> void:
	for y in range(0, C.MAP_HEIGHT):
		var cx := 50 + int(sin(float(y) * 0.12) * 6.0)
		_set_rect(Vector2i(cx, y), Vector2i(4, 1), TileType.WATER)

func _make_pavements_and_alleys() -> void:
	for y in range(1, C.MAP_HEIGHT - 1):
		for x in range(1, C.MAP_WIDTH - 1):
			if grid[y][x] == TileType.ROAD:
				for o in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var c := Vector2i(x, y) + o
					if _in_bounds(c) and grid[c.y][c.x] == TileType.PARK:
						grid[c.y][c.x] = TileType.PAVEMENT
	# alleys between dense estates
	for y in range(26, 72, 6):
		_set_rect(Vector2i(70, y), Vector2i(1, 4), TileType.ALLEY)

func _index_cells() -> void:
	for y in range(C.MAP_HEIGHT):
		for x in range(C.MAP_WIDTH):
			var cell := Vector2i(x, y)
			match int(grid[y][x]):
				TileType.PAVEMENT, TileType.ALLEY:
					pavement_cells.append(cell)
				TileType.ROAD:
					road_cells.append(cell)
	# restricted area sample in warehouse at night
	for x in range(22, 36):
		for y in range(78, 86):
			restricted_cells.append(Vector2i(x, y))

func _set_rect(pos: Vector2i, size: Vector2i, t: int) -> void:
	for y in range(pos.y, pos.y + size.y):
		for x in range(pos.x, pos.x + size.x):
			_set_cell(Vector2i(x, y), t)

func _set_cell(c: Vector2i, t: int) -> void:
	if _in_bounds(c):
		grid[c.y][c.x] = t

func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < C.MAP_WIDTH and c.y < C.MAP_HEIGHT

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(floor(world_pos.x / C.TILE_SIZE), floor(world_pos.y / C.TILE_SIZE))

func cell_to_world(cell: Vector2i) -> Vector2:
	return (Vector2(cell.x, cell.y) + Vector2(0.5, 0.5)) * C.TILE_SIZE

func get_tile(cell: Vector2i) -> int:
	if not _in_bounds(cell):
		return TileType.BUILDING
	return int(grid[cell.y][cell.x])

func is_walkable(world_pos: Vector2) -> bool:
	var t := get_tile(world_to_cell(world_pos))
	return t in [TileType.ROAD, TileType.PAVEMENT, TileType.PARK, TileType.ALLEY]

func is_driveable(world_pos: Vector2) -> bool:
	var t := get_tile(world_to_cell(world_pos))
	return t in [TileType.ROAD, TileType.PAVEMENT]

func random_pavement_world() -> Vector2:
	if pavement_cells.is_empty():
		return Vector2.ZERO
	return cell_to_world(pavement_cells[randi() % pavement_cells.size()])

func random_road_world() -> Vector2:
	if road_cells.is_empty():
		return Vector2.ZERO
	return cell_to_world(road_cells[randi() % road_cells.size()])
