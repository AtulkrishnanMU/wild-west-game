class_name MetalSparkUtils
extends RefCounted

const SPARK_SOUND_PATH := "res://sounds/spark.mp3"

# Create metal sparks with specific parameters for different object types
static func create_metal_sparks(pos: Vector2, normal: Vector2, spark_type: String = "default", scene_tree: SceneTree = null) -> void:
	# Get scene tree if not provided
	if scene_tree == null:
		scene_tree = Engine.get_main_loop() as SceneTree
	
	# Get parameters based on spark type
	var params = _get_spark_parameters(spark_type)
	
	# Play spark sound with random segment
	var spark_sound = load(SPARK_SOUND_PATH)
	if spark_sound:
		_play_spark_sound_segment(spark_sound, pos, params.sound_duration, scene_tree, params.pitch_range)
	
	var sparks = _create_spark_node(params.spark_count, params.duration, params.spread_range, 
		params.velocity_range, params.scale_range, params.gravity)
	scene_tree.current_scene.add_child(sparks)
	sparks.global_position = pos
	sparks.rotation = normal.angle()

# Get spark parameters based on type
static func _get_spark_parameters(spark_type: String) -> Dictionary:
	match spark_type:
		"bat":
			return {
				"spark_count": 8,
				"duration": 0.8,
				"sound_duration": 0.8,
				"spread_range": Vector2(5, 15),
				"velocity_range": Vector2(100, 200),
				"scale_range": Vector2(0.4, 0.8),  # Increased from 0.2-0.4 to 0.4-0.8
				"gravity": 80,
				"pitch_range": Vector2(0.7, 1.3)
			}
		"bullet":
			return {
				"spark_count": 6,
				"duration": 0.5,
				"sound_duration": 0.5,
				"spread_range": Vector2(3, 10),
				"velocity_range": Vector2(80, 150),
				"scale_range": Vector2(0.3, 0.6),  # Increased from 0.15-0.3 to 0.3-0.6
				"gravity": 40,
				"pitch_range": Vector2(0.8, 1.4)
			}
		_:  # default
			return {
				"spark_count": 6,
				"duration": 0.5,
				"sound_duration": 0.5,
				"spread_range": Vector2(3, 10),
				"velocity_range": Vector2(80, 150),
				"scale_range": Vector2(0.3, 0.6),  # Increased from 0.15-0.3 to 0.3-0.6
				"gravity": 40,
				"pitch_range": Vector2(0.8, 1.4)
			}

# Create a spark node with specified parameters
static func _create_spark_node(spark_count: int, duration: float, spread_range: Vector2, 
		velocity_range: Vector2, scale_range: Vector2, gravity: float) -> Node2D:
	var spark_root := Node2D.new()
	
	for i in range(spark_count):
		var spark := Sprite2D.new()
		spark.texture = _create_spark_texture()
		
		var angle = randf_range(0, 2 * PI)
		var distance = randf_range(spread_range.x, spread_range.y)
		spark.position = Vector2(cos(angle), sin(angle)) * distance
		
		var velocity_angle = angle + randf_range(-PI/4, PI/4)
		var velocity = randf_range(velocity_range.x, velocity_range.y)
		
		spark.scale = Vector2(randf_range(scale_range.x, scale_range.y), randf_range(scale_range.x, scale_range.y))
		spark.rotation = randf_range(0, 2 * PI)
		
		spark_root.add_child(spark)
		
		var tween := spark.create_tween()
		tween.set_parallel(true)
		
		var end_pos = spark.position + Vector2(cos(velocity_angle), sin(velocity_angle)) * velocity * duration
		end_pos.y += gravity
		
		tween.tween_property(spark, "position", end_pos, duration)
		tween.tween_property(spark, "modulate:a", 0.0, duration)
		tween.tween_property(spark, "scale", Vector2.ZERO, duration)
	
	var cleanup := spark_root.create_tween()
	cleanup.tween_callback(spark_root.queue_free).set_delay(duration + 0.1)
	
	return spark_root

# Create a spark texture (black color)
static func _create_spark_texture() -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)  # Increased from 16x16 to 32x32
	image.fill(Color.TRANSPARENT)
	
	# Create solid spark pattern
	for x in range(32):
		for y in range(32):
			var dist = Vector2(x - 16, y - 16).length()  # Adjusted center for 32x32
			if dist < 10:  # Slightly smaller radius for more solid appearance
				var brightness = 1.0 - (dist / 10.0)
				# Make it more solid by increasing the probability
				if randf() < (brightness * 0.8):  # 80% chance instead of random brightness
					var color = Color.BLACK
					color.a = brightness
					image.set_pixel(x, y, color)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

# Play spark sound with random segment
static func _play_spark_sound_segment(spark_sound: AudioStream, position: Vector2, duration: float, 
		scene_tree: SceneTree, pitch_range: Vector2) -> void:
	var audio := AudioStreamPlayer2D.new()
	audio.stream = spark_sound
	audio.position = position
	
	# Set random pitch
	audio.pitch_scale = randf_range(pitch_range.x, pitch_range.y)
	
	# Calculate random start time within the audio file
	var audio_length = spark_sound.get_length() if spark_sound.has_method("get_length") else 5.0
	var max_start_time = max(0.0, audio_length - duration)
	var random_start = randf_range(0.0, max_start_time)
	
	# Add to scene tree BEFORE playing
	scene_tree.current_scene.add_child(audio)
	audio.play(random_start)
	
	# Auto-cleanup
	var timer := Timer.new()
	timer.wait_time = duration + 0.1
	timer.one_shot = true
	timer.timeout.connect(func(): audio.queue_free(); timer.queue_free())
	scene_tree.current_scene.add_child(timer)
	timer.start()
