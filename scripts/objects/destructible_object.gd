extends CharacterBody2D

# Base class for destructible objects (barrel, box, vase)
# Handles damage, animations, and gravity like enemies

const GRAVITY: float = 900.0
var health: int
var max_health: int
var is_destroyed: bool = false
var damage_cooldown_timer: float = 0.0
const DAMAGE_COOLDOWN: float = 0.20
var initial_y_position: float = 0.0  # Store initial Y position

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Virtual method to be overridden by child classes
func get_max_health() -> int:
	return 2  # Default: 2 hits for barrel/box

func _ready() -> void:
	max_health = get_max_health()
	health = max_health
	
	# Store initial Y position to prevent vertical movement
	initial_y_position = global_position.y
	
	# Set up collision layers for destructible objects
	collision_layer = 4  # Destructible objects layer
	collision_mask = 1    # Player layer
	collision_mask += 2   # Enemy layer
	collision_mask += 4   # Other destructible objects
	collision_mask += 32  # World/ground layer
	
	# Initialize animated sprite
	if animated_sprite:
		animated_sprite.play("idle")
		animated_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	# Don't process physics for destroyed objects
	if is_destroyed:
		return
	
	# DISABLE GRAVITY COMPLETELY - no vertical movement at all
	# if not is_on_floor():
	# 	velocity.y += GRAVITY * delta
	
	# Apply friction to stop movement
	velocity.x = move_toward(velocity.x, 0, 100.0 * delta)
	
	# Force vertical velocity to zero before movement
	velocity.y = 0
	
	# Debug output
	if abs(velocity.y) > 0.1:
		print("DEBUG: Vertical velocity: ", velocity.y, " is_on_floor: ", is_on_floor())
	
	# Check for player collision
	move_and_slide()
	
	# Force vertical velocity to zero at end of physics process
	velocity.y = 0
	
	# Check if we're colliding with the player or enemies
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and (collider.is_in_group("player") or collider.is_in_group("enemies")):
			print("Destructible object colliding with character!")
			var push_direction = (global_position - collider.global_position).normalized()
			velocity.x = push_direction.x * 10.0  # Much smaller push force
			velocity.y = 0  # Disable vertical movement
			break
	
	# Cooldown countdown
	if damage_cooldown_timer > 0.0:
		damage_cooldown_timer -= delta
	
	# FINAL SAFEGUARD: Lock Y position to prevent any vertical movement
	global_position.y = initial_y_position

func set_knockback(horizontal_velocity: float, duration: float) -> void:
	# Only apply horizontal knockback, ignore vertical
	velocity.x = horizontal_velocity
	velocity.y = 0  # Force vertical velocity to zero

func take_damage(amount: int) -> void:
	take_damage_with_direction(amount, Vector2.ZERO)

func take_damage_with_direction(amount: int, bullet_direction: Vector2, bullet_position: Vector2 = Vector2.ZERO) -> void:
	if is_destroyed or damage_cooldown_timer > 0.0:
		return
	
	# Reduce health
	health = max(health - amount, 0)
	
	# Start damage cooldown
	damage_cooldown_timer = DAMAGE_COOLDOWN
	
	_create_dust_effect(bullet_position)
	
	# Flash effect
	_flash_white()
	
	# Apply knockback if not destroyed
	if not is_destroyed:
		var dir: float = 1.0
		if bullet_direction != Vector2.ZERO:
			dir = sign(bullet_direction.x)
		else:
			# Default knockback direction (random if no bullet direction)
			dir = 1.0 if randf() < 0.5 else -1.0
		
		velocity.x = dir * 200.0
		velocity.y = 0  # Force vertical velocity to zero
	
	# Check if object should be destroyed
	if health <= 0 and not is_destroyed:
		is_destroyed = true
		_play_break_animation()
	else:
		# Play damage animation
		_play_damage_animation()

func _create_dust_effect(hit_position: Vector2 = Vector2.ZERO) -> void:
	# Create dust particles at hit position
	var dust_scene = preload("res://scenes/objects/dust_splash.tscn")
	if dust_scene:
		var dust := dust_scene.instantiate()
		var scene := get_tree().current_scene
		if dust and scene:
			# Use hit position or object center
			var spawn_position := hit_position
			if spawn_position == Vector2.ZERO:
				spawn_position = global_position
			
			# Add some random offset
			var offset_x := randf_range(-4.0, 4.0)
			var offset_y := randf_range(-4.0, 4.0)
			dust.global_position = spawn_position + Vector2(offset_x, offset_y)
			
			# Set dust direction based on damage source
			dust.set_direction(Vector2.UP)  # Dust goes upward
			
			scene.add_child(dust)

func _flash_white() -> void:
	if animated_sprite:
		animated_sprite.modulate = Color(1, 1, 1)
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)

func _play_damage_animation() -> void:
	if animated_sprite and animated_sprite.sprite_frames.has_animation("damage"):
		animated_sprite.play("damage")

func _play_break_animation() -> void:
	if animated_sprite and animated_sprite.sprite_frames.has_animation("break"):
		animated_sprite.play("break")
	else:
		queue_free()

func _on_animation_finished() -> void:
	var anim = animated_sprite.animation
	
	if anim == "damage":
		# Return to idle after damage animation
		if animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")
	elif anim == "break":
		# Keep the broken object visible, don't remove it
		# Just stop the animation on the last frame
		is_destroyed = true
		# Disable collision so it doesn't interfere anymore
		collision_layer = 0
		collision_mask = 0

# Override this in child classes for different health values
func _get_health_value() -> int:
	return 2  # Default for barrel/box