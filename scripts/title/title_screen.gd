extends Control

@onready var hint: Label = $Center/Hint

func _ready() -> void:
	hint.text = "Press any key"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		get_tree().change_scene_to_file("res://scenes/world/world_root.tscn")
