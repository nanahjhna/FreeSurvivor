extends Node3D

var zombie_scene: PackedScene = preload("res://scenes/monsters/zombie/zombie.tscn")
var skeleton_scene: PackedScene = preload("res://scenes/monsters/skeleton/skeleton_enemy.tscn")
var mutant_scene: PackedScene = preload("res://scenes/monsters/mutant/mutant.tscn")

@export var max_active_monsters: int = 90
@export var min_spawn_dist: float = 18.0
@export var max_spawn_dist: float = 26.0

var spawn_timer: float = 0.0
var spawn_interval: float = 2.0
var player: Node3D = null
var boss_spawned: bool = false

func _process(delta: float):
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	
	spawn_timer += delta
	var current_time = GameManager.battle_time
	if current_time >= 180.0:
		if not boss_spawned:
			boss_spawned = true
			_spawn_boss()
		return
	
	# Start at a lively pace and increase pressure toward the boss encounter.
	spawn_interval = clamp(0.85 - (current_time / 180.0) * 0.30, 0.45, 0.85)
	
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_spawn_wave(current_time)

func _spawn_wave(current_time: float):
	var active_count := get_tree().get_nodes_in_group("enemies").size()
	if active_count >= max_active_monsters:
		return
	
	# Number of monsters in this burst
	var burst_size = 1
	if current_time > 15.0:
		burst_size = 2
	if current_time > 60.0:
		burst_size = 3
	if current_time > 120.0:
		burst_size = 4
	if current_time > 150.0:
		burst_size = 5
	
	for i in range(burst_size):
		if active_count >= max_active_monsters:
			break
		_spawn_single_monster(current_time)
		active_count += 1

func _spawn_boss():
	if player == null or not is_instance_valid(player):
		return
	UiFeedback.show_info("보스 등장! 강력한 변이 괴물을 처치하세요!")
	var angle := randf() * TAU
	var dist := max_spawn_dist + 3.0
	var boss := mutant_scene.instantiate() as Node3D
	get_tree().current_scene.add_child(boss)
	boss.global_position = player.global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	# Mutant's _ready sets its normal stats, so apply boss stats after adding it.
	boss.set("monster_id", "mutant_lord")
	boss.set("max_hp", 900.0)
	boss.set("current_hp", 900.0)
	boss.set("move_speed", 1.7)
	boss.set("attack_damage", 24.0)
	boss.set("xp_value", 60)
	var visual := boss.get_node_or_null("VisualRoot") as Node3D
	if visual:
		visual.scale = Vector3(2.2, 2.2, 2.2)

func _spawn_single_monster(current_time: float):
	var angle = randf() * TAU
	var dist = randf_range(min_spawn_dist, max_spawn_dist)
	var spawn_pos = player.global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	
	# Select monster type based on time
	var roll = randf()
	var selected_scene: PackedScene = zombie_scene
	
	if current_time < 45.0:
		selected_scene = zombie_scene
	elif current_time < 120.0:
		if roll < 0.7:
			selected_scene = zombie_scene
		else:
			selected_scene = skeleton_scene
	elif current_time < 200.0:
		if roll < 0.5:
			selected_scene = zombie_scene
		elif roll < 0.82:
			selected_scene = skeleton_scene
		else:
			selected_scene = mutant_scene
	else:
		if roll < 0.35:
			selected_scene = zombie_scene
		elif roll < 0.7:
			selected_scene = skeleton_scene
		else:
			selected_scene = mutant_scene
	
	var monster = selected_scene.instantiate()
	get_tree().current_scene.add_child(monster)
	monster.global_position = spawn_pos
