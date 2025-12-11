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
	# Find the player in the scene
	player = $Player
	
	# Find gun enemy if it exists (optional)
	_gun_enemy = $Gun_enemy if has_node("Gun_enemy") else null
	
	# Connect alarm trigger if it exists
	if _alarm_trigger:
		_alarm_trigger.alarm_triggered.connect(_on_alarm_triggered)
	
	# Assign UI references to parent class variables
	health_bar = $UI/HealthBar
	cash_label = $UI/CashLabel
	health_percent_label = $UI/HealthPercentLabel
	bullet_icons = $UI/BulletIcons
	reload_label = $UI/ReloadLabel
	combo_text_label = $UI/ComboTextLabel
	combo_total_label = $UI/ComboTotalLabel
	combo_timer_bar = $UI/ComboTimerBar
	ui_layer = $UI
	
	# Use common UI setup (now with player available)
	setup_ui()
	
	# Use common level setup   
	setup_level()
	
	# Start intro animation using generic framework
	_start_intro_animation()
	
	print("Level1 initialized with UI connections and intro animation")

# Override UI update functions to ensure visibility works correctly
func _update_bullet_icons(current: int, max_value: int) -> void:
	# Call parent function first
	super._update_bullet_icons(current, max_value)
	
	# Ensure visibility is set correctly when player has gun
	if player and player.has_gun and bullet_icons:
		bullet_icons.visible = true
		bullet_icons.modulate.a = 1.0

func _update_reload_label(current: int, max_value: int) -> void:
	# Call parent function first
	super._update_reload_label(current, max_value)
	
	# Ensure visibility is set correctly when player has gun
	if player and player.has_gun and reload_label:
		reload_label.visible = true
		reload_label.modulate.a = 1.0

func _process(delta: float) -> void:
	# Only process level logic if intro animation is complete
	if not _intro_animation_active:
		# Use common level process for UI updates (camera follow, etc.)
		process_level(delta)

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
	_fade_in_essential_ui()

func _fade_in_essential_ui() -> void:
	# Create fade tween for UI elements
	var fade_tween := create_tween()
	
	# Fade in essential UI elements (health, cash, health percent)
	# The essential UI (health, cash, health percent) was already made visible by the base class
	# Conditional UI (bullets, reload, combo) will appear when their respective actions occur
	if ui_layer:
		if health_bar:
			# Health bar is already visible from base class, just fade in
			fade_tween.tween_property(health_bar, "modulate:a", 1.0, 0.5)
			# Also fade in child elements
			for child in health_bar.get_children():
				fade_tween.tween_property(child, "modulate:a", 1.0, 0.5)
		if cash_label:
			fade_tween.tween_property(cash_label, "modulate:a", 1.0, 0.5)
		if health_percent_label:
			fade_tween.tween_property(health_percent_label, "modulate:a", 1.0, 0.5)
		# Note: bullet_icons, reload_label, and combo elements remain hidden
		# They will be shown by their respective update functions when needed

func _on_alarm_triggered() -> void:
	if not alarm_active:
		alarm_active = true
		print("Alarm system activated!")
		
		# Start the alarm sound if the alarm node exists and has the start_alarm method
		if _alert_alarm and _alert_alarm.has_method("start_alarm"):
			_alert_alarm.start_alarm()
		else:
			print("Warning: Alert alarm node doesn't have start_alarm method")
