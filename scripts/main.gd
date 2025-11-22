extends Node2D

var pressed: bool = false
var intro_done: bool = false
var intro_running: bool = false
var intro_camera_height: float = 220.0
var camera_follow_speed: float = 12.0
var press_blink_time: float = 0.0
var press_blink_speed: float = 4.0
var INTRO_GUN_SOUND: AudioStream = null

@onready var player = $Player
@onready var camera: Camera2D = $Camera2D
@onready var title_layer: CanvasLayer = $TitleLayer
@onready var press_label: Label = $TitleLayer/PressLabel
@onready var ui_layer: CanvasLayer = $UI
@onready var health_bar: ProgressBar = $UI/HealthBar
@onready var cash_label: Label = $UI/CashLabel
@onready var health_percent_label: Label = $UI/HealthPercentLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player.health_changed.connect(_on_player_health_changed)
	player.cash_changed.connect(_on_player_cash_changed)
	player.controls_enabled = false
	var ui_font := load("res://fonts/PixelOperator8.ttf")
	if ui_font:
		health_bar.add_theme_font_override("font", ui_font)
		cash_label.add_theme_font_override("font", ui_font)
		health_percent_label.add_theme_font_override("font", ui_font)
		if press_label:
			press_label.add_theme_font_override("font", ui_font)
	health_bar.show_percentage = false
	var music := get_node_or_null("Music")
	if music and music.stream:
		music.stream.loop = true
		music.volume_db = -8.0
	INTRO_GUN_SOUND = load("res://sounds/intro-gun-shot.mp3")
	_on_player_health_changed(player.health, player.MAX_HEALTH)

	# Set up intro camera and title UI
	if camera and player:
		camera.global_position = player.global_position + Vector2(0, -intro_camera_height)
		camera.make_current()

	if title_layer:
		title_layer.visible = true
	if ui_layer:
		ui_layer.visible = false
		
func _input(event: InputEvent) -> void:
	if intro_done or intro_running:
		return
	if event.is_action_pressed("ui_accept"):
		_start_intro_pan()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Blink "PRESS ENTER" text while waiting for input
	if not intro_done and not intro_running and press_label:
		press_blink_time += delta * press_blink_speed
		var alpha := 0.5 + 0.5 * sin(press_blink_time)
		var color := press_label.modulate
		color.a = alpha
		press_label.modulate = color

	# Simple camera follow after intro is complete
	if intro_done and camera and player:
		camera.global_position = camera.global_position.lerp(player.global_position, camera_follow_speed * delta)


func _start_intro_pan() -> void:
	if intro_done or intro_running:
		return
	intro_running = true
	_play_intro_gun_sound()
	if title_layer:
		title_layer.visible = false
	if not camera or not player:
		_intro_finish()
		return
	var tween := create_tween()
	tween.tween_property(camera, "global_position", player.global_position, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_intro_finish()


func _intro_finish() -> void:
	intro_running = false
	intro_done = true
	if player:
		player.controls_enabled = true
	if ui_layer:
		ui_layer.visible = true


func _play_intro_gun_sound() -> void:
	if INTRO_GUN_SOUND == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var audio := AudioStreamPlayer.new()
	audio.stream = INTRO_GUN_SOUND
	scene.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)

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
