extends Node2D

const CityMapScript := preload("res://scripts/world/city_map.gd")
const PlayerScene := preload("res://scenes/player/player.tscn")
const VehicleScene := preload("res://scenes/vehicles/vehicle.tscn")
const PoliceVehicleScene := preload("res://scenes/vehicles/police_vehicle.tscn")
const NPCScene := preload("res://scenes/npcs/civilian_npc.tscn")
const DoorScene := preload("res://scenes/world/interior_door.tscn")
const ServiceTerminalScene := preload("res://scenes/world/service_terminal.tscn")

const VEHICLE_ARCHETYPES: Array[Dictionary] = [
	{
		"id": "hatchback",
		"weight": 30,
		"top_speed": 365.0,
		"reverse_speed": 115.0,
		"acceleration": 220.0,
		"brake_force": 290.0,
		"low_turn": 3.8,
		"high_turn": 1.9,
		"max_health": 85,
		"mass_factor": 0.9,
		"coast_drag": 0.93,
		"drift_factor": 0.75,
		"scale_x": 0.95,
		"scale_y": 0.95
	},
	{
		"id": "family",
		"weight": 35,
		"top_speed": 400.0,
		"reverse_speed": 120.0,
		"acceleration": 205.0,
		"brake_force": 270.0,
		"low_turn": 3.4,
		"high_turn": 1.6,
		"max_health": 100,
		"mass_factor": 1.0,
		"coast_drag": 0.94,
		"drift_factor": 0.85
	},
	{
		"id": "sports",
		"weight": 15,
		"top_speed": 455.0,
		"reverse_speed": 130.0,
		"acceleration": 255.0,
		"brake_force": 300.0,
		"low_turn": 3.7,
		"high_turn": 1.4,
		"max_health": 78,
		"mass_factor": 0.85,
		"coast_drag": 0.955,
		"drift_factor": 0.92,
		"scale_x": 1.0,
		"scale_y": 0.9
	},
	{
		"id": "van",
		"weight": 13,
		"top_speed": 335.0,
		"reverse_speed": 105.0,
		"acceleration": 160.0,
		"brake_force": 220.0,
		"low_turn": 2.8,
		"high_turn": 1.2,
		"max_health": 130,
		"mass_factor": 1.25,
		"coast_drag": 0.925,
		"drift_factor": 0.72,
		"scale_x": 1.1,
		"scale_y": 1.05
	},
	{
		"id": "truck",
		"weight": 7,
		"top_speed": 300.0,
		"reverse_speed": 95.0,
		"acceleration": 135.0,
		"brake_force": 200.0,
		"low_turn": 2.3,
		"high_turn": 0.95,
		"max_health": 165,
		"mass_factor": 1.55,
		"coast_drag": 0.91,
		"drift_factor": 0.6,
		"scale_x": 1.2,
		"scale_y": 1.1
	}
]

var city_map: CityMap
var player: PlayerController
var npcs: Array[CivilianNPC] = []
var parked_vehicles: Array[VehicleController] = []
var police_vehicles: Array[Node] = []
var revisit_counter: Dictionary = {}
var conversation_window: Array[float] = []
var _last_region_key := ""
var _last_hitped_time: float = -999.0

@onready var city_renderer: Node2D = $CityRenderer
@onready var city_tilemap: TileMap = $CityTileMap
@onready var dynamic_layer: Node2D = $Dynamic
@onready var hud: HUD = $HUD
@onready var dialogue_box: DialogueBox = $DialogueBox
@onready var mission_executor: Node = $MissionExecutor
@onready var mission_select: Control = $MissionSelect

func _ready() -> void:
	randomize()
	city_map = CityMapScript.new()
	city_map.build()
	city_renderer.city_map = city_map
	city_renderer.queue_redraw()
	if city_tilemap and city_tilemap.has_method("build_from_city_map"):
		city_tilemap.build_from_city_map(city_map)
		city_tilemap.visible = false
	city_renderer.visible = true

	_spawn_player()
	_spawn_vehicles(20)
	_spawn_npcs(42)
	_spawn_police_background(2)
	_spawn_doors_and_services()

	WantedSystem.chase_requested.connect(_on_chase_requested)
	WantedSystem.stop_event_requested.connect(_on_stop_event)
	WantedSystem.helicopter_state_changed.connect(_on_helicopter)
	GameState.day_advanced.connect(_on_day_advanced)

	if not SaveSystem.load_game():
		GameState.notify("Welcome to FLAGGED")
	elif GameState.player_world_position != Vector2.ZERO:
		player.global_position = GameState.player_world_position
	_ensure_player_spawn_valid()
	GameState.notify("Walk with WASD. Press E near a car to hotwire and drive.")
	if hud and hud.minimap:
		hud.minimap.world_root = self
	if mission_executor:
		mission_executor.world_root = self
	if mission_select:
		mission_select.mission_chosen.connect(_on_mission_selected)

func _process(delta: float) -> void:
	_track_passive_meter(delta)
	_update_police_targets()
	_handle_npc_scatter()
	_handle_vehicle_collisions()

func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	player.world_root = self
	player.global_position = city_map.cell_to_world(Vector2i(28, 46))
	var map_px_w: int = city_map.grid[0].size() * 32
	var map_px_h: int = city_map.grid.size() * 32
	if player.camera:
		player.camera.limit_left = 0
		player.camera.limit_top = 0
		player.camera.limit_right = map_px_w
		player.camera.limit_bottom = map_px_h
	dynamic_layer.add_child(player)

func _ensure_player_spawn_valid() -> void:
	if player == null:
		return
	if _is_valid_player_position(player.global_position):
		return
	var start_cell: Vector2i = city_map.world_to_cell(player.global_position)
	for radius in range(1, 14):
		for y in range(start_cell.y - radius, start_cell.y + radius + 1):
			for x in range(start_cell.x - radius, start_cell.x + radius + 1):
				var c: Vector2i = Vector2i(x, y)
				if not city_map.is_cell_in_bounds(c):
					continue
				var candidate: Vector2 = city_map.cell_to_world(c)
				if _is_valid_player_position(candidate):
					player.global_position = candidate
					GameState.player_world_position = candidate
					return
	var fallback: Vector2 = get_respawn_position()
	player.global_position = fallback
	GameState.player_world_position = fallback

func ensure_player_unstuck() -> void:
	if player == null:
		return
	if _is_valid_player_position(player.global_position):
		return
	_ensure_player_spawn_valid()

func _is_valid_player_position(world_pos: Vector2) -> bool:
	if not city_map.is_walkable(world_pos):
		return false
	if _is_vehicle_blocking(world_pos, 15.0, null, false):
		return false
	# Avoid "valid but trapped" spawn points by requiring at least one free step.
	var step: float = 14.0
	var dirs: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	for d in dirs:
		var probe: Vector2 = world_pos + d * step
		if city_map.is_walkable(probe) and not _is_vehicle_blocking(probe, 15.0, null, false):
			return true
	return false

func _spawn_vehicles(count: int) -> void:
	var near_player_spawns: Array[Vector2] = [
		city_map.cell_to_world(Vector2i(30, 46)),
		city_map.cell_to_world(Vector2i(32, 46)),
		city_map.cell_to_world(Vector2i(34, 46)),
		city_map.cell_to_world(Vector2i(30, 72)),
		city_map.cell_to_world(Vector2i(62, 46))
	]
	for i in range(count):
		var car: VehicleController = VehicleScene.instantiate()
		if i < near_player_spawns.size():
			car.global_position = near_player_spawns[i]
		else:
			car.global_position = _find_parked_car_spawn()
		car.rotation = _road_aligned_rotation(car.global_position)
		dynamic_layer.add_child(car)
		var profile: Dictionary = _roll_vehicle_archetype()
		if car.has_method("apply_archetype"):
			car.apply_archetype(profile)
		if car.visual:
			car.visual.color = Color.from_hsv(randf(), 0.65, 0.9)
		parked_vehicles.append(car)

func _find_parked_car_spawn() -> Vector2:
	var fallback: Vector2 = city_map.random_road_world()
	for _attempt in range(100):
		var candidate: Vector2 = city_map.random_road_world()
		var near_player: bool = player != null and candidate.distance_to(player.global_position) < 7.0 * 32.0
		if near_player:
			continue
		var too_close: bool = false
		for v in parked_vehicles:
			if not is_instance_valid(v):
				continue
			if candidate.distance_to(v.global_position) < 3.5 * 32.0:
				too_close = true
				break
		if too_close:
			continue
		return candidate
	return fallback

func _road_aligned_rotation(world_pos: Vector2) -> float:
	var cell: Vector2i = city_map.world_to_cell(world_pos)
	var left: int = city_map.get_tile(cell + Vector2i.LEFT)
	var right: int = city_map.get_tile(cell + Vector2i.RIGHT)
	var up: int = city_map.get_tile(cell + Vector2i.UP)
	var down: int = city_map.get_tile(cell + Vector2i.DOWN)
	var horizontal_score: int = int(left == CityMap.TileType.ROAD) + int(right == CityMap.TileType.ROAD)
	var vertical_score: int = int(up == CityMap.TileType.ROAD) + int(down == CityMap.TileType.ROAD)
	if horizontal_score >= vertical_score:
		return 0.0
	return PI * 0.5

func _spawn_police_background(count: int) -> void:
	for _i in range(count):
		var unit = PoliceVehicleScene.instantiate()
		unit.global_position = city_map.random_road_world()
		unit.target = player
		unit.pursuit = false
		dynamic_layer.add_child(unit)
		police_vehicles.append(unit)

func _spawn_npcs(count: int) -> void:
	var types: Array[String] = ["Shopkeeper", "Pensioner", "Student", "Office Worker", "Bus Driver", "Courier", "Council Clerk", "Nurse", "Barfly", "Journalist"]
	for _i in range(count):
		var npc: CivilianNPC = NPCScene.instantiate()
		npc.npc_type = types[randi() % types.size()]
		npc.global_position = city_map.random_pavement_world()
		npc.world_root = self
		dynamic_layer.add_child(npc)
		npcs.append(npc)

func can_walk_to(world_pos: Vector2, ignore_vehicle: VehicleController = null) -> bool:
	if not city_map.is_walkable(world_pos):
		return false
	return not _is_vehicle_blocking(world_pos, 15.0, ignore_vehicle, true)

func can_drive_to(world_pos: Vector2, ignore_vehicle: VehicleController = null) -> bool:
	if not city_map.is_driveable(world_pos):
		return false
	return not _is_vehicle_blocking(world_pos, 23.0, ignore_vehicle, false)

func _is_vehicle_blocking(world_pos: Vector2, radius: float, ignore_vehicle: VehicleController = null, allow_escape_for_player: bool = false) -> bool:
	for v in parked_vehicles:
		if not is_instance_valid(v):
			continue
		if ignore_vehicle != null and v == ignore_vehicle:
			continue
		if world_pos.distance_to(v.global_position) < radius:
			if allow_escape_for_player and player != null:
				var cur_d: float = player.global_position.distance_to(v.global_position)
				var next_d: float = world_pos.distance_to(v.global_position)
				if cur_d < radius and next_d > cur_d:
					continue
			return true
	for p in police_vehicles:
		var pv: VehicleController = p as VehicleController
		if pv == null or not is_instance_valid(pv):
			continue
		if ignore_vehicle != null and pv == ignore_vehicle:
			continue
		if world_pos.distance_to(pv.global_position) < radius:
			if allow_escape_for_player and player != null:
				var cur_pd: float = player.global_position.distance_to(pv.global_position)
				var next_pd: float = world_pos.distance_to(pv.global_position)
				if cur_pd < radius and next_pd > cur_pd:
					continue
			return true
	return false

func is_pavement_world(world_pos: Vector2) -> bool:
	var t: int = city_map.get_tile(city_map.world_to_cell(world_pos))
	return t in [CityMap.TileType.PAVEMENT, CityMap.TileType.ALLEY]

func random_pavement_cell_near(origin: Vector2i, radius: int) -> Vector2i:
	for _i in 16:
		var c: Vector2i = origin + Vector2i(randi_range(-radius, radius), randi_range(-radius, radius))
		var t: int = city_map.get_tile(c)
		if t == CityMap.TileType.PAVEMENT or t == CityMap.TileType.ALLEY:
			return c
	return Vector2i(-1, -1)

func is_npc_active(pos: Vector2) -> bool:
	return player.global_position.distance_to(pos) <= 30 * 32

func get_respawn_position() -> Vector2:
	return city_map.cell_to_world(Vector2i(22, 50))

func open_dialogue_for_npc(npc: CivilianNPC) -> void:
	conversation_window.append(Time.get_unix_time_from_system())
	dialogue_box.open_for_npc(npc)

func _on_chase_requested(level: int) -> void:
	var desired: int = clampi(level + (1 if GameState.get_tier() == "BLACK" else 0), 1, 4)
	while police_vehicles.size() < desired + 1:
		var unit: Node2D = PoliceVehicleScene.instantiate()
		unit.global_position = city_map.random_road_world()
		unit.target = player
		dynamic_layer.add_child(unit)
		police_vehicles.append(unit)
	for i in range(police_vehicles.size()):
		var active: bool = i < desired
		police_vehicles[i].pursuit = active
		if police_vehicles[i].has_method("set_pursuit_profile"):
			police_vehicles[i].set_pursuit_profile(desired)
	GameState.notify("Police pursuit level %d" % desired)

func _on_stop_event() -> void:
	GameState.notify("Routine check requested")
	if GameState.has_tag("contraband"):
		GameState.confiscate_all_items()
		GameState.add_cash(-int(GameState.cash * randf_range(0.1, 0.2)))
		GameState.notify("Contraband found. Fine issued.")

func _on_helicopter(active: bool) -> void:
	if active:
		GameState.notify("Police helicopter overhead")
	else:
		GameState.notify("Helicopter departed")

func _on_day_advanced(_day: int) -> void:
	revisit_counter.clear()

func _spawn_doors_and_services() -> void:
	var flat_door: Node2D = DoorScene.instantiate()
	flat_door.destination_scene = "res://scenes/interiors/flat.tscn"
	flat_door.global_position = city_map.cell_to_world(Vector2i(23, 50))
	dynamic_layer.add_child(flat_door)

	var pub_door: Node2D = DoorScene.instantiate()
	pub_door.destination_scene = "res://scenes/interiors/pub.tscn"
	pub_door.global_position = city_map.cell_to_world(Vector2i(28, 46))
	dynamic_layer.add_child(pub_door)

	var shop_door: Node2D = DoorScene.instantiate()
	shop_door.destination_scene = "res://scenes/interiors/shop.tscn"
	shop_door.global_position = city_map.cell_to_world(Vector2i(35, 46))
	dynamic_layer.add_child(shop_door)

	var workshop: Node2D = ServiceTerminalScene.instantiate()
	workshop.mode = "workshop"
	workshop.global_position = city_map.cell_to_world(Vector2i(60, 38))
	dynamic_layer.add_child(workshop)

	var compliance: Node2D = ServiceTerminalScene.instantiate()
	compliance.mode = "compliance"
	compliance.global_position = city_map.cell_to_world(Vector2i(26, 71))
	dynamic_layer.add_child(compliance)

	var bribe: Node2D = ServiceTerminalScene.instantiate()
	bribe.mode = "bribe"
	bribe.global_position = city_map.cell_to_world(Vector2i(69, 45))
	dynamic_layer.add_child(bribe)

func _track_passive_meter(_delta: float) -> void:
	var cell: Vector2i = city_map.world_to_cell(player.global_position)
	var key: String = "%d_%d" % [int(floor(float(cell.x) / 8.0)), int(floor(float(cell.y) / 8.0))]
	if key != _last_region_key:
		_last_region_key = key
		revisit_counter[key] = int(revisit_counter.get(key, 0)) + 1
		if revisit_counter[key] == 3:
			GameState.add_meter(2, "Unusual movement pattern detected")

	conversation_window = conversation_window.filter(func(t): return Time.get_unix_time_from_system() - t <= 60.0)
	if conversation_window.size() >= 5:
		GameState.add_meter(3, "Excessive social contact logged")
		conversation_window.clear()

	var hour: int = int(floor(float(GameState.world_time_minutes) / 60.0))
	if hour >= 23:
		if randi() % 60 == 0:
			GameState.add_meter(1, "Curfew advisory in effect")

	if cell in city_map.restricted_cells and hour >= 21:
		if randi() % 240 == 0:
			GameState.add_meter(2, "Restricted area monitoring active")

func _update_police_targets() -> void:
	for p in police_vehicles:
		p.target = player

func has_line_of_sight_to_player(from_pos: Vector2) -> bool:
	if from_pos.distance_to(player.global_position) >= 22 * 32:
		return false
	var steps: int = 18
	for i in range(1, steps):
		var t: float = float(i) / float(steps)
		var p: Vector2 = from_pos.lerp(player.global_position, t)
		var tile: int = city_map.get_tile(city_map.world_to_cell(p))
		if tile == CityMap.TileType.BUILDING or tile == CityMap.TileType.WATER:
			return false
	return true

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("special_action"):
		# shop robbery prototype action
		GameState.add_cash(randi_range(100, 300))
		GameState.add_meter(20, "Shop alarm triggered")
		WantedSystem.trigger_offence(2)

func _handle_npc_scatter() -> void:
	if not player or not player.in_vehicle:
		return
	var car_tile: int = city_map.get_tile(city_map.world_to_cell(player.global_position))
	if car_tile != CityMap.TileType.PAVEMENT and car_tile != CityMap.TileType.ALLEY:
		return
	for npc in npcs:
		if not is_instance_valid(npc):
			continue
		var dist: float = npc.global_position.distance_to(player.global_position)
		if dist <= 96.0:
			npc.trigger_scatter(player.global_position)
		if dist <= 18.0 and player.current_vehicle and abs(player.current_vehicle.speed) > 90.0:
			var push: Vector2 = (npc.global_position - player.global_position).normalized()
			if push.length() < 0.1:
				push = Vector2.RIGHT.rotated(randf() * TAU)
			npc.global_position += push * 28.0
			npc.trigger_scatter(player.global_position)
			var now: float = Time.get_unix_time_from_system()
			if now - _last_hitped_time > 0.8:
				_last_hitped_time = now
				WantedSystem.trigger_offence(2)
				GameState.add_meter(4, "Hit-and-run incident logged")

func _handle_vehicle_collisions() -> void:
	var all_vehicles: Array[VehicleController] = []
	for v in parked_vehicles:
		if is_instance_valid(v):
			all_vehicles.append(v)
	for p in police_vehicles:
		var pv: VehicleController = p as VehicleController
		if pv and is_instance_valid(pv):
			all_vehicles.append(pv)

	for i in range(all_vehicles.size()):
		for j in range(i + 1, all_vehicles.size()):
			var a: VehicleController = all_vehicles[i]
			var b: VehicleController = all_vehicles[j]
			var delta: Vector2 = b.global_position - a.global_position
			var dist: float = delta.length()
			var min_dist: float = 26.0
			if dist <= 0.001 or dist >= min_dist:
				continue
			var n: Vector2 = delta / dist
			var overlap: float = min_dist - dist
			a.global_position -= n * (overlap * 0.5)
			b.global_position += n * (overlap * 0.5)

			var a_speed: float = abs(a.speed)
			var b_speed: float = abs(b.speed)
			var a_is_police: bool = a.get_script() != null and String(a.get_script().resource_path) == "res://scripts/vehicles/police_vehicle.gd"
			var b_is_police: bool = b.get_script() != null and String(b.get_script().resource_path) == "res://scripts/vehicles/police_vehicle.gd"
			var a_weight: float = (a.mass_factor if a.has_method("apply_archetype") else 1.0) + (0.6 if a_is_police else 0.0)
			var b_weight: float = (b.mass_factor if b.has_method("apply_archetype") else 1.0) + (0.6 if b_is_police else 0.0)
			var a_push: float = clampf((b_speed / max(a_weight, 0.1)) * 0.35, 20.0, 180.0)
			var b_push: float = clampf((a_speed / max(b_weight, 0.1)) * 0.35, 20.0, 180.0)

			a.speed = -signf(a.speed if abs(a.speed) > 1.0 else 1.0) * a_push
			b.speed = -signf(b.speed if abs(b.speed) > 1.0 else 1.0) * b_push
			a.apply_damage(int(clampf((b_speed / 55.0) * b_weight, 2.0, 14.0)))
			b.apply_damage(int(clampf((a_speed / 55.0) * a_weight, 2.0, 14.0)))

func remove_random_npc() -> void:
	if npcs.is_empty():
		return
	var idx: int = randi() % npcs.size()
	var npc: CivilianNPC = npcs[idx]
	npcs.remove_at(idx)
	if is_instance_valid(npc):
		npc.queue_free()
	GameState.notify("An associate has been removed from public records.")

func open_mission_menu() -> void:
	if mission_select:
		mission_select.open_menu()

func _on_mission_selected(id: String) -> void:
	if MissionSystem.start_mission(id):
		GameState.notify("Mission started: %s" % id)

func _roll_vehicle_archetype() -> Dictionary:
	var total_weight := 0
	for profile in VEHICLE_ARCHETYPES:
		total_weight += int(profile.get("weight", 1))
	var pick := randi_range(1, max(total_weight, 1))
	var running := 0
	for profile in VEHICLE_ARCHETYPES:
		running += int(profile.get("weight", 1))
		if pick <= running:
			return profile
	return VEHICLE_ARCHETYPES[1]
