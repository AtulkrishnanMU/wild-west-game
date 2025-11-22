extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const AudioUtils = preload("res://scripts/audio_utils.gd")
const BLOOD_SCENE := preload("res://scenes/blood_splash.tscn")
const PLAYER_BULLET_SCENE := preload("res://scenes/bullet.tscn")
const PLAYER_GUN_SHOT_SOUND := preload("res://sounds/gun-shot.mp3")
signal health_changed(current: int, max: int)
signal cash_changed(current: int)

var PLAYER_DEATH_SOUND: AudioStream = null
var HURT_SOUND: AudioStream = null

const MAX_HEALTH := 200
var health: int = MAX_HEALTH
var cash: int = 0
var controls_enabled: bool = true

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

var is_attacking := false
var is_dead := false
var has_gun: bool = false

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
	PLAYER_DEATH_SOUND = load("res://sounds/player-death.mp3")
	HURT_SOUND = load("res://sounds/hurt.mp3")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

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
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_attacking:
		velocity.y = JUMP_VELOCITY
	
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
	
	if has_gun:
		# With gun: left-click shoots instead of melee; allow rapid fire on every click
		if gun_attack_pressed and not is_dead:
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
	if is_attacking:
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
	# Finally, add the bullet to the scene
	var scene := get_tree().current_scene
	if scene:
		scene.add_child(bullet)


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
