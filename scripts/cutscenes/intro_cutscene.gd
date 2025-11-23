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

var _layer_speeds: Array[float] = [0.4, 0.6, 0.8, 1.0, 1.2, 1.4]
var _layer_widths: Array[float] = []


func _ready() -> void:
	_setup_cutscene_common()
	_full_text = "This is the <y>Damnation District</y>.(pause=1.2)\nWhere dreams and corpses share the same address."
	_next_scene_path = "res://scenes/levels/chapter_1.tscn"
	_start_typing(_full_text)

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
