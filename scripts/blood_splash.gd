extends Node2D

@onready var particles: GPUParticles2D = $Particles

func _ready() -> void:
	if particles:
		particles.emitting = true
	# Auto-free after particles finish
	await get_tree().create_timer(0.8).timeout
	queue_free()
