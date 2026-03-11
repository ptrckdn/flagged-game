extends Node

func _ready() -> void:
	_bind_action("move_up", [KEY_W, KEY_UP], [JOY_AXIS_LEFT_Y])
	_bind_action("move_down", [KEY_S, KEY_DOWN], [JOY_AXIS_LEFT_Y])
	_bind_action("move_left", [KEY_A, KEY_LEFT], [JOY_AXIS_LEFT_X])
	_bind_action("move_right", [KEY_D, KEY_RIGHT], [JOY_AXIS_LEFT_X])
	_bind_action("interact", [KEY_E, KEY_ENTER, KEY_SPACE], [])
	_bind_action("sprint", [KEY_SHIFT], [])
	_bind_action("special_action", [KEY_F], [])
	_bind_action("pause", [KEY_ESCAPE], [])
	_bind_action("inventory", [KEY_TAB], [])
	_bind_action("horn", [KEY_H], [])

func _bind_action(action: StringName, keys: Array, _axes: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	# Avoid duplicate events on repeated boots.
	for event in InputMap.action_get_events(action):
		InputMap.action_erase_event(action, event)
	for key in keys:
		var ev := InputEventKey.new()
		ev.keycode = key
		InputMap.action_add_event(action, ev)
