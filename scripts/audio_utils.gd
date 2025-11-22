extends Object
class_name AudioUtils

static func play_random_pitch(audio, min_pitch: float = 0.9, max_pitch: float = 1.1) -> void:
	if audio == null:
		return
	audio.pitch_scale = randf_range(min_pitch, max_pitch)
	audio.play()
