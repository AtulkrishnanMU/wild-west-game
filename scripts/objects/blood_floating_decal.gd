extends "res://scripts/objects/particle.gd"

var float_duration: float = 0.0  # How long to move before sticking
var float_age: float = 0.0
var is_floating: bool = true
var float_drift: Vector2 = Vector2.ZERO
var has_stuck_in_air: bool = false

func _ready() -> void:
	# Override particle properties for floating blood decal
	particle_gravity = 0.0  # No gravity - stays in air
	lifetime = 8.0  # Longer lifetime for decals
	fade_alpha_multiplier = 0.6  # Slower fade for decals
	
	# Set random floating duration (0.4 seconds)
	float_duration = randf_range(0.3, 0.5)
	
	# Set random drift for floating effect
	float_drift = Vector2(randf_range(-25, 25), randf_range(-15, 15))
	
	
	super._ready()

func _setup_particle_appearance() -> void:
	# Set up floating blood decal appearance with solid pixels
	if sprite:
		var texture = ImageTexture.new()
		var image = Image.create(12, 12, false, Image.FORMAT_RGBA8)  # Smaller than ground decals
		image.fill(Color.TRANSPARENT)
		
		# Generate lighter red shade for floating decals
		var red_value = randf_range(0.5, 0.7)        # Red channel: 50%-70% (lighter than ground)
		var green_value = randf_range(0.0, 0.1)      # Green channel: 0%-10%
		var blue_value = randf_range(0.0, 0.05)       # Blue channel: 0%-5%
		
		# Create solid pixel blood decal pattern (smaller than ground decals)
		for x in range(12):
			for y in range(12):
				# Create smaller, more concentrated pattern for floating decals
				var center = Vector2(6, 6)
				var dist = Vector2(x, y).distance_to(center)
				if dist < 5:
					# Create pixelated pattern with some randomness
					var pixel_chance = 1.0 - (dist / 5.0)
					if randf() < pixel_chance:
						image.set_pixel(x, y, Color(red_value, green_value, blue_value, 0.6))
		
		texture.set_image(image)
		sprite.texture = texture
		sprite.centered = true
		
		# Disable texture filtering for crisp pixels
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _physics_process(delta: float) -> void:
	if has_stuck or has_stuck_in_air:
		return
	
	age += delta
	
	if is_floating:
		float_age += delta
		
		# Apply drift while floating
		global_position += float_drift * delta
		
		# Apply slight upward bias while floating
		velocity.y += -20.0 * delta
		global_position += velocity * delta
		
		# Check if floating duration is over - then stick in air
		if float_age >= float_duration:
			is_floating = false
			has_stuck_in_air = true
			velocity = Vector2.ZERO  # Stop all movement
			float_drift = Vector2.ZERO
	# Should not reach here anymore since decals stick in air
	
	# Fade out over lifetime - very slow fade for stuck decals
	if sprite:
		var alpha = max(0.0, 1.0 - (age / lifetime))
		sprite.modulate.a = alpha * fade_alpha_multiplier
	
	# Remove if lifetime exceeded
	if age >= lifetime:
		queue_free()

func _should_collide_with(body: Node) -> bool:
	# Floating blood decals only collide if they haven't stuck in air yet
	if has_stuck_in_air:
		return false
	return body is TileMap or body.is_in_group("walls") or body.is_in_group("ground") or body.is_in_group("colliders") or body.is_in_group("enemies") or body.is_in_group("player")

func _on_collision(body: Node) -> void:
	# Floating decals don't create additional decals on collision
	# They just stick to whatever they hit
	if not has_stuck_in_air:
		is_floating = false
		has_stuck_in_air = true
		velocity = Vector2.ZERO
		float_drift = Vector2.ZERO
