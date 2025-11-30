class_name CharacterUtils
extends RefCounted

# Common scene preloads
const DUST_SCENE := preload("res://scenes/objects/dust_splash.tscn")
const BLOOD_SCENE := preload("res://scenes/objects/blood_splash.tscn")

# Dust creation functions
static func create_dust_effect(character: Node2D, offset_y: float = 12.0, spread_x: float = 8.0) -> void:
	# Spawn dust splash at character landing position (near feet)
	print("Creating dust effect for: ", character.name)
	if DUST_SCENE:
		var dust := DUST_SCENE.instantiate()
		var scene := character.get_tree().current_scene
		if dust and scene:
			var offset := Vector2(randf_range(-spread_x, spread_x), offset_y)
			dust.global_position = character.global_position + offset
			dust.set_direction(Vector2(randf_range(-0.3, 0.3), 0.8))  # Downward with slight spread
			scene.add_child(dust)
			print("Dust added successfully for: ", character.name)
	else:
		print("DUST_SCENE not found!")

static func create_running_dust(character: Node2D, offset_y: float = 12.0, spread_x: float = 4.0) -> void:
	# Spawn smaller dust effect while running (at feet level)
	print("Creating running dust for: ", character.name)
	if DUST_SCENE:
		var dust := DUST_SCENE.instantiate()
		var scene := character.get_tree().current_scene
		if dust and scene:
			var offset := Vector2(randf_range(-spread_x, spread_x), offset_y)
			dust.global_position = character.global_position + offset
			dust.set_direction(Vector2(randf_range(-0.5, -0.1), 0.5))  # Backward and slightly down
			scene.add_child(dust)
			print("Running dust added successfully for: ", character.name)
	else:
		print("DUST_SCENE not found for running dust!")

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
