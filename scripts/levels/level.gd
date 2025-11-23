extends Node2D

# Shared UI helpers for main and endless levels
const BULLET_ICON_TEXTURE_PATH := "res://assets/icons/bullet-icon.png"

# These are expected to be set by child scripts via @onready vars
var player: Node = null
var health_bar: ProgressBar = null
var heal_cooldown_bar: ProgressBar = null
var cash_label: Label = null
var health_percent_label: Label = null
var bullet_icons: HBoxContainer = null


func _on_player_health_changed(current: int, max_value: int) -> void:
	var ratio: float = 0.0
	if max_value > 0:
		ratio = float(current) / float(max_value)
	if health_bar != null:
		health_bar.max_value = max_value
		health_bar.value = current
		if ratio > 0.6:
			health_bar.modulate = Color(0.2, 0.9, 0.2)
		elif ratio > 0.3:
			health_bar.modulate = Color(0.95, 0.8, 0.2)
		else:
			health_bar.modulate = Color(0.95, 0.2, 0.2)
	if health_percent_label != null and max_value > 0:
		health_percent_label.text = str(int(round(ratio * 100.0))) + "%"


func _on_player_cash_changed(current: int) -> void:
	if cash_label != null:
		cash_label.text = "CASH: " + str(current)


func _on_player_bullets_changed(current: int, max_value: int) -> void:
	_update_bullet_icons(current)


func _update_bullet_icons(current: int) -> void:
	if bullet_icons == null:
		return
	bullet_icons.add_theme_constant_override("separation", 10)
	for child in bullet_icons.get_children():
		child.queue_free()
	var tex := load(BULLET_ICON_TEXTURE_PATH)
	if tex == null:
		return
	for i in range(current):
		var icon := TextureRect.new()
		icon.texture = tex
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.custom_minimum_size = Vector2(8, 8)
		bullet_icons.add_child(icon)


func update_heal_cooldown_bar() -> void:
	if heal_cooldown_bar == null or player == null:
		return
	if not player.has_method("get_heal_cooldown_progress"):
		return
	var progress: float = player.get_heal_cooldown_progress()
	heal_cooldown_bar.value = progress
	heal_cooldown_bar.modulate = Color(1.0, 0.4, 0.8)
