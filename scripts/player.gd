extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const AudioUtils = preload("res://scripts/audio_utils.gd")
signal health_changed(current: int, max: int)
signal cash_changed(current: int)

var PLAYER_DEATH_SOUND: AudioStream = null
var HURT_SOUND: AudioStream = null

const MAX_HEALTH := 200
var health: int = MAX_HEALTH
var cash: int = 0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var slash_player: AudioStreamPlayer2D = $SlashPlayer
@onready var hit_player: AudioStreamPlayer2D = $HitPlayer
@onready var camera: Camera2D = $Camera2D

# Add these variables near the top with the others
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
const PLAYER_KNOCKBACK_DURATION: float = 0.05  # seconds of forced knockback

var camera_shake_amount: float = 1.0
var camera_shake_time: float = 0.1
var _camera_shake_timer: float = 0.0
var _camera_original_offset: Vector2 = Vector2.ZERO

var is_attacking := false
var is_dead := false

# Reference to the current flicker tween so we can cancel/replace it
var _flicker_tween: Tween = null

func _ready() -> void:
	randomize()
	animated_sprite.animation_finished.connect(_on_animation_finished)
	emit_signal("health_changed", health, MAX_HEALTH)
	emit_signal("cash_changed", cash)
	if camera:
		_camera_original_offset = camera.offset
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

	# ——— INPUT (only runs when not in knockback) ———
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_attacking:
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
		animated_sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Attack
	if Input.is_action_just_pressed("attack") and not is_attacking and not is_dead:
		if direction != 0 or velocity.x != 0:
			_start_attack_moving()
		else:
			_start_attack_idle()

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

	move_and_slide()


# ——— ATTACK ———
func _start_attack_idle() -> void:
	is_attacking = true
	var anim = "ATTACK1" if randf() < 0.5 else "ATTACK2"
	if slash_player:
		AudioUtils.play_random_pitch(slash_player, 0.7, 1.6)
	animated_sprite.play(anim)

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
	
	if anim.begins_with("ATTACK"):
		_apply_damage_to_enemies()
		is_attacking = false


# ——— DAMAGE ———
func take_damage(amount: int) -> void:
	if is_dead: return

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
	var hit_range_h: float = 45.0
	var hit_range_v: float = 40.0
	var base_damage: int = 15
	var facing: int = -1 if animated_sprite.flip_h else 1
	var hit_something := false

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.has_method("take_damage"):
			continue
		var dx: float = enemy.global_position.x - global_position.x
		var dy: float = abs(enemy.global_position.y - global_position.y)
		if dx * facing > 0 and abs(dx) <= hit_range_h and dy <= hit_range_v:
			enemy.take_damage(base_damage)
			hit_something = true

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
