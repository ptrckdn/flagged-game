extends Node2D

signal interacted(marker: Node)

@export var objective_text := ""

@onready var visual: ColorRect = $Visual

func _ready() -> void:
	visual.color = Color(1.0, 0.95, 0.2)

func on_player_interact(_player) -> void:
	emit_signal("interacted", self)
