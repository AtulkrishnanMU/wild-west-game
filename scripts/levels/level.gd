extends Node2D

# Shared UI helpers for main and endless levels
const BULLET_ICON_TEXTURE_PATH := "res://assets/icons/bullet-icon.png"
const DEFAULT_MUSIC_VOLUME_DB := -8.0

# These are expected to be set by child scripts via @onready vars
var player: Node = null
var health_bar: ProgressBar = null
var cash_label: Label = null
var health_percent_label: Label = null
var bullet_icons: HBoxContainer = null

# Common level variables
var camera: Camera2D = null
var ui_layer: CanvasLayer = null

# Camera follow settings
var camera_follow_speed: float = 12.0
var camera_follow_enabled: bool = true

# Common UI setup function
func setup_ui() -> void:
	# Connect player signals if available
	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)
		if player.has_signal("cash_changed"):
			player.cash_changed.connect(_on_player_cash_changed)
		if player.has_signal("bullets_changed"):
			player.bullets_changed.connect(_on_player_bullets_changed)
		
		# Initialize UI to current player state
		_on_player_health_changed(player.health, player.MAX_HEALTH)
		_on_player_cash_changed(player.cash)
	
	# Apply pixel font to UI elements
	var ui_font := load("res://fonts/PixelOperator8.ttf")
	if ui_font:
		if health_bar:
			health_bar.add_theme_font_override("font", ui_font)
		if cash_label:
			cash_label.add_theme_font_override("font", ui_font)
		if health_percent_label:
			health_percent_label.add_theme_font_override("font", ui_font)
	
	# Configure progress bars
	if health_bar:
		health_bar.show_percentage = false

# Common setup function
func setup_level() -> void:
	# Setup music if present
	setup_music()
	
	# Setup camera if present
	setup_camera()

# Setup music with common settings
func setup_music() -> void:
	var music := get_node_or_null("Music")
	if music and music.stream:
		music.stream.loop = true
		music.volume_db = DEFAULT_MUSIC_VOLUME_DB

# Setup camera with common settings
func setup_camera() -> void:
	camera = get_node_or_null("Camera2D")
	if camera and player:
		camera.make_current()

# Common process function for camera following and UI updates
func process_level(delta: float) -> void:
	# Camera follow logic
	if camera_follow_enabled and camera and player:
		camera.global_position = camera.global_position.lerp(player.global_position, camera_follow_speed * delta)
	

# Base enemy spawning functionality
func spawn_enemy_around_player(enemy_scene: PackedScene, min_distance: float = 120.0, max_distance: float = 420.0) -> Node:
	if enemy_scene == null:
		return null
	
	var enemy := enemy_scene.instantiate()
	if enemy == null:
		return null
	
	var scene := get_tree().current_scene
	if scene == null:
		return null
	
	# Spawn around the player horizontally; fall back to origin if player is missing
	var base_pos: Vector2 = Vector2.ZERO
	if player:
		base_pos = player.global_position
	
	var offset_x := randf_range(-max_distance, max_distance)
	# Ensure enemies do not spawn too close to the player
	if abs(offset_x) < min_distance:
		offset_x = sign(offset_x if offset_x != 0.0 else 1.0) * min_distance
	
	var spawn_pos := base_pos + Vector2(offset_x, 0.0)
	enemy.global_position = spawn_pos
	
	# Track kills via Enemy's enemy_killed signal, if present
	if enemy.has_signal("enemy_killed"):
		print("[LEVEL] Connecting enemy_killed signal for: ", enemy.name, " (player is: ", player.name if player else "null", ")")
		enemy.connect("enemy_killed", _on_enemy_killed)
		
		# Also connect directly to player if available (more reliable)
		if player and player.has_method("gain_health_from_kill_with_enemy"):
			print("[LEVEL] Connecting enemy directly to player for health gain")
			enemy.connect("enemy_killed", player.gain_health_from_kill_with_enemy)
	else:
		print("[LEVEL] Enemy has no enemy_killed signal: ", enemy.name)
	
	scene.add_child(enemy)
	return enemy

# Common enemy killed handler
func _on_enemy_killed(enemy: Node) -> void:
	print("[LEVEL] Enemy killed: ", enemy.name)
	# Give player 5% health for each enemy kill
	if player and player.has_method("gain_health_from_kill"):
		print("[LEVEL] Calling gain_health_from_kill on player")
		player.gain_health_from_kill()
	else:
		print("[LEVEL] Player reference missing or no gain_health_from_kill method")

func _on_player_health_changed(current: int, max_value: int) -> void:
	var ratio: float = 0.0
	if max_value > 0:
		ratio = float(current) / float(max_value)
	if health_bar != null:
		health_bar.max_value = max_value
		health_bar.value = current
		if ratio > 0.6:
			health_bar.modulate = Color(0.2, 0.9, 0.2)
		elif ratio > 0.3:
			health_bar.modulate = Color(0.95, 0.8, 0.2)
		else:
			health_bar.modulate = Color(0.95, 0.2, 0.2)
	if health_percent_label != null and max_value > 0:
		health_percent_label.text = str(int(round(ratio * 100.0))) + "%"


func _on_player_cash_changed(current: int) -> void:
	if cash_label != null:
		cash_label.text = "CASH: " + str(current)


func _on_player_bullets_changed(current: int, max_value: int) -> void:
	_update_bullet_icons(current)


func _update_bullet_icons(current: int) -> void:
	if bullet_icons == null:
		return
	bullet_icons.add_theme_constant_override("separation", 10)
	for child in bullet_icons.get_children():
		child.queue_free()
	var tex := load(BULLET_ICON_TEXTURE_PATH)
	if tex == null:
		return
	for i in range(current):
		var icon := TextureRect.new()
		icon.texture = tex
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.custom_minimum_size = Vector2(8, 8)
		bullet_icons.add_child(icon)
