extends Node2D

const CityMapScript := preload("res://scripts/world/city_map.gd")
const PlayerScene := preload("res://scenes/player/player.tscn")
const VehicleScene := preload("res://scenes/vehicles/vehicle.tscn")
const PoliceVehicleScene := preload("res://scenes/vehicles/police_vehicle.tscn")
const NPCScene := preload("res://scenes/npcs/civilian_npc.tscn")
const DoorScene := preload("res://scenes/world/interior_door.tscn")
const ServiceTerminalScene := preload("res://scenes/world/service_terminal.tscn")

var city_map: CityMap
var player: PlayerController
var npcs: Array[CivilianNPC] = []
var parked_vehicles: Array[VehicleController] = []
var police_vehicles: Array[Node] = []
var revisit_counter: Dictionary = {}
var conversation_window: Array[float] = []
var _last_region_key := ""

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
		city_renderer.visible = false

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

func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	player.world_root = self
	player.global_position = city_map.cell_to_world(Vector2i(28, 46))
	dynamic_layer.add_child(player)

func _spawn_vehicles(count: int) -> void:
	for i in range(count):
		var car: VehicleController = VehicleScene.instantiate()
		car.global_position = city_map.random_road_world() + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		car.rotation = randf() * TAU
		car.visual.color = Color.from_hsv(randf(), 0.65, 0.9)
		dynamic_layer.add_child(car)
		parked_vehicles.append(car)

func _spawn_police_background(count: int) -> void:
	for _i in range(count):
		var unit = PoliceVehicleScene.instantiate()
		unit.global_position = city_map.random_road_world()
		unit.target = player
		unit.pursuit = false
		dynamic_layer.add_child(unit)
		police_vehicles.append(unit)

func _spawn_npcs(count: int) -> void:
	var types := ["Shopkeeper", "Pensioner", "Student", "Office Worker", "Bus Driver", "Courier", "Council Clerk", "Nurse", "Barfly", "Journalist"]
	for _i in range(count):
		var npc: CivilianNPC = NPCScene.instantiate()
		npc.npc_type = types[randi() % types.size()]
		npc.global_position = city_map.random_pavement_world()
		npc.world_root = self
		dynamic_layer.add_child(npc)
		npcs.append(npc)

func can_walk_to(world_pos: Vector2) -> bool:
	return city_map.is_walkable(world_pos)

func can_drive_to(world_pos: Vector2) -> bool:
	return city_map.is_driveable(world_pos)

func is_pavement_world(world_pos: Vector2) -> bool:
	var t := city_map.get_tile(city_map.world_to_cell(world_pos))
	return t in [CityMap.TileType.PAVEMENT, CityMap.TileType.ALLEY]

func random_pavement_cell_near(origin: Vector2i, radius: int) -> Vector2i:
	for _i in 16:
		var c := origin + Vector2i(randi_range(-radius, radius), randi_range(-radius, radius))
		var t := city_map.get_tile(c)
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
	var desired := clampi(level + (1 if GameState.get_tier() == "BLACK" else 0), 1, 4)
	while police_vehicles.size() < desired + 1:
		var unit = PoliceVehicleScene.instantiate()
		unit.global_position = city_map.random_road_world()
		unit.target = player
		dynamic_layer.add_child(unit)
		police_vehicles.append(unit)
	for i in range(police_vehicles.size()):
		police_vehicles[i].pursuit = i < desired
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
	var flat_door = DoorScene.instantiate()
	flat_door.destination_scene = "res://scenes/interiors/flat.tscn"
	flat_door.global_position = city_map.cell_to_world(Vector2i(23, 50))
	dynamic_layer.add_child(flat_door)

	var pub_door = DoorScene.instantiate()
	pub_door.destination_scene = "res://scenes/interiors/pub.tscn"
	pub_door.global_position = city_map.cell_to_world(Vector2i(28, 46))
	dynamic_layer.add_child(pub_door)

	var shop_door = DoorScene.instantiate()
	shop_door.destination_scene = "res://scenes/interiors/shop.tscn"
	shop_door.global_position = city_map.cell_to_world(Vector2i(35, 46))
	dynamic_layer.add_child(shop_door)

	var workshop = ServiceTerminalScene.instantiate()
	workshop.mode = "workshop"
	workshop.global_position = city_map.cell_to_world(Vector2i(60, 38))
	dynamic_layer.add_child(workshop)

	var compliance = ServiceTerminalScene.instantiate()
	compliance.mode = "compliance"
	compliance.global_position = city_map.cell_to_world(Vector2i(26, 71))
	dynamic_layer.add_child(compliance)

	var bribe = ServiceTerminalScene.instantiate()
	bribe.mode = "bribe"
	bribe.global_position = city_map.cell_to_world(Vector2i(69, 45))
	dynamic_layer.add_child(bribe)

func _track_passive_meter(_delta: float) -> void:
	var cell := city_map.world_to_cell(player.global_position)
	var key := "%d_%d" % [cell.x / 8, cell.y / 8]
	if key != _last_region_key:
		_last_region_key = key
		revisit_counter[key] = int(revisit_counter.get(key, 0)) + 1
		if revisit_counter[key] == 3:
			GameState.add_meter(2, "Unusual movement pattern detected")

	conversation_window = conversation_window.filter(func(t): return Time.get_unix_time_from_system() - t <= 60.0)
	if conversation_window.size() >= 5:
		GameState.add_meter(3, "Excessive social contact logged")
		conversation_window.clear()

	var hour := int(GameState.world_time_minutes / 60)
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
	return from_pos.distance_to(player.global_position) < 22 * 32

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("special_action"):
		# shop robbery prototype action
		GameState.add_cash(randi_range(100, 300))
		GameState.add_meter(20, "Shop alarm triggered")
		WantedSystem.trigger_offence(2)

func _handle_npc_scatter() -> void:
	if not player or not player.in_vehicle:
		return
	for npc in npcs:
		if not is_instance_valid(npc):
			continue
		if npc.global_position.distance_to(player.global_position) < 80.0:
			npc.trigger_scatter(player.global_position)

func remove_random_npc() -> void:
	if npcs.is_empty():
		return
	var idx := randi() % npcs.size()
	var npc := npcs[idx]
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
