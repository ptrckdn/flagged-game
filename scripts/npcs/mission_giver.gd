extends CharacterBody2D

@onready var visual: ColorRect = $Visual
@onready var interact: Area2D = $InteractArea

func _ready() -> void:
	visual.color = Color("ffcc00")

func on_player_interact(_player) -> void:
	var world := get_tree().current_scene
	if world and world.has_method("open_mission_menu"):
		world.open_mission_menu()
