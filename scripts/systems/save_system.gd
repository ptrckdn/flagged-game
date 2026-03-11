extends Node

const SAVE_PATH := "user://savegame.json"

func save_game(extra: Dictionary = {}) -> bool:
	var payload := GameState.as_save_data()
	payload["mission_completed"] = MissionSystem.completed
	payload["extra"] = extra
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	GameState.notify("Game saved")
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		GameState.load_from_data(parsed)
		MissionSystem.completed = parsed.get("mission_completed", {})
		GameState.notify("Save loaded")
		return true
	return false
