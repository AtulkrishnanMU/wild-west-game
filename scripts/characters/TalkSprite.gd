extends Node2D

@export var body_texture: Texture2D
@export var mouth_frames: Array[Texture2D] = []
@export var mouth_fps: float = 12.0
@export var mouth_closed_index: int = 0
@export var expression_names: Array[String] = []
@export var expression_textures: Array[Texture2D] = []
@export var body_offset: Vector2 = Vector2.ZERO
@export var mouth_offset: Vector2 = Vector2.ZERO
@export var expression_offset: Vector2 = Vector2.ZERO
@export var flip_h: bool = false
@export var flip_v: bool = false

@onready var body_sprite: Sprite2D = $BodySprite
@onready var expression_sprite: Sprite2D = $ExpressionSprite
@onready var mouth_sprite: Sprite2D = $MouthSprite

var _talking: bool = false
var _mouth_timer: float = 0.0
var _mouth_frame: int = 0

func _ready() -> void:
	_apply_visuals()
	_set_mouth_closed()

func _process(delta: float) -> void:
	if not _talking:
		return
	if mouth_frames.size() <= 0 or mouth_fps <= 0.0:
		return
	_mouth_timer += delta
	var step := 1.0 / mouth_fps
	while _mouth_timer >= step:
		_mouth_timer -= step
		_mouth_frame = (_mouth_frame + 1) % mouth_frames.size()
		mouth_sprite.texture = mouth_frames[_mouth_frame]

func start_talking() -> void:
	_talking = true
	_mouth_timer = 0.0
	_mouth_frame = 0
	if mouth_frames.size() > 0:
		mouth_sprite.texture = mouth_frames[_mouth_frame]

func stop_talking() -> void:
	_talking = false
	_set_mouth_closed()

func set_expression(name: String) -> void:
	var i := expression_names.find(name)
	if i == -1:
		expression_sprite.texture = null
		return
	if i < expression_textures.size():
		expression_sprite.texture = expression_textures[i]
	else:
		expression_sprite.texture = null

func clear_expression() -> void:
	expression_sprite.texture = null

func set_body(texture: Texture2D) -> void:
	body_texture = texture
	body_sprite.texture = body_texture

func set_flip(h: bool, v: bool=false) -> void:
	flip_h = h
	flip_v = v
	_apply_flips()

func set_offsets(body: Vector2, mouth: Vector2, expr: Vector2) -> void:
	body_offset = body
	mouth_offset = mouth
	expression_offset = expr
	_apply_offsets()

func _apply_visuals() -> void:
	body_sprite.texture = body_texture
	_apply_offsets()
	_apply_flips()

func _apply_offsets() -> void:
	body_sprite.position = body_offset
	mouth_sprite.position = mouth_offset
	expression_sprite.position = expression_offset

func _apply_flips() -> void:
	body_sprite.flip_h = flip_h
	body_sprite.flip_v = flip_v
	mouth_sprite.flip_h = flip_h
	mouth_sprite.flip_v = flip_v
	expression_sprite.flip_h = flip_h
	expression_sprite.flip_v = flip_v

func _set_mouth_closed() -> void:
	if mouth_frames.size() == 0:
		mouth_sprite.texture = null
		return
	var idx := clamp(mouth_closed_index, 0, mouth_frames.size() - 1)
	mouth_sprite.texture = mouth_frames[idx]
