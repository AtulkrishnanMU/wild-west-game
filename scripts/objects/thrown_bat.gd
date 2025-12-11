class_name ThrownBat
extends Area2D

const CharacterUtils = preload("res://scripts/utils/character_utils.gd")
const AudioUtils = preload("res://scripts/utils/audio_utils.gd")
const SPIN_SOUND_PATH := "res://sounds/spin.mp3"
const METAL_BOUNCE_SOUND_PATH := "res://sounds/metal.mp3"
const SPARK_SOUND_PATH := "res://sounds/spark.mp3"

const BAT_SPEED = 600.0
const BAT_RETURN_SPEED = 800.0
const BAT_TRAVEL_DISTANCE = 300.0
const SPIN_SPEED = 20.0  # Rotations per second

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var direction: Vector2 = Vector2.RIGHT
var start_position: Vector2
var thrower: Node2D
var rotation_angle: float = 0.0
var damage: int = 25
var spin_sound_player: AudioStreamPlayer2D = null
var bounce_count: int = 0
var max_bounces: int = 3  # After 3 bounces, bat drops
var can_bounce: bool = true
var bounce_cooldown: float = 0.2
var _prev_position: Vector2 = Vector2.ZERO

# New state variables
var can_return: bool = true  # Only return if no bounces occurred
var is_dropping: bool = false
var is_pickable: bool = false
var is_returning: bool = false  # Track if bat is in auto-return mode
var vertical_velocity: float = 0.0
var drop_gravity: float = 200.0
var return_timeout: float = 3.0  # 3 seconds timeout for clean return

# Fallback auto-return variables
var fallback_timeout: float = 8.0  # 8 seconds total timeout for fallback
var stuck_detection_time: float = 2.0  # 2 seconds without movement = stuck
var last_position: Vector2 = Vector2.ZERO
var stuck_timer: float = 0.0

# Speed variation variables
var current_speed: float = BAT_SPEED  # Current movement speed
var min_flight_speed: float = BAT_SPEED * 0.3  # 30% of base speed at max distance
var speed_transition_distance: float = BAT_TRAVEL_DISTANCE * 0.7  # Start slowing at 70% distance

# Metal spark particles - NO LONGER NEEDED
# var spark_scene: PackedScene = null

# Rotation speed variables for realistic spinning
var current_spin_speed: float = 0.0  # Current rotation speed multiplier
var target_spin_speed: float = 1.0   # Target rotation speed multiplier
var spin_acceleration_time: float = 0.0  # Time spent accelerating spin
var total_flight_time: float = 0.0    # Total time bat has been in flight
var time_since_bounce: float = 0.0    # Time since last bounce

func _ready() -> void:
	start_position = global_position
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Set up spin sound
	_setup_spin_sound()
	_play_spin_sound()

func _physics_process(delta: float) -> void:
	total_flight_time += delta
	time_since_bounce += delta
	
	_update_spin_speed(delta)
	_update_flight_speed()  # Update speed based on distance
	
	rotation_angle += SPIN_SPEED * current_spin_speed * 2 * PI * delta
	sprite.rotation = rotation_angle
	
	if spin_sound_player and not spin_sound_player.playing and not is_dropping and not is_pickable:
		spin_sound_player.play()
	if spin_sound_player and not is_dropping and not is_pickable:
		_update_sound_volume()
	
	_prev_position = global_position
	
	# FALLBACK AUTO-RETURN CHECKS (highest priority after existing return state)
	_check_fallback_conditions()
	
	# AUTO-RETURN state - highest priority
	if is_returning:
		_handle_auto_return(delta)
		return
	
	# STATE 1: DROPPING - After 3 bounces
	if is_dropping:
		_handle_dropping(delta)
		return
	
	# STATE 2: PICKABLE - Wait for player pickup
	if is_pickable:
		_handle_pickable()
		return
	
	# STATE 3: AUTO-RETURN TRIGGER - Only if no bounces occurred
	if bounce_count == 0 and total_flight_time >= return_timeout:
		is_returning = true
		_handle_auto_return(delta)
		return
	
	# STATE 4: NORMAL FLIGHT - Movement with bouncing
	# Check max distance before moving
	if global_position.distance_to(start_position) >= BAT_TRAVEL_DISTANCE:
		if bounce_count == 0:
			is_returning = true  # start returning immediately
		else:
			_enter_drop_state()
		return
	
	_move_and_bounce(delta)

func _on_body_entered(body: Node) -> void:
	if body == thrower:
		return  # Don't hit the thrower
		
	# Check if enemy is inactive - if on screen, damage and activate it
	if body.is_in_group("enemies") and ("is_active" in body) and not body.is_active:
		# Check if the inactive enemy is visible on screen
		var notifier = body.get_node_or_null("VisibilityNotifier2D")
		if notifier and notifier.is_on_screen():
			# Enemy is on screen but inactive - damage it and activate it
			if body.has_method("take_damage"):
				body.take_damage(damage)
				# Activate the enemy after taking damage
				body.is_active = true
				body.has_been_visible_with_player = true
			# Apply knockback
			var knockback_dir = sign(body.global_position.x - global_position.x)
			CharacterUtils.apply_knockback(body, knockback_dir, 300.0, 0.2)
			# Create impact effect
			_create_impact_effect(body.global_position)
			return
		else:
			# Enemy is inactive and not on screen - don't damage
			return
		
	if body.has_method("take_damage"):
		body.take_damage(damage)
		# Apply knockback
		var knockback_dir = sign(body.global_position.x - global_position.x)
		CharacterUtils.apply_knockback(body, knockback_dir, 300.0, 0.2)
		
		# Create impact effect
		_create_impact_effect(body.global_position)

func _on_area_entered(area: Area2D) -> void:
	# Handle hitting other areas (like enemy hitboxes)
	var owner = area.get_parent()
	if owner and owner != thrower:
		# Check if enemy is inactive - if on screen, damage and activate it
		if owner.is_in_group("enemies") and ("is_active" in owner) and not owner.is_active:
			# Check if the inactive enemy is visible on screen
			var notifier = owner.get_node_or_null("VisibilityNotifier2D")
			if notifier and notifier.is_on_screen():
				# Enemy is on screen but inactive - damage it and activate it
				if owner.has_method("take_damage"):
					owner.take_damage(damage)
					# Activate the enemy after taking damage
					owner.is_active = true
					owner.has_been_visible_with_player = true
				# Apply knockback
				var knockback_dir = sign(owner.global_position.x - global_position.x)
				CharacterUtils.apply_knockback(owner, knockback_dir, 300.0, 0.2)
				# Create impact effect
				_create_impact_effect(owner.global_position)
				return
			else:
				# Enemy is inactive and not on screen - don't damage
				return
		
		if owner.has_method("take_damage"):
			owner.take_damage(damage)
			var knockback_dir = sign(owner.global_position.x - global_position.x)
			CharacterUtils.apply_knockback(owner, knockback_dir, 300.0, 0.2)
			_create_impact_effect(owner.global_position)

func _create_impact_effect(pos: Vector2) -> void:
	# Create blood splash effect if available
	var blood_scene = preload("res://scenes/objects/blood_splash.tscn")
	if blood_scene:
		var blood = blood_scene.instantiate()
		var scene = get_tree().current_scene
		if scene:
			blood.global_position = pos
			var blood_direction = (pos - global_position).normalized()
			blood.set_direction(blood_direction)
			
			# Add blood to scene at correct position
			var wall_node = scene.get_node_or_null("Wall")
			var background_node = scene.get_node_or_null("background")
			
			if wall_node and background_node:
				var blood_index = wall_node.get_index() + 1
				scene.add_child(blood)
				scene.move_child(blood, blood_index)
			elif wall_node:
				var blood_index = wall_node.get_index() + 1
				scene.add_child(blood)
				scene.move_child(blood, blood_index)
			else:
				scene.add_child(blood)

func _setup_spin_sound() -> void:
	var spin_sound = load(SPIN_SOUND_PATH)
	if spin_sound:
		spin_sound_player = AudioStreamPlayer2D.new()
		spin_sound_player.stream = spin_sound
		spin_sound_player.pitch_scale = 1.2  # Slightly higher pitch for spinning effect
		add_child(spin_sound_player)

func _play_spin_sound() -> void:
	if spin_sound_player:
		spin_sound_player.play()

func _stop_spin_sound() -> void:
	if spin_sound_player:
		spin_sound_player.stop()

func _create_spark_node() -> Node2D:
	var spark_root := Node2D.new()
	
	var spark_count = 8
	for i in range(spark_count):
		var spark := Sprite2D.new()
		spark.texture = _create_spark_texture()
		
		var angle = randf_range(0, 2 * PI)
		var distance = randf_range(5, 15)
		spark.position = Vector2(cos(angle), sin(angle)) * distance
		
		var velocity_angle = angle + randf_range(-PI/4, PI/4)
		var velocity = randf_range(100, 200)
		
		spark.scale = Vector2(randf_range(0.2, 0.4), randf_range(0.2, 0.4))
		spark.rotation = randf_range(0, 2 * PI)
		
		spark_root.add_child(spark)
		
		var tween := spark.create_tween()
		tween.set_parallel(true)
		
		var duration = 0.8
		var end_pos = spark.position + Vector2(cos(velocity_angle), sin(velocity_angle)) * velocity * duration
		end_pos.y += 80
		
		tween.tween_property(spark, "position", end_pos, duration)
		tween.tween_property(spark, "modulate:a", 0.0, duration)
		tween.tween_property(spark, "scale", Vector2.ZERO, duration)
	
	var cleanup := spark_root.create_tween()
	cleanup.tween_callback(spark_root.queue_free).set_delay(1.0)
	
	return spark_root

func _create_spark_texture() -> ImageTexture:
	# Create a larger 16x16 spark texture for maximum visibility
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)  # Use RGBA for transparency
	image.fill(Color.TRANSPARENT)  # Transparent background
	
	# Create a very bright spark pattern
	for x in range(16):
		for y in range(16):
			var dist = Vector2(x - 8, y - 8).length()
			if dist <= 6:  # Within larger radius
				if dist <= 2:
					image.set_pixel(x, y, Color.WHITE)  # Bright white center
				elif dist <= 4:
					image.set_pixel(x, y, Color.YELLOW)  # Yellow middle
				else:
					image.set_pixel(x, y, Color.ORANGE)  # Orange edge
	
	var texture := ImageTexture.new()
	texture.set_image(image)
	return texture

func _play_spark_sound_segment(spark_sound: AudioStream, position: Vector2, duration: float) -> void:
	var audio := AudioStreamPlayer2D.new()
	audio.stream = spark_sound
	audio.position = position
	
	# Set random pitch
	audio.pitch_scale = randf_range(0.7, 1.3)
	
	# Calculate random start time within the audio file
	var audio_length = spark_sound.get_length() if spark_sound.has_method("get_length") else 5.0  # Fallback to 5s
	var max_start_time = max(0.0, audio_length - duration)
	var random_start = randf_range(0.0, max_start_time)
	
	# Add to scene FIRST, then play
	get_tree().current_scene.add_child(audio)
	
	# Set playback to start at random position
	audio.play(random_start)
	
	# Create timer to stop audio after duration and cleanup
	var timer := Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(func(): 
		if audio and is_instance_valid(audio):
			audio.stop()
			audio.queue_free()
		if timer and is_instance_valid(timer):
			timer.queue_free()
	)
	get_tree().current_scene.add_child(timer)
	timer.start()

func _create_metal_sparks(pos: Vector2, normal: Vector2) -> void:
	print("Creating metal sparks at: ", pos, " with normal: ", normal)
	
	# Play spark sound with random segment
	var spark_sound = load(SPARK_SOUND_PATH)
	if spark_sound:
		_play_spark_sound_segment(spark_sound, pos, 0.8)  # 0.8s duration for bat sparks
	
	var sparks = _create_spark_node()
	get_tree().current_scene.add_child(sparks)
	sparks.global_position = pos
	sparks.rotation = normal.angle()
	
	print("Sparks created and positioned!")

func _update_sound_volume() -> void:
	if not spin_sound_player or not thrower or not is_instance_valid(thrower):
		return
	
	# Calculate distance from thrower
	var distance = global_position.distance_to(thrower.global_position)
	
	# Validate distance
	if is_nan(distance) or is_inf(distance) or distance < 0.0:
		return
	
	# Volume settings
	var max_distance = 500.0  # Distance at which sound is barely audible
	var min_volume = 0.1    # Minimum volume (10%)
	var max_volume = 1.0    # Maximum volume (100%)
	
	# Calculate volume based on distance (inverse relationship)
	if distance <= 50.0:  # Close to player
		spin_sound_player.volume_db = 0.0  # Full volume
	else:
		# Linear falloff from max_volume to min_volume
		var volume_ratio = 1.0 - (distance - 50.0) / (max_distance - 50.0)
		volume_ratio = clamp(volume_ratio, min_volume, max_volume)
		
		# Ensure volume_ratio is positive and valid before log calculation
		if volume_ratio <= 0.0 or is_nan(volume_ratio) or is_inf(volume_ratio):
			volume_ratio = min_volume  # Use minimum volume instead of zero
		
		# Convert to decibels (logarithmic scale)
		var volume_db = 20.0 * log(volume_ratio) / log(10.0)
		
		# Final validation before setting volume
		if not is_nan(volume_db) and not is_inf(volume_db):
			spin_sound_player.volume_db = volume_db

func _update_spin_speed(delta: float) -> void:
	# 1. INITIAL THROW - Accelerate into spin (first 0.2 seconds)
	if total_flight_time < 0.2:
		spin_acceleration_time += delta
		# Quick ramp-up from 0 to peak speed
		var acceleration_progress = spin_acceleration_time / 0.2
		current_spin_speed = acceleration_progress * 1.2  # Peak at 120% for dramatic effect
		target_spin_speed = 1.0
	
	# 2. MID-FLIGHT - Maintain fast spin with slight decay
	elif not is_dropping and not is_pickable:
		# Maintain high spin with very slow decay due to air resistance
		var air_resistance_factor = 0.98  # Very slight decay
		current_spin_speed = current_spin_speed * air_resistance_factor
		current_spin_speed = max(current_spin_speed, 0.8)  # Don't go below 80% in mid-flight
	
	# 3. DROPPING - Spin decays faster
	elif is_dropping:
		var drop_decay_factor = 0.9
		current_spin_speed = current_spin_speed * drop_decay_factor
		current_spin_speed = max(current_spin_speed, 0.3)  # Minimum 30% while dropping

func _apply_bounce_spin_loss() -> void:
	# Bounce impact reduces spin speed by 20-30%
	var spin_loss_factor = randf_range(0.7, 0.8)  # Keep 70-80% of current spin
	current_spin_speed = current_spin_speed * spin_loss_factor
	current_spin_speed = max(current_spin_speed, 0.2)  # Never go below 20% spin

func _update_flight_speed() -> void:
	var distance_traveled = global_position.distance_to(start_position)
	
	if is_returning:
		# Accelerate while returning to player
		var return_progress = 1.0 - (global_position.distance_to(thrower.global_position) / BAT_TRAVEL_DISTANCE)
		current_speed = lerp(min_flight_speed, BAT_RETURN_SPEED, return_progress)
	else:
		# Normal flight - fast at first, slow down near max distance
		if distance_traveled <= speed_transition_distance:
			# Fast speed for first 70% of distance
			current_speed = BAT_SPEED
		else:
			# Gradual slowdown from 70% to 100% distance
			var slowdown_progress = (distance_traveled - speed_transition_distance) / (BAT_TRAVEL_DISTANCE - speed_transition_distance)
			current_speed = lerp(BAT_SPEED, min_flight_speed, slowdown_progress)

# Shared movement + bounce detection
func _move_and_bounce(delta: float):
	var move_vec = direction.normalized() * current_speed * delta
	var intended_pos = global_position + move_vec
	
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, intended_pos)
	query.exclude = [self]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 0xFFFFFFFF
	
	var ray_result := space.intersect_ray(query)
	
	if ray_result and ray_result.collider and ray_result.collider is TileMap:
		if can_bounce:
			print("BOUNCE DETECTED! Creating sparks...")
			var normal = ray_result.normal
			if normal == Vector2.ZERO:
				normal = Vector2.UP
			
			var incoming = move_vec.normalized()
			var reflected = incoming.bounce(normal).normalized()
			direction = reflected
			
			global_position = ray_result.position + normal * 2.0
			
			# Create metal sparks at collision point
			_create_metal_sparks(ray_result.position, normal)
			
			bounce_count += 1
			time_since_bounce = 0.0
			
			# First bounce disables return capability
			if bounce_count == 1:
				can_return = false
			
			# After 3 bounces, enter drop state
			if bounce_count >= 3:
				_enter_drop_state()
				return
			
			_apply_bounce_spin_loss()
			
			# Play metal bounce sound with random pitch
			var metal_sound = load(METAL_BOUNCE_SOUND_PATH)
			if metal_sound:
				AudioUtils.play_positioned_sound(metal_sound, global_position, 0.8, 1.2)
			
			can_bounce = false
			await get_tree().create_timer(bounce_cooldown).timeout
			can_bounce = true
		return
	
	# No bounce → normal movement
	global_position = intended_pos

# STATE HANDLERS

func _enter_drop_state():
	is_dropping = true
	vertical_velocity = 0.0
	_stop_spin_sound()  # Stop spinning audio when dropping
	print("Bat entering drop state after 3 bounces")

func _handle_dropping(delta: float):
	# Apply gravity
	vertical_velocity += drop_gravity * delta
	global_position.y += vertical_velocity * delta

	# Enhanced ground detection with multiple raycasts
	var space := get_world_2d().direct_space_state
	var ground_found := false
	var closest_ground_y := INF
	var float_height = 15.0
	
	# Check multiple points for better ground detection
	var check_distances := [20.0, 35.0, 50.0, 75.0, 100.0]  # Multiple distances for redundancy
	for distance in check_distances:
		var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, distance))
		query.exclude = [self]
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.collision_mask = 0xFFFFFFFF
		
		var ground_result := space.intersect_ray(query)
		if ground_result and ground_result.collider and ground_result.collider is TileMap:
			ground_found = true
			var target_y = ground_result.position.y - float_height
			if target_y < closest_ground_y:
				closest_ground_y = target_y

	# HORIZONTAL WALL DETECTION - Check for walls on left and right
	var wall_found := false
	var closest_wall_x_left := -INF
	var closest_wall_x_right := INF
	var wall_float_distance := 20.0  # Distance to maintain from walls
	
	# Check left side
	var left_check_distances := [20.0, 35.0, 50.0, 75.0, 100.0]
	for distance in left_check_distances:
		var left_query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(-distance, 0))
		left_query.exclude = [self]
		left_query.collide_with_areas = false
		left_query.collide_with_bodies = true
		left_query.collision_mask = 0xFFFFFFFF
		
		var left_result := space.intersect_ray(left_query)
		if left_result and left_result.collider and left_result.collider is TileMap:
			wall_found = true
			var target_x = left_result.position.x + wall_float_distance
			if target_x > closest_wall_x_left:
				closest_wall_x_left = target_x
	
	# Check right side
	var right_check_distances := [20.0, 35.0, 50.0, 75.0, 100.0]
	for distance in right_check_distances:
		var right_query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(distance, 0))
		right_query.exclude = [self]
		right_query.collide_with_areas = false
		right_query.collide_with_bodies = true
		right_query.collision_mask = 0xFFFFFFFF
		
		var right_result := space.intersect_ray(right_query)
		if right_result and right_result.collider and right_result.collider is TileMap:
			wall_found = true
			var target_x = right_result.position.x - wall_float_distance
			if target_x < closest_wall_x_right:
				closest_wall_x_right = target_x

	# Apply horizontal positioning if walls detected
	if wall_found:
		# If too close to left wall, push right
		if closest_wall_x_left != -INF and global_position.x <= closest_wall_x_left:
			global_position.x = closest_wall_x_left
		
		# If too close to right wall, push left
		if closest_wall_x_right != INF and global_position.x >= closest_wall_x_right:
			global_position.x = closest_wall_x_right

	# If ground detected, stop dropping
	if ground_found and closest_ground_y != INF:
		# Only stop if bat is at or below the target position
		if global_position.y >= closest_ground_y:
			global_position.y = closest_ground_y
			vertical_velocity = 0.0
			is_dropping = false
			is_pickable = true
			print("Bat is now pickable - ground detected")
	
	# Additional safety check: if bat falls too far, force it to stop
	var max_fall_distance := 500.0  # Maximum pixels below starting position
	if global_position.y - start_position.y > max_fall_distance:
		print("Bat fell too far, forcing pickable state")
		vertical_velocity = 0.0
		is_dropping = false
		is_pickable = true

func _handle_pickable():
	# EASE-IN-OUT ROTATION while attracting
	if thrower and is_instance_valid(thrower):
		var to_player: Vector2 = thrower.global_position - global_position
		var dist := to_player.length()
		var attraction_radius := 120.0
		
		if dist <= attraction_radius:
			# Calculate rotation based on distance (ease-in-out effect)
			var distance_ratio: float = 1.0 - (dist / attraction_radius)
			# Ease-in-out curve: slow start, fast middle, slow end
			var ease_factor: float = distance_ratio * distance_ratio * (3.0 - 2.0 * distance_ratio)
			
			# Target rotation speed based on attraction strength
			var target_rotation_speed: float = ease_factor * 3.0  # Max 3.0 rotations/sec
			current_spin_speed = lerp(current_spin_speed, target_rotation_speed, 0.1)
			
			# Attraction speed increases as player gets closer
			var speed: float = lerp(4.0, 8.0, 1.0 - (dist / attraction_radius))
			global_position = global_position.lerp(thrower.global_position, speed * 0.016)  # 60fps normalized
		else:
			# Normal rotation decay when not in attraction radius
			current_spin_speed = lerp(current_spin_speed, 0.0, 0.05)
	else:
		# Fallback rotation decay if no thrower
		current_spin_speed = lerp(current_spin_speed, 0.0, 0.05)
	
	# Check for player pickup
	if thrower and is_instance_valid(thrower):
		var distance_to_player = global_position.distance_to(thrower.global_position)
		if distance_to_player < 40.0:
			_pickup_bat()

func _handle_auto_return(delta: float):
	if not thrower or not is_instance_valid(thrower):
		return

	var to_player = thrower.global_position - global_position
	var distance = to_player.length()
	if distance <= 0.0:
		_pickup_bat()
		return

	# Clamp movement to remaining distance
	var move_distance = min(current_speed * delta, distance)
	global_position += to_player.normalized() * move_distance

	# Check for pickup immediately after moving
	if global_position.distance_to(thrower.global_position) <= 40.0:
		_pickup_bat()

func _pickup_bat():
	print("Bat picked up by player")
	is_returning = false  # Reset return state
	if thrower and is_instance_valid(thrower):
		if thrower.has_method("_on_bat_returned"):
			thrower._on_bat_returned()
	queue_free()

func _check_fallback_conditions():
	# Skip if already in special states
	if is_returning or is_dropping or is_pickable:
		return
	
	# CONDITION 1: Total timeout exceeded
	if total_flight_time >= fallback_timeout:
		print("FALLBACK: Bat timeout exceeded, forcing return")
		_force_fallback_return()
		return
	
	# CONDITION 2: Stuck detection (no movement)
	if last_position != Vector2.ZERO:
		var movement_distance = global_position.distance_to(last_position)
		if movement_distance < 1.0:  # Barely moved
			stuck_timer += get_physics_process_delta_time()
			if stuck_timer >= stuck_detection_time:
				print("FALLBACK: Bat appears stuck, forcing return")
				_force_fallback_return()
				return
		else:
			stuck_timer = 0.0  # Reset stuck timer if moving
	
	# Update last position for next frame
	last_position = global_position

func _force_fallback_return():
	# Enable collision ignoring for safe return
	collision_layer = 0
	collision_mask = 0
	
	# Set return state
	is_returning = true
	can_return = true  # Allow return regardless of bounces
	
	# Stop spinning audio and play return sound
	_stop_spin_sound()
	
	# Optional: Play return sound effect
	var return_sound = load("res://sounds/spin.mp3")  # Reuse spin sound for return
	if return_sound:
		AudioUtils.play_positioned_sound(return_sound, global_position, 1.2, 1.5)
	
	print("FALLBACK ACTIVATED: Bat returning to player (ignoring collisions)")

func _return_to_player():
	print("Bat returning to player (no bounces)")
	if thrower and is_instance_valid(thrower):
		if thrower.has_method("_on_bat_returned"):
			thrower._on_bat_returned()
	queue_free()
