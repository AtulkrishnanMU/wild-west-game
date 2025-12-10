class_name CharacterUtils
extends RefCounted

# Common scene preloads
const DUST_SCENE := preload("res://scenes/objects/dust_splash.tscn")
const BLOOD_SCENE := preload("res://scenes/objects/blood_splash.tscn")

# Dust creation functions
static func create_dust_effect(character: Node2D, offset_y: float = 12.0, spread_x: float = 8.0) -> void:
	# Spawn dust splash at character landing position (near feet)
	if DUST_SCENE:
		var dust := DUST_SCENE.instantiate()
		var scene := character.get_tree().current_scene
		if dust and scene:
			var offset := Vector2(randf_range(-spread_x, spread_x), offset_y)
			dust.global_position = character.global_position + offset
			dust.set_direction(Vector2(randf_range(-0.3, 0.3), 0.8))  # Downward with slight spread
			scene.add_child(dust)
	else:
		push_error("DUST_SCENE not found!")

static func create_running_dust(character: Node2D, offset_y: float = 12.0, spread_x: float = 4.0) -> void:
	# Spawn smaller dust effect while running (at feet level)
	if DUST_SCENE:
		var dust := DUST_SCENE.instantiate()
		var scene := character.get_tree().current_scene
		if dust and scene:
			var offset := Vector2(randf_range(-spread_x, spread_x), offset_y)
			dust.global_position = character.global_position + offset
			dust.set_direction(Vector2(randf_range(-0.5, -0.1), 0.5))  # Backward and slightly down
			scene.add_child(dust)
	else:
		push_error("DUST_SCENE not found for running dust!")

# Blood creation functions
static func create_blood_effect(character: Node2D, spread: float = 4.0) -> void:
	# Spawn blood splash at character position
	if BLOOD_SCENE:
		var blood := BLOOD_SCENE.instantiate()
		var scene := character.get_tree().current_scene
		if blood and scene:
			var offset := Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
			blood.global_position = character.global_position + offset
			# Set direction based on character facing if available
			if character.has_method("get_facing_direction"):
				blood.set_direction(character.get_facing_direction())
			elif character.has_node("AnimatedSprite2D"):
				var sprite = character.get_node("AnimatedSprite2D") as AnimatedSprite2D
				var facing_dir := Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
				blood.set_direction(facing_dir)
			
			# Add blood to scene tree at correct position (after Wall, before background)
			var wall_node = scene.get_node_or_null("Wall")
			var background_node = scene.get_node_or_null("background")
			
			if wall_node and background_node:
				# Insert blood after Wall node but before background
				var blood_index = wall_node.get_index() + 1
				scene.add_child(blood)
				scene.move_child(blood, blood_index)
			elif wall_node:
				# Fallback: insert after Wall
				var blood_index = wall_node.get_index() + 1
				scene.add_child(blood)
				scene.move_child(blood, blood_index)
			else:
				# Fallback: just add to scene
				scene.add_child(blood)

# Dust tracking for landing detection
static func check_dust_landing(character: Node2D, was_on_floor: bool, velocity: Vector2, threshold: float = 50.0) -> bool:
	# Returns true if dust should be created on landing
	if character.is_on_floor() and not was_on_floor and abs(velocity.y) > threshold:
		return true
	return false

# Dust tracking for running detection  
static func check_running_dust(character: Node2D, velocity: Vector2, chance: float = 0.1, speed_threshold: float = 50.0) -> bool:
	# Returns true if dust should be created while running
	if character.is_on_floor() and abs(velocity.x) > speed_threshold and randf() < chance:
		return true
	return false

# Smooth movement with ease-in/ease-out acceleration
static func apply_smooth_movement(character: CharacterBody2D, target_speed: float, max_speed: float, delta: float, acceleration: float = 1200.0, deceleration: float = 1500.0, air_acceleration: float = 800.0) -> float:
	# Apply smooth acceleration/deceleration to horizontal velocity
	var acceleration_rate: float = acceleration
	if not character.is_on_floor():
		acceleration_rate = air_acceleration
	
	if target_speed != 0.0:
		# Accelerating towards target speed
		var speed_diff: float = target_speed - character.velocity.x
		var accel: float = sign(speed_diff) * min(abs(speed_diff), acceleration_rate * delta)
		return character.velocity.x + accel
	else:
		# Decelerating to stop
		var decel: float = sign(character.velocity.x) * min(abs(character.velocity.x), deceleration * delta)
		var new_velocity: float = character.velocity.x - decel
		# Stop completely if very close to zero to prevent tiny movements
		if abs(new_velocity) < 1.0:
			return 0.0
		return new_velocity

# Clean floating popup method (similar to cash popup)
static func spawn_floating_popup(character: Node2D, text: String, color: Color, offset: Vector2 = Vector2(0, -20), font_size: int = FontConfig.DEFAULT_POPUP_FONT_SIZE, height: float = 0.0) -> void:
	var scene := character.get_tree().current_scene
	if scene == null:
		return

	var popup_root := Node2D.new()
	# Use pixel-perfect positioning to prevent blurriness
	# Add height offset to prevent overlapping popups
	popup_root.position = (character.global_position + offset + Vector2(0, -height)).round()
	scene.add_child(popup_root)

	var label := Label.new()
	label.text = text
	label.modulate = color
# Apply popup font (no outlines)
	FontConfig.apply_popup_font(label)
	# Override font size if it's not the default
	if font_size != FontConfig.DEFAULT_POPUP_FONT_SIZE:
		label.add_theme_font_size_override("font_size", font_size)

	popup_root.add_child(label)

	var tween := scene.get_tree().create_tween()
	
	# Check if this is an HP popup (contains "HP" text)
	var is_hp_popup = "HP" in text
	
	if is_hp_popup:
		# Add flicker effect for HP popups
		var flicker_tween := scene.get_tree().create_tween()
		flicker_tween.set_loops(3)  # Flicker 3 times
		flicker_tween.tween_property(label, "modulate:a", 0.3, 0.1)  # Fade to 30% opacity
		flicker_tween.tween_property(label, "modulate:a", 1.0, 0.1)  # Back to full opacity
	
	# Popup: float up and fade over ~0.5 seconds
	tween.tween_property(popup_root, "position:y", popup_root.position.y - 20.0, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.finished.connect(popup_root.queue_free)

# Health system utilities
static func apply_damage_with_effects(character: Node2D, amount: int, blood_scene: PackedScene, blood_splat_sound: AudioStream, hit_player: AudioStreamPlayer2D = null, bullet_direction: Vector2 = Vector2.ZERO, hit_position: Vector2 = Vector2.ZERO) -> void:
	# Spawn blood splash at hit position or character center
	if blood_scene:
		var blood := blood_scene.instantiate()
		var scene := character.get_tree().current_scene
		if blood and scene:
			var spawn_position := hit_position if hit_position != Vector2.ZERO else character.global_position
			
			# For alive enemies, offset blood position backwards from bullet impact
			var is_dead: bool = "is_dead" in character and character.is_dead
			if not is_dead and bullet_direction != Vector2.ZERO:
				# Offset blood spawn position backwards along bullet direction
				var backward_offset := bullet_direction.normalized() * 12.0  # 12 pixels behind impact
				spawn_position += backward_offset
			
			var offset := Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
			blood.global_position = spawn_position + offset
			
			# Set dead enemy flag to reduce blood amount
			blood.set_dead_enemy(is_dead)
			
			# Set blood direction based on bullet direction or character state
			if bullet_direction != Vector2.ZERO:
				# Check if bullet direction is mostly vertical (gun angled up/down relative to body)
				var vertical_threshold := 0.94  # ~70-degree angle threshold
				print("Bullet direction: ", bullet_direction, ", Y component: ", bullet_direction.y, ", threshold: ", vertical_threshold)
				if abs(bullet_direction.y) > vertical_threshold:
					# Gun is mostly vertical - make blood splash upwards
					print("Making blood splash upwards (vertical shot)")
					blood.set_direction(Vector2(0.0, -1.0))
				else:
					# Normal horizontal bullet direction - use bullet direction for realistic blood spray
					print("Using bullet direction for blood spray")
					blood.set_direction(bullet_direction)
			else:
				# Fallback to character-based direction for non-bullet damage
				if "is_dead" in character and character.is_dead:
					# Dead characters: fountain effect (upward)
					blood.set_direction(Vector2(0.0, -1.0))  # Straight up with slight random spread
				else:
					# Alive characters: normal sideways blood based on facing direction
					var facing_dir := Vector2.LEFT
					if character.has_node("AnimatedSprite2D"):
						var sprite = character.get_node("AnimatedSprite2D") as AnimatedSprite2D
						facing_dir = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
					blood.set_direction(facing_dir)
			
			# Add blood to scene tree at correct position (after Wall, before background)
			var wall_node = scene.get_node_or_null("Wall")
			var background_node = scene.get_node_or_null("background")
			
			if wall_node and background_node:
				# Insert blood after Wall node but before background
				var blood_index = wall_node.get_index() + 1
				scene.add_child(blood)
				scene.move_child(blood, blood_index)
			elif wall_node:
				# Fallback: insert after Wall
				var blood_index = wall_node.get_index() + 1
				scene.add_child(blood)
				scene.move_child(blood, blood_index)
			else:
				# Fallback: just add to scene
				scene.add_child(blood)
	
	# Play blood splat sound
	if blood_splat_sound:
		AudioUtils.play_blood_splat_sound(blood_splat_sound, character.global_position)
	
	# Play hit sound if available
	if hit_player:
		AudioUtils.play_random_pitch(hit_player, 0.7, 1.6)
	
	# Centralized camera shake for successful damage only
	_trigger_camera_shake(character)

# Centralized camera shake system
static func _trigger_camera_shake(damaged_character: Node2D) -> void:
	# Find the player to trigger camera shake
	var scene := damaged_character.get_tree().current_scene
	if scene == null:
		return
	
	var player := scene.get_node_or_null("Player")
	if player == null:
		return
	
	# Only trigger camera shake if the damaged character is not the player
	# AND the character is not dead (skip dead bodies)
	if damaged_character != player and player.has_method("_start_camera_shake"):
		# Check if damaged character is dead - skip shake for dead bodies
		var is_dead = false
		if damaged_character.has_method("is_dead"):
			is_dead = damaged_character.is_dead()
		elif "is_dead" in damaged_character:
			is_dead = damaged_character.is_dead
		
		if is_dead:
			return
		player._start_camera_shake()

# Knockback system utilities
static func apply_knockback(character: CharacterBody2D, direction: float, strength: float, duration: float) -> void:
	# Apply knockback velocity
	if character.has_method("set_knockback"):
		character.set_knockback(direction * strength, duration)
	else:
		# Fallback: directly modify velocity if character doesn't have knockback system
		character.velocity.x = direction * strength

# Animation utilities
static func play_character_animation(animated_sprite: AnimatedSprite2D, anim_name: String) -> void:
	if animated_sprite and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)

static func set_character_facing(animated_sprite: AnimatedSprite2D, should_face_left: bool) -> void:
	if animated_sprite:
		animated_sprite.flip_h = should_face_left
