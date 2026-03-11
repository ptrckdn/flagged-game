extends Node2D

@export_enum("workshop", "compliance", "bribe") var mode := "workshop"
var last_workshop_day := -999

@onready var visual: ColorRect = $Visual

func _ready() -> void:
	if mode == "workshop":
		visual.color = Color(0.2, 0.8, 0.9)
	elif mode == "compliance":
		visual.color = Color(0.9, 0.9, 0.95)
	else:
		visual.color = Color(0.8, 0.6, 0.2)

func on_player_interact(_player) -> void:
	match mode:
		"workshop":
			if last_workshop_day == GameState.world_day:
				GameState.notify("Workshop already completed today")
				return
			GameState.notify("MODULE 7: Understanding Why Your Opinions Need Updating")
			await get_tree().create_timer(10.0).timeout
			GameState.add_meter(-15, "Workshop completion")
			last_workshop_day = GameState.world_day
		"compliance":
			GameState.add_meter(-15, "Voluntary compliance filed")
			if randi() % 3 == 0:
				_remove_random_npc()
		"bribe":
			if GameState.try_spend(2000):
				GameState.add_meter(-10, "Council clerk adjusted your file")
			else:
				GameState.notify("Insufficient funds for bribe")

func _remove_random_npc() -> void:
	var world = get_tree().current_scene
	if world and world.has_method("remove_random_npc"):
		world.remove_random_npc()
