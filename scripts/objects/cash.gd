extends Area2D

const CASH_AMOUNT := 50
const CASH_SOUND := preload("res://sounds/cash.mp3")

var _player: Node2D = null
var _attraction_timer: Timer = null

func _on_ready() -> void:
	# Make sure this Area2D actually detects the Player (which is on layer 2)
	collision_layer = 1
	collision_mask = 2
	var scene := get_tree().current_scene
	if scene:
		_player = scene.get_node_or_null("Player")
	
	# Initialize attraction timer
	_attraction_timer = Timer.new()
	_attraction_timer.wait_time = 1.0
	_attraction_timer.one_shot = true
	_attraction_timer.timeout.connect(_on_attraction_timer_timeout)
	add_child(_attraction_timer)


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	
	var distance_sq = _player.global_position.distance_squared_to(global_position)
	var attraction_radius_sq = 100.0 * 100.0  # Square the radius
	
	if distance_sq <= attraction_radius_sq:
		var speed = 6.0
		global_position = global_position.lerp(_player.global_position, speed * delta)
	elif distance_sq > 200.0 * 200.0:  # Disable physics when very far
		set_physics_process(false)
		_attraction_timer.start(1.0)  # Re-enable after delay


func _on_body_entered(body: Node) -> void:
	if body == null:
		return
	if not body.has_method("add_cash"):
		return
	body.add_cash(CASH_AMOUNT)
	_play_cash_sound(body)
	# Use CharacterUtils for popup (works for any Node2D)
	if body.has_method("get") and body.get("POPUP_FONT_SIZE"):
		# Use player's popup font size and cash height if available
		CharacterUtils.spawn_floating_popup(body, "+%d $" % CASH_AMOUNT, Color.WHITE, Vector2(0, -20), body.POPUP_FONT_SIZE, body.CASH_POPUP_HEIGHT)
	else:
		# Fallback to default font size and height
		CharacterUtils.spawn_floating_popup(body, "+%d $" % CASH_AMOUNT, Color.WHITE)
	queue_free()


func _on_attraction_timer_timeout() -> void:
	set_physics_process(true)


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
