extends "res://scripts/cutscenes/cutscene_base.gd"

func _ready() -> void:
	_setup_cutscene_common()
	_full_text = "They called him the <r>Dead Eye Hunter</r>.(pause=1.0)\nA ghost in the gutters of this city..."
	_next_scene_path = "res://scenes/cutscenes/intro_cutscene.tscn"
	_start_typing(_full_text)

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
