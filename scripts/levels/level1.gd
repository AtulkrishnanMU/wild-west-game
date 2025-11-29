extends "res://scripts/levels/level.gd"

func _ready() -> void:
	# Find the player in the scene
	player = $Player
	
	# Assign UI references to parent class variables
	health_bar = $UI/HealthBar
	heal_cooldown_bar = $UI/HealCooldownBar
	cash_label = $UI/CashLabel
	health_percent_label = $UI/HealthPercentLabel
	bullet_icons = $UI/BulletIcons
	ui_layer = $UI
	
	# Use common UI setup (now with player available)
	setup_ui()
	
	# Use common level setup
	setup_level()
	
	print("Level1 initialized with UI connections")

func _process(delta: float) -> void:
	# Use common level process for UI updates (camera follow, heal cooldown, etc.)
	process_level(delta)
