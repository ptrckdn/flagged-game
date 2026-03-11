extends Control

signal mission_chosen(id: String)

@onready var list: VBoxContainer = $Panel/VBox/List

func open_menu() -> void:
	visible = true
	get_tree().paused = true
	_refresh()

func close_menu() -> void:
	visible = false
	get_tree().paused = false

func _refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	var next_available := MissionSystem.get_next_available_mission()
	for id in MissionSystem.mission_sequence:
		var btn := Button.new()
		if MissionSystem.completed.get(id, false):
			btn.text = "✓ %s" % id
			btn.disabled = true
			btn.modulate = Color(0.6, 0.6, 0.6)
		elif id == next_available:
			btn.text = id
			btn.modulate = Color(1.0, 1.0, 0.4)
			btn.pressed.connect(_on_mission_pressed.bind(id))
		else:
			btn.text = "???"
			btn.disabled = true
			btn.modulate = Color(0.35, 0.35, 0.35)
		list.add_child(btn)

func _on_mission_pressed(id: String) -> void:
	emit_signal("mission_chosen", id)
	close_menu()

func _on_close_pressed() -> void:
	close_menu()
