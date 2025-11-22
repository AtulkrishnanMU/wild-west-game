class_name Enemy
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
const BLOOD_SCENE := preload("res://scenes/blood_splash.tscn")
const AudioUtils = preload("res://scripts/audio_utils.gd")
var ENEMY_DEATH_SOUND_1: AudioStream = null
var ENEMY_DEATH_SOUND_2: AudioStream = null
var ENEMY_HURT_SOUND: AudioStream = null
var health: int = MAX_HEALTH
var FAR_JUMP_DISTANCE: float = 140.0
var ATTACK_RANGE_DISTANCE: float = ATTACK_RANGE
var is_dead: bool = false
var has_been_visible_with_player := false
var is_active := false
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var slash_player: AudioStreamPlayer2D = $SlashEnemyPlayer
@onready var hit_player: AudioStreamPlayer2D = $HitEnemyPlayer
@onready var player: CharacterBody2D = get_parent().get_node("Player")
@onready var notifier: VisibleOnScreenNotifier2D = $VisibilityNotifier2D
@onready var player_notifier: VisibleOnScreenNotifier2D = player.get_node("VisibilityNotifier2D")
@onready var sprite_material: ShaderMaterial = animated_sprite.material
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_hitbox_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D
var is_attacking: bool = false
var damage_cooldown_timer: float = 0.0
var _hit_tween: Tween = null
var _knockback_timer: float = 0.0
var _attack_hitbox_base_position: Vector2 = Vector2.ZERO
var _player_in_attack_hitbox: bool = false

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
	if attack_hitbox:
		_attack_hitbox_base_position = attack_hitbox.position
		attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
		attack_hitbox.body_exited.connect(_on_attack_hitbox_body_exited)

func _physics_process(delta: float) -> void:

	# ─────────────────────────────────────────────
	# SCREEN-ACTIVATION: Enemy AI OFF until both are visible
	# ─────────────────────────────────────────────
	_check_visibility_activation()

	if not is_active:
		# Before activation: enemy stays idle + gravity works
		if not is_on_floor():
			velocity.y += GRAVITY * delta

		velocity.x = 0.0
		animated_sprite.play("IDLE")
		move_and_slide()
		return
	# ─────────────────────────────────────────────


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
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		velocity.x = move_toward(velocity.x, 0.0, SPEED * delta)
		animated_sprite.play("IDLE")
		move_and_slide()
		return

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Knockback window
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

	# Avoid exact overlapping
	var overlap_x_threshold := 6.0
	var overlap_y_threshold := 24.0
	if vertical_distance < overlap_y_threshold and abs_distance > 1.0 and abs_distance < overlap_x_threshold:
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
			# Far → chance to lunge jump
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
		# While attacking, slow movement
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 2.0 * delta)

	# Keep hitbox in front of enemy
	if attack_hitbox:
		var sign_x := -1.0 if animated_sprite.flip_h else 1.0
		attack_hitbox.position = Vector2(_attack_hitbox_base_position.x * sign_x, _attack_hitbox_base_position.y)

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
	if is_dead:
		return
	
	# Spawn blood splash at enemy position
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
		# Remove enemy from collision layers so it no longer blocks player/bullets,
		# but keep its mask so it can still collide with the ground and fall normally.
		collision_layer = 0
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
	
func _check_visibility_activation():
	if has_been_visible_with_player:
		return  # Already activated once
	
	# If visibility notifiers are missing for some reason, fall back to always-active
	if notifier == null or player_notifier == null:
		has_been_visible_with_player = true
		is_active = true
		return
	
	# Activate once this enemy is on screen
	if notifier.is_on_screen():
		has_been_visible_with_player = true
		is_active = true
