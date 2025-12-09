extends Node2D

# Shared UI helpers for main and endless levels
const BULLET_ICON_TEXTURE_PATH := "res://assets/icons/bullet-icon.png"
const DEFAULT_MUSIC_VOLUME_DB := -8.0

# Health color thresholds - SINGLE SOURCE OF TRUTH
const HEALTH_HIGH_THRESHOLD := 0.6  # Above this = green
const HEALTH_LOW_THRESHOLD := 0.3   # Above this = yellow, below = red

# Health color definitions - SINGLE SOURCE OF TRUTH
const HEALTH_HIGH_COLOR := Color(0.2, 0.6, 0.2)    # Green (less bright)
const HEALTH_MEDIUM_COLOR := Color(0.95, 0.8, 0.2)  # Yellow
const HEALTH_LOW_COLOR := Color(0.95, 0.2, 0.2)    # Red

# Heartbeat sound system
var heartbeat_player: AudioStreamPlayer = null
var is_heartbeat_playing: bool = false
const HEARTBEAT_SOUND_PATH := "res://sounds/heartbeat-sound.mp3"

# Health bar pulsing system
var health_bar_pulse_tween: Tween = null
var is_pulsing: bool = false
var original_health_bar_scale: Vector2 = Vector2.ONE

# These are expected to be set by child scripts via @onready vars
var player: Node = null
var health_bar: ProgressBar = null
var cash_label: Label = null
var health_percent_label: Label = null
var reload_label: Label = null
var bullet_icons: HBoxContainer = null
var combo_number_label: Label = null
var combo_text_label: Label = null
var combo_total_label: Label = null
var combo_timer_bar: ProgressBar = null

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

# Helper function to get health color based on ratio - SINGLE SOURCE OF TRUTH
func get_health_color(ratio: float) -> Color:
	if ratio > HEALTH_HIGH_THRESHOLD:
		return HEALTH_HIGH_COLOR
	elif ratio > HEALTH_LOW_THRESHOLD:
		return HEALTH_MEDIUM_COLOR
	else:
		return HEALTH_LOW_COLOR

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
		# Configure progress bars FIRST before initializing health
	if health_bar:
		health_bar.show_percentage = false
		# Reduce corner radius and add white outline
		health_bar.add_theme_stylebox_override("background", create_health_bar_background())
		health_bar.add_theme_stylebox_override("foreground", create_health_bar_foreground())
		
		# Initialize health bar with proper color using unified function
		set_health_bar_color_unified(HEALTH_HIGH_COLOR)
	
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
		
	# Initialize UI to current player state AFTER styling is configured
		update_health_bar_unified(player.health, player.MAX_HEALTH)
		_on_player_cash_changed(player.cash)
		_on_player_reloads_changed(player._player_reload_count, player.PLAYER_MAX_RELOADS)
	
	# Connect existing enemies to combo system
	_connect_existing_enemies()
	
	# Apply default font to UI elements
	if cash_label:
		FontConfig.apply_ui_font(cash_label)
	if health_percent_label:
		FontConfig.apply_ui_font(health_percent_label)
		# Set initial text to MAX_HEALTH/MAX_HEALTH format
		if player:
			health_percent_label.text = str(player.MAX_HEALTH) + "/" + str(player.MAX_HEALTH) + " HP"
	if reload_label:
		FontConfig.apply_ui_font(reload_label)
	# Combo labels are styled individually in the combo handler

# Common setup function
func setup_level() -> void:
	# Initialize camera follow if available
	if player and player.has_node("Camera2D"):
		camera = player.get_node("Camera2D")
	
	# Initialize heartbeat sound system
	_setup_heartbeat_sound()
	
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

# DEPRECATED: create_health_bar_fill() is no longer needed - use set_health_bar_color_unified() instead

# Helper function to get current health color for outline
func get_current_health_color() -> Color:
	if player == null:
		return HEALTH_HIGH_COLOR  # Default to green if no player
	
	# Ensure we don't divide by zero
	if player.MAX_HEALTH <= 0:
		return HEALTH_HIGH_COLOR
	
	var ratio = float(player.health) / float(player.MAX_HEALTH)
	return get_health_color(ratio)

func create_health_bar_foreground() -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color.TRANSPARENT  # Transparent foreground
	style_box.border_width_left = 1
	style_box.border_width_right = 1
	style_box.border_width_top = 1
	style_box.border_width_bottom = 1
	# Use current health color for outline instead of white
	var health_color = get_current_health_color()
	style_box.border_color = health_color  # Same color as fill
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
	
	# Update combo timer bar
	if combo_timer_bar and player and player._combo_timer and player._combo_active:
		var time_left = player._combo_timer.time_left
		var max_time = player._combo_duration
		var new_value = max_time - time_left
		combo_timer_bar.value = new_value


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

# SINGLE UNIFIED HEALTH BAR UPDATE METHOD - USE THIS EVERYWHERE
func update_health_bar_unified(current: int, max_value: int, duration: float = 0.3) -> void:
	if health_bar == null:
		return
	
	# Update max_value immediately
	health_bar.max_value = max_value
	
	# Animate health bar value with smooth easing
	var health_tween := create_tween()
	health_tween.set_ease(Tween.EASE_IN_OUT)
	health_tween.set_trans(Tween.TRANS_CUBIC)
	health_tween.tween_property(health_bar, "value", current, duration)
	
	# Calculate and apply color
	var ratio: float = 0.0
	if max_value > 0:
		ratio = float(current) / float(max_value)
	
	var health_color = get_health_color(ratio)
	set_health_bar_color_unified(health_color, duration)

# SINGLE UNIFIED COLOR SETTER - ALWAYS SETS BOTH MODULATE AND FILL TOGETHER
func set_health_bar_color_unified(color: Color, duration: float = 0.0) -> void:
	if health_bar == null:
		return
	
	if duration > 0.0:
		# Animated color change
		var tween = create_tween()
		tween.set_parallel(true)
		
		# Animate modulate
		tween.tween_property(health_bar, "modulate", color, duration)
		
		# Create and animate fill color
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = color
		fill_style.corner_radius_top_left = 2
		fill_style.corner_radius_top_right = 2
		fill_style.corner_radius_bottom_left = 2
		fill_style.corner_radius_bottom_right = 2
		
		# Apply fill style immediately, then animate
		health_bar.add_theme_stylebox_override("fill", fill_style)
		# Also update foreground outline to match fill color
		health_bar.add_theme_stylebox_override("foreground", create_health_bar_foreground())
	else:
		# Immediate color change - ALWAYS set both together
		health_bar.modulate = color
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = color
		fill_style.corner_radius_top_left = 2
		fill_style.corner_radius_top_right = 2
		fill_style.corner_radius_bottom_left = 2
		fill_style.corner_radius_bottom_right = 2
		health_bar.add_theme_stylebox_override("fill", fill_style)
		# Also update foreground outline to match fill color
		health_bar.add_theme_stylebox_override("foreground", create_health_bar_foreground())

# Helper function to sync fill color with health bar modulate - DEPRECATED, use set_health_bar_color_unified instead
func sync_health_bar_fill_color() -> void:
	print("WARNING: sync_health_bar_fill_color() is deprecated, use set_health_bar_color_unified instead")
	if health_bar != null and player != null:
		update_health_bar_unified(player.health, player.MAX_HEALTH)

# Unified health bar color function - DEPRECATED, use set_health_bar_color_unified instead
func set_health_bar_color(color: Color, duration: float = 0.0) -> void:
	print("WARNING: set_health_bar_color() is deprecated, use set_health_bar_color_unified instead")
	set_health_bar_color_unified(color, duration)

# Restore health bar to appropriate color based on current health level
func restore_health_bar_color(duration: float = 0.3) -> void:
	if health_bar == null or player == null:
		return
	
	var ratio = float(player.health) / float(player.MAX_HEALTH)
	var appropriate_color = get_health_color(ratio)
	
	set_health_bar_color_unified(appropriate_color, duration)

func _on_player_health_changed(current: int, max_value: int) -> void:
	var ratio: float = 0.0
	if max_value > 0:
		ratio = float(current) / float(max_value)
	
	# Calculate health color outside the if block for proper scope
	var health_color = get_health_color(ratio)
	
	if health_bar != null:
		health_bar.max_value = max_value
		
		# Use unified color function to ensure both modulate and fill are always the same
		update_health_bar_unified(current, max_value)
	
	# Manage heartbeat sound based on health level
	_manage_heartbeat_sound(ratio)
	
	# Manage health bar pulsing based on health color
	if health_color == HEALTH_LOW_COLOR:  # Red color
		_start_health_bar_pulse()
	else:
		_stop_health_bar_pulse()
		
	if health_percent_label != null and max_value > 0:
		health_percent_label.text = str(current) + "/" + str(max_value) + " HP"

func _setup_heartbeat_sound() -> void:
	# Create heartbeat sound player
	heartbeat_player = AudioStreamPlayer.new()
	add_child(heartbeat_player)
	
	# Load the heartbeat sound
	var heartbeat_sound = load(HEARTBEAT_SOUND_PATH)
	if heartbeat_sound:
		heartbeat_player.stream = heartbeat_sound
		heartbeat_player.volume_db = 0.0  # Increased volume (was -5.0)
		heartbeat_player.stream.loop = true  # Enable looping
	else:
		print("Warning: Heartbeat sound not found at ", HEARTBEAT_SOUND_PATH)

func _manage_heartbeat_sound(health_ratio: float) -> void:
	if heartbeat_player == null or heartbeat_player.stream == null:
		return
	
	# Stop heartbeat if player is dead
	if player and player.is_dead:
		if is_heartbeat_playing:
			heartbeat_player.stop()
			is_heartbeat_playing = false
			print("DEBUG: Stopped heartbeat sound (player died)")
		return
	
	var should_play = health_ratio <= HEALTH_LOW_THRESHOLD  # Play when health is 30% or less
	
	if should_play and not is_heartbeat_playing:
		# Start playing heartbeat sound
		heartbeat_player.play()
		is_heartbeat_playing = true
		print("DEBUG: Started heartbeat sound (health ratio: ", health_ratio, ")")
	elif not should_play and is_heartbeat_playing:
		# Stop playing heartbeat sound
		heartbeat_player.stop()
		is_heartbeat_playing = false
		print("DEBUG: Stopped heartbeat sound (health ratio: ", health_ratio, ")")

# Public function to stop heartbeat sound immediately (called from player)
func stop_heartbeat_sound() -> void:
	if heartbeat_player and is_heartbeat_playing:
		heartbeat_player.stop()
		is_heartbeat_playing = false
		print("DEBUG: Stopped heartbeat sound (external call)")
	
	# Also stop health bar pulsing when player dies
	_stop_health_bar_pulse()

func _start_health_bar_pulse() -> void:
	if is_pulsing or health_bar == null:
		return
	
	# Store original scale and set pivot to center
	if original_health_bar_scale == Vector2.ONE:
		original_health_bar_scale = health_bar.scale
		# Set pivot to center for proper pulsing anchor
		health_bar.pivot_offset = health_bar.size / 2
	
	is_pulsing = true
	_pulse_health_bar()

func _stop_health_bar_pulse() -> void:
	if not is_pulsing:
		return
	
	# Cancel existing tween
	if health_bar_pulse_tween and health_bar_pulse_tween.is_valid():
		health_bar_pulse_tween.kill()
	
	# Reset health bar scale
	if health_bar:
		health_bar.scale = original_health_bar_scale
	
	is_pulsing = false

func _pulse_health_bar() -> void:
	if not is_pulsing or health_bar == null:
		return
	
	# Create pulsing tween
	health_bar_pulse_tween = create_tween()
	health_bar_pulse_tween.set_loops()
	
	# Pulsing parameters - faster and smaller
	var pulse_scale = 1.05  # 5% bigger (reduced from 10%)
	var pulse_duration = 0.4  # Duration of one pulse cycle (faster, was 0.8)
	
	# Health bar pulsing from center
	health_bar_pulse_tween.tween_property(health_bar, "scale", original_health_bar_scale * pulse_scale, pulse_duration * 0.5)
	health_bar_pulse_tween.tween_property(health_bar, "scale", original_health_bar_scale, pulse_duration * 0.5).set_delay(pulse_duration * 0.5)


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
			# Fade in animation
			_fade_in_combo_element(combo_number_label)
		
		# Update text label with smaller font
		if combo_text_label:
			combo_text_label.text = "K I L L S"
			combo_text_label.add_theme_font_size_override("font_size", 16)  # Smaller font for text
			FontConfig.apply_ui_font(combo_text_label)

			_fade_in_combo_element(combo_text_label)
		
		if combo_total_label:
			# Calculate total HP that will be added (triangular formula: n(n+1)/2)
			var total_hp = current * (current + 1) / 2
			combo_total_label.text = "HP: +" + str(total_hp)
			combo_total_label.label_settings = null  # Remove LabelSettings to allow font override
			FontConfig.apply_ui_font(combo_total_label)
			# Apply custom overrides AFTER FontConfig
			combo_total_label.add_theme_font_size_override("font_size", 30)  # Much larger font
			combo_total_label.modulate = Color(1.0, 0.75, 0.8)  # Pink color
			combo_total_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.8))  # Pink font color
			combo_total_label.add_theme_color_override("font_outline_color", Color.BLACK)  # Black outline

			_fade_in_combo_element(combo_total_label)
		
# Setup timer bar (only style once)
		if combo_timer_bar and player and player._combo_timer:
			combo_timer_bar.max_value = player._combo_duration
			combo_timer_bar.value = 0  # Start empty
			# Fade in animation
			_fade_in_combo_element(combo_timer_bar)
			
			# Apply timer bar styling
			# Blue background with health bar style outline
			var timer_style = StyleBoxFlat.new()
			timer_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)  # Dark background
			timer_style.border_width_left = 2
			timer_style.border_width_right = 2
			timer_style.border_width_top = 2
			timer_style.border_width_bottom = 2
			timer_style.border_color = Color(0.3, 0.7, 1.0, 0.9)  # Blue border
			timer_style.corner_radius_top_left = 3
			timer_style.corner_radius_top_right = 3
			timer_style.corner_radius_bottom_left = 3
			timer_style.corner_radius_bottom_right = 3
			
			# Blue fill similar to health bar
			var fill_style = StyleBoxFlat.new()
			fill_style.bg_color = Color(0.3, 0.7, 1.0, 0.9)  # Blue fill
			fill_style.corner_radius_top_left = 2
			fill_style.corner_radius_top_right = 2
			fill_style.corner_radius_bottom_left = 2
			fill_style.corner_radius_bottom_right = 2
			
			combo_timer_bar.add_theme_stylebox_override("background", timer_style)
			combo_timer_bar.add_theme_stylebox_override("fill", fill_style)
		else:
			# Timer bar setup failed - will be handled by UI visibility
			pass
		
		# Special bonus for 20 combo (max combo)
		if current == 20 and player:
			# Reset combo at max (20 is the highest possible)
			if player.has_method("reset_combo_streak"):
				player.reset_combo_streak()
	else:
		# Hide both labels with fade out animation
		if combo_number_label:
			_fade_out_combo_element(combo_number_label)
		if combo_text_label:
			_fade_out_combo_element(combo_text_label)
		if combo_total_label:
			_fade_out_combo_element(combo_total_label)
		if combo_timer_bar:
			_fade_out_combo_element(combo_timer_bar)

func _process(delta: float) -> void:
	# Simple debug to check if process is running
	if player and player._combo_active:
		print("DEBUG: _process running, combo_active: ", player._combo_active)
	
	# Update combo timer bar
	if combo_timer_bar and player and player._combo_timer and player._combo_active:
		var time_left = player._combo_timer.time_left
		var max_time = player._combo_duration
		var new_value = max_time - time_left
		print("DEBUG: Timer update - time_left: ", time_left, " max_time: ", max_time, " new_value: ", new_value)
		combo_timer_bar.value = new_value
		print("DEBUG: Timer bar value set to: ", combo_timer_bar.value)
	else:
		if player and player._combo_timer:
			print("DEBUG: Timer update failed - combo_timer_bar: ", combo_timer_bar, " _combo_active: ", player._combo_active, " time_left: ", player._combo_timer.time_left)


func _update_bullet_icons(current: int, max_value: int) -> void:
	if bullet_icons == null:
		return
	bullet_icons.add_theme_constant_override("separation", 10)
	for child in bullet_icons.get_children():
		child.queue_free()
	
	# Hide bullet icons if player has no gun, otherwise show them
	if player and not player.has_gun:
		bullet_icons.visible = false
	else:
		bullet_icons.visible = true
	
	# Create bullet icons
	for i in range(max_value):
		var icon = TextureRect.new()
		var tex = load("res://assets/icons/bullet-icon.png")
		if tex == null:
			# Fallback to objects folder if icon not found
			tex = load("res://assets/objects/bullet.png")
		if tex == null:
			# Create a simple colored rectangle as fallback
			print("Bullet texture not found, using colored rectangle")
			icon.color = Color.WHITE
		else:
			icon.texture = tex
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.custom_minimum_size = Vector2(12, 12)  # Slightly larger for visibility
		
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

# Combo element animation functions
func _fade_in_combo_element(element: Control) -> void:
	if not element:
		return
	
	# Kill any existing tweens
	if element.has_meta("fade_tween"):
		var existing_tween = element.get_meta("fade_tween")
		if existing_tween and existing_tween.is_valid():
			existing_tween.kill()
	
	# Start invisible and fade in
	element.modulate = Color(1, 1, 1, 0)
	element.visible = true
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(element, "modulate:a", 1.0, 0.3)
	
	# Store tween reference
	element.set_meta("fade_tween", tween)

func _fade_out_combo_element(element: Control) -> void:
	if not element or not element.visible:
		return
	
	print("DEBUG: Fading out combo element: ", element.name)
	
	# Kill any existing tweens
	if element.has_meta("fade_tween"):
		var existing_tween = element.get_meta("fade_tween")
		if existing_tween and existing_tween.is_valid():
			existing_tween.kill()
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(element, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): 
		element.visible = false
		print("DEBUG: Element faded out and hidden: ", element.name)
		# Check if this is the combo number label (last element) and trigger healing after fade
		if element == combo_number_label and player and player.has_method("apply_combo_healing"):
			print("DEBUG: Combo number label faded out, starting 0.1 second delay before healing")
			# Add small delay to ensure fade out is complete before healing popup
			await get_tree().create_timer(0.1).timeout
			print("DEBUG: Delay complete, calling apply_combo_healing")
			player.apply_combo_healing()
	)
	
	# Store tween reference
	element.set_meta("fade_tween", tween)


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
