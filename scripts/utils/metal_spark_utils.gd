class_name MetalSparkUtils
extends RefCounted

const SPARK_SOUND_PATH := "res://sounds/spark.mp3"

# Create metal sparks at a specific position with customizable parameters
static func create_metal_sparks(pos: Vector2, normal: Vector2, spark_count: int = 6, duration: float = 0.5, sound_duration: float = 0.5, scene_tree: SceneTree = null) -> void:
	# Get scene tree if not provided
	if scene_tree == null:
		scene_tree = Engine.get_main_loop() as SceneTree
	
	# Play spark sound with random segment
	var spark_sound = load(SPARK_SOUND_PATH)
	if spark_sound:
		_play_spark_sound_segment(spark_sound, pos, sound_duration, scene_tree)
	
	var sparks = _create_spark_node(spark_count, duration)
	scene_tree.current_scene.add_child(sparks)
	sparks.global_position = pos
	sparks.rotation = normal.angle()

# Create a spark node with specified count and duration
static func _create_spark_node(spark_count: int, duration: float) -> Node2D:
	var spark_root := Node2D.new()
	
	for i in range(spark_count):
		var spark := Sprite2D.new()
		spark.texture = _create_spark_texture()
		
		var angle = randf_range(0, 2 * PI)
		var distance = randf_range(3, 10)  # Smaller spread for general use
		spark.position = Vector2(cos(angle), sin(angle)) * distance
		
		var velocity_angle = angle + randf_range(-PI/4, PI/4)
		var velocity = randf_range(80, 150)  # Moderate velocity
		
		spark.scale = Vector2(randf_range(0.15, 0.3), randf_range(0.15, 0.3))
		spark.rotation = randf_range(0, 2 * PI)
		
		spark_root.add_child(spark)
		
		var tween := spark.create_tween()
		tween.set_parallel(true)
		
		var end_pos = spark.position + Vector2(cos(velocity_angle), sin(velocity_angle)) * velocity * duration
		end_pos.y += 40  # Gravity effect
		
		tween.tween_property(spark, "position", end_pos, duration)
		tween.tween_property(spark, "modulate:a", 0.0, duration)
		tween.tween_property(spark, "scale", Vector2.ZERO, duration)
	
	var cleanup := spark_root.create_tween()
	cleanup.tween_callback(spark_root.queue_free).set_delay(duration + 0.1)
	
	return spark_root

# Create a spark texture
static func _create_spark_texture() -> ImageTexture:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Create spark pattern
	for x in range(16):
		for y in range(16):
			var dist = Vector2(x - 8, y - 8).length()
			if dist < 6:
				var brightness = 1.0 - (dist / 6.0)
				if randf() < brightness:
					var color = Color.WHITE
					color.a = brightness
					if dist < 2:
						color = Color.YELLOW
					elif dist < 4:
						color = Color.ORANGE
					image.set_pixel(x, y, color)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

# Play spark sound with random segment
static func _play_spark_sound_segment(spark_sound: AudioStream, position: Vector2, duration: float, scene_tree: SceneTree) -> void:
	var audio := AudioStreamPlayer2D.new()
	audio.stream = spark_sound
	audio.position = position
	
	# Set random pitch
	audio.pitch_scale = randf_range(0.8, 1.4)
	
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
