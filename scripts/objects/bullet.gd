extends Area2D

const AudioUtils = preload("res://scripts/utils/audio_utils.gd")
const SPARK_SOUND = preload("res://sounds/spark.mp3")

@export var speed: float = 520.0
@export var damage: int = 20
@export var safe_enemy_player_distance: float = 32.0
@export var safe_enemy_shooter_distance: float = 100.0
var direction: Vector2 = Vector2.RIGHT
var shooter: Node = null
var _spark_texture: ImageTexture = null

const DUST_PARTICLE_SCENE := preload("res://scenes/objects/dust_particle.tscn")

func _ready() -> void:
	direction = direction.normalized()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	# Cache spark texture
	_spark_texture = create_spark_texture()
	
	# Ensure bullet can hit both alive and dead enemies by adding their layers
	collision_mask |= 2  # Add alive enemy layer (bitwise OR)
	collision_mask |= 8  # Add dead enemy layer (bitwise OR)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
	_apply_damage(area)

func _on_body_entered(body: Node) -> void:
	# Check if hit a tileset (TileMap) or solid surface
	if body is TileMap or body.is_in_group("walls") or body.is_in_group("ground"):
		call_deferred("_create_impact_effect")
		queue_free()
		return
	
	_apply_damage(body)

func _create_impact_effect() -> void:
	# Create white particle impact effect
	var scene := get_tree().current_scene
	if scene == null or DUST_PARTICLE_SCENE == null:
		return
	
	# Create metal sparks for bullet impact
	_create_metal_sparks(global_position, direction)
	
	# Create 3-5 white particles for impact
	var particle_count := randi_range(3, 5)
	for i in range(particle_count):
		var particle := DUST_PARTICLE_SCENE.instantiate()
		if particle == null:
			continue
		
		# Position particle at bullet impact location
		particle.global_position = global_position
		
		# Give particle random velocity away from impact point
		var spread_angle := randf_range(0.0, PI * 2.0)
		var spread_speed := randf_range(50.0, 120.0)
		particle.velocity = Vector2(cos(spread_angle), sin(spread_angle)) * spread_speed
		
		# Shorter lifetime for impact particles
		particle.lifetime = randf_range(0.3, 0.6)
		
		# Make particles white and more visible
		if particle.has_node("Sprite"):
			var sprite = particle.get_node("Sprite")
			sprite.modulate = Color.WHITE
		
		scene.add_child(particle)

func _apply_damage(target: Node) -> void:
	if not is_instance_valid(target):
		return
	# Do not damage the shooter who fired this bullet
	if target == shooter:
		return
	# Do not damage enemies that are currently very close to the player
	if target.is_in_group("enemies") and shooter and shooter.is_in_group("enemies"):
		var player := _get_player()
		if player and player.global_position.distance_to(target.global_position) < safe_enemy_player_distance:
			return
		# Also do not damage enemies that are very close to the shooter
		if shooter.global_position.distance_to(target.global_position) < safe_enemy_shooter_distance:
			return
	# Check if enemy is inactive - if on screen, damage and activate it
	if target.is_in_group("enemies") and ("is_active" in target) and not target.is_active:
		# Check if the inactive enemy is visible on screen
		var notifier = target.get_node_or_null("VisibilityNotifier2D")
		if notifier and notifier.is_on_screen():
			# Enemy is on screen but inactive - damage it and activate it
			if target.has_method("take_damage"):
				# Pass bullet direction and position to take_damage for proper blood spray direction and position
				if target.has_method("take_damage_with_direction"):
					target.take_damage_with_direction(damage, direction, global_position)
				else:
					target.take_damage(damage)
				# Activate the enemy after taking damage
				target.is_active = true
				target.has_been_visible_with_player = true
			queue_free()
			return
		else:
			# Enemy is inactive and not on screen - don't damage
			return
	if target.has_method("take_damage"):
		# Pass bullet direction and position to take_damage for proper blood spray direction and position
		if target.has_method("take_damage_with_direction"):
			target.take_damage_with_direction(damage, direction, global_position)
		else:
			target.take_damage(damage)
		queue_free()

func _get_player() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("Player")

func _create_metal_sparks(pos: Vector2, normal: Vector2) -> void:
	# Use preloaded sound
	if SPARK_SOUND:
		_play_spark_sound_segment(SPARK_SOUND, pos, 0.5)  # 0.5s duration for bullet sparks
	
	var sparks = _create_spark_node()
	get_tree().current_scene.add_child(sparks)
	sparks.global_position = pos
	sparks.rotation = normal.angle()

func _create_spark_node() -> Node2D:
	var spark_root := Node2D.new()
	
	var spark_count = 6  # Fewer sparks for bullets
	for i in range(spark_count):
		var spark := Sprite2D.new()
		spark.texture = _spark_texture  # Use cached texture
		
		var angle = randf_range(0, 2 * PI)
		var distance = randf_range(3, 10)  # Smaller spread for bullets
		spark.position = Vector2(cos(angle), sin(angle)) * distance
		
		var velocity_angle = angle + randf_range(-PI/4, PI/4)
		var velocity = randf_range(80, 150)  # Slower for bullets
		
		spark.scale = Vector2(randf_range(0.15, 0.3), randf_range(0.15, 0.3))  # Even smaller for bullets
		spark.rotation = randf_range(0, 2 * PI)
		
		spark_root.add_child(spark)
		
		var tween := spark.create_tween()
		tween.set_parallel(true)
		
		var duration = 0.5  # Shorter duration for bullet sparks
		var end_pos = spark.position + Vector2(cos(velocity_angle), sin(velocity_angle)) * velocity * duration
		end_pos.y += 40  # Less gravity for bullets
		
		tween.tween_property(spark, "position", end_pos, duration)
		tween.tween_property(spark, "modulate:a", 0.0, duration)
		tween.tween_property(spark, "scale", Vector2.ZERO, duration)
	
	var cleanup := spark_root.create_tween()
	cleanup.tween_callback(spark_root.queue_free).set_delay(0.6)
	
	return spark_root

func create_spark_texture() -> ImageTexture:
	# Create a 16x16 spark texture
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Create spark pattern
	for x in range(16):
		for y in range(16):
			var dist = Vector2(x - 8, y - 8).length()
			if dist <= 6:
				if dist <= 2:
					image.set_pixel(x, y, Color.WHITE)
				elif dist <= 4:
					image.set_pixel(x, y, Color.YELLOW)
				else:
					image.set_pixel(x, y, Color.ORANGE)
	
	var texture := ImageTexture.new()
	texture.set_image(image)
	return texture

func _play_spark_sound_segment(spark_sound: AudioStream, position: Vector2, duration: float) -> void:
	var audio := AudioStreamPlayer2D.new()
	audio.stream = spark_sound
	audio.position = position
	
	# Set random pitch (higher range for bullets)
	audio.pitch_scale = randf_range(0.8, 1.4)
	
	# Calculate random start time within the audio file
	var audio_length = spark_sound.get_length() if spark_sound.has_method("get_length") else 5.0  # Fallback to 5s
	var max_start_time = max(0.0, audio_length - duration)
	var random_start = randf_range(0.0, max_start_time)
	
	# Add to scene FIRST, then play
	get_tree().current_scene.add_child(audio)
	
	# Set playback to start at random position
	audio.play(random_start)
	
	# Create timer to stop audio after duration and cleanup
	var timer := Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(func(): 
		if audio and is_instance_valid(audio):
			audio.stop()
			audio.queue_free()
		if timer and is_instance_valid(timer):
			timer.queue_free()
	)
	get_tree().current_scene.add_child(timer)
	timer.start()
