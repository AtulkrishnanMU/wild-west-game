extends Node2D

var pressed: bool = false

@onready var player = $Player
@onready var health_bar: ProgressBar = $UI/HealthBar
@onready var cash_label: Label = $UI/CashLabel
@onready var health_percent_label: Label = $UI/HealthPercentLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player.health_changed.connect(_on_player_health_changed)
	player.cash_changed.connect(_on_player_cash_changed)
	var ui_font := load("res://fonts/PixelOperator8.ttf")
	if ui_font:
		health_bar.add_theme_font_override("font", ui_font)
		cash_label.add_theme_font_override("font", ui_font)
		health_percent_label.add_theme_font_override("font", ui_font)
	health_bar.show_percentage = false
	_on_player_health_changed(player.health, player.MAX_HEALTH)
	
func _input(event: InputEvent) -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_player_health_changed(current: int, max_value: int) -> void:
	health_bar.max_value = max_value
	health_bar.value = current
	var ratio := 0.0
	if max_value > 0:
		ratio = float(current) / float(max_value)
	if ratio > 0.6:
		health_bar.modulate = Color(0.2, 0.9, 0.2)   # green
	elif ratio > 0.3:
		health_bar.modulate = Color(0.95, 0.8, 0.2)  # yellow
	else:
		health_bar.modulate = Color(0.95, 0.2, 0.2)  # red
	if health_percent_label:
		health_percent_label.text = str(int(round(ratio * 100.0))) + "%"


func _on_player_cash_changed(current: int) -> void:
	if cash_label:
		cash_label.text = "CASH: " + str(current)
