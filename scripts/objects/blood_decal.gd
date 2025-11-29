extends Node2D

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	# Set a random blood texture/sprite appearance
	if sprite:
		# Use a simple colored rectangle as blood decal
		var texture = ImageTexture.new()
		var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		
		# Create a simple blood splatter pattern
		var center = Vector2(8, 8)
		for x in range(16):
			for y in range(16):
				var dist = Vector2(x, y).distance_to(center)
				if dist < 6:
					var alpha = 1.0 - (dist / 6.0)
					var redness = randf_range(0.7, 1.0)
					image.set_pixel(x, y, Color(redness, 0.1, 0.1, alpha * 0.7))
		
		texture.set_image(image)
		sprite.texture = texture
		sprite.centered = true
