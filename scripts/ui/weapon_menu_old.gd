extends CanvasLayer

signal weapon_changed(weapon_type: String)

var player: Player = null
var is_menu_open: bool = false
var current_weapon: String = "bat"  # Default weapon

var weapon_panel: Panel = null
var bat_button: Button = null
var gun_button: Button = null
var close_button: Button = null
var title_label: Label = null

# Bat cooldown UI
var bat_cooldown_bar: Control = null
var yeet_label: Label = null

# Menu sounds
var menu_hover_sound: AudioStream = null
var menu_select_sound: AudioStream = null

func _ready() -> void:
	# Add to weapon_menu group so player can find this
	add_to_group("weapon_menu")
	
	# Try to get nodes with fallbacks
	weapon_panel = get_node_or_null("WeaponPanel")
	bat_button = get_node_or_null("WeaponPanel/VBoxContainer/BatButton")
	gun_button = get_node_or_null("WeaponPanel/VBoxContainer/GunButton")
	close_button = get_node_or_null("WeaponPanel/VBoxContainer/CloseButton")
	title_label = get_node_or_null("WeaponPanel/VBoxContainer/TitleLabel")
	
	# Get bat cooldown UI nodes
	bat_cooldown_bar = get_node_or_null("BatCooldownBar")
	yeet_label = get_node_or_null("YeetLabel")
	
	# Apply default font to all UI elements
	if yeet_label:
		FontConfig.apply_ui_font(yeet_label)
	if title_label:
		FontConfig.apply_ui_font(title_label)
	if bat_button:
		FontConfig.apply_default_font_button(bat_button)
	if gun_button:
		FontConfig.apply_default_font_button(gun_button)
	if close_button:
		FontConfig.apply_default_font_button(close_button)
	
	# Load menu sounds
	menu_hover_sound = load("res://sounds/menu-hover.mp3")
	menu_select_sound = load("res://sounds/menu-select.mp3")
	
	
	# Hide menu initially
	if weapon_panel:
		weapon_panel.visible = false
	
	# Connect button signals safely
	if bat_button:
		bat_button.pressed.connect(_on_bat_selected)
		bat_button.mouse_entered.connect(_play_hover_sound)
		
	if gun_button:
		gun_button.pressed.connect(_on_gun_selected)
		gun_button.mouse_entered.connect(_play_hover_sound)
		
	if close_button:
		close_button.pressed.connect(_close_menu)
		close_button.mouse_entered.connect(_play_hover_sound)

func set_player(p: Player) -> void:
	player = p
	# Initialize current weapon from player's state
	if player:
		if player.current_equipped_weapon:
			current_weapon = player.current_equipped_weapon
		# Update initial cooldown visibility
		update_bat_cooldown(player._bat_throw_cooldown)
	_update_weapon_buttons()

func _update_weapon_buttons() -> void:
	if not player:
		return
	
	# Update button states based on available weapons
	if bat_button:
		bat_button.disabled = false
		bat_button.text = "BAT"
		if current_weapon == "bat":
			bat_button.text = "BAT [EQUIPPED]"
	
	if gun_button:
		gun_button.disabled = not player.has_gun
		gun_button.text = "GUN"
		if not player.has_gun:
			gun_button.text = "GUN [LOCKED]"
		elif current_weapon == "gun":
			gun_button.text = "GUN [EQUIPPED]"

func toggle_menu() -> void:
	if is_menu_open:
		_close_menu()
	else:
		_open_menu()

func _open_menu() -> void:
	if not weapon_panel:
		return
	
	is_menu_open = true
	weapon_panel.visible = true
	_update_weapon_buttons()
	
	# Make the panel consume all mouse input
	weapon_panel.mouse_filter = Control.MOUSE_FILTER_STOP

func _close_menu() -> void:
	if not weapon_panel:
		return
	
	is_menu_open = false
	weapon_panel.visible = false
	
	# Reset mouse filter to allow normal input
	weapon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _play_hover_sound() -> void:
	if menu_hover_sound:
		var audio_player = AudioStreamPlayer.new()
		audio_player.stream = menu_hover_sound
		add_child(audio_player)
		audio_player.play()
		audio_player.finished.connect(audio_player.queue_free)

func _play_select_sound() -> void:
	if menu_select_sound:
		var audio_player = AudioStreamPlayer.new()
		audio_player.stream = menu_select_sound
		add_child(audio_player)
		audio_player.play()
		audio_player.finished.connect(audio_player.queue_free)

func _on_bat_selected() -> void:
	if not player:
		return
	
	# Play select sound
	_play_select_sound()
	
	# Use player's weapon switching method
	player.switch_to_weapon("bat")
	current_weapon = "bat"
	
	# Update UI
	_update_weapon_buttons()
	_close_menu()
	
	# Update cooldown visibility
	if player:
		update_bat_cooldown(player._bat_throw_cooldown)
	
	# Emit signal
	weapon_changed.emit("bat")

func _on_gun_selected() -> void:
	if not player or not player.has_gun:
		return
	
	# Play select sound
	_play_select_sound()
	
	# Use player's weapon switching method
	player.switch_to_weapon("gun")
	current_weapon = "gun"
	
	# Update UI
	_update_weapon_buttons()
	_close_menu()
	
	# Update cooldown visibility
	if player:
		update_bat_cooldown(player._bat_throw_cooldown)
	
	# Emit signal
	weapon_changed.emit("gun")

func _gui_input(event: InputEvent) -> void:
	# Block all mouse clicks when menu is open
	if is_menu_open and event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()

func update_bat_cooldown(cooldown_time: float, bat_thrown: bool = false) -> void:
	if bat_cooldown_bar:
		# Always visible when bat is equipped, invisible for other weapons
		if player and current_weapon == "bat":
			bat_cooldown_bar.visible = true
			if yeet_label:
				yeet_label.visible = true
			if bat_thrown:
				# Quick animation to 0 when bat is thrown
				bat_cooldown_bar.quick_reset_to_zero()
			else:
				# Normal cooldown update
				bat_cooldown_bar.set_progress_from_cooldown(cooldown_time, 10.0)
		else:
			bat_cooldown_bar.visible = false
			if yeet_label:
				yeet_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	# Block all attack inputs when menu is open
	if is_menu_open and event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Toggle menu with Tab key (check physical key directly)
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		toggle_menu()
	
	# Close menu with Escape
	if event.is_action_pressed("ui_cancel") and is_menu_open:
		_close_menu()
