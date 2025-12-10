extends "res://scripts/characters/axe_enemy.gd"
class_name DeadAxeMan

func _ready() -> void:
	super._ready()
	# Don't auto-start - let IntroSequence control when to start
	pass

func _start_idle_then_die() -> void:
	# Set health to 0 and mark as dead but don't play death yet
	health = 0
	is_dead = false  # Keep as false initially to allow idle animation
	
	# Disable attack functionality immediately
	if attack_hitbox:
		attack_hitbox.monitoring = false
		attack_hitbox.monitorable = false
	
	# Play idle animation first and face left
	if animated_sprite and animated_sprite.sprite_frames.has_animation("IDLE"):
		animated_sprite.play("IDLE")
		animated_sprite.flip_h = true  # Face left
		print("Playing IDLE animation for DeadAxeMan")
	
	# Wait 1 second then die
	await get_tree().create_timer(1.0).timeout
	_force_death_state()

func _force_death_state() -> void:
	# Now mark as dead
	is_dead = true
	
	# Ensure attack hitbox stays disabled
	if attack_hitbox:
		attack_hitbox.monitoring = false
		attack_hitbox.monitorable = false
	
	# Stop any current animation first
	if animated_sprite:
		animated_sprite.stop()
	
	# Play death animation immediately and face left
	if animated_sprite and animated_sprite.sprite_frames.has_animation("DEATH"):
		animated_sprite.play("DEATH")
		animated_sprite.flip_h = true  # Face left
		print("Playing DEATH animation for DeadAxeMan")
	else:
		print("DEATH animation not found!")
	
	# Play death sound effect
	_play_enemy_death_sound()
	
	# Start corpse decay
	_start_corpse_decay()
	
	# Switch to dead collision
	_switch_to_dead_collision()
	
	# Remove from enemies group
	if is_in_group("enemies"):
		remove_from_group("enemies")

func _physics_process(delta: float) -> void:
	# Always enforce left-facing direction
	if animated_sprite:
		animated_sprite.flip_h = true
	
	# Only override physics when actually dead
	if is_dead:
		# When dead, still fall with gravity but slowly come to a horizontal stop
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		velocity.x = CharacterUtils.apply_smooth_movement(self, 0.0, SPEED, delta, ACCELERATION, DECELERATION, AIR_ACCELERATION)
		move_and_slide()
		
		# Ensure death animation stays on last frame
		if animated_sprite and animated_sprite.animation != "DEATH":
			animated_sprite.play("DEATH")
		return
	
	# Before death, disable all attack behavior
	is_attacking = false
	damage_cooldown_timer = 0.0
	
	# Apply basic physics but no movement
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	velocity.x = CharacterUtils.apply_smooth_movement(self, 0.0, 0.0, delta, ACCELERATION, DECELERATION, AIR_ACCELERATION)
	move_and_slide()

# Override all attack-related functions to do nothing
func _start_attack_close() -> void:
	pass  # Do nothing

func _start_attack_running() -> void:
	pass  # Do nothing

func _apply_damage_to_player() -> void:
	pass  # Do nothing - never damage player

func _get_attack_movement(delta: float) -> void:
	pass  # Do nothing - no attack movement
