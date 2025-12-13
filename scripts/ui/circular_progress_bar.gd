extends Control

@export var max_value: float = 100.0
@export var value: float = 0.0
@export var color: Color = Color.WHITE  # White color
@export var bg_color: Color = Color(0.1, 0.1, 0.1, 0.8)
@export var thickness: float = 8.0
@export var radius: float = 20.0

var target_value: float = 0.0
var animation_speed: float = 100.0  # Speed of the quick drop animation (100% / 1s = 100% per second)

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	# Smooth animation towards target value
	if value != target_value:
		value = move_toward(value, target_value, animation_speed * delta)
		queue_redraw()
		
		# Stop processing when animation is complete
		if abs(value - target_value) < 0.1:
			value = target_value
			set_process(false)

func set_progress_from_cooldown(cooldown_time: float, max_cooldown: float) -> void:
	# Convert cooldown time to percentage (0 to 100)
	var new_target_value = (1.0 - (cooldown_time / max_cooldown)) * 100.0
	new_target_value = clamp(new_target_value, 0.0, max_value)
	
	# Always animate towards the target value
	target_value = new_target_value
	set_process(true)  # Start animation

func quick_reset_to_zero() -> void:
	# Called when bat is thrown - quick animation to 0
	target_value = 0.0
	set_process(true)

func _draw() -> void:
	var center = Vector2(size.x / 2, size.y / 2)
	
	# Draw background circle
	draw_arc(center, radius, 0, TAU, 64, bg_color, thickness, false)
	
	# Draw progress arc
	if value > 0:
		var progress_angle = (value / max_value) * TAU
		# Start from top (-90 degrees) and go clockwise
		draw_arc(center, radius, -PI/2, -PI/2 + progress_angle, 64, color, thickness, false)
