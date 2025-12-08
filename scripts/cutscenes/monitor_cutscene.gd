extends Node2D

# Font configuration
const FontConfig := preload("res://scripts/utils/font_config.gd")

# References to nodes
@onready var dialogue_label: RichTextLabel = $CanvasLayer/RichTextLabel
@onready var typing_player: AudioStreamPlayer = $TypingPlayer
@onready var pc_screen: Sprite2D = $CanvasLayer/PcScreen
@onready var pixel1: ColorRect = $CanvasLayer/Pixel1
@onready var pixel2: ColorRect = $CanvasLayer/Pixel2
var _pc_sound_player: AudioStreamPlayer
var _alert_sound_player: AudioStreamPlayer

# Typing effect
var _full_text: String = ""
var _display_text: String = ""
var _can_advance: bool = false
var _char_index: int = 0
var _typing_speed: float = 0.0001  # Time between characters in seconds
var _typing_timer: float = 0.0
var _is_typing: bool = false
var _next_scene_path: String = ""
var _current_bbcode_tags: Array[String] = []
var _chars_per_frame: int = 2  # Type 2 characters at once for faster typing

# Cursor effect
var _cursor_timer: float = 0.0
var _cursor_blink_speed: float = 0.5  # Blink every 0.5 seconds
var _cursor_visible: bool = true
var _cursor_char: String = "_"

# Glitch effect
var _glitch_timer: float = 0.0
var _is_glitching: bool = false
var _glitch_duration: float = 0.05  # How long the glitch lasts
var _glitch_chars: String = "!@#$%^&*()_+-=[]{}|;:,.<>/?~`"
var _glitch_chance: float = 0.01  # 1% chance of glitch per character

# Typing sound variations
var _sound_variation_timer: float = 0.0
var _sound_variation_interval: float = 1.0  # Change sound every 1 second

# Text glitch effect (disabled)
var _text_glitch_timer: float = 0.0
var _text_glitch_interval: float = 0.0  # Disabled
var _text_glitch_duration: float = 0.0  # Disabled
var _text_glitch_active: bool = false
var _next_glitch_time: float = 0.0

# Pixel blinking effect
var _pixel_blink_timer: float = 0.0
var _pixel_blink_speed: float = 0.3  # Blink every 0.3 seconds (faster)
var _pixel_visible: bool = true
var _pixel_min_opacity: float = 0.3  # Minimum opacity during blink (30%)
var _pixel_max_opacity: float = 1.0  # Maximum opacity (100%)

func _ready() -> void:
	# Hide dialogue label and PC screen initially
	if dialogue_label:
		dialogue_label.modulate.a = 0.0
	if pc_screen:
		pc_screen.modulate.a = 0.0
	
	# Initialize pixels
	if pixel1 and pixel2:
		pixel1.modulate.a = _pixel_max_opacity
		pixel2.modulate.a = _pixel_max_opacity
	
	
	# Initialize the cutscene
	_setup_cutscene()
	
	# Trigger fade-in effect for monitor cutscene
	var tree := get_tree()
	if tree:
		var root := tree.get_root()
		var tm := root.get_node_or_null("TransitionManager")
		if not tm:
			var tm_script := load("res://scripts/TransitionManager.gd")
			if tm_script:
				tm = Node.new()
				tm.name = "TransitionManager"
				tm.set_script(tm_script)
				root.add_child.call_deferred(tm)
				# Wait for the node to be added before using it
				await tree.process_frame
		if tm:
			tm.fade_in(1.0)  # Faster 1 second fade-in
			# Fade in PC screen and text after fade-in starts
			await get_tree().create_timer(0.5).timeout  # Wait for fade-in to start
			var tween := create_tween()
			if pc_screen:
				tween.tween_property(pc_screen, "modulate:a", 1.0, 0.5)  # PC screen fades in over 0.5s
			if dialogue_label:
				tween.tween_property(dialogue_label, "modulate:a", 1.0, 1.0)  # Text fades in over 1.0s
	
func _setup_cutscene() -> void:
	# Apply default font to monitor text
	FontConfig.apply_dialogue_font(dialogue_label)
	# Set consistent font size and line separation
	dialogue_label.add_theme_font_size_override("normal_font_size", 15)
	dialogue_label.add_theme_font_size_override("bold_font_size", 15)
	dialogue_label.add_theme_font_size_override("italics_font_size", 15)
	dialogue_label.add_theme_font_size_override("bold_italics_font_size", 15)
	dialogue_label.add_theme_font_size_override("mono_font_size", 15)
	
	dialogue_label.add_theme_constant_override("line_separation", 8)
	dialogue_label.add_theme_constant_override("line_height", 20)
	dialogue_label.add_theme_constant_override("paragraph_separation", 4)
	dialogue_label.visible = true
	# Enable BBCode for rich text formatting
	dialogue_label.bbcode_enabled = true
	
	# Set up PC background sound
	_pc_sound_player = AudioStreamPlayer.new()
	add_child(_pc_sound_player)
	var pc_sound = preload("res://sounds/PC_sound.mp3")
	if pc_sound:
		_pc_sound_player.stream = pc_sound
		_pc_sound_player.volume_db = -10.0  # Adjust volume as needed
		_pc_sound_player.stream.loop = true
		_pc_sound_player.play()
	
	# Set up alert background sound
	_alert_sound_player = AudioStreamPlayer.new()
	add_child(_alert_sound_player)
	var alert_sound = preload("res://sounds/alert.mp3")
	if alert_sound:
		_alert_sound_player.stream = alert_sound
		_alert_sound_player.volume_db = -8.0  # Slightly louder than PC sound
		_alert_sound_player.stream.loop = true
		_alert_sound_player.play()

	# Set the typing sound to digital-typing.mp3
	if typing_player:
		var typing_sound = preload("res://sounds/digital-typing.mp3")
		if typing_sound:
			typing_player.stream = typing_sound
			typing_player.stream.loop = true

	# Set the next scene to level 1
	_next_scene_path = "res://scenes/levels/level1.tscn"

	# Set the full text with proper formatting and colors
	# Using simplified BBCode that RichTextLabel can handle
	_full_text = """[color=#00ff00]╔════════════════════════════════════════════════════════════════════════╗
║                                  SYSWARN v4.3  
╚════════════════════════════════════════════════════════════════════════╝[/color]
timestamp:      2087-11-28 03:17:44 UTC
event_id:       IVN-EB-7713-A
classification: [color=#ff0000]LEVEL OMEGA BREACH[/color]

[color=#ff0000]>>> CONTAINMENT FAILURE
>>> PRISONER 7H-3R13-004K ESCAPED[/color]

breach_time:    03:16:02  sector_7
primary_node:   10.0.7.1    [color=#ff0000]OFFLINE[/color]
backup_node:    10.0.7.2    [color=#ffff00]DEGRADED[/color]
firewall:       [color=#ff0000]BYPASSED[/color]"""

	# Start typing the text
	_start_typing()

func _start_typing() -> void:
	_is_typing = true
	_char_index = 0
	_display_text = ""
	_current_bbcode_tags = []
	dialogue_label.text = ""
	dialogue_label.text = ""
	_can_advance = false
	
	# Start playing the typing sound if available
	if typing_player and not typing_player.playing:
		typing_player.play()

func _process(delta: float) -> void:
	# Handle pixel blinking effect
	if pixel1 and pixel2:
		_pixel_blink_timer += delta
		if _pixel_blink_timer >= _pixel_blink_speed:
			_pixel_blink_timer = 0.0
			_pixel_visible = not _pixel_visible
			
			# Set opacity based on visibility state
			var target_opacity = _pixel_max_opacity if _pixel_visible else _pixel_min_opacity
			pixel1.modulate.a = target_opacity
			pixel2.modulate.a = target_opacity
	
	# Handle typing sound variations
	if typing_player and typing_player.playing:
		_sound_variation_timer += delta
		if _sound_variation_timer >= _sound_variation_interval:
			_sound_variation_timer = 0.0
			# Random pitch between 0.8 and 1.2
			typing_player.pitch_scale = randf_range(0.8, 1.2)
			# Random volume between -10dB and -2dB
			typing_player.volume_db = randf_range(-10.0, -2.0)
	
	
	# Handle cursor blinking when typing or when typing is complete
	if _is_typing or _can_advance:
		_cursor_timer += delta
		if _cursor_timer >= _cursor_blink_speed:
			_cursor_timer = 0.0
			_cursor_visible = not _cursor_visible
	
		
	if not _is_typing and not _can_advance:
		# Hide cursor when not typing and not ready to advance
		if _cursor_visible:
			_cursor_visible = false
			_update_display_text()
		return
		
	_typing_timer += delta
	if _typing_timer >= _typing_speed:
		_typing_timer = 0.0
		
		# Type multiple characters at once
		for i in range(_chars_per_frame):
			# Get the next character
			if _char_index >= _full_text.length():
				# Finished typing
				_is_typing = false
				_can_advance = true
				if typing_player and typing_player.playing:
					typing_player.stop()
				_update_display_text()
				return
			
			# Get the next character
			var next_char = _full_text[_char_index]
			
			# Handle BBCode tags - just skip them for now
			if next_char == '[':
				var tag_end = _full_text.find("]", _char_index)
				if tag_end != -1:
					_char_index = tag_end + 1
					continue  # Skip to next iteration
			
			
			# Add the character to the display text
			_char_index += 1
			
			# Skip delay for newlines and spaces (only on last character)
			if next_char in ["\n", " "] and i == _chars_per_frame - 1:
				_typing_timer = -_typing_speed  # Negative to process next batch immediately
				break
		
		_update_display_text()

func _update_display_text() -> void:
	if _char_index >= _full_text.length():
		dialogue_label.text = _full_text
		# Add blinking cursor at the end when typing is complete
		if _can_advance and _cursor_visible:
			# Get the last color from the full text
			var current_color = "#00ff00"  # Default green
			var color_stack: Array[String] = ["#00ff00"]
			var i = 0
			
			while i < _full_text.length():
				if _full_text.substr(i, 7) == "[color=":
					var end_tag = _full_text.find("]", i)
					if end_tag != -1:
						var color_tag = _full_text.substr(i, end_tag - i + 1)
						var color_start = color_tag.find("#")
						if color_start != -1:
							var color_end = color_tag.find("]", color_start)
							if color_end != -1:
								var color = color_tag.substr(color_start, color_end - color_start)
								color_stack.append(color)
						i = end_tag + 1
				elif _full_text.substr(i, 8) == "[/color]":
					if color_stack.size() > 1:
						color_stack.pop_back()
					i += 8
				else:
					i += 1
			
			if color_stack.size() > 0:
				current_color = color_stack.back()
			
			dialogue_label.text += "[color=" + current_color + "]" + _cursor_char + "[/color]"
		return
	
	# Get current color context by analyzing the text up to cursor
	var current_color = "#00ff00"  # Default green
	var text_up_to_cursor = _full_text.substr(0, _char_index)
	
	# Track color stack to handle nested tags
	var color_stack: Array[String] = ["#00ff00"]
	var i = 0
	
	while i < text_up_to_cursor.length():
		if text_up_to_cursor.substr(i, 7) == "[color=":
			var end_tag = text_up_to_cursor.find("]", i)
			if end_tag != -1:
				var color_tag = text_up_to_cursor.substr(i, end_tag - i + 1)
				# Extract color value from tag
				var color_start = color_tag.find("#")
				if color_start != -1:
					var color_end = color_tag.find("]", color_start)
					if color_end != -1:
						var color = color_tag.substr(color_start, color_end - color_start)
						color_stack.append(color)
				i = end_tag + 1
		elif text_up_to_cursor.substr(i, 8) == "[/color]":
			if color_stack.size() > 1:
				color_stack.pop_back()
			i += 8
		else:
			i += 1
	
	# Get the current active color
	if color_stack.size() > 0:
		current_color = color_stack.back()
	
	# Build display text with cursor
	var display_text = text_up_to_cursor
	if _is_typing and _cursor_visible:
		display_text += "[color=" + current_color + "]" + _cursor_char + "[/color]"
	
	dialogue_label.text = display_text


func _unhandled_input(event: InputEvent) -> void:
	var pressed_accept := event.is_action_pressed("ui_accept")
	var pressed_space: bool = event is InputEventKey and event.pressed and event.keycode == KEY_SPACE
	
	if pressed_accept or pressed_space:
		if _can_advance:
			# Immediately start transition without delay
			_transition_to_level1()
		else:
			# Skip typing animation by showing all text immediately
			_is_typing = false
			dialogue_label.text = _full_text
			if typing_player and typing_player.playing:
				typing_player.stop()
			_can_advance = true
			return

func _transition_to_level1() -> void:
	# Create parallel tweens for simultaneous fade-out
	var tween := create_tween()
	tween.set_parallel(true)  # Allow all tweens to run simultaneously
	
	# Fade out visuals
	if dialogue_label:
		tween.tween_property(dialogue_label, "modulate:a", 0.0, 1.0)  # Text fades out over 1.0s
	if pc_screen:
		tween.tween_property(pc_screen, "modulate:a", 0.0, 2.0)  # PC screen fades out over 1.0s
	
	# Fade out audio simultaneously (but keep alert sound for smooth transition)
	tween.set_parallel(true)
	tween.tween_property(typing_player, "volume_db", -80.0, 1.0)  # Fade typing sound to silence
	if _pc_sound_player:
		tween.tween_property(_pc_sound_player, "volume_db", -80.0, 1.0)  # Fade PC sound to silence
	# NOTE: Keep alert sound playing for smooth transition to level1
	
	# Wait for all fade-outs to complete, then do scene transition
	await tween.finished
	
	# Stop all audio after fade-out (except alert sound for smooth transition)
	if typing_player and typing_player.playing:
		typing_player.stop()
	if _pc_sound_player and _pc_sound_player.playing:
		_pc_sound_player.stop()
	# NOTE: Keep alert sound playing for smooth transition to level1
	
	# Use TransitionManager for fade-out/fade-in when changing scenes
	if _next_scene_path and _next_scene_path != "":
		var tree := get_tree()
		if tree:
			var root := tree.get_root()
			var tm := root.get_node_or_null("TransitionManager")
			if not tm:
				var tm_script := load("res://scripts/TransitionManager.gd")
				if tm_script:
					tm = Node.new()
					tm.name = "TransitionManager"
					tm.set_script(tm_script)
					root.add_child.call_deferred(tm)
					# Wait for the node to be added before using it
					await tree.process_frame
			if tm:
				# Faster transitions - 0.8s fade out, 0.8s fade in
				tm.fade_to_scene(_next_scene_path, 0.8, 0.8)
			else:
				# Fallback: hard cut if TransitionManager couldn't be created
				tree.change_scene_to_file(_next_scene_path)
