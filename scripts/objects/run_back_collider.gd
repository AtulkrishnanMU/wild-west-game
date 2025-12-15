extends StaticBody2D

var dialogue_played: bool = false
var player_in_area: bool = false
@onready var area: Area2D = $Area2D

func _ready():
	print("RunBackCollider: _ready() called")
	
	# Check if Area2D node exists
	if area:
		print("RunBackCollider: Area2D node found: ", area.name)
		
		# Connect area signals
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
		print("RunBackCollider: Area signals connected")
	else:
		print("RunBackCollider: ERROR - Area2D node not found!")
	
	# Set up collision layers for Area2D to detect player
	if area:
		print("RunBackCollider: Setting up collision layers")
		area.collision_layer = 0  # Don't detect other areas
		area.collision_mask = 1 | 2  # Monitor player and enemy layers (like working collider)
		print("RunBackCollider: Area2D collision_layer: ", area.collision_layer, " collision_mask: ", area.collision_mask)
	
	print("RunBackCollider: Ready complete")
	
	# Debug: Check if we can find the player in the scene
	call_deferred("_debug_check_player")

func _debug_check_player():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		print("RunBackCollider: Found player in group 'player': ", player.name, " - Type: ", player.get_class())
		print("RunBackCollider: Player position: ", player.global_position)
		print("RunBackCollider: Player collision_layer: ", player.collision_layer)
	else:
		print("RunBackCollider: Player not found in group 'player', trying by name...")
		player = get_tree().current_scene.get_node_or_null("Player")
		if player:
			print("RunBackCollider: Found player by name: ", player.name, " - Type: ", player.get_class())
			print("RunBackCollider: Player position: ", player.global_position)
			print("RunBackCollider: Player collision_layer: ", player.collision_layer)
		else:
			print("RunBackCollider: Player not found at all!")

func _on_body_entered(body):
	print("RunBackCollider: _on_body_entered() called!")
	print("RunBackCollider: Body entered: ", body.name, " - Type: ", body.get_class())
	print("RunBackCollider: Body position: ", body.global_position)
	print("RunBackCollider: Collider position: ", global_position)
	print("RunBackCollider: Distance: ", body.global_position.distance_to(global_position))
	
	# Simple check like the working collider
	if body.name == "Player":
		player_in_area = true
		print("RunBackCollider: Player detected")
		if not dialogue_played:
			# Check if dialogue is already active before showing new dialogue
			if CharacterUtils and not CharacterUtils.is_dialogue_active(false):
				print("RunBackCollider: Triggering dialogue...")
				# Use the player's show_dialogue method like the level script does
				if body.has_method("show_dialogue"):
					body.show_dialogue("I can't run away. I must move forward and teach these punks a lesson", "D:/Atul/godot/ashbreaker/wild-west-game/assets/characters/Player/Portrait.png", 0.04)
				else:
					# Fallback to CharacterUtils if character method doesn't exist
					CharacterUtils.show_dialogue(body, "I can't run away. I must move forward and teach these punks a lesson", "D:/Atul/godot/ashbreaker/wild-west-game/assets/characters/Player/Portrait.png", 0.04, false)
				print("RunBackCollider: Dialogue called successfully")
				dialogue_played = true
				print("RunBackCollider: Dialogue marked as played")
			elif CharacterUtils:
				print("RunBackCollider: Dialogue already active, skipping")
			else:
				print("RunBackCollider: ERROR - CharacterUtils not available!")
		else:
			print("RunBackCollider: Dialogue already played, ignoring")
	else:
		print("RunBackCollider: Not player, ignoring collision")

func _on_body_exited(body):
	print("RunBackCollider: _on_body_exited() called!")
	print("RunBackCollider: Body exited: ", body.name)
	
	# Reset dialogue flag when player leaves so it can trigger again
	if body.name == "Player":
		player_in_area = false
		dialogue_played = false  # Reset so dialogue can trigger again on next entry
		print("RunBackCollider: Player left area, dialogue flag reset")

func _process(delta):
	# Continuously check player position if they're in the area
	if player_in_area:
		var player = get_tree().get_first_node_in_group("player")
		if not player:
			# Try getting player by name if not in group
			player = get_tree().current_scene.get_node_or_null("Player")
		if player:
			_check_player_position(player)

func _check_player_position(player):
	if not player_in_area:
		return
	
	# Get the center of this collider
	var collider_center = global_position
	
	# Check if player is close to the center (within 50 pixels)
	var distance_to_center = player.global_position.distance_to(collider_center)
	print("RunBackCollider: Distance to center: ", distance_to_center)
	
	if distance_to_center < 50.0:
		# Player is in the middle, trigger dialogue if not already played
		print("RunBackCollider: Player in middle, triggering dialogue!")
		if not dialogue_played:
			if CharacterUtils and not CharacterUtils.is_dialogue_active(false):
				# Use the player's show_dialogue method like the level script does
				if player.has_method("show_dialogue"):
					player.show_dialogue("I can't run away. I must move forward and teach these punks a lesson", "D:/Atul/godot/ashbreaker/wild-west-game/assets/characters/Player/Portrait.png", 0.04)
				else:
					# Fallback to CharacterUtils if character method doesn't exist
					CharacterUtils.show_dialogue(player, "I can't run away. I must move forward and teach these punks a lesson", "D:/Atul/godot/ashbreaker/wild-west-game/assets/characters/Player/Portrait.png", 0.04, false)
				dialogue_played = true
				print("RunBackCollider: Dialogue triggered at middle of run_back_collider")
			elif CharacterUtils:
				print("RunBackCollider: Dialogue already active, skipping middle trigger")
