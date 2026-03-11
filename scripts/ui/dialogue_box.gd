extends Control
class_name DialogueBox

signal closed

var active_npc
var active_dialogue: Dictionary

@onready var npc_name_label: Label = $Panel/Margin/VBox/NPCName
@onready var opening_label: Label = $Panel/Margin/VBox/Opening
@onready var responses_container: VBoxContainer = $Panel/Margin/VBox/Responses

func open_for_npc(npc) -> void:
	active_npc = npc
	active_dialogue = DialogueSystem.get_random_dialogue(npc.npc_type)
	npc_name_label.text = npc.npc_type
	opening_label.text = String(active_dialogue.get("opening", "..."))
	_build_response_buttons(active_dialogue.get("responses", []))
	visible = true
	get_tree().paused = true

func _build_response_buttons(responses: Array) -> void:
	for c in responses_container.get_children():
		c.queue_free()
	for response in responses:
		var btn := Button.new()
		var delta := int(response.get("meter_delta", 0))
		btn.text = "%s [%+d]" % [String(response.get("text", "...")), delta]
		if delta <= 0:
			btn.modulate = Color("2ecc40")
		elif delta <= 7:
			btn.modulate = Color("ffdc00")
		else:
			btn.modulate = Color("ff4136")
		btn.pressed.connect(_on_response_selected.bind(response))
		responses_container.add_child(btn)

func _on_response_selected(response: Dictionary) -> void:
	DialogueSystem.apply_response(response)
	close_dialogue()

func close_dialogue() -> void:
	get_tree().paused = false
	visible = false
	emit_signal("closed")

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close_dialogue()
