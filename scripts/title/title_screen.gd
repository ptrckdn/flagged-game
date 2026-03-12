extends Control

@onready var hint: Label = $Center/Hint
var _started: bool = false

func _ready() -> void:
	hint.text = "Press any key"
	focus_mode = Control.FOCUS_ALL
	grab_focus()
	_start_game_after_delay()

func _input(event: InputEvent) -> void:
	if _started:
		return
	var begin := false
	if event is InputEventKey and event.pressed and not event.echo:
		begin = true
	elif event is InputEventMouseButton and event.pressed:
		begin = true
	elif event is InputEventJoypadButton and event.pressed:
		begin = true
	if begin:
		_start_game()

func _start_game_after_delay() -> void:
	await get_tree().create_timer(0.6).timeout
	_start_game()

func _start_game() -> void:
	if _started:
		return
	_started = true
	get_tree().change_scene_to_file("res://scenes/world/world_root.tscn")
