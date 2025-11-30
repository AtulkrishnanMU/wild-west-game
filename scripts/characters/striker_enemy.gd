extends "res://scripts/characters/enemy.gd"
class_name StrikerEnemy

# Striker enemies (melee) move closer during attacks if player not in hitbox

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

func _get_attack_movement(delta: float) -> void:
	# While attacking, slow movement but move closer if player not in hitbox
	if not _player_in_attack_hitbox and player:
		# Move toward player if not in range
		var attack_to_player: Vector2 = player.global_position - global_position
		var attack_direction: float = sign(attack_to_player.x)
		var approach_speed = SPEED * 0.3  # Slow approach during attack
		velocity.x = CharacterUtils.apply_smooth_movement(self, attack_direction * approach_speed, approach_speed, delta, ACCELERATION * 2.0, DECELERATION * 2.0, AIR_ACCELERATION)
	else:
		# Normal slow movement when in range
		velocity.x = CharacterUtils.apply_smooth_movement(self, 0.0, SPEED, delta, ACCELERATION * 2.0, DECELERATION * 2.0, AIR_ACCELERATION)
