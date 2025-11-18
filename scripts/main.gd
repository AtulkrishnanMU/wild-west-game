extends Node2D

var pressed: bool = false

@onready var player = $Player
@onready var health_bar: ProgressBar = $UI/HealthBar

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player.health_changed.connect(_on_player_health_changed)
	pass
	
func _input(event: InputEvent) -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_player_health_changed(current: int, max_value: int) -> void:
	health_bar.max_value = max_value
	health_bar.value = current
