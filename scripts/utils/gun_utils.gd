class_name GunUtils
extends RefCounted

# Creates a muzzle flash effect at the specified position and direction
static func create_muzzle_flash(position: Vector2, direction: Vector2) -> void:
	var scene: Node = Engine.get_main_loop().current_scene
	if scene == null:
		return
	
	# Create muzzle flash container
	var flash_root := Node2D.new()
	flash_root.position = position
	flash_root.rotation = direction.angle()
	scene.add_child(flash_root)
	
	# Create multiple flash particles for burst effect
	var flash_count = 4
	for i in range(flash_count):
		var flash := Sprite2D.new()
		# Use procedural texture directly (no external file dependency)
		flash.texture = create_muzzle_flash_texture()
		
		# Random positioning within small radius
		var spread_angle = randf_range(-0.3, 0.3)  # Small spread in radians
		var distance = randf_range(2.0, 8.0)
		flash.position = Vector2.RIGHT.rotated(spread_angle) * distance
		
		# Random size variation
		var scale = randf_range(0.8, 1.5)
		flash.scale = Vector2(scale, scale)
		
		# Bright yellow-orange color
		flash.modulate = Color(1.0, randf_range(0.6, 0.9), 0.0)
		
		flash_root.add_child(flash)
		
		# Animate flash: quick fade out and scale down
		var tween := flash_root.create_tween()
		tween.set_parallel(true)
		tween.tween_property(flash, "modulate:a", 0.0, 0.08)  # Very quick fade
		tween.tween_property(flash, "scale", Vector2.ZERO, 0.08)  # Shrink to nothing
		tween.finished.connect(flash.queue_free)
	
	# Remove the container after all flashes are done
	var cleanup_tween := flash_root.create_tween()
	cleanup_tween.tween_callback(flash_root.queue_free).set_delay(0.1)

# Creates a simple 4x4 muzzle flash texture as fallback
static func create_muzzle_flash_texture() -> ImageTexture:
	var image := Image.create(4, 4, false, Image.FORMAT_RGB8)
	image.fill(Color.WHITE)  # White base
	# Make center brighter
	image.set_pixel(1, 1, Color.YELLOW)
	image.set_pixel(2, 1, Color.YELLOW)
	image.set_pixel(1, 2, Color.YELLOW)
	image.set_pixel(2, 2, Color.YELLOW)
	var texture := ImageTexture.new()
	texture.set_image(image)
	return texture
