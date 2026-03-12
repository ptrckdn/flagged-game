extends Node2D
class_name VehicleController

const C := preload("res://scripts/data/game_constants.gd")

@export var top_speed: float = C.CAR_TOP_SPEED
@export var reverse_speed: float = C.CAR_REVERSE_SPEED
@export var acceleration: float = 200.0
@export var brake_force: float = 280.0
@export var low_speed_turn_rate: float = 3.6
@export var high_speed_turn_rate: float = 1.8
@export var max_health: int = 100
@export var coast_drag: float = 0.94
@export var reverse_accel_multiplier: float = 0.65
@export var drift_factor: float = 0.85
@export var impact_bounce: float = 0.44

var speed: float = 0.0
var steer_input: float = 0.0
var velocity_vec: Vector2 = Vector2.ZERO
var angular_velocity: float = 0.0
var vehicle_class: String = "family"
var mass_factor: float = 1.0
var driver: PlayerController
var health: int = max_health
var is_disabled: bool = false

@onready var visual: ColorRect = $Visual

func _physics_process(delta: float) -> void:
	if is_disabled:
		speed = move_toward(speed, 0.0, brake_force * delta)
		velocity_vec = velocity_vec.move_toward(Vector2.ZERO, brake_force * delta)
		angular_velocity = move_toward(angular_velocity, 0.0, 3.2 * delta)
		rotation += angular_velocity * delta
		return

	if driver:
		_simulate_arcade_driving(delta)
	else:
		# Parked vehicles settle gradually instead of snapping to stop.
		velocity_vec *= pow(coast_drag, 60.0 * delta)
		angular_velocity = move_toward(angular_velocity, 0.0, 2.0 * delta)
		rotation += angular_velocity * delta
		speed = velocity_vec.length()

	var previous_pos: Vector2 = global_position
	global_position += velocity_vec * delta

	if get_parent() and get_parent().has_method("can_drive_to"):
		if not get_parent().can_drive_to(global_position, self):
			global_position = previous_pos
			# Bounce with momentum loss and slight spin for GTA-style impact feel.
			velocity_vec = -velocity_vec * impact_bounce
			speed = velocity_vec.length()
			angular_velocity += deg_to_rad(randf_range(-180.0, 180.0)) * clampf(speed / max(top_speed, 1.0), 0.2, 1.0)
			apply_damage(6)

func _simulate_arcade_driving(delta: float) -> void:
	var forward: Vector2 = Vector2.RIGHT.rotated(rotation)
	var lateral: Vector2 = forward.orthogonal()
	var forward_speed: float = velocity_vec.dot(forward)
	var lateral_speed: float = velocity_vec.dot(lateral)

	steer_input = Input.get_axis("move_left", "move_right")
	var speed_ratio: float = clampf(abs(forward_speed) / max(top_speed, 1.0), 0.0, 1.0)

	# Tight control at low speed, loose rear at high speed while steering.
	var lateral_grip: float = lerpf(9.5, 3.0, speed_ratio)
	if speed_ratio > 0.7 and abs(steer_input) > 0.2:
		lateral_grip *= (1.0 - (drift_factor * 0.55))
	var lateral_kill: float = clampf(lateral_grip * delta, 0.0, 1.0)
	velocity_vec -= lateral * lateral_speed * lateral_kill

	var accel_input: float = Input.get_action_strength("move_up")
	var brake_input: float = Input.get_action_strength("move_down")

	if accel_input > 0.01:
		velocity_vec += forward * (acceleration * accel_input * delta)
	elif brake_input > 0.01:
		if forward_speed > 20.0:
			velocity_vec -= forward * (brake_force * brake_input * delta)
		else:
			velocity_vec -= forward * (acceleration * reverse_accel_multiplier * brake_input * delta)
	else:
		velocity_vec *= pow(coast_drag, 60.0 * delta)

	forward_speed = velocity_vec.dot(forward)
	var turn_rate: float = lerpf(low_speed_turn_rate, high_speed_turn_rate, speed_ratio)
	var target_angular: float = steer_input * turn_rate * signf(forward_speed if abs(forward_speed) > 0.01 else 1.0) * speed_ratio
	var steering_lag: float = lerpf(11.0, 3.0, speed_ratio)
	angular_velocity = lerpf(angular_velocity, target_angular, clampf(steering_lag * delta, 0.0, 1.0))
	rotation += angular_velocity * delta

	_clamp_longitudinal_speed()
	speed = velocity_vec.length()

func _clamp_longitudinal_speed() -> void:
	var forward: Vector2 = Vector2.RIGHT.rotated(rotation)
	var lateral: Vector2 = forward.orthogonal()
	var forward_speed: float = clampf(velocity_vec.dot(forward), -reverse_speed, top_speed)
	var lateral_speed: float = velocity_vec.dot(lateral)
	velocity_vec = forward * forward_speed + lateral * lateral_speed

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
	var duration: float = randf_range(1.0, 2.0)
	var elapsed: float = 0.0
	GameState.set_hotwire_progress(true, 0.0)
	while elapsed < duration:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		GameState.set_hotwire_progress(true, elapsed / duration)
	GameState.set_hotwire_progress(false, 0.0)

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
	if health <= int(round(float(max_health) / 3.0)) and health > 0:
		visual.color = Color(0.35, 0.35, 0.35)
	if health == 0:
		disable_vehicle()

func disable_vehicle() -> void:
	is_disabled = true
	visual.color = Color(0.15, 0.15, 0.15)
	if driver:
		driver.exit_vehicle(global_position + Vector2(24, 0))
		driver = null

func apply_archetype(profile: Dictionary) -> void:
	vehicle_class = String(profile.get("id", "family"))
	top_speed = float(profile.get("top_speed", top_speed))
	reverse_speed = float(profile.get("reverse_speed", reverse_speed))
	acceleration = float(profile.get("acceleration", acceleration))
	brake_force = float(profile.get("brake_force", brake_force))
	low_speed_turn_rate = float(profile.get("low_turn", low_speed_turn_rate))
	high_speed_turn_rate = float(profile.get("high_turn", high_speed_turn_rate))
	max_health = int(profile.get("max_health", max_health))
	mass_factor = float(profile.get("mass_factor", mass_factor))
	coast_drag = float(profile.get("coast_drag", coast_drag))
	drift_factor = float(profile.get("drift_factor", drift_factor))
	health = max_health
	if visual and profile.has("scale_x"):
		var sx: float = float(profile.get("scale_x", 1.0))
		var sy: float = float(profile.get("scale_y", 1.0))
		visual.scale = Vector2(sx, sy)
