extends Object
class_name AudioUtils

static func play_random_pitch(audio, min_pitch: float = 0.9, max_pitch: float = 1.1) -> void:
	if audio == null:
		return
	audio.pitch_scale = randf_range(min_pitch, max_pitch)
	audio.play()

# Plays a one-shot sound at a specific position
static func play_positioned_sound(sound_stream: AudioStream, position: Vector2, min_pitch: float = 0.9, max_pitch: float = 1.1) -> void:
	if sound_stream == null:
		return
	var scene: Node = Engine.get_main_loop().current_scene
	if scene == null:
		return
	
	var audio := AudioStreamPlayer2D.new()
	audio.stream = sound_stream
	audio.position = position
	scene.add_child(audio)
	play_random_pitch(audio, min_pitch, max_pitch)
	audio.finished.connect(audio.queue_free)

# Plays running sound using existing audio player
static func play_running_sound(running_player: AudioStreamPlayer2D, running_sound: AudioStream) -> void:
	if running_sound == null or running_player == null:
		return
	if not running_player.playing:
		running_player.stream = running_sound
		play_random_pitch(running_player, 0.9, 1.1)

# Stops running sound
static func stop_running_sound(running_player: AudioStreamPlayer2D) -> void:
	if running_player and running_player.playing:
		running_player.stop()

# Plays blood splat sound at position
static func play_blood_splat_sound(blood_splat_sound: AudioStream, position: Vector2) -> void:
	play_positioned_sound(blood_splat_sound, position, 0.8, 1.2)

# Plays death sound with optional random selection between two sounds
static func play_death_sound(death_sound_1: AudioStream, death_sound_2: AudioStream, position: Vector2) -> void:
	var sound_to_play: AudioStream = null
	
	if death_sound_1 and death_sound_2:
		# Randomly choose between two death sounds
		sound_to_play = death_sound_1 if randf() < 0.5 else death_sound_2
	elif death_sound_1:
		sound_to_play = death_sound_1
	elif death_sound_2:
		sound_to_play = death_sound_2
	else:
		return
	
	play_positioned_sound(sound_to_play, position, 0.9, 1.1)

# Plays hurt sound at position
static func play_hurt_sound(hurt_sound: AudioStream, position: Vector2) -> void:
	play_positioned_sound(hurt_sound, position, 0.9, 1.1)
