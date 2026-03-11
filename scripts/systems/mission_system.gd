extends Node

signal mission_started(id: String)
signal mission_updated(id: String, objective_index: int, text: String)
signal mission_completed(id: String)
signal mission_failed(id: String)

var missions: Dictionary = {}
var mission_sequence: Array[String] = []
var completed: Dictionary = {}
var active_mission_id := ""
var active_objective_index := 0

func _ready() -> void:
	_load_missions()

func _load_missions() -> void:
	var file := FileAccess.open("res://data/missions.json", FileAccess.READ)
	if not file:
		push_warning("missions.json missing")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		missions = parsed
		mission_sequence = missions.keys()
		mission_sequence.sort()

func unlock_mission(id: String) -> void:
	if not GameState.mission_progress.has(id):
		GameState.mission_progress[id] = "unlocked"

func get_next_available_mission() -> String:
	for id in mission_sequence:
		if completed.get(id, false):
			continue
		var req := String(missions[id].get("unlock_after", ""))
		if req == "" or completed.get(req, false):
			return id
	return ""

func start_mission(id: String) -> bool:
	if not missions.has(id):
		return false
	active_mission_id = id
	active_objective_index = 0
	emit_signal("mission_started", id)
	_emit_objective()
	return true

func _emit_objective() -> void:
	if active_mission_id == "":
		return
	var objectives: Array = missions[active_mission_id].get("objectives", [])
	if active_objective_index >= objectives.size():
		complete_active_mission()
		return
	var obj: Dictionary = objectives[active_objective_index]
	emit_signal("mission_updated", active_mission_id, active_objective_index, String(obj.get("text", "")))

func advance_objective() -> void:
	active_objective_index += 1
	_emit_objective()

func complete_active_mission() -> void:
	if active_mission_id == "":
		return
	var mission: Dictionary = missions.get(active_mission_id, {})
	var rewards: Dictionary = mission.get("rewards", {})
	GameState.add_cash(int(rewards.get("cash", 0)))
	GameState.add_meter(int(rewards.get("meter", 0)), "Mission exposure")
	completed[active_mission_id] = true
	GameState.mission_progress[active_mission_id] = "complete"
	emit_signal("mission_completed", active_mission_id)
	active_mission_id = ""
	active_objective_index = 0

func fail_active_mission() -> void:
	if active_mission_id == "":
		return
	emit_signal("mission_failed", active_mission_id)
	active_mission_id = ""
	active_objective_index = 0
