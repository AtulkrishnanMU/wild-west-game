extends Node2D

# Font configuration
const FontConfig := preload("res://scripts/utils/font_config.gd")

# Shared UI helpers for main and endless levels
const BULLET_ICON_TEXTURE_PATH := "res://assets/icons/bullet-icon.png"
const DEFAULT_MUSIC_VOLUME_DB := -8.0

# These are expected to be set by child scripts via @onready vars
var player: Node = null
var health_bar: ProgressBar = null
var cash_label: Label = null
var health_percent_label: Label = null
var reload_label: Label = null
var bullet_icons: HBoxContainer = null
var combo_number_label: Label = null
var combo_text_label: Label = null

# Common level variables
var camera: Camera2D = null
var ui_layer: CanvasLayer = null

# Camera follow settings
var camera_follow_speed: float = 12.0
var camera_follow_enabled: bool = true
# Camera zoom settings for slow-motion attacks
var camera_zoom_amount: float = 1.03  # Zoom in factor (1.1 = 10% closer)
var camera_zoom_duration: float = 0.15  # Time to zoom in/out
var _camera_zoom_tween: Tween = null
var _original_camera_zoom: float = 1.0

# Common setup function
func _connect_existing_enemies() -> void:
	# Find all existing enemies in the scene and connect them to combo system
	var enemies := get_tree().get_nodes_in_group("enemies")
	print("DEBUG: Found ", enemies.size(), " existing enemies to connect")
	for enemy in enemies:
		if enemy.has_signal("enemy_killed"):
			print("DEBUG: Connecting existing enemy to combo system")
			enemy.connect("enemy_killed", _on_enemy_killed)
		else:
			print("DEBUG: Existing enemy does not have enemy_killed signal")

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
		if player.has_signal("reloads_changed"):
			player.reloads_changed.connect(_on_player_reloads_changed)
		if player.has_signal("combo_streak_changed"):
			player.combo_streak_changed.connect(_on_combo_streak_changed)
		
		# Initialize UI to current player state
		_on_player_health_changed(player.health, player.MAX_HEALTH)
		_on_player_cash_changed(player.cash)
		_on_player_reloads_changed(player._player_reload_count, player.PLAYER_MAX_RELOADS)
	
	# Connect existing enemies to combo system
	_connect_existing_enemies()
	
	# Apply default font to UI elements
	if cash_label:
		FontConfig.apply_ui_font(cash_label)
	if health_percent_label:
		FontConfig.apply_ui_font(health_percent_label)
	if reload_label:
		FontConfig.apply_ui_font(reload_label)
	# Combo labels are styled individually in the combo handler
	
	# Configure progress bars
	if health_bar:
		health_bar.show_percentage = false
		# Reduce corner radius and add white outline
		health_bar.add_theme_stylebox_override("background", create_health_bar_background())
		health_bar.add_theme_stylebox_override("fill", create_health_bar_fill())
		health_bar.add_theme_stylebox_override("foreground", create_health_bar_foreground())

# Common setup function
func setup_level() -> void:
	# Initialize camera follow if available
	if player and player.has_node("Camera2D"):
		camera = player.get_node("Camera2D")
	
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

# Health bar styling functions
func create_health_bar_background() -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Dark gray background
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color.WHITE  # White outline
	style_box.corner_radius_top_left = 2  # Reduced corner radius
	style_box.corner_radius_top_right = 2
	style_box.corner_radius_bottom_left = 2
	style_box.corner_radius_bottom_right = 2
	return style_box

func create_health_bar_fill() -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	# Use the health bar's current modulate color for dynamic coloring
	var fill_color = health_bar.modulate if health_bar else Color(0.2, 0.9, 0.2)
	style_box.bg_color = fill_color
	style_box.corner_radius_top_left = 2  # Reduced corner radius
	style_box.corner_radius_top_right = 2
	style_box.corner_radius_bottom_left = 2
	style_box.corner_radius_bottom_right = 2
	return style_box

func create_health_bar_foreground() -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color.TRANSPARENT  # Transparent foreground
	style_box.border_width_left = 1
	style_box.border_width_right = 1
	style_box.border_width_top = 1
	style_box.border_width_bottom = 1
	style_box.border_color = Color.WHITE  # White outline
	style_box.corner_radius_top_left = 2  # Reduced corner radius
	style_box.corner_radius_top_right = 2
	style_box.corner_radius_bottom_left = 2
	style_box.corner_radius_bottom_right = 2
	return style_box

# Setup camera with common settings
func setup_camera() -> void:
	camera = get_node_or_null("Camera2D")
	if camera and player:
		camera.make_current()
		# Store original camera zoom for zoom effects
		_original_camera_zoom = camera.zoom.x

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
		print("DEBUG: Connecting enemy_killed signal")
		enemy.connect("enemy_killed", _on_enemy_killed)
		print("DEBUG: Successfully connected enemy_killed signal")
	else:
		print("DEBUG: Enemy does not have enemy_killed signal")
		
	# Also connect directly to player if available (more reliable)
	# Note: Old health gain system removed - now using combo streak system
	
	scene.add_child(enemy)
	return enemy

# Common enemy killed handler
func _on_enemy_killed(enemy: Node) -> void:
	print("DEBUG: Enemy killed, attempting to increment combo")
	# Increment combo streak for each enemy kill
	if player and player.has_method("increment_combo_streak"):
		player.increment_combo_streak()
	else:
		print("DEBUG: Player or increment_combo_streak method not found")

# Helper function to sync fill color with health bar modulate
func sync_health_bar_fill_color() -> void:
	if health_bar != null:
		health_bar.add_theme_stylebox_override("fill", create_health_bar_fill())

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
		# Update fill color to match the new modulate color
		sync_health_bar_fill_color()
	if health_percent_label != null and max_value > 0:
		health_percent_label.text = str(int(round(ratio * 100.0))) + "%"


func _on_player_cash_changed(current: int) -> void:
	if cash_label != null:
		cash_label.text = "CASH: " + str(current) + "$"


func _on_player_bullets_changed(current: int, max_value: int) -> void:
	_update_bullet_icons(current, max_value)


func _on_player_reloads_changed(current: int, max_value: int) -> void:
	_update_reload_label(current, max_value)

func _on_combo_streak_changed(current: int) -> void:
	if current > 0:
		# Special font mapping for numbers 10-20
		var display_text: String
		if current >= 10 and current <= 20:
			var mapping = {
				10: "a", 11: "z", 12: "e", 13: "r", 14: "t", 15: "y", 
				16: "u", 17: "i", 18: "o", 19: "p", 20: "q"
			}
			display_text = mapping.get(current, str(current))
		else:
			display_text = str(current)
		
		# Update number label with big font
		if combo_number_label:
			combo_number_label.text = display_text
			combo_number_label.add_theme_font_size_override("font_size", 32)  # Big font for number
			FontConfig.apply_ui_font(combo_number_label)
			combo_number_label.visible = true
		
		# Update text label with smaller font
		if combo_text_label:
			combo_text_label.text = "K I L L S"
			combo_text_label.add_theme_font_size_override("font_size", 16)  # Smaller font for text
			FontConfig.apply_ui_font(combo_text_label)
			combo_text_label.visible = true
		
		# Special bonus for 20 combo (max combo)
		if current == 20 and player:
			print("DEBUG: Reached max combo of 20, resetting")
			# Reset combo at max (20 is the highest possible)
			if player.has_method("reset_combo_streak"):
				player.reset_combo_streak()
	else:
		# Hide both labels when no combo
		if combo_number_label:
			combo_number_label.visible = false
		if combo_text_label:
			combo_text_label.visible = false


func _update_bullet_icons(current: int, max_value: int) -> void:
	if bullet_icons == null:
		return
	bullet_icons.add_theme_constant_override("separation", 10)
	for child in bullet_icons.get_children():
		child.queue_free()
	
	# Hide bullet icons if player has no gun
	if player and not player.has_gun:
		return
	
	var tex := load(BULLET_ICON_TEXTURE_PATH)
	if tex == null:
		return
	
	# Show bullet icons for available bullets and low opacity icons for used bullets
	for i in range(max_value):
		var icon := TextureRect.new()
		icon.texture = tex
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.custom_minimum_size = Vector2(8, 8)
		
		if i < current:
			# Available bullet - full opacity
			icon.modulate = Color.WHITE
		else:
			# Used bullet - low opacity
			icon.modulate = Color(1.0, 1.0, 1.0, 0.2)  # 20% opacity
		
		bullet_icons.add_child(icon)


func _update_reload_label(current: int, max_value: int) -> void:
	if reload_label == null:
		return
	# Hide reload label if player has no gun (current=0 and player.has_gun is false)
	if current == 0 and player and not player.has_gun:
		reload_label.visible = false
	else:
		reload_label.visible = true
		reload_label.text = "RELOADS " + str(current) + "/" + str(max_value)


# Camera zoom functions for slow-motion attacks
func start_attack_zoom() -> void:
	if camera == null:
		return
	
	# Cancel any existing zoom tween
	if _camera_zoom_tween and _camera_zoom_tween.is_valid():
		_camera_zoom_tween.kill()
	
	# Create zoom in tween with ease in
	_camera_zoom_tween = create_tween()
	_camera_zoom_tween.set_parallel(true)
	_camera_zoom_tween.set_trans(Tween.TRANS_CUBIC)
	_camera_zoom_tween.set_ease(Tween.EASE_IN)
	
	var target_zoom = _original_camera_zoom * camera_zoom_amount
	_camera_zoom_tween.tween_property(camera, "zoom", Vector2(target_zoom, target_zoom), camera_zoom_duration)


func end_attack_zoom() -> void:
	if camera == null:
		return
	
	# Cancel any existing zoom tween
	if _camera_zoom_tween and _camera_zoom_tween.is_valid():
		_camera_zoom_tween.kill()
	
	# Create zoom out tween with ease out
	_camera_zoom_tween = create_tween()
	_camera_zoom_tween.set_parallel(true)
	_camera_zoom_tween.set_trans(Tween.TRANS_CUBIC)
	_camera_zoom_tween.set_ease(Tween.EASE_OUT)
	
	_camera_zoom_tween.tween_property(camera, "zoom", Vector2(_original_camera_zoom, _original_camera_zoom), camera_zoom_duration)
