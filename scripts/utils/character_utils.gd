class_name CharacterUtils
extends RefCounted

# Common scene preloads
const DUST_SCENE := preload("res://scenes/objects/dust_splash.tscn")
const BLOOD_SCENE := preload("res://scenes/objects/blood_splash.tscn")

# Single source of truth for dialogue positioning
const DIALOGUE_TOP_Y_RATIO := 0.25  # Position 25% from top of screen (relative)
const DIALOGUE_WIDTH_RATIO := 0.67  # 67% of screen width
const DIALOGUE_HEIGHT_RATIO := 0.17  # 17% of screen height

# Performance optimization: cached player reference
static var _cached_player_ref: WeakRef = weakref(null)

# Performance optimization: cached scene node references
static var _cached_wall_node: WeakRef = weakref(null)
static var _cached_background_node: WeakRef = weakref(null)
static var _cache_initialized: bool = false

# Initialize scene node cache for better performance
static func _initialize_scene_cache(scene: Node) -> void:
	if _cache_initialized:
		return
	
	_cached_wall_node = weakref(scene.get_node_or_null("Wall"))
	_cached_background_node = weakref(scene.get_node_or_null("background"))
	_cache_initialized = true

# Dust creation functions
static func create_dust_effect(character: Node2D, offset_y: float = 12.0, spread_x: float = 8.0) -> void:
	# Spawn dust splash at character landing position (near feet)
	if DUST_SCENE:
		var dust := DUST_SCENE.instantiate()
		var scene := character.get_tree().current_scene
		if dust and scene:
			var offset := Vector2(randf_range(-spread_x, spread_x), offset_y)
			dust.global_position = character.global_position + offset
			dust.set_direction(Vector2(randf_range(-0.3, 0.3), 0.8))  # Downward with slight spread
			scene.add_child(dust)
	else:
		push_error("DUST_SCENE not found!")

static func create_running_dust(character: Node2D, offset_y: float = 12.0, spread_x: float = 4.0) -> void:
	# Spawn smaller dust effect while running (at feet level)
	if DUST_SCENE:
		var dust := DUST_SCENE.instantiate()
		var scene := character.get_tree().current_scene
		if dust and scene:
			var offset := Vector2(randf_range(-spread_x, spread_x), offset_y)
			dust.global_position = character.global_position + offset
			dust.set_direction(Vector2(randf_range(-0.5, -0.1), 0.5))  # Backward and slightly down
			scene.add_child(dust)
	else:
		push_error("DUST_SCENE not found for running dust!")

# Blood creation functions
static func create_blood_effect(character: Node2D, spread: float = 4.0) -> void:
	# Spawn blood splash at character position
	if BLOOD_SCENE:
		var blood := BLOOD_SCENE.instantiate()
		var scene := character.get_tree().current_scene
		if blood and scene:
			var offset := Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
			blood.global_position = character.global_position + offset
			# Set direction based on character facing if available
			if character.has_method("get_facing_direction"):
				blood.set_direction(character.get_facing_direction())
			elif character.has_node("AnimatedSprite2D"):
				var sprite = character.get_node("AnimatedSprite2D") as AnimatedSprite2D
				var facing_dir := Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
				blood.set_direction(facing_dir)
			
			# Initialize scene cache and use cached references for better performance
			_initialize_scene_cache(scene)
			var wall_node = _cached_wall_node.get_ref()
			var background_node = _cached_background_node.get_ref()
			
			# Place blood at the very bottom layer (first to be drawn)
			scene.add_child(blood)
			scene.move_child(blood, 0)

# Dust tracking for landing detection
static func check_dust_landing(character: Node2D, was_on_floor: bool, velocity: Vector2, threshold: float = 50.0) -> bool:
	# Returns true if dust should be created on landing
	if character.is_on_floor() and not was_on_floor and abs(velocity.y) > threshold:
		return true
	return false

# Dust tracking for running detection  
static func check_running_dust(character: Node2D, velocity: Vector2, chance: float = 0.1, speed_threshold: float = 50.0) -> bool:
	# Returns true if dust should be created while running
	if character.is_on_floor() and abs(velocity.x) > speed_threshold and randf() < chance:
		return true
	return false

# Smooth movement with ease-in/ease-out acceleration
static func apply_smooth_movement(character: CharacterBody2D, target_speed: float, max_speed: float, delta: float, acceleration: float = 1200.0, deceleration: float = 1500.0, air_acceleration: float = 800.0) -> float:
	# Apply smooth acceleration/deceleration to horizontal velocity
	var acceleration_rate: float = acceleration
	if not character.is_on_floor():
		acceleration_rate = air_acceleration
	
	if target_speed != 0.0:
		# Accelerating towards target speed
		var speed_diff: float = target_speed - character.velocity.x
		var accel: float = sign(speed_diff) * min(abs(speed_diff), acceleration_rate * delta)
		return character.velocity.x + accel
	else:
		# Decelerating to stop
		var decel: float = sign(character.velocity.x) * min(abs(character.velocity.x), deceleration * delta)
		var new_velocity: float = character.velocity.x - decel
		# Stop completely if very close to zero to prevent tiny movements
		if abs(new_velocity) < 1.0:
			return 0.0
		return new_velocity

# Shared gun aiming logic for both player and gun enemies
static func calculate_gun_aim_direction(gun_sprite: Sprite2D, target_position: Vector2, animated_sprite: AnimatedSprite2D, gun_base_position: Vector2, left_offset: Vector2 = Vector2.ZERO) -> float:
	var to_target: Vector2 = target_position - gun_sprite.global_position
	if to_target.length() <= 0.0:
		return 0.0
	
	var angle: float = to_target.angle()
	var target_angle: float = angle
	var facing_right: bool = to_target.x >= 0.0
	
	if facing_right:
		target_angle = clamp(angle, -PI / 2.0, PI / 2.0)
		gun_sprite.scale.x = 1.0
		animated_sprite.flip_h = false
		gun_sprite.position = gun_base_position
	else:
		gun_sprite.scale.x = -1.0
		animated_sprite.flip_h = true
		gun_sprite.position = gun_base_position + left_offset
		
		# Better angle calculation for left-facing
		if angle >= 0:
			target_angle = -(PI - angle)
		else:
			target_angle = -(-PI - angle)
		
		target_angle = clamp(target_angle, -PI / 2.0, PI / 2.0)
	
	return target_angle

# Clean floating popup method (similar to cash popup)
static func spawn_floating_popup(character: Node2D, text: String, color: Color, offset: Vector2 = Vector2(0, -20), font_size: int = FontConfig.DEFAULT_POPUP_FONT_SIZE, height: float = 0.0) -> void:
	var scene := character.get_tree().current_scene
	if scene == null:
		return

	var popup_root := Node2D.new()
	# Use pixel-perfect positioning to prevent blurriness
	# Add height offset to prevent overlapping popups
	popup_root.position = (character.global_position + offset + Vector2(0, -height)).round()
	scene.add_child(popup_root)

	var label := Label.new()
	label.text = text
	label.modulate = color
# Apply popup font (no outlines)
	FontConfig.apply_popup_font(label)
	# Override font size if it's not the default
	if font_size != FontConfig.DEFAULT_POPUP_FONT_SIZE:
		label.add_theme_font_size_override("font_size", font_size)

	popup_root.add_child(label)

	var tween := scene.get_tree().create_tween()
	
	# Check if this is an HP popup (contains "HP" text)
	var is_hp_popup = "HP" in text
	
	if is_hp_popup:
		# Add flicker effect for HP popups
		var flicker_tween := scene.get_tree().create_tween()
		flicker_tween.set_loops(3)  # Flicker 3 times
		flicker_tween.tween_property(label, "modulate:a", 0.3, 0.1)  # Fade to 30% opacity
		flicker_tween.tween_property(label, "modulate:a", 1.0, 0.1)  # Back to full opacity
	
	# Popup: float up and fade over ~0.5 seconds
	tween.tween_property(popup_root, "position:y", popup_root.position.y - 20.0, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.finished.connect(popup_root.queue_free)

# Health system utilities
static func apply_damage_with_effects(character: Node2D, amount: int, blood_scene: PackedScene, blood_splat_sound: AudioStream, hit_player: AudioStreamPlayer2D = null, bullet_direction: Vector2 = Vector2.ZERO, hit_position: Vector2 = Vector2.ZERO) -> void:
	# Spawn blood splash at hit position or character center
	if blood_scene:
		var blood := blood_scene.instantiate()
		var scene := character.get_tree().current_scene
		if blood and scene:
			# Use existing position to avoid creating new Vector2
			var spawn_position := hit_position
			if spawn_position == Vector2.ZERO:
				spawn_position = character.global_position
			
			# For alive enemies, offset blood position backwards from bullet impact
			var is_dead: bool = "is_dead" in character and character.is_dead
			if not is_dead and bullet_direction != Vector2.ZERO:
				# Offset blood spawn position backwards along bullet direction
				var backward_offset := bullet_direction.normalized() * 12.0  # 12 pixels behind impact
				spawn_position += backward_offset
			
			# Reuse offset calculation
			var offset_x := randf_range(-4.0, 4.0)
			var offset_y := randf_range(-4.0, 4.0)
			blood.global_position = spawn_position + Vector2(offset_x, offset_y)
			
			# Set dead enemy flag to reduce blood amount
			blood.set_dead_enemy(is_dead)
			
			# Set blood direction based on bullet direction or character state
			if bullet_direction != Vector2.ZERO:
				# Check if bullet direction is mostly vertical (gun angled up/down relative to body)
				const VERTICAL_THRESHOLD := 0.94  # ~70-degree angle threshold
				if abs(bullet_direction.y) > VERTICAL_THRESHOLD:
					# Gun is mostly vertical - make blood splash upwards
					blood.set_direction(Vector2.UP)
				else:
					# Normal horizontal bullet direction - use bullet direction for realistic blood spray
					blood.set_direction(bullet_direction)
			else:
				# Fallback to character-based direction for non-bullet damage
				if "is_dead" in character and character.is_dead:
					# Dead characters: fountain effect (upward)
					blood.set_direction(Vector2.UP)
				else:
					# Alive characters: normal sideways blood based on facing direction
					var facing_dir := Vector2.LEFT
					if character.has_node("AnimatedSprite2D"):
						var sprite = character.get_node("AnimatedSprite2D") as AnimatedSprite2D
						facing_dir = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
					blood.set_direction(facing_dir)
			
			# Initialize scene cache and use cached references for better performance
			_initialize_scene_cache(scene)
			var wall_node: Node = _cached_wall_node.get_ref()
			var background_node: Node = _cached_background_node.get_ref()
			
			# Place blood at the very bottom layer (first to be drawn)
			scene.add_child(blood)
			scene.move_child(blood, 0)
	
	# Play blood splat sound
	if blood_splat_sound:
		AudioUtils.play_blood_splat_sound(blood_splat_sound, character.global_position)
	
	# Play hit sound if available
	if hit_player:
		AudioUtils.play_random_pitch(hit_player, 0.7, 1.6)
	
	# Centralized camera shake for successful damage only
	_trigger_camera_shake(character)

# Centralized camera shake system
static func _trigger_camera_shake(damaged_character: Node2D) -> void:
	# Use cached player reference to avoid expensive lookups
	var player = _cached_player_ref.get_ref()
	if not player:
		player = damaged_character.get_tree().current_scene.get_node_or_null("Player")
		_cached_player_ref = weakref(player)
	
	if player == null:
		return
	
	# Only trigger camera shake if the damaged character is not the player
	# AND the character is not dead (skip dead bodies)
	if damaged_character != player and player.has_method("_start_camera_shake"):
		# Check if damaged character is dead - skip shake for dead bodies
		var is_dead = false
		if damaged_character.has_method("is_dead"):
			is_dead = damaged_character.is_dead()
		elif "is_dead" in damaged_character:
			is_dead = damaged_character.is_dead
		
		if is_dead:
			return
		player._start_camera_shake()

# Knockback system utilities
static func apply_knockback(character: CharacterBody2D, direction: float, strength: float, duration: float) -> void:
	# Apply knockback velocity
	if character.has_method("set_knockback"):
		character.set_knockback(direction * strength, duration)
	else:
		# Fallback: directly modify velocity if character doesn't have knockback system
		character.velocity.x = direction * strength

# Animation utilities
static func play_character_animation(animated_sprite: AnimatedSprite2D, anim_name: String) -> void:
	if animated_sprite and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)

static func set_character_facing(animated_sprite: AnimatedSprite2D, should_face_left: bool) -> void:
	if animated_sprite:
		animated_sprite.flip_h = should_face_left

# ===== DIALOGUE SYSTEM FOR CUTSCENES =====

# Dialogue data structure for characters
class DialogueData:
	var active: bool = false
	var box: Control = null
	var label: RichTextLabel = null
	var portrait: TextureRect = null
	var tween: Tween = null
	var current_text: String = ""
	var current_parts: PackedStringArray = []
	var current_index: int = 0
	var portrait_path: String = ""
	var waiting_for_input: bool = false
	var character: Node = null
	var typing_sound_player: AudioStreamPlayer = null
	var blink_tween: Tween = null  # For blinking > symbol
	var original_text: String = ""  # Store text without > symbol
	
	func clear() -> void:
		active = false
		box = null
		label = null
		portrait = null
		tween = null
		blink_tween = null
		current_text = ""
		original_text = ""
		current_parts.clear()
		current_index = 0
		portrait_path = ""
		waiting_for_input = false
		character = null
		typing_sound_player = null

# Character dialogue instances
static var _player_dialogue: DialogueData = DialogueData.new()
static var _enemy_dialogue: DialogueData = DialogueData.new()

# Show dialogue for any character (player or enemy)
# character: the character showing dialogue
# dialogue_text: text to display (supports <break> tags)
# portrait_path: optional path to portrait image
# text_speed: seconds per character (default 0.05)
# is_enemy: true if this is enemy dialogue, false for player dialogue
static func show_dialogue(character: Node, dialogue_text: String, portrait_path: String = "", text_speed: float = 0.05, is_enemy: bool = false) -> void:
	var dialogue_data = _enemy_dialogue if is_enemy else _player_dialogue
	
	if dialogue_data.active:
		return  # Don't overlap dialogues
	
	# Store dialogue data
	dialogue_data.current_text = dialogue_text
	dialogue_data.portrait_path = portrait_path
	dialogue_data.character = character
	
	# Split dialogue by <break> tags
	dialogue_data.current_parts = dialogue_text.split("<break>", false)
	dialogue_data.current_index = 0
	
	# Create dialogue UI
	_create_dialogue_ui(character, dialogue_data, is_enemy)
	
	# Start showing dialogue
	dialogue_data.active = true
	_show_dialogue_part(character, dialogue_data, text_speed)

# Create dialogue UI for character
static func _create_dialogue_ui(character: Node, dialogue_data: DialogueData, is_enemy: bool) -> void:
	# Create main dialogue container with black background
	dialogue_data.box = Control.new()
	dialogue_data.box.z_index = 1000  # Show on top of everything
	
	# Get viewport size for relative positioning
	var viewport_size = character.get_viewport().get_visible_rect().size
	var dialogue_width = viewport_size.x * DIALOGUE_WIDTH_RATIO
	var dialogue_height = viewport_size.y * DIALOGUE_HEIGHT_RATIO
	var dialogue_top_y = viewport_size.y * DIALOGUE_TOP_Y_RATIO
	var dialogue_half_width = dialogue_width / 2
	
	# Anchor container to center-top of screen using relative positioning
	dialogue_data.box.anchor_left = 0.5
	dialogue_data.box.anchor_right = 0.5
	dialogue_data.box.anchor_top = 0
	dialogue_data.box.offset_left = -dialogue_half_width  # Center the dialogue box
	dialogue_data.box.offset_right = dialogue_half_width   # Center the dialogue box
	dialogue_data.box.offset_top = dialogue_top_y
	dialogue_data.box.offset_bottom = dialogue_top_y + dialogue_height
	
	# Add black background panel
	var background_panel = Panel.new()
	background_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Create custom style with white border
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color.BLACK
	style_box.border_width_left = 4
	style_box.border_width_right = 4
	style_box.border_width_top = 4
	style_box.border_width_bottom = 4
	style_box.border_color = Color.WHITE
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	
	background_panel.add_theme_stylebox_override("panel", style_box)
	dialogue_data.box.add_child(background_panel)
	
	# Create container for portrait and text
	var container = HBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.add_theme_constant_override("separation", 15)
	
	# Add margin to center content
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)  # Same right margin for both player and enemy
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	
	dialogue_data.box.add_child(margin)
	margin.add_child(container)
	
	# Create portrait
	dialogue_data.portrait = TextureRect.new()
	dialogue_data.portrait.custom_minimum_size = Vector2(80, 80)  # Square portrait
	dialogue_data.portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	dialogue_data.portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	
	# Load portrait if path provided
	if dialogue_data.portrait_path != "":
		var portrait_texture = load(dialogue_data.portrait_path)
		if portrait_texture:
			dialogue_data.portrait.texture = portrait_texture
	
	# Create text container
	var text_container = VBoxContainer.new()
	text_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Mirror portrait positions: player portrait on left, enemy portrait on right
	if is_enemy:
		# Enemy dialogue: text first, then portrait (portrait on right)
		container.add_child(text_container)
		container.add_child(dialogue_data.portrait)
	else:
		# Player dialogue: portrait first, then text (portrait on left)
		container.add_child(dialogue_data.portrait)
		container.add_child(text_container)
	
	text_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Create speaker label (shows who is speaking) - left aligned
	var speaker_label = Label.new()
	speaker_label.text = "Enemy" if is_enemy else "Player"
	speaker_label.add_theme_font_size_override("font_size", 18)
	speaker_label.add_theme_color_override("font_color", Color.CYAN)  # Same cyan color for both player and enemy
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT  # Always left align character name for everyone
	# Apply default font from FontConfig
	FontConfig.apply_ui_font(speaker_label)
	text_container.add_child(speaker_label)
	
	# Create dialogue label - left aligned
	dialogue_data.label = RichTextLabel.new()
	dialogue_data.label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_data.label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_data.label.custom_minimum_size = Vector2(600, 0)
	
	dialogue_data.label.bbcode_enabled = true
	dialogue_data.label.autowrap_mode = TextServer.AUTOWRAP_WORD
	dialogue_data.label.scroll_active = false
	dialogue_data.label.fit_content = false
	
	dialogue_data.label.text = ""
	dialogue_data.label.add_theme_font_size_override("normal_font_size", 16)
	dialogue_data.label.add_theme_color_override("default_color", Color.WHITE)
	dialogue_data.label.add_theme_constant_override("line_separation", 4)
	dialogue_data.label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT  # Always left align text for everyone
	# Apply default font from FontConfig for RichTextLabel
	FontConfig.apply_dialogue_font(dialogue_data.label)
	text_container.add_child(dialogue_data.label)
	
	# Add dialogue box to UI layer (not world scene)
	var scene = character.get_tree().current_scene
	if scene:
		# Try to find UI layer first
		var ui_layer = scene.get_node_or_null("UI")
		if ui_layer:
			ui_layer.add_child(dialogue_data.box)
		else:
			# Fallback to scene root if no UI layer found
			scene.add_child(dialogue_data.box)

# Show a part of the dialogue with gradual text reveal using substring approach
static func _show_dialogue_part(character: Node, dialogue_data: DialogueData, text_speed: float) -> void:
	if dialogue_data.current_index >= dialogue_data.current_parts.size():
		_hide_dialogue(character, dialogue_data)
		return
	
	var current_part = dialogue_data.current_parts[dialogue_data.current_index]
	
	# Store original text without > symbol
	dialogue_data.original_text = current_part
	
	# Set full text immediately (prevents layout shifts)
	dialogue_data.label.text = current_part
	
	# Kill existing tween if any
	if dialogue_data.tween and dialogue_data.tween.is_valid():
		dialogue_data.tween.kill()
	
	# Kill existing blink tween if any
	if dialogue_data.blink_tween and dialogue_data.blink_tween.is_valid():
		dialogue_data.blink_tween.kill()
	
	# Create new tween for substring-based reveal
	dialogue_data.tween = character.create_tween()
	dialogue_data.tween.set_parallel(false)
	
	# Store the full text for substring operations
	var full_text = current_part
	var total_chars = full_text.length()
	
	# Start with empty visible text
	dialogue_data.label.visible_ratio = 0.0
	
	# Create and start typing sound
	_setup_typing_sound(dialogue_data)
	_play_typing_sound(dialogue_data)
	
	# Gradual reveal using visible_ratio (more efficient than character insertion)
	var reveal_duration = text_speed * total_chars
	dialogue_data.tween.tween_method(
		func(progress: float): dialogue_data.label.visible_ratio = progress,
		0.0, 1.0, reveal_duration
	)
	
	# Wait for completion, then stop sound and add blinking > symbol
	dialogue_data.tween.tween_callback(_stop_typing_sound.bind(dialogue_data))
	dialogue_data.tween.tween_callback(_start_blinking_arrow.bind(character, dialogue_data))
	dialogue_data.tween.tween_callback(_setup_dialogue_input_wait.bind(character, dialogue_data))

# Setup waiting for player input to continue dialogue
static func _setup_dialogue_input_wait(character: Node, dialogue_data: DialogueData) -> void:
	dialogue_data.waiting_for_input = true

# Start blinking > symbol after text reveal
static func _start_blinking_arrow(character: Node, dialogue_data: DialogueData) -> void:
	if not dialogue_data.label:
		return
	
	# Create blinking tween
	dialogue_data.blink_tween = character.create_tween()
	dialogue_data.blink_tween.set_loops()  # Loop infinitely
	
	# Blink between original text and text with > symbol
	var text_with_arrow = dialogue_data.original_text + " >"
	
	dialogue_data.blink_tween.tween_callback(func(): dialogue_data.label.text = text_with_arrow)
	dialogue_data.blink_tween.tween_interval(0.5)
	dialogue_data.blink_tween.tween_callback(func(): dialogue_data.label.text = dialogue_data.original_text)
	dialogue_data.blink_tween.tween_interval(0.5)

# Stop blinking > symbol
static func _stop_blinking_arrow(dialogue_data: DialogueData) -> void:
	if dialogue_data.blink_tween and dialogue_data.blink_tween.is_valid():
		dialogue_data.blink_tween.kill()
		dialogue_data.blink_tween = null
	
	# Restore original text
	if dialogue_data.label and dialogue_data.original_text != "":
		dialogue_data.label.text = dialogue_data.original_text

# Check if dialogue is waiting for player input
static func is_waiting_for_input(is_enemy: bool = false) -> bool:
	var dialogue_data = _enemy_dialogue if is_enemy else _player_dialogue
	return dialogue_data.waiting_for_input

# Check if dialogue is currently active (animating or waiting)
static func is_dialogue_active(is_enemy: bool = false) -> bool:
	var dialogue_data = _enemy_dialogue if is_enemy else _player_dialogue
	return dialogue_data.active

# Handle player input to continue dialogue
static func handle_dialogue_input(is_enemy: bool = false) -> void:
	var dialogue_data = _enemy_dialogue if is_enemy else _player_dialogue
	print("DEBUG: handle_dialogue_input called, is_enemy: ", is_enemy, " waiting_for_input: ", dialogue_data.waiting_for_input)
	
	# Check if text animation is still playing (tween is active)
	if dialogue_data.tween and dialogue_data.tween.is_valid():
		print("DEBUG: Text animation still playing, skipping to full text")
		# Stop the animation tween
		dialogue_data.tween.kill()
		# Show full text immediately
		dialogue_data.label.visible_ratio = 1.0
		# Stop typing sound
		_stop_typing_sound(dialogue_data)
		# Start blinking arrow and setup input wait
		_start_blinking_arrow(dialogue_data.character, dialogue_data)
		_setup_dialogue_input_wait(dialogue_data.character, dialogue_data)
	elif dialogue_data.waiting_for_input:
		dialogue_data.waiting_for_input = false
		_continue_dialogue(dialogue_data.character, dialogue_data)
	else:
		print("DEBUG: Not waiting for input, ignoring")

# Continue to next dialogue part
static func _continue_dialogue(character: Node, dialogue_data: DialogueData) -> void:
	print("DEBUG: _continue_dialogue called, current_index: ", dialogue_data.current_index, " parts size: ", dialogue_data.current_parts.size())
	
	# Stop blinking arrow before continuing
	_stop_blinking_arrow(dialogue_data)
	
	dialogue_data.current_index += 1
	
	# Check if there are more dialogue parts
	if dialogue_data.current_index >= dialogue_data.current_parts.size():
		print("DEBUG: No more dialogue parts, hiding dialogue")
		# No more dialogue parts, hide dialogue
		_hide_dialogue(character, dialogue_data)
	else:
		print("DEBUG: Showing next dialogue part")
		# Show next dialogue part
		_show_dialogue_part(character, dialogue_data, 0.05)

# Hide dialogue and clean up
static func _hide_dialogue(character: Node, dialogue_data: DialogueData) -> void:
	print("DEBUG: _hide_dialogue called")
	if dialogue_data.box:
		# Stop typing sound if playing
		_stop_typing_sound(dialogue_data)
		# Stop blinking arrow if playing
		_stop_blinking_arrow(dialogue_data)
		dialogue_data.box.queue_free()
		dialogue_data.clear()
		print("DEBUG: Dialogue data cleared")

# Setup typing sound player
static func _setup_typing_sound(dialogue_data: DialogueData) -> void:
	# Create audio player if it doesn't exist
	if not dialogue_data.typing_sound_player:
		dialogue_data.typing_sound_player = AudioStreamPlayer.new()
		dialogue_data.typing_sound_player.autoplay = false
		dialogue_data.character.add_child(dialogue_data.typing_sound_player)
		# Connect finished signal for manual looping
		dialogue_data.typing_sound_player.finished.connect(_on_sound_finished.bind(dialogue_data))
	
	# Load character-specific sound
	var sound_path: String
	# More robust character type detection
	var character_name = dialogue_data.character.get_script().get_global_name()
	var is_enemy = dialogue_data.character.is_in_group("enemy")
	
	print("DEBUG: Character name: ", character_name)
	print("DEBUG: Is enemy: ", is_enemy)
	
	# Check for enemy class names (contains "Enemy" or specific class names)
	if character_name == "Enemy" or character_name == "AxeEnemy" or character_name.contains("Enemy"):
		sound_path = "res://sounds/enemy dialogue.wav"
		print("DEBUG: Selected enemy dialogue sound")
	elif character_name == "Player":
		sound_path = "res://sounds/player dialogue.wav"
		print("DEBUG: Selected player dialogue sound")
	elif is_enemy:
		sound_path = "res://sounds/enemy dialogue.wav"
		print("DEBUG: Selected enemy dialogue sound (group check)")
	else:
		sound_path = "res://sounds/player dialogue.wav"
		print("DEBUG: Selected player dialogue sound (default)")
	
	print("DEBUG: Final sound path: ", sound_path)
	dialogue_data.typing_sound_player.stream = load(sound_path)

# Handle sound finished signal for manual looping
static func _on_sound_finished(dialogue_data: DialogueData) -> void:
	# Replay the sound if dialogue is still revealing text
	if dialogue_data.active and dialogue_data.tween and dialogue_data.tween.is_valid():
		dialogue_data.typing_sound_player.play()

# Play typing sound in loop
static func _play_typing_sound(dialogue_data: DialogueData) -> void:
	if dialogue_data.typing_sound_player:
		dialogue_data.typing_sound_player.play()

# Stop typing sound
static func _stop_typing_sound(dialogue_data: DialogueData) -> void:
	if dialogue_data.typing_sound_player and dialogue_data.typing_sound_player.playing:
		dialogue_data.typing_sound_player.stop()

# Force hide all dialogue (useful for scene changes)
static func hide_all_dialogue() -> void:
	_player_dialogue.clear()
	_enemy_dialogue.clear()
