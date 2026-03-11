extends "res://scripts/vehicles/vehicle.gd"

@export var target: Node2D
@export var pursuit := false
@export var lose_sight_seconds := 45.0

var los_timer := 0.0

func _ready() -> void:
	top_speed = 460.0
	acceleration = 340.0
	base_turn_speed = 2.1
	visual.color = Color("7aa8ff")

func _physics_process(delta: float) -> void:
	if pursuit and target:
		ai_drive(delta)
	else:
		_patrol_idle(delta)
	super._physics_process(delta)

func ai_drive(delta: float) -> void:
	var to_target := target.global_position - global_position
	var desired_angle := to_target.angle()
	var diff := wrapf(desired_angle - rotation, -PI, PI)
	steer_input = clamp(diff * 2.0, -1.0, 1.0)

	if to_target.length() > 40.0:
		speed = move_toward(speed, top_speed, acceleration * delta)
	else:
		speed = move_toward(speed, 80.0, brake_force * delta)

	if to_target.length() < 30.0 and WantedSystem:
		WantedSystem.apply_capture_consequences(target)
		pursuit = false

	if get_parent() and get_parent().has_method("has_line_of_sight_to_player"):
		if get_parent().has_line_of_sight_to_player(global_position):
			los_timer = 0.0
		else:
			los_timer += delta
			if los_timer >= lose_sight_seconds:
				pursuit = false
				GameState.notify("Police lost visual contact")

func _patrol_idle(delta: float) -> void:
	speed = move_toward(speed, 110.0, acceleration * 0.4 * delta)
	steer_input = sin(Time.get_ticks_msec() * 0.001 + float(get_instance_id() % 100)) * 0.3
