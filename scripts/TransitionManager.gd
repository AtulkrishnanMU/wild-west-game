extends Node

var _overlay: ColorRect
var _is_running: bool = false
var _target_scene: String = ""
var _fade_out_time: float = 1.5
var _fade_in_time: float = 1.5

func _ready() -> void:
	# Create a fullscreen overlay that sits on top of the scene tree
	var root := get_tree().get_root()
	_overlay = ColorRect.new()
	_overlay.name = "GlobalFadeOverlay"
	_overlay.color = Color(0, 0, 0, 1)
	_overlay.modulate.a = 0.0
	_overlay.anchor_left = 0.0
	_overlay.anchor_top = 0.0
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.show_behind_parent = false
	_overlay.z_index = 1000
	root.add_child(_overlay)


func fade_in(duration: float = 1.5) -> void:
	# Simple fade from black to transparent without changing scene
	_overlay.modulate.a = 1.0
	_overlay.visible = true
	var tween := create_tween()
	tween.tween_property(_overlay, "modulate:a", 0.0, duration)

func fade_to_scene(path: String, fade_out_time: float = 1.5, fade_in_time: float = 1.5) -> void:
	if _is_running:
		return
	_is_running = true
	_target_scene = path
	_fade_out_time = fade_out_time
	_fade_in_time = fade_in_time
	# Ensure overlay starts transparent
	_overlay.modulate.a = 0.0
	_overlay.visible = true
	var tween := create_tween()
	# Fade from transparent to black
	tween.tween_property(_overlay, "modulate:a", 1.0, _fade_out_time)
	# After fade-out, change scene, then fade back in
	tween.tween_callback(Callable(self, "_do_change_scene"))
	tween.tween_property(_overlay, "modulate:a", 0.0, _fade_in_time)
	tween.tween_callback(Callable(self, "_finish"))

func _do_change_scene() -> void:
	if _target_scene == "":
		return
	var tree := get_tree()
	if tree:
		tree.change_scene_to_file(_target_scene)

func _finish() -> void:
	_is_running = false
