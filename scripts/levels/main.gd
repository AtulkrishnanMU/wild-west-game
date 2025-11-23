extends "res://scripts/levels/level.gd"

var pressed: bool = false
var intro_done: bool = false
var intro_running: bool = false
var intro_camera_height: float = 220.0
var camera_follow_speed: float = 12.0
var press_blink_time: float = 0.0
var press_blink_speed: float = 4.0
var INTRO_GUN_SOUND: AudioStream = null

@onready var camera: Camera2D = $Camera2D
@onready var title_layer: CanvasLayer = $TitleLayer
@onready var press_label: Label = $TitleLayer/PressLabel
@onready var ui_layer: CanvasLayer = $UI
@onready var btn_continue: Button = $TitleLayer/Menu/ContinueButton
@onready var btn_new_game: Button = $TitleLayer/Menu/NewGameButton
@onready var btn_tutorial: Button = $TitleLayer/Menu/TutorialButton
@onready var btn_endless: Button = $TitleLayer/Menu/EndlessButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Initialize shared UI references for Level base class
	player = $Player
	health_bar = $"UI/HealthBar"
	heal_cooldown_bar = $"UI/HealCooldownBar"
	cash_label = $"UI/CashLabel"
	health_percent_label = $"UI/HealthPercentLabel"
	bullet_icons = $"UI/BulletIcons"

	player.health_changed.connect(_on_player_health_changed)
	player.cash_changed.connect(_on_player_cash_changed)
	if player.has_signal("bullets_changed"):
		player.bullets_changed.connect(_on_player_bullets_changed)
	player.controls_enabled = false
	var ui_font := load("res://fonts/PixelOperator8.ttf")
	if ui_font:
		health_bar.add_theme_font_override("font", ui_font)
		if heal_cooldown_bar:
			heal_cooldown_bar.add_theme_font_override("font", ui_font)
		cash_label.add_theme_font_override("font", ui_font)
		health_percent_label.add_theme_font_override("font", ui_font)
		if press_label:
			press_label.add_theme_font_override("font", ui_font)
		if btn_continue:
			btn_continue.add_theme_font_override("font", ui_font)
		if btn_new_game:
			btn_new_game.add_theme_font_override("font", ui_font)
		if btn_tutorial:
			btn_tutorial.add_theme_font_override("font", ui_font)
		if btn_endless:
			btn_endless.add_theme_font_override("font", ui_font)
	health_bar.show_percentage = false
	if heal_cooldown_bar:
		heal_cooldown_bar.show_percentage = false
		heal_cooldown_bar.min_value = 0.0
		heal_cooldown_bar.max_value = 1.0
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
	if btn_continue:
		btn_continue.pressed.connect(_on_continue_pressed)
	if btn_new_game:
		btn_new_game.pressed.connect(_on_new_game_pressed)
	if btn_tutorial:
		btn_tutorial.pressed.connect(_on_tutorial_pressed)
	if btn_endless:
		btn_endless.pressed.connect(_on_endless_pressed)
		
func _input(event: InputEvent) -> void:
	if intro_done or intro_running:
		return
	if event.is_action_pressed("ui_accept"):
		_start_intro_pan()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Simple camera follow after intro is complete
	if intro_done and camera and player:
		camera.global_position = camera.global_position.lerp(player.global_position, camera_follow_speed * delta)
	update_heal_cooldown_bar()


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
	var root := get_tree().get_root()
	if root == null:
		return
	var audio := AudioStreamPlayer.new()
	audio.stream = INTRO_GUN_SOUND
	root.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)


func _on_continue_pressed() -> void:
	_start_intro_pan()


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/cutscenes/prologue_cutscene.tscn")


func _on_tutorial_pressed() -> void:
	_start_intro_pan()


func _on_endless_pressed() -> void:
	_play_intro_gun_sound()
	get_tree().change_scene_to_file("res://scenes/levels/endless.tscn")
