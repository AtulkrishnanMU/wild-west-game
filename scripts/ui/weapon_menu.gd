extends CanvasLayer

signal weapon_changed(weapon_type: String)

var player: Player = null
var is_menu_open: bool = false
var current_weapon: String = "bat"  # Default weapon

var weapon_panel: Panel = null
var bat_button: Button = null
var gun_button: Button = null
var close_button: Button = null

func _ready() -> void:
	# Add to weapon_menu group so player can find this
	add_to_group("weapon_menu")
	
	# Try to get nodes with fallbacks
	weapon_panel = get_node_or_null("WeaponPanel")
	bat_button = get_node_or_null("WeaponPanel/VBoxContainer/BatButton")
	gun_button = get_node_or_null("WeaponPanel/VBoxContainer/GunButton")
	close_button = get_node_or_null("WeaponPanel/VBoxContainer/CloseButton")
	
	print("Weapon menu nodes found:")
	print("  WeaponPanel: ", weapon_panel != null)
	print("  BatButton: ", bat_button != null)
	print("  GunButton: ", gun_button != null)
	print("  CloseButton: ", close_button != null)
	
	# Hide menu initially
	if weapon_panel:
		weapon_panel.visible = false
	
	# Connect button signals safely
	if bat_button:
		bat_button.pressed.connect(_on_bat_selected)
		print("BatButton connected successfully")
	else:
		print("Warning: BatButton not found")
		
	if gun_button:
		gun_button.pressed.connect(_on_gun_selected)
		print("GunButton connected successfully")
	else:
		print("Warning: GunButton not found")
		
	if close_button:
		close_button.pressed.connect(_close_menu)
		print("CloseButton connected successfully")
	else:
		print("Warning: CloseButton not found")

func set_player(p: Player) -> void:
	player = p
	# Initialize current weapon from player's state
	if player:
		if player.current_equipped_weapon:
			current_weapon = player.current_equipped_weapon
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
		print("Warning: WeaponPanel not found")
		return
	
	is_menu_open = true
	weapon_panel.visible = true
	_update_weapon_buttons()
	
	# Make the panel consume all mouse input
	weapon_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	print("Weapon menu opened")

func _close_menu() -> void:
	if not weapon_panel:
		print("Warning: WeaponPanel not found")
		return
	
	is_menu_open = false
	weapon_panel.visible = false
	
	# Reset mouse filter to allow normal input
	weapon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	print("Weapon menu closed")

func _on_bat_selected() -> void:
	print("Bat button clicked!")
	if not player:
		print("No player reference")
		return
	
	# Use player's weapon switching method
	player.switch_to_weapon("bat")
	current_weapon = "bat"
	
	# Update UI
	_update_weapon_buttons()
	_close_menu()
	
	# Emit signal
	weapon_changed.emit("bat")
	print("Weapon switched to: BAT")

func _on_gun_selected() -> void:
	print("Gun button clicked!")
	if not player or not player.has_gun:
		print("No player reference or player doesn't have gun")
		return
	
	# Use player's weapon switching method
	player.switch_to_weapon("gun")
	current_weapon = "gun"
	
	# Update UI
	_update_weapon_buttons()
	_close_menu()
	
	# Emit signal
	weapon_changed.emit("gun")
	print("Weapon switched to: GUN")

func _gui_input(event: InputEvent) -> void:
	# Block all mouse clicks when menu is open
	if is_menu_open and event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		print("Mouse click blocked in GUI while menu is open")

func _unhandled_input(event: InputEvent) -> void:
	# Block all attack inputs when menu is open
	if is_menu_open and event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()
		print("Attack input blocked while menu is open")

func _input(event: InputEvent) -> void:
	# Toggle menu with Tab key (check physical key directly)
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		print("Tab key pressed, toggling menu")
		toggle_menu()
	
	# Close menu with Escape
	if event.is_action_pressed("ui_cancel") and is_menu_open:
		print("Escape pressed, closing menu")
		_close_menu()
