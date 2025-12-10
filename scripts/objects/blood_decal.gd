extends Node2D

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	# Set a solid blood texture appearance
	if sprite:
		# Use a simple colored rectangle as blood decal
		var texture = ImageTexture.new()
		var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		
		# Generate random red shade
		var redness = randf_range(0.4, 0.7)
		
		# Create solid square blood decal
		for x in range(16):
			for y in range(16):
				image.set_pixel(x, y, Color(redness, 0.05, 0.05, 0.7))
		
		texture.set_image(image)
		sprite.texture = texture
		sprite.centered = true
		
		# Disable texture filtering for crisp pixels
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
