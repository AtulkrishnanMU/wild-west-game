extends Node2D

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	# Set a random dust texture/sprite appearance
	if sprite:
		# Use a simple colored rectangle as dust decal
		var texture = ImageTexture.new()
		var image = Image.create(12, 12, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		
		# Create a simple dust splatter pattern with brown colors
		var center = Vector2(6, 6)
		for x in range(12):
			for y in range(12):
				var dist = Vector2(x, y).distance_to(center)
				if dist < 5:
					var alpha = 1.0 - (dist / 5.0)
					# Brown dust colors
					var brown_base = randf_range(0.25, 0.35)
					var red_component = brown_base + randf_range(0.15, 0.25)
					var green_component = brown_base + randf_range(0.05, 0.15)
					var blue_component = brown_base * 0.6
					image.set_pixel(x, y, Color(red_component, green_component, blue_component, alpha * 0.5))
		
		texture.set_image(image)
		sprite.texture = texture
		sprite.centered = true
