extends Node2D
class_name IntroSequence

signal intro_sequence_finished

@onready var player: CharacterBody2D = get_parent().get_node("Player")
@onready var dead_axe_man: CharacterBody2D = get_parent().get_node("DeadAxeMan")

func _ready() -> void:
	# Start the intro sequence immediately
	call_deferred("_start_intro_sequence")

func _start_intro_sequence() -> void:
	print("Starting intro sequence")
	
	# Make player uncontrollable
	_make_player_uncontrollable()
	
	# Start player attack animation
	_start_player_attack()
	
	# Wait for player attack to finish, then trigger axe man death
	await get_tree().create_timer(0.8).timeout
	_trigger_axe_man_death()

func _make_player_uncontrollable() -> void:
	# Disable player controls using the built-in controls_enabled variable
	if player:
		player.controls_enabled = false
		player.velocity = Vector2.ZERO
		player.is_attacking = true  # Prevent other actions
		print("Player controls disabled")

func _start_player_attack() -> void:
	if not player or not player.animated_sprite:
		return
	
	# Play attack animation (face right since axe man is to the right)
	player.animated_sprite.flip_h = false
	
	# Play a random attack animation
	var attack_anim = "ATTACK1" if randf() < 0.5 else "ATTACK2"
	player.animated_sprite.play(attack_anim)
	
	# Play attack sound
	if player.has_node("SlashPlayer"):
		var slash_player = player.get_node("SlashPlayer")
		if slash_player:
			slash_player.pitch_scale = randf_range(0.7, 1.6)
			slash_player.play()
	
	print("Playing player attack animation: ", attack_anim)

func _trigger_axe_man_death() -> void:
	# Signal the dead axe man to start its sequence
	if dead_axe_man and dead_axe_man.has_method("_start_idle_then_die"):
		dead_axe_man._start_idle_then_die()
		print("Triggered axe man death sequence")
	
	# Wait for the entire sequence to finish
	await get_tree().create_timer(2.5).timeout  # 1s idle + death animation time
	
	# Show dialogue
	_show_dialogue()

func _show_dialogue() -> void:
	print("Showing post-death dialogue")
	
	# Create and show dialogue
	var dialogue_scene = preload("res://scenes/levels/post_death_dialogue.tscn").instantiate()
	get_parent().add_child(dialogue_scene)
	
	# Dialogue is now centered by default in the scene
	
	# Wait for dialogue to finish
	dialogue_scene.dialogue_finished.connect(_on_dialogue_finished)
	
	# Start the dialogue
	dialogue_scene.show_dialogue()
	print("Dialogue started")

func _on_dialogue_finished() -> void:
	print("Dialogue finished")
	
	# Make player controllable again
	_make_player_controllable()
	
	# Signal that the intro sequence is finished
	intro_sequence_finished.emit()
	print("Intro sequence finished")

func _make_player_controllable() -> void:
	# Re-enable player controls using the built-in controls_enabled variable
	if player:
		player.controls_enabled = true
		player.is_attacking = false
		# Return to idle animation
		if player.animated_sprite:
			player.animated_sprite.play("IDLE")
		print("Player controls re-enabled")
