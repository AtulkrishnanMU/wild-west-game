extends Area2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
var _float_tween: Tween = null

func _ready() -> void:
	# Start gentle floating motion up and down
	var start_pos := global_position
	var up_pos := start_pos + Vector2(0.0, -3.0)
	var down_pos := start_pos + Vector2(0.0, 3.0)
	_float_tween = create_tween()
	_float_tween.set_loops()
	_float_tween.tween_property(self, "global_position", up_pos, 0.35)
	_float_tween.tween_property(self, "global_position", down_pos, 0.35)

func _on_body_entered(body: Node) -> void:
	# Player picks up the gun
	if body.name != "Player":
		return
	# Defer pickup logic to avoid modifying physics state during callback
	call_deferred("_do_pickup", body)

func _do_pickup(player: Node) -> void:
	# Stop floating and disable collisions
	if _float_tween and _float_tween.is_valid():
		_float_tween.kill()
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	# Tell the player to reveal its built-in gun, then remove this pickup
	if player.has_method("pickup_gun"):
		player.pickup_gun()
	queue_free()
