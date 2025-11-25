extends "res://scripts/cutscenes/cutscene_base.gd"

var _hb_faded_out: bool = false

func _ready() -> void:
	if heartbeat_player:
		heartbeat_player.volume_db = -30.0
		if heartbeat_player.stream:
			heartbeat_player.stream.loop = true

	_setup_cutscene_common()
	_full_text = "...(pause=2.0)<sounds/clock-and-gun-shots.mp3>HEARD THAT? (pause=1.0)\nTHAT USED TO BE MY VOICE FOR TWENTY YEARS.(pause=2.0)\n<r>TWENTY (pause=0.5)FUCKIN’ (pause=0.5)YEARS</r>. (pause=1.0)\nI WAS LIKE A DOG FOR THEM."
	_next_scene_path = "res://scenes/cutscenes/intro_cutscene.tscn"
	_start_typing(_full_text)

	if heartbeat_player:
		var t := create_tween()
		t.tween_property(heartbeat_player, "volume_db", -8.0, 1.2)

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


func _unhandled_input(event: InputEvent) -> void:
	var pressed_accept := event.is_action_pressed("ui_accept")
	var pressed_space: bool = event is InputEventKey and event.pressed and event.keycode == KEY_SPACE
	if not (pressed_accept or pressed_space):
		super._unhandled_input(event)
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
