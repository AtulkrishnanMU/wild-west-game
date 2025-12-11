class_name ThrownBat
extends Area2D

const CharacterUtils = preload("res://scripts/utils/character_utils.gd")
const AudioUtils = preload("res://scripts/utils/audio_utils.gd")
const SPIN_SOUND_PATH := "res://sounds/spin.mp3"
const METAL_BOUNCE_SOUND_PATH := "res://sounds/metal.mp3"

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
	
	rotation_angle += SPIN_SPEED * current_spin_speed * 2 * PI * delta
	sprite.rotation = rotation_angle
	
	if spin_sound_player and not spin_sound_player.playing:
		spin_sound_player.play()
	if spin_sound_player:
		_update_sound_volume()
	
	_prev_position = global_position
	
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

func _update_sound_volume() -> void:
	if not spin_sound_player or not thrower or not is_instance_valid(thrower):
		return
	
	# Calculate distance from thrower
	var distance = global_position.distance_to(thrower.global_position)
	
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
		# Convert to decibels (logarithmic scale)
		spin_sound_player.volume_db = 20.0 * log(volume_ratio) / log(10.0)

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

# Shared movement + bounce detection
func _move_and_bounce(delta: float):
	var move_vec = direction.normalized() * BAT_SPEED * delta
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
			var normal = ray_result.normal
			if normal == Vector2.ZERO:
				normal = Vector2.UP
			
			var incoming = move_vec.normalized()
			var reflected = incoming.bounce(normal).normalized()
			direction = reflected
			
			global_position = ray_result.position + normal * 2.0
			
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
	print("Bat entering drop state after 3 bounces")

func _handle_dropping(delta: float):
	# Apply gravity
	vertical_velocity += drop_gravity * delta
	global_position.y += vertical_velocity * delta

	# Ground detection
	var space := get_world_2d().direct_space_state
	var ground_query = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 50))
	ground_query.exclude = [self]
	ground_query.collision_mask = 0xFFFFFFFF
	var ground_result = space.intersect_ray(ground_query)

	if ground_result:
		var float_height = 5.0
		var target_y = ground_result.position.y - float_height

		# Only stop if bat is at or below the target position
		if global_position.y >= target_y:
			global_position.y = target_y
			vertical_velocity = 0.0
			is_dropping = false
			is_pickable = true
			print("Bat is now pickable")

func _handle_pickable():
	# Slow down rotation gradually
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
	var move_distance = min(BAT_RETURN_SPEED * delta, distance)
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

func _return_to_player():
	print("Bat returning to player (no bounces)")
	if thrower and is_instance_valid(thrower):
		if thrower.has_method("_on_bat_returned"):
			thrower._on_bat_returned()
	queue_free()
