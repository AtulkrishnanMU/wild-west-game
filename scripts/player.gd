class_name Player
extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const AudioUtils = preload("res://scripts/audio_utils.gd")
const BLOOD_SCENE := preload("res://scenes/blood_splash.tscn")
const PLAYER_BULLET_SCENE := preload("res://scenes/bullet.tscn")
const PLAYER_GUN_SHOT_SOUND := preload("res://sounds/gun-shot.mp3")
const PLAYER_RELOAD_SOUND_PATH := "res://sounds/reload.mp3"
const PLAYER_MAG_SIZE: int = 10
const PLAYER_MAX_RELOADS: int = 5
const PLAYER_GUN_PICKUP_SCENE := preload("res://scenes/gun.tscn")
signal health_changed(current: int, max: int)
signal cash_changed(current: int)
signal bullets_changed(current: int, max: int)

var PLAYER_DEATH_SOUND: AudioStream = null
var HURT_SOUND: AudioStream = null

const MAX_HEALTH := 200
var health: int = MAX_HEALTH
var cash: int = 0
var controls_enabled: bool = true
var _heal_buffer: float = 0.0

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

var HEAL_SOUND: AudioStream = preload("res://sounds/health-gain.mp3")
var heal_player: AudioStreamPlayer2D = null
var _heal_pitch: float = 1.0
var _heal_pitch_increment: float = 0.1
var _heal_pitch_max: float = 2.0
var _heal_limit: int = int(MAX_HEALTH * 0.2)  # 20% max per heal session
var _heal_accumulated: int = 0                 # Tracks health healed in current session
var _heal_cooldown: float = 30.0              # seconds to wait before next heal
var _heal_cooldown_timer: float = 0.0         # counts down
var _heal_on_cooldown: bool = false  # NEW flag


var is_attacking := false
var is_dead := false
var has_gun: bool = false
var is_healing: bool = false

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
	
	# Heal sound setup
	heal_player = AudioStreamPlayer2D.new()
	heal_player.stream = HEAL_SOUND
	add_child(heal_player)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	# ——— DEAD ———
	if is_dead:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		move_and_slide()
		return

	# ——— HEAL COOLDOWN TIMER (runs regardless of input) ———
	if _heal_on_cooldown:
		_heal_cooldown_timer -= delta
		if _heal_cooldown_timer <= 0.0:
			_heal_cooldown_timer = 0.0
			_heal_accumulated = 0       # Reset accumulated heal once cooldown finishes
			_heal_on_cooldown = false   # Cooldown finished

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
	# Check for dual-click healing (both mouse buttons held)
	var left_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var right_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	is_healing = left_down and right_down and not is_dead and is_on_floor()

	# Force-stop attack if healing starts
	if is_healing:
		is_attacking = false

		# PLAY HEAL ANIMATION HERE
		animated_sprite.play("HEAL")

		# Stop horizontal motion while healing
		velocity.x = move_toward(velocity.x, 0, SPEED)

		# Only allow healing if cooldown is finished and under heal limit
		if is_healing and not _heal_on_cooldown and health < MAX_HEALTH:
			var heal_per_second: float = float(MAX_HEALTH) * 0.05
			_heal_buffer += heal_per_second * delta
			if _heal_buffer >= 1.0:
				var heal_points: int = int(_heal_buffer)
				_heal_buffer -= float(heal_points)

				# Clamp heal to remaining allowed amount
				var remaining_heal: int = _heal_limit - _heal_accumulated
				var heal_this_tick: int = min(heal_points, remaining_heal)
				var new_health: int = min(MAX_HEALTH, health + heal_this_tick)
				
				if new_health != health:
					health = new_health
					emit_signal("health_changed", health, MAX_HEALTH)
					_heal_accumulated += heal_this_tick
					# Show pink "+X%" popup for the healed amount
					var healed_percent: int = int(round(float(heal_this_tick) * 100.0 / float(MAX_HEALTH)))
					if healed_percent > 0:
						_spawn_floating_popup("+%d%%" % healed_percent, Color(1.0, 0.4, 0.8))

					# Play overlapping healing sound with rising pitch
					var heal_audio := AudioStreamPlayer2D.new()
					heal_audio.stream = HEAL_SOUND
					heal_audio.pitch_scale = _heal_pitch
					heal_audio.position = global_position
					get_tree().current_scene.add_child(heal_audio)
					heal_audio.play()
					heal_audio.finished.connect(heal_audio.queue_free)
					
					_heal_pitch = min(_heal_pitch + _heal_pitch_increment, _heal_pitch_max)

				# Start cooldown if reached heal limit
				if _heal_accumulated >= _heal_limit:
					_heal_cooldown_timer = _heal_cooldown
					_heal_on_cooldown = true
		else:
			# Reset pitch if not healing
			_heal_pitch = 1.0

		move_and_slide()
		return

	else:
		if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_attacking:
			velocity.y = JUMP_VELOCITY
		
		# Horizontal movement: only while right mouse button is held
		var direction: float = 0.0
		if right_down:
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
		
		if has_gun:
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

	# ——— ANIMATION CHOICE ———
	if is_healing:
		animated_sprite.play("HEAL")
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
			blood.rotation = facing_dir.angle()
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


func get_heal_cooldown_progress() -> float:
	if _heal_cooldown <= 0.0:
		return 1.0
	if _heal_on_cooldown:
		var elapsed := _heal_cooldown - _heal_cooldown_timer
		return clamp(elapsed / _heal_cooldown, 0.0, 1.0)
	return 1.0
