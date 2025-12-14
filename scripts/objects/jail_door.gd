extends Node2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_area = $CollisionArea

var is_open = false
var is_locked = true
var door_sound_player: AudioStreamPlayer2D

func _ready():
	# Create audio player for door sound
	door_sound_player = AudioStreamPlayer2D.new()
	add_child(door_sound_player)
	door_sound_player.stream = load("res://sounds/door-open.mp3")
	
	# Connect area detection signals
	collision_area.body_entered.connect(_on_body_entered)
	collision_area.body_exited.connect(_on_body_exited)
	
	# Set up collision layers to detect player (player is on layer 2)
	collision_area.collision_layer = 0  # Don't collide with anything
	collision_area.collision_mask = 2  # Only detect player (layer 2)
	
	# Start with door unlocked so it opens on collision
	is_locked = false


func _on_body_entered(body):
	if body.name == "Player" and not is_locked:
		# Player collided with door - play open animation
		open_door()

func _on_body_exited(body):
	if body.name == "Player":
		# Player left the area
		pass

func open_door():
	if not is_open and not is_locked:
		is_open = true
		animated_sprite.play("open")
		# Play door sound effect
		if door_sound_player:
			door_sound_player.play()

func close_door():
	if is_open:
		is_open = false
		animated_sprite.play("closing")
		await animated_sprite.animation_finished
		animated_sprite.play("closed")

func unlock_door():
	is_locked = false

func lock_door():
	is_locked = true
