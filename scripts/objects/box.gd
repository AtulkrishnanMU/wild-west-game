extends "res://scripts/objects/destructible_object.gd"

# Box destructible object
# Takes 2 hits to break

func get_max_health() -> int:
	return 2  # Box takes 2 hits to break
