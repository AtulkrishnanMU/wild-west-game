extends "res://scripts/objects/destructible_object.gd"

# Barrel destructible object
# Takes 2 hits to break

func get_max_health() -> int:
	return 2  # Barrel takes 2 hits to break
