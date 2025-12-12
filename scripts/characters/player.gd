class_name Player
extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const TILE_SIZE = 16
const MAX_JUMP_HEIGHT_TILES = 6
const MAX_JUMP_HEIGHT = MAX_JUMP_HEIGHT_TILES * TILE_SIZE  # 64 pixels
const MAX_JUMP_HOLD_TIME = 0.3  # seconds to reach max height

# Movement acceleration constants (for CharacterUtils)
const ACCELERATION = 1200.0  # pixels per second squared
const DECELERATION = 1500.0  # pixels per second squared (stronger for quicker stops)
const AIR_ACCELERATION = 800.0  # reduced acceleration when in air
const POPUP_FONT_SIZE = FontConfig.DEFAULT_POPUP_FONT_SIZE  # font size for floating popups
const COMBO_POPUP_HEIGHT = 60.0
# Popup height offsets to prevent overlapping (higher number = higher position)
const CASH_POPUP_HEIGHT = 0.0      # Default height for cash popups
const GUN_POPUP_HEIGHT = 15.0       # Height for gun-related popups
const HEALTH_POPUP_HEIGHT = 15.0    # Height for health gain popups
# Specific gun popup heights to prevent overlapping
const GUN_STORED_HEIGHT = 15.0      # "GUN STORED" popup
const MAX_BACKUP_HEIGHT = 25.0       # "MAX BACKUP\nREACHED" popup  
const BACKUP_EQUIPPED_HEIGHT = 40.0  # "BACKUP EQUIPPED" popup
const OUT_OF_AMMO_HEIGHT = 45.0      # "OUT OF AMMO" popup
const AudioUtils = preload("res://scripts/utils/audio_utils.gd")
const GunUtils = preload("res://scripts/utils/gun_utils.gd")

# Health color constants - should match level.gd constants
const HEALTH_HIGH_THRESHOLD := 0.6  # Above this = green
const HEALTH_LOW_THRESHOLD := 0.3   # Above this = yellow, below = red
const HEALTH_HIGH_COLOR := Color(0.2, 0.6, 0.2)    # Green (less bright)
const HEALTH_MEDIUM_COLOR := Color(0.95, 0.8, 0.2)  # Yellow
const HEALTH_LOW_COLOR := Color(0.95, 0.2, 0.2)    # Red
const HEALTH_HIGHLIGHT_COLOR := Color(1.0, 0.75, 0.8)  # Pink for healing highlights
const HEALTH_GAIN_SOUND := preload("res://sounds/health-gain.mp3")  # Health gain sound effect

# Health bar highlight variables
var _health_bar_highlight_tween: Tween = null
var _original_health_bar_color: Color = Color.WHITE
const BLOOD_SCENE := preload("res://scenes/objects/blood_splash.tscn")
const PLAYER_BULLET_SCENE := preload("res://scenes/objects/bullet.tscn")
const PLAYER_GUN_SHOT_SOUND := preload("res://sounds/gun-shot.mp3")
const PLAYER_RELOAD_SOUND := preload("res://sounds/reload.mp3")
const PLAYER_AIR_ATTACK_SOUND := preload("res://sounds/air-attack.mp3")
const PLAYER_BAT_THROW_SOUND := preload("res://sounds/slash.mp3")
const PLAYER_DEATH_SOUND := preload("res://sounds/player-death.mp3")
const HURT_SOUND := preload("res://sounds/hurt.mp3")
const BLOOD_SPLAT_SOUND := preload("res://sounds/blood-splat.mp3")
const RUNNING_SOUND := preload("res://sounds/running.mp3")
const PLAYER_BAT_SCENE := preload("res://scenes/objects/thrown_bat.tscn")
const PLAYER_MAG_SIZE: int = 10
const PLAYER_MAX_RELOADS: int = 5
const PLAYER_GUN_FIRE_COOLDOWN: float = 0.2  # Cooldown between bullet fires
const PLAYER_GUN_PICKUP_SCENE := preload("res://scenes/objects/gun.tscn")
signal health_changed(current: int, max: int)
signal cash_changed(current: int)
signal bullets_changed(current: int, max: int)
signal reloads_changed(current: int, max: int)
signal combo_streak_changed(current: int)

# Combo system variables
var combo_streak: int = 0
var _last_damage_time: float = 0.0
var _combo_active: bool = false
var _combo_timer: Timer = null
var _combo_duration: float = 5.0  # Seconds before combo expires

# Performance optimization: cached audio streams to avoid repeated loading
var running_sound_player: AudioStreamPlayer2D = null
var _air_attack_sound_cache: AudioStream = null
var _reload_sound_cache: AudioStream = null
var _bat_throw_sound_cache: AudioStream = null

const MAX_HEALTH := 200
var health: int = MAX_HEALTH
var cash: int = 0
var controls_enabled: bool = true
var was_on_floor: bool = false  # Track if player was on floor in previous frame

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var slash_player: AudioStreamPlayer2D = $SlashPlayer
@onready var hit_player: AudioStreamPlayer2D = $HitPlayer
@onready var running_player: AudioStreamPlayer2D = get_node_or_null("RunningPlayer")
@onready var camera: Camera2D = get_parent().get_node_or_null("Camera2D")
@onready var sword_hitbox: Area2D = $SwordHitbox
@onready var sword_hitbox_shape: CollisionShape2D = $SwordHitbox/CollisionShape2D
@onready var gun_sprite: Sprite2D = $GunSprite
@onready var bat_sprite: Sprite2D = $BatSprite

# Add this variable near the top with the others
var _air_attack_finished_mid_air: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
const PLAYER_KNOCKBACK_DURATION: float = 0.05  # seconds of forced knockback

var camera_shake_amount: float = 1.0
var camera_shake_time: float = 0.1
var _camera_shake_timer: float = 0.0
var _camera_original_offset: Vector2 = Vector2.ZERO
var _sword_hitbox_base_position: Vector2 = Vector2.ZERO
var _gun_base_position: Vector2 = Vector2.ZERO
var _bat_base_position: Vector2 = Vector2.ZERO
var _gun_recoil_tween: Tween = null
var _bat_swing_tween: Tween = null
var _bat_aim_tween: Tween = null

# Gun reload state (similar to gun enemy)
var _player_shots_since_reload: int = 0
var _player_is_reloading: bool = false
var _player_reload_tween: Tween = null
var _player_reload_count: int = 0
var _gun_fire_cooldown: float = 0.0  # Cooldown between bullet fires



var is_attacking := false
var is_dead := false
var has_gun: bool = false
var has_bat: bool = true  # Player always has bat for normal attacks
var is_air_attacking := false
var air_attack_target: Node = null
var air_attack_speed: float = 1000.0
var air_attack_horizontal_distance: float = 500.0  # Constant horizontal range
var air_attack_tween: Tween = null
var _air_attack_just_ended := false  # Prevent getting stuck in jump animation
var _air_attack_cooldown := 0.0
var _force_idle_after_air_attack := false  # Persistent flag to prevent override
var _air_attack_ending := false  # Prevent multiple calls to _end_air_attack

# Bat throw system
var _bat_thrown: bool = false
var _thrown_bat: Node2D = null

# Backup weapon system
var backup_gun_data: Dictionary = {}
var has_backup_gun: bool = false

# Current equipped weapon tracking
var current_equipped_weapon: String = "bat"  # "bat" or "gun"

# Jump variables for variable height jumping
var is_jumping: bool = false
var jump_hold_time: float = 0.0
var jump_start_y: float = 0.0

# Jump buffer system
var jump_buffer_time: float = 0.0
const JUMP_BUFFER_WINDOW: float = 0.1  # 100ms buffer window

# Wall jump variables
var is_wall_jumping: bool = false
var wall_jump_direction: float = 0.0
const WALL_JUMP_HORIZONTAL_VELOCITY: float = 350.0
const WALL_JUMP_VERTICAL_VELOCITY: float = -300.0
var last_wall_jump_time: float = 0.0
const WALL_JUMP_COOLDOWN: float = 0.2  # Prevent immediate re-jumps
var consecutive_wall_jumps: int = 0  # Track consecutive wall jumps
const MAX_CONSECUTIVE_WALL_JUMPS: int = 4  # Maximum allowed consecutive wall jumps

# Cursor management
var gun_cursor_texture: Texture2D = null
var normal_cursor_shape: Input.CursorShape = Input.CURSOR_ARROW
var _was_holding_gun: bool = false

# Reference to the current flicker tween so we can cancel/replace it
var _flicker_tween: Tween = null

# Performance optimization: cached enemy references
var _cached_enemies: Array[Node] = []
var _enemy_cache_update_timer: float = 0.0
const ENEMY_CACHE_UPDATE_INTERVAL: float = 0.1  # Update cache every 100ms
# Performance optimization: track connected enemies to avoid redundant checks
var _connected_enemies: Array[Node] = []
# Performance optimization: air attack state tracking
var _air_attack_collision_threshold_sq: float = 40.0 * 40.0  # Pre-calculated threshold
var _air_attack_check_timer: float = 0.0  # Timer to reduce check frequency
const AIR_ATTACK_CHECK_INTERVAL: float = 0.02  # Check every 20ms instead of every frame

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
	if bat_sprite:
		_bat_base_position = bat_sprite.position
	
	# Setup combo timer
	_setup_combo_timer()
	
	# Cache audio streams for performance (now using preloaded constants)
	_air_attack_sound_cache = PLAYER_AIR_ATTACK_SOUND
	_reload_sound_cache = PLAYER_RELOAD_SOUND
	_bat_throw_sound_cache = PLAYER_BAT_THROW_SOUND
	
	
	# Load gun cursor texture
	gun_cursor_texture = load("res://assets/objects/gun_aim.png")

func _physics_process(delta: float) -> void:
	# Update enemy cache periodically (optimized)
	_update_enemy_cache(delta)
	
	# Handle core physics and states
	_handle_physics(delta)
	
	# Early returns for special states
	if _should_skip_normal_movement():
		_handle_special_movement(delta)
		return
	
	# Handle normal player input and movement
	_handle_movement_input(delta)
	_handle_combat_input()
	_handle_weapon_systems()
	_handle_animation_and_effects()
	
	# Final physics update
	move_and_slide()

func _handle_physics(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Handle jump mechanics
	_handle_jump_mechanics(delta)
	
	# Handle landing and dust effects
	_handle_landing_effects()

func _handle_jump_mechanics(delta: float) -> void:
	# Limit jump height to max
	if is_jumping:
		var current_jump_height = jump_start_y - global_position.y
		if current_jump_height >= MAX_JUMP_HEIGHT:
			velocity.y = max(velocity.y, 200.0)
			is_jumping = false
	
	# Check if landed
	if is_jumping and is_on_floor():
		is_jumping = false

func _handle_landing_effects() -> void:
	# Check for landing - create dust effect
	if CharacterUtils.check_dust_landing(self, was_on_floor, velocity):
		print("Creating dust effect - landing velocity: ", velocity.y)
		CharacterUtils.create_dust_effect(self)
	
	# Reset jump state when landing
	if is_on_floor() and not was_on_floor:
		is_jumping = false
		is_wall_jumping = false
		consecutive_wall_jumps = 0
		_air_attack_just_ended = false
		_force_idle_after_air_attack = false
		_air_attack_finished_mid_air = false
	
	# Create dust while running on ground
	if CharacterUtils.check_running_dust(self, velocity):
		CharacterUtils.create_running_dust(self)
	
	was_on_floor = is_on_floor()

func _should_skip_normal_movement() -> bool:
	return is_dead or knockback_timer > 0.0 or not controls_enabled

func _handle_special_movement(delta: float) -> void:
	if is_dead:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	elif knockback_timer > 0.0:
		knockback_timer -= delta
		velocity.x = knockback_velocity.x
		velocity.y += knockback_velocity.y
		if knockback_timer <= 0.0:
			knockback_velocity = Vector2.ZERO
	elif not controls_enabled:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	move_and_slide()

func _handle_movement_input(delta: float) -> void:
	# Variable height jumping with buffer system
	var jump_pressed = Input.is_action_pressed("ui_accept")
	var jump_just_pressed = Input.is_action_just_pressed("ui_accept")
	
	# Update jump buffer
	if jump_just_pressed:
		jump_buffer_time = JUMP_BUFFER_WINDOW
	
	# Decay jump buffer
	if jump_buffer_time > 0.0:
		jump_buffer_time -= delta
	
	# Update wall jump cooldown
	if last_wall_jump_time > 0.0:
		last_wall_jump_time -= delta
	
	# Handle jumping
	_handle_jumping(jump_just_pressed)
	
	# Handle wall jumping
	_handle_wall_jumping(jump_just_pressed)
	
	# Handle horizontal movement
	_handle_horizontal_movement()

func _handle_jumping(jump_just_pressed: bool) -> void:
	if (jump_just_pressed or jump_buffer_time > 0.0) and is_on_floor() and not is_attacking and not is_jumping:
		_force_idle_after_air_attack = false
		_air_attack_finished_mid_air = false
		_air_attack_just_ended = false
		is_jumping = true
		jump_hold_time = 0.0
		jump_start_y = global_position.y
		velocity.y = JUMP_VELOCITY
		jump_buffer_time = 0.0
	
	# Continue jumping while holding space
	if is_jumping and Input.is_action_pressed("ui_accept") and jump_hold_time < MAX_JUMP_HOLD_TIME:
		jump_hold_time += get_physics_process_delta_time()
		var height_reached = jump_start_y - global_position.y
		if height_reached < MAX_JUMP_HEIGHT:
			velocity.y = JUMP_VELOCITY * (1.0 - (jump_hold_time / MAX_JUMP_HOLD_TIME) * 0.5)
		else:
			is_jumping = false
	
	# Early release - cut jump short
	if is_jumping and not Input.is_action_pressed("ui_accept"):
		is_jumping = false
		if velocity.y < 0:
			velocity.y *= 0.5

func _handle_wall_jumping(jump_just_pressed: bool) -> void:
	if jump_just_pressed and not is_on_floor() and not is_attacking and last_wall_jump_time <= 0.0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var wall_dir = _get_wall_direction()
		if wall_dir != 0.0 and consecutive_wall_jumps < MAX_CONSECUTIVE_WALL_JUMPS:
			is_wall_jumping = true
			wall_jump_direction = wall_dir
			velocity.x = wall_jump_direction * WALL_JUMP_HORIZONTAL_VELOCITY
			velocity.y = WALL_JUMP_VERTICAL_VELOCITY
			last_wall_jump_time = WALL_JUMP_COOLDOWN
			jump_buffer_time = 0.0
			consecutive_wall_jumps += 1
			animated_sprite.flip_h = wall_jump_direction < 0

func _handle_horizontal_movement() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var dx: float = mouse_pos.x - global_position.x
	var dead_zone: float = 4.0
	
	# Mouse-facing logic
	if abs(dx) > dead_zone and not is_air_attacking:
		animated_sprite.flip_h = dx < 0
	
	# Horizontal movement: only while right mouse button is held
	var direction: float = 0.0
	var target_speed: float = 0.0
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_force_idle_after_air_attack = false
		if abs(dx) > dead_zone:
			direction = sign(dx)
			target_speed = direction * SPEED
		else:
			target_speed = 0.0
	else:
		target_speed = 0.0
	
	# Apply smooth acceleration/deceleration
	if is_wall_jumping:
		var wall_jump_acceleration = AIR_ACCELERATION * 0.7
		velocity.x = CharacterUtils.apply_smooth_movement(self, target_speed, SPEED, get_physics_process_delta_time(), wall_jump_acceleration, DECELERATION, AIR_ACCELERATION)
	else:
		velocity.x = CharacterUtils.apply_smooth_movement(self, target_speed, SPEED, get_physics_process_delta_time(), ACCELERATION, DECELERATION, AIR_ACCELERATION)

func _handle_combat_input() -> void:
	var attack_pressed: bool = Input.is_action_just_pressed("attack")
	
	# Don't process attacks if weapon menu is open
	var weapon_menu = get_tree().get_first_node_in_group("weapon_menu")
	if weapon_menu and weapon_menu.is_menu_open:
		return
	
	var gun_attack_pressed: bool = current_equipped_weapon == "gun" and has_gun and attack_pressed
	var bat_throw_pressed: bool = false
	
	# Only check for bat_throw action if it exists in InputMap
	if InputMap.has_action("bat_throw"):
		bat_throw_pressed = Input.is_action_just_pressed("bat_throw")
	
	# Handle bat throw inputs
	_handle_bat_throw_inputs(attack_pressed, bat_throw_pressed)
	
	# Handle normal attacks
	_handle_normal_attacks(attack_pressed, gun_attack_pressed)

func _handle_bat_throw_inputs(attack_pressed: bool, bat_throw_pressed: bool) -> void:
	# Keyboard bat throw
	if bat_throw_pressed and current_equipped_weapon == "bat" and has_bat and not is_dead and not is_attacking and not is_air_attacking and not _bat_thrown:
		print("Keyboard bat throw triggered!")
		_start_bat_throw()
	
	# Shift + Click bat throw
	if attack_pressed and Input.is_key_pressed(KEY_SHIFT) and current_equipped_weapon == "bat" and has_bat and not is_dead and not is_attacking and not is_air_attacking and not _bat_thrown:
		print("Shift+Click bat throw triggered!")
		_start_bat_throw()

func _handle_normal_attacks(attack_pressed: bool, gun_attack_pressed: bool) -> void:
	# Normal bat attack
	if current_equipped_weapon == "bat" and has_bat and attack_pressed and not is_dead and not is_attacking and not is_air_attacking and not _bat_thrown:
		var direction = 0.0
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			var mouse_pos = get_global_mouse_position()
			var dx = mouse_pos.x - global_position.x
			if abs(dx) > 4.0:
				direction = sign(dx)
		
		if direction != 0 or velocity.x != 0:
			_start_attack_moving()
		else:
			_start_attack_idle()
	
	# Air attack
	if attack_pressed and not is_on_floor() and not is_dead and not is_air_attacking and current_equipped_weapon == "bat" and has_bat and not _bat_thrown:
		_start_air_attack()
	
	# Gun attack
	elif current_equipped_weapon == "gun" and has_gun:
		if gun_attack_pressed and not is_dead and not _player_is_reloading and _gun_fire_cooldown <= 0.0:
			_start_gun_attack()

func _handle_weapon_systems() -> void:
	# Gun aiming
	if current_equipped_weapon == "gun" and has_gun and gun_sprite and not is_air_attacking:
		_handle_gun_aiming()
	
	# Update bat aiming
	_update_bat_aim()
	
	# Update cursor based on gun state
	_update_cursor()
	
	# Update weapon visibility based on current weapon
	_update_weapon_visibility()

func _handle_gun_aiming() -> void:
	var to_mouse: Vector2 = get_global_mouse_position() - gun_sprite.global_position
	if to_mouse.length() <= 0.0:
		return
	
	var angle: float = to_mouse.angle()
	var target_angle: float = angle
	var facing_right: bool = to_mouse.x >= 0.0
	
	if facing_right:
		target_angle = clamp(angle, -PI / 2.0, PI / 2.0)
		gun_sprite.scale.x = 1.0
		animated_sprite.flip_h = false
		gun_sprite.position = _gun_base_position
	else:
		gun_sprite.scale.x = -1.0
		animated_sprite.flip_h = true
		gun_sprite.position = _gun_base_position + Vector2(-8.0, 0.0)
		
		# Better angle calculation for left-facing
		if angle >= 0:
			target_angle = -(PI - angle)
		else:
			target_angle = -(-PI - angle)
		
		target_angle = clamp(target_angle, -PI / 2.0, PI / 2.0)
	
	gun_sprite.rotation = target_angle

func _handle_animation_and_effects() -> void:
	# Update air attack
	_update_air_attack()
	
	# Update air attack cooldown
	if _air_attack_cooldown > 0.0:
		_air_attack_cooldown -= get_physics_process_delta_time()
		if _air_attack_cooldown <= 0.0:
			_air_attack_just_ended = false
			_force_idle_after_air_attack = false

	# Update gun fire cooldown
	if _gun_fire_cooldown > 0.0:
		_gun_fire_cooldown -= get_physics_process_delta_time()
	
	# Camera shake
	_handle_camera_shake()
	
	# Sword hitbox positioning
	_update_sword_hitbox()
	
	# Animation selection
	_update_animation()

func _handle_camera_shake() -> void:
	if _camera_shake_timer > 0.0:
		_camera_shake_timer -= get_physics_process_delta_time()
		if camera:
			var offset_x = randf_range(-camera_shake_amount, camera_shake_amount)
			var offset_y = randf_range(-camera_shake_amount, camera_shake_amount)
			camera.offset = _camera_original_offset + Vector2(offset_x, offset_y)
	else:
		if camera:
			camera.offset = _camera_original_offset

func _update_sword_hitbox() -> void:
	if sword_hitbox:
		var sign_x := -1.0 if animated_sprite.flip_h else 1.0
		sword_hitbox.position = Vector2(_sword_hitbox_base_position.x * sign_x, _sword_hitbox_base_position.y)

func _update_animation() -> void:
	if is_air_attacking:
		animated_sprite.play("AIR_ATTACK")
	elif is_attacking:
		pass  # handled by animation_finished
	elif _air_attack_finished_mid_air:
		pass  # stay on last frame
	elif _force_idle_after_air_attack:
		if current_equipped_weapon == "gun" and has_gun:
			animated_sprite.play("GUN_IDLE")
		else:
			animated_sprite.play("IDLE")
		_stop_running_sound()
	elif is_wall_jumping:
		if current_equipped_weapon == "gun" and has_gun:
			animated_sprite.play("GUN_JUMP")
		else:
			animated_sprite.play("JUMP")
		_stop_running_sound()
	elif not is_on_floor() and not _air_attack_just_ended:
		if current_equipped_weapon == "gun" and has_gun:
			animated_sprite.play("GUN_JUMP")
		else:
			animated_sprite.play("JUMP")
		_stop_running_sound()
	elif velocity.x != 0:
		_force_idle_after_air_attack = false
		_air_attack_finished_mid_air = false
		if current_equipped_weapon == "gun" and has_gun:
			animated_sprite.play("GUN_RUN")
		else:
			animated_sprite.play("RUN")
		_play_running_sound()
	else:
		if current_equipped_weapon == "gun" and has_gun:
			animated_sprite.play("GUN_IDLE")
		else:
			animated_sprite.play("IDLE")
		_stop_running_sound()

func _update_weapon_visibility() -> void:
	# Hide both weapons by default (but only if not currently swinging/attacking)
	if gun_sprite:
		gun_sprite.visible = false
	# We won't forcibly hide the bat if an attack is in progress or an air attack is active.
	if bat_sprite and not is_attacking and not is_air_attacking:
		bat_sprite.visible = false

	# Show appropriate weapon based on currently equipped weapon
	if current_equipped_weapon == "gun" and has_gun and gun_sprite:
		gun_sprite.visible = true
	elif current_equipped_weapon == "bat" and has_bat and not _bat_thrown:
		# Show bat when not in air attack OR during active melee attack
		if bat_sprite:
			# Bat must be visible during melee attack. Let attack code control visibility.
			if is_attacking or not is_air_attacking:
				bat_sprite.visible = true

func _update_bat_aim() -> void:
	if not bat_sprite or not has_bat or current_equipped_weapon == "gun" or is_air_attacking or is_attacking:
		return

	var to_mouse := get_global_mouse_position() - bat_sprite.global_position
	if to_mouse.length() <= 0.0:
		return

	var facing_right := to_mouse.x >= 0.0
	var target_rot := -PI/2 if facing_right else 0.0  # -90° when right, 0° when left
	var target_pos := _bat_base_position  # Always use base position, no left offset

	# Player flips like normal, but bat DOES NOT flip horizontally
	animated_sprite.flip_h = not facing_right
	bat_sprite.flip_h = false

	# Kill old tween
	if _bat_aim_tween and _bat_aim_tween.is_valid():
		_bat_aim_tween.kill()

	_bat_aim_tween = create_tween()
	_bat_aim_tween.set_trans(Tween.TRANS_CUBIC)
	_bat_aim_tween.set_ease(Tween.EASE_IN_OUT)

	# Smooth aim
	_bat_aim_tween.tween_property(bat_sprite, "rotation", target_rot, 0.05)
	_bat_aim_tween.parallel().tween_property(bat_sprite, "position", target_pos, 0.05)


# ——— ATTACK ———
func _start_attack_idle() -> void:
	is_attacking = true
	var anim = "ATTACK1" if randf() < 0.5 else "ATTACK2"
	if slash_player:
		AudioUtils.play_random_pitch(slash_player, 0.7, 1.6)
	animated_sprite.play(anim)
	_show_bat_and_swing()

func _start_gun_attack() -> void:
	is_attacking = true
	animated_sprite.play("GUN_ATTACK")
	_fire_player_bullet()
	_gun_fire_cooldown = PLAYER_GUN_FIRE_COOLDOWN  # Set cooldown after firing

func _start_attack_moving() -> void:
	is_attacking = true
	if slash_player:
		slash_player.pitch_scale = randf_range(0.7, 1.6)
		slash_player.play()
	animated_sprite.play("ATTACK3")
	_show_bat_and_swing()


func _show_bat_and_swing() -> void:
	if not bat_sprite:
		return

	bat_sprite.visible = true

	# Determine facing from cursor like the aim code
	var to_mouse := get_global_mouse_position() - bat_sprite.global_position
	var facing_right := to_mouse.x >= 0.0
	var fm := 1 if facing_right else -1

	# Start rotation (rest pose)
	var rest_rot := -PI/2 if facing_right else 0.0  # -90° when right, 0° when left
	bat_sprite.rotation = rest_rot

	bat_sprite.flip_h = false  # IMPORTANT: no horizontal flip

	# Base position
	var base_pos := _bat_base_position

	# Swing arc positions
	var windup_pos := base_pos + Vector2(-4 * fm, -2)
	var hit_pos := base_pos + Vector2(8 * fm, 4)
	var follow_pos := base_pos + Vector2(10 * fm, 5)
	var end_pos := base_pos

	# --- ROTATION ARC (FULL 180° SWING) ---
	var windup_rot := rest_rot + deg_to_rad(-90 * fm)
	var hit_rot := rest_rot + deg_to_rad(90 * fm)
	var follow_rot := rest_rot + deg_to_rad(110 * fm)

	# Kill old tween
	if _bat_swing_tween and _bat_swing_tween.is_valid():
		_bat_swing_tween.kill()

	_bat_swing_tween = create_tween()
	_bat_swing_tween.set_trans(Tween.TRANS_CUBIC)
	_bat_swing_tween.set_ease(Tween.EASE_IN_OUT)

	# --- WIND UP ---
	_bat_swing_tween.tween_property(bat_sprite, "rotation", windup_rot, 0.08)
	_bat_swing_tween.parallel().tween_property(bat_sprite, "position", windup_pos, 0.08)

	# --- STRIKE ---
	_bat_swing_tween.tween_property(bat_sprite, "rotation", hit_rot, 0.10)
	_bat_swing_tween.parallel().tween_property(bat_sprite, "position", hit_pos, 0.10)
	_bat_swing_tween.parallel().tween_callback(_apply_damage_to_enemies)

	# --- FOLLOW THROUGH ---
	_bat_swing_tween.tween_property(bat_sprite, "rotation", follow_rot, 0.06)
	_bat_swing_tween.parallel().tween_property(bat_sprite, "position", follow_pos, 0.06)

	# --- RETURN ---
	_bat_swing_tween.tween_property(bat_sprite, "rotation", rest_rot, 0.10)
	_bat_swing_tween.parallel().tween_property(bat_sprite, "position", end_pos, 0.10)

	_bat_swing_tween.tween_callback(func():
		if bat_sprite:
			bat_sprite.rotation = rest_rot
			bat_sprite.position = end_pos
	)

func _hide_bat() -> void:
	if bat_sprite:
		bat_sprite.visible = false

	if _bat_swing_tween and _bat_swing_tween.is_valid():
		_bat_swing_tween.kill()
	_bat_swing_tween = null


# ——— AIR ATTACK ———
func _start_air_attack() -> void:
	if is_air_attacking:
		return
	
	# Play air attack sound
	if _air_attack_sound_cache:
		var scene_for_sound := get_tree().current_scene
		if scene_for_sound:
			var audio := AudioStreamPlayer2D.new()
			audio.stream = _air_attack_sound_cache
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
	
	# Priority 1: If enemy exists, aim toward them horizontally
	if air_attack_target != null:
		var to_enemy: Vector2 = air_attack_target.global_position - global_position
		horizontal_direction = sign(to_enemy.x)
	# Priority 2: Use player's current facing direction as fallback only if no enemy found
	elif animated_sprite.flip_h:
		horizontal_direction = -1.0
	
	# Calculate target position for straight diagonal movement
	var target_x: float = global_position.x + (horizontal_direction * air_attack_horizontal_distance)
	var target_y: float = global_position.y + (air_attack_horizontal_distance * 0.8)  # Downward diagonal
	var target_position: Vector2 = Vector2(target_x, target_y)
	
	# Face the attack direction
	animated_sprite.flip_h = horizontal_direction < 0
	
	# Create motion tween for smooth diagonal movement with ease-in/ease-out
	if air_attack_tween and air_attack_tween.is_valid():
		air_attack_tween.kill()
	
	air_attack_tween = create_tween()
	air_attack_tween.set_trans(Tween.TRANS_CUBIC)  # Smooth cubic easing
	air_attack_tween.set_ease(Tween.EASE_IN_OUT)   # Ease in and out for natural motion
	
	var duration: float = 0.3  # Fixed duration for consistent speed
	
	# Instead of setting constant velocity, use tween to interpolate position
	# for smooth ease-in/ease-out diagonal movement
	var start_position: Vector2 = global_position
	var attack_target_position: Vector2 = Vector2(target_x, target_y)
	
	# Create smooth position interpolation
	air_attack_tween.tween_method(_update_air_attack_position.bind(start_position, attack_target_position), 0.0, 1.0, duration)
	
	air_attack_tween.finished.connect(_on_air_attack_tween_finished)

func _update_air_attack_position(progress: float, start_pos: Vector2, target_pos: Vector2) -> void:
	# Apply smooth cubic easing to position
	var current_pos: Vector2 = start_pos.lerp(target_pos, progress)
	# Calculate velocity from position change for physics
	var new_velocity: Vector2 = (current_pos - global_position) / get_physics_process_delta_time()
	velocity = new_velocity

func _find_nearest_enemy() -> Node:
	var nearest: Node = null
	var nearest_distance_sq: float = 10000.0  # Reasonable search radius squared
	
	for enemy in _cached_enemies:
		if not is_instance_valid(enemy) or enemy.is_dead or not enemy.is_active:
			continue
		
		var distance_sq = global_position.distance_squared_to(enemy.global_position)
		if distance_sq < nearest_distance_sq:
			nearest_distance_sq = distance_sq
			nearest = enemy
	
	return nearest

func _update_air_attack() -> void:
	# Early exit with combined state check
	if not is_air_attacking or _air_attack_ending:
		return
	
	# Check ground contact first (most common ending condition)
	if is_on_floor():
		_end_air_attack()
		return
	
	# Optimize: Only check enemy collisions at intervals instead of every frame
	_air_attack_check_timer += get_physics_process_delta_time()
	if _air_attack_check_timer < AIR_ATTACK_CHECK_INTERVAL:
		return  # Skip collision check this frame
	
	_air_attack_check_timer = 0.0  # Reset timer
	
	# Check enemy collisions only if still in air (optimized)
	_check_air_attack_enemy_collisions()

func _check_air_attack_enemy_collisions() -> void:
	var player_pos_sq := global_position  # Cache position for all distance checks
	
	# Single pass: find nearby enemies and apply damage immediately
	for enemy in _cached_enemies:
		if not is_instance_valid(enemy) or enemy.is_dead or not enemy.is_active:
			continue
		
		# Quick distance check using squared distance (faster than sqrt)
		var distance_sq = player_pos_sq.distance_squared_to(enemy.global_position)
		if distance_sq < _air_attack_collision_threshold_sq:
			air_attack_target = enemy
			_apply_air_attack_damage()
			_end_air_attack()
			return

func _on_air_attack_tween_finished() -> void:
	# Only end if not already ending
	if not _air_attack_ending:
		_end_air_attack()

func _apply_air_attack_damage() -> void:
	if air_attack_target and air_attack_target.has_method("take_damage"):
		air_attack_target.take_damage(20)
		
		# Apply knockback to enemy in the direction player is facing during air attack
		var facing_dir: int = -1 if animated_sprite.flip_h else 1
		CharacterUtils.apply_knockback(air_attack_target, facing_dir, 320.0, 0.25)
		
		# Create impact effect
		if BLOOD_SCENE:
			var blood := BLOOD_SCENE.instantiate()
			var scene := get_tree().current_scene
			if blood and scene:
				blood.global_position = air_attack_target.global_position
				var blood_direction: Vector2 = (air_attack_target.global_position - global_position).normalized()
				blood.set_direction(blood_direction)
				
				# Add blood to scene tree at correct position (after Wall, before background)
				var wall_node = scene.get_node_or_null("Wall")
				var background_node = scene.get_node_or_null("background")
				
				if wall_node and background_node:
					# Insert blood after Wall node but before background
					var blood_index = wall_node.get_index() + 1
					scene.add_child(blood)
					scene.move_child(blood, blood_index)
				elif wall_node:
					# Fallback: insert after Wall
					var blood_index = wall_node.get_index() + 1
					scene.add_child(blood)
					scene.move_child(blood, blood_index)
				else:
					# Fallback: just add to scene
					scene.add_child(blood)

func _end_air_attack() -> void:
	# Prevent multiple calls to this function
	if _air_attack_ending:
		return
	
	# Also skip if air attack is already ended
	if not is_air_attacking:
		return
	
	_air_attack_ending = true
	is_air_attacking = false
	air_attack_target = null
	is_attacking = false  # Also clear regular attack state
	_air_attack_just_ended = true
	_air_attack_cooldown = 1.0  # 1 second cooldown
	_force_idle_after_air_attack = true  # Force idle animation until player moves
	
	# Check if we're still in the air when the attack ends
	if not is_on_floor():
		_air_attack_finished_mid_air = true
		# Let the animation finish naturally, then connect to animation_finished
		# to pause it on the last frame
		if not animated_sprite.animation_finished.is_connected(_on_air_attack_animation_finished):
			animated_sprite.animation_finished.connect(_on_air_attack_animation_finished)
	else:
		_air_attack_finished_mid_air = false
	
	# Kill the tween if it's still running
	if air_attack_tween and air_attack_tween.is_valid():
		air_attack_tween.kill()
	air_attack_tween = null
	
	# Reset velocity to prevent any residual movement
	velocity = Vector2.ZERO
	
	# Delay animation state update to next frame to avoid conflict with main animation logic
	call_deferred("_update_animation_state")


# ——— ANIMATION FINISHED ———
func _update_animation_state() -> void:
	# Force immediate animation update based on current state
	var old_anim = animated_sprite.animation
	
	# Clear the ending flag since we're now updating
	_air_attack_ending = false
	
	# Don't change animation if air attack finished mid-air - stay on last frame
	if _air_attack_finished_mid_air:
		return
	
	if is_dead:
		animated_sprite.play("DEATH")
	elif is_air_attacking:
		animated_sprite.play("AIR_ATTACK")
	elif is_attacking:
		# attack animations handled by animation_finished
		pass
	elif is_wall_jumping:
		# Use jump animation for wall jump as well
		if has_gun:
			animated_sprite.play("GUN_JUMP")
		else:
			animated_sprite.play("JUMP")
		_stop_running_sound()
	elif not is_on_floor() and not _air_attack_just_ended:
		# Only play jump animation if not in cooldown from air attack
		if has_gun:
			animated_sprite.play("GUN_JUMP")
		else:
			animated_sprite.play("JUMP")
		_stop_running_sound()
	elif velocity.x != 0:
		if has_gun:
			animated_sprite.play("GUN_RUN")
		else:
			animated_sprite.play("RUN")
		_play_running_sound()
	else:
		if has_gun:
			animated_sprite.play("GUN_IDLE")
		else:
			animated_sprite.play("IDLE")
		_stop_running_sound()
	
	var new_anim = animated_sprite.animation
	if old_anim != new_anim:
		print("[AIR_ATTACK] Animation changed: ", old_anim, " -> ", new_anim)

func _on_air_attack_animation_finished() -> void:
	# This is called when the air attack animation finishes naturally
	# Disconnect the signal to avoid multiple calls
	if animated_sprite.animation_finished.is_connected(_on_air_attack_animation_finished):
		animated_sprite.animation_finished.disconnect(_on_air_attack_animation_finished)
	
	# Only pause if we're still in the air attack finished state and in the air
	if _air_attack_finished_mid_air and not is_on_floor():
		# Pause on the last frame
		animated_sprite.pause()

func _on_animation_finished() -> void:
	var anim = animated_sprite.animation

	if anim == "DEATH":
		animated_sprite.stop()
		animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count("DEATH") - 1
		return
	
	if anim == "ATTACK1" or anim == "ATTACK2" or anim == "ATTACK3":
		is_attacking = false
		# hide + reset bat now attack animation finished
		_hide_bat()
		# Return to idle animation after attack
		if has_gun:
			animated_sprite.play("GUN_IDLE")
		else:
			animated_sprite.play("IDLE")
	elif anim == "GUN_ATTACK":
		is_attacking = false
		# Return to idle animation after gun attack
		animated_sprite.play("GUN_IDLE")




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
	# Tag shooter so bullet won't damage the player
	bullet.shooter = self
	# Create muzzle flash effect at spawn position
	GunUtils.create_muzzle_flash(spawn_pos, dir)
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
	emit_signal("bullets_changed", remaining, PLAYER_MAG_SIZE)
	if _player_shots_since_reload >= PLAYER_MAG_SIZE:
		# Magazine empty: either start a reload or drop the gun if reload limit is reached
		if _player_reload_count >= PLAYER_MAX_RELOADS:
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
	# Round ended: clear all bullets from UI
	emit_signal("bullets_changed", 0, PLAYER_MAG_SIZE)
	# Stop any existing reload tween
	if _player_reload_tween and _player_reload_tween.is_valid():
		_player_reload_tween.kill()
	# Base the reload rotation on the current gun rotation
	var start_rotation: float = gun_sprite.rotation
	# Full 360 degree rotation (2 * PI radians)
	var full_rotation: float = deg_to_rad(360.0)
	# Adjust rotation direction based on facing
	if animated_sprite and animated_sprite.flip_h:
		full_rotation = -full_rotation
	
	# Create a smooth 360-degree rotation tween
	_player_reload_tween = create_tween()
	_player_reload_tween.set_trans(Tween.TRANS_QUAD)
	_player_reload_tween.set_ease(Tween.EASE_OUT)
	# Rotate 360 degrees over 0.4 seconds
	_player_reload_tween.tween_property(gun_sprite, "rotation", start_rotation + full_rotation, 0.4)
	# Ensure we end up at the exact starting rotation
	_player_reload_tween.tween_property(gun_sprite, "rotation", start_rotation, 0)
	_player_reload_tween.finished.connect(_on_player_reload_finished)
	# Play reload sound at the gun position (using cached stream)
	var scene_for_sound := get_tree().current_scene
	if scene_for_sound and _reload_sound_cache:
		var audio := AudioStreamPlayer2D.new()
		audio.stream = _reload_sound_cache
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
	# Emit reload count change signal
	emit_signal("reloads_changed", _player_reload_count, PLAYER_MAX_RELOADS)
	# Reload finished: refill magazine in UI
	emit_signal("bullets_changed", PLAYER_MAG_SIZE, PLAYER_MAG_SIZE)


func _drop_player_gun() -> void:
	# Gun is exhausted: hide it, drop a pickup on the ground, and revert to melee
	has_gun = false
	_player_is_reloading = false
	_player_shots_since_reload = 0
	
	# Check if we have a backup gun to auto-equip
	if has_backup_gun:
		# Equip backup gun immediately with fresh reloads and full magazine
		has_gun = true
		_player_shots_since_reload = 0  # Reset to full magazine for backup gun
		_player_reload_count = 0  # Reset to full reloads for backup gun
		_player_is_reloading = false  # Reset reload state
		has_backup_gun = false
		backup_gun_data = {}
		
		if gun_sprite:
			gun_sprite.visible = true
		
		print("[PLAYER GUN] Auto-equipped backup gun")
		CharacterUtils.spawn_floating_popup(self, "BACKUP EQUIPPED", Color(0.4, 1.0, 0.4), Vector2(-35, -22), POPUP_FONT_SIZE, BACKUP_EQUIPPED_HEIGHT)
		emit_signal("bullets_changed", PLAYER_MAG_SIZE - _player_shots_since_reload, PLAYER_MAG_SIZE)
		emit_signal("reloads_changed", _player_reload_count, PLAYER_MAX_RELOADS)
	else:
		# No backup gun - show "OUT OF AMMO" and hide gun
		CharacterUtils.spawn_floating_popup(self, "OUT OF AMMO", Color(1.0, 0.4, 0.4), Vector2(-29, -22), POPUP_FONT_SIZE, OUT_OF_AMMO_HEIGHT)
		if gun_sprite:
			gun_sprite.visible = false
		# Clear bullets from UI
		emit_signal("bullets_changed", 0, PLAYER_MAG_SIZE)
		emit_signal("reloads_changed", 0, PLAYER_MAX_RELOADS)
	
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
	
	# Get current gun position (which includes left-facing offset)
	var current_gun_pos := gun_sprite.position
	var back_pos := current_gun_pos - shot_dir.normalized() * recoil_distance
	
	_gun_recoil_tween.tween_property(gun_sprite, "position", back_pos, 0.04)
	_gun_recoil_tween.tween_property(gun_sprite, "position", current_gun_pos, 0.06)

func take_damage(amount: int) -> void:
	take_damage_with_direction(amount, Vector2.ZERO)  # Default direction for non-bullet damage

func take_damage_with_direction(amount: int, bullet_direction: Vector2, bullet_position: Vector2 = Vector2.ZERO) -> void:
	if is_dead: return
	
	# Apply combo healing before taking damage if combo is active
	apply_combo_healing()
	
	# Apply damage effects using CharacterUtils with bullet direction and position
	CharacterUtils.apply_damage_with_effects(self, amount, BLOOD_SCENE, BLOOD_SPLAT_SOUND, hit_player, bullet_direction, bullet_position)
	
	# Add pink flash after damage if healing was applied
	if combo_streak > 0:
		var current_scene = get_tree().current_scene
		if current_scene and current_scene.has_method("set_health_bar_color_unified"):
			# Use unified health bar color function for pink flash
			current_scene.set_health_bar_color_unified(HEALTH_HIGHLIGHT_COLOR, 0.1)
			
			# Restore normal color after delay
			await get_tree().create_timer(0.3).timeout
			current_scene.restore_health_bar_color(0.2)

	health = max(health - amount, 0)
	emit_signal("health_changed", health, MAX_HEALTH)

	if health <= 0:
		if not is_dead:
			is_dead = true
			is_attacking = false
			CharacterUtils.play_character_animation(animated_sprite, "DEATH")
			_play_player_death_sound()
			
			# Stop heartbeat sound when player dies
			var current_scene = get_tree().current_scene
			if current_scene and current_scene.has_method("stop_heartbeat_sound"):
				current_scene.stop_heartbeat_sound()
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

# Old health gain system removed - now using combo streak system

func _highlight_health_bar() -> void:
	# Get the health bar from the level scene
	var scene := get_tree().current_scene
	if scene == null:
		return
	
	var health_bar = scene.get_node_or_null("UI/HealthBar")
	if health_bar == null:
		return
	
	# Cancel any existing highlight tween
	if _health_bar_highlight_tween and _health_bar_highlight_tween.is_valid():
		_health_bar_highlight_tween.kill()
	
	# Create highlight effect: flash pink then return to normal
	_health_bar_highlight_tween = create_tween()
	_health_bar_highlight_tween.set_parallel(true)
	
	# Flash to pink
	_health_bar_highlight_tween.tween_property(health_bar, "modulate", HEALTH_HIGHLIGHT_COLOR, 0.1)
	
	# Create pink fill style directly using unified method
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("set_health_bar_color_unified"):
		current_scene.set_health_bar_color_unified(HEALTH_HIGHLIGHT_COLOR, 0.0)
	
	# Hold pink color briefly
	_health_bar_highlight_tween.tween_property(health_bar, "modulate", HEALTH_HIGHLIGHT_COLOR, 0.2).set_delay(0.1)
	
	# Fade back to proper color based on current health
	var proper_color = get_health_color()
	_health_bar_highlight_tween.tween_property(health_bar, "modulate", proper_color, 0.3).set_delay(0.3)
	
	# Also restore the fill color after the highlight
	_health_bar_highlight_tween.tween_callback(func(): 
		# Force update health bar color using the level's unified method
		if current_scene and current_scene.has_method("update_health_bar_unified"):
			# Use the level's unified method to ensure proper color
			current_scene.update_health_bar_unified(current_scene.player.health, current_scene.player.MAX_HEALTH)
	).set_delay(0.3)

# Combo streak system functions
func _setup_combo_timer() -> void:
	_combo_timer = Timer.new()
	_combo_timer.wait_time = _combo_duration
	_combo_timer.one_shot = true
	_combo_timer.timeout.connect(_on_combo_timer_expired)
	add_child(_combo_timer)

func _on_combo_timer_expired() -> void:
	print("DEBUG: Combo timer expired, applying combo healing")
	# Apply healing before resetting the combo
	apply_combo_healing()
	# Emit signal to trigger fade out animation (0 means combo ended)
	emit_signal("combo_streak_changed", 0)

func increment_combo_streak() -> void:
	combo_streak += 1
	_combo_active = true
	emit_signal("combo_streak_changed", combo_streak)
	
	# Refresh combo timer
	if _combo_timer:
		_combo_timer.stop()
		_combo_timer.start()

func reset_combo_streak() -> void:
	combo_streak = 0
	_combo_active = false
	emit_signal("combo_streak_changed", combo_streak)
	
	# Stop combo timer
	if _combo_timer:
		_combo_timer.stop()

func apply_combo_healing() -> void:
	print("DEBUG: apply_combo_healing called, current combo: ", combo_streak)
	if combo_streak > 0:
		# Calculate heal potential using triangular formula: n(n+1)/2
		var heal_potential: int = combo_streak * (combo_streak + 1) / 2
		var actual_heal: int = heal_potential
		if actual_heal > 0:
			var old_health := health
			health = min(health + actual_heal, MAX_HEALTH)
			emit_signal("health_changed", health, MAX_HEALTH)
			print("DEBUG: Healed for: ", actual_heal, " (combo: ", combo_streak, ", potential: ", heal_potential, ")")
			# Show healing popup with consistent size
			CharacterUtils.spawn_floating_popup(self, "+" + str(actual_heal) + " HP", Color(1.0, 0.75, 0.8), Vector2(-20, -25), 14, HEALTH_POPUP_HEIGHT)
			# Play health gain sound
			AudioUtils.play_positioned_sound(HEALTH_GAIN_SOUND, global_position)
			# Sync health bar color to show pink flash
			var current_scene = get_tree().current_scene
			if current_scene and current_scene.has_method("update_health_bar_unified"):
				current_scene.update_health_bar_unified(current_scene.player.health, current_scene.player.MAX_HEALTH)
			# Add temporary pink flash effect
			if current_scene and current_scene.has_method("set_health_bar_color_unified"):
				current_scene.set_health_bar_color_unified(HEALTH_HIGHLIGHT_COLOR, 0.1)
				# Reset to original color after 0.3 seconds
				await get_tree().create_timer(0.3).timeout
				current_scene.restore_health_bar_color(0.2)
		
		reset_combo_streak()

# Helper function to get proper health color based on current health
# Uses same thresholds as level.gd - SINGLE SOURCE OF TRUTH
func get_health_color() -> Color:
	var ratio: float = 0.0
	if MAX_HEALTH > 0:
		ratio = float(health) / float(MAX_HEALTH)
	
	# Use shared constants instead of hardcoded values
	if ratio > HEALTH_HIGH_THRESHOLD:
		return HEALTH_HIGH_COLOR
	elif ratio > HEALTH_LOW_THRESHOLD:
		return HEALTH_MEDIUM_COLOR
	else:
		return HEALTH_LOW_COLOR

# Old health gain system removed - now using combo streak system

func _update_enemy_cache(delta: float) -> void:
	_enemy_cache_update_timer += delta
	if _enemy_cache_update_timer >= ENEMY_CACHE_UPDATE_INTERVAL:
		_enemy_cache_update_timer = 0.0
		
		# Only update if player is in combat or recently damaged
		if _combo_active or _last_damage_time > Time.get_time_dict_from_system().second - 5.0:
			_cached_enemies = get_tree().get_nodes_in_group("enemies")



func pickup_gun() -> bool:
	if has_gun:
		# Store current gun as backup if we don't already have one
		if not has_backup_gun:
			backup_gun_data = {
				"shots_since_reload": _player_shots_since_reload,
				"reload_count": _player_reload_count,
				"is_reloading": _player_is_reloading
			}
			has_backup_gun = true
			CharacterUtils.spawn_floating_popup(self, "GUN STORED", Color(0.4, 1.0, 0.4), Vector2(-25, -22), POPUP_FONT_SIZE, GUN_STORED_HEIGHT)
			# Don't reset anything - we're still using the same gun
			# Only reset when backup gun is actually equipped
			_player_is_reloading = false
			emit_signal("bullets_changed", PLAYER_MAG_SIZE - _player_shots_since_reload, PLAYER_MAG_SIZE)
			emit_signal("reloads_changed", _player_reload_count, PLAYER_MAX_RELOADS)
			return true  # Successfully stored backup
		else:
			# Already have a backup gun - can't pick up another
			CharacterUtils.spawn_floating_popup(self, "MAX. BACKUP!!", Color(1.0, 0.4, 0.4), Vector2(-35, -22), POPUP_FONT_SIZE, MAX_BACKUP_HEIGHT)
			return false  # Failed to pick up
	else:
		# No gun currently equipped, just pick it up
		has_gun = true
		if gun_sprite:
			gun_sprite.visible = true
		
		# Reset magazine and reload state; new gun starts with fresh reloads
		_player_shots_since_reload = 0
		_player_reload_count = 0
		_player_is_reloading = false
		
		emit_signal("bullets_changed", PLAYER_MAG_SIZE, PLAYER_MAG_SIZE)
		emit_signal("reloads_changed", _player_reload_count, PLAYER_MAX_RELOADS)
		_update_cursor()
		return true  # Successfully picked up gun


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
	if not bat_sprite:
		return
	
	var base_damage: int = 15
	var hit_something := false
	
	# Check for bat collision with enemies
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.has_method("take_damage"):
			continue
		
		# Check if bat sprite collides with enemy using distance-based collision
		var distance := bat_sprite.global_position.distance_to(enemy.global_position)
		if distance > 40.0:  # Bat reach distance
			continue
		
		# Apply damage to enemy
		enemy.take_damage(base_damage)
		hit_something = true
		
		# Apply knockback away from bat position
		var knockback_direction: int = sign(enemy.global_position.x - bat_sprite.global_position.x)
		CharacterUtils.apply_knockback(enemy, knockback_direction, 250.0, 0.18)
	
	if hit_something:
		# Play hit sound
		if hit_player:
			hit_player.play()


func _start_camera_shake() -> void:
	_camera_shake_timer = camera_shake_time


func _play_player_death_sound() -> void:
	AudioUtils.play_death_sound(PLAYER_DEATH_SOUND, null, global_position)


func _play_hurt_sound() -> void:
	AudioUtils.play_hurt_sound(HURT_SOUND, global_position)


func _play_running_sound() -> void:
	AudioUtils.play_running_sound(running_player, RUNNING_SOUND)

func _stop_running_sound() -> void:
	AudioUtils.stop_running_sound(running_player)

func _play_blood_splat_sound() -> void:
	AudioUtils.play_blood_splat_sound(BLOOD_SPLAT_SOUND, global_position)


# ——— BAT THROW ———
func _start_bat_throw() -> void:
	if _bat_thrown or not has_bat or current_equipped_weapon == "gun":
		return
	
	_bat_thrown = true
	is_attacking = true  # Prevent other attacks during throw
	
	# Hide the bat sprite
	if bat_sprite:
		bat_sprite.visible = false
	
	# Play throw sound
	if _bat_throw_sound_cache:
		var scene_for_sound := get_tree().current_scene
		if scene_for_sound:
			var audio := AudioStreamPlayer2D.new()
			audio.stream = _bat_throw_sound_cache
			audio.position = global_position
			scene_for_sound.add_child(audio)
			AudioUtils.play_random_pitch(audio, 0.9, 1.1)
			audio.finished.connect(audio.queue_free)
	
	# Create thrown bat
	var thrown_bat = PLAYER_BAT_SCENE.instantiate()
	if thrown_bat:
		# Set throw direction toward mouse
		var mouse_pos := get_global_mouse_position()
		var throw_direction := (mouse_pos - global_position).normalized()
		thrown_bat.direction = throw_direction
		thrown_bat.thrower = self
		thrown_bat.global_position = global_position
		
		# Add to scene
		var scene := get_tree().current_scene
		if scene:
			scene.add_child(thrown_bat)
			_thrown_bat = thrown_bat
	
	# Short throw animation
	animated_sprite.play("ATTACK1")
	
	# End throw animation quickly
	await get_tree().create_timer(0.3).timeout
	is_attacking = false

func _on_bat_returned() -> void:
	_bat_thrown = false
	_thrown_bat = null
	
	# Show bat again
	if bat_sprite:
		bat_sprite.visible = true
	
	# Play catch sound (could use a soft hit sound)
	if hit_player:
		hit_player.pitch_scale = 0.8
		hit_player.play()






# ——— CURSOR MANAGEMENT ———
func _get_wall_direction() -> float:
	# Check if player is touching a wall and return the direction (-1 for left, 1 for right, 0 for no wall)
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# Check if collision is with a wall (vertical surface)
		if collider and (collider.is_in_group("walls") or collider is TileMap):
			var normal = collision.get_normal()
			# Check if this is a vertical wall (normal.x is significant)
			if abs(normal.x) > 0.5:  # Mostly horizontal normal means vertical wall
				return -normal.x  # Return direction away from wall
	
	return 0.0  # No wall detected

func _update_cursor() -> void:
	if current_equipped_weapon == "gun" and has_gun and gun_cursor_texture:
		# Set custom cursor when holding gun
		Input.set_custom_mouse_cursor(gun_cursor_texture, Input.CURSOR_ARROW, Vector2(16, 16))
	else:
		# Reset to normal cursor when not holding gun
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)

# ——— WEAPON SWITCHING ———
func switch_to_weapon(weapon_type: String) -> void:
	if weapon_type == "bat":
		current_equipped_weapon = "bat"
		print("Player switched to BAT")
	elif weapon_type == "gun":
		if has_gun:  # Only switch to gun if player has obtained it
			current_equipped_weapon = "gun"
			print("Player switched to GUN")
		else:
			print("Player cannot switch to GUN - not obtained")
	else:
		print("Invalid weapon type: ", weapon_type)
	
	# Update weapon visibility immediately
	_update_weapon_visibility()
	_update_cursor()
	
	# Force UI updates when switching weapons
	if has_signal("bullets_changed"):
		emit_signal("bullets_changed", PLAYER_MAG_SIZE - _player_shots_since_reload, PLAYER_MAG_SIZE)
	if has_signal("reloads_changed"):
		reloads_changed.emit(_player_reload_count, PLAYER_MAX_RELOADS)
