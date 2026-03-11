extends Node

signal chase_requested(level: int)
signal stop_event_requested
signal helicopter_state_changed(active: bool)

var stop_event_timer := 0.0
var helicopter_timer := 0.0
var helicopter_active := false
var black_patrol_refresh := 0.0

func _ready() -> void:
	GameState.meter_changed.connect(_on_meter_changed)
	_on_meter_changed(GameState.civility_index, GameState.get_tier())

func _process(delta: float) -> void:
	var tier := GameState.get_tier()
	stop_event_timer -= delta
	helicopter_timer -= delta
	black_patrol_refresh -= delta

	if tier == "AMBER":
		if stop_event_timer <= 0.0:
			emit_signal("stop_event_requested")
			stop_event_timer = randf_range(180.0, 240.0)
	elif tier == "RED":
		if stop_event_timer <= 0.0:
			emit_signal("stop_event_requested")
			stop_event_timer = randf_range(60.0, 120.0)
		if helicopter_timer <= 0.0:
			helicopter_active = true
			helicopter_timer = 30.0
			emit_signal("helicopter_state_changed", helicopter_active)
		elif helicopter_active and helicopter_timer <= 0.1:
			helicopter_active = false
			helicopter_timer = randf_range(120.0, 180.0)
			emit_signal("helicopter_state_changed", helicopter_active)
	elif tier == "BLACK":
		if not helicopter_active:
			helicopter_active = true
			emit_signal("helicopter_state_changed", true)
		if black_patrol_refresh <= 0.0:
			black_patrol_refresh = 8.0
	else:
		if helicopter_active:
			helicopter_active = false
			emit_signal("helicopter_state_changed", false)

func _on_meter_changed(_value: int, tier: String) -> void:
	match tier:
		"GREEN": stop_event_timer = 99999.0
		"AMBER": stop_event_timer = randf_range(90.0, 150.0)
		"RED": stop_event_timer = randf_range(30.0, 60.0)
		"BLACK": stop_event_timer = 20.0

func trigger_offence(severity := 1) -> void:
	var tier := GameState.get_tier()
	var chase_level := severity
	if tier == "AMBER":
		chase_level = max(chase_level, 1)
	elif tier == "RED":
		chase_level = max(chase_level, 2)
	elif tier == "BLACK":
		chase_level = max(chase_level, 3)
	emit_signal("chase_requested", chase_level)

func apply_capture_consequences(player: Node) -> void:
	var tier := GameState.get_tier()
	GameState.confiscate_all_items()
	MissionSystem.fail_active_mission()
	if player and player.has_method("on_captured"):
		player.on_captured()
	match tier:
		"GREEN", "AMBER":
			GameState.add_cash(-int(GameState.cash * randf_range(0.1, 0.2)))
		"RED":
			GameState.add_cash(-int(GameState.cash * randf_range(0.3, 0.5)))
		"BLACK":
			GameState.add_cash(-GameState.cash)
			GameState.set_meter(50)
			GameState.home_storage.clear()
			GameState.notify("Flat raided. Home storage confiscated.")
