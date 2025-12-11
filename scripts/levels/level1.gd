extends "res://scripts/levels/level.gd"

# Intro animation variables
var _intro_animation_active: bool = true
var _gun_enemy: Node = null
var _player_start_position: Vector2 = Vector2(-200, 410)  # Off-screen left
var _player_center_position: Vector2 = Vector2(480, 410)   # Center position
var _animation_duration: float = 2.0  # Time to run to center

# Tutorial popup variables
var _tutorial_popup: Control = null
var _tutorial_active: bool = false
var _tutorial_label: Label = null
var _tutorial_left_clicked: bool = false
var _tutorial_right_clicked: bool = false
var _tutorial_space_pressed: bool = false

# Level-specific nodes
@onready var _axe_enemy2: CharacterBody2D = $Axe_enemy2
@onready var _alert_alarm: Node = $AlertAlarm
@onready var _alarm_trigger: Area2D = $AlarmTrigger

# Alarm system
var alarm_active: bool = false

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
	
	# Make UI invisible during intro (after setup_ui is complete)
	if ui_layer:
		# Hide individual UI elements since CanvasLayer doesn't have modulate
		if health_bar:
			health_bar.modulate.a = 0.0
			health_bar.visible = false  # Also hide visibility
			# Hide any potential child elements
			for child in health_bar.get_children():
				child.modulate.a = 0.0
				child.visible = false
		if cash_label:
			cash_label.modulate.a = 0.0
			cash_label.visible = false
		if health_percent_label:
			health_percent_label.modulate.a = 0.0
			health_percent_label.visible = false
		if bullet_icons:
			bullet_icons.modulate.a = 0.0
			bullet_icons.visible = false
		if reload_label:
			reload_label.modulate.a = 0.0
			reload_label.visible = false
		if combo_text_label:
			combo_text_label.modulate.a = 0.0
			combo_text_label.visible = false
		if combo_total_label:
			combo_total_label.modulate.a = 0.0
			combo_total_label.visible = false
		if combo_timer_bar:
			combo_timer_bar.modulate.a = 0.0
			combo_timer_bar.visible = false
	
	# Start intro animation
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
	
	# Update tutorial position to follow player
	if _tutorial_active and _tutorial_popup and player:
		_tutorial_popup.global_position = player.global_position + Vector2(0, 50)
	
	# Check for tutorial input tracking
	if _tutorial_active:
		# Track mouse clicks
		if Input.is_action_just_pressed("attack"):
			_tutorial_left_clicked = true
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_tutorial_right_clicked = true
		# Track spacebar
		if Input.is_action_just_pressed("ui_accept") or Input.is_physical_key_pressed(KEY_SPACE):
			_tutorial_space_pressed = true
		
		# Check if all inputs have been used
		if _tutorial_left_clicked and _tutorial_right_clicked and _tutorial_space_pressed:
			_hide_tutorial_popup()

func _start_intro_animation() -> void:
	if not player or not _gun_enemy:
		print("ERROR: Player or gun enemy not found for intro animation")
		_intro_animation_active = false
		return
	
	# Position player directly at center position (no running animation)
	player.global_position = _player_center_position
	
	# Set player to IDLE animation
	var animated_sprite = player.get_node_or_null("AnimatedSprite2D")
	if animated_sprite:
		animated_sprite.play("IDLE")
		animated_sprite.flip_h = false
	
	# Make gun enemy face left initially (since player is already in position)
	_set_gun_enemy_facing_direction("left")
	
	# >>> DO NOT FOLLOW PLAYER DURING INTRO <<<
	camera_follow_enabled = false
	
	if camera:
		camera.make_current()
		# Position camera to show the player
		camera.global_position = _player_center_position
	
	# Wait 8 seconds before enabling controls
	await get_tree().create_timer(8.0).timeout
	
	# Enable player controls and end intro animation
	_end_intro_animation()


func _set_gun_enemy_facing_direction(direction: String) -> void:
	if not _gun_enemy:
		return
	
	# For gun enemies, we need to flip the sprite and adjust gun position
	var animated_sprite = _gun_enemy.get_node_or_null("AnimatedSprite2D")
	var gun_sprite = _gun_enemy.get_node_or_null("Gun")
	
	if direction == "right":
		# Face right - no flip
		if animated_sprite:
			animated_sprite.flip_h = false
		if gun_sprite:
			# Adjust gun position for right-facing
			gun_sprite.position.x = abs(gun_sprite.position.x)
	elif direction == "left":
		# Face left - flip horizontally
		if animated_sprite:
			animated_sprite.flip_h = true
		if gun_sprite:
			# Adjust gun position for left-facing
			gun_sprite.position.x = -abs(gun_sprite.position.x)

func _end_intro_animation() -> void:
	# Enable player controls
	if player:
		if player.has_method("set_controls_enabled"):
			player.set_controls_enabled(true)
		else:
			player.controls_enabled = true
	
	# Enable camera follow and make camera current
	camera_follow_enabled = true
	if camera:
		camera.make_current()
		camera.global_position = player.global_position
	
	# Mark intro animation as complete
	_intro_animation_active = false
	
	# Show tutorial popup
	_show_tutorial_popup()
	
	print("Intro animation completed, player controls enabled, camera following")

func _show_tutorial_popup() -> void:
	# Reset input tracking
	_tutorial_left_clicked = false
	_tutorial_right_clicked = false
	_tutorial_space_pressed = false
	
	# Create tutorial popup
	_tutorial_popup = Control.new()
	_tutorial_popup.name = "TutorialPopup"
	
	# Create tutorial label (no background box)
	_tutorial_label = Label.new()
	_tutorial_label.text = "USE MOUSE BUTTONS\nAND SPACE BAR"
	_tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tutorial_label.position = Vector2(-125, -80)
	_tutorial_label.size = Vector2(250, 250)
	
	# Apply default font to tutorial label
	FontConfig.apply_ui_font(_tutorial_label)
	# Ensure crisp pixel rendering
	_tutorial_label.add_theme_constant_override("outline_size", 1)
	_tutorial_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_tutorial_label.modulate = Color.WHITE
	
	_tutorial_popup.add_child(_tutorial_label)
	
	# Add to scene (not UI layer, so it follows player)
	add_child(_tutorial_popup)
	
	# Position below player and start fade in
	if player:
		_tutorial_popup.global_position = player.global_position + Vector2(0, 50)
	
	# Start with invisible and fade in
	_tutorial_popup.modulate.a = 0.0
	var fade_tween := create_tween()
	fade_tween.tween_property(_tutorial_popup, "modulate:a", 1.0, 0.5)
	
	# Fade in UI at the same time as tutorial (only essential elements initially)
	if ui_layer:
		if health_bar:
			health_bar.visible = true  # Restore visibility
			fade_tween.tween_property(health_bar, "modulate:a", 1.0, 0.5)
			# Also fade in child elements
			for child in health_bar.get_children():
				child.visible = true
				fade_tween.tween_property(child, "modulate:a", 1.0, 0.5)
		if cash_label:
			cash_label.visible = true
			fade_tween.tween_property(cash_label, "modulate:a", 1.0, 0.5)
		if health_percent_label:
			health_percent_label.visible = true
			fade_tween.tween_property(health_percent_label, "modulate:a", 1.0, 0.5)
		# Don't show bullet icons, reload label, and combo-related items initially
		# These will appear when the player gets a gun or starts killing enemies
	
	_tutorial_active = true
	print("Tutorial popup displayed")

func _hide_tutorial_popup() -> void:
	if _tutorial_popup:
		# Fade out before removing
		var fade_tween := create_tween()
		fade_tween.tween_property(_tutorial_popup, "modulate:a", 0.0, 0.3)
		fade_tween.tween_callback(_remove_tutorial_popup)
	_tutorial_active = false
	print("Tutorial popup hiding")

func _on_alarm_triggered() -> void:
	if not alarm_active:
		alarm_active = true
		print("Alarm system activated!")
		
		# Start the alarm sound if the alarm node exists and has the start_alarm method
		if _alert_alarm and _alert_alarm.has_method("start_alarm"):
			_alert_alarm.start_alarm()
		else:
			print("Warning: Alert alarm node doesn't have start_alarm method")

func _remove_tutorial_popup() -> void:
	if _tutorial_popup:
		_tutorial_popup.queue_free()
		_tutorial_popup = null
		_tutorial_label = null
		print("Tutorial popup removed")
