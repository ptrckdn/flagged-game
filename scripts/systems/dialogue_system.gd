extends Node

var dialogue_db: Dictionary = {}

func _ready() -> void:
	load_dialogues()

func load_dialogues() -> void:
	var file := FileAccess.open("res://data/dialogues.json", FileAccess.READ)
	if not file:
		push_warning("dialogues.json not found")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		dialogue_db = parsed

func get_random_dialogue(npc_type: String) -> Dictionary:
	var pool: Array = dialogue_db.get(npc_type, [])
	if pool.is_empty():
		return {
			"opening": "...",
			"responses": [
				{"text": "Leave", "meter_delta": 0, "outcome": "none", "outcome_payload": ""}
			]
		}
	return pool[randi() % pool.size()]

func apply_response(response: Dictionary) -> void:
	var delta := int(response.get("meter_delta", 0))
	if delta > 0:
		GameState.add_meter(delta, "Conversation flagged")
	var outcome := String(response.get("outcome", "none"))
	var payload = response.get("outcome_payload", "")
	match outcome:
		"notify": GameState.notify(String(payload))
		"item": GameState.add_item({"id": String(payload), "tags": ["mission"]})
		"unlock_mission": MissionSystem.unlock_mission(String(payload))
		_:
			pass
