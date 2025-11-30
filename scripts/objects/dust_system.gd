extends Node2D

const DUST_PARTICLE_SCENE := preload("res://scenes/objects/dust_particle.tscn")
const PARTICLE_COUNT := 8

var direction: Vector2 = Vector2.UP  # Default upward direction for dust

func _ready() -> void:
	call_deferred("_spawn_dust_particles")

func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()

func _spawn_dust_particles() -> void:
	for i in range(PARTICLE_COUNT):
		var particle = DUST_PARTICLE_SCENE.instantiate()
		if particle:
			add_child(particle)
			# Random initial velocity and position based on direction
			var angle_offset = randf_range(-PI/4, PI/4)  # Smaller spread for dust
			var angle = direction.angle() + angle_offset
			var speed = randf_range(80, 150)  # Slower than blood
			var velocity_dir = Vector2.RIGHT.rotated(angle)
			
			particle.position = Vector2(randf_range(-4, 4), randf_range(-4, 4))
			particle.velocity = velocity_dir * speed
			particle.lifetime = randf_range(1.0, 1.5)
