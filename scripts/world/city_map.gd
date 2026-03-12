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
		for _x in range(C.MAP_WIDTH):
			grid[y].append(TileType.PARK)

	_make_base_road_grid()
	_make_roundabouts()
	_make_river_and_bridges()
	_make_districts()
	_make_pavements_and_alleys()
	_index_cells()

func _make_base_road_grid() -> void:
	var road_w: int = 4
	for x in range(4, C.MAP_WIDTH - 4):
		_set_rect(Vector2i(x, 21), Vector2i(1, road_w), TileType.ROAD, true)
		_set_rect(Vector2i(x, 43), Vector2i(1, road_w), TileType.ROAD, true) # high street
		_set_rect(Vector2i(x, 65), Vector2i(1, road_w), TileType.ROAD, true)
	for y in range(4, C.MAP_HEIGHT - 4):
		_set_rect(Vector2i(17, y), Vector2i(road_w, 1), TileType.ROAD, true)
		_set_rect(Vector2i(39, y), Vector2i(road_w, 1), TileType.ROAD, true)
		_set_rect(Vector2i(61, y), Vector2i(road_w, 1), TileType.ROAD, true)
		_set_rect(Vector2i(81, y), Vector2i(road_w, 1), TileType.ROAD, true)

func _make_roundabouts() -> void:
	_draw_roundabout(Vector2i(41, 45), 5)
	_draw_roundabout(Vector2i(63, 45), 5)
	_draw_roundabout(Vector2i(63, 67), 5)

func _draw_roundabout(center: Vector2i, radius: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var d: float = Vector2(x - center.x, y - center.y).length()
			if d >= radius - 1.2 and d <= radius + 0.5:
				_set_cell(Vector2i(x, y), TileType.ROAD, true)

func _make_river_and_bridges() -> void:
	for y in range(0, C.MAP_HEIGHT):
		var cx: int = 50 + int(sin(float(y) * 0.1) * 4.0)
		_set_rect(Vector2i(cx, y), Vector2i(3, 1), TileType.WATER, true)
	# bridges on arterial roads
	_set_rect(Vector2i(45, 21), Vector2i(12, 4), TileType.ROAD, true)
	_set_rect(Vector2i(45, 43), Vector2i(12, 4), TileType.ROAD, true)
	_set_rect(Vector2i(45, 65), Vector2i(12, 4), TileType.ROAD, true)

func _make_districts() -> void:
	# North-centre park
	_set_rect(Vector2i(30, 4), Vector2i(36, 16), TileType.PARK)

	# West posh area: larger buildings, more green pockets.
	_place_building_blocks(Rect2i(4, 26, 30, 36), 8, 6, 3)
	_set_rect(Vector2i(8, 30), Vector2i(6, 6), TileType.PARK)
	_set_rect(Vector2i(24, 50), Vector2i(8, 6), TileType.PARK)

	# East council estate: tighter, smaller blocks.
	_place_building_blocks(Rect2i(66, 26, 26, 44), 4, 4, 1)

	# South commercial/warehouse district.
	_place_building_blocks(Rect2i(8, 72, 84, 20), 12, 8, 2)

	# High street shops around centre road.
	_place_building_blocks(Rect2i(22, 36, 56, 7), 4, 3, 1)
	_place_building_blocks(Rect2i(22, 48, 56, 7), 4, 3, 1)

func _place_building_blocks(area: Rect2i, bw: int, bh: int, spacing: int) -> void:
	var y: int = area.position.y
	while y < area.end.y - bh:
		var x: int = area.position.x
		while x < area.end.x - bw:
			_set_rect(Vector2i(x, y), Vector2i(bw, bh), TileType.BUILDING)
			x += bw + spacing
		y += bh + spacing

func _make_pavements_and_alleys() -> void:
	var offsets: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for y in range(1, C.MAP_HEIGHT - 1):
		for x in range(1, C.MAP_WIDTH - 1):
			if grid[y][x] == TileType.ROAD:
				for off: Vector2i in offsets:
					var c: Vector2i = Vector2i(x, y) + off
					if _in_bounds(c) and grid[c.y][c.x] == TileType.PARK:
						grid[c.y][c.x] = TileType.PAVEMENT
	# pedestrian back alleys in estate
	for y in range(28, 70, 6):
		_set_rect(Vector2i(71, y), Vector2i(1, 4), TileType.ALLEY)
		_set_rect(Vector2i(77, y), Vector2i(1, 4), TileType.ALLEY)

func _index_cells() -> void:
	for y in range(C.MAP_HEIGHT):
		for x in range(C.MAP_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			match int(grid[y][x]):
				TileType.PAVEMENT, TileType.ALLEY:
					pavement_cells.append(cell)
				TileType.ROAD:
					road_cells.append(cell)
	for x in range(22, 36):
		for y in range(78, 86):
			restricted_cells.append(Vector2i(x, y))

func _set_rect(pos: Vector2i, size: Vector2i, t: int, force: bool = false) -> void:
	for y in range(pos.y, pos.y + size.y):
		for x in range(pos.x, pos.x + size.x):
			_set_cell(Vector2i(x, y), t, force)

func _set_cell(c: Vector2i, t: int, force: bool = false) -> void:
	if not _in_bounds(c):
		return
	if force:
		grid[c.y][c.x] = t
		return
	if t == TileType.BUILDING:
		var existing: int = int(grid[c.y][c.x])
		if existing == TileType.ROAD or existing == TileType.WATER:
			return
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

func is_cell_in_bounds(cell: Vector2i) -> bool:
	return _in_bounds(cell)

func is_cell_driveable(cell: Vector2i) -> bool:
	var t: int = get_tile(cell)
	return t == TileType.ROAD or t == TileType.PAVEMENT

func is_cell_pavement(cell: Vector2i) -> bool:
	var t: int = get_tile(cell)
	return t == TileType.PAVEMENT or t == TileType.ALLEY

func is_cell_walkable(cell: Vector2i) -> bool:
	var t: int = get_tile(cell)
	return t == TileType.ROAD or t == TileType.PAVEMENT or t == TileType.PARK or t == TileType.ALLEY

func get_cardinal_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var offsets: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for off: Vector2i in offsets:
		var n: Vector2i = cell + off
		if _in_bounds(n):
			out.append(n)
	return out

func is_walkable(world_pos: Vector2) -> bool:
	return is_cell_walkable(world_to_cell(world_pos))

func is_driveable(world_pos: Vector2) -> bool:
	return is_cell_driveable(world_to_cell(world_pos))

func random_pavement_world() -> Vector2:
	if pavement_cells.is_empty():
		return Vector2.ZERO
	return cell_to_world(pavement_cells[randi() % pavement_cells.size()])

func random_road_world() -> Vector2:
	if road_cells.is_empty():
		return Vector2.ZERO
	return cell_to_world(road_cells[randi() % road_cells.size()])
