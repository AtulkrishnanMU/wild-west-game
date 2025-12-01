extends "res://scripts/levels/level.gd"

const AXE_ENEMY_SCENE := preload("res://scenes/characters/axe_enemy.tscn")
const GUN_ENEMY_SCENE := preload("res://scenes/characters/gun_enemy.tscn")

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
		cash_label = $"UI/CashLabel"
	health_percent_label = $"UI/HealthPercentLabel"
	bullet_icons = $"UI/BulletIcons"
	reload_label = $"UI/ReloadLabel"
	ui_layer = $"UI"

	# Use common UI setup
	setup_ui()
	
	# Use common level setup
	setup_level()

	if player == null:
		push_warning("EndlessLevel: Player node not found; spawning logic will still run but player-dependent placement may fail.")
	
	spawn_timer = spawn_interval_start

func _process(delta: float) -> void:
	time_since_start += delta
	
	# Use common level process
	process_level(delta)
	
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

func _get_current_spawn_interval() -> float:
	var t := 0.0
	if kills_for_max_speed > 0:
		t = clamp(float(kill_count) / float(kills_for_max_speed), 0.0, 1.0)
	return lerp(spawn_interval_start, spawn_interval_min, t)

func _update_spawn_interval() -> void:
	# Intentionally left simple for now; _get_current_spawn_interval() handles scaling
	pass

func _spawn_axe_enemy() -> void:
	spawn_enemy_around_player(AXE_ENEMY_SCENE, 120.0, 420.0)

func _spawn_gun_enemy() -> void:
	if GUN_ENEMY_SCENE == null:
		return
	if gun_enemy_alive or current_gun_enemy != null:
		return
	
	var enemy := spawn_enemy_around_player(GUN_ENEMY_SCENE, 260.0, 520.0)
	if enemy:
		current_gun_enemy = enemy
		# Also watch for the gun enemy leaving the tree as a fallback
		enemy.tree_exited.connect(_on_gun_enemy_tree_exited.bind(enemy))

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
