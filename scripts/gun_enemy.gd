extends "res://scripts/enemy.gd"

const BULLET_SCENE := preload("res://scenes/bullet.tscn")
const GUN_SHOT_SOUND := preload("res://sounds/gun-shot.mp3")

@onready var gun_sprite: Sprite2D = $Gun
var _aim_tween: Tween = null
var _recoil_tween: Tween = null
var _gun_base_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Call base enemy _ready first
	super._ready()
	# Make gun enemies start attacking (stop running) from further away
	ATTACK_RANGE_DISTANCE = 100.0
	# Make gun enemies jump from further away than default
	FAR_JUMP_DISTANCE = 220.0
	# Adjust gun pivot so that rotation happens around the horizontal middle of the gun
	if gun_sprite and gun_sprite.texture:
		gun_sprite.centered = true
		# With centered = true, an offset of (0, 0) keeps the pivot at the texture center
		gun_sprite.offset = Vector2.ZERO
		_gun_base_position = gun_sprite.position

func _physics_process(delta: float) -> void:
	# Run base enemy movement/attack logic
	super._physics_process(delta)
	# Then update gun aiming
	_update_gun_aim()

func _update_gun_aim() -> void:
	if player == null or gun_sprite == null:
		return
	var to_player: Vector2 = player.global_position - gun_sprite.global_position
	if to_player.length() == 0.0:
		return
	var angle: float = to_player.angle()

	# Smoothly tween gun rotation toward the desired angle
	if _aim_tween and _aim_tween.is_valid():
		_aim_tween.kill()
	_aim_tween = create_tween()
	_aim_tween.set_trans(Tween.TRANS_SINE)
	_aim_tween.set_ease(Tween.EASE_OUT)
	_aim_tween.tween_property(gun_sprite, "rotation", angle, 0.1)

	var degrees: float = rad_to_deg(angle)
	var facing_right: bool = abs(degrees) <= 90.0
	animated_sprite.flip_h = not facing_right
	# Flip the gun vertically so it stays visually correct when the enemy turns
	if animated_sprite.flip_h:
		gun_sprite.scale.y = -1.0
	else:
		gun_sprite.scale.y = 1.0

func _start_attack_close() -> void:
	if is_attacking:
		return
	is_attacking = true
	if slash_player:
		AudioUtils.play_random_pitch(slash_player, 0.7, 1.6)
	animated_sprite.play("ATTACK")

func _start_attack_running() -> void:
	_start_attack_close()

func _on_animation_finished() -> void:
	var anim = animated_sprite.animation
	if anim == "ATTACK":
		_fire_bullet()
		damage_cooldown_timer = DAMAGE_COOLDOWN
		is_attacking = false
		if is_on_floor() and abs(velocity.x) < 10.0 and not is_dead:
			animated_sprite.play("IDLE")
	elif anim == "DEATH":
		animated_sprite.stop()
		animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count("DEATH") - 1

func _apply_damage_to_player() -> void:
	# Unused for gun enemy; bullets handle player damage
	pass

func _fire_bullet() -> void:
	if BULLET_SCENE == null or gun_sprite == null:
		return
	var bullet := BULLET_SCENE.instantiate()
	if bullet == null:
		return
	# Direction: from gun toward player at fire time
	var dir: Vector2 = Vector2.RIGHT
	if player:
		dir = (player.global_position - gun_sprite.global_position).normalized()
	bullet.direction = dir
	# Spawn at muzzle point: small offset along gun's current forward direction
	var muzzle_offset: float = 16.0
	var spawn_pos: Vector2 = gun_sprite.global_position + dir * muzzle_offset
	bullet.global_position = spawn_pos
	bullet.rotation = dir.angle()
	# Tag shooter so bullet won’t damage its own enemy
	bullet.shooter = self
	# Apply a small recoil on the gun in the opposite direction of the shot
	_play_gun_recoil(dir)
	# Play gun-shot sound at the gun position with random pitch
	if GUN_SHOT_SOUND:
		var scene_for_sound := get_tree().current_scene
		if scene_for_sound:
			var audio := AudioStreamPlayer2D.new()
			audio.stream = GUN_SHOT_SOUND
			audio.position = gun_sprite.global_position
			scene_for_sound.add_child(audio)
			AudioUtils.play_random_pitch(audio, 0.9, 1.2)
			audio.finished.connect(audio.queue_free)
	var scene := get_tree().current_scene
	if scene:
		scene.add_child(bullet)

func _play_gun_recoil(shot_dir: Vector2) -> void:
	if gun_sprite == null:
		return
	if _recoil_tween and _recoil_tween.is_valid():
		_recoil_tween.kill()
	_recoil_tween = create_tween()
	var recoil_distance := 4.0
	var back_pos := _gun_base_position - shot_dir.normalized() * recoil_distance
	_recoil_tween.tween_property(gun_sprite, "position", back_pos, 0.04)
	_recoil_tween.tween_property(gun_sprite, "position", _gun_base_position, 0.06)
