extends "res://scripts/objects/destructible_object.gd"

# Vase destructible object
# Takes 1 hit to break

func get_max_health() -> int:
	return 1  # Vase only takes 1 hit to break
