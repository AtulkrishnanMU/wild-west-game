extends "res://scripts/characters/enemy.gd"
class_name ShooterEnemy

# Shooter enemies (ranged) stay in place during attacks

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

func _get_attack_movement(delta: float) -> void:
	# While attacking, stay in place (no movement)
	velocity.x = CharacterUtils.apply_smooth_movement(self, 0.0, SPEED, delta, ACCELERATION * 2.0, DECELERATION * 2.0, AIR_ACCELERATION)
