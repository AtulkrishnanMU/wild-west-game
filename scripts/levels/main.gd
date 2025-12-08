extends "res://scripts/levels/level.gd"

# Font configuration
const FontConfig := preload("res://scripts/utils/font_config.gd")

var pressed: bool = false
var intro_done: bool = false
var intro_running: bool = false
var intro_camera_height: float = 220.0
var press_blink_time: float = 0.0
var press_blink_speed: float = 4.0
var INTRO_GUN_SOUND: AudioStream = null

@onready var title_layer: CanvasLayer = $TitleLayer
@onready var press_label: Label = $TitleLayer/PressLabel
@onready var btn_continue: Button = $TitleLayer/Menu/ContinueButton
@onready var btn_new_game: Button = $TitleLayer/Menu/NewGameButton
@onready var btn_tutorial: Button = $TitleLayer/Menu/TutorialButton
@onready var btn_endless: Button = $TitleLayer/Menu/EndlessButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Initialize shared UI references for Level base class
	player = get_node_or_null("Player")
	health_bar = $"UI/HealthBar"
	cash_label = $"UI/CashLabel"
	health_percent_label = $"UI/HealthPercentLabel"
	bullet_icons = $"UI/BulletIcons"
	reload_label = $"UI/ReloadLabel"
	ui_layer = $"UI"

	# Use common UI setup only if player exists
	if player:
		setup_ui()
	
	# Use common level setup only if player exists
	if player:
		setup_level()
	
	# Apply default font to main menu UI elements
	FontConfig.apply_ui_font(press_label)
	FontConfig.apply_ui_font(btn_continue)
	FontConfig.apply_ui_font(btn_new_game)
	FontConfig.apply_ui_font(btn_tutorial)
	FontConfig.apply_ui_font(btn_endless)
	
	if player:
		player.controls_enabled = false
	INTRO_GUN_SOUND = load("res://sounds/intro-gun-shot.mp3")

	# Set up intro camera and title UI
	if camera and player:
		camera.global_position = player.global_position + Vector2(0, -intro_camera_height)

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
	# Use common level process only after intro is complete
	if intro_done:
		camera_follow_enabled = true
		process_level(delta)
	else:
		pass

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
