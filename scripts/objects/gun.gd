extends RigidBody2D

@export var can_be_picked_up: bool = true
@export var initial_velocity: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
var _float_tween: Tween = null
var _area_detector: Area2D = null
var _pickup_cooldown_timer: Timer = null
var _pickup_blocked: bool = false

func _ready() -> void:
	# Create an Area2D for pickup detection
	_area_detector = Area2D.new()
	var detector_shape = CollisionShape2D.new()
	detector_shape.shape = collision_shape.shape.duplicate()
	_area_detector.add_child(detector_shape)
	_area_detector.collision_layer = 0
	_area_detector.collision_mask = 2  # Player layer
	add_child(_area_detector)
	_area_detector.body_entered.connect(_on_body_entered)
	
	# Setup pickup cooldown timer
	_pickup_cooldown_timer = Timer.new()
	_pickup_cooldown_timer.wait_time = 1.0  # 1 second cooldown
	_pickup_cooldown_timer.one_shot = true
	_pickup_cooldown_timer.timeout.connect(_on_pickup_cooldown_finished)
	add_child(_pickup_cooldown_timer)
	
	if not can_be_picked_up:
		# Thrown dummy gun: apply initial velocity and let RigidBody2D handle physics
		linear_velocity = initial_velocity
		gravity_scale = 1.0  # Enable normal gravity
		# Set physics properties for realistic behavior
		mass = 0.3  # Lighter mass for better throwing feel
		physics_material_override = PhysicsMaterial.new()
		physics_material_override.friction = 0.7  # Good friction to stop sliding
		physics_material_override.bounce = 0.1  # Minimal bounce
		# Disable rotation for now to keep gun orientation stable
		lock_rotation = true
		# Set contact monitoring to detect when it lands
		contact_monitor = true
		max_contacts_reported = 3
	else:
		# Normal pickup: disable physics and float
		gravity_scale = 0.0  # Disable gravity
		freeze = true  # Disable physics completely
		# Start floating animation
		_start_floating()


func _start_floating() -> void:
	# Restart floating animation
	var start_pos := global_position
	var up_pos := start_pos + Vector2(0.0, -3.0)
	var down_pos := start_pos + Vector2(0.0, 3.0)
	_float_tween = create_tween()
	_float_tween.set_loops()
	_float_tween.tween_property(self, "global_position", up_pos, 0.35)
	_float_tween.tween_property(self, "global_position", down_pos, 0.35)


func _on_body_entered(body: Node) -> void:
	# Player picks up the gun (only if this instance is pickable)
	if body.name != "Player":
		return
	if not can_be_picked_up:
		return
	if _pickup_blocked:
		return  # Cooldown active, prevent pickup
	# Defer pickup logic to avoid modifying physics state during callback
	call_deferred("_do_pickup", body)

func _do_pickup(player: Node) -> void:
	# Stop floating and disable collisions
	if _float_tween and _float_tween.is_valid():
		_float_tween.kill()
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if _area_detector:
		_area_detector.set_deferred("monitoring", false)
	# Tell the player to pick up the gun and check if successful
	if player.has_method("pickup_gun"):
		var success = player.pickup_gun()
		if success:
			# Only remove pickup if player successfully picked it up
			queue_free()
		else:
			# Player couldn't pick up gun (max backup reached), start cooldown and restore collision
			_pickup_blocked = true
			_pickup_cooldown_timer.start()
			if collision_shape:
				collision_shape.set_deferred("disabled", false)
			if _area_detector:
				_area_detector.set_deferred("monitoring", true)

func _on_pickup_cooldown_finished() -> void:
	_pickup_blocked = false
	# Restart floating animation if this is a pickupable gun
	if can_be_picked_up:
		_start_floating()
