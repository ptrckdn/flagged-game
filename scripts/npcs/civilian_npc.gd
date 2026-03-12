extends CharacterBody2D
class_name CivilianNPC

@export var npc_type: String = "Office Worker"
@export var walk_speed: float = 80.0
@export var sprint_speed: float = 185.0

enum AiMode {
	DISABLED,
	WANDERING,
	PANIC
}

var world_root: Node
var ai_mode: int = AiMode.WANDERING
var destination: Vector2 = Vector2.ZERO
var path_cells: Array[Vector2i] = []
var path_index: int = 0
var run_to_target: bool = false
var scatter_timer: float = 0.0
var panic_repath_timer: float = 0.0
var heading_dir: Vector2 = Vector2.RIGHT

@onready var visual: ColorRect = $Visual

func _ready() -> void:
	destination = global_position
	visual.color = Color.from_hsv(randf(), 0.7, 0.95)
	_start_wandering()

func _physics_process(delta: float) -> void:
	if world_root and world_root.has_method("is_npc_active") and not world_root.is_npc_active(global_position):
		return

	if ai_mode == AiMode.PANIC:
		_update_panic(delta)
	elif ai_mode == AiMode.WANDERING:
		_update_wandering(delta)

	move_and_slide()

func _update_wandering(_delta: float) -> void:
	if _continue_walk_to_waypoint():
		return
	if not _choose_walk_waypoint(false):
		_start_panic()
		return
	_continue_walk_to_waypoint()

func _update_panic(delta: float) -> void:
	scatter_timer -= delta
	panic_repath_timer -= delta
	if scatter_timer <= 0.0:
		_start_wandering()
		return
	if panic_repath_timer <= 0.0:
		_choose_walk_waypoint(true)
		panic_repath_timer = 0.35
	_continue_walk_to_waypoint()

func _start_wandering() -> void:
	ai_mode = AiMode.WANDERING
	run_to_target = false
	_choose_walk_waypoint(false)

func _start_panic() -> void:
	ai_mode = AiMode.PANIC
	run_to_target = true
	scatter_timer = max(scatter_timer, 2.0)
	panic_repath_timer = 0.0
	_choose_walk_waypoint(true)

func _continue_walk_to_waypoint() -> bool:
	_follow_path_if_any()
	var to_target: Vector2 = destination - global_position
	if to_target.length_squared() <= 8.0 * 8.0:
		velocity = Vector2.ZERO
		return false

	heading_dir = to_target.normalized()
	var speed: float = sprint_speed if run_to_target else walk_speed
	velocity = heading_dir * speed
	return true

func _follow_path_if_any() -> void:
	if path_cells.is_empty():
		return
	if path_index >= path_cells.size():
		path_cells.clear()
		return
	var city_map: CityMap = world_root.city_map as CityMap
	if city_map == null:
		return
	var waypoint_world: Vector2 = city_map.cell_to_world(path_cells[path_index])
	if global_position.distance_to(waypoint_world) < 10.0:
		path_index += 1
		if path_index >= path_cells.size():
			path_cells.clear()
			return
		waypoint_world = city_map.cell_to_world(path_cells[path_index])
	destination = waypoint_world

func _choose_walk_waypoint(is_panic: bool) -> bool:
	if world_root == null:
		return false
	var city_map: CityMap = world_root.city_map as CityMap
	if city_map == null:
		return false

	var current_cell: Vector2i = city_map.world_to_cell(global_position)
	var current_dir: Vector2i = _map_dir_from_heading(heading_dir)
	var dirs: Array[Vector2i] = [
		current_dir,
		Vector2i(-current_dir.y, current_dir.x),
		Vector2i(current_dir.y, -current_dir.x),
		-current_dir
	]

	var selected: Vector2i = Vector2i(-9999, -9999)
	for d in dirs:
		var cand: Vector2i = current_cell + d
		if not city_map.is_cell_in_bounds(cand):
			continue
		if city_map.is_cell_pavement(cand):
			selected = cand
			break
		if is_panic:
			var t: int = city_map.get_tile(cand)
			if t == CityMap.TileType.ROAD or t == CityMap.TileType.PARK:
				selected = cand
				break

	if selected.x == -9999:
		return false

	var goal: Vector2i = selected
	if not is_panic:
		goal = _random_pavement_goal(current_cell, 10)
	var path: Array[Vector2i] = GridPathfinder.find_path(
		current_cell,
		goal,
		func(c: Vector2i): return city_map.is_cell_pavement(c),
		func(c: Vector2i): return city_map.get_cardinal_neighbors(c),
		400
	)
	if path.is_empty():
		path = [selected]
	path_cells = path
	path_index = 0
	var subx: float = randf_range(0.25, 0.75)
	var suby: float = randf_range(0.25, 0.75)
	destination = (Vector2(path_cells[min(path_index, path_cells.size() - 1)]) + Vector2(subx, suby)) * 32.0
	return true

func _random_pavement_goal(origin: Vector2i, radius: int) -> Vector2i:
	var city_map: CityMap = world_root.city_map as CityMap
	if city_map == null:
		return origin
	for _i in 20:
		var c: Vector2i = origin + Vector2i(randi_range(-radius, radius), randi_range(-radius, radius))
		if city_map.is_cell_pavement(c):
			return c
	return origin

func _map_dir_from_heading(dir: Vector2) -> Vector2i:
	if abs(dir.x) > abs(dir.y):
		return Vector2i(1, 0) if dir.x >= 0.0 else Vector2i(-1, 0)
	return Vector2i(0, 1) if dir.y >= 0.0 else Vector2i(0, -1)

func trigger_scatter(from_pos: Vector2) -> void:
	if ai_mode == AiMode.PANIC and scatter_timer > 0.2:
		return
	var away: Vector2 = (global_position - from_pos).normalized()
	if away.length() < 0.1:
		away = Vector2.RIGHT.rotated(randf() * TAU)
	heading_dir = away
	_start_panic()

func on_player_interact(_player: Node) -> void:
	if world_root and world_root.has_method("open_dialogue_for_npc"):
		world_root.open_dialogue_for_npc(self)
