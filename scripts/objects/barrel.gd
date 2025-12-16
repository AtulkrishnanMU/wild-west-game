extends RigidBody2D

func _ready() -> void:
	# Essential physics properties (match character_vs_rigid defaults)
	gravity_scale = 1.0  # Default gravity scale
	mass = 1.0          # Default mass
	freeze = false      # Not frozen

func _on_body_entered(body):
	if body.name == "Player":
		prints(name, "collided with player")
