extends Node2D

@export var destination_scene := "res://scenes/interiors/shop.tscn"
@export var label := "Enter"

@onready var visual: ColorRect = $Visual

func _ready() -> void:
	visual.color = Color(0.95, 0.92, 0.2)

func on_player_interact(_player) -> void:
	SaveSystem.save_game({"from_world": true})
	get_tree().change_scene_to_file(destination_scene)
