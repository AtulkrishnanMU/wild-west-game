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
	# Use CharacterUtils for popup (works for any Node2D)
	CharacterUtils.spawn_floating_popup(body, "+%d" % CASH_AMOUNT, Color(1.0, 0.84, 0.0))
	queue_free()


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
