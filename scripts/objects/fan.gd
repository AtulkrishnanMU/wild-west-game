extends Node2D

@export var rotation_speed: float = 180.0  # degrees per second
@onready var fan_blade: Sprite2D = $FanBlade
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready():
	# Set the fan blade texture
	fan_blade.texture = load("res://assets/objects/fan.png")
	fan_blade.centered = true
	
	# Set up and play the ventilator sound
	var sound_stream = load("res://sounds/ventilador.mp3")
	if sound_stream:
		sound_stream.loop = true
		audio_player.stream = sound_stream
		audio_player.play()

func _process(delta):
	# Rotate only the fan blade
	fan_blade.rotation += deg_to_rad(rotation_speed) * delta
