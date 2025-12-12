class_name ThrownBat
extends Area2D

const CharacterUtils = preload("res://scripts/utils/character_utils.gd")
const AudioUtils = preload("res://scripts/utils/audio_utils.gd")
const MetalSparkUtils = preload("res://scripts/utils/metal_spark_utils.gd")
const SPIN_SOUND_PATH := "res://sounds/spin.mp3"
const METAL_BOUNCE_SOUND_PATH := "res://sounds/metal.mp3"

# Performance optimization: preload audio
const SPIN_SOUND := preload("res://sounds/spin.mp3")
const METAL_BOUNCE_SOUND := preload("res://sounds/metal.mp3")

const BAT_SPEED = 600.0
const BAT_RETURN_SPEED = 800.0
const BAT_TRAVEL_DISTANCE = 300.0
const SPIN_SPEED = 20.0  # Rotations per second

@onready var sprite: Sprite2D = $Sprite2D

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

# Performance optimization: raycast caching
var _ground_check_timer: float = 0.0
var _wall_check_timer: float = 0.0
const RAYCAST_CHECK_INTERVAL: float = 0.05  # Check every 50ms instead of every frame


# New state variables
var can_return: bool = true  # Only return if no bounces occurred
var is_returning: bool = false  # Track if bat is in auto-return mode
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
	
	# Add to projectiles group for chain detection
	add_to_group("projectiles")
	
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
	
	if spin_sound_player and not spin_sound_player.playing and not is_returning:
		spin_sound_player.play()
	if spin_sound_player and not is_returning:
		_update_sound_volume()
	
	_prev_position = global_position
	
	# FALLBACK AUTO-RETURN CHECKS (highest priority after existing return state)
	_check_fallback_conditions()
	
	# AUTO-RETURN state - highest priority
	if is_returning:
		_handle_auto_return(delta)
		return
	
	# STATE 1: AUTO-RETURN TRIGGER - Always return after timeout
	if total_flight_time >= return_timeout:
		is_returning = true
		_handle_auto_return(delta)
		return
	
	# Check max distance before moving
	var current_distance = global_position.distance_to(start_position)
	if current_distance >= BAT_TRAVEL_DISTANCE:
		# Max distance reached - always return
		is_returning = true
		_handle_auto_return(delta)
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


func _setup_spin_sound():
	spin_sound_player = AudioStreamPlayer2D.new()
	spin_sound_player.stream = SPIN_SOUND  # Use preloaded sound
	spin_sound_player.pitch_scale = 1.2  # Slightly higher pitch for spinning effect
	add_child(spin_sound_player)

func _play_spin_sound() -> void:
	if spin_sound_player:
		spin_sound_player.play()

func _stop_spin_sound() -> void:
	if spin_sound_player:
		spin_sound_player.stop()


func _play_metal_bounce_sound() -> void:
	AudioUtils.play_positioned_sound(METAL_BOUNCE_SOUND, global_position, 0.8, 1.2)

func _create_metal_sparks(pos: Vector2, normal: Vector2) -> void:
	MetalSparkUtils.create_metal_sparks(pos, normal, "bat")

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
	elif not is_returning:
		# Maintain high spin with very slow decay due to air resistance
		var air_resistance_factor = 0.98  # Very slight decay
		current_spin_speed = current_spin_speed * air_resistance_factor
		current_spin_speed = max(current_spin_speed, 0.8)  # Don't go below 80% in mid-flight

func _apply_bounce_spin_loss() -> void:
	# Bounce impact reduces spin speed by 20-30%
	var spin_loss_factor = randf_range(0.7, 0.8)  # Keep 70-80% of current spin
	current_spin_speed = current_spin_speed * spin_loss_factor
	current_spin_speed = max(current_spin_speed, 0.2)  # Never go below 20% spin

func _update_flight_speed() -> void:
	var distance_traveled = global_position.distance_to(start_position)
	
	if is_returning:
		# Accelerate while returning to player
		var distance_to_player = global_position.distance_to(thrower.global_position)
		var return_progress = 1.0 - (distance_to_player / BAT_TRAVEL_DISTANCE)
		return_progress = clamp(return_progress, 0.0, 1.0)  # Prevent negative values
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
	# Validate inputs before movement
	if _is_position_invalid() or _is_direction_invalid():
		# Invalid state detected in _move_and_bounce
		_force_fallback_return()
		return
	
	var move_vec = direction.normalized() * current_speed * delta
	var intended_pos = global_position + move_vec
	
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, intended_pos)
	query.exclude = [self]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 0xFFFFFFFF
	
	var ray_result := space.intersect_ray(query)
	
	if ray_result:
		
		if ray_result.collider and (ray_result.collider is TileMap or ray_result.collider.is_in_group("colliders")):
			if can_bounce:
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
				
				# After 3 bounces, always return
				if bounce_count >= 3:
					is_returning = true
					_handle_auto_return(delta)
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
	
	# Check if bat is going out of bounds
	var screen_size = get_viewport().get_visible_rect().size
	var camera_pos = get_viewport().get_camera_2d().global_position if get_viewport().get_camera_2d() else Vector2.ZERO
	var screen_bounds = Rect2(camera_pos - screen_size/2, screen_size)
	
	if not screen_bounds.has_point(global_position):
		# Bat left screen - trigger return logic
		if not is_returning:
			_force_fallback_return()

# STATE HANDLERS

func _handle_auto_return(delta: float):
	if not thrower or not is_instance_valid(thrower):
		# Thrower invalid during return
		queue_free()
		return

	# Check for invalid states before return movement
	if _is_position_invalid():
		# Invalid position during return, forcing cleanup
		queue_free()
		return

	var to_player = thrower.global_position - global_position
	var distance = to_player.length()
	if distance <= 0.0:
		_pickup_bat()
		return
	
	# Check for infinite distance
	if is_inf(distance) or is_nan(distance):
		# Infinite/NaN distance to player
		queue_free()
		return

	# Clamp movement to remaining distance
	var move_distance = min(current_speed * delta, distance)
	global_position += to_player.normalized() * move_distance

	# Check for pickup immediately after moving
	if global_position.distance_to(thrower.global_position) <= 40.0:
		_pickup_bat()

func _pickup_bat():
	# Bat picked up by player
	is_returning = false  # Reset return state
	if thrower and is_instance_valid(thrower):
		if thrower.has_method("_on_bat_returned"):
			thrower._on_bat_returned()
	queue_free()

func _check_fallback_conditions():
	# Skip if already returning
	if is_returning:
		return
	
	# CONDITION 1: Total timeout exceeded
	if total_flight_time >= fallback_timeout:
		# Fallback: Bat timeout exceeded, forcing return
		_force_fallback_return()
		return
	
	# CONDITION 2: Stuck detection (no movement)
	if last_position != Vector2.ZERO:
		var movement_distance = global_position.distance_to(last_position)
		if movement_distance < 1.0:  # Barely moved
			stuck_timer += get_physics_process_delta_time()
			if stuck_timer >= stuck_detection_time:
				# Fallback: Bat appears stuck, forcing return
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
	
	# Fallback activated: Bat returning to player (ignoring collisions)

func _return_to_player():
	# Bat returning to player (no bounces)
	if thrower and is_instance_valid(thrower):
		if thrower.has_method("_on_bat_returned"):
			thrower._on_bat_returned()
	queue_free()

func _get_current_state() -> String:
	if is_returning:
		return "RETURNING"
	else:
		return "FLYING"

# DEBUG: Helper functions to detect invalid bat states
func _is_position_invalid(pos: Vector2 = global_position) -> bool:
	return is_nan(pos.x) or is_nan(pos.y) or is_inf(pos.x) or is_inf(pos.y)

func _is_direction_invalid() -> bool:
	return is_nan(direction.x) or is_nan(direction.y) or is_inf(direction.x) or is_inf(direction.y)

func _is_speed_invalid() -> bool:
	return is_nan(current_speed) or is_inf(current_speed) or current_speed < 0.0
