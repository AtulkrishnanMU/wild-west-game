extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

signal health_changed(current: int, max: int)

const MAX_HEALTH := 200
var health: int = MAX_HEALTH

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# State flags
var is_attacking := false
var is_hurt := false
var is_dead := false

func _ready() -> void:
	randomize()
	# Connect once at startup
	animated_sprite.animation_finished.connect(_on_animation_finished)
	emit_signal("health_changed", health, MAX_HEALTH)


func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# ——— DEAD STATE ———
	if is_dead:
		# Slowly stop horizontal movement
		velocity.x = move_toward(velocity.x, 0, SPEED)
		move_and_slide()
		return  # Ignore all input and other animations when dead

	# ——— INPUT & MOVEMENT (only if alive) ———
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_hurt:
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		velocity.x = direction * SPEED
		animated_sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Attack input
	if Input.is_action_just_pressed("attack") and not is_attacking and not is_hurt:
		if direction != 0:
			_start_attack_moving()
		else:
			_start_attack_idle()

	# ——— ANIMATION SELECTION ———
	if is_attacking:
		# Let the attack animation run (controlled by _start_attack_* functions)
		pass
	elif is_hurt:
		animated_sprite.play("HURT")
	else:
		if not is_on_floor():
			animated_sprite.play("JUMP")
		elif direction != 0:
			animated_sprite.play("RUN")
		else:
			animated_sprite.play("IDLE")

	move_and_slide()


# ——— ATTACK STARTERS ———
func _start_attack_idle() -> void:
	is_attacking = true
	var attack_anim := "ATTACK1" if randf() < 0.5 else "ATTACK2"
	animated_sprite.play(attack_anim)

func _start_attack_moving() -> void:
	is_attacking = true
	animated_sprite.play("ATTACK3")


# ——— ANIMATION FINISHED CALLBACK ———
func _on_animation_finished() -> void:
	var anim_name = animated_sprite.animation

	# DEATH: Play once → stop forever on last frame
	if anim_name == "DEATH":
		animated_sprite.stop()
		# Force the last frame in case it stopped slightly before/after
		var frame_count = animated_sprite.sprite_frames.get_frame_count("DEATH")
		animated_sprite.frame = frame_count - 1
		return

	# ATTACK finished → allow new actions
	if anim_name.begins_with("ATTACK"):
		is_attacking = false
		# Optional: snap to correct animation immediately
		if is_on_floor() and velocity.x == 0:
			animated_sprite.play("IDLE")

	# HURT finished → recover
	elif anim_name == "HURT":
		is_hurt = false


# ——— DAMAGE & DEATH ———
func take_damage(amount: int) -> void:
	if is_dead:
		return

	health = max(health - amount, 0)
	emit_signal("health_changed", health, MAX_HEALTH)

	if health <= 0:
		# Die only once
		is_dead = true
		is_attacking = false
		is_hurt = false
		animated_sprite.play("DEATH")  # Triggers once → handled in _on_animation_finished
	else:
		# Normal hit reaction
		is_hurt = true
		animated_sprite.play("HURT")
