extends CharacterBody2D
var SPEED: float = 150.0
const GRAVITY: float = 900.0
const JUMP_SPEED: float = -360.0
const ATTACK_RANGE: float = 18.0          # When enemy stops chasing and starts attacking
const DAMAGE_H_RANGE: float = 45.0        # Tight but fair – enemy must be close
const DAMAGE_V_RANGE: float = 50.0        # Good vertical coverage (jumping, etc.)
const DAMAGE_COOLDOWN: float = 0.20       # Prevents insane damage spam
const ENEMY_KNOCKBACK_SPEED: float = 120.0
const MAX_HEALTH := 50
const CASH_SCENE := preload("res://scenes/cash.tscn")
const AudioUtils = preload("res://scripts/audio_utils.gd")
var ENEMY_DEATH_SOUND_1: AudioStream = null
var ENEMY_DEATH_SOUND_2: AudioStream = null
var ENEMY_HURT_SOUND: AudioStream = null
var health: int = MAX_HEALTH
var FAR_JUMP_DISTANCE: float = 140.0
var ATTACK_RANGE_DISTANCE: float = ATTACK_RANGE
var is_dead: bool = false
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var slash_player: AudioStreamPlayer2D = $SlashEnemyPlayer
@onready var hit_player: AudioStreamPlayer2D = $HitEnemyPlayer
@onready var player: CharacterBody2D = get_parent().get_node("Player")
@onready var sprite_material: ShaderMaterial = animated_sprite.material
var is_attacking: bool = false
var damage_cooldown_timer: float = 0.0
var _hit_tween: Tween = null
var _knockback_timer: float = 0.0

func _ready() -> void:
	randomize()
	SPEED = randf_range(150.0, 300.0)
	add_to_group("enemies")
	# Make sure each enemy has its own material instance so hit_silhouette is per-enemy
	if sprite_material:
		var local_mat := sprite_material.duplicate()
		animated_sprite.material = local_mat
		sprite_material = local_mat
	animated_sprite.animation_finished.connect(_on_animation_finished)
	ENEMY_DEATH_SOUND_1 = load("res://sounds/enemy-death.mp3")
	ENEMY_DEATH_SOUND_2 = load("res://sounds/enemy-death2.mp3")
	ENEMY_HURT_SOUND = load("res://sounds/hurt.mp3")

func _physics_process(delta: float) -> void:
	if is_dead:
		# When dead, still fall with gravity but slowly come to a horizontal stop
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		velocity.x = move_toward(velocity.x, 0.0, SPEED * delta)
		move_and_slide()
		return

	if player == null:
		animated_sprite.play("IDLE")
		return

	# If the player is dead, stop attacking and stay idle
	if player.is_dead:
		is_attacking = false
		# Still fall with gravity even though AI is disabled
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		velocity.x = move_toward(velocity.x, 0.0, SPEED * delta)
		animated_sprite.play("IDLE")
		move_and_slide()
		return

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Knockback: during a short window, just slide with current velocity
	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		move_and_slide()
		return

	# Cooldown countdown
	if damage_cooldown_timer > 0.0:
		damage_cooldown_timer -= delta

	var to_player: Vector2 = player.global_position - global_position
	var distance_x: float = to_player.x
	var abs_distance: float = abs(distance_x)
	var direction: float = sign(distance_x)
	var vertical_distance: float = abs(player.global_position.y - global_position.y)

	# If we are almost exactly overlapping the player, step back slightly using REV_WALK
	var overlap_x_threshold := 6.0
	var overlap_y_threshold := 24.0
	# Require a small but non-zero horizontal offset so we don't get stuck when perfectly aligned
	if vertical_distance < overlap_y_threshold and abs_distance > 1.0 and abs_distance < overlap_x_threshold:
		# Cancel any attack attempt because we must reposition
		is_attacking = false

		var back_dir := -direction
		velocity.x = back_dir * SPEED * 0.8

		if is_on_floor():
			animated_sprite.flip_h = direction < 0
			if animated_sprite.sprite_frames.has_animation("REV_WALK"):
				animated_sprite.play("REV_WALK")
			else:
				animated_sprite.play("RUN")

		move_and_slide()
		return

	# ── Movement & Attack Logic ──
	if not is_attacking:
		if abs_distance > ATTACK_RANGE_DISTANCE:
			# Occasionally do a jumping lunge toward the player when they are REALLY far away
			if abs_distance > FAR_JUMP_DISTANCE and is_on_floor() and randf() < 0.3:
				velocity.y = JUMP_SPEED
				velocity.x = direction * SPEED * 1.2
				animated_sprite.flip_h = direction < 0
				animated_sprite.play("JUMP")
			else:
				# Normal chase
				velocity.x = direction * SPEED
				animated_sprite.flip_h = direction < 0
				animated_sprite.play("RUN")
				# Occasional running swing
				if randf() < 0.012:
					_start_attack_running()
		else:
			# Close enough → standing attack
			velocity.x = 0.0
			_start_attack_close()
	else:
		# Slowly stop while attacking
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 2.0 * delta)

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
	if player == null:
		return false
	var dx: float = abs(player.global_position.x - global_position.x)
	var dy: float = abs(player.global_position.y - global_position.y)
	return dx < DAMAGE_H_RANGE and dy < DAMAGE_V_RANGE

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

func take_damage(amount: int) -> void:
	if is_dead:
		return
	
	health = max(health - amount, 0)
	if hit_player:
		AudioUtils.play_random_pitch(hit_player, 0.7, 1.6)
	if health > 0 and randf() < 0.1:
		_play_enemy_hurt_sound()
	
	# FLASH WHITE ON EVERY HIT (including killing blow)
	_flash_white()
	
	if health > 0:
		# Knock the enemy away from the player horizontally
		if player:
			var dir: float = sign(global_position.x - player.global_position.x)
			velocity.x = dir * ENEMY_KNOCKBACK_SPEED
			_knockback_timer = 0.12
	else:
		is_dead = true
		is_attacking = false
		velocity = Vector2.ZERO
		# Remove from enemies group so player can no longer hit the corpse
		if is_in_group("enemies"):
			remove_from_group("enemies")
		# Face the player on death if possible
		if player:
			animated_sprite.flip_h = (player.global_position.x < global_position.x)
		animated_sprite.play("DEATH")
		if randf() < 0.2:
			_start_kill_slowmo()
		# Always drop cash on death, but defer to avoid physics flush issues
		call_deferred("_drop_cash_on_death")
		_play_enemy_death_sound()

func _flash_white() -> void:
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()

	_hit_tween = create_tween()
	_hit_tween.set_trans(Tween.TRANS_LINEAR)
	if sprite_material:
		# Start fully white, then fade the silhouette flag back to 0 over 0.5s
		sprite_material.set_shader_parameter("hit_silhouette", 1.0)
		_hit_tween.tween_property(sprite_material, "shader_parameter/hit_silhouette", 0.0, 0.5)


func _start_kill_slowmo() -> void:
	Engine.time_scale = 0.3
	_restore_time_scale_after_kill()


func _restore_time_scale_after_kill() -> void:
	await get_tree().create_timer(0.35).timeout
	Engine.time_scale = 1.0


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
	var scene := get_tree().current_scene
	if scene == null:
		return
	var audio := AudioStreamPlayer2D.new()
	var choice := randf()
	if choice < 0.5 and ENEMY_DEATH_SOUND_1:
		audio.stream = ENEMY_DEATH_SOUND_1
	elif ENEMY_DEATH_SOUND_2:
		audio.stream = ENEMY_DEATH_SOUND_2
	else:
		return
	audio.position = global_position
	scene.add_child(audio)
	AudioUtils.play_random_pitch(audio, 0.9, 1.1)
	audio.finished.connect(audio.queue_free)


func _play_enemy_hurt_sound() -> void:
	if ENEMY_HURT_SOUND == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var audio := AudioStreamPlayer2D.new()
	audio.stream = ENEMY_HURT_SOUND
	audio.position = global_position
	audio.pitch_scale = randf_range(0.9, 1.1)
	scene.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)
