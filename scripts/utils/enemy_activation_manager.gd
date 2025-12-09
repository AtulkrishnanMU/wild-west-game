class_name EnemyActivationManager
extends RefCounted

# Singleton-like instance
static var _instance: EnemyActivationManager
static var instance: EnemyActivationManager:
	get:
		if _instance == null:
			_instance = EnemyActivationManager.new()
		return _instance

# Cached references
var player: CharacterBody2D
var player_notifier: VisibleOnScreenNotifier2D
var scene_tree: SceneTree
var all_enemies: Array[Enemy] = []
var active_enemies: Array[Enemy] = []

# Performance optimization
var last_update_time: float = 0.0
var update_interval: float = 0.1  # Update every 100ms instead of every frame

func _init():
	pass

func setup(p: CharacterBody2D):
	player = p
	player_notifier = p.get_node("VisibilityNotifier2D")
	scene_tree = p.get_tree()
	# Cache all enemies initially
	refresh_enemy_cache()

func refresh_enemy_cache():
	all_enemies.clear()
	var enemies = scene_tree.get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy is Enemy:
			all_enemies.append(enemy)

func register_enemy(enemy: Enemy):
	if enemy not in all_enemies:
		all_enemies.append(enemy)

func unregister_enemy(enemy: Enemy):
	all_enemies.erase(enemy)
	active_enemies.erase(enemy)

func update_activation(delta: float) -> void:
	last_update_time += delta
	if last_update_time < update_interval:
		return
	
	last_update_time = 0.0
	
	# Only check enemies that haven't been activated yet
	for enemy in all_enemies:
		if enemy.has_been_visible_with_player:
			continue
		
		# Check if both enemy and player are visible
		if _should_activate_enemy(enemy):
			activate_enemy(enemy)

func _should_activate_enemy(enemy: Enemy) -> bool:
	# If visibility notifiers are missing, activate immediately
	if enemy.notifier == null or player_notifier == null:
		return true
	
	# Check if both are on screen (original condition)
	var both_on_screen = enemy.notifier.is_on_screen() and player_notifier.is_on_screen()
	
	# Check if player and enemy are on the same horizontal level (line of sight)
	var same_horizontal_level = _is_same_horizontal_level(enemy)
	
	# Activate only if BOTH conditions are met: on screen AND same horizontal level
	return both_on_screen and same_horizontal_level

# Activate enemy
func activate_enemy(enemy: Enemy):
	enemy.has_been_visible_with_player = true
	enemy.is_active = true
	if enemy not in active_enemies:
		active_enemies.append(enemy)

func _is_same_horizontal_level(enemy: Enemy) -> bool:
	# Check if player and enemy are on the same horizontal level
	# Define a threshold for what counts as "same level" (in pixels)
	var horizontal_threshold = 50.0  # Adjust this value as needed
	
	var vertical_distance = abs(enemy.global_position.y - player.global_position.y)
	return vertical_distance <= horizontal_threshold

func get_active_enemies() -> Array[Enemy]:
	return active_enemies.filter(func(e): return e.is_active and not e.is_dead)

func get_enemies_in_range(position: Vector2, range_distance: float) -> Array[Enemy]:
	var nearby_enemies: Array[Enemy] = []
	for enemy in active_enemies:
		if enemy.is_active and not enemy.is_dead:
			var distance = position.distance_to(enemy.global_position)
			if distance <= range_distance:
				nearby_enemies.append(enemy)
	return nearby_enemies

func cleanup_dead_enemies():
	var to_remove: Array[Enemy] = []
	for enemy in active_enemies:
		if enemy.is_dead:
			to_remove.append(enemy)
	
	for enemy in to_remove:
		unregister_enemy(enemy)
