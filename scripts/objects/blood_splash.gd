extends Node2D

const BLOOD_DROPLET_SCENE := preload("res://scenes/objects/blood_droplet.tscn")
const BLOOD_FLOATING_DROPLET_SCENE := preload("res://scenes/objects/blood_floating_droplet.tscn")
const DROPLET_COUNT := 12
const FLOATING_DROPLET_COUNT := 4  # Number of floating droplets
const DEAD_ENEMY_DROPLET_COUNT := 3  # Reduced blood for dead enemies
const DEAD_ENEMY_FLOATING_COUNT := 1  # Reduced floating for dead enemies

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
	var floating_count = DEAD_ENEMY_FLOATING_COUNT if is_dead_enemy else FLOATING_DROPLET_COUNT
	print("Blood splash: is_dead_enemy=", is_dead_enemy, ", droplet_count=", droplet_count, ", floating_count=", floating_count)
	
	# Spawn regular falling droplets
	for i in range(droplet_count):
		var droplet = BLOOD_DROPLET_SCENE.instantiate()
		if droplet:
			add_child(droplet)
			# Random initial velocity and position based on direction
			var angle_offset = randf_range(-PI/3, PI/3)  # Spread in front arc
			var angle = direction.angle() + angle_offset
			var speed = randf_range(150, 300)
			var velocity_dir = Vector2.RIGHT.rotated(angle)
			
			droplet.position = Vector2(randf_range(-8, 8), randf_range(-8, 8))
			droplet.velocity = velocity_dir * speed
			droplet.lifetime = randf_range(1.5, 2.5)
	
	# Spawn floating droplets
	for i in range(floating_count):
		var floating_droplet = BLOOD_FLOATING_DROPLET_SCENE.instantiate()
		if floating_droplet:
			add_child(floating_droplet)
			# Random initial velocity and position based on direction - more dramatic movement
			var angle_offset = randf_range(-PI/6, PI/6)  # Tighter spread for focused effect
			
			# Calculate base angle from direction
			var base_angle = direction.angle()
			
			# Apply upward bias relative to direction, not absolute
			var angle = base_angle + angle_offset
			if direction.x > 0:  # Shooting right
				angle -= PI/3  # Bias upward
			else:  # Shooting left
				angle += PI/3  # Bias upward (relative to left direction)
			
			var speed = randf_range(120, 200)  # Good initial speed for movement
			var velocity_dir = Vector2.RIGHT.rotated(angle)
			
			floating_droplet.position = Vector2(randf_range(-4, 4), randf_range(-8, -4))  # Start slightly higher
			floating_droplet.velocity = velocity_dir * speed
			print("Spawned floating droplet with direction: ", direction, " base_angle: ", base_angle, " final_angle: ", angle, " velocity: ", velocity_dir * speed)
