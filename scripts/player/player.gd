extends CharacterBody2D
class_name PlayerController

const C := preload("res://scripts/data/game_constants.gd")

@export var walk_speed := C.WALK_SPEED
@export var sprint_speed := C.SPRINT_SPEED
@export var interaction_radius := 36.0

var world_root: Node
var in_vehicle := false
var current_vehicle: Node = null
var facing := Vector2.DOWN
var nearby_interactables: Array[Node] = []
var _last_pos: Vector2 = Vector2.ZERO
var _stuck_timer: float = 0.0

@onready var sprite: ColorRect = $Visual
@onready var camera: Camera2D = $Camera2D
@onready var interact_area: Area2D = $InteractArea

func _ready() -> void:
	camera.enabled = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.zoom = Vector2(1.0, 1.0)
	_last_pos = global_position
	interact_area.area_entered.connect(_on_area_entered)
	interact_area.area_exited.connect(_on_area_exited)

func _physics_process(_delta: float) -> void:
	if in_vehicle:
		global_position = current_vehicle.global_position
		rotation = current_vehicle.rotation
		_update_vehicle_camera(_delta)
		if Input.is_action_just_pressed("interact"):
			attempt_interact()
		return

	# On-foot camera resets to neutral framing.
	camera.offset = camera.offset.lerp(Vector2.ZERO, clampf(_delta * 6.0, 0.0, 1.0))
	camera.zoom = camera.zoom.lerp(Vector2(1.0, 1.0), clampf(_delta * 5.0, 0.0, 1.0))

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length_squared() < 0.0001:
		# Fallback for editor/runtime input-map glitches.
		var fx: float = 0.0
		var fy: float = 0.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			fx -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			fx += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			fy -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			fy += 1.0
		input_dir = Vector2(fx, fy).normalized()
	if input_dir.length() > 0.01:
		facing = input_dir.normalized()
	var target_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	velocity = input_dir.normalized() * target_speed

	var desired := global_position + velocity * get_physics_process_delta_time()
	if world_root and world_root.has_method("can_walk_to") and not world_root.can_walk_to(desired):
		velocity = Vector2.ZERO
	move_and_slide()
	_handle_unstuck(input_dir, _delta)

	if velocity.length() > 0.1:
		rotation = facing.angle()
	GameState.player_world_position = global_position

	if Input.is_action_just_pressed("interact"):
		attempt_interact()

func _handle_unstuck(input_dir: Vector2, delta: float) -> void:
	if input_dir.length() < 0.1:
		_stuck_timer = 0.0
		_last_pos = global_position
		return
	if global_position.distance_to(_last_pos) < 0.5:
		_stuck_timer += delta
		if _stuck_timer > 0.35 and world_root and world_root.has_method("ensure_player_unstuck"):
			world_root.ensure_player_unstuck()
			_stuck_timer = 0.0
	else:
		_stuck_timer = 0.0
	_last_pos = global_position

func attempt_interact() -> void:
	if in_vehicle and current_vehicle and current_vehicle.has_method("try_exit_driver"):
		current_vehicle.try_exit_driver(self)
		return

	var best: Node = null
	var best_d := INF
	for n in nearby_interactables:
		if not is_instance_valid(n):
			continue
		var d := global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	if best and best.has_method("on_player_interact"):
		best.on_player_interact(self)

func enter_vehicle(vehicle: Node) -> void:
	in_vehicle = true
	current_vehicle = vehicle
	visible = false

func exit_vehicle(at_pos: Vector2) -> void:
	in_vehicle = false
	current_vehicle = null
	global_position = at_pos
	visible = true

func on_captured() -> void:
	if in_vehicle and current_vehicle and current_vehicle.has_method("disable_vehicle"):
		current_vehicle.disable_vehicle()
		exit_vehicle(current_vehicle.global_position + Vector2(24, 0))
	global_position = world_root.get_respawn_position() if world_root else Vector2.ZERO

func _update_vehicle_camera(delta: float) -> void:
	if not current_vehicle:
		return
	var vehicle_speed: float = abs(current_vehicle.speed)
	var speed_ratio: float = clampf(vehicle_speed / 400.0, 0.0, 1.0)
	var target_zoom: Vector2 = Vector2.ONE * lerpf(1.0, 0.78, speed_ratio)
	camera.zoom = camera.zoom.lerp(target_zoom, clampf(delta * 4.0, 0.0, 1.0))

	var forward: Vector2 = Vector2.RIGHT.rotated(current_vehicle.rotation)
	var lead_dist: float = lerpf(25.0, 145.0, speed_ratio)
	var target_offset: Vector2 = forward * lead_dist
	camera.offset = camera.offset.lerp(target_offset, clampf(delta * 3.5, 0.0, 1.0))

func _on_area_entered(area: Area2D) -> void:
	var area_parent: Node = area.get_parent()
	if area_parent and area_parent != self and not nearby_interactables.has(area_parent):
		nearby_interactables.append(area_parent)

func _on_area_exited(area: Area2D) -> void:
	var area_parent: Node = area.get_parent()
	nearby_interactables.erase(area_parent)
