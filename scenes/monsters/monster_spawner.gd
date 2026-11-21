extends Node3D

@export var max_active_monsters: int = 100
@export var min_spawn_dist: float = 18.0
@export var max_spawn_dist: float = 26.0
@export var monster_pool: Array[String] = ["infected"]
@export var boss_monster_id: String = "infected_boss"

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
	if current_time >= GameManager.next_boss_time and not boss_spawned:
		boss_spawned = true
		_spawn_boss()
	
	# Start at a lively pace and increase pressure toward the boss encounter.
	spawn_interval = clamp(0.65 - (current_time / 180.0) * 0.30, 0.35, 0.65)
	
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_spawn_wave(current_time)

func _spawn_wave(current_time: float):
	var active_count := get_tree().get_nodes_in_group("enemies").size()
	if active_count >= max_active_monsters:
		return
	
	# Number of monsters in this burst
	var burst_size = 2
	if current_time > 45.0:
		burst_size = 3
	if current_time > 100.0:
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
	UiFeedback.show_info("보스 등장! 거대 감염자를 처치하세요!")
	var angle := randf() * TAU
	var dist := max_spawn_dist + 3.0
	var boss_hp: float = 900.0 * (1.0 + float(GameManager.boss_defeated_count) * 0.35)
	var boss := MonsterManager.spawn_monster(
		boss_monster_id,
		get_tree().current_scene,
		player.global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist),
		{
			"max_hp": boss_hp,
			"move_speed": 1.7 + float(GameManager.boss_defeated_count) * 0.05,
			"attack_damage": 24.0 * (1.0 + float(GameManager.boss_defeated_count) * 0.2),
			"attack_range": 3.0,
			"xp_value": 60,
			"visual_scale": Vector3(2.2, 2.2, 2.2),
			"collision_scale": Vector3(2.2, 2.2, 2.2)
		}
	)
	if boss == null:
		return
	boss.set_meta("boss_reward_multiplier", GameManager.boss_reward_multiplier)
	boss.died.connect(_on_boss_died)

func _on_boss_died(_boss: BaseMonster):
	boss_spawned = false

func _spawn_single_monster(current_time: float):
	var angle = randf() * TAU
	var dist = randf_range(min_spawn_dist, max_spawn_dist)
	var spawn_pos = player.global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	
	var monster_id := "infected"
	if not monster_pool.is_empty():
		monster_id = monster_pool[randi_range(0, monster_pool.size() - 1)]
	var monster := MonsterManager.spawn_monster(monster_id, get_tree().current_scene, spawn_pos)
	if monster == null:
		return
	var difficulty: float = 1.0 + floorf(current_time / 180.0) * 0.25
	monster.max_hp *= difficulty
	monster.current_hp = monster.max_hp
	monster.attack_damage *= difficulty
	monster.global_position = spawn_pos
