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
				_show_enemy_dialogue()
		
		return

func _start_cutscene():
	_cutscene_active = true
	
	# Find enemy node
	_enemy_node = $Axe_enemy if has_node("Axe_enemy") else null
	
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
		player.global_position = Vector2(-200, 392)  # Start off-screen left

func _show_enemy_dialogue():
	_dialogue_active = true
	
	# Show enemy dialogue using the enemy's dialogue system
	if _enemy_node and _enemy_node.has_method("show_dialogue"):
		var dialogue_text = "Hold up— who the fuck are you? How the hell did you slip in here?"
		var portrait_path = "D:/Atul/godot/ashbreaker/wild-west-game/assets/characters/axe enemy/Portrait.png"
		_enemy_node.show_dialogue(dialogue_text, portrait_path, 0.04)
		
		# Wait for dialogue to finish, then end cutscene
		await _wait_for_dialogue_finish()
		_end_cutscene()

func _wait_for_dialogue_finish():
	# Wait until dialogue is no longer active
	while _dialogue_active and _enemy_node and _enemy_node.is_dialogue_active():
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
	
	# Clean up tween
	if _cutscene_tween and _cutscene_tween.is_valid():
		_cutscene_tween.kill()
		_cutscene_tween = null
