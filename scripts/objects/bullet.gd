extends Area2D

const AudioUtils = preload("res://scripts/utils/audio_utils.gd")
const MetalSparkUtils = preload("res://scripts/utils/metal_spark_utils.gd")

@export var speed: float = 520.0
@export var damage: int = 20
@export var safe_enemy_player_distance: float = 32.0
@export var safe_enemy_shooter_distance: float = 100.0
var direction: Vector2 = Vector2.RIGHT
var shooter: Node = null

const DUST_PARTICLE_SCENE := preload("res://scenes/objects/dust_particle.tscn")

func _ready() -> void:
	direction = direction.normalized()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	# Add to projectiles group for chain detection
	add_to_group("projectiles")
	
	# Ensure bullet can hit both alive and dead enemies by adding their layers
	collision_mask |= 2  # Add alive enemy layer (bitwise OR)
	collision_mask |= 8  # Add dead enemy layer (bitwise OR)
	collision_mask |= 1  # Add world/collider layer (bitwise OR)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
	_apply_damage(area)

func _on_body_entered(body: Node) -> void:
	# Check if hit a tileset (TileMap), solid surface, or collider
	if body is TileMap or body.is_in_group("walls") or body.is_in_group("ground") or body.is_in_group("colliders"):
		call_deferred("_create_impact_effect")
		queue_free()
		return
	
	_apply_damage(body)

func _create_impact_effect() -> void:
	# Create white particle impact effect
	var scene := get_tree().current_scene
	if scene == null or DUST_PARTICLE_SCENE == null:
		return
	
	# Create metal sparks for bullet impact
	_create_metal_sparks(global_position, direction)
	
	# Create 3-5 white particles for impact
	var particle_count := randi_range(3, 5)
	for i in range(particle_count):
		var particle := DUST_PARTICLE_SCENE.instantiate()
		if particle == null:
			continue
		
		# Position particle at bullet impact location
		particle.global_position = global_position
		
		# Give particle random velocity away from impact point
		var spread_angle := randf_range(0.0, PI * 2.0)
		var spread_speed := randf_range(50.0, 120.0)
		particle.velocity = Vector2(cos(spread_angle), sin(spread_angle)) * spread_speed
		
		# Shorter lifetime for impact particles
		particle.lifetime = randf_range(0.3, 0.6)
		
		# Make particles white and more visible
		if particle.has_node("Sprite"):
			var sprite = particle.get_node("Sprite")
			sprite.modulate = Color.WHITE
		
		scene.add_child(particle)

func _apply_damage(target: Node) -> void:
	if not is_instance_valid(target):
		return
	# Do not damage the shooter who fired this bullet
	if target == shooter:
		return
	# Do not damage enemies that are currently very close to the player
	if target.is_in_group("enemies") and shooter and shooter.is_in_group("enemies"):
		var player := _get_player()
		if player and player.global_position.distance_to(target.global_position) < safe_enemy_player_distance:
			return
		# Also do not damage enemies that are very close to the shooter
		if shooter.global_position.distance_to(target.global_position) < safe_enemy_shooter_distance:
			return
	# Check if enemy is inactive - if on screen, damage and activate it
	if target.is_in_group("enemies") and ("is_active" in target) and not target.is_active:
		# Check if the inactive enemy is visible on screen
		var notifier = target.get_node_or_null("VisibilityNotifier2D")
		if notifier and notifier.is_on_screen():
			# Enemy is on screen but inactive - damage it and activate it
			if target.has_method("take_damage"):
				# Pass bullet direction and position to take_damage for proper blood spray direction and position
				if target.has_method("take_damage_with_direction"):
					target.take_damage_with_direction(damage, direction, global_position)
				else:
					target.take_damage(damage)
				# Activate the enemy after taking damage
				target.is_active = true
				target.has_been_visible_with_player = true
			queue_free()
			return
		else:
			# Enemy is inactive and not on screen - don't damage
			return
	if target.has_method("take_damage"):
		# Pass bullet direction and position to take_damage for proper blood spray direction and position
		if target.has_method("take_damage_with_direction"):
			target.take_damage_with_direction(damage, direction, global_position)
		else:
			target.take_damage(damage)
		queue_free()

func _get_player() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("Player")

func _create_metal_sparks(pos: Vector2, normal: Vector2) -> void:
	MetalSparkUtils.create_metal_sparks(pos, normal, "bullet")

