extends "res://scripts/levels/level.gd"

# Intro animation variables
var _intro_animation_active: bool = true
var _gun_enemy: Node = null
var _player_start_position: Vector2 = Vector2(-200, 410)  # Off-screen left
var _player_center_position: Vector2 = Vector2(480, 410)   # Center position
var _animation_duration: float = 2.0  # Time to run to center

func _ready() -> void:
	# Find the player and gun enemy in the scene
	player = $Player
	_gun_enemy = $Gun_enemy
	
	# Assign UI references to parent class variables
	health_bar = $UI/HealthBar
	heal_cooldown_bar = $UI/HealCooldownBar
	cash_label = $UI/CashLabel
	health_percent_label = $UI/HealthPercentLabel
	bullet_icons = $UI/BulletIcons
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
		# Use common level process for UI updates (camera follow, heal cooldown, etc.)
		process_level(delta)

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
	
	print("Intro animation completed, player controls enabled, camera following")
