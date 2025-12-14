extends "res://scripts/levels/level.gd"

# Level1 specific implementation
# This script extends the base level functionality

func _ready():
	# Call parent _ready() which will auto-assign nodes and setup everything
	super._ready()
	
	# Level1 specific initialization can go here
	print("Level1 loaded")

func _process(delta: float) -> void:
	# Use common level process for UI updates (camera follow, etc.)
	process_level(delta)
