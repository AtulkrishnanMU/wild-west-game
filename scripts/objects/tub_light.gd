extends PointLight2D

var base_energy: float
var flicker_timer: float = 0.0
var is_off: bool = false
var off_duration: float = 0.0

@onready var normal_sound: AudioStreamPlayer2D = $NormalSound
@onready var flicker_sound: AudioStreamPlayer2D = $FlickerSound
@onready var dark_overlay: ColorRect = $DarkOverlay

var fade_tween: Tween

func _ready():
	# Store the base energy from the scene file
	base_energy = energy
	# Configure the light for spherical emission
	color = Color(1, 1, 0.9, 1)  # Warm white light
	shadow_enabled = false
	blend_mode = Light2D.BLEND_MODE_ADD
	
	# Start with dark overlay hidden and transparent
	dark_overlay.visible = true
	dark_overlay.modulate.a = 0.0
	
	# Start normal light sound on loop
	normal_sound.play()

# Subtle flickering effect with occasional complete flicker off
func _process(delta):
	flicker_timer += delta
	
	# Occasionally flicker completely off (like real tube lights)
	if not is_off and randf() < 0.002:  # 0.2% chance per frame
		is_off = true
		off_duration = randf_range(0.05, 0.15)  # Off for 0.05-0.15 seconds
		energy = 0
		
		# Play flicker sound and pause normal sound
		normal_sound.stop()
		flicker_sound.play()
		
		# Fade in dark overlay
		_fade_in_dark_overlay()
	elif is_off:
		off_duration -= delta
		if off_duration <= 0:
			is_off = false
			energy = base_energy
			
			# Resume normal sound when light comes back
			normal_sound.play()
			
			# Fade out dark overlay
			_fade_out_dark_overlay()
	else:
		# Very subtle flickering (±2% variation)
		var flicker = randf_range(-0.02, 0.02)
		energy = base_energy + (base_energy * flicker)

func _fade_in_dark_overlay():
	# Cancel any existing fade
	if fade_tween:
		fade_tween.kill()
	
	# Create fade in effect
	fade_tween = create_tween()
	fade_tween.tween_property(dark_overlay, "modulate:a", 0.5, 0.1)  # Fade to 50% opacity over 0.1 seconds

func _fade_out_dark_overlay():
	# Cancel any existing fade
	if fade_tween:
		fade_tween.kill()
	
	# Create fade out effect
	fade_tween = create_tween()
	fade_tween.tween_property(dark_overlay, "modulate:a", 0.0, 0.2)  # Fade to 0% opacity over 0.2 seconds
