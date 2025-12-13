extends CanvasLayer

signal weapon_changed(weapon_type: String)

var player: Player = null
var is_menu_open: bool = false
var current_weapon: String = "bat"  # Default weapon

# UI Elements
var weapon_menu: Panel = null
var title_label: Label = null
var grid_container: GridContainer = null

# Weapon buttons from scene
var bat_weapon_button: Button = null
var gun_weapon_button: Button = null
var close_button: Button = null

# Weapon icons and labels from scene
var bat_icon: TextureRect = null
var gun_icon: TextureRect = null
var bat_label: Label = null
var gun_label: Label = null

# Original icon textures for switching
var bat_original_texture: Texture2D = null
var gun_original_texture: Texture2D = null

# Red silhouette textures
var bat_silhouette_texture: Texture2D = null
var gun_silhouette_texture: Texture2D = null

# Other UI elements to hide when menu is open
var health_bar: ProgressBar = null
var cash_label: Label = null
var bullet_icons: HBoxContainer = null
var reload_label: Label = null
var health_percent_label: Label = null
var combo_text_label: Label = null
var combo_total_label: Label = null
var color_rect: ColorRect = null

# Bat cooldown UI
var bat_cooldown_bar: Control = null
var yeet_label: Label = null

# Menu sounds
var menu_hover_sound: AudioStream = null
var menu_select_sound: AudioStream = null

# Weapon data
const WEAPON_DATA = {
	"bat": {
		"name": "BAT",
		"icon_path": "res://assets/objects/bat.png",
		"unlocked": true
	},
	"gun": {
		"name": "GUN", 
		"icon_path": "res://assets/objects/gun.png",
		"unlocked": false  # Will be updated based on player state
	}
}

func _ready() -> void:
	# Add to weapon_menu group so player can find this
	add_to_group("weapon_menu")
	
	# Get main UI elements
	weapon_menu = get_node_or_null("WeaponMenu")
	title_label = get_node_or_null("WeaponMenu/TitleLabel")
	grid_container = get_node_or_null("WeaponMenu/GridContainer")
	
	# Get weapon buttons from scene
	bat_weapon_button = get_node_or_null("WeaponMenu/GridContainer/BatWeapon")
	gun_weapon_button = get_node_or_null("WeaponMenu/GridContainer/GunWeapon")
	close_button = get_node_or_null("WeaponMenu/CloseButton")
	
	# Get weapon icons and labels from scene
	bat_icon = get_node_or_null("WeaponMenu/GridContainer/BatWeapon/BatIcon")
	gun_icon = get_node_or_null("WeaponMenu/GridContainer/GunWeapon/GunIcon")
	bat_label = get_node_or_null("WeaponMenu/GridContainer/BatWeapon/BatLabel")
	gun_label = get_node_or_null("WeaponMenu/GridContainer/GunWeapon/GunLabel")
	
	# Store original textures and create red silhouettes
	if bat_icon:
		bat_original_texture = bat_icon.texture
		bat_silhouette_texture = _create_red_silhouette(bat_original_texture)
		bat_icon.texture = bat_silhouette_texture  # Default to silhouette
	
	if gun_icon:
		gun_original_texture = gun_icon.texture
		gun_silhouette_texture = _create_red_silhouette(gun_original_texture)
		gun_icon.texture = gun_silhouette_texture  # Default to silhouette
	
	# Get bat cooldown UI nodes
	bat_cooldown_bar = get_node_or_null("BatCooldownBar")
	yeet_label = get_node_or_null("YeetLabel")
	
	print("BatCooldownBar reference: ", bat_cooldown_bar)
	print("YeetLabel reference: ", yeet_label)
	
	# Get other UI elements to hide when menu opens
	health_bar = get_node_or_null("HealthBar")
	cash_label = get_node_or_null("CashLabel")
	bullet_icons = get_node_or_null("BulletIcons")
	reload_label = get_node_or_null("ReloadLabel")
	health_percent_label = get_node_or_null("HealthPercentLabel")
	combo_text_label = get_node_or_null("ComboTextLabel")
	combo_total_label = get_node_or_null("ComboTotalLabel")
	color_rect = get_node_or_null("ColorRect")
	
	# Apply default font to all text elements
	_apply_fonts()
	
	# Connect button signals
	if bat_weapon_button:
		bat_weapon_button.pressed.connect(_on_bat_selected)
		bat_weapon_button.mouse_entered.connect(_on_weapon_hover_start.bind(bat_weapon_button, bat_label))
		bat_weapon_button.mouse_exited.connect(_on_weapon_hover_end.bind(bat_weapon_button, bat_label))
	if gun_weapon_button:
		gun_weapon_button.pressed.connect(_on_gun_selected)
		gun_weapon_button.mouse_entered.connect(_on_weapon_hover_start.bind(gun_weapon_button, gun_label))
		gun_weapon_button.mouse_exited.connect(_on_weapon_hover_end.bind(gun_weapon_button, gun_label))
	if close_button:
		close_button.pressed.connect(_close_menu)
		close_button.mouse_entered.connect(_play_hover_sound)
	
	# Load menu sounds
	menu_hover_sound = load("res://sounds/menu-hover.mp3")
	menu_select_sound = load("res://sounds/menu-select.mp3")
	
	# Hide menu initially
	if weapon_menu:
		weapon_menu.visible = false

func _apply_fonts() -> void:
	# Apply font to title
	if title_label:
		FontConfig.apply_ui_font(title_label)
	
	# Apply font to YEET label
	if yeet_label:
		FontConfig.apply_ui_font(yeet_label)
	
	# Apply font to weapon labels WITHOUT outline
	if bat_label:
		_apply_weapon_label_font(bat_label)
	if gun_label:
		_apply_weapon_label_font(gun_label)
	
	# Apply font to close button
	if close_button:
		FontConfig.apply_default_font_button(close_button)

func _apply_weapon_label_font(label: Label) -> void:
	# Apply font without outline for weapon labels
	var font := FontConfig.get_default_font()
	if font and label:
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", FontConfig.DEFAULT_UI_FONT_SIZE)
		# No outline for weapon labels

func _create_red_silhouette(original_texture: Texture2D) -> Texture2D:
	if not original_texture:
		return null
	
	# Create new image from original texture
	var image := original_texture.get_image()
	if not image:
		return null
	
	# Convert to red silhouette
	var red_color = Color(0.651, 0.067, 0.11, 1)  # Same as HEALTH_LOW_COLOR
	for x in range(image.get_width()):
		for y in range(image.get_height()):
			var pixel_color = image.get_pixel(x, y)
			if pixel_color.a > 0:  # If pixel is not transparent
				image.set_pixel(x, y, red_color)
	
	# Create new texture from modified image
	var new_texture = ImageTexture.create_from_image(image)
	return new_texture

func set_player(p: Player) -> void:
	player = p
	# Initialize current weapon from player's state
	if player:
		if player.current_equipped_weapon:
			current_weapon = player.current_equipped_weapon
		# Update initial cooldown visibility
		update_bat_cooldown(player._bat_throw_cooldown)
	_update_weapon_states()

func _update_weapon_states() -> void:
	if not player:
		return
	
	# Reorder weapons to put equipped item first
	_reorder_weapons()
	
	# Update bat button and label
	if bat_weapon_button and bat_label:
		bat_weapon_button.visible = true  # Bat is always available
		_apply_default_weapon_style(bat_weapon_button, bat_label)
		if current_weapon == "bat":
			bat_label.text = "BAT\n<EQUIPPED>"
			bat_weapon_button.modulate = Color(1.2, 1.2, 1.0)
		else:
			bat_label.text = "BAT"
			bat_weapon_button.modulate = Color.WHITE
	
	# Update gun button and label - hide if player doesn't have gun
	if gun_weapon_button and gun_label:
		if not player.has_gun:
			gun_weapon_button.visible = false
		else:
			gun_weapon_button.visible = true
			_apply_default_weapon_style(gun_weapon_button, gun_label)
			if current_weapon == "gun":
				gun_label.text = "GUN\n<EQUIPPED>"
				gun_weapon_button.modulate = Color(1.2, 1.2, 1.0)
				gun_weapon_button.disabled = false
			else:
				gun_label.text = "GUN"
				gun_weapon_button.modulate = Color.WHITE
				gun_weapon_button.disabled = false

func _reorder_weapons() -> void:
	if not grid_container:
		return
	
	# Store references to weapon buttons
	var weapons_to_add = []
	
	# Remove all weapon buttons from grid container (but don't delete them)
	if bat_weapon_button:
		grid_container.remove_child(bat_weapon_button)
		weapons_to_add.append(bat_weapon_button)
	
	if gun_weapon_button and player and player.has_gun:
		grid_container.remove_child(gun_weapon_button)
		weapons_to_add.append(gun_weapon_button)
	
	# Add weapons back in the correct order
	if current_weapon == "gun" and gun_weapon_button and player and player.has_gun:
		# Gun is equipped, add it first
		grid_container.add_child(gun_weapon_button)
		if bat_weapon_button:
			grid_container.add_child(bat_weapon_button)
	else:
		# Bat is equipped or gun not available, add bat first
		if bat_weapon_button:
			grid_container.add_child(bat_weapon_button)
		if gun_weapon_button and player and player.has_gun:
			grid_container.add_child(gun_weapon_button)

func _apply_default_weapon_style(button: Button, label: Label) -> void:
	# Default style: black background, white text
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color.BLACK
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color.WHITE
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	
	button.add_theme_stylebox_override("normal", style_box)
	label.add_theme_color_override("font_color", Color.WHITE)

func _on_weapon_hover_start(button: Button, label: Label) -> void:
	# Reset modulate to ensure it doesn't affect the color
	button.modulate = Color.WHITE
	
	# Hover style: same red as health low color
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.651, 0.067, 0.11, 1)  # Same as HEALTH_LOW_COLOR
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color.BLACK
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	
	# Override both normal and hover states to ensure red color
	button.add_theme_stylebox_override("normal", style_box)
	button.add_theme_stylebox_override("hover", style_box)
	label.add_theme_color_override("font_color", Color.BLACK)
	
	# Switch to original icon on hover
	if button == bat_weapon_button and bat_icon and bat_original_texture:
		bat_icon.texture = bat_original_texture
	elif button == gun_weapon_button and gun_icon and gun_original_texture:
		gun_icon.texture = gun_original_texture
	
	_play_hover_sound()

func _on_weapon_hover_end(button: Button, label: Label) -> void:
	# Return to default style
	_apply_default_weapon_style(button, label)
	
	# Switch back to red silhouette
	if button == bat_weapon_button and bat_icon and bat_silhouette_texture:
		bat_icon.texture = bat_silhouette_texture
	elif button == gun_weapon_button and gun_icon and gun_silhouette_texture:
		gun_icon.texture = gun_silhouette_texture

func toggle_menu() -> void:
	if is_menu_open:
		_close_menu()
	else:
		_open_menu()

func _open_menu() -> void:
	if not weapon_menu:
		print("Warning: WeaponMenu not found")
		return
	
	is_menu_open = true
	weapon_menu.visible = true
	_update_weapon_states()
	
	# Hide other UI elements for cleaner experience
	_hide_other_ui_elements()
	
	# Make the menu consume all mouse input
	weapon_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	print("Weapon menu opened")

func _close_menu() -> void:
	if not weapon_menu:
		print("Warning: WeaponMenu not found")
		return
	
	is_menu_open = false
	weapon_menu.visible = false
	
	# Show other UI elements again
	_show_other_ui_elements()
	
	# Reset mouse filter to allow normal input
	weapon_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	print("Weapon menu closed")

func _hide_other_ui_elements() -> void:
	# Hide all other UI elements when weapon menu is open
	if health_bar:
		health_bar.visible = false
	if cash_label:
		cash_label.visible = false
	if bullet_icons:
		bullet_icons.visible = false
	if reload_label:
		reload_label.visible = false
	if health_percent_label:
		health_percent_label.visible = false
	if combo_text_label:
		combo_text_label.visible = false
	if combo_total_label:
		combo_total_label.visible = false
	if color_rect:
		color_rect.visible = false
	
	# Always hide bat cooldown UI when menu is open, regardless of current weapon
	if bat_cooldown_bar:
		bat_cooldown_bar.visible = false
		print("Hiding bat cooldown bar")
	if yeet_label:
		yeet_label.visible = false
		print("Hiding yeet label")

func _show_other_ui_elements() -> void:
	# Show all other UI elements when weapon menu is closed
	if health_bar:
		health_bar.visible = true
	if cash_label:
		cash_label.visible = true
	if bullet_icons:
		bullet_icons.visible = true
	if reload_label:
		reload_label.visible = true
	if health_percent_label:
		health_percent_label.visible = true
	# Only show combo labels if they're supposed to be visible (check their original state)
	if combo_text_label:
		combo_text_label.visible = false  # Keep combo labels hidden by default
	if combo_total_label:
		combo_total_label.visible = false  # Keep combo labels hidden by default
	if color_rect:
		color_rect.visible = true
	
	# Show weapon-specific UI based on current weapon
	_show_weapon_specific_ui()

func _show_weapon_specific_ui() -> void:
	# Hide all weapon-specific UI first
	if bat_cooldown_bar:
		bat_cooldown_bar.visible = false
	if yeet_label:
		yeet_label.visible = false
	if reload_label:
		reload_label.visible = false
	if bullet_icons:
		bullet_icons.visible = false
	
	# Show UI based on current weapon
	if current_weapon == "bat":
		# Show bat-specific UI
		if bat_cooldown_bar:
			bat_cooldown_bar.visible = true
		if yeet_label:
			yeet_label.visible = true
	elif current_weapon == "gun":
		# Show gun-specific UI
		if reload_label:
			reload_label.visible = true
		if bullet_icons:
			bullet_icons.visible = true

func _on_bat_selected() -> void:
	print("Bat button clicked!")
	if not player:
		print("No player reference")
		return
	
	# Play select sound
	_play_select_sound()
	
	# Use player's weapon switching method
	player.switch_to_weapon("bat")
	current_weapon = "bat"
	
	# Update UI
	_update_weapon_states()
	_close_menu()
	
	# Emit signal
	weapon_changed.emit("bat")
	print("Weapon switched to: BAT")

func _on_gun_selected() -> void:
	print("Gun button clicked!")
	if not player or not player.has_gun:
		print("No player reference or player doesn't have gun")
		return
	
	# Play select sound
	_play_select_sound()
	
	# Use player's weapon switching method
	player.switch_to_weapon("gun")
	current_weapon = "gun"
	
	# Update UI
	_update_weapon_states()
	_close_menu()
	
	# Emit signal
	weapon_changed.emit("gun")
	print("Weapon switched to: GUN")

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

func update_bat_cooldown(cooldown_time: float, bat_thrown: bool = false) -> void:
	if bat_cooldown_bar:
		# Only show when bat is equipped AND menu is NOT open
		if player and current_weapon == "bat" and not is_menu_open:
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
