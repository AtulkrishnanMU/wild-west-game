extends Node2D

const AudioUtils = preload("res://scripts/utils/audio_utils.gd")
const CHAIN_SOUND_PATH := "res://sounds/chain.mp3"
const CHAIN_SOUND := preload("res://sounds/chain.mp3")  # Preloaded for performance

# Performance optimization: cached references
var _cached_player: CharacterBody2D = null
var _cached_enemies: Array[Node] = []
var _cached_areas: Array[Node] = []
var _cache_update_timer: float = 0.0
const CACHE_UPDATE_INTERVAL: float = 0.1  # Update cache every 100ms

# Performance optimization: collision check timer
var _collision_check_timer: float = 0.0
const COLLISION_CHECK_INTERVAL: float = 0.02  # Check every 20ms instead of every frame

# Player bat attack tracking
var _player_bat_attack_active: bool = false
var _player_bat_hit_this_attack: bool = false

# Chain configuration
var chain_segments = []
var collision_enabled = true
var chain_force = 150.0  # Default force for player collisions
var chain_damping = 0.95
var settle_timer = 0.0
var collision_cooldown = 0.0  # Cooldown to prevent re-triggering

func _ready():
	# Get all chain segments
	for child in get_children():
		if child is RigidBody2D:
			chain_segments.append(child)
	
	# Set up physics properties for realistic chain motion
	_setup_chain_physics()
	
	# Set up a physics process to check for collisions manually
	set_physics_process(true)

func _setup_chain_physics():
	# Configure each segment for realistic chain behavior
	for segment in chain_segments:
		segment.custom_integrator = false
		segment.gravity_scale = 0.5  # Further reduced gravity
		segment.mass = 2.0  # Further increased mass for maximum stability
		segment.linear_damp = 0.8  # Much higher damping to minimize swinging
		segment.angular_damp = 1.2  # Much higher angular damping
		segment.contact_monitor = true
		
		# Set up collision layers - chain should not block player
		# Layer 1: World/Environment
		# Layer 2: Player  
		# Layer 3: Enemies
		# Layer 4: Chain (non-blocking)
		segment.collision_layer = 4  # Put chain on its own layer
		segment.collision_mask = 1  # Only collide with world, not with player or enemies

func _physics_process(delta):
	if not collision_enabled:
		return
	
	# Update cooldown timer
	if collision_cooldown > 0:
		collision_cooldown -= delta
	
	# Update settle timer
	if settle_timer > 0:
		settle_timer -= delta
		if settle_timer <= 0:
			# Allow chain to sleep and settle
			for segment in chain_segments:
				if segment.linear_velocity.length() < 10 and segment.angular_velocity < 0.1:
					segment.sleeping = true
	
	# Update cache periodically (optimized)
	_update_cache(delta)
	
	# Optimize: Only check collisions at intervals instead of every frame
	_collision_check_timer += delta
	if _collision_check_timer < COLLISION_CHECK_INTERVAL:
		return  # Skip collision check this frame
	
	_collision_check_timer = 0.0  # Reset timer
	
	# Check for collisions with cached references
	_check_collisions_optimized()

func _update_cache(delta: float):
	_cache_update_timer += delta
	if _cache_update_timer < CACHE_UPDATE_INTERVAL:
		return
	
	_cache_update_timer = 0.0
	
	# Update player cache
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = _find_player()
	
	# Only update enemies within range
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	_cached_enemies.clear()
	for enemy in all_enemies:
		if enemy.global_position.distance_squared_to(global_position) < 250000:  # 500px range squared
			_cached_enemies.append(enemy)
	
	# Update areas cache (only bat and bullet objects)
	_cached_areas = _find_projectile_areas()

func _find_player() -> CharacterBody2D:
	# Try to find player through common groups first
	var character_bodies = get_tree().get_nodes_in_group("character")
	for body in character_bodies:
		if body.get_script() and body.get_script().get_global_name() == "Player":
			return body as CharacterBody2D
	
	# Fallback: search scene tree (only if needed)
	var root = get_tree().current_scene
	return _search_for_player_recursive(root)

func _search_for_player_recursive(node: Node) -> CharacterBody2D:
	if node is CharacterBody2D and node.get_script() and node.get_script().get_global_name() == "Player":
		return node as CharacterBody2D
	
	for child in node.get_children():
		var result = _search_for_player_recursive(child)
		if result:
			return result
	
	return null

func _find_projectile_areas() -> Array:
	var areas: Array[Node] = []
	
	# Check for thrown bat and bullet areas efficiently
	var all_areas = get_tree().get_nodes_in_group("projectiles")
	if all_areas.is_empty():
		# Fallback: search scene tree only if needed
		var root = get_tree().current_scene
		_search_for_projectile_areas_recursive(root, areas)
	else:
		areas = all_areas
	
	return areas

func _search_for_projectile_areas_recursive(node: Node, areas: Array):
	if node is Area2D:
		# Check if it's a thrown bat
		if node.get_script() and node.get_script().get_global_name() == "ThrownBat":
			areas.append(node)
		# Check if it's a bullet
		elif "bullet" in node.name.to_lower() or node.name == "bullet":
			areas.append(node)
	
	for child in node.get_children():
		_search_for_projectile_areas_recursive(child, areas)

func _check_collisions_optimized():
	var chain_center = global_position
	const CHECK_DISTANCE = 500.0
	const CHECK_DISTANCE_SQ = CHECK_DISTANCE * CHECK_DISTANCE
	
	# Check cached player
	if _cached_player and is_instance_valid(_cached_player):
		var distance_sq = _cached_player.global_position.distance_squared_to(chain_center)
		if distance_sq < CHECK_DISTANCE_SQ:
			_check_collision_with_body(_cached_player)
			
		# Track player attack state and check bat collision
		var is_attacking = _cached_player.get("is_attacking")
		if is_attacking and not _player_bat_attack_active:
			# Player just started attacking
			_player_bat_attack_active = true
			_player_bat_hit_this_attack = false
		elif not is_attacking and _player_bat_attack_active:
			# Player just stopped attacking
			_player_bat_attack_active = false
			_player_bat_hit_this_attack = false
		
		# Check player's bat sprite during attack (but only once per attack)
		if is_attacking and not _player_bat_hit_this_attack:
			_check_player_bat_collision(_cached_player)
	
	# Check cached enemies (optimized distance check)
	for enemy in _cached_enemies:
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		
		var distance_sq = enemy.global_position.distance_squared_to(chain_center)
		if distance_sq < CHECK_DISTANCE_SQ:
			_check_collision_with_body(enemy)
	
	# Check cached areas (projectiles)
	for area in _cached_areas:
		if not is_instance_valid(area):
			continue
		
		var distance_sq = area.global_position.distance_squared_to(chain_center)
		if distance_sq < CHECK_DISTANCE_SQ:
			_check_collision_with_body(area)

func _check_player_bat_collision(player: CharacterBody2D):
	# Get the player's bat sprite
	var bat_sprite = player.get("bat_sprite")
	if not bat_sprite or not bat_sprite.visible:
		return
	
	# Check distance between bat sprite and chain
	var bat_pos = bat_sprite.global_position
	var chain_center = global_position
	if bat_pos.distance_to(chain_center) > 150:  # Same detection range as other collisions
		return
	
	# Check collision with each chain segment
	for segment in chain_segments:
		var segment_pos = segment.global_position + Vector2(0, 31)  # Account for sprite offset
		var bat_size = Vector2(32, 32)  # Approximate bat size
		var segment_size = Vector2(20, 20)
		
		# Simple AABB collision check
		if abs(bat_pos.x - segment_pos.x) < (bat_size.x + segment_size.x) / 2 and \
		   abs(bat_pos.y - segment_pos.y) < (bat_size.y + segment_size.y) / 2:
			
			# Mark that we've hit the chain this attack
			_player_bat_hit_this_attack = true
			
			# Apply chain motion with thrown bat force (same as thrown bat)
			_apply_chain_motion(player, 400.0)
			
			# Play chain swing sound
			AudioUtils.play_positioned_sound(CHAIN_SOUND, global_position, 0.8, 1.2)
			
			# Apply cooldown for player bat attacks so chain can settle
			_settle_chain_timer(true)
			break

func _check_collision_with_body(body):
	if not body:
		return
	
	# Skip collision detection during cooldown ONLY for characters (player/enemies) and dropped bats
	var is_dropped_bat = false
	if body.get_script() and body.get_script().get_global_name() == "ThrownBat":
		# Check if bat is dropped/pickable (not thrown)
		is_dropped_bat = body.get("is_pickable") or body.get("is_dropping")
	
	if collision_cooldown > 0 and ((body is CharacterBody2D or body.is_in_group("enemies")) or is_dropped_bat):
		return
		
	var body_pos = body.global_position
	var body_size = Vector2(32, 32)  # Reduced to more accurate size
	
	# Quick distance check first to avoid spam
	var chain_center = global_position
	if body_pos.distance_to(chain_center) > 150:  # Much tighter detection range
		return
	
	
	# Check collision with each chain segment
	for segment in chain_segments:
		var segment_pos = segment.global_position + Vector2(0, 31)  # Account for sprite offset
		var segment_size = Vector2(20, 20)  # Reduced to actual segment size
		
		
		# Simple AABB collision check with tighter threshold
		if abs(body_pos.x - segment_pos.x) < (body_size.x + segment_size.x) / 2 and \
		   abs(body_pos.y - segment_pos.y) < (body_size.y + segment_size.y) / 2:
			
			var force = _get_collision_force(body)
			var is_character = body is CharacterBody2D or body.is_in_group("enemies")
			
			_apply_chain_motion(body, force)
			
			# Play chain swing sound with random pitch (using preloaded audio)
			AudioUtils.play_positioned_sound(CHAIN_SOUND, global_position, 0.8, 1.2)
			
			# Allow chain to settle after a short time
			_settle_chain_timer(is_character or is_dropped_bat)
			break

func _get_collision_force(colliding_body):
	# Determine force based on collision type
	var force = chain_force  # Default force for player
	
	# Check if it's a thrown bat (Area2D with ThrownBat class)
	if colliding_body.get_script() and colliding_body.get_script().get_global_name() == "ThrownBat":
		force = 400.0  # High force for bat impacts
	
	# Check if it's a bullet (Area2D with bullet name or script)
	elif "bullet" in colliding_body.name.to_lower() or colliding_body.name == "bullet":
		force = 300.0  # Medium-high force for bullets
	
	# Check if it's an enemy
	elif colliding_body.is_in_group("enemies"):
		force = 200.0  # Slightly higher force for enemies
	
	else:
		# Default force for player
		force = chain_force
		
	return force

func _apply_chain_motion(body, force_multiplier = 1.0):
	var collision_point = body.global_position
	var closest = _get_closest_segment(collision_point)

	if closest:
		closest.sleeping = false  # Only wake up the chain segment

		var dir = (closest.global_position - body.global_position).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2(randf() - 0.5, randf() - 0.5).normalized()
		
		closest.apply_central_impulse(dir * force_multiplier)
		closest.apply_torque_impulse(randf_range(-10, 10))  # Very minimal torque

		if body is RigidBody2D:
			body.sleeping = false  # Only wake up if it's a RigidBody2D
			body.apply_central_impulse(-dir * force_multiplier * 0.4)

		_propagate_chain_motion(closest, dir, force_multiplier)
		
		# Allow chain to settle after a short time
		_settle_chain_timer()

func _propagate_chain_motion(source_segment, force_direction, force_multiplier):
	var propagation_delay = 0.05
	var force_falloff = 0.3  # Much less propagation force
	
	# Find connected segments through joints
	for segment in chain_segments:
		if segment != source_segment:
			var distance = segment.global_position.distance_to(source_segment.global_position)
			if distance < 100:  # Only affect nearby segments
				var delayed_force = force_direction * force_multiplier * force_falloff * (1.0 - distance/100)
				segment.apply_central_impulse(delayed_force)
				segment.apply_torque_impulse(randf_range(-5, 5))  # Very minimal torque

func _get_closest_segment(point):
	var closest_segment = null
	var closest_distance = INF
	
	for segment in chain_segments:
		var distance = segment.global_position.distance_to(point)
		if distance < closest_distance:
			closest_distance = distance
			closest_segment = segment
	
	return closest_segment


func set_collision_enabled(enabled: bool):
	collision_enabled = enabled

func get_chain_segments():
	return chain_segments

func _settle_chain_timer(is_character_collision: bool = true):
	settle_timer = 2.0  # Settle after 2 seconds
	if is_character_collision:
		collision_cooldown = 3.0  # 3 second cooldown only for character collisions
	else:
		collision_cooldown = 0.0  # No cooldown for projectile collisions
