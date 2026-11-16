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
	"r": 0.0,
	"a": 0.0,
	"s": 0.0
}

var player: Node3D = null
var auto_battle_enabled: bool = true
var _auto_potion_timer: float = 0.0
var _auto_battle_timer: float = 0.0
var _cooldown_ui_timer: float = 0.0

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
	
	# Update cooldown values every frame but refresh the HUD at 10 Hz.
	_cooldown_ui_timer += delta
	var refresh_cooldown_ui := _cooldown_ui_timer >= 0.10
	if refresh_cooldown_ui:
		_cooldown_ui_timer = 0.0
	for key in cooldowns:
		if cooldowns[key] > 0.0:
			cooldowns[key] = max(0.0, cooldowns[key] - delta)
			if refresh_cooldown_ui or cooldowns[key] <= 0.0:
				var max_cd := get_max_cooldown(key)
				emit_signal("skill_cooldown_updated", key, cooldowns[key], max_cd)
	
	# Keyboard shortcuts still go through the exact same public function as buttons.
	for key in cooldowns:
		if Input.is_action_just_pressed("skill_" + str(key)):
			press_skill(key)
	
	if auto_battle_enabled:
		_run_auto_battle(delta)

func press_skill(key: String):
	var skill := GameData.get_equipped_skill(key)
	if not GameData.skill_meta.has(skill):
		return
	if not GameData.is_survival_skill_unlocked(skill):
		UiFeedback.show_info("서바이벌 Lv.%d에 해금됩니다." % GameData.skill_meta[skill].unlock_level)
		return
	if not try_cast(key):
		var cd := get_cooldown(key)
		if cd > 0.05:
			UiFeedback.show_info("%s 스킬 쿨타임이 %.1f초 남았습니다." % [key.to_upper(), cd])
		elif player and is_instance_valid(player):
			if skill == "renewal" and player.current_hp >= player.max_hp:
				UiFeedback.show_info("체력이 가득 찼습니다.")

func try_cast(skill_key: String, target: Node3D = null) -> bool:
	if GameManager.current_location != GameManager.Location.BATTLE:
		return false
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return false
	if not cooldowns.has(skill_key):
		return false
	var ability_id := GameData.get_equipped_skill(skill_key)
	if not GameData.is_survival_skill_unlocked(ability_id):
		return false
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return false
	if cooldowns[skill_key] > 0.0:
		return false
	if ability_id == "renewal" and player.current_hp >= player.max_hp:
		return false
	var meta: Dictionary = GameData.skill_meta[ability_id]
	cooldowns[skill_key] = float(GameData.skill_cooldowns.get(ability_id, meta.get("base_cd", 1.0)))
	emit_signal("skill_cooldown_updated", skill_key, cooldowns[skill_key], get_max_cooldown(skill_key))
	match ability_id:
		"q":
			_launch_wave(_get_cast_direction(target), GameData.get_skill_damage_multiplier("q") * _get_survival_skill_multiplier())
		"w":
			_cast_w()
		"e":
			_cast_e(_get_cast_direction(target))
		"r":
			_cast_r()
		"volley":
			var facing := _get_cast_direction(target)
			for angle in [-0.32, 0.0, 0.32]:
				_launch_wave(facing.rotated(Vector3.UP, angle), float(meta.base_dmg_ratio) * _get_survival_skill_multiplier())
		"renewal":
			player.heal(player.max_hp * 0.2)
	return true

func get_cooldown(skill_key: String) -> float:
	return float(cooldowns.get(skill_key, 0.0))

func get_max_cooldown(skill_key: String) -> float:
	var ability_id := GameData.get_equipped_skill(skill_key)
	return float(GameData.skill_cooldowns.get(ability_id, 1.0))

func set_auto_battle(enabled: bool):
	auto_battle_enabled = enabled
	UiFeedback.show_info("자동 스킬 시전 %s" % ("ON" if enabled else "OFF"))

func _run_auto_battle(delta: float):
	_auto_battle_timer += delta
	if _auto_battle_timer < 0.10:
		return
	var tick_delta := _auto_battle_timer
	_auto_battle_timer = 0.0
	if player.current_hp <= player.max_hp * 0.7:
		try_cast("s")
	_auto_potion_timer = max(0.0, _auto_potion_timer - tick_delta)
	if _auto_potion_timer <= 0.0:
		_auto_potion_timer = 4.0
		if player.current_hp <= player.max_hp * 0.4 and int(GameData.item_counts.get(1, 0)) > 0:
			player.use_item(1)

	var target := _nearest_enemy()
	if target == null:
		return
	var distance := player.global_position.distance_to(target.global_position)
	for key in ["r", "a", "q", "w", "e"]:
		if cooldowns[key] > 0.0:
			continue
		var ability_id := GameData.get_equipped_skill(key)
		if not GameData.is_survival_skill_unlocked(ability_id):
			continue
		var meta: Dictionary = GameData.skill_meta.get(ability_id, {})
		var reach: float = float(meta.get("range", 8.0))
		if distance <= reach:
			try_cast(key, target)

func _nearest_enemy() -> Node3D:
	var nearest: Node3D = null
	var best_distance := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			var distance := player.global_position.distance_squared_to(enemy.global_position)
			if distance < best_distance:
				nearest = enemy
				best_distance = distance
	return nearest

func _get_cast_direction(target: Node3D) -> Vector3:
	if is_instance_valid(target):
		var direction := (target.global_position - player.global_position).slide(Vector3.UP)
		if not direction.is_zero_approx():
			return direction.normalized()
	var visual_root = player.get_node_or_null("VisualRoot")
	if visual_root:
		return -visual_root.global_transform.basis.z.slide(Vector3.UP).normalized()
	return -player.global_transform.basis.z

func _get_magic_power_multiplier() -> float:
	var stats := player.get("stat_manager") as StatManager
	if stats == null:
		return 1.0
	return clampf(stats.mag_atk() / 20.0, 0.7, 1.6)

func _get_survival_skill_multiplier(skill_id: String = "") -> float:
	var multiplier := 1.0 + GameData.get_survival_bonus("damage") + GameData.get_survival_bonus("damage_reckless") + GameData.get_survival_bonus("skill_damage") + GameData.get_survival_bonus("magic_damage")
	if skill_id == "e":
		multiplier += GameData.get_survival_bonus("fire_damage")
	if skill_id in ["w", "r"]:
		multiplier += GameData.get_survival_bonus("area_damage")
	return multiplier

func _launch_wave(facing: Vector3, power: float):
	var wave = sword_wave_scene.instantiate()
	get_tree().current_scene.add_child(wave)
	wave.global_position = player.global_position + Vector3(0, 0.8, 0) + facing * 0.5
	wave.setup(facing, GameData.attack_damage_mult * power)

func _cast_w():
	var spin = spin_attack_scene.instantiate()
	get_tree().current_scene.add_child(spin)
	spin.setup(player, GameData.attack_damage_mult * GameData.get_skill_damage_multiplier("w") * _get_survival_skill_multiplier("w"))

func _cast_e(facing: Vector3):
	var flame = flame_attack_scene.instantiate()
	get_tree().current_scene.add_child(flame)
	var damage_multiplier = GameData.attack_damage_mult * GameData.get_skill_damage_multiplier("e") * _get_magic_power_multiplier() * _get_survival_skill_multiplier("e")
	flame.setup(player.global_position, facing, damage_multiplier)

func _cast_r():
	var boom = explosion_scene.instantiate()
	get_tree().current_scene.add_child(boom)
	var damage_multiplier = GameData.attack_damage_mult * GameData.get_skill_damage_multiplier("r") * _get_magic_power_multiplier() * _get_survival_skill_multiplier("r")
	boom.setup(player.global_position, damage_multiplier)
