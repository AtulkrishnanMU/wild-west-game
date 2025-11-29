extends Area2D

@onready var blood_splash: Node2D = get_parent()

func _ready() -> void:
	# Connect to area entered signals for collision detection
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _on_body_entered(body: Node) -> void:
	# When blood particles hit a solid body (walls, ground), create a blood decal
	if body.is_in_group("walls") or body.is_in_group("ground") or body is TileMap:
		_create_blood_at_collision()

func _on_area_entered(area: Area2D) -> void:
	# Handle collision with other areas if needed
	pass

func _create_blood_at_collision() -> void:
	# Create blood decal at collision point
	if blood_splash and blood_splash.has_method("create_blood_decal"):
		var collision_point = global_position
		var normal = Vector2.UP  # Default normal, can be calculated based on collision surface
		blood_splash.create_blood_decal(collision_point, normal)
