extends Control

@onready var panel: Panel = $Panel

func _ready() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		visible = not visible
		get_tree().paused = visible

func _on_resume_pressed() -> void:
	visible = false
	get_tree().paused = false

func _on_restart_mission_pressed() -> void:
	MissionSystem.fail_active_mission()
	visible = false
	get_tree().paused = false

func _on_quit_pressed() -> void:
	get_tree().quit()
