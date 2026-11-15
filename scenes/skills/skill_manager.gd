extends Node

signal skill_cooldown_updated(skill_key: String, current_cd: float, max_cd: float)

var sword_wave_scene: PackedScene = preload("res://scenes/skills/sword_wave.tscn")
var spin_attack_scene: PackedScene = preload("res://scenes/skills/spin_attack.tscn")
var flame_attack_scene: PackedScene = preload("res://scenes/skills/flame_attack.tscn")
var explosion_scene: PackedScene = preload("res://scenes/skills/explosion.tscn")

var cooldowns: Dictionary = {
	"q": 0.0,
	"w": 0.0,
	"e": 0.0,
	"r": 0.0
}

var player: Node3D = null
var auto_battle_enabled: bool = false
var _auto_potion_timer: float = 0.0

func _ready():
	player = get_parent() as Node3D

func _process(delta: float):
	if GameManager.current_location != GameManager.Location.BATTLE:
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		return
	
	# Update cooldowns
	for key in cooldowns:
		if cooldowns[key] > 0.0:
			cooldowns[key] = max(0.0, cooldowns[key] - delta)
			var max_cd := get_max_cooldown(key)
			emit_signal("skill_cooldown_updated", key, cooldowns[key], max_cd)
	
	# Keyboard shortcuts still go through the exact same public function as buttons.
	if Input.is_action_just_pressed("skill_q"):
		_press_skill("q")
	elif Input.is_action_just_pressed("skill_w"):
		_press_skill("w")
	elif Input.is_action_just_pressed("skill_e"):
		_press_skill("e")
	elif Input.is_action_just_pressed("skill_r"):
		_press_skill("r")
	
	if auto_battle_enabled:
		_run_auto_battle(delta)

func _press_skill(key: String):
	if not try_cast(key):
		var cd := get_cooldown(key)
		if cd > 0.05:
			UiFeedback.show_info("%s 스킬 쿨타임이 %.1f초 남았습니다." % [key.to_upper(), cd])
		elif player and is_instance_valid(player):
			var skill_id := GameData.get_equipped_skill(key)
			var cost := int(GameData.skill_meta.get(skill_id, {}).get("sp_cost", 0))
			if float(player.get("current_sp")) < cost:
				UiFeedback.show_info("SP가 부족합니다. (%d / %d)" % [int(player.get("current_sp")), cost])

func try_cast(skill_key: String) -> bool:
	if GameManager.current_location != GameManager.Location.BATTLE:
		return false
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return false
	if not cooldowns.has(skill_key):
		return false
	var ability_id := GameData.get_equipped_skill(skill_key)
	if not GameData.skill_meta.has(ability_id):
		return false
	if not ["q", "w", "e", "r"].has(ability_id):
		return false
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return false
	if cooldowns[skill_key] > 0.0:
		return false
	var meta: Dictionary = GameData.skill_meta[ability_id]
	var sp_cost := float(meta.get("sp_cost", 0))
	if float(player.get("current_sp")) < sp_cost:
		return false
	if not player.has_method("use_sp") or not player.call("use_sp", sp_cost):
		return false
	cooldowns[skill_key] = float(GameData.skill_cooldowns.get(ability_id, meta.get("base_cd", 1.0)))
	emit_signal("skill_cooldown_updated", skill_key, cooldowns[skill_key], get_max_cooldown(skill_key))
	match ability_id:
		"q":
			_cast_q()
		"w":
			_cast_w()
		"e":
			_cast_e()
		"r":
			_cast_r()
	return true

func get_cooldown(skill_key: String) -> float:
	return float(cooldowns.get(skill_key, 0.0))

func get_max_cooldown(skill_key: String) -> float:
	var ability_id := GameData.get_equipped_skill(skill_key)
	return float(GameData.skill_cooldowns.get(ability_id, 1.0))

func set_auto_battle(enabled: bool):
	auto_battle_enabled = enabled
	UiFeedback.show_info("자동 전투를 %s했습니다." % ("켜" if enabled else "꺼"))

func _run_auto_battle(delta: float):
	_auto_potion_timer = max(0.0, _auto_potion_timer - delta)
	if _auto_potion_timer <= 0.0:
		_auto_potion_timer = 4.0
		if player.current_hp <= player.max_hp * 0.4 and int(GameData.item_counts.get(1, 0)) > 0:
			player.use_item(1)

	for key in ["q", "w", "e", "r"]:
		if cooldowns[key] > 0.0:
			continue
		var ability_id := GameData.get_equipped_skill(key)
		var meta: Dictionary = GameData.skill_meta.get(ability_id, {})
		var reach: float = float(meta.get("range", 8.0))
		if _has_enemy_within(reach):
			try_cast(key)

func _has_enemy_within(reach: float) -> bool:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			if player.global_position.distance_to(enemy.global_position) <= reach:
				return true
	return false

func _get_player_facing() -> Vector3:
	var visual_root = player.get_node_or_null("VisualRoot")
	if visual_root:
		var rot_y = visual_root.rotation.y
		return Vector3(sin(rot_y), 0, cos(rot_y))
	return -player.global_transform.basis.z

func _get_magic_power_multiplier() -> float:
	var stats := player.get("stat_manager") as StatManager
	if stats == null:
		return 1.0
	return clampf(stats.mag_atk() / 20.0, 0.7, 1.6)

func _cast_q():
	var facing = _get_player_facing()
	var wave = sword_wave_scene.instantiate()
	get_tree().current_scene.add_child(wave)
	wave.global_position = player.global_position + Vector3(0, 0.8, 0) + facing * 0.5
	wave.setup(facing, GameData.attack_damage_mult * GameData.get_skill_damage_multiplier("q"))

func _cast_w():
	var spin = spin_attack_scene.instantiate()
	get_tree().current_scene.add_child(spin)
	spin.setup(player, GameData.attack_damage_mult * GameData.get_skill_damage_multiplier("w"))

func _cast_e():
	var facing = _get_player_facing()
	var flame = flame_attack_scene.instantiate()
	get_tree().current_scene.add_child(flame)
	var damage_multiplier = GameData.attack_damage_mult * GameData.get_skill_damage_multiplier("e") * _get_magic_power_multiplier()
	flame.setup(player.global_position, facing, damage_multiplier)

func _cast_r():
	var boom = explosion_scene.instantiate()
	get_tree().current_scene.add_child(boom)
	var damage_multiplier = GameData.attack_damage_mult * GameData.get_skill_damage_multiplier("r") * _get_magic_power_multiplier()
	boom.setup(player.global_position, damage_multiplier)
