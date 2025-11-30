extends Area2D

@onready var dust_splash: Node2D = get_parent()

func _ready() -> void:
	# Connect to area entered signals for collision detection
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _on_body_entered(body: Node) -> void:
	# When dust particles hit a solid body (walls, ground), create a dust decal
	if body.is_in_group("walls") or body.is_in_group("ground") or body is TileMap:
		_create_dust_at_collision()

func _on_area_entered(area: Area2D) -> void:
	# Handle collision with other areas if needed
	pass

func _create_dust_at_collision() -> void:
	# Create dust decal at collision point
	if dust_splash and dust_splash.has_method("create_dust_decal"):
		var collision_point = global_position
		var normal = Vector2.UP  # Default normal, can be calculated based on collision surface
		dust_splash.create_dust_decal(collision_point, normal)
