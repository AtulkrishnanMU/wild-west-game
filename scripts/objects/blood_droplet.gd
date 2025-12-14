extends "res://scripts/objects/particle.gd"

const BLOOD_DECAL_SCENE := preload("res://scenes/objects/blood_decal.tscn")

func _ready() -> void:
	# Override particle properties for blood
	particle_gravity = 500.0
	lifetime = 2.0
	fade_alpha_multiplier = 0.8
	
	super._ready()

func _setup_particle_appearance() -> void:
	# Set up blood droplet appearance with solid pixels
	if sprite:
		var texture = ImageTexture.new()
		var image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		
		# Generate darker red shade
		var red_value = randf_range(0.4, 0.7)        # Red channel: 40%-70% (darker)
		var green_value = randf_range(0.0, 0.1)      # Green channel: 0%-10% (for darker reds)
		var blue_value = randf_range(0.0, 0.05)       # Blue channel: 0%-5% (minimal blue)
		
		# Create solid pixel blood droplet (4x4 square)
		for x in range(2, 6):  # Center 4x4 pixels
			for y in range(2, 6):
				image.set_pixel(x, y, Color(red_value, green_value, blue_value, 1.0))
		
		texture.set_image(image)
		sprite.texture = texture
		sprite.centered = true
		
		# Disable texture filtering for crisp pixels
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _should_collide_with(body: Node) -> bool:
	# Blood collides with more surfaces including characters
	return body is TileMap or body.is_in_group("walls") or body.is_in_group("ground") or body.is_in_group("colliders") or body.is_in_group("enemies") or body.is_in_group("player")

func _on_collision(body: Node) -> void:
	# Create blood decal on collision
	_create_blood_decal()
	
	# Start disappearance timer after hitting floor
	if body is TileMap or body.is_in_group("ground") or body.is_in_group("colliders"):
		# Set a short timer to disappear after 0.5 seconds
		var timer = get_tree().create_timer(0.5)
		timer.timeout.connect(queue_free)

func _create_blood_decal() -> void:
	var decal = BLOOD_DECAL_SCENE.instantiate()
	if decal:
		# Add decal to the scene tree at bottom layer (first to be drawn)
		var scene = get_tree().current_scene
		scene.add_child(decal)
		scene.move_child(decal, 0)
		
		decal.global_position = global_position
		
		# Random rotation and scale for variety
		decal.rotation = randf() * PI
		var scale_factor = randf_range(0.2, 0.6)
		decal.scale = Vector2(scale_factor, scale_factor)
