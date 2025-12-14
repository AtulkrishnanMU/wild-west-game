class_name CharacterUtils
extends RefCounted

# Common scene preloads
const DUST_SCENE := preload("res://scenes/objects/dust_splash.tscn")
const BLOOD_SCENE := preload("res://scenes/objects/blood_splash.tscn")

# Performance optimization: cached player reference
static var _cached_player_ref: WeakRef = weakref(null)

# Performance optimization: cached scene node references
static var _cached_wall_node: WeakRef = weakref(null)
static var _cached_background_node: WeakRef = weakref(null)
static var _cache_initialized: bool = false

# Initialize scene node cache for better performance
static func _initialize_scene_cache(scene: Node) -> void:
	if _cache_initialized:
		return
	
	_cached_wall_node = weakref(scene.get_node_or_null("Wall"))
	_cached_background_node = weakref(scene.get_node_or_null("background"))
	_cache_initialized = true

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
			
			# Initialize scene cache and use cached references for better performance
			_initialize_scene_cache(scene)
			var wall_node = _cached_wall_node.get_ref()
			var background_node = _cached_background_node.get_ref()
			
			if wall_node and background_node:
				# Insert blood after Wall node but before background
				var blood_index: int = wall_node.get_index() + 1
				scene.add_child(blood)
				scene.move_child(blood, blood_index)
			elif wall_node:
				# Fallback: insert after Wall
				var blood_index: int = wall_node.get_index() + 1
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

# Shared gun aiming logic for both player and gun enemies
static func calculate_gun_aim_direction(gun_sprite: Sprite2D, target_position: Vector2, animated_sprite: AnimatedSprite2D, gun_base_position: Vector2, left_offset: Vector2 = Vector2.ZERO) -> float:
	var to_target: Vector2 = target_position - gun_sprite.global_position
	if to_target.length() <= 0.0:
		return 0.0
	
	var angle: float = to_target.angle()
	var target_angle: float = angle
	var facing_right: bool = to_target.x >= 0.0
	
	if facing_right:
		target_angle = clamp(angle, -PI / 2.0, PI / 2.0)
		gun_sprite.scale.x = 1.0
		animated_sprite.flip_h = false
		gun_sprite.position = gun_base_position
	else:
		gun_sprite.scale.x = -1.0
		animated_sprite.flip_h = true
		gun_sprite.position = gun_base_position + left_offset
		
		# Better angle calculation for left-facing
		if angle >= 0:
			target_angle = -(PI - angle)
		else:
			target_angle = -(-PI - angle)
		
		target_angle = clamp(target_angle, -PI / 2.0, PI / 2.0)
	
	return target_angle

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
			# Use existing position to avoid creating new Vector2
			var spawn_position := hit_position
			if spawn_position == Vector2.ZERO:
				spawn_position = character.global_position
			
			# For alive enemies, offset blood position backwards from bullet impact
			var is_dead: bool = "is_dead" in character and character.is_dead
			if not is_dead and bullet_direction != Vector2.ZERO:
				# Offset blood spawn position backwards along bullet direction
				var backward_offset := bullet_direction.normalized() * 12.0  # 12 pixels behind impact
				spawn_position += backward_offset
			
			# Reuse offset calculation
			var offset_x := randf_range(-4.0, 4.0)
			var offset_y := randf_range(-4.0, 4.0)
			blood.global_position = spawn_position + Vector2(offset_x, offset_y)
			
			# Set dead enemy flag to reduce blood amount
			blood.set_dead_enemy(is_dead)
			
			# Set blood direction based on bullet direction or character state
			if bullet_direction != Vector2.ZERO:
				# Check if bullet direction is mostly vertical (gun angled up/down relative to body)
				const VERTICAL_THRESHOLD := 0.94  # ~70-degree angle threshold
				if abs(bullet_direction.y) > VERTICAL_THRESHOLD:
					# Gun is mostly vertical - make blood splash upwards
					blood.set_direction(Vector2.UP)
				else:
					# Normal horizontal bullet direction - use bullet direction for realistic blood spray
					blood.set_direction(bullet_direction)
			else:
				# Fallback to character-based direction for non-bullet damage
				if "is_dead" in character and character.is_dead:
					# Dead characters: fountain effect (upward)
					blood.set_direction(Vector2.UP)
				else:
					# Alive characters: normal sideways blood based on facing direction
					var facing_dir := Vector2.LEFT
					if character.has_node("AnimatedSprite2D"):
						var sprite = character.get_node("AnimatedSprite2D") as AnimatedSprite2D
						facing_dir = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
					blood.set_direction(facing_dir)
			
			# Initialize scene cache and use cached references for better performance
			_initialize_scene_cache(scene)
			var wall_node: Node = _cached_wall_node.get_ref()
			var background_node: Node = _cached_background_node.get_ref()
			
			if wall_node and background_node:
				# Insert blood after Wall node but before background
				var blood_index: int = wall_node.get_index() + 1
				scene.add_child(blood)
				scene.move_child(blood, blood_index)
			elif wall_node:
				# Fallback: insert after Wall
				var blood_index: int = wall_node.get_index() + 1
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
	# Use cached player reference to avoid expensive lookups
	var player = _cached_player_ref.get_ref()
	if not player:
		player = damaged_character.get_tree().current_scene.get_node_or_null("Player")
		_cached_player_ref = weakref(player)
	
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
