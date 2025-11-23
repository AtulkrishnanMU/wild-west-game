extends "res://scripts/levels/level.gd"

const AXE_ENEMY_SCENE := preload("res://scenes/characters/axe_enemy.tscn")
const GUN_ENEMY_SCENE := preload("res://scenes/characters/gun_enemy.tscn")

@onready var ui_layer: CanvasLayer = $"UI"

var kill_count: int = 0
var time_since_start: float = 0.0

var spawn_timer: float = 0.0
var spawn_interval_start: float = 4.0
var spawn_interval_min: float = 0.8
var kills_for_max_speed: int = 40

var gun_unlock_kills: int = 12
var gun_unlock_time: float = 45.0

var gun_spawned: bool = false
var gun_enemy_alive: bool = false
var current_gun_enemy: Node = null

func _ready() -> void:
	# Initialize shared UI references for Level base class
	player = $"Player"
	health_bar = $"UI/HealthBar"
	heal_cooldown_bar = $"UI/HealCooldownBar"
	cash_label = $"UI/CashLabel"
	health_percent_label = $"UI/HealthPercentLabel"
	bullet_icons = $"UI/BulletIcons"

	if player == null:
		push_warning("EndlessLevel: Player node not found; spawning logic will still run but player-dependent placement may fail.")
	else:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)
		if player.has_signal("cash_changed"):
			player.cash_changed.connect(_on_player_cash_changed)
		if player.has_signal("bullets_changed"):
			player.bullets_changed.connect(_on_player_bullets_changed)
		# Initialize UI to current player state
		_on_player_health_changed(player.health, player.MAX_HEALTH)
		_on_player_cash_changed(player.cash)
	# Apply same pixel font as main scene if available
	var ui_font := load("res://fonts/PixelOperator8.ttf")
	if ui_font:
		if health_bar:
			health_bar.add_theme_font_override("font", ui_font)
		if heal_cooldown_bar:
			heal_cooldown_bar.add_theme_font_override("font", ui_font)
		if cash_label:
			cash_label.add_theme_font_override("font", ui_font)
		if health_percent_label:
			health_percent_label.add_theme_font_override("font", ui_font)
	if health_bar:
		health_bar.show_percentage = false
	if heal_cooldown_bar:
		heal_cooldown_bar.show_percentage = false
		heal_cooldown_bar.min_value = 0.0
		heal_cooldown_bar.max_value = 1.0
	spawn_timer = spawn_interval_start

func _process(delta: float) -> void:
	time_since_start += delta
	# While there is no active gun enemy, keep spawning axe enemies on a timer.
	# Spawning is paused only while a gun enemy is alive so the player gets breathing room.
	if not gun_enemy_alive:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_axe_enemy()
			_update_spawn_interval()
			spawn_timer = _get_current_spawn_interval()
		
	if (not gun_spawned) and (kill_count >= gun_unlock_kills or time_since_start >= gun_unlock_time):
		_spawn_gun_enemy()
		gun_spawned = true
		gun_enemy_alive = true
	update_heal_cooldown_bar()

func _get_current_spawn_interval() -> float:
	var t := 0.0
	if kills_for_max_speed > 0:
		t = clamp(float(kill_count) / float(kills_for_max_speed), 0.0, 1.0)
	return lerp(spawn_interval_start, spawn_interval_min, t)

func _update_spawn_interval() -> void:
	# Intentionally left simple for now; _get_current_spawn_interval() handles scaling
	pass

func _spawn_axe_enemy() -> void:
	if AXE_ENEMY_SCENE == null:
		return
	var enemy := AXE_ENEMY_SCENE.instantiate()
	if enemy == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	# Spawn around the player horizontally; fall back to origin if player is missing
	var base_pos: Vector2 = Vector2.ZERO
	if player:
		base_pos = player.global_position
	var offset_x := randf_range(-420.0, 420.0)
	# Ensure enemies do not spawn too close to the player
	if abs(offset_x) < 120.0:
		offset_x = sign(offset_x if offset_x != 0.0 else 1.0) * 120.0
	var spawn_pos := base_pos + Vector2(offset_x, 0.0)
	enemy.global_position = spawn_pos
	# Track kills via Enemy's enemy_killed signal, if present
	if enemy.has_signal("enemy_killed"):
		enemy.connect("enemy_killed", Callable(self, "_on_enemy_killed"))
	scene.add_child(enemy)

func _spawn_gun_enemy() -> void:
	if GUN_ENEMY_SCENE == null:
		return
	if gun_enemy_alive or current_gun_enemy != null:
		return
	var enemy := GUN_ENEMY_SCENE.instantiate()
	if enemy == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var base_pos: Vector2 = Vector2.ZERO
	if player:
		base_pos = player.global_position
	var offset_x := randf_range(260.0, 520.0)
	if randi() % 2 == 0:
		offset_x = -offset_x
	var spawn_pos := base_pos + Vector2(offset_x, 0.0)
	enemy.global_position = spawn_pos
	current_gun_enemy = enemy
	if enemy.has_signal("enemy_killed"):
		enemy.connect("enemy_killed", Callable(self, "_on_enemy_killed"))
	# Also watch for the gun enemy leaving the tree as a fallback
	enemy.tree_exited.connect(_on_gun_enemy_tree_exited.bind(enemy))
	scene.add_child(enemy)

func _on_enemy_killed(enemy: Node) -> void:
	kill_count += 1
	if enemy == current_gun_enemy:
		gun_enemy_alive = false
		current_gun_enemy = null
		# After the gun enemy dies, normal spawning resumes automatically in _process

func _on_gun_enemy_tree_exited(exiting: Node) -> void:
	if exiting == current_gun_enemy:
		gun_enemy_alive = false
		current_gun_enemy = null
