extends Area2D

const BLOOD_DECAL_SCENE := preload("res://scenes/objects/blood_decal.tscn")
const GRAVITY := 500.0

var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 2.0
var age: float = 0.0
var has_stuck: bool = false

@onready var sprite: Sprite2D = $Sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# Set up blood droplet appearance
	if sprite:
		var texture = ImageTexture.new()
		var image = Image.create(6, 6, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		
		# Create small blood droplet
		var center = Vector2(3, 3)
		for x in range(6):
			for y in range(6):
				var dist = Vector2(x, y).distance_to(center)
				if dist < 2.5:
					var alpha = 1.0 - (dist / 2.5)
					image.set_pixel(x, y, Color(0.9, 0.1, 0.1, alpha * 0.8))
		
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
	
	# Apply gravity
	velocity.y += GRAVITY * delta
	
	# Move and check collision
	global_position += velocity * delta
	
	# Fade out over lifetime
	if sprite:
		var alpha = max(0.0, 1.0 - (age / lifetime))
		sprite.modulate.a = alpha * 0.8
	
	# Remove if lifetime exceeded
	if age >= lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if has_stuck:
		return
	
	# Check if hit a solid surface (walls, ground, tilemap, or any physics body)
	if body is TileMap or body.is_in_group("walls") or body.is_in_group("ground") or body.is_in_group("enemies") or body.is_in_group("player"):
		_create_blood_decal()
		has_stuck = true
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if has_stuck:
		return
	# Handle area collisions if needed

func _create_blood_decal() -> void:
	var decal = BLOOD_DECAL_SCENE.instantiate()
	if decal:
		# Add decal to the scene tree (not as child of droplet)
		get_tree().current_scene.add_child(decal)
		decal.global_position = global_position
		
		# Random rotation and scale for variety
		decal.rotation = randf() * PI
		var scale_factor = randf_range(0.2, 0.6)
		decal.scale = Vector2(scale_factor, scale_factor)
