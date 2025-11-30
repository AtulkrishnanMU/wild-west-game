class_name Player
extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const TILE_SIZE = 16
const MAX_JUMP_HEIGHT_TILES = 6
const MAX_JUMP_HEIGHT = MAX_JUMP_HEIGHT_TILES * TILE_SIZE  # 64 pixels
const MAX_JUMP_HOLD_TIME = 0.3  # seconds to reach max height
const AudioUtils = preload("res://scripts/utils/audio_utils.gd")
const BLOOD_SCENE := preload("res://scenes/objects/blood_splash.tscn")
const PLAYER_BULLET_SCENE := preload("res://scenes/objects/bullet.tscn")
const PLAYER_GUN_SHOT_SOUND := preload("res://sounds/gun-shot.mp3")
const PLAYER_RELOAD_SOUND_PATH := "res://sounds/reload.mp3"
const PLAYER_AIR_ATTACK_SOUND_PATH := "res://sounds/air-attack.mp3"
const PLAYER_MAG_SIZE: int = 10
const PLAYER_MAX_RELOADS: int = 5
const PLAYER_GUN_PICKUP_SCENE := preload("res://scenes/objects/gun.tscn")
signal health_changed(current: int, max: int)
signal cash_changed(current: int)
signal bullets_changed(current: int, max: int)

var PLAYER_DEATH_SOUND: AudioStream = null
var HURT_SOUND: AudioStream = null

const MAX_HEALTH := 200
var health: int = MAX_HEALTH
var cash: int = 0
var controls_enabled: bool = true
var was_on_floor: bool = false  # Track if player was on floor in previous frame

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var slash_player: AudioStreamPlayer2D = $SlashPlayer
@onready var hit_player: AudioStreamPlayer2D = $HitPlayer
@onready var camera: Camera2D = get_parent().get_node_or_null("Camera2D")
@onready var sword_hitbox: Area2D = $SwordHitbox
@onready var sword_hitbox_shape: CollisionShape2D = $SwordHitbox/CollisionShape2D
@onready var gun_sprite: Sprite2D = $GunSprite

# Add these variables near the top with the others
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
const PLAYER_KNOCKBACK_DURATION: float = 0.05  # seconds of forced knockback

var camera_shake_amount: float = 1.0
var camera_shake_time: float = 0.1
var _camera_shake_timer: float = 0.0
var _camera_original_offset: Vector2 = Vector2.ZERO
var _sword_hitbox_base_position: Vector2 = Vector2.ZERO
var _gun_base_position: Vector2 = Vector2.ZERO
var _gun_recoil_tween: Tween = null

# Gun reload state (similar to gun enemy)
var _player_shots_since_reload: int = 0
var _player_is_reloading: bool = false
var _player_reload_tween: Tween = null
var _player_reload_count: int = 0



var is_attacking := false
var is_dead := false
var has_gun: bool = false
var is_air_attacking := false
var air_attack_target: Node = null
var air_attack_speed: float = 1000.0
var air_attack_horizontal_distance: float = 700.0  # Constant horizontal range
var air_attack_tween: Tween = null

# Jump variables for variable height jumping
var is_jumping: bool = false
var jump_hold_time: float = 0.0
var jump_start_y: float = 0.0

# Jump buffer system
var jump_buffer_time: float = 0.0
const JUMP_BUFFER_WINDOW: float = 0.1  # 100ms buffer window

# Cursor management
var gun_cursor_texture: Texture2D = null
var normal_cursor_shape: Input.CursorShape = Input.CURSOR_ARROW
var _was_holding_gun: bool = false

# Reference to the current flicker tween so we can cancel/replace it
var _flicker_tween: Tween = null

func _ready() -> void:
	randomize()
	animated_sprite.animation_finished.connect(_on_animation_finished)
	emit_signal("health_changed", health, MAX_HEALTH)
	emit_signal("cash_changed", cash)
	if camera:
		_camera_original_offset = camera.offset
	if sword_hitbox:
		_sword_hitbox_base_position = sword_hitbox.position
	if gun_sprite:
		_gun_base_position = gun_sprite.position
	PLAYER_DEATH_SOUND = load("res://sounds/player-death.mp3")
	HURT_SOUND = load("res://sounds/hurt.mp3")
	
	
	# Load gun cursor texture
	gun_cursor_texture = load("res://assets/objects/gun_aim.png")

func _physics_process(delta: float) -> void:
	# Limit jump height to max
	if is_jumping:
		var current_jump_height = jump_start_y - global_position.y
		if current_jump_height >= MAX_JUMP_HEIGHT:
			# Reached max height, force fall
			velocity.y = max(velocity.y, 200.0)
			is_jumping = false
	
	# Check if landed
	if is_jumping and is_on_floor():
		is_jumping = false
	
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Check for landing - create dust effect
	if CharacterUtils.check_dust_landing(self, was_on_floor, velocity):
		print("Creating dust effect - landing velocity: ", velocity.y)
		CharacterUtils.create_dust_effect(self)
	
	# Reset jump state when landing
	if is_on_floor() and not was_on_floor:
		is_jumping = false
	
	# Create dust while running on ground
	if CharacterUtils.check_running_dust(self, velocity):
		CharacterUtils.create_running_dust(self)
	
	was_on_floor = is_on_floor()  # Update floor tracking

	# ——— DEAD ———
	if is_dead:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		move_and_slide()
		return


	# ——— KNOCKBACK OVERR — normal movement is blocked while knockback_timer > 0 ———
	if knockback_timer > 0.0:
		knockback_timer -= delta
		velocity.x = knockback_velocity.x   # keep applying knockback
		velocity.y += knockback_velocity.y  # optional small upward kick
		move_and_slide()
		if knockback_timer <= 0.0:
			knockback_velocity = Vector2.ZERO
		return  # skip normal input while being knocked back

	# ——— DISABLED CONTROLS (e.g. during intro) ———
	if not controls_enabled:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		move_and_slide()
		return

	# ——— INPUT (only runs when not in knockback) ———
	# Variable height jumping with buffer system
	var jump_pressed = Input.is_action_pressed("ui_accept")
	var jump_just_pressed = Input.is_action_just_pressed("ui_accept")
	
	# Update jump buffer
	if jump_just_pressed:
		jump_buffer_time = JUMP_BUFFER_WINDOW
	
	# Decay jump buffer
	if jump_buffer_time > 0.0:
		jump_buffer_time -= delta
	
	# Start jump (either immediate press or buffered)
	if (jump_just_pressed or jump_buffer_time > 0.0) and is_on_floor() and not is_attacking and not is_jumping:
		is_jumping = true
		jump_hold_time = 0.0
		jump_start_y = global_position.y
		velocity.y = JUMP_VELOCITY
		jump_buffer_time = 0.0  # Consume the buffer
	
	# Continue jumping while holding space (with max height limit)
	if is_jumping and jump_pressed and jump_hold_time < MAX_JUMP_HOLD_TIME:
		jump_hold_time += delta
		var height_reached = jump_start_y - global_position.y
		if height_reached < MAX_JUMP_HEIGHT:
			# Apply upward force to continue jump
			velocity.y = JUMP_VELOCITY * (1.0 - (jump_hold_time / MAX_JUMP_HOLD_TIME) * 0.5)
		else:
			# Max height reached, stop jumping
			is_jumping = false
	
	# Early release - cut jump short
	if is_jumping and not jump_pressed:
		is_jumping = false
		# Reduce upward velocity when releasing early
		if velocity.y < 0:
			velocity.y *= 0.5
	
	# Stop jumping when landing or hitting max height
	if is_jumping and (not is_on_floor() and (jump_start_y - global_position.y) >= MAX_JUMP_HEIGHT):
		is_jumping = false
	
	# Horizontal movement: only while right mouse button is held
	var direction: float = 0.0
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var mouse_pos: Vector2 = get_global_mouse_position()
		var dx: float = mouse_pos.x - global_position.x
		var dead_zone: float = 4.0
		if abs(dx) > dead_zone:
			direction = sign(dx)
			velocity.x = direction * SPEED
			animated_sprite.flip_h = direction < 0
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	# Attack input (left mouse / attack action)
	var attack_pressed: bool = Input.is_action_just_pressed("attack")
	var gun_attack_pressed: bool = has_gun and attack_pressed
	
	# Check for air attack (in air + left click)
	if attack_pressed and not is_on_floor() and not is_dead and not is_air_attacking and not has_gun:
		_start_air_attack()
	elif has_gun:
		# With gun: left-click shoots instead of melee; allow rapid fire on every click
		# Block shooting while the player gun is reloading
		if gun_attack_pressed and not is_dead and not _player_is_reloading:
			_start_gun_attack()
	else:
		# Without gun: normal melee attack
		if attack_pressed and not is_attacking and not is_dead:
			if direction != 0 or velocity.x != 0:
				_start_attack_moving()
			else:
				_start_attack_idle()
	
	# Gun aiming: rotate held gun toward mouse cursor
	if has_gun and gun_sprite:
		var to_mouse: Vector2 = get_global_mouse_position() - gun_sprite.global_position
		if to_mouse.length() > 0.0:
			var angle: float = to_mouse.angle()
			var target_angle: float = angle
			var facing_right: bool = to_mouse.x >= 0.0
			if facing_right:
				# Aim within [-90°, 90°] while facing right
				target_angle = clamp(angle, -PI / 2.0, PI / 2.0)
				gun_sprite.scale.x = 1.0
				animated_sprite.flip_h = false
			else:
				# Mirror horizontally when aiming left, still keep rotation in [-90°, 90°]
				var local_angle: float = angle + PI
				target_angle = clamp(local_angle, -PI / 2.0, PI / 2.0)
				gun_sprite.scale.x = -1.0
				animated_sprite.flip_h = true
			gun_sprite.rotation = target_angle
	
	# Update cursor based on gun state
	_update_cursor()

	# ——— ANIMATION CHOICE ———
	if is_air_attacking:
		animated_sprite.play("JUMP")  # Use jump animation during air attack
	elif is_attacking:
		# attack animations handled by animation_finished
		pass
	elif not is_on_floor():
		animated_sprite.play("JUMP")
	elif velocity.x != 0:
		animated_sprite.play("RUN")
	else:
		animated_sprite.play("IDLE")

	if _camera_shake_timer > 0.0:
		_camera_shake_timer -= delta
		if camera:
			var offset_x = randf_range(-camera_shake_amount, camera_shake_amount)
			var offset_y = randf_range(-camera_shake_amount, camera_shake_amount)
			camera.offset = _camera_original_offset + Vector2(offset_x, offset_y)
	else:
		if camera:
			camera.offset = _camera_original_offset
	# Keep sword hitbox in front of the player based on facing direction
	if sword_hitbox:
		var sign_x := -1.0 if animated_sprite.flip_h else 1.0
		sword_hitbox.position = Vector2(_sword_hitbox_base_position.x * sign_x, _sword_hitbox_base_position.y)

	# Update air attack if active
	_update_air_attack()

	move_and_slide()


# ——— ATTACK ———
func _start_attack_idle() -> void:
	is_attacking = true
	var anim = "ATTACK1" if randf() < 0.5 else "ATTACK2"
	if slash_player:
		AudioUtils.play_random_pitch(slash_player, 0.7, 1.6)
	animated_sprite.play(anim)

func _start_gun_attack() -> void:
	is_attacking = true
	animated_sprite.play("GUN_ATTACK")
	_fire_player_bullet()

func _start_attack_moving() -> void:
	is_attacking = true
	if slash_player:
		slash_player.pitch_scale = randf_range(0.7, 1.6)
		slash_player.play()
	animated_sprite.play("ATTACK3")


# ——— AIR ATTACK ———
func _start_air_attack() -> void:
	if is_air_attacking:
		return
	
	# Play air attack sound
	var air_attack_stream := load(PLAYER_AIR_ATTACK_SOUND_PATH)
	if air_attack_stream:
		var scene_for_sound := get_tree().current_scene
		if scene_for_sound:
			var audio := AudioStreamPlayer2D.new()
			audio.stream = air_attack_stream
			audio.position = global_position
			scene_for_sound.add_child(audio)
			AudioUtils.play_random_pitch(audio, 0.9, 1.1)
			audio.finished.connect(audio.queue_free)
	
	# Find nearest enemy (optional, for aiming)
	air_attack_target = _find_nearest_enemy()
	
	is_air_attacking = true
	is_attacking = false  # Override normal attack state
	
	# Always perform downward diagonal attack with constant horizontal distance
	var horizontal_direction: float = 1.0  # Default right
	
	# If enemy exists, aim toward them horizontally
	if air_attack_target != null:
		var to_enemy: Vector2 = air_attack_target.global_position - global_position
		horizontal_direction = sign(to_enemy.x)
	
	# Use player's current facing direction as fallback
	if animated_sprite.flip_h:
		horizontal_direction = -1.0
	
	# Calculate target position for straight diagonal movement
	var target_x: float = global_position.x + (horizontal_direction * air_attack_horizontal_distance)
	var target_y: float = global_position.y + (air_attack_horizontal_distance * 0.8)  # Downward diagonal
	var target_position: Vector2 = Vector2(target_x, target_y)
	
	# Face the attack direction
	animated_sprite.flip_h = horizontal_direction < 0
	
	# Create motion tween for timing control while maintaining physics
	if air_attack_tween and air_attack_tween.is_valid():
		air_attack_tween.kill()
	
	air_attack_tween = create_tween()
	air_attack_tween.set_trans(Tween.TRANS_LINEAR)
	air_attack_tween.set_ease(Tween.EASE_OUT)
	
	var duration: float = 0.3  # Fixed duration for consistent speed
	
	# Calculate constant velocity for perfect diagonal movement
	velocity.x = horizontal_direction * (air_attack_horizontal_distance / duration)
	velocity.y = (air_attack_horizontal_distance * 0.8) / duration
	
	# Use tween only for timing - physics will handle the movement
	air_attack_tween.tween_callback(_stop_air_attack_velocity).set_delay(duration)
	air_attack_tween.finished.connect(_on_air_attack_tween_finished)

func _find_nearest_enemy() -> Node:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node = null
	var nearest_distance: float = INF
	
	for enemy in enemies:
		if enemy.is_dead or not enemy.is_active:
			continue
		var distance: float = global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	
	return nearest

func _update_air_attack() -> void:
	if not is_air_attacking:
		return
	
	# Check if we've collided with any enemy during tween movement
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.is_dead or not enemy.is_active:
			continue
		var distance: float = global_position.distance_to(enemy.global_position)
		if distance < 40.0:  # Decreased collision threshold for more precise diagonal attack
			air_attack_target = enemy  # Set target for damage application
			_apply_air_attack_damage()
			_end_air_attack()
			return
	
	# End air attack if player touches ground
	if is_on_floor():
		_end_air_attack()

func _stop_air_attack_velocity() -> void:
	velocity = Vector2.ZERO

func _on_air_attack_tween_finished() -> void:
	_end_air_attack()

func _apply_air_attack_damage() -> void:
	if air_attack_target and air_attack_target.has_method("take_damage"):
		air_attack_target.take_damage(20)
		
		# Create impact effect
		if BLOOD_SCENE:
			var blood := BLOOD_SCENE.instantiate()
			var scene := get_tree().current_scene
			if blood and scene:
				blood.global_position = air_attack_target.global_position
				var facing_dir: Vector2 = (air_attack_target.global_position - global_position).normalized()
				blood.set_direction(facing_dir)
				scene.add_child(blood)
		
		# Camera shake for impact
		_start_camera_shake()

func _end_air_attack() -> void:
	is_air_attacking = false
	air_attack_target = null
	
	# Kill the tween if it's still running
	if air_attack_tween and air_attack_tween.is_valid():
		air_attack_tween.kill()
	air_attack_tween = null
	
	# Reset velocity to prevent any residual movement
	velocity = Vector2.ZERO


# ——— ANIMATION FINISHED ———
func _on_animation_finished() -> void:
	var anim = animated_sprite.animation

	if anim == "DEATH":
		animated_sprite.stop()
		animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count("DEATH") - 1
		return
	
	if anim == "ATTACK1" or anim == "ATTACK2" or anim == "ATTACK3":
		_apply_damage_to_enemies()
		is_attacking = false
	elif anim == "GUN_ATTACK":
		is_attacking = false


func _fire_player_bullet() -> void:
	if PLAYER_BULLET_SCENE == null or gun_sprite == null:
		return
	# Block shooting during reload
	if _player_is_reloading:
		return
	var bullet := PLAYER_BULLET_SCENE.instantiate()
	if bullet == null:
		return
	# Direction: from gun toward mouse at fire time
	var dir: Vector2 = Vector2.RIGHT
	var mouse_pos := get_global_mouse_position()
	if mouse_pos != gun_sprite.global_position:
		dir = (mouse_pos - gun_sprite.global_position).normalized()
	bullet.direction = dir
	# Spawn at muzzle point: small offset along gun's current forward direction
	var muzzle_offset: float = 16.0
	var spawn_pos: Vector2 = gun_sprite.global_position + dir * muzzle_offset
	bullet.global_position = spawn_pos
	bullet.rotation = dir.angle()
	# Tag shooter so bullet won’t damage the player
	bullet.shooter = self
	# Apply a small recoil on the gun in the opposite direction of the shot
	_play_player_gun_recoil(dir)
	# Play gun-shot sound at the gun position with random pitch
	if PLAYER_GUN_SHOT_SOUND:
		var scene_for_sound := get_tree().current_scene
		if scene_for_sound:
			var audio := AudioStreamPlayer2D.new()
			audio.stream = PLAYER_GUN_SHOT_SOUND
			audio.position = gun_sprite.global_position
			scene_for_sound.add_child(audio)
			AudioUtils.play_random_pitch(audio, 0.9, 1.2)
			audio.finished.connect(audio.queue_free)
	# Track number of shots and trigger reload / drop when magazine is empty
	_player_shots_since_reload += 1
	var remaining: int = max(PLAYER_MAG_SIZE - _player_shots_since_reload, 0)
	print("[PLAYER GUN] Shot fired. shots_since_reload=", _player_shots_since_reload, " remaining=", remaining, " reload_count=", _player_reload_count)
	emit_signal("bullets_changed", remaining, PLAYER_MAG_SIZE)
	if _player_shots_since_reload >= PLAYER_MAG_SIZE:
		print("[PLAYER GUN] Magazine empty. reload_count=", _player_reload_count, " max_reloads=", PLAYER_MAX_RELOADS)
		# Magazine empty: either start a reload or drop the gun if the NEXT reload would exceed the limit
		if _player_reload_count + 1 > PLAYER_MAX_RELOADS:
			print("[PLAYER GUN] Reload limit reached; dropping gun")
			_drop_player_gun()
		else:
			_start_player_reload_animation()
	# Finally, add the bullet to the scene
	var scene := get_tree().current_scene
	if scene:
		scene.add_child(bullet)


func _start_player_reload_animation() -> void:
	if gun_sprite == null:
		return
	# If already reloading, don't stack another reload
	if _player_is_reloading:
		return
	_player_is_reloading = true
	print("[PLAYER GUN] Starting reload animation. reload_count=", _player_reload_count, " shots_since_reload=", _player_shots_since_reload)
	# Round ended: clear all bullets from UI
	emit_signal("bullets_changed", 0, PLAYER_MAG_SIZE)
	# Stop any existing reload tween
	if _player_reload_tween and _player_reload_tween.is_valid():
		_player_reload_tween.kill()
	# Base the reload rotation on the current gun rotation
	var start_rotation: float = gun_sprite.rotation
	# Rotate about 20 degrees; flip sign when facing left so the motion feels natural
	var angle_offset: float = deg_to_rad(20.0)
	if animated_sprite and animated_sprite.flip_h:
		angle_offset = -angle_offset
	_player_reload_tween = create_tween()
	_player_reload_tween.tween_property(gun_sprite, "rotation", start_rotation + angle_offset, 0.08)
	_player_reload_tween.tween_property(gun_sprite, "rotation", start_rotation, 0.08)
	_player_reload_tween.finished.connect(_on_player_reload_finished)
	# Play reload sound at the gun position (loaded at runtime to avoid parse-time errors)
	var scene_for_sound := get_tree().current_scene
	if scene_for_sound and PLAYER_RELOAD_SOUND_PATH != "":
		var reload_stream := load(PLAYER_RELOAD_SOUND_PATH)
		if reload_stream:
			var audio := AudioStreamPlayer2D.new()
			audio.stream = reload_stream
			audio.position = gun_sprite.global_position
			scene_for_sound.add_child(audio)
			AudioUtils.play_random_pitch(audio, 0.95, 1.05)
			audio.finished.connect(audio.queue_free)


func _on_player_reload_finished() -> void:
	_player_is_reloading = false
	_player_reload_tween = null
	# Count this completed reload and reset magazine
	_player_reload_count += 1
	_player_shots_since_reload = 0
	print("[PLAYER GUN] Reload finished. reload_count=", _player_reload_count, " shots_since_reload=", _player_shots_since_reload)
	# Reload finished: refill magazine in UI
	emit_signal("bullets_changed", PLAYER_MAG_SIZE, PLAYER_MAG_SIZE)


func _drop_player_gun() -> void:
	# Gun is exhausted: hide it, drop a pickup on the ground, and revert to melee
	has_gun = false
	_player_is_reloading = false
	_player_shots_since_reload = 0
	print("[PLAYER GUN] Dropping gun. reload_count=", _player_reload_count)
	# Show an "OUT OF AMMO" popup above the player (smaller, slightly left)
	_spawn_floating_popup("OUT OF AMMO", Color(1.0, 0.4, 0.4), Vector2(-29, -22), 6)
	if gun_sprite:
		gun_sprite.visible = false
	# Clear bullets from UI
	emit_signal("bullets_changed", 0, PLAYER_MAG_SIZE)
	_update_cursor()
	# Spawn a ground gun pickup as if the player threw it away
	var scene := get_tree().current_scene
	if scene == null:
		return
	if PLAYER_GUN_PICKUP_SCENE == null:
		return
	var pickup := PLAYER_GUN_PICKUP_SCENE.instantiate()
	if pickup == null:
		return
	var drop_pos := global_position + Vector2(0.0, -12.0)
	if gun_sprite:
		drop_pos = gun_sprite.global_position
	pickup.global_position = drop_pos
	# This is a thrown-away gun: make it a visual dummy with a throw arc, not a pickup
	pickup.can_be_picked_up = false
	pickup.use_gravity = true
	var throw_dir := -1.0
	if animated_sprite and animated_sprite.flip_h:
		# Facing left → throw to the right
		throw_dir = 1.0
	# Softer arc: slight backwards throw, lower upward force
	pickup.initial_velocity = Vector2(throw_dir * 140.0, -180.0)
	scene.add_child(pickup)


func _play_player_gun_recoil(shot_dir: Vector2) -> void:
	if gun_sprite == null:
		return
	if _gun_recoil_tween and _gun_recoil_tween.is_valid():
		_gun_recoil_tween.kill()
	_gun_recoil_tween = create_tween()
	var recoil_distance := 4.0
	var back_pos := _gun_base_position - shot_dir.normalized() * recoil_distance
	_gun_recoil_tween.tween_property(gun_sprite, "position", back_pos, 0.04)
	_gun_recoil_tween.tween_property(gun_sprite, "position", _gun_base_position, 0.06)


# ——— DAMAGE ———
func take_damage(amount: int) -> void:
	if is_dead: return
	
	# Spawn blood splash at player position
	if BLOOD_SCENE:
		var blood := BLOOD_SCENE.instantiate()
		var scene := get_tree().current_scene
		if blood and scene:
			var offset := Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
			blood.global_position = global_position + offset
			var facing_dir := Vector2.LEFT if animated_sprite.flip_h else Vector2.RIGHT
			blood.set_direction(facing_dir)
			scene.add_child(blood)

	health = max(health - amount, 0)
	if hit_player:
		AudioUtils.play_random_pitch(hit_player, 0.7, 1.6)
	emit_signal("health_changed", health, MAX_HEALTH)

	if health <= 0:
		if not is_dead:
			is_dead = true
			is_attacking = false
			animated_sprite.play("DEATH")
			_play_player_death_sound()
	else:
		# Only visual feedback — everything else continues uninterrupted
		_flicker_red()
		if randf() < 0.1:
			_play_hurt_sound()


func add_cash(amount: int) -> void:
	if amount <= 0:
		return
	cash += amount
	emit_signal("cash_changed", cash)


func pickup_gun() -> void:
	if has_gun:
		return
	has_gun = true
	if gun_sprite:
		gun_sprite.visible = true
	# Reset magazine and reload state; new gun starts with fresh reloads
	_player_shots_since_reload = 0
	_player_reload_count = 0
	_player_is_reloading = false
	print("[PLAYER GUN] Gun picked up. reload_count reset to ", _player_reload_count)
	emit_signal("bullets_changed", PLAYER_MAG_SIZE, PLAYER_MAG_SIZE)
	_update_cursor()


# ——— RED FLICKER (2 fast flashes) ———
func _flicker_red() -> void:
	# Kill any previous flicker tween so rapid hits don't stack
	if _flicker_tween and _flicker_tween.is_valid():
		_flicker_tween.kill()

	_flicker_tween = create_tween()
	_flicker_tween.set_trans(Tween.TRANS_LINEAR)

	animated_sprite.modulate = Color.WHITE

	# Flash 1
	_flicker_tween.tween_property(animated_sprite, "modulate", Color(2, 0.4, 0.4), 0.07)
	_flicker_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.07)

	# Flash 2
	_flicker_tween.tween_property(animated_sprite, "modulate", Color(2, 0.4, 0.4), 0.07)
	_flicker_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.07)

func _apply_damage_to_enemies() -> void:
	if sword_hitbox == null:
		return
	var base_damage: int = 15
	var facing: int = -1 if animated_sprite.flip_h else 1
	var hit_something := false
	for body in sword_hitbox.get_overlapping_bodies():
		if not body.is_in_group("enemies"):
			continue
		if not body.has_method("take_damage"):
			continue
		
		# Check if enemy is on the same side the player is facing
		var to_enemy: Vector2 = body.global_position - global_position
		var enemy_direction: int = sign(to_enemy.x)
		
		# Only hit enemy if they're on the same side as player's facing direction
		if enemy_direction != facing:
			continue
		
		body.take_damage(base_damage)
		hit_something = true
		# Only hit each enemy once per attack resolution
	
	if hit_something:
		# Strong, satisfying self-knockback (horizontal only)
		var knockback_strength := 180.0
		knockback_velocity.x = -facing * knockback_strength
		# knockback_velocity.y = -60.0  # ← DELETE THIS LINE
		knockback_timer = PLAYER_KNOCKBACK_DURATION
		_start_camera_shake()


func _start_camera_shake() -> void:
	_camera_shake_timer = camera_shake_time


func _play_player_death_sound() -> void:
	if PLAYER_DEATH_SOUND == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var audio := AudioStreamPlayer2D.new()
	audio.stream = PLAYER_DEATH_SOUND
	audio.position = global_position
	scene.add_child(audio)
	AudioUtils.play_random_pitch(audio, 0.9, 1.1)
	audio.finished.connect(audio.queue_free)


func _play_hurt_sound() -> void:
	if HURT_SOUND == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var audio := AudioStreamPlayer2D.new()
	audio.stream = HURT_SOUND
	audio.position = global_position
	audio.pitch_scale = randf_range(0.9, 1.1)
	scene.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)


func _spawn_floating_popup(text: String, color: Color, offset: Vector2 = Vector2(0, -20), font_size: int = 8) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	var popup_root := Node2D.new()
	popup_root.position = global_position + offset
	scene.add_child(popup_root)

	var label := Label.new()
	label.text = text
	label.modulate = color
	var font := load("res://fonts/PixelOperator8.ttf")
	if font:
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", font_size)

	popup_root.add_child(label)

	var tween := get_tree().create_tween()
	# Popup: float up and fade over ~0.5 seconds
	tween.tween_property(popup_root, "position:y", popup_root.position.y - 20.0, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.finished.connect(popup_root.queue_free)




# ——— CURSOR MANAGEMENT ———
func _update_cursor() -> void:
	if has_gun and gun_cursor_texture:
		# Set custom cursor when holding gun
		Input.set_custom_mouse_cursor(gun_cursor_texture, Input.CURSOR_ARROW, Vector2(16, 16))
	else:
		# Reset to normal cursor when not holding gun
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
