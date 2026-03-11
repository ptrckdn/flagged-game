extends CharacterBody2D
class_name CivilianNPC

const C := preload("res://scripts/data/game_constants.gd")

@export var npc_type := "Office Worker"
@export var walk_speed := 80.0
@export var sprint_speed := 185.0

var world_root: Node
var home_pos := Vector2.ZERO
var target_pos := Vector2.ZERO
var pause_timer := 0.0
var scatter_timer := 0.0

@onready var visual: ColorRect = $Visual

func _ready() -> void:
	home_pos = global_position
	target_pos = global_position
	visual.color = Color.from_hsv(randf(), 0.7, 0.95)

func _physics_process(delta: float) -> void:
	if world_root and world_root.has_method("is_npc_active") and not world_root.is_npc_active(global_position):
		return

	if scatter_timer > 0.0:
		scatter_timer -= delta
		move_and_slide()
		return

	if pause_timer > 0.0:
		pause_timer -= delta
		velocity = Vector2.ZERO
		return

	if global_position.distance_to(target_pos) < 6.0:
		pause_timer = randf_range(2.0, 5.0)
		target_pos = _pick_patrol_target()
		velocity = Vector2.ZERO
		return

	var dir := (target_pos - global_position).normalized()
	velocity = dir * walk_speed
	var candidate := global_position + velocity * delta
	if world_root and world_root.has_method("is_pavement_world") and not world_root.is_pavement_world(candidate):
		target_pos = _pick_patrol_target()
		velocity = Vector2.ZERO
	move_and_slide()

func _pick_patrol_target() -> Vector2:
	if not world_root:
		return home_pos
	for _i in 10:
		var cell = world_root.random_pavement_cell_near(world_root.city_map.world_to_cell(home_pos), 10)
		if cell != Vector2i(-1, -1):
			return world_root.city_map.cell_to_world(cell)
	return home_pos

func trigger_scatter(from_pos: Vector2) -> void:
	var away := (global_position - from_pos).normalized()
	if away.length() < 0.1:
		away = Vector2.RIGHT.rotated(randf() * TAU)
	velocity = away * sprint_speed
	scatter_timer = 2.0
	GameState.notify("Pedestrians scatter")

func on_player_interact(_player: Node) -> void:
	if world_root and world_root.has_method("open_dialogue_for_npc"):
		world_root.open_dialogue_for_npc(self)
