extends Node

const MarkerScene := preload("res://scenes/world/mission_marker.tscn")

var world_root: Node
var active_marker: Node
var objective_positions := {
	"newsagent": Vector2i(36, 44),
	"package": Vector2i(36, 44),
	"pub": Vector2i(28, 46),
	"bridge_street_car": Vector2i(42, 44),
	"foundry_lockup": Vector2i(72, 76),
	"leaflets": Vector2i(24, 50),
	"drop_1": Vector2i(20, 40),
	"drop_2": Vector2i(76, 44),
	"drop_3": Vector2i(60, 22),
	"drop_4": Vector2i(66, 80),
	"drop_5": Vector2i(30, 28),
	"dave_flat": Vector2i(74, 52),
	"pickup_dave": Vector2i(74, 52),
	"safehouse": Vector2i(16, 20),
	"depot": Vector2i(72, 82),
	"fence_gap": Vector2i(69, 84),
	"power_cell": Vector2i(74, 84),
	"library": Vector2i(19, 34),
	"install_cell": Vector2i(19, 34),
	"library_escape": Vector2i(12, 36),
	"high_street_start": Vector2i(24, 44),
	"shopkeeper_1": Vector2i(26, 44),
	"shopkeeper_2": Vector2i(40, 44),
	"shopkeeper_3": Vector2i(54, 44),
	"upload_phone": Vector2i(58, 44),
	"council_offices": Vector2i(64, 40),
	"enter_front": Vector2i(64, 40),
	"basement": Vector2i(64, 43),
	"search_files": Vector2i(64, 45),
	"archive_photo": Vector2i(64, 46),
	"council_exit": Vector2i(63, 39),
	"start_broadcast": Vector2i(19, 34),
	"broadcast_timer": Vector2i(19, 34),
	"library_collapse": Vector2i(14, 36)
}

func _ready() -> void:
	MissionSystem.mission_started.connect(_on_mission_started)
	MissionSystem.mission_updated.connect(_on_mission_updated)
	MissionSystem.mission_completed.connect(_on_mission_completed)
	MissionSystem.mission_failed.connect(_on_mission_failed)

func _on_mission_started(id: String) -> void:
	GameState.notify("Briefing: %s" % MissionSystem.missions[id].get("briefing", ""))

func _on_mission_updated(id: String, objective_index: int, _text: String) -> void:
	_clear_marker()
	var objectives: Array = MissionSystem.missions[id].get("objectives", [])
	if objective_index >= objectives.size():
		return
	var obj: Dictionary = objectives[objective_index]
	var t := String(obj.get("type", ""))
	if t == "survive_time":
		var secs := int(obj.get("params", {}).get("seconds", 10))
		await get_tree().create_timer(secs).timeout
		MissionSystem.advance_objective()
		return
	var target_id := String(obj.get("target_id", ""))
	if not objective_positions.has(target_id):
		MissionSystem.advance_objective()
		return
	active_marker = MarkerScene.instantiate()
	active_marker.objective_text = String(obj.get("text", "Objective"))
	active_marker.global_position = world_root.city_map.cell_to_world(objective_positions[target_id])
	active_marker.interacted.connect(_on_marker_interacted)
	world_root.dynamic_layer.add_child(active_marker)
	_apply_complications(id, objective_index)

func _apply_complications(id: String, idx: int) -> void:
	if id == "m2_wheels" and idx == 1:
		GameState.add_meter(3, "Vehicle theft detected")
		if GameState.civility_index > 25:
			WantedSystem.trigger_offence(1)
	if id == "m3_leaflet_run":
		if idx == 1:
			GameState.add_meter(5, "Leaflet surveillance spike")
		elif idx == 2:
			WantedSystem.trigger_offence(1)
		elif idx == 4:
			WantedSystem.trigger_offence(2)
	if id == "m5_the_signal" and idx == 2:
		if randi() % 2 == 0:
			GameState.add_meter(15, "Depot alarm triggered")
			WantedSystem.trigger_offence(2)
	if id == "m6_market_research" and idx == 4:
		WantedSystem.trigger_offence(2)
	if id == "m7_archive" and idx == 1:
		GameState.add_item({"id": "fake_id", "tags": ["utility", "mission"]})
	if id == "m8_broadcast_day" and idx == 2:
		WantedSystem.trigger_offence(3)

func _on_marker_interacted(_marker: Node) -> void:
	MissionSystem.advance_objective()

func _on_mission_completed(_id: String) -> void:
	_clear_marker()
	GameState.notify("Mission complete")

func _on_mission_failed(_id: String) -> void:
	_clear_marker()
	GameState.notify("Mission failed")

func _clear_marker() -> void:
	if active_marker and is_instance_valid(active_marker):
		active_marker.queue_free()
	active_marker = null
