extends "res://scripts/objects/particle.gd"

const BLOOD_DECAL_SCENE := preload("res://scenes/objects/blood_decal.tscn")

func _ready() -> void:
	# Override particle properties for blood
	particle_gravity = 500.0
	lifetime = 2.0
	fade_alpha_multiplier = 0.8
	
	super._ready()

func _setup_particle_appearance() -> void:
	# Set up blood droplet appearance with random red shade
	if sprite:
		var texture = ImageTexture.new()
		var image = Image.create(6, 6, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		
		# Generate random red shade
		var red_value = randf_range(0.7, 1.0)        # Red channel: 70%-100%
		var green_value = randf_range(0.0, 0.2)      # Green channel: 0%-20% (for darker/brighter reds)
		var blue_value = randf_range(0.0, 0.15)       # Blue channel: 0%-15% (minimal blue)
		
		# Create small blood droplet
		var center = Vector2(3, 3)
		for x in range(6):
			for y in range(6):
				var dist = Vector2(x, y).distance_to(center)
				if dist < 2.5:
					var alpha = 1.0 - (dist / 2.5)
					image.set_pixel(x, y, Color(red_value, green_value, blue_value, alpha * 0.8))
		
		texture.set_image(image)
		sprite.texture = texture
		sprite.centered = true

func _should_collide_with(body: Node) -> bool:
	# Blood collides with more surfaces including characters
	return body is TileMap or body.is_in_group("walls") or body.is_in_group("ground") or body.is_in_group("enemies") or body.is_in_group("player")

func _on_collision(body: Node) -> void:
	# Create blood decal on collision
	_create_blood_decal()

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
