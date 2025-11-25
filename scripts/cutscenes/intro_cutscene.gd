extends "res://scripts/cutscenes/cutscene_base.gd"

@export var base_speed: float = 8.0

@onready var city_layers: Array[Node2D] = [
	$CityRoot/Layer1,
	$CityRoot/Layer2,
	$CityRoot/Layer3,
	$CityRoot/Layer4,
	$CityRoot/Layer5,
	$CityRoot/Layer6,
]

@onready var rain_player: AudioStreamPlayer = $RainPlayer

var _layer_speeds: Array[float] = [0.4, 0.6, 0.8, 1.0, 1.2, 1.4]
var _layer_widths: Array[float] = []
var _rain_faded_out: bool = false


func _ready() -> void:
	_setup_cutscene_common()
	_full_text = "I DID ALL THE DIRTY WORK FOR THEM... (pause=1.0)\nAND I SMILED WHEN THEY PAT MY HEAD AND TOSSED ME A BONE. <break>ONE DAY I SAID “FUCK IT. I’VE HAD ENOUGH”. \nSO I CUT MY LEASH."
	_next_scene_path = "res://scenes/levels/chapter_1.tscn"
	_start_typing(_full_text)
 
	if heartbeat_player:
		heartbeat_player.stop()

	if rain_player:
		if rain_player.stream:
			rain_player.stream.loop = true
		rain_player.volume_db = -30.0
		rain_player.play()
		var t := create_tween()
		t.tween_property(rain_player, "volume_db", -8.0, 1.2)

	_layer_widths.clear()
	for i in city_layers.size():
		var layer := city_layers[i] as Sprite2D
		if layer == null:
			_layer_widths.append(0.0)
			continue

		var tex := layer.texture
		var width: float = 0.0
		if tex:
			width = float(tex.get_width())

		_layer_widths.append(width)

		if width <= 0.0:
			continue

		var dup := Sprite2D.new()
		dup.texture = tex
		dup.position = layer.position + Vector2(width, 0.0)
		layer.get_parent().add_child(dup)

		city_layers.append(dup)
		_layer_speeds.append(_layer_speeds[i])
		_layer_widths.append(width)


func _process(delta: float) -> void:
	super._process(delta)
	var count: int = min(city_layers.size(), min(_layer_speeds.size(), _layer_widths.size()))
	for i in count:
		var layer := city_layers[i]
		var width := _layer_widths[i]
		if width <= 0.0:
			continue
		layer.position.x -= base_speed * _layer_speeds[i] * delta
		if layer.position.x <= -width:
			layer.position.x += width * 2.0


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
		if rain_player and not _rain_faded_out:
			_rain_faded_out = true
			var t := create_tween()
			t.tween_property(rain_player, "volume_db", -40.0, 1.5)
			t.tween_callback(Callable(rain_player, "stop"))
		super._unhandled_input(event)
		return

	super._unhandled_input(event)
