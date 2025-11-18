extends CharacterBody2D

const SPEED: float = 150.0
const GRAVITY: float = 900.0
const ATTACK_RANGE: float = 18.0          # When enemy stops chasing and starts attacking
const DAMAGE_H_RANGE: float = 45.0        # Tight but fair – enemy must be close
const DAMAGE_V_RANGE: float = 50.0        # Good vertical coverage (jumping, etc.)
const DAMAGE_COOLDOWN: float = 0.20       # Prevents insane damage spam

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var player: CharacterBody2D = get_parent().get_node("Player")

var is_attacking: bool = false
var damage_cooldown_timer: float = 0.0

func _ready() -> void:
	animated_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	if player == null:
		animated_sprite.play("IDLE")
		return

	# If the player is dead, stop attacking and stay idle
	if player.is_dead:
		is_attacking = false
		velocity.x = move_toward(velocity.x, 0.0, SPEED * delta)
		animated_sprite.play("IDLE")
		move_and_slide()
		return

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Cooldown countdown
	if damage_cooldown_timer > 0.0:
		damage_cooldown_timer -= delta

	var to_player: Vector2 = player.global_position - global_position
	var distance_x: float = to_player.x
	var abs_distance: float = abs(distance_x)
	var direction: float = sign(distance_x)

	# ── Movement & Attack Logic ──
	if not is_attacking:
		if abs_distance > ATTACK_RANGE:
			# Chase
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

	animated_sprite.play(attack_anim)


func _start_attack_running() -> void:
	if is_attacking:
		return
	is_attacking = true
	animated_sprite.play("ATTACK3")


func _on_animation_finished() -> void:
	if animated_sprite.animation.begins_with("ATTACK"):
		# Apply damage ONCE at the end of the attack if the player is in range
		if _is_player_in_attack_range():
			_apply_damage_to_player()
			damage_cooldown_timer = DAMAGE_COOLDOWN
		is_attacking = false
		if is_on_floor() and abs(velocity.x) < 10.0:
			animated_sprite.play("IDLE")


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

	player.take_damage(dmg)
