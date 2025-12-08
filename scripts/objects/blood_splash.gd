extends Node2D

const BLOOD_DROPLET_SCENE := preload("res://scenes/objects/blood_droplet.tscn")
const DROPLET_COUNT := 12
const DEAD_ENEMY_DROPLET_COUNT := 3  # Reduced blood for dead enemies

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
	print("Blood splash: is_dead_enemy=", is_dead_enemy, ", droplet_count=", droplet_count)
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
