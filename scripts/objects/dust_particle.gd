extends Area2D

const DUST_DECAL_SCENE := preload("res://scenes/objects/dust_decal.tscn")
const GRAVITY := 300.0  # Heavier gravity for settling dust

var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 1.5
var age: float = 0.0
var has_stuck: bool = false

@onready var sprite: Sprite2D = $Sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# Set up dust particle appearance
	if sprite:
		var texture = ImageTexture.new()
		var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)  # Even larger size
		image.fill(Color.TRANSPARENT)
		
		# Create small dust particle with white colors
		var center = Vector2(8, 8)
		for x in range(16):
			for y in range(16):
				var dist = Vector2(x, y).distance_to(center)
				if dist < 6.0:  # Larger radius
					var alpha = 1.0 - (dist / 6.0)
					# White dust colors with very reduced opacity
					var white_value = randf_range(0.8, 1.0)
					image.set_pixel(x, y, Color(white_value, white_value, white_value, alpha * 0.15))
		
		texture.set_image(image)
		sprite.texture = texture
		sprite.centered = true
	
	# Connect collision signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if has_stuck:
		return
	
	age += delta
	
	# Apply gravity (less than blood)
	velocity.y += GRAVITY * delta
	
	# Move and check collision
	global_position += velocity * delta
	
	# Fade out over lifetime
	if sprite:
		var alpha = max(0.0, 1.0 - (age / lifetime))
		sprite.modulate.a = alpha * 0.6
	
	# Remove if lifetime exceeded
	if age >= lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if has_stuck:
		return
	
	# Check if hit a solid surface (ground, walls, tilemap)
	if body is TileMap or body.is_in_group("walls") or body.is_in_group("ground"):
		# Just disappear when hitting surface - no decal for dust
		has_stuck = true
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if has_stuck:
		return
	# Handle area collisions if needed
