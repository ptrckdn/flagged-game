extends Node2D

@export var return_scene_path := "res://scenes/world/world_root.tscn"
@export var return_position := Vector2(900, 1450)

func _ready() -> void:
	SaveSystem.save_game({"interior": name})

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		GameState.player_world_position = return_position
		get_tree().change_scene_to_file(return_scene_path)
