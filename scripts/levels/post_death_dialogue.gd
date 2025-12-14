extends Control
class_name PostDeathDialogue

signal dialogue_finished

@onready var dialogue_label: RichTextLabel = $DialogueLabel
@onready var typing_player: AudioStreamPlayer = $TypingPlayer

var dialogue_text: String = ""
var words: PackedStringArray = []
var current_word_index: int = 0
var word_display_delay: float = 0.8  # Seconds between words
var _time_accum: float = 0.0
var _word_display_active: bool = false
var _can_advance: bool = false

# Gun shot sound
const GUN_SHOT_SOUND_PATH := "res://sounds/gun-shot.mp3"

func _ready() -> void:
	# Get text from the scene
	dialogue_text = dialogue_label.text
	
	# Split text into words
	words = dialogue_text.split(" ")
	
	# Setup dialogue label styling
	FontConfig.apply_custom_font_rich(dialogue_label, "res://fonts/Crédible-Regular.otf", 24)
	dialogue_label.add_theme_constant_override("line_separation", 14)
	dialogue_label.bbcode_enabled = true
	dialogue_label.autowrap_mode = 2
	
	# Hide initially
	visible = false

func show_dialogue() -> void:
	visible = true
	current_word_index = 0
	_time_accum = 0.0
	_word_display_active = true
	_can_advance = false
	dialogue_label.text = ""  # Clear text initially
	
	
	# Start word display effect
	_word_display_active = true

func _process(delta: float) -> void:
	if not _word_display_active:
		return
	
	# Word display effect
	_time_accum += delta
	
	# Check if it's time to show next word
	if _time_accum >= word_display_delay:
		_time_accum = 0.0
		
		if current_word_index < words.size():
			# Show next word
			if current_word_index > 0:
				dialogue_label.text += " "  # Add space between words
			dialogue_label.text += words[current_word_index]
			
			# Play gun shot sound
			_play_gun_shot_sound()
			
			
			current_word_index += 1
		else:
			# All words displayed
			_word_display_active = false
			_can_advance = true

func _play_gun_shot_sound() -> void:
	var gun_shot_sound = load(GUN_SHOT_SOUND_PATH)
	if gun_shot_sound:
		var audio := AudioStreamPlayer2D.new()
		audio.stream = gun_shot_sound
		audio.position = global_position
		get_tree().current_scene.add_child(audio)
		AudioUtils.play_random_pitch(audio, 0.9, 1.2)
		audio.finished.connect(audio.queue_free)

func _input(event: InputEvent) -> void:
	if not _can_advance:
		return
	
	# Check for spacebar press
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_finish_dialogue()

func _finish_dialogue() -> void:
	# Keep the text visible, just emit the signal
	dialogue_finished.emit()
	# Don't hide the dialogue or queue_free() - let the text stay visible

func skip_typing() -> void:
	if _word_display_active:
		# Show all remaining words at once
		dialogue_label.text = ""
		for i in range(words.size()):
			if i > 0:
				dialogue_label.text += "  "
			dialogue_label.text += words[i]
		_word_display_active = false
		_can_advance = true
