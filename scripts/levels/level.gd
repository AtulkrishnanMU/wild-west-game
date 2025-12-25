extends Node2D

# Shared UI helpers for main and endless levels
const BULLET_ICON_TEXTURE_PATH := "res://assets/icons/bullet-icon.png"
const DEFAULT_MUSIC_VOLUME_DB := -8.0

# Health color thresholds - SINGLE SOURCE OF TRUTH
const HEALTH_HIGH_THRESHOLD := 0.6  # Above this = green
const HEALTH_LOW_THRESHOLD := 0.3   # Above this = yellow, below = red

# Health color definitions - SINGLE SOURCE OF TRUTH
const HEALTH_HIGH_COLOR := Color.WHITE  # White for high health
const HEALTH_LOW_COLOR := Color(0.651, 0.067, 0.11, 1)  # #a6111c

# Tutorial configuration class
class TutorialConfig:
	var tutorial_text: String
	var fade_in_duration: float = 0.5
	var fade_out_duration: float = 0.3
	var position_offset: Vector2 = Vector2(0, 50)
	var popup_size: Vector2 = Vector2(250, 250)
	var label_position: Vector2 = Vector2(-125, -80)
	var track_mouse_left: bool = true
	var track_mouse_right: bool = true
	var track_space: bool = true
	var auto_hide_on_input: bool = true
	
	func _init(text: String):
		tutorial_text = text

# Heartbeat sound system
var heartbeat_player: AudioStreamPlayer = null
var is_heartbeat_playing: bool = false
const HEARTBEAT_SOUND_PATH := "res://sounds/heartbeat-sound.mp3"

# Health bar pulsing system
var health_bar_pulse_tween: Tween = null
var is_pulsing: bool = false
var original_health_bar_scale: Vector2 = Vector2.ONE

# Performance optimization: cached StyleBox objects for health bar
var _cached_fill_style: StyleBoxFlat = null
var _cached_foreground_style: StyleBoxFlat = null

# Initialize cached StyleBox objects for better performance
func _initialize_health_bar_styles() -> void:
	if _cached_fill_style != null:
		return  # Already initialized
	
	# Create reusable fill style
	_cached_fill_style = StyleBoxFlat.new()
	_cached_fill_style.border_width_left = 2
	_cached_fill_style.border_width_right = 2
	_cached_fill_style.border_width_top = 2
	_cached_fill_style.border_width_bottom = 2
	_cached_fill_style.border_color = Color.WHITE
	_cached_fill_style.corner_radius_top_left = 2
	_cached_fill_style.corner_radius_top_right = 2
	_cached_fill_style.corner_radius_bottom_left = 2
	_cached_fill_style.corner_radius_bottom_right = 2
	
	# Cache foreground style
	_cached_foreground_style = create_health_bar_foreground()

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
var camera_zoom_amount: float = 1.1  # Zoom in factor (1.1 = 10% closer)
var camera_zoom_duration: float = 0.15  # Time to zoom in/out
var _camera_zoom_tween: Tween = null
var _original_camera_zoom: float = 1.0

# Intro animation system
var _intro_animation_active: bool = false
var _intro_config: IntroConfig = null

# Tutorial popup system
var _tutorial_popup: Control = null
var _tutorial_active: bool = false
var _tutorial_label: Label = null
var _tutorial_config: TutorialConfig = null

# Tutorial input tracking
var _tutorial_left_clicked: bool = false
var _tutorial_right_clicked: bool = false
var _tutorial_space_pressed: bool = false

# Base _ready function that handles automatic setup
func _ready():
	# Automatically find and assign common nodes
	_auto_assign_nodes()
	
	# Call setup functions
	setup_level()
	setup_ui()

# Automatically assign common nodes if they exist
func _auto_assign_nodes():
	# Find player if not already assigned
	if not player and has_node("Player"):
		player = $Player
	
	# Find UI layer if not already assigned
	if not ui_layer and has_node("UI"):
		ui_layer = $UI
	
	# Find UI elements if UI layer exists
	if ui_layer:
		if not health_bar and ui_layer.has_node("HealthBar"):
			health_bar = ui_layer.get_node("HealthBar")
		if not cash_label and ui_layer.has_node("CashLabel"):
			cash_label = ui_layer.get_node("CashLabel")
		if not health_percent_label and ui_layer.has_node("HealthPercentLabel"):
			health_percent_label = ui_layer.get_node("HealthPercentLabel")
		if not bullet_icons and ui_layer.has_node("BulletIcons"):
			bullet_icons = ui_layer.get_node("BulletIcons")
		if not reload_label and ui_layer.has_node("ReloadLabel"):
			reload_label = ui_layer.get_node("ReloadLabel")
		if not combo_text_label and ui_layer.has_node("ComboTextLabel"):
			combo_text_label = ui_layer.get_node("ComboTextLabel")
		if not combo_total_label and ui_layer.has_node("ComboTotalLabel"):
			combo_total_label = ui_layer.get_node("ComboTotalLabel")
		if not combo_timer_bar and ui_layer.has_node("ComboTimerBar"):
			combo_timer_bar = ui_layer.get_node("ComboTimerBar")
		if not combo_number_label and ui_layer.has_node("ComboNumberLabel"):
			combo_number_label = ui_layer.get_node("ComboNumberLabel")

# Helper function to get health color based on ratio - SINGLE SOURCE OF TRUTH
func get_health_color(ratio: float) -> Color:
	if ratio > HEALTH_LOW_THRESHOLD:
		return HEALTH_HIGH_COLOR
	else:
		return HEALTH_LOW_COLOR

# Common setup function
func _connect_existing_enemies() -> void:
	# Find all existing enemies in the scene and connect them to combo system
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_signal("enemy_killed"):
			enemy.connect("enemy_killed", _on_enemy_killed)

# Common UI setup function
func setup_ui() -> void:
	# Validate that player exists
	if not player:
		push_error("ERROR: Player not found in scene! Make sure a Player node is added to the scene.")
		assert(false, "Player node is required for UI setup. Please add a Player node to the scene.")
		return
	
	# Configure progress bars FIRST before initializing health
	if health_bar:
		health_bar.show_percentage = false
		# Reduce corner radius and add white outline
		health_bar.add_theme_stylebox_override("background", create_health_bar_background())
		health_bar.add_theme_stylebox_override("foreground", create_health_bar_foreground())
		
		# Initialize health bar with red color
		set_health_bar_color_unified(HEALTH_LOW_COLOR)
	
	# Hide conditional UI elements by default (they'll be shown when needed)
	_set_conditional_ui_visibility(false)
	
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
	
	# Initialize bullets UI if player starts with gun
	if player.has_gun:
		_on_player_bullets_changed(player.PLAYER_MAG_SIZE - player._player_shots_since_reload, player.PLAYER_MAG_SIZE)
	
	# Connect existing enemies to combo system
	_connect_existing_enemies()
	
	# Setup weapon menu
	_setup_weapon_menu()
	
	# Apply default font to UI elements
	if cash_label:
		FontConfig.apply_ui_font(cash_label)
	if health_percent_label:
		FontConfig.apply_ui_font(health_percent_label)
		health_percent_label.modulate = Color.WHITE  # Set HP text color to white
		# Set initial text to MAX_HEALTH/MAX_HEALTH format
		if player:
			health_percent_label.text = str(player.MAX_HEALTH) + "/" + str(player.MAX_HEALTH) + " HP"
	if reload_label:
		FontConfig.apply_ui_font(reload_label)
	# Combo labels are styled individually in the combo handler

# Set visibility of conditional UI elements (bullets, reload, combo)
func _set_conditional_ui_visibility(visible: bool) -> void:
	if bullet_icons:
		bullet_icons.visible = visible
	if reload_label:
		reload_label.visible = visible
	if combo_text_label:
		combo_text_label.visible = visible
	if combo_total_label:
		combo_total_label.visible = visible
	if combo_timer_bar:
		combo_timer_bar.visible = visible

# Setup weapon menu (common across all levels)
func _setup_weapon_menu() -> void:
	# Connect weapon menu to player if UI layer exists
	if ui_layer and ui_layer.has_method("set_player"):
		ui_layer.set_player(player)

# Fade in essential UI elements (common across all levels)
func fade_in_essential_ui() -> void:
	# Create fade tween for UI elements
	var fade_tween := create_tween()
	
	# Fade in essential UI elements (health, cash, health percent)
	if ui_layer:
		if health_bar:
			# Health bar is already visible from base class, just fade in
			fade_tween.tween_property(health_bar, "modulate:a", 1.0, 0.5)
			# Also fade in child elements
			for child in health_bar.get_children():
				fade_tween.tween_property(child, "modulate:a", 1.0, 0.5)
		if cash_label:
			fade_tween.tween_property(cash_label, "modulate:a", 1.0, 0.5)
		if health_percent_label:
			fade_tween.tween_property(health_percent_label, "modulate:a", 1.0, 0.5)
		# Note: bullet_icons, reload_label, and combo elements remain hidden
		# They will be shown by their respective update functions when needed

# Common setup function
func setup_level() -> void:
	# Validate that player exists
	if not player:
		push_error("ERROR: Player not found in scene! Make sure a Player node is added to the scene.")
		assert(false, "Player node is required for level setup. Please add a Player node to the scene.")
		return
	
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
	style_box.border_width_left = 0  # Remove border from background
	style_box.border_width_right = 0
	style_box.border_width_top = 0
	style_box.border_width_bottom = 0
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
	style_box.border_width_left = 0  # Remove border from foreground too
	style_box.border_width_right = 0
	style_box.border_width_top = 0
	style_box.border_width_bottom = 0
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
		enemy.connect("enemy_killed", _on_enemy_killed)
		
	# Also connect directly to player if available (more reliable)
	# Note: Old health gain system removed - now using combo streak system
	
	scene.add_child(enemy)
	return enemy

# Common enemy killed handler
func _on_enemy_killed(enemy: Node) -> void:
	# Increment combo streak for each enemy kill
	if player and player.has_method("increment_combo_streak"):
		player.increment_combo_streak()

# SINGLE UNIFIED HEALTH BAR UPDATE METHOD - USE THIS EVERYWHERE
func update_health_bar_unified(current: int, max_value: int, duration: float = 0.3) -> void:
	if health_bar == null:
		return
	
	# Always use the red color #a6111c
	var red_color = HEALTH_LOW_COLOR
	set_health_bar_color_unified(red_color, duration)
	
	# Update health bar values
	health_bar.max_value = max_value
	health_bar.value = current

# SINGLE UNIFIED COLOR SETTER - ALWAYS SETS BOTH MODULATE AND FILL TOGETHER
func set_health_bar_color_unified(color: Color, duration: float = 0.0) -> void:
	if health_bar == null:
		return
	
	# Initialize cached styles if not done yet
	_initialize_health_bar_styles()
	
	if duration > 0.0:
		# Animated color change
		var tween = create_tween()
		tween.set_parallel(true)
		
		# Animate modulate
		tween.tween_property(health_bar, "modulate", color, duration)
		
		# Update cached fill style color and apply
		_cached_fill_style.bg_color = color
		health_bar.add_theme_stylebox_override("fill", _cached_fill_style)
		# Also update foreground outline to match fill color
		health_bar.add_theme_stylebox_override("foreground", _cached_foreground_style)
	else:
		# Immediate color change - ALWAYS set both together
		health_bar.modulate = color
		# Update cached fill style color and apply
		_cached_fill_style.bg_color = color
		health_bar.add_theme_stylebox_override("fill", _cached_fill_style)
		# Also update foreground outline to match fill color
		health_bar.add_theme_stylebox_override("foreground", _cached_foreground_style)

# Helper function to sync fill color with health bar modulate - DEPRECATED, use set_health_bar_color_unified instead
func sync_health_bar_fill_color() -> void:
	if health_bar != null and player != null:
		update_health_bar_unified(player.health, player.MAX_HEALTH)

# Unified health bar color function - DEPRECATED, use set_health_bar_color_unified instead
func set_health_bar_color(color: Color, duration: float = 0.0) -> void:
	set_health_bar_color_unified(color, duration)

# Restore health bar color function removed - health bar is always red

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
	
	# Manage health bar pulsing based on health color - AFTER color is set
	if health_color == HEALTH_LOW_COLOR:  # Red color (low health)
		print("Starting health bar pulse - health ratio: ", ratio)
		_start_health_bar_pulse()
	else:
		print("Stopping health bar pulse - health ratio: ", ratio)
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

func _manage_heartbeat_sound(health_ratio: float) -> void:
	if heartbeat_player == null or heartbeat_player.stream == null:
		return
	
	# Stop heartbeat if player is dead
	if player and player.is_dead:
		if is_heartbeat_playing:
			heartbeat_player.stop()
			is_heartbeat_playing = false
		return
	
	var should_play = health_ratio <= HEALTH_LOW_THRESHOLD  # Play when health is 30% or less
	
	if should_play and not is_heartbeat_playing:
		# Start playing heartbeat sound
		heartbeat_player.play()
		is_heartbeat_playing = true
	elif not should_play and is_heartbeat_playing:
		# Stop playing heartbeat sound
		heartbeat_player.stop()
		is_heartbeat_playing = false

# Public function to stop heartbeat sound immediately (called from player)
func stop_heartbeat_sound() -> void:
	if heartbeat_player and is_heartbeat_playing:
		heartbeat_player.stop()
		is_heartbeat_playing = false
	
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
	
	# Start pulsing after a small delay to ensure it can override the color setting
	await get_tree().create_timer(0.1).timeout
	if is_pulsing:  # Check if still supposed to be pulsing
		_pulse_health_bar()

func _stop_health_bar_pulse() -> void:
	if not is_pulsing:
		return
	
	# Cancel existing tweens
	if health_bar_pulse_tween and health_bar_pulse_tween.is_valid():
		health_bar_pulse_tween.kill()
	
	# Restore health bar scale and color
	if health_bar:
		health_bar.scale = original_health_bar_scale
		# Restore original fill color
		_initialize_health_bar_styles()
		_cached_fill_style.bg_color = HEALTH_LOW_COLOR
		health_bar.add_theme_stylebox_override("fill", _cached_fill_style)
		# Also restore modulate
		health_bar.modulate = HEALTH_LOW_COLOR
	
	is_pulsing = false

func _pulse_health_bar() -> void:
	if not is_pulsing or health_bar == null:
		return
	
	# Initialize cached styles if not done yet
	_initialize_health_bar_styles()
	
	# Cancel any existing pulse tween
	if health_bar_pulse_tween and health_bar_pulse_tween.is_valid():
		health_bar_pulse_tween.kill()
	
	# Create new pulsing tween
	health_bar_pulse_tween = create_tween()
	health_bar_pulse_tween.set_loops()
	
	# Pulsing parameters - sync with heartbeat sound
	var pulse_duration = 0.6  # Duration of one pulse cycle (matches heartbeat)
	var flash_duration = 0.2  # Flash for 200ms
	
	# Store original color
	var original_color = HEALTH_LOW_COLOR
	
	# White flash pulse cycle
	health_bar_pulse_tween.tween_property(health_bar, "modulate", Color.WHITE, flash_duration)
	health_bar_pulse_tween.tween_property(health_bar, "modulate", original_color, pulse_duration - flash_duration)
	
	# Also update fill color in sync with modulate
	health_bar_pulse_tween.tween_callback(func():
		_cached_fill_style.bg_color = Color.WHITE
		health_bar.add_theme_stylebox_override("fill", _cached_fill_style)
	).set_delay(0)
	
	health_bar_pulse_tween.tween_callback(func():
		_cached_fill_style.bg_color = original_color
		health_bar.add_theme_stylebox_override("fill", _cached_fill_style)
	).set_delay(flash_duration)


func _on_player_cash_changed(current: float) -> void:
	if cash_label != null:
		# Format to show decimals only if not a whole number
		if current == floor(current):
			cash_label.text = "CASH: %.0f$" % current
		else:
			cash_label.text = "CASH: %.1f$" % current


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
		
		# Update combined kills label with smaller font
		if combo_text_label:
			combo_text_label.text = display_text + " KILLS"
			combo_text_label.add_theme_font_size_override("font_size", 18)  # Smaller combined font
			FontConfig.apply_ui_font(combo_text_label)
			_fade_in_combo_element(combo_text_label)
		
		# Hide the number label since we're combining them
		if combo_number_label:
			combo_number_label.visible = false
			# Apply FontConfig for consistency (even though hidden)
			FontConfig.apply_ui_font(combo_number_label)
		
		if combo_total_label:
			# Calculate total HP that will be added (triangular formula: n(n+1)/2)
			var total_hp = current * (current + 1) / 2
			combo_total_label.text = "HP: +" + str(total_hp)
			combo_total_label.label_settings = null  # Remove LabelSettings to allow font override
			FontConfig.apply_ui_font(combo_total_label)
			# Apply custom overrides AFTER FontConfig
			combo_total_label.add_theme_font_size_override("font_size", 30)  # Much larger font
			combo_total_label.modulate = Color.WHITE  # White color
			combo_total_label.add_theme_color_override("font_color", Color.WHITE)  # White font color
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

# Debug function to test health bar pulsing (call from console or key press)
func debug_test_low_health() -> void:
	if player:
		print("DEBUG: Setting health to 30 (below threshold) to test pulsing")
		player.health = 30  # Set to very low health to trigger pulsing
		_on_player_health_changed(player.health, player.MAX_HEALTH)

# Debug function to restore health (call from console or key press)  
func debug_restore_health() -> void:
	if player:
		print("DEBUG: Restoring health to full")
		player.health = player.MAX_HEALTH
		_on_player_health_changed(player.health, player.MAX_HEALTH)

func _process(delta: float) -> void:
	# Update combo timer bar only when combo is active
	if combo_timer_bar and player and player._combo_timer and player._combo_active:
		var time_left = player._combo_timer.time_left
		var max_time = player._combo_duration
		combo_timer_bar.value = max_time - time_left
	
	# Process tutorial input tracking
	_process_tutorial_input()
	
	# Debug controls for testing health bar pulsing
	if Input.is_action_just_pressed("ui_accept"):  # Space key
		if Input.is_key_pressed(KEY_H):  # H + Space = Low health test
			debug_test_low_health()
		elif Input.is_key_pressed(KEY_R):  # R + Space = Restore health
			debug_restore_health()


func _update_bullet_icons(current: int, max_value: int) -> void:
	if bullet_icons == null:
		return
	bullet_icons.add_theme_constant_override("separation", 10)
	
	# Clear existing children
	for child in bullet_icons.get_children():
		child.queue_free()
	
	# Hide bullet icons if player has no gun or gun is not equipped, otherwise show them
	if player and (not player.has_gun or player.current_equipped_weapon != "gun"):
		bullet_icons.visible = false
		# Also hide the background panel
		var background = bullet_icons.get_parent().get_node_or_null("BulletBackground")
		if background:
			background.visible = false
		return
	else:
		bullet_icons.visible = true
		# Also show the background panel
		var background = bullet_icons.get_parent().get_node_or_null("BulletBackground")
		if background:
			background.visible = true
	
	# Create bullet icons
	for i in range(max_value):
		var icon = TextureRect.new()
		var tex = load("res://assets/icons/bullet-icon.png")
		if tex == null:
			# Fallback to objects folder if icon not found
			tex = load("res://assets/objects/bullet.png")
		if tex == null:
			# Create a simple colored rectangle as fallback
			icon.color = Color.WHITE
		else:
			icon.texture = tex
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.custom_minimum_size = Vector2(12, 12)
		
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
	# Hide reload label if player has no gun or gun is not equipped
	if player and (not player.has_gun or player.current_equipped_weapon != "gun"):
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
		# Check if this is the combo number label (last element) and trigger healing after fade
		if element == combo_number_label and player and player.has_method("apply_combo_healing"):
			# Add small delay to ensure fade out is complete before healing popup
			await get_tree().create_timer(0.1).timeout
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

# Generic tutorial popup framework
func show_tutorial_popup(config: TutorialConfig) -> void:
	if not player:
		return
	
	_tutorial_config = config
	_tutorial_active = true
	
	# Reset input tracking
	_reset_tutorial_input_tracking()
	
	# Create tutorial popup
	_tutorial_popup = Control.new()
	_tutorial_popup.name = "TutorialPopup"
	
	# Create tutorial label
	_tutorial_label = Label.new()
	_tutorial_label.text = config.tutorial_text
	_tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tutorial_label.position = config.label_position
	_tutorial_label.size = config.popup_size
	
	# Apply default font and styling
	_apply_tutorial_label_styling()
	
	_tutorial_popup.add_child(_tutorial_label)
	
	# Add to scene
	add_child(_tutorial_popup)
	
	# Position and fade in
	_position_tutorial_popup()
	_fade_in_tutorial_popup(config.fade_in_duration)
	

func hide_tutorial_popup() -> void:
	if not _tutorial_popup:
		return
	
	var fade_out_duration = _tutorial_config.fade_out_duration if _tutorial_config else 0.3
	
	# Fade out before removing
	var fade_tween := create_tween()
	fade_tween.tween_property(_tutorial_popup, "modulate:a", 0.0, fade_out_duration)
	fade_tween.tween_callback(_remove_tutorial_popup)
	
	_tutorial_active = false

# Tutorial input tracking in process
func _process_tutorial_input() -> void:
	if not _tutorial_active or not _tutorial_config:
		return
	
	# Track mouse clicks
	if _tutorial_config.track_mouse_left and Input.is_action_just_pressed("attack"):
		_tutorial_left_clicked = true
	
	if _tutorial_config.track_mouse_right and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_tutorial_right_clicked = true
	
	# Track spacebar
	if _tutorial_config.track_space and (Input.is_action_just_pressed("ui_accept") or Input.is_physical_key_pressed(KEY_SPACE)):
		_tutorial_space_pressed = true
	
	# Check if all required inputs have been used
	if _tutorial_config.auto_hide_on_input:
		var required_inputs_met = true
		
		if _tutorial_config.track_mouse_left and not _tutorial_left_clicked:
			required_inputs_met = false
		if _tutorial_config.track_mouse_right and not _tutorial_right_clicked:
			required_inputs_met = false
		if _tutorial_config.track_space and not _tutorial_space_pressed:
			required_inputs_met = false
		
		if required_inputs_met:
			hide_tutorial_popup()

# Tutorial helper methods
func _reset_tutorial_input_tracking() -> void:
	_tutorial_left_clicked = false
	_tutorial_right_clicked = false
	_tutorial_space_pressed = false

func _apply_tutorial_label_styling() -> void:
	if not _tutorial_label:
		return
	
	# Apply default font
	FontConfig.apply_ui_font(_tutorial_label)
	
	# Ensure crisp pixel rendering
	_tutorial_label.add_theme_constant_override("outline_size", 1)
	_tutorial_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_tutorial_label.modulate = Color.WHITE

func _position_tutorial_popup() -> void:
	if not _tutorial_popup or not player:
		return
	
	var config = _tutorial_config
	if config:
		_tutorial_popup.global_position = player.global_position + config.position_offset

func _fade_in_tutorial_popup(duration: float) -> void:
	if not _tutorial_popup:
		return
	
	# Start with invisible and fade in
	_tutorial_popup.modulate.a = 0.0
	var fade_tween := create_tween()
	fade_tween.tween_property(_tutorial_popup, "modulate:a", 1.0, duration)

func _remove_tutorial_popup() -> void:
	if _tutorial_popup:
		_tutorial_popup.queue_free()
		_tutorial_popup = null
		_tutorial_label = null
		_tutorial_config = null

# Intro animation configuration class
class IntroConfig:
	var player_start_position: Vector2
	var player_center_position: Vector2
	var animation_duration: float
	var wait_duration: float
	var initial_camera_position: Vector2
	var disable_camera_follow: bool = true
	var disable_player_controls: bool = true
	var hide_ui_elements: bool = true
	var target_character: Node = null
	var character_facing: String = ""
	
	func _init(start_pos: Vector2, center_pos: Vector2, anim_dur: float, wait_dur: float, cam_pos: Vector2 = Vector2.ZERO):
		player_start_position = start_pos
		player_center_position = center_pos
		animation_duration = anim_dur
		wait_duration = wait_dur
		initial_camera_position = cam_pos

# Generic intro animation framework
func start_intro_sequence(config: IntroConfig) -> void:
	if not player:
		return
	
	_intro_config = config
	_intro_animation_active = true
	
	# Disable camera follow if requested
	if config.disable_camera_follow:
		camera_follow_enabled = false
	
	# Disable player controls if requested
	if config.disable_player_controls:
		_set_player_controls_enabled(false)
	
	# Hide UI elements if requested
	if config.hide_ui_elements:
		_set_ui_visibility(false)
	
	# Position player
	player.global_position = config.player_center_position
	
	# Set player animation to IDLE
	_set_player_animation("IDLE", false)
	
	# Set character facing direction if specified
	if config.target_character and config.character_facing != "":
		_set_character_facing_direction(config.target_character, config.character_facing)
	
	# Setup camera
	if camera:
		camera.make_current()
		var cam_pos = config.initial_camera_position
		if cam_pos == Vector2.ZERO:
			cam_pos = config.player_center_position
		camera.global_position = cam_pos
	
	# Wait for specified duration before ending intro
	await get_tree().create_timer(config.wait_duration).timeout
	
	# End intro sequence
	end_intro_sequence()

func end_intro_sequence() -> void:
	if not _intro_config:
		return
	
	# Enable player controls
	if _intro_config.disable_player_controls:
		_set_player_controls_enabled(true)
	
	# Enable camera follow
	if _intro_config.disable_camera_follow:
		camera_follow_enabled = true
		if camera and player:
			camera.make_current()
			camera.global_position = player.global_position
	
	# Show UI elements
	if _intro_config.hide_ui_elements:
		_set_ui_visibility(true)
	
	# Call post-intro hook for child classes
	_on_intro_sequence_completed()
	
	# Mark intro animation as complete
	_intro_animation_active = false
	_intro_config = null
	

# Virtual method for child classes to override
func _on_intro_sequence_completed() -> void:
	pass

# Helper methods for intro animation
func _set_player_controls_enabled(enabled: bool) -> void:
	if not player:
		return
	
	if player.has_method("set_controls_enabled"):
		player.set_controls_enabled(enabled)
	else:
		player.controls_enabled = enabled

func _set_player_animation(animation_name: String, flip_h: bool) -> void:
	if not player:
		return
	
	var animated_sprite = player.get_node_or_null("AnimatedSprite2D")
	if animated_sprite:
		animated_sprite.play(animation_name)
		animated_sprite.flip_h = flip_h

func _set_character_facing_direction(character: Node, direction: String) -> void:
	if not character:
		return
	
	# For gun enemies, we need to flip the sprite and adjust gun position
	var animated_sprite = character.get_node_or_null("AnimatedSprite2D")
	var gun_sprite = character.get_node_or_null("Gun")
	
	if direction == "right":
		# Face right - no flip
		if animated_sprite:
			animated_sprite.flip_h = false
		if gun_sprite:
			# Adjust gun position for right-facing
			gun_sprite.position.x = abs(gun_sprite.position.x)
	elif direction == "left":
		# Face left - flip horizontally
		if animated_sprite:
			animated_sprite.flip_h = true
		if gun_sprite:
			# Adjust gun position for left-facing
			gun_sprite.position.x = -abs(gun_sprite.position.x)

func _set_ui_visibility(visible: bool) -> void:
	if not ui_layer:
		return
	
	var alpha = 1.0 if visible else 0.0
	var vis = visible
	
	# Apply visibility and alpha to essential UI elements only
	if health_bar:
		health_bar.modulate.a = alpha
		health_bar.visible = vis
		for child in health_bar.get_children():
			child.modulate.a = alpha
			child.visible = vis
	
	if cash_label:
		cash_label.modulate.a = alpha
		cash_label.visible = vis
	
	if health_percent_label:
		health_percent_label.modulate.a = alpha
		health_percent_label.visible = vis
