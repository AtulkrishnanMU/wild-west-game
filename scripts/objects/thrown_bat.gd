class_name ThrownBat
extends Area2D

const CharacterUtils = preload("res://scripts/utils/character_utils.gd")

const BAT_SPEED = 600.0
const BAT_RETURN_SPEED = 800.0
const BAT_TRAVEL_DISTANCE = 400.0
const SPIN_SPEED = 20.0  # Rotations per second

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var direction: Vector2 = Vector2.RIGHT
var start_position: Vector2
var is_returning: bool = false
var thrower: Node2D
var rotation_angle: float = 0.0
var damage: int = 25

func _ready() -> void:
	start_position = global_position
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	# Spin the bat
	rotation_angle += SPIN_SPEED * 2 * PI * delta
	sprite.rotation = rotation_angle
	
	# Move the bat
	if is_returning:
		# Return to thrower
		if thrower and is_instance_valid(thrower):
			var to_thrower = thrower.global_position - global_position
			if to_thrower.length() < 30.0:
				# Bat has returned to player
				_return_to_player()
			else:
				# Move toward player
				position += to_thrower.normalized() * BAT_RETURN_SPEED * delta
		else:
			# Thrower no longer exists, just destroy the bat
			queue_free()
	else:
		# Moving forward
		position += direction * BAT_SPEED * delta
		
		# Check if reached max distance
		if global_position.distance_to(start_position) >= BAT_TRAVEL_DISTANCE:
			is_returning = true

func _on_body_entered(body: Node) -> void:
	if body == thrower:
		return  # Don't hit the thrower
		
	# Check if enemy is inactive - if on screen, damage and activate it
	if body.is_in_group("enemies") and ("is_active" in body) and not body.is_active:
		# Check if the inactive enemy is visible on screen
		var notifier = body.get_node_or_null("VisibilityNotifier2D")
		if notifier and notifier.is_on_screen():
			# Enemy is on screen but inactive - damage it and activate it
			if body.has_method("take_damage"):
				body.take_damage(damage)
				# Activate the enemy after taking damage
				body.is_active = true
				body.has_been_visible_with_player = true
			# Apply knockback
			var knockback_dir = sign(body.global_position.x - global_position.x)
			CharacterUtils.apply_knockback(body, knockback_dir, 300.0, 0.2)
			# Create impact effect
			_create_impact_effect(body.global_position)
			# Start returning after hitting something
			if not is_returning:
				is_returning = true
			return
		else:
			# Enemy is inactive and not on screen - don't damage
			return
		
	if body.has_method("take_damage"):
		body.take_damage(damage)
		# Apply knockback
		var knockback_dir = sign(body.global_position.x - global_position.x)
		CharacterUtils.apply_knockback(body, knockback_dir, 300.0, 0.2)
		
		# Create impact effect
		_create_impact_effect(body.global_position)
		
		# Start returning after hitting something
		if not is_returning:
			is_returning = true

func _on_area_entered(area: Area2D) -> void:
	# Handle hitting other areas (like enemy hitboxes)
	var owner = area.get_parent()
	if owner and owner != thrower:
		# Check if enemy is inactive - if on screen, damage and activate it
		if owner.is_in_group("enemies") and ("is_active" in owner) and not owner.is_active:
			# Check if the inactive enemy is visible on screen
			var notifier = owner.get_node_or_null("VisibilityNotifier2D")
			if notifier and notifier.is_on_screen():
				# Enemy is on screen but inactive - damage it and activate it
				if owner.has_method("take_damage"):
					owner.take_damage(damage)
					# Activate the enemy after taking damage
					owner.is_active = true
					owner.has_been_visible_with_player = true
				# Apply knockback
				var knockback_dir = sign(owner.global_position.x - global_position.x)
				CharacterUtils.apply_knockback(owner, knockback_dir, 300.0, 0.2)
				# Create impact effect
				_create_impact_effect(owner.global_position)
				# Start returning after hitting something
				if not is_returning:
					is_returning = true
				return
			else:
				# Enemy is inactive and not on screen - don't damage
				return
		
		if owner.has_method("take_damage"):
			owner.take_damage(damage)
			var knockback_dir = sign(owner.global_position.x - global_position.x)
			CharacterUtils.apply_knockback(owner, knockback_dir, 300.0, 0.2)
			_create_impact_effect(owner.global_position)
			
			if not is_returning:
				is_returning = true

func _create_impact_effect(pos: Vector2) -> void:
	# Create blood splash effect if available
	var blood_scene = preload("res://scenes/objects/blood_splash.tscn")
	if blood_scene:
		var blood = blood_scene.instantiate()
		var scene = get_tree().current_scene
		if scene:
			blood.global_position = pos
			var blood_direction = (pos - global_position).normalized()
			blood.set_direction(blood_direction)
			
			# Add blood to scene at correct position
			var wall_node = scene.get_node_or_null("Wall")
			var background_node = scene.get_node_or_null("background")
			
			if wall_node and background_node:
				var blood_index = wall_node.get_index() + 1
				scene.add_child(blood)
				scene.move_child(blood, blood_index)
			elif wall_node:
				var blood_index = wall_node.get_index() + 1
				scene.add_child(blood)
				scene.move_child(blood, blood_index)
			else:
				scene.add_child(blood)

func _return_to_player() -> void:
	if thrower and is_instance_valid(thrower):
		if thrower.has_method("_on_bat_returned"):
			thrower._on_bat_returned()
	queue_free()
