extends Node2D

const BLOOD_DROPLET_SCENE := preload("res://scenes/objects/blood_droplet.tscn")
const BLOOD_FLOATING_DECAL_SCENE := preload("res://scenes/objects/blood_floating_decal.tscn")
const DROPLET_COUNT := 12
const FLOATING_DECAL_COUNT := 4  # Increased count since we're removing droplets
const DEAD_ENEMY_DROPLET_COUNT := 3  # Reduced blood for dead enemies
const DEAD_ENEMY_FLOATING_DECAL_COUNT := 2  # Increased for dead enemies

var direction: Vector2 = Vector2.RIGHT  # Default direction, can be set from outside
var is_dead_enemy: bool = false  # Flag to reduce blood amount

func _ready() -> void:
	call_deferred("_spawn_blood_droplets")

func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()

func set_dead_enemy(dead: bool) -> void:
	is_dead_enemy = dead

func _spawn_blood_droplets() -> void:
	var droplet_count = DEAD_ENEMY_DROPLET_COUNT if is_dead_enemy else DROPLET_COUNT
	var floating_decal_count = DEAD_ENEMY_FLOATING_DECAL_COUNT if is_dead_enemy else FLOATING_DECAL_COUNT
	
	# Spawn regular falling droplets
	for i in range(droplet_count):
		var droplet = BLOOD_DROPLET_SCENE.instantiate()
		if droplet:
			add_child(droplet)
			# Random initial velocity and position based on direction
			var angle_offset = randf_range(-PI/3, PI/3)  # Spread in front arc
			var angle = direction.angle() + angle_offset
			# Higher speed for dead enemies to compensate for fewer particles
			var speed = randf_range(350, 500) if is_dead_enemy else randf_range(250, 400)
			var velocity_dir = Vector2.RIGHT.rotated(angle)
			
			droplet.position = Vector2(randf_range(-8, 8), randf_range(-8, 8))
			droplet.velocity = velocity_dir * speed
			droplet.lifetime = randf_range(1.5, 2.5)
	
	# Spawn floating blood decals
	for i in range(floating_decal_count):
		var floating_decal = BLOOD_FLOATING_DECAL_SCENE.instantiate()
		if floating_decal:
			add_child(floating_decal)
			# Random initial velocity and position based on direction
			var angle_offset = randf_range(-PI/4, PI/4)  # Spread for decals
			
			# Calculate base angle from direction
			var base_angle = direction.angle()
			
			# Apply upward bias relative to direction
			var angle = base_angle + angle_offset
			if direction.x > 0:  # Shooting right
				angle -= PI/4  # Bias upward
			else:  # Shooting left
				angle += PI/4  # Bias upward (relative to left direction)
			
			# Higher speed for dead enemies to compensate for fewer particles
			var speed = randf_range(180, 300) if is_dead_enemy else randf_range(120, 220)
			var velocity_dir = Vector2.RIGHT.rotated(angle)
			
			floating_decal.position = Vector2(randf_range(-6, 6), randf_range(-6, -2))  # Start position
			floating_decal.velocity = velocity_dir * speed
