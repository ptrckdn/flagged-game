extends Node2D
class_name VehicleController

const C := preload("res://scripts/data/game_constants.gd")

@export var top_speed := C.CAR_TOP_SPEED
@export var reverse_speed := C.CAR_REVERSE_SPEED
@export var acceleration := 280.0
@export var brake_force := 360.0
@export var base_turn_speed := 2.8
@export var drift_factor := 0.9
@export var max_health := 100

var speed := 0.0
var steer_input := 0.0
var driver: PlayerController
var health := max_health
var is_disabled := false

@onready var visual: ColorRect = $Visual

func _physics_process(delta: float) -> void:
	if is_disabled:
		speed = move_toward(speed, 0.0, brake_force * delta)
		return

	if driver:
		_drive_input(delta)
	else:
		speed = move_toward(speed, 0.0, 100.0 * delta)

	var direction := Vector2.RIGHT.rotated(rotation)
	var velocity := direction * speed
	global_position += velocity * delta

	if get_parent() and get_parent().has_method("can_drive_to"):
		if not get_parent().can_drive_to(global_position):
			global_position -= velocity * delta
			speed *= -0.35
			apply_damage(5)

func _drive_input(delta: float) -> void:
	var throttle := Input.get_action_strength("move_up")
	var brake := Input.get_action_strength("move_down")
	steer_input = Input.get_axis("move_left", "move_right")

	if throttle > 0.01:
		speed = move_toward(speed, top_speed, acceleration * delta)
	elif brake > 0.01:
		if speed > 8.0:
			speed = move_toward(speed, 0.0, brake_force * delta)
		else:
			speed = move_toward(speed, -reverse_speed, acceleration * 0.7 * delta)
	else:
		speed = move_toward(speed, 0.0, 120.0 * delta)

	var speed_ratio := clamp(abs(speed) / top_speed, 0.0, 1.0)
	var turn_rate := lerp(base_turn_speed, base_turn_speed * 0.35, speed_ratio)
	rotation += steer_input * turn_rate * delta * signf(speed if abs(speed) > 1.0 else 1.0)

	# Drift/slip by preserving some previous momentum.
	speed = lerp(speed, speed * drift_factor, 0.04)

func on_player_interact(player: PlayerController) -> void:
	if driver != null:
		return
	if is_disabled:
		GameState.notify("This car is dead. Find another.")
		return
	await _hotwire_sequence()
	driver = player
	player.enter_vehicle(self)
	GameState.notify("Vehicle acquired")
	WantedSystem.trigger_offence(1)

func _hotwire_sequence() -> void:
	GameState.notify("Hotwiring...")
	await get_tree().create_timer(randf_range(1.0, 2.0)).timeout

func try_exit_driver(player: PlayerController) -> void:
	if driver != player:
		return
	if abs(speed) > 40.0:
		GameState.notify("Slow down to exit vehicle")
		return
	driver = null
	player.exit_vehicle(global_position + Vector2(24, 0).rotated(rotation))

func apply_damage(amount: int) -> void:
	health = max(0, health - amount)
	if health <= max_health / 3 and health > 0:
		visual.color = Color(0.35, 0.35, 0.35)
	if health == 0:
		disable_vehicle()

func disable_vehicle() -> void:
	is_disabled = true
	visual.color = Color(0.15, 0.15, 0.15)
	if driver:
		driver.exit_vehicle(global_position + Vector2(24, 0))
		driver = null
