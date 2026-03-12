extends "res://scripts/vehicles/vehicle.gd"

@export var target: Node2D
@export var pursuit: bool = false
@export var lose_sight_seconds: float = 45.0
@export var pursuit_level: int = 1

var los_timer: float = 0.0
var path_repath_timer: float = 0.0
var road_path: Array[Vector2i] = []
var path_index: int = 0

func _ready() -> void:
	top_speed = 460.0
	acceleration = 340.0
	low_speed_turn_rate = 2.6
	high_speed_turn_rate = 1.2
	visual.color = Color("7aa8ff")

func _physics_process(delta: float) -> void:
	if pursuit and target:
		ai_drive(delta)
	else:
		_patrol_idle(delta)
	super._physics_process(delta)

func ai_drive(delta: float) -> void:
	_ensure_los_timer(delta)
	if not pursuit:
		return

	path_repath_timer -= delta
	if path_repath_timer <= 0.0:
		_recompute_path_to_target()
		path_repath_timer = 0.35

	var desired_world: Vector2 = target.global_position
	if not road_path.is_empty() and path_index < road_path.size():
		var wr: Node = _world_root()
		if wr and wr.has_method("get"):
			var city_map: CityMap = wr.get("city_map") as CityMap
			if city_map:
				desired_world = city_map.cell_to_world(road_path[path_index])
		if global_position.distance_to(desired_world) < 18.0:
			path_index = min(path_index + 1, road_path.size() - 1)

	var to_target: Vector2 = desired_world - global_position
	var desired_angle: float = to_target.angle()
	var angle_diff: float = wrapf(desired_angle - rotation, -PI, PI)
	steer_input = clampf(angle_diff * 1.6, -1.0, 1.0)

	var dist_to_player: float = global_position.distance_to(target.global_position)
	if dist_to_player < 8.0 * 32.0:
		# Close range: abandon path and cut corners directly like GTA cops.
		var direct: Vector2 = target.global_position - global_position
		steer_input = clampf(wrapf(direct.angle() - rotation, -PI, PI) * 2.2, -1.0, 1.0)
		velocity_vec += Vector2.RIGHT.rotated(rotation) * (acceleration * 1.05) * delta
	else:
		velocity_vec += Vector2.RIGHT.rotated(rotation) * acceleration * delta
	_clamp_longitudinal_speed()

	if dist_to_player < 30.0 and WantedSystem:
		WantedSystem.apply_capture_consequences(target)
		pursuit = false

func _ensure_los_timer(delta: float) -> void:
	var wr: Node = _world_root()
	if wr and wr.has_method("has_line_of_sight_to_player"):
		if wr.has_line_of_sight_to_player(global_position):
			los_timer = 0.0
		else:
			los_timer += delta
			if los_timer >= lose_sight_seconds:
				pursuit = false
				road_path.clear()
				path_index = 0
				GameState.notify("Police lost visual contact")

func _recompute_path_to_target() -> void:
	var wr: Node = _world_root()
	if wr == null or target == null:
		return
	var city_map: CityMap = wr.get("city_map") as CityMap
	if city_map == null:
		return
	var start_cell: Vector2i = city_map.world_to_cell(global_position)
	var goal_cell: Vector2i = city_map.world_to_cell(target.global_position)
	road_path = GridPathfinder.find_path(
		start_cell,
		goal_cell,
		func(c: Vector2i): return city_map.is_cell_driveable(c),
		func(c: Vector2i): return city_map.get_cardinal_neighbors(c),
		1800
	)
	path_index = 0

func _world_root() -> Node:
	return get_tree().current_scene

func _patrol_idle(delta: float) -> void:
	steer_input = sin(Time.get_ticks_msec() * 0.001 + float(get_instance_id() % 100)) * 0.3
	velocity_vec += Vector2.RIGHT.rotated(rotation) * (acceleration * 0.35) * delta
	_clamp_longitudinal_speed()

func set_pursuit_profile(level: int) -> void:
	pursuit_level = level
	lose_sight_seconds = 45.0
	if level == 2:
		lose_sight_seconds = 60.0
	elif level >= 3:
		lose_sight_seconds = 90.0
