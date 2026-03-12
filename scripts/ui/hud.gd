extends CanvasLayer
class_name HUD

var notifications: Array[String] = []
var notif_timer: float = 0.0

@onready var civility_label: Label = $Top/CivilityLabel
@onready var civility_bar: ColorRect = $Top/CivilityContainer/CivilityBar
@onready var civility_value: Label = $Top/CivilityContainer/CivilityValue
@onready var money_label: Label = $Money
@onready var notification_label: Label = $Notification
@onready var mission_label: Label = $Mission
@onready var minimap: Control = $Minimap
@onready var hotwire_bar: ProgressBar = $HotwireBar

var full_bar_width: float = 320.0

func _ready() -> void:
	GameState.meter_changed.connect(_on_meter_changed)
	GameState.cash_changed.connect(_on_cash_changed)
	GameState.notification.connect(push_notification)
	GameState.hotwire_progress.connect(_on_hotwire_progress)
	MissionSystem.mission_updated.connect(_on_mission_updated)
	_on_meter_changed(GameState.civility_index, GameState.get_tier())
	_on_cash_changed(GameState.cash)
	notification_label.text = ""
	hotwire_bar.visible = false

func _process(delta: float) -> void:
	if notif_timer > 0.0:
		notif_timer -= delta
		if notif_timer <= 0.0:
			notification_label.text = ""
	if notification_label.text == "" and not notifications.is_empty():
		notification_label.text = notifications.pop_front()
		notif_timer = 3.0

func _on_meter_changed(value: int, tier: String) -> void:
	civility_label.text = "CIVILITY INDEX"
	var ratio: float = clampf(float(value) / 100.0, 0.0, 1.0)
	civility_bar.custom_minimum_size.x = full_bar_width * max(0.02, ratio)
	civility_value.text = str(value)
	match tier:
		"GREEN": civility_bar.color = Color("2ecc40")
		"AMBER": civility_bar.color = Color("ffdc00")
		"RED": civility_bar.color = Color("ff4136")
		"BLACK": civility_bar.color = Color("1a0000")

func _on_cash_changed(value: int) -> void:
	money_label.text = "£%d" % value

func push_notification(text: String) -> void:
	notifications.append(text)

func _on_mission_updated(_id: String, _index: int, text: String) -> void:
	mission_label.text = text

func _on_hotwire_progress(active: bool, progress: float) -> void:
	hotwire_bar.visible = active
	hotwire_bar.value = progress * 100.0
