extends Object
class_name AudioUtils

# Object pool for audio players
static var _audio_pool: Array[AudioStreamPlayer2D] = []
static var _pool_size: int = 10

static func play_random_pitch(audio, min_pitch: float = 0.9, max_pitch: float = 1.1) -> void:
	if audio == null:
		return
	audio.pitch_scale = randf_range(min_pitch, max_pitch)
	audio.play()

# Pool management functions
static func _get_audio_player() -> AudioStreamPlayer2D:
	if _audio_pool.size() > 0:
		var audio = _audio_pool.pop_back()
		# Remove from current parent if it has one
		if audio.get_parent():
			audio.get_parent().remove_child(audio)
		return audio
	
	var audio = AudioStreamPlayer2D.new()
	audio.finished.connect(_return_audio_player.bind(audio))
	return audio

static func _return_audio_player(audio: AudioStreamPlayer2D):
	# Stop the audio and remove from parent before returning to pool
	audio.stop()
	if audio.get_parent():
		audio.get_parent().remove_child(audio)
	
	if _audio_pool.size() < _pool_size:
		_audio_pool.append(audio)
	else:
		audio.queue_free()

# Plays a one-shot sound at a specific position
static func play_positioned_sound(sound_stream: AudioStream, position: Vector2, min_pitch: float = 0.9, max_pitch: float = 1.1) -> void:
	if sound_stream == null:
		return
	var scene: Node = Engine.get_main_loop().current_scene
	if scene == null:
		return
	
	var audio := _get_audio_player()
	audio.stream = sound_stream
	audio.position = position
	scene.add_child(audio)
	play_random_pitch(audio, min_pitch, max_pitch)

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

# Plays death sound with random selection from array of sounds
static func play_death_sound(death_sounds: Array[AudioStream], position: Vector2) -> void:
	if death_sounds.is_empty():
		return
	
	# Randomly select one death sound from the array
	var sound_to_play = death_sounds[randi() % death_sounds.size()]
	
	play_positioned_sound(sound_to_play, position, 0.9, 1.1)

# Plays hurt sound at position
static func play_hurt_sound(hurt_sound: AudioStream, position: Vector2) -> void:
	play_positioned_sound(hurt_sound, position, 0.9, 1.1)
