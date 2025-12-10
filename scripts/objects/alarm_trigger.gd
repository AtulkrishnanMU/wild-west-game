extends Area2D
class_name AlarmTrigger

signal alarm_triggered

var alarm_triggered_once: bool = false

func _ready() -> void:
	# Connect the body_entered signal
	body_entered.connect(_on_body_entered)
	
	# Set up collision layers to detect player (player is on layer 2)
	collision_layer = 0
	collision_mask = 2  # Player layer
	
	print("AlarmTrigger ready at position: ", global_position)
	print("Collision mask: ", collision_mask)
	print("Collision layer: ", collision_layer)

func _on_body_entered(body: Node) -> void:
	print("Body entered trigger: ", body.name, " - Is player: ", body.name == "Player")
	
	# Check if it's the player and alarm hasn't been triggered yet
	if body.name == "Player" and not alarm_triggered_once:
		alarm_triggered_once = true
		print("Alarm triggered by player crossing point!")
		alarm_triggered.emit()
		
		# Optionally disable the trigger after use
		set_deferred("monitoring", false)
