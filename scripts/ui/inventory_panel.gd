extends Control

@onready var items_label: Label = $Panel/VBox/Items

func _ready() -> void:
	visible = false
	GameState.inventory_changed.connect(_refresh)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		visible = not visible
		_refresh()

func _refresh() -> void:
	var lines: Array[String] = []
	for item in GameState.inventory:
		lines.append("- %s" % String(item.get("id", "item")))
	if lines.is_empty():
		items_label.text = "(empty)"
	else:
		items_label.text = "\n".join(lines)
