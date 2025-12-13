extends StaticBody2D

class_name Collider

# Simple collider script for extendable collision shapes
# Can be resized in the editor or programmatically

func _ready():
	# Set up collision properties
	collision_layer = 1  # World collision layer
	collision_mask = 8   # Detect projectiles (bullets are on layer 8)
	
	# Ensure the ColorRect matches the collision shape
	update_visual_size()

func update_visual_size():
	# Sync visual size with collision shape
	var collision_shape = $CollisionShape2D
	var color_rect = $ColorRect
	
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rect_size = collision_shape.shape.size
		color_rect.size = rect_size
		color_rect.position = -rect_size / 2

# Function to resize the collider
func set_size(new_size: Vector2):
	var collision_shape = $CollisionShape2D
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = new_size
		update_visual_size()

# Function to get current size
func get_size() -> Vector2:
	var collision_shape = $CollisionShape2D
	if collision_shape and collision_shape.shape is RectangleShape2D:
		return collision_shape.shape.size
	return Vector2.ZERO
