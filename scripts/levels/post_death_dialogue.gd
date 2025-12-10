extends Control
class_name PostDeathDialogue

signal dialogue_finished

@onready var dialogue_label: RichTextLabel = $DialogueLabel
@onready var typing_player: AudioStreamPlayer = $TypingPlayer

var dialogue_text: String = ""
var typing_speed: float = 40.0  # Match cutscene typing speed
var _char_index: int = 0
var _time_accum: float = 0.0
var _typing_active: bool = false
var _can_advance: bool = false

func _ready() -> void:
	# Get text from the scene
	dialogue_text = dialogue_label.text
	
	# Setup dialogue label styling
	FontConfig.apply_dialogue_font(dialogue_label)
	dialogue_label.add_theme_constant_override("line_separation", 14)
	dialogue_label.bbcode_enabled = true
	dialogue_label.autowrap_mode = 2
	
	# Hide initially
	visible = false

func show_dialogue() -> void:
	visible = true
	_char_index = 0
	_time_accum = 0.0
	_typing_active = true
	_can_advance = false
	dialogue_label.text = ""  # Clear text for typing effect
	
	print("Starting dialogue with text: ", dialogue_text)
	print("Dialogue label position: ", dialogue_label.global_position)
	print("Dialogue label size: ", dialogue_label.size)
	print("Dialogue visible: ", visible)
	print("Typing speed: ", typing_speed)
	
	# Start typing effect
	_typing_active = true

func _process(delta: float) -> void:
	if not _typing_active:
		return
	
	# Typing effect
	_time_accum += delta
	var chars_to_type: int = int(_time_accum * typing_speed)
	
	print("Time accum: ", _time_accum, " Chars to type: ", chars_to_type, " Current index: ", _char_index)
	
	while _char_index < dialogue_text.length() and _char_index < chars_to_type:
		dialogue_label.text += dialogue_text[_char_index]
		_char_index += 1
		
		# Play typing sound for each character (but stop previous sound first)
		if typing_player:
			typing_player.stop()
			typing_player.pitch_scale = randf_range(0.8, 1.2)
			typing_player.play()
		
		print("Added character '", dialogue_text[_char_index - 1], "'. Current text: '", dialogue_label.text, "'")
	
	# Check if typing is complete
	if _char_index >= dialogue_text.length():
		_typing_active = false
		_can_advance = true
		# Stop typing sound when complete
		if typing_player:
			typing_player.stop()
		print("Typing complete, press spacebar to continue")

func _input(event: InputEvent) -> void:
	if not _can_advance:
		return
	
	# Check for spacebar press
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_finish_dialogue()

func _finish_dialogue() -> void:
	visible = false  # Hide instead of removing
	dialogue_finished.emit()
	# Don't queue_free() since this is now a permanent node in the scene

func skip_typing() -> void:
	if _typing_active:
		_char_index = dialogue_text.length()
		dialogue_label.text = dialogue_text
		_typing_active = false
		_can_advance = true
