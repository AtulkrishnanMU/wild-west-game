extends "res://scripts/objects/particle.gd"

func _ready() -> void:
	# Override particle properties for dust
	particle_gravity = 300.0  # Less gravity for settling dust
	lifetime = 1.5
	fade_alpha_multiplier = 0.6
	
	super._ready()

func _setup_particle_appearance() -> void:
	# Set up dust particle appearance
	if sprite:
		var texture = ImageTexture.new()
		var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)  # Larger size for dust
		image.fill(Color.TRANSPARENT)
		
		# Create dust particle with white colors
		var center = Vector2(8, 8)
		for x in range(16):
			for y in range(16):
				var dist = Vector2(x, y).distance_to(center)
				if dist < 6.0:  # Larger radius
					var alpha = 1.0 - (dist / 6.0)
					# Black dust colors with very reduced opacity
					var black_value = randf_range(0.0, 0.2)  # Dark black values
					image.set_pixel(x, y, Color(black_value, black_value, black_value, alpha * 0.15))
		
		texture.set_image(image)
		sprite.texture = texture
		sprite.centered = true

func _should_collide_with(body: Node) -> bool:
	# Dust only collides with basic surfaces
	return body is TileMap or body.is_in_group("walls") or body.is_in_group("ground")

func _on_collision(body: Node) -> void:
	# Dust just disappears - no decal
	pass
