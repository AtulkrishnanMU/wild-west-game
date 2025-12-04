class_name Particle
extends Area2D

# Shared particle properties - can be overridden by child classes
var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 2.0
var age: float = 0.0
var has_stuck: bool = false
var particle_gravity: float = 500.0
var fade_alpha_multiplier: float = 0.8

@onready var sprite: Sprite2D = $Sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# Set up particle appearance - to be overridden by child classes
	_setup_particle_appearance()
	
	# Connect collision signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if has_stuck:
		return
	
	age += delta
	
	# Apply gravity
	velocity.y += particle_gravity * delta
	
	# Move and check collision
	global_position += velocity * delta
	
	# Fade out over lifetime
	if sprite:
		var alpha = max(0.0, 1.0 - (age / lifetime))
		sprite.modulate.a = alpha * fade_alpha_multiplier
	
	# Remove if lifetime exceeded
	if age >= lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if has_stuck:
		return
	
	# Check if hit a solid surface - can be overridden by child classes
	if _should_collide_with(body):
		_on_collision(body)
		has_stuck = true
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if has_stuck:
		return
	# Handle area collisions if needed - can be overridden by child classes

# Virtual methods to be overridden by child classes
func _setup_particle_appearance() -> void:
	# Override this method in child classes to set up custom appearance
	pass

func _should_collide_with(body: Node) -> bool:
	# Override this method in child classes to define collision behavior
	# Default implementation for basic surfaces
	return body is TileMap or body.is_in_group("walls") or body.is_in_group("ground")

func _on_collision(body: Node) -> void:
	# Override this method in child classes to handle collision effects
	# Default implementation does nothing
	pass
