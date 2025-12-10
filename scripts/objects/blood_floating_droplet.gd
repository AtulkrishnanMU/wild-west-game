extends "res://scripts/objects/particle.gd"

const BLOOD_DECAL_SCENE := preload("res://scenes/objects/blood_decal.tscn")

var float_duration: float = 0.0  # How long to move before sticking
var float_age: float = 0.0
var is_floating: bool = true
var float_drift: Vector2 = Vector2.ZERO
var has_stuck_in_air: bool = false

func _ready() -> void:
	# Override particle properties for floating blood
	particle_gravity = 0.0  # No gravity - stays in air
	lifetime = 6.0  # Longer lifetime for stuck particles
	fade_alpha_multiplier = 0.4  # Slower fade
	
	# Set random floating duration (0.3 seconds) - quick stick effect
	float_duration = 0.3
	
	# Set random drift for floating effect
	float_drift = Vector2(randf_range(-30, 30), randf_range(-20, 20))
	
	print("Floating droplet created at position: ", global_position, " with drift: ", float_drift, " duration: ", float_duration)
	
	super._ready()

func _setup_particle_appearance() -> void:
	# Set up floating blood droplet appearance - same size as regular droplets
	if sprite:
		var texture = ImageTexture.new()
		var image = Image.create(6, 6, false, Image.FORMAT_RGBA8)  # Same size as regular
		image.fill(Color.TRANSPARENT)
		
		# Generate lighter red shade for floating particles
		var red_value = randf_range(0.6, 0.8)        # Red channel: 60%-80% (lighter)
		var green_value = randf_range(0.0, 0.15)     # Green channel: 0%-15%
		var blue_value = randf_range(0.0, 0.1)       # Blue channel: 0%-10%
		
		# Create blood droplet - same size as regular
		var center = Vector2(3, 3)  # Same center as regular
		for x in range(6):
			for y in range(6):
				var dist = Vector2(x, y).distance_to(center)
				if dist < 2.5:  # Same radius as regular
					var alpha = 1.0 - (dist / 2.5)
					image.set_pixel(x, y, Color(red_value, green_value, blue_value, alpha * 0.8))  # Same alpha
		
		texture.set_image(image)
		sprite.texture = texture
		sprite.centered = true

func _physics_process(delta: float) -> void:
	if has_stuck or has_stuck_in_air:
		return
	
	age += delta
	
	if is_floating:
		float_age += delta
		
		# Apply drift while floating
		global_position += float_drift * delta
		
		# Apply slight upward bias while floating
		velocity.y += -30.0 * delta
		global_position += velocity * delta
		
		# Check if floating duration is over - then stick in air
		if float_age >= float_duration:
			is_floating = false
			has_stuck_in_air = true
			velocity = Vector2.ZERO  # Stop all movement
			float_drift = Vector2.ZERO
			print("Floating droplet stuck in air at position: ", global_position)
	else:
		# Should not reach here anymore since particles stick in air
		pass
	
	# Fade out over lifetime - very slow fade for stuck particles
	if sprite:
		var alpha = max(0.0, 1.0 - (age / lifetime))
		sprite.modulate.a = alpha * fade_alpha_multiplier
	
	# Remove if lifetime exceeded
	if age >= lifetime:
		queue_free()

func _should_collide_with(body: Node) -> bool:
	# Floating blood only collides if it hasn't stuck in air yet
	if has_stuck_in_air:
		return false
	return body is TileMap or body.is_in_group("walls") or body.is_in_group("ground") or body.is_in_group("enemies") or body.is_in_group("player")

func _on_collision(body: Node) -> void:
	# Only create decal if not stuck in air
	if not has_stuck_in_air:
		_create_blood_decal()

func _create_blood_decal() -> void:
	var decal = BLOOD_DECAL_SCENE.instantiate()
	if decal:
		# Add decal to the scene tree (not as child of droplet)
		get_tree().current_scene.add_child(decal)
		decal.global_position = global_position
		
		# Smaller scale for floating droplet decals
		decal.rotation = randf() * PI
		var scale_factor = randf_range(0.1, 0.3)  # Smaller than regular droplets
		decal.scale = Vector2(scale_factor, scale_factor)
