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

@onready var sprite: ColorRect = $Visual
@onready var camera: Camera2D = $Camera2D
@onready var interact_area: Area2D = $InteractArea

func _ready() -> void:
	camera.enabled = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.zoom = Vector2(0.32, 0.32)
	interact_area.area_entered.connect(_on_area_entered)
	interact_area.area_exited.connect(_on_area_exited)

func _physics_process(_delta: float) -> void:
	if in_vehicle:
		global_position = current_vehicle.global_position
		rotation = current_vehicle.rotation
		if Input.is_action_just_pressed("interact"):
			attempt_interact()
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length() > 0.01:
		facing = input_dir.normalized()
	var target_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	velocity = input_dir.normalized() * target_speed

	var desired := global_position + velocity * get_physics_process_delta_time()
	if world_root and world_root.has_method("can_walk_to") and not world_root.can_walk_to(desired):
		velocity = Vector2.ZERO
	move_and_slide()

	if velocity.length() > 0.1:
		rotation = facing.angle()
	GameState.player_world_position = global_position

	if Input.is_action_just_pressed("interact"):
		attempt_interact()

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

func _on_area_entered(area: Area2D) -> void:
	var owner := area.get_parent()
	if owner and owner != self and not nearby_interactables.has(owner):
		nearby_interactables.append(owner)

func _on_area_exited(area: Area2D) -> void:
	var owner := area.get_parent()
	nearby_interactables.erase(owner)
