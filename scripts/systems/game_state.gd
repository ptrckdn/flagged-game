extends Node

signal meter_changed(value: int, tier: String)
signal cash_changed(value: int)
signal inventory_changed()
signal notification(text: String)
signal day_advanced(day: int)
signal hotwire_progress(active: bool, progress: float)

const MAX_METER := 100
const MIN_METER := 0
const CARRY_LIMIT := 5
const STORAGE_LIMIT := 10

var civility_index := 0
var cash := 50
var inventory: Array[Dictionary] = []
var home_storage: Array[Dictionary] = []
var safehouse_storage: Array[Dictionary] = []
var mission_progress := {}
var world_time_minutes := 8 * 60
var world_day := 1
var player_world_position := Vector2.ZERO
var _time_accumulator := 0.0

func _process(delta: float) -> void:
	# 60s realtime = 1h game time.
	_time_accumulator += delta
	if _time_accumulator >= 1.0:
		var minutes := int(floor(_time_accumulator))
		_time_accumulator -= float(minutes)
		world_time_minutes += minutes
	if world_time_minutes >= 24 * 60:
		world_time_minutes = 0
		world_day += 1
		emit_signal("day_advanced", world_day)

func get_tier() -> String:
	if civility_index <= 25:
		return "GREEN"
	if civility_index <= 50:
		return "AMBER"
	if civility_index <= 75:
		return "RED"
	return "BLACK"

func add_meter(amount: int, reason := "") -> void:
	set_meter(civility_index + amount, reason)

func set_meter(value: int, reason := "") -> void:
	var before_tier := get_tier()
	var before_value := civility_index
	civility_index = clampi(value, MIN_METER, MAX_METER)
	var after_tier := get_tier()
	emit_signal("meter_changed", civility_index, after_tier)
	if reason != "":
		notify("%s (%+d)" % [reason, civility_index - before_value])
	if before_tier != after_tier:
		notify(_tier_notification(after_tier))

func _tier_notification(tier: String) -> String:
	match tier:
		"AMBER": return "Your Community Standing has been noted."
		"RED": return "FORMAL NOTICE: You have been classified as a Flagged Individual."
		"BLACK": return "ALERT: You have been designated an Enemy of Civility. Full monitoring authorised."
		_: return "Civility index normalised."

func add_cash(amount: int) -> void:
	cash = max(0, cash + amount)
	emit_signal("cash_changed", cash)

func try_spend(amount: int) -> bool:
	if cash < amount:
		return false
	add_cash(-amount)
	return true

func add_item(item: Dictionary) -> bool:
	if inventory.size() >= CARRY_LIMIT:
		return false
	inventory.append(item)
	emit_signal("inventory_changed")
	return true

func remove_item_by_id(item_id: String) -> bool:
	for i in range(inventory.size()):
		if inventory[i].get("id", "") == item_id:
			inventory.remove_at(i)
			emit_signal("inventory_changed")
			return true
	return false

func has_tag(tag: String) -> bool:
	for item in inventory:
		var tags: Array = item.get("tags", [])
		if tag in tags:
			return true
	return false

func confiscate_all_items() -> void:
	inventory.clear()
	emit_signal("inventory_changed")

func notify(text: String) -> void:
	emit_signal("notification", text)

func set_hotwire_progress(active: bool, progress: float) -> void:
	hotwire_progress.emit(active, clampf(progress, 0.0, 1.0))

func as_save_data() -> Dictionary:
	return {
		"civility_index": civility_index,
		"cash": cash,
		"inventory": inventory,
		"home_storage": home_storage,
		"safehouse_storage": safehouse_storage,
		"mission_progress": mission_progress,
		"world_time_minutes": world_time_minutes,
		"world_day": world_day,
		"player_world_position": [player_world_position.x, player_world_position.y]
	}

func load_from_data(data: Dictionary) -> void:
	civility_index = int(data.get("civility_index", 0))
	cash = int(data.get("cash", 50))
	inventory = _dict_array_from_variant(data.get("inventory", []))
	home_storage = _dict_array_from_variant(data.get("home_storage", []))
	safehouse_storage = _dict_array_from_variant(data.get("safehouse_storage", []))
	mission_progress = data.get("mission_progress", {})
	world_time_minutes = int(data.get("world_time_minutes", 8 * 60))
	world_day = int(data.get("world_day", 1))
	var pos = data.get("player_world_position", [0, 0])
	if pos is Array and pos.size() >= 2:
		player_world_position = Vector2(float(pos[0]), float(pos[1]))
	emit_signal("meter_changed", civility_index, get_tier())
	emit_signal("cash_changed", cash)
	emit_signal("inventory_changed")

func _dict_array_from_variant(value: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if value is Array:
		for item in value:
			if item is Dictionary:
				out.append(item)
	return out
