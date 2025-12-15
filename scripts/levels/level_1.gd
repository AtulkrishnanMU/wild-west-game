extends "res://scripts/levels/level.gd"

# Level1 specific implementation
# This script extends the base level functionality

# Cutscene variables
var _cutscene_active: bool = false
var _cutscene_tween: Tween = null
var _cutscene_duration: float = 0.0
var _cutscene_timer: float = 0.0
var _cutscene_direction: float = 0.0
var _cutscene_distance: float = 0.0
var _start_position: Vector2 = Vector2.ZERO
var _target_position: float = 0.0
var _enemy_node: Node = null  # Reference to enemy
var _dialogue_active: bool = false  # Track if dialogue is showing
var _enemy_dialogue_shown := false  # One-shot guard to prevent repeated dialogue calls
var _exclamation_mark: Label = null  # Exclamation mark popup above enemy head

func _ready():
	# Call parent _ready() which will auto-assign nodes and setup everything
	super._ready()
	
	# Start the cutscene
	_start_cutscene()

func _process(delta: float) -> void:
	# Only process level logic if cutscene is not active
	if not _cutscene_active:
		process_level(delta)

func _physics_process(delta: float) -> void:
	# Handle cutscene movement in physics process
	if _cutscene_active:
		_cutscene_timer += delta
		
		# Force enemy to stay inactive during cutscene (override internal activation logic)
		if _enemy_node:
			_enemy_node.is_active = false
		
		# Call run method continuously during cutscene with distance check
		if player and _cutscene_timer < _cutscene_duration:
			# Check if player has reached the target position
			var current_distance = player.global_position.x - _start_position.x
			if current_distance < _cutscene_distance:
				player.run(_cutscene_direction, 0.0)
			else:
				# Player reached target, stop running and show dialogue
				player.run(0.0, 0.0)  # Stop movement
				
				# Show enemy dialogue only once using one-shot guard
				if not _enemy_dialogue_shown:
					_enemy_dialogue_shown = true
					_show_enemy_dialogue()
		
		return

func _start_cutscene():
	_cutscene_active = true
	
	# Find enemy node
	_enemy_node = $Axe_enemy if has_node("Axe_enemy") else null
	
	# Disable enemy immediately when cutscene starts to prevent jumping
	if _enemy_node:
		_enemy_node.is_active = false
		_enemy_node.is_in_cutscene = true  # Set cutscene flag
		# Also reset enemy velocity to prevent any residual movement
		if _enemy_node.has_method("set_velocity"):
			_enemy_node.set_velocity(Vector2.ZERO)
		elif "velocity" in _enemy_node:
			_enemy_node.velocity = Vector2.ZERO
	
	# Set cutscene parameters
	_cutscene_direction = 1.0  # Run right
	_cutscene_duration = 3.0    # Max duration in seconds
	_cutscene_timer = 0.0
	
	# Calculate target position based on enemy location
	if _enemy_node:
		# Stop 250 pixels to the left of the enemy
		var enemy_position = _enemy_node.global_position.x
		_target_position = enemy_position - 250
	else:
		# Fallback to hardcoded position if no enemy found
		_target_position = 632.0
	
	# Disable player controls but keep playable for movement
	if player:
		_start_position = player.global_position
		_cutscene_distance = _target_position - _start_position.x
		player.controls_enabled = false  # Disable input
		player.playable = true           # Allow run method to work
		player.velocity = Vector2.ZERO
	
	# Disable enemy during cutscene
	if _enemy_node:
		_enemy_node.is_active = false
	
	# Position player at the left side of the screen
	if player:
		player.global_position = Vector2(-150, 392)  # Start off-screen left (moved 50px right)

func _show_enemy_dialogue():
	# Prevent accidental double-calls
	if _dialogue_active:
		return
		
	_dialogue_active = true
	
	# Show exclamation mark above enemy head first
	_show_exclamation_mark()
	
	# Wait a moment for the exclamation mark to be visible
	await get_tree().create_timer(1.0).timeout
	
	# Hide exclamation mark before dialogue
	_hide_exclamation_mark()

	# Show enemy dialogue using the enemy's dialogue system
	if _enemy_node and _enemy_node.has_method("show_dialogue"):
		var dialogue_text = "Hold up— who the fuck are you? How the hell did you slip in here?"
		var portrait_path = "D:/Atul/godot/ashbreaker/wild-west-game/assets/characters/axe enemy/Portrait.png"
		_enemy_node.show_dialogue(dialogue_text, portrait_path, 0.04)
		
		# Wait for enemy dialogue to finish, then show player response
		await _wait_for_dialogue_finish()
		_show_player_response()

func _show_exclamation_mark():
	if not _enemy_node:
		return
	
	# Create exclamation mark label
	_exclamation_mark = Label.new()
	_exclamation_mark.text = "!"
	_exclamation_mark.add_theme_font_size_override("font_size", 48)
	_exclamation_mark.add_theme_color_override("font_color", Color.YELLOW)
	_exclamation_mark.add_theme_color_override("font_shadow_color", Color.BLACK)
	_exclamation_mark.add_theme_constant_override("shadow_offset_x", 2)
	_exclamation_mark.add_theme_constant_override("shadow_offset_y", 2)
	
	# Position above enemy head
	var enemy_position = _enemy_node.global_position
	var enemy_height = 80  # Approximate enemy sprite height
	_exclamation_mark.position = enemy_position + Vector2(0, -enemy_height - 30)
	
	# Add to scene tree
	add_child(_exclamation_mark)
	
	# Create popup animation
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Scale from 0 to 1.2 with bounce effect
	_exclamation_mark.scale = Vector2.ZERO
	tween.tween_property(_exclamation_mark, "scale", Vector2(1.2, 1.2), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_exclamation_mark, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	
	# Fade in
	_exclamation_mark.modulate = Color.TRANSPARENT
	tween.tween_property(_exclamation_mark, "modulate", Color.WHITE, 0.3).set_ease(Tween.EASE_OUT)

func _hide_exclamation_mark():
	if _exclamation_mark:
		# Create fade out animation
		var tween = create_tween()
		tween.set_parallel(true)
		
		# Fade out and scale down
		tween.tween_property(_exclamation_mark, "modulate", Color.TRANSPARENT, 0.2).set_ease(Tween.EASE_IN)
		tween.tween_property(_exclamation_mark, "scale", Vector2(0.5, 0.5), 0.2).set_ease(Tween.EASE_IN)
		
		# Remove after animation
		tween.tween_callback(func(): 
			if _exclamation_mark:
				_exclamation_mark.queue_free()
				_exclamation_mark = null
		)

func _show_player_response():
	_dialogue_active = true
	
	# Show player dialogue using the player's dialogue system
	if player and player.has_method("show_dialogue"):
		var dialogue_text = "Just a regular guy who's had enough of your gang's bullshit over the streets.<break>And tonight I'm erasing every last one of you sorry fucks from the map."
		var portrait_path = "D:/Atul/godot/ashbreaker/wild-west-game/assets/characters/Player/Portrait.png"
		player.show_dialogue(dialogue_text, portrait_path, 0.04)
		
		# Wait for player dialogue to finish, then show guard response
		await _wait_for_dialogue_finish()
		_show_guard_response()

func _show_guard_response():
	_dialogue_active = true
	
	# Show guard dialogue using the enemy's dialogue system
	if _enemy_node and _enemy_node.has_method("show_dialogue"):
		var dialogue_text = "Oh yeah? Big talk, motherfucker. You just picked a fight with the wrong group of people!"
		var portrait_path = "D:/Atul/godot/ashbreaker/wild-west-game/assets/characters/axe enemy/Portrait.png"
		_enemy_node.show_dialogue(dialogue_text, portrait_path, 0.04)
		
		# Wait for guard dialogue to finish, then end cutscene
		await _wait_for_dialogue_finish()
		_end_cutscene()

func _wait_for_dialogue_finish():
	# Wait until dialogue is no longer active (check both enemy and player)
	while _dialogue_active:
		var enemy_dialogue_active = _enemy_node and _enemy_node.is_dialogue_active()
		var player_dialogue_active = player and player.is_dialogue_active()
		
		if not enemy_dialogue_active and not player_dialogue_active:
			break
			
		await get_tree().process_frame
	_dialogue_active = false

func _end_cutscene():
	print("Cutscene ended")
	_cutscene_active = false
	
	# Re-enable player controls
	if player:
		player.controls_enabled = true  # Re-enable input
		player.animated_sprite.play("IDLE")
	
	# Re-enable enemy after cutscene
	if _enemy_node:
		_enemy_node.is_active = true
		_enemy_node.is_in_cutscene = false  # Clear cutscene flag
	
	# Clean up tween
	if _cutscene_tween and _cutscene_tween.is_valid():
		_cutscene_tween.kill()
		_cutscene_tween = null
