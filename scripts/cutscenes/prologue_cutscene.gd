extends "res://scripts/cutscenes/cutscene_base.gd"

var _hb_faded_out: bool = false
var _title_showing: bool = true
var _title_label: Label
var _thud_sound: AudioStreamPlayer
var _main_text_started: bool = false
var _title_timer: SceneTreeTimer
var _title_minimum_time: float = 3.0
var _title_elapsed_time: float = 0.0
var _title_can_skip: bool = false

func _ready() -> void:
	# Hide cursor initially
	if dialogue_label:
		dialogue_label.visible = false
	# Initialize thud sound
	_thud_sound = AudioStreamPlayer.new()
	add_child(_thud_sound)
	var thud_sound = preload("res://sounds/thud.mp3")
	if thud_sound:
		_thud_sound.stream = thud_sound

	# Create title label
	_title_label = Label.new()
	_title_label.text = "DECADES AFTER THE FALL..."
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.size = Vector2(800, 100)  # Fixed size for the label
	_title_label.position = Vector2(
		(get_viewport_rect().size.x - 1900) * 0.5,  # Center horizontally
		(get_viewport_rect().size.y - 700) * 0.5   # Center vertically
	)
	_title_label.anchor_left = 0.5
	_title_label.anchor_top = 0.5
	_title_label.anchor_right = 0.5
	_title_label.anchor_bottom = 0.5
	_title_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_title_label.modulate.a = 0.0  # Start invisible
	
	# Set up font for the title
	var font = preload("res://fonts/PixelOperator8.ttf")
	_title_label.add_theme_font_override("font", font)
	_title_label.add_theme_font_size_override("font_size", 36)  # Larger size for the title
	
	add_child(_title_label)

	# Set up heartbeat player
	if heartbeat_player:
		heartbeat_player.volume_db = -30.0
		if heartbeat_player.stream:
			heartbeat_player.stream.loop = true

	_setup_cutscene_common()
	_full_text = "The world ended a long time ago. (pause=0.5) \nMost folks just didn't notice until it was too late. <break>Been down here so long I forgot what the sun feels like. <break>TWENTY YEARS.(pause=1.0)\n<r>TWENTY (pause=0.5)FUCKIN' (pause=0.5)YEARS</r>. <break>It's finally time to cut the leash."
	_next_scene_path = "res://scenes/cutscenes/monitor_cutscene.tscn"

	# Set up a timer to show the title after a delay
	_title_timer = get_tree().create_timer(1.5)  # 1.5 second delay
	_title_timer.timeout.connect(_on_title_timer_timeout)
	
	# Set up timer for minimum title display time
	var min_time_timer = get_tree().create_timer(_title_minimum_time)
	min_time_timer.timeout.connect(_on_minimum_time_elapsed)
	
	# Set up heartbeat fade in after a short delay
	if heartbeat_player:
		var tween = create_tween()
		tween.tween_property(heartbeat_player, "volume_db", -8.0, 1.2).set_delay(0.5)

func _on_title_timer_timeout() -> void:
	# Play thud sound and show title with fade in
	if _thud_sound.stream:
		_thud_sound.play()
	
	# Fade in title
	var tween = create_tween()
	tween.tween_property(_title_label, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_LINEAR)

	# Trigger a fade-in from black for the first cutscene
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
				root.add_child(tm)
		if tm:
			tm.fade_in(1.5)


func _start_typing(text: String) -> void:
	# Show the dialogue label when starting to type
	if dialogue_label:
		dialogue_label.visible = true
	super._start_typing(text)
	if typing_player and typing_player.stream:
		typing_player.play()

func _start_main_text() -> void:
	if not _main_text_started:
		_main_text_started = true
		# Make sure the dialogue label is visible
		if dialogue_label:
			dialogue_label.modulate.a = 1.0
		# Start typing the main text (this will show the cursor)
		_start_typing(_full_text)
		# Remove the title label after fade out is complete
		if _title_label:
			_title_label.queue_free()

func _on_minimum_time_elapsed() -> void:
	_title_can_skip = true

func _skip_cutscene() -> void:
	# Stop all audio
	if typing_player and typing_player.playing:
		typing_player.stop()
	if heartbeat_player and heartbeat_player.playing:
		heartbeat_player.stop()
	if _thud_sound and _thud_sound.playing:
		_thud_sound.stop()
	
	# Clean up title label if it exists
	if _title_label:
		_title_label.queue_free()
	
	# Go directly to next scene
	if _next_scene_path != "":
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
					root.add_child(tm)
			if tm:
				tm.fade_to_scene(_next_scene_path, 1.0, 1.0)
			else:
				tree.change_scene_to_file(_next_scene_path)

func _unhandled_input(event: InputEvent) -> void:
	var pressed_accept := event.is_action_pressed("ui_accept")
	var pressed_space: bool = event is InputEventKey and event.pressed and event.keycode == KEY_SPACE
	var pressed_escape: bool = event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE
	
	# Skip button (ESC) - bypass all dialogue and go to next scene
	if pressed_escape:
		_skip_cutscene()
		return
		
	if not (pressed_accept or pressed_space):
		return
		
	if _title_showing:
		# Only allow skipping after minimum time has elapsed
		if _title_can_skip:
			_title_showing = false
			var tween = create_tween()
			tween.tween_property(_title_label, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_LINEAR)
			tween.tween_callback(_start_main_text)
			return
		else:
			# Don't allow skipping before minimum time
			return

	if _awaiting_break_continue:
		super._unhandled_input(event)
		return

	if _can_advance and _next_scene_path != "":
		if heartbeat_player and not _hb_faded_out:
			_hb_faded_out = true
			var t := create_tween()
			t.tween_property(heartbeat_player, "volume_db", -40.0, 1.5)
			t.tween_callback(Callable(heartbeat_player, "stop"))
		super._unhandled_input(event)
		return

	super._unhandled_input(event)
