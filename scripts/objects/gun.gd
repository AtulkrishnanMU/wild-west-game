extends Area2D

@export var can_be_picked_up: bool = true
@export var use_gravity: bool = false
@export var initial_velocity: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
var _float_tween: Tween = null
var _velocity: Vector2 = Vector2.ZERO
var _ground_y: float = 0.0

func _ready() -> void:
	if not can_be_picked_up and use_gravity:
		# Thrown dummy gun: start with given velocity, let physics-style motion handle it
		_velocity = initial_velocity
		_ground_y = global_position.y + 12.0
	else:
		# Normal pickup: gentle floating motion up and down
		var start_pos := global_position
		var up_pos := start_pos + Vector2(0.0, -3.0)
		var down_pos := start_pos + Vector2(0.0, 3.0)
		_float_tween = create_tween()
		_float_tween.set_loops()
		_float_tween.tween_property(self, "global_position", up_pos, 0.35)
		_float_tween.tween_property(self, "global_position", down_pos, 0.35)


func _start_floating() -> void:
	# Restart floating animation
	var start_pos := global_position
	var up_pos := start_pos + Vector2(0.0, -3.0)
	var down_pos := start_pos + Vector2(0.0, 3.0)
	_float_tween = create_tween()
	_float_tween.set_loops()
	_float_tween.tween_property(self, "global_position", up_pos, 0.35)
	_float_tween.tween_property(self, "global_position", down_pos, 0.35)

func _physics_process(delta: float) -> void:
	# Simple ballistic motion for thrown dummy guns
	if not can_be_picked_up and use_gravity:
		# Apply gravity
		_velocity.y += 900.0 * delta
		global_position += _velocity * delta
		# Light horizontal damping so it slows down a bit
		_velocity.x = lerp(_velocity.x, 0.0, 2.0 * delta)
		# Stop when we "hit" the ground level
		if global_position.y >= _ground_y:
			global_position.y = _ground_y
			use_gravity = false
			_velocity = Vector2.ZERO

func _on_body_entered(body: Node) -> void:
	# Player picks up the gun (only if this instance is pickable)
	if body.name != "Player":
		return
	if not can_be_picked_up:
		return
	# Defer pickup logic to avoid modifying physics state during callback
	call_deferred("_do_pickup", body)

func _do_pickup(player: Node) -> void:
	# Stop floating and disable collisions
	if _float_tween and _float_tween.is_valid():
		_float_tween.kill()
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	# Tell the player to pick up the gun and check if successful
	if player.has_method("pickup_gun"):
		var success = player.pickup_gun()
		if success:
			# Only remove pickup if player successfully picked it up
			queue_free()
		else:
			# Player couldn't pick up gun (max backup reached), restore collision
			if collision_shape:
				collision_shape.set_deferred("disabled", false)
			# Restart floating animation
			_start_floating()
