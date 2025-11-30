extends Node2D

const DUST_PARTICLE_SCENE := preload("res://scenes/objects/dust_particle.tscn")
const PARTICLE_COUNT := 6  # Increased from 4

var direction: Vector2 = Vector2(0.2, 0.8)  # Mostly downward with slight horizontal spread

func _ready() -> void:
	call_deferred("_spawn_dust_particles")

func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()

func _spawn_dust_particles() -> void:
	print("Spawning dust particles!")
	for i in range(PARTICLE_COUNT):
		var particle = DUST_PARTICLE_SCENE.instantiate()
		if particle:
			add_child(particle)
			print("Created dust particle ", i)
			# Random initial velocity and position based on direction
			var angle_offset = randf_range(-PI/3, PI/3)  # Wider spread for dust
			var angle = direction.angle() + angle_offset
			var speed = randf_range(60, 120)  # Slower speed for settling dust
			var velocity_dir = Vector2.RIGHT.rotated(angle)
			
			particle.position = Vector2(randf_range(-4, 4), randf_range(-4, 4))
			particle.velocity = velocity_dir * speed
			particle.lifetime = randf_range(1.5, 2.5)  # Shorter lifetime
		else:
			print("Failed to instantiate dust particle!")
