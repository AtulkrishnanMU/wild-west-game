extends Node2D

var door_sound: AudioStreamPlayer2D
var player_in_area: bool = false
var last_sound_time: float = 0.0
var sound_cooldown: float = 1.0  # Prevent sound spam (1 second cooldown)

@onready var area: Area2D = $Area2D

func _ready():
	# Create audio player for door sound
	door_sound = AudioStreamPlayer2D.new()
	add_child(door_sound)
	door_sound.stream = load("res://sounds/door-open.mp3")
	print("ColliderNoCollision: Audio player created and sound loaded")
	
	# Configure Area2D collision layers to detect player
	# Layer 1: Player, Layer 2: Enemies, Layer 3: Objects, Layer 4: Environment
	# Set Area2D to monitor layer 1 (player) and layer 2 (enemies)
	area.collision_layer = 0  # Don't belong to any layer
	area.collision_mask = 1 | 2  # Monitor player and enemy layers
	print("ColliderNoCollision: Area collision configured - layer: ", area.collision_layer, " mask: ", area.collision_mask)
	
	# Connect area signals
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	print("ColliderNoCollision: Area signals connected")

func _on_body_entered(body):
	print("ColliderNoCollision: Body entered: ", body.name, " - Type: ", body.get_class())
	if body.name == "Player":
		player_in_area = true
		print("ColliderNoCollision: Player detected in area")

func _on_body_exited(body):
	print("ColliderNoCollision: Body exited: ", body.name)
	if body.name == "Player":
		player_in_area = false
		print("ColliderNoCollision: Player left area")

func _check_player_position(player):
	if not player_in_area:
		return
	
	# Check cooldown to prevent sound spam
	var current_time = Time.get_time_dict_from_system().second + Time.get_time_dict_from_system().minute * 60
	if current_time - last_sound_time < sound_cooldown:
		return
	
	# Get the center of this collider
	var collider_center = global_position
	
	# Check if player is close to the center (within 50 pixels)
	var distance_to_center = player.global_position.distance_to(collider_center)
	print("ColliderNoCollision: Distance to center: ", distance_to_center)
	
	if distance_to_center < 50.0:
		# Player is in the middle, play the sound with random pitch
		print("ColliderNoCollision: Player in middle, playing sound with random pitch!")
		AudioUtils.play_random_pitch(door_sound, 0.8, 1.2)  # Random pitch between 0.8 and 1.2
		last_sound_time = current_time
		print("ColliderNoCollision: Door sound played at middle of collider_no_collision")

func _process(delta):
	# Continuously check player position if they're in the area
	if player_in_area:
		var player = get_tree().get_first_node_in_group("player")
		if not player:
			# Try getting player by name if not in group
			player = get_tree().current_scene.get_node_or_null("Player")
		if player:
			_check_player_position(player)
