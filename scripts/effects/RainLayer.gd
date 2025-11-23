extends Node2D

const RAIN_DROP_COUNT: int = 120
const RAIN_SPEED: float = 260.0
const RAIN_MIN_LENGTH: float = 6.0
const RAIN_MAX_LENGTH: float = 14.0

var _rain_positions: Array[Vector2] = []
var _rain_lengths: Array[float] = []
# Slightly diagonal but mostly downward so coverage stays even
var _rain_direction: Vector2 = Vector2(-0.6, 3.0).normalized() # gentle down-left

func _ready() -> void:
	_rain_positions.clear()
	_rain_lengths.clear()
	var viewport_size: Vector2 = get_viewport_rect().size
	for i in RAIN_DROP_COUNT:
		# Spawn anywhere across the top edge so rain is evenly distributed
		var pos := Vector2(
			randf() * viewport_size.x,
			randf() * viewport_size.y
		)
		_rain_positions.append(pos)
		var len: float = lerp(RAIN_MIN_LENGTH, RAIN_MAX_LENGTH, randf())
		_rain_lengths.append(len)

func _process(delta: float) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	for i in RAIN_DROP_COUNT:
		var pos := _rain_positions[i]
		pos += _rain_direction * RAIN_SPEED * delta
		if pos.x < -20.0 or pos.y > viewport_size.y + 20.0:
			# Respawn along the full top edge so drops stay spread over the screen
			pos.x = randf() * viewport_size.x
			pos.y = -20.0 + randf() * 40.0
		_rain_positions[i] = pos
	queue_redraw()

func _draw() -> void:
	var color := Color(1, 1, 1, 0.7)
	for i in RAIN_DROP_COUNT:
		var start := _rain_positions[i]
		var length := _rain_lengths[i]
		var end := start + _rain_direction * length
		draw_line(start, end, color, 1.0)
