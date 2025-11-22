extends Area2D

@export var speed: float = 520.0
@export var damage: int = 20
@export var safe_enemy_player_distance: float = 32.0
@export var safe_enemy_shooter_distance: float = 100.0
var direction: Vector2 = Vector2.RIGHT
var shooter: Node = null

func _ready() -> void:
	direction = direction.normalized()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
	_apply_damage(area)

func _on_body_entered(body: Node) -> void:
	_apply_damage(body)

func _apply_damage(target: Node) -> void:
	if not is_instance_valid(target):
		return
	# Do not damage the shooter who fired this bullet
	if target == shooter:
		return
	# Do not damage enemies that are currently very close to the player
	if target.is_in_group("enemies") and shooter and shooter.is_in_group("enemies"):
		var player := _get_player()
		if player and player.global_position.distance_to(target.global_position) < safe_enemy_player_distance:
			return
		# Also do not damage enemies that are very close to the shooter
		if shooter.global_position.distance_to(target.global_position) < safe_enemy_shooter_distance:
			return
	if target.has_method("take_damage"):
		target.take_damage(damage)
	queue_free()

func _get_player() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("Player")
