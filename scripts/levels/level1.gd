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

func _ready() -> void:
	# Find the player and gun enemy in the scene
	player = $Player
	_gun_enemy = $Gun_enemy
	
	# Assign UI references to parent class variables
	health_bar = $UI/HealthBar
	cash_label = $UI/CashLabel
	health_percent_label = $UI/HealthPercentLabel
	bullet_icons = $UI/BulletIcons
	reload_label = $UI/ReloadLabel
	ui_layer = $UI
	
	# Use common UI setup (now with player available)
	setup_ui()
	
	# Use common level setup   
	setup_level()
	
	# Start intro animation
	_start_intro_animation()
	
	print("Level1 initialized with UI connections and intro animation")

func _process(delta: float) -> void:
	# Only process level logic if intro animation is complete
	if not _intro_animation_active:
		# Use common level process for UI updates (camera follow, etc.)
		process_level(delta)
	
	# Update tutorial position to follow player
	if _tutorial_active and _tutorial_popup and player:
		_tutorial_popup.global_position = player.global_position + Vector2(0, -100)
	
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
	
	# Disable player controls during animation
	if player.has_method("set_controls_enabled"):
		player.set_controls_enabled(false)
	else:
		player.controls_enabled = false
	
	# Position player off-screen to the left
	player.global_position = _player_start_position
	
	# Make gun enemy face right initially
	_set_gun_enemy_facing_direction("right")
	
	# >>> DO NOT FOLLOW PLAYER DURING INTRO <<<
	camera_follow_enabled = false
	
	if camera:
		camera.make_current()
		# Position camera to show the intro action (center of level)
		camera.global_position = _player_center_position
	
	# Start the player run animation
	_animate_player_running()

func _animate_player_running() -> void:
	if not player:
		return
	
	# Manually play the RUN animation
	var animated_sprite = player.get_node_or_null("AnimatedSprite2D")
	if animated_sprite:
		animated_sprite.play("RUN")
		# Make sprite face right while running
		animated_sprite.flip_h = false
	
	# Create tween for smooth movement
	var tween := create_tween()
	tween.set_parallel(false)  # Sequential animations
	
	# Animate player running to center position
	tween.tween_property(player, "global_position", _player_center_position, _animation_duration)
	
	# Wait for movement to complete, then trigger enemy turn
	tween.tween_callback(_on_player_reached_center)

func _on_player_reached_center() -> void:
	if not _gun_enemy:
		return
	
	# Switch to IDLE animation when player stops
	var animated_sprite = player.get_node_or_null("AnimatedSprite2D")
	if animated_sprite:
		animated_sprite.play("IDLE")
	
	# Make gun enemy turn to face left
	_set_gun_enemy_facing_direction("left")
	
	# Wait a moment for the turn to register, then enable controls
	await get_tree().create_timer(0.5).timeout
	
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
	
	# Apply pixel font
	var font = load("res://fonts/PixelOperator8.ttf")
	if font:
		_tutorial_label.add_theme_font_override("font", font)
		_tutorial_label.add_theme_font_size_override("font_size", 8)
		# Ensure crisp pixel rendering
		_tutorial_label.add_theme_constant_override("outline_size", 1)
		_tutorial_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_tutorial_label.modulate = Color.WHITE
	
	_tutorial_popup.add_child(_tutorial_label)
	
	# Add to scene (not UI layer, so it follows player)
	add_child(_tutorial_popup)
	
	# Position above player and start fade in
	if player:
		_tutorial_popup.global_position = player.global_position + Vector2(0, -100)
	
	# Start with invisible and fade in
	_tutorial_popup.modulate.a = 0.0
	var fade_tween := create_tween()
	fade_tween.tween_property(_tutorial_popup, "modulate:a", 1.0, 0.5)
	
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

func _remove_tutorial_popup() -> void:
	if _tutorial_popup:
		_tutorial_popup.queue_free()
		_tutorial_popup = null
		_tutorial_label = null
		print("Tutorial popup removed")
