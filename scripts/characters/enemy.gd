class_name Enemy
extends CharacterBody2D
signal enemy_killed(enemy: Node)
var SPEED: float = 150.0
const GRAVITY: float = 900.0
const JUMP_SPEED: float = -360.0
const ATTACK_RANGE: float = 25.0          # Increased attack range
const DAMAGE_H_RANGE: float = 60.0        # Increased horizontal range
const DAMAGE_V_RANGE: float = 50.0        # Good vertical coverage (jumping, etc.)
const DAMAGE_COOLDOWN: float = 0.20       # Prevents insane damage spam
const ENEMY_KNOCKBACK_SPEED: float = 120.0
const MAX_HEALTH := 50

# Movement acceleration constants (for CharacterUtils)
const ACCELERATION = 800.0   # pixels per second squared (slower than player)
const DECELERATION = 1000.0  # pixels per second squared (stronger for quicker stops)
const AIR_ACCELERATION = 600.0  # reduced acceleration when in air
# Softer, less saturated green for final corpse tint
const CORPSE_DECAY_COLOR: Color = Color(0.62, 0.82, 0.68, 1.0)
const CASH_SCENE := preload("res://scenes/objects/cash.tscn")
const BLOOD_SCENE := preload("res://scenes/objects/blood_splash.tscn")
const AudioUtils = preload("res://scripts/utils/audio_utils.gd")
var ENEMY_DEATH_SOUND_1: AudioStream = null
var ENEMY_DEATH_SOUND_2: AudioStream = null
var ENEMY_HURT_SOUND: AudioStream = null
var BLOOD_SPLAT_SOUND: AudioStream = null
var RUNNING_SOUND: AudioStream = null
var health: int = MAX_HEALTH
var FAR_JUMP_DISTANCE: float = 140.0
var ATTACK_RANGE_DISTANCE: float = ATTACK_RANGE
var is_dead: bool = false
var has_been_visible_with_player := false
var is_active := false
var was_on_floor: bool = false  # Track if enemy was on floor in previous frame
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var slash_player: AudioStreamPlayer2D = $SlashEnemyPlayer
@onready var hit_player: AudioStreamPlayer2D = $HitEnemyPlayer
@onready var running_player: AudioStreamPlayer2D = get_node_or_null("RunningPlayer")
@onready var player: CharacterBody2D = get_parent().get_node("Player")
@onready var notifier: VisibleOnScreenNotifier2D = $VisibilityNotifier2D
@onready var player_notifier: VisibleOnScreenNotifier2D = player.get_node("VisibilityNotifier2D")
@onready var sprite_material: ShaderMaterial = animated_sprite.material
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_hitbox_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D
var is_attacking: bool = false
var damage_cooldown_timer: float = 0.0
var _hit_tween: Tween = null
var _decay_tween: Tween = null
var _knockback_timer: float = 0.0
var _attack_hitbox_base_position: Vector2 = Vector2.ZERO
var _player_in_attack_hitbox: bool = false
var _dead_collision_shape: CollisionShape2D = null

# Dead end detection variables
var _stuck_timer: float = 0.0
var _previous_position: Vector2 = Vector2.ZERO
var _stuck_threshold: float = 1.0  # Time in seconds before considering enemy stuck
var _leap_cooldown: float = 0.0
var _leap_cooldown_max: float = 2.0  # Cooldown between leap escapes

func _ready() -> void:
	randomize()
	SPEED = randf_range(150.0, 300.0)
	add_to_group("enemies")
	# Optimize material duplication: only duplicate if we don't have a unique instance
	if sprite_material:
		# Check if this is a shared material (from pool or scene)
		var current_material = animated_sprite.material
		if current_material == null or current_material == sprite_material:
			# Create unique material instance only when needed
			var unique_material = sprite_material.duplicate()
			animated_sprite.material = unique_material
			sprite_material = unique_material
		# Ensure decay tint starts as neutral white so alive enemies are unmodified
		sprite_material.set_shader_parameter("decay_tint", Color(1, 1, 1, 1))
	animated_sprite.animation_finished.connect(_on_animation_finished)
	ENEMY_DEATH_SOUND_1 = load("res://sounds/enemy-death.mp3")
	ENEMY_DEATH_SOUND_2 = load("res://sounds/enemy-death2.mp3")
	ENEMY_HURT_SOUND = load("res://sounds/hurt.mp3")
	BLOOD_SPLAT_SOUND = load("res://sounds/blood-splat.mp3")
	RUNNING_SOUND = load("res://sounds/running.mp3")
	if attack_hitbox:
		_attack_hitbox_base_position = attack_hitbox.position
		attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
		attack_hitbox.body_exited.connect(_on_attack_hitbox_body_exited)
	
	# Try to find dead collision shape
	_dead_collision_shape = get_node_or_null("DeadCollisionShape2D")
	
	# Initialize dead end detection
	_previous_position = global_position

func _physics_process(delta: float) -> void:

	# ─────────────────────────────────────────────
	# SCREEN-ACTIVATION: Enemy AI OFF until both are visible
	# ─────────────────────────────────────────────
	_check_visibility_activation()

	if not is_active:
		# Before activation: enemy stays idle + gravity works
		if not is_on_floor():
			velocity.y += GRAVITY * delta

		velocity.x = CharacterUtils.apply_smooth_movement(self, 0.0, SPEED, delta, ACCELERATION, DECELERATION, AIR_ACCELERATION)
		animated_sprite.play("IDLE")
		move_and_slide()
		
		# Check for dust even when inactive (falling, landing)
		if CharacterUtils.check_dust_landing(self, was_on_floor, velocity):
			CharacterUtils.create_dust_effect(self, 10.0, 6.0)
		
		was_on_floor = is_on_floor()  # Update floor tracking
		return
	# ─────────────────────────────────────────────


	if is_dead:
		# When dead, still fall with gravity but slowly come to a horizontal stop
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		velocity.x = CharacterUtils.apply_smooth_movement(self, 0.0, SPEED, delta, ACCELERATION, DECELERATION, AIR_ACCELERATION)
		move_and_slide()
		return

	if player == null:
		animated_sprite.play("IDLE")
		return

	# If the player is dead, stop attacking and stay idle
	if player.is_dead:
		is_attacking = false
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		velocity.x = CharacterUtils.apply_smooth_movement(self, 0.0, SPEED, delta, ACCELERATION, DECELERATION, AIR_ACCELERATION)
		animated_sprite.play("IDLE")
		move_and_slide()
		return

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Check for landing - create dust effect
	if CharacterUtils.check_dust_landing(self, was_on_floor, velocity):
		CharacterUtils.create_dust_effect(self, 10.0, 6.0)
	
	# Create dust while running on ground
	if CharacterUtils.check_running_dust(self, velocity):
		CharacterUtils.create_running_dust(self, 10.0, 3.0)
	
	was_on_floor = is_on_floor()  # Update floor tracking

	# Knockback window
	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		move_and_slide()
		return

	# Cooldown countdown
	if damage_cooldown_timer > 0.0:
		damage_cooldown_timer -= delta
	
	# Leap cooldown countdown
	if _leap_cooldown > 0.0:
		_leap_cooldown -= delta

	var to_player: Vector2 = player.global_position - global_position
	var distance_x: float = to_player.x
	var abs_distance: float = abs(distance_x)
	var direction: float = sign(distance_x)
	var vertical_distance: float = abs(player.global_position.y - global_position.y)

	# Avoid exact overlapping
	var overlap_x_threshold := 10.0
	var overlap_y_threshold := 24.0
	if vertical_distance < overlap_y_threshold and abs_distance > 1.0 and abs_distance < overlap_x_threshold:
		is_attacking = false
		var back_dir := -direction
		var back_target_speed = back_dir * SPEED * 0.8
		velocity.x = CharacterUtils.apply_smooth_movement(self, back_target_speed, SPEED * 0.8, delta, ACCELERATION, DECELERATION, AIR_ACCELERATION)
		if is_on_floor():
			animated_sprite.flip_h = direction < 0
			if animated_sprite.sprite_frames.has_animation("REV_WALK"):
				animated_sprite.play("REV_WALK")
				_play_running_sound()
			else:
				animated_sprite.play("RUN")
				_play_running_sound()
		move_and_slide()
		return

	# ── Movement & Attack Logic ──

	if not is_attacking:

		if abs_distance > ATTACK_RANGE_DISTANCE:
			# Far → chance to lunge jump
			if abs_distance > FAR_JUMP_DISTANCE and is_on_floor() and randf() < 0.3:
				velocity.y = JUMP_SPEED
				var jump_target_speed = direction * SPEED * 1.2
				velocity.x = CharacterUtils.apply_smooth_movement(self, jump_target_speed, SPEED * 1.2, delta, ACCELERATION, DECELERATION, AIR_ACCELERATION)
				animated_sprite.flip_h = direction < 0
				animated_sprite.play("JUMP")
			else:
				# Normal chase
				var target_speed = direction * SPEED
				velocity.x = CharacterUtils.apply_smooth_movement(self, target_speed, SPEED, delta, ACCELERATION, DECELERATION, AIR_ACCELERATION)
				animated_sprite.flip_h = direction < 0
				animated_sprite.play("RUN")
				_play_running_sound()

				# Check for dead end (stuck) situation
				_check_dead_end_detection(delta, direction)

				# Occasional running swing
				if randf() < 0.012:
					_start_attack_running()

		else:
			# Close enough → standing attack
			velocity.x = CharacterUtils.apply_smooth_movement(self, 0.0, SPEED, delta, ACCELERATION, DECELERATION, AIR_ACCELERATION)
			_stop_running_sound()
			_start_attack_close()

	else:
		# Handle attack movement (implemented by child classes)
		_get_attack_movement(delta)

	# Keep hitbox more centered for better coverage from both sides
	if attack_hitbox:
		var sign_x := -1.0 if animated_sprite.flip_h else 1.0
		# Position hitbox more centered instead of purely in front
		var offset_x = _attack_hitbox_base_position.x * sign_x * 0.5  # Less forward offset
		attack_hitbox.position = Vector2(offset_x, _attack_hitbox_base_position.y)

	move_and_slide()


func _start_attack_close() -> void:
	if is_attacking:
		return
	is_attacking = true
	var roll: float = randf()
	var attack_anim: String = "ATTACK1"
	if roll < 0.35:
		attack_anim = "ATTACK1"
	elif roll < 0.75:
		attack_anim = "ATTACK2"   # 40% chance
	else:
		attack_anim = "ATTACK3"
	if slash_player:
		AudioUtils.play_random_pitch(slash_player, 0.7, 1.6)
	animated_sprite.play(attack_anim)

func _start_attack_running() -> void:
	if is_attacking:
		return
	is_attacking = true
	if slash_player:
		slash_player.pitch_scale = randf_range(0.7, 1.6)
		slash_player.play()
	animated_sprite.play("ATTACK3")

func _on_animation_finished() -> void:
	var anim = animated_sprite.animation
	if anim.begins_with("ATTACK"):
		# Apply damage ONCE at the end of the attack if the player is in range
		if _is_player_in_attack_range():
			_apply_damage_to_player()
			damage_cooldown_timer = DAMAGE_COOLDOWN
		is_attacking = false
		if is_on_floor() and abs(velocity.x) < 10.0 and not is_dead:
			animated_sprite.play("IDLE")
	elif anim == "DEATH":
		# Hold on last DEATH frame
		animated_sprite.stop()
		animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count("DEATH") - 1

# Centered hitbox (no forward offset – enemy must be close)
func _is_player_in_attack_range() -> bool:
	return _player_in_attack_hitbox

func _apply_damage_to_player() -> void:
	if not player.has_method("take_damage"):
		return
	var dmg: int = 0
	match animated_sprite.animation:
		"ATTACK1":
			dmg = 12
		"ATTACK2":
			dmg = 20
		"ATTACK3":
			dmg = 10
		
	# Apply knockback to the player away from this enemy
	var dir: float = sign(player.global_position.x - global_position.x)
	player.velocity.x = dir * 150.0
	player.take_damage(dmg)

func _on_attack_hitbox_body_entered(body: Node) -> void:
	if body == player:
		_player_in_attack_hitbox = true

func _on_attack_hitbox_body_exited(body: Node) -> void:
	if body == player:
		_player_in_attack_hitbox = false

func take_damage(amount: int) -> void:
	take_damage_with_direction(amount, Vector2.ZERO)  # Default direction for non-bullet damage

func take_damage_with_direction(amount: int, bullet_direction: Vector2, bullet_position: Vector2 = Vector2.ZERO) -> void:
	# Reduce health
	health = max(health - amount, 0)
	print("DEBUG: Enemy took damage, health now: ", health, " (was ", health + amount, ")")
	
	# Spawn blood splash at bullet hit position with bullet direction
	CharacterUtils.apply_damage_with_effects(self, amount, BLOOD_SCENE, BLOOD_SPLAT_SOUND, null, bullet_direction, bullet_position)

	# FLASH REDDISH ON EVERY HIT (including killing blow)
	_flash_reddish()
	
	# Apply knockback if not dead
	if not is_dead:
		var dir: float = sign(global_position.x - player.global_position.x)
		CharacterUtils.apply_knockback(self, dir, ENEMY_KNOCKBACK_SPEED, 0.12)
	
	# Check if enemy died from this damage
	if health <= 0 and not is_dead:
		print("DEBUG: Enemy died! Emitting enemy_killed signal")
		# Death handling
		is_dead = true
		is_attacking = false
		velocity = Vector2.ZERO
		
		# Play death animation
		CharacterUtils.play_character_animation(animated_sprite, "DEATH")
		
		# Notify listeners (e.g., Endless mode) that this enemy was killed
		emit_signal("enemy_killed", self)
		# Remove from enemies group so player can no longer hit the corpse
		if is_in_group("enemies"):
			remove_from_group("enemies")
		# Switch to dead collision setup using call_deferred to avoid physics flushing errors
		call_deferred("_switch_to_dead_collision")
		# Face the player on death if possible
		if player:
			animated_sprite.flip_h = (player.global_position.x < global_position.x)
		_start_corpse_decay()
		if randf() < 0.2:
			_start_kill_slowmo()
		# Always drop cash on death, but defer to avoid physics flush issues
		call_deferred("_drop_cash_on_death")
		_play_enemy_death_sound()

func _start_corpse_decay() -> void:
	if _decay_tween and _decay_tween.is_valid():
		_decay_tween.kill()
	if sprite_material == null:
		return
	_decay_tween = create_tween()
	_decay_tween.set_trans(Tween.TRANS_SINE)
	_decay_tween.set_ease(Tween.EASE_IN_OUT)
	# Fade the dedicated decay_tint parameter toward green; base enemies stay unchanged.
	_decay_tween.tween_property(sprite_material, "shader_parameter/decay_tint", CORPSE_DECAY_COLOR, 10.0)


func _flash_reddish() -> void:
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()

	_hit_tween = create_tween()
	_hit_tween.set_trans(Tween.TRANS_LINEAR)
	
	# Store original material and temporarily disable shader
	var original_material = animated_sprite.material
	animated_sprite.material = null
	
	# Use reddish tint like player
	animated_sprite.modulate = Color(2, 0.4, 0.4)
	_hit_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.5)
	
	# Restore material after flash
	_hit_tween.tween_callback(func(): animated_sprite.material = original_material)


func _start_kill_slowmo() -> void:
	Engine.time_scale = 0.3
	# Camera zoom disabled - only slow-mo effect
	# _start_attack_zoom()
	_restore_time_scale_after_kill()


func _restore_time_scale_after_kill() -> void:
	await get_tree().create_timer(0.35).timeout
	Engine.time_scale = 1.0
	# Camera zoom disabled - no zoom to end
	# _end_attack_zoom()


func _start_attack_zoom() -> void:
	# Get the level script to control camera zoom
	var scene := get_tree().current_scene
	if scene and scene.has_method("start_attack_zoom"):
		scene.start_attack_zoom()


func _end_attack_zoom() -> void:
	# Get the level script to control camera zoom
	var scene := get_tree().current_scene
	if scene and scene.has_method("end_attack_zoom"):
		scene.end_attack_zoom()


func _switch_to_dead_collision() -> void:
	# Switch to dead collision setup
	var alive_collision_shape = get_node_or_null("CollisionShape2D")
	if alive_collision_shape:
		alive_collision_shape.disabled = true
	if _dead_collision_shape:
		_dead_collision_shape.disabled = false
		# Set dead collision to layer 8 (dead enemies layer)
		collision_layer = 8
	else:
		# Fallback: keep enemy layer for bullet collisions if no dead shape exists
		collision_layer = 2  # Keep enemy layer for bullet collisions

func _drop_cash_on_death() -> void:
	if CASH_SCENE == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var drop_count := randi_range(1, 3)
	for i in range(drop_count):
		var cash := CASH_SCENE.instantiate()
		if cash == null:
			continue
		var offset := Vector2(randf_range(-16.0, 16.0), randf_range(-4.0, 4.0))
		cash.global_position = global_position + offset
		scene.add_child(cash)


func _play_enemy_death_sound() -> void:
	AudioUtils.play_death_sound(ENEMY_DEATH_SOUND_1, ENEMY_DEATH_SOUND_2, global_position)


func _play_running_sound() -> void:
	AudioUtils.play_running_sound(running_player, RUNNING_SOUND)

func _stop_running_sound() -> void:
	AudioUtils.stop_running_sound(running_player)

func _play_blood_splat_sound() -> void:
	AudioUtils.play_blood_splat_sound(BLOOD_SPLAT_SOUND, global_position)

func _play_enemy_hurt_sound() -> void:
	AudioUtils.play_hurt_sound(ENEMY_HURT_SOUND, global_position)
	
func _check_visibility_activation():
	if has_been_visible_with_player:
		return  # Already activated once
	
	# If visibility notifiers are missing for some reason, fall back to always-active
	if notifier == null or player_notifier == null:
		has_been_visible_with_player = true
		is_active = true
		return
	
	# Check if both are on screen (original condition)
	var both_on_screen = notifier.is_on_screen() and player_notifier.is_on_screen()
	
	# Check if player and enemy are on the same horizontal level (line of sight)
	var same_horizontal_level = _is_same_horizontal_level()
	
	# Activate only if BOTH conditions are met: on screen AND same horizontal level
	if both_on_screen and same_horizontal_level:
		has_been_visible_with_player = true
		is_active = true

func _is_same_horizontal_level() -> bool:
	# Check if player and enemy are on the same horizontal level
	# Define a threshold for what counts as "same level" (in pixels)
	var horizontal_threshold = 50.0  # Adjust this value as needed
	
	var vertical_distance = abs(global_position.y - player.global_position.y)
	return vertical_distance <= horizontal_threshold

# Virtual method for attack movement - override in child classes
func _get_attack_movement(delta: float) -> void:
	# Default implementation: stay in place
	velocity.x = CharacterUtils.apply_smooth_movement(self, 0.0, SPEED, delta, ACCELERATION * 2.0, DECELERATION * 2.0, AIR_ACCELERATION)

# Dead end detection function
func _check_dead_end_detection(delta: float, direction: float) -> void:
	if not is_on_floor():
		_stuck_timer = 0.0  # Reset when not on floor
		_previous_position = global_position
		return
	
	# Check if enemy is stuck (not moving much)
	var movement_distance = global_position.distance_to(_previous_position)
	var movement_threshold = 5.0  # pixels per frame
	
	if movement_distance < movement_threshold:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0  # Reset if moving properly
	
	_previous_position = global_position
	
	# If stuck for too long and leap is ready, perform leap escape
	if _stuck_timer >= _stuck_threshold and _leap_cooldown <= 0.0:
		_perform_leap_escape(direction)

# Leap escape mechanics
func _perform_leap_escape(direction: float) -> void:
	# Reset stuck timer and set cooldown
	_stuck_timer = 0.0
	_leap_cooldown = _leap_cooldown_max
	
	# Apply leap velocity - forward and upward
	velocity.y = JUMP_SPEED * 0.8  # Slightly lower than normal jump for more forward momentum
	var leap_speed = direction * SPEED * 1.5  # Faster forward speed
	velocity.x = CharacterUtils.apply_smooth_movement(self, leap_speed, SPEED * 1.5, 0.016, ACCELERATION * 1.5, DECELERATION, AIR_ACCELERATION)
	
	# Update animation
	animated_sprite.flip_h = direction < 0
	animated_sprite.play("JUMP")
	
	# Create dust effect for the leap
	CharacterUtils.create_dust_effect(self, 12.0, 8.0)
	
	# Play leap sound (use running sound or add specific leap sound later)
	if running_player:
		AudioUtils.play_random_pitch(running_player, 1.2, 1.5)
