extends Area2D

class_name AlertAlarm

const MAX_HEALTH := 20
var health: int = MAX_HEALTH

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

var _fade_tween: Tween = null
var _blink_tween: Tween = null
var _damage_flash_tween: Tween = null
var _is_destroyed: bool = false

signal alarm_destroyed()

func _ready() -> void:
	# Setup collision
	add_to_group("destructible")
	add_to_group("alarm")
	
	# Connect area signals for damage detection
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Make sure audio is playing and looping
	if audio_player:
		audio_player.stream.loop = true
		audio_player.play()
	
	# Start blinking effect
	start_blinking()

func _on_body_entered(body: Node) -> void:
	# Handle bullet collision (if bullets are CharacterBody2D)
	if body.is_in_group("bullet"):
		take_damage(10)
		if body.has_method("destroy"):
			body.destroy()

func _on_area_entered(area: Area2D) -> void:
	# Handle bullet collision (if bullets are Area2D)
	if area.is_in_group("bullet"):
		take_damage(10)
		if area.has_method("destroy"):
			area.destroy()

func start_blinking() -> void:
	if _is_destroyed:
		return
	
	_blink_tween = create_tween()
	_blink_tween.set_loops()
	_blink_tween.tween_property(sprite, "modulate", Color.BLUE, 0.5)
	_blink_tween.tween_property(sprite, "modulate", Color.RED, 0.5)

func take_damage(damage_amount: int) -> void:
	if _is_destroyed:
		return
	
	health -= damage_amount
	
	# Stop blinking temporarily and flash white
	if _blink_tween:
		_blink_tween.kill()
	
	# White flash effect
	sprite.modulate = Color.WHITE
	if _damage_flash_tween:
		_damage_flash_tween.kill()
	_damage_flash_tween = create_tween()
	_damage_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	_damage_flash_tween.tween_callback(_resume_blinking_after_damage)
	
	if health <= 0:
		destroy()

func _resume_blinking_after_damage() -> void:
	if not _is_destroyed:
		start_blinking()

func destroy() -> void:
	if _is_destroyed:
		return
	
	_is_destroyed = true
	
	# Stop blinking
	if _blink_tween:
		_blink_tween.kill()
	if _damage_flash_tween:
		_damage_flash_tween.kill()
	
	# Reset to normal color
	sprite.modulate = Color.WHITE
	
	# Fade out audio over 1 second
	if audio_player and audio_player.playing:
		_fade_tween = create_tween()
		_fade_tween.tween_property(audio_player, "volume_db", -80.0, 1.0)
		_fade_tween.tween_callback(_on_audio_fade_complete)
	else:
		_on_audio_fade_complete()

func _on_audio_fade_complete() -> void:
	# Stop audio
	if audio_player:
		audio_player.stop()
	
	# Emit signal
	emit_signal("alarm_destroyed")

func _exit_tree() -> void:
	# Clean up all tweens
	if _fade_tween:
		_fade_tween.kill()
	if _blink_tween:
		_blink_tween.kill()
	if _damage_flash_tween:
		_damage_flash_tween.kill()
