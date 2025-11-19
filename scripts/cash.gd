extends Area2D

const CASH_AMOUNT := 50
const CASH_SOUND := preload("res://sounds/cash.mp3")

var _player: Node2D = null

func _on_ready() -> void:
	# Make sure this Area2D actually detects the Player (which is on layer 2)
	collision_layer = 1
	collision_mask = 2
	var scene := get_tree().current_scene
	if scene:
		_player = scene.get_node_or_null("Player")


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	var to_player: Vector2 = _player.global_position - global_position
	var dist := to_player.length()
	var attraction_radius := 100.0
	if dist <= attraction_radius:
		var speed := 6.0
		global_position = global_position.lerp(_player.global_position, speed * delta)


func _on_body_entered(body: Node) -> void:
	if body == null:
		return
	if not body.has_method("add_cash"):
		return
	body.add_cash(CASH_AMOUNT)
	_play_cash_sound(body)
	_spawn_cash_popup(body)
	queue_free()


func _spawn_cash_popup(player: Node) -> void:
	if player == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return

	# World-space popup just above the player
	var popup_root := Node2D.new()
	popup_root.position = player.global_position + Vector2(0, -20)
	scene.add_child(popup_root)

	var label := Label.new()
	label.text = "+%d" % CASH_AMOUNT
	# Golden color, smaller pixel font
	label.modulate = Color(1.0, 0.84, 0.0)
	var font := load("res://fonts/PixelOperator8.ttf")
	if font:
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 8)
	popup_root.add_child(label)

	var tween := get_tree().create_tween()
	tween.tween_property(popup_root, "position:y", popup_root.position.y - 20.0, 0.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.finished.connect(popup_root.queue_free)


func _play_cash_sound(player: Node) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var audio := AudioStreamPlayer2D.new()
	audio.stream = CASH_SOUND
	audio.position = player.global_position
	scene.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)
