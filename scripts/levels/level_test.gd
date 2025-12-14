extends "res://scripts/levels/level.gd"

# Level-specific nodes
@onready var _axe_enemy2: CharacterBody2D = $Axe_enemy2
@onready var _alert_alarm: Node = $AlertAlarm
@onready var _alarm_trigger: Area2D = $AlarmTrigger

# Alarm system
var alarm_active: bool = false

# Intro animation configuration
var _gun_enemy: Node = null

func _ready() -> void:
	# Call parent _ready() which will auto-assign nodes and setup everything
	super._ready()
	
	# Find gun enemy if it exists (optional)
	_gun_enemy = $Gun_enemy if has_node("Gun_enemy") else null
	
	# Connect alarm trigger if it exists
	if _alarm_trigger:
		_alarm_trigger.alarm_triggered.connect(_on_alarm_triggered)
	
	# Start intro animation using generic framework
	_start_intro_animation()

func _start_intro_animation() -> void:
	# Find gun enemy if it exists (optional)
	_gun_enemy = $Gun_enemy if has_node("Gun_enemy") else null
	
	# Create intro configuration
	var intro_config = IntroConfig.new(
		Vector2(-200, 410),  # player_start_position (off-screen left)
		Vector2(480, 410),   # player_center_position (center position)
		2.0,                # animation_duration (not used in current implementation)
		8.0,                # wait_duration (8 seconds before enabling controls)
		Vector2.ZERO        # initial_camera_position (will use player_center_position)
	)
	
	# Configure specific settings for level1 intro
	intro_config.target_character = _gun_enemy
	intro_config.character_facing = "left"
	
	# Start the generic intro sequence
	start_intro_sequence(intro_config)

func _process(delta: float) -> void:
	# Only process level logic if intro animation is complete
	if not _intro_animation_active:
		# Use common level process for UI updates (camera follow, etc.)
		process_level(delta)

# Override the post-intro hook to show tutorial popup
func _on_intro_sequence_completed() -> void:
	# Create tutorial configuration for level1
	var tutorial_config = TutorialConfig.new("USE MOUSE BUTTONS\nAND SPACE BAR")
	tutorial_config.fade_in_duration = 0.5
	tutorial_config.fade_out_duration = 0.3
	tutorial_config.position_offset = Vector2(0, 50)
	tutorial_config.popup_size = Vector2(250, 250)
	tutorial_config.label_position = Vector2(-125, -80)
	tutorial_config.track_mouse_left = true
	tutorial_config.track_mouse_right = true
	tutorial_config.track_space = true
	tutorial_config.auto_hide_on_input = true
	
	# Show tutorial popup using generic framework
	show_tutorial_popup(tutorial_config)
	
	# Fade in essential UI elements along with tutorial
	fade_in_essential_ui()

func _on_alarm_triggered() -> void:
	if not alarm_active:
		alarm_active = true
		
		# Start the alarm sound if the alarm node exists and has the start_alarm method
		if _alert_alarm and _alert_alarm.has_method("start_alarm"):
			_alert_alarm.start_alarm()
