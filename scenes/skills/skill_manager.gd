extends Node

signal skill_cooldown_updated(skill_key: String, current_cd: float, max_cd: float)

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
	if player.is_dead:
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
			if str(GameData.skill_meta.get(skill, {}).get("cast_type", "")) == "heal" and player.current_hp >= player.max_hp:
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
	if player == null or not is_instance_valid(player) or player.is_dead:
		return false
	if player.has_method("is_skill_animation_busy") and player.is_skill_animation_busy():
		return false
	if cooldowns[skill_key] > 0.0:
		return false
	if str(GameData.skill_meta.get(ability_id, {}).get("cast_type", "")) == "heal" and player.current_hp >= player.max_hp:
		return false
	var meta: Dictionary = GameData.skill_meta[ability_id].duplicate(true)
	var cast_type := str(meta.get("cast_type", ""))
	if cast_type != "heal" and str(meta.get("effect_scene", "")).is_empty():
		push_warning("스킬 효과 씬이 등록되지 않았습니다: %s" % ability_id)
		return false
	cooldowns[skill_key] = float(GameData.skill_cooldowns.get(ability_id, meta.get("base_cd", 1.0)))
	emit_signal("skill_cooldown_updated", skill_key, cooldowns[skill_key], get_max_cooldown(skill_key))
	if player.has_method("play_skill_animation"):
		player.play_skill_animation(skill_key, ability_id)
	var runtime_definition := _prepare_skill_definition(ability_id, meta)
	if cast_type == "heal":
		player.heal(player.max_hp * float(meta.get("heal_ratio", 0.2)))
	else:
		var damage_multiplier := _get_skill_total_multiplier(ability_id, runtime_definition)
		var direction := _get_cast_direction(target)
		var delay := maxf(0.0, float(runtime_definition.get("impact_delay", 0.0)))
		if delay > 0.0:
			get_tree().create_timer(delay).timeout.connect(func():
				if is_instance_valid(player) and not player.is_dead and GameManager.current_state == GameManager.GameState.PLAYING:
					_spawn_registered_effect(ability_id, runtime_definition, target, direction, damage_multiplier)
			)
		else:
			_spawn_registered_effect(ability_id, runtime_definition, target, direction, damage_multiplier)
	return true


func _prepare_skill_definition(skill_id: String, definition: Dictionary) -> Dictionary:
	var prepared := definition.duplicate(true)
	prepared["skill_id"] = skill_id
	prepared["resolved_damage"] = _get_skill_attack_power(prepared) * GameData.get_skill_damage_multiplier(skill_id) * GameData.attack_damage_mult * _get_survival_skill_multiplier(skill_id, prepared)
	prepared["range_multiplier"] = _get_skill_range_multiplier(prepared)
	prepared["effect_range"] = maxf(0.1, float(prepared.get("range", 1.0))) * float(prepared["range_multiplier"])
	return prepared


func _get_skill_attack_power(definition: Dictionary) -> float:
	var stats := player.get("stat_manager") as StatManager
	if stats == null:
		return float(player.get("base_attack_damage"))
	if bool(definition.get("uses_magic_power", false)):
		return stats.mag_atk()
	return stats.phys_atk(bool(player.get("_has_ranged_weapon")))


func _get_skill_total_multiplier(_skill_id: String, definition: Dictionary) -> float:
	var attack_power := maxf(1.0, _get_skill_attack_power(definition))
	var resolved_damage := maxf(0.0, float(definition.get("resolved_damage", attack_power)))
	return resolved_damage / attack_power


func _get_skill_range_multiplier(definition: Dictionary) -> float:
	var bonus := GameData.get_survival_bonus("area_damage") + GameData.get_survival_bonus("attack_range")
	if str(definition.get("cast_type", "")) in ["spin", "burst", "flame"] or str(definition.get("bonus_type", "")) == "area":
		return maxf(1.0, 1.0 + bonus)
	return 1.0


func _spawn_registered_effect(
	skill_id: String,
	definition: Dictionary,
	target: Node3D,
	direction: Vector3,
	damage_multiplier: float
) -> void:
	var scene_path := str(definition.get("effect_scene", ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_warning("등록된 스킬 효과 씬을 찾을 수 없습니다: %s (%s)" % [skill_id, scene_path])
		return
	var effect_scene := load(scene_path) as PackedScene
	if effect_scene == null:
		push_warning("스킬 효과 씬을 불러오지 못했습니다: %s" % scene_path)
		return
	var count := 1
	if str(definition.get("cast_pattern", "")) == "fan":
		count = maxi(1, int(definition.get("projectile_count", 3)))
	var spread := float(definition.get("spread_radians", 0.0))
	for index in range(count):
		var angle := (float(index) - float(count - 1) * 0.5) * spread
		var effect := effect_scene.instantiate() as SkillEffectBase
		if effect == null:
			push_warning("효과 씬은 SkillEffectBase를 상속해야 합니다: %s" % scene_path)
			return
		effect.damage_source = skill_id
		effect.set_meta("resolved_damage", float(definition.get("resolved_damage", 0.0)))
		effect.set_meta("range_multiplier", float(definition.get("range_multiplier", 1.0)))
		effect.set_meta("effect_range", float(definition.get("effect_range", 0.0)))
		get_tree().current_scene.add_child(effect)
		effect.cast(player, target, direction.rotated(Vector3.UP, angle), damage_multiplier, definition)

func get_cooldown(skill_key: String) -> float:
	return float(cooldowns.get(skill_key, 0.0))

func get_passive_regen_amount(elapsed: float) -> float:
	if player == null or not is_instance_valid(player):
		return 0.0
	var total := 0.0
	for skill_id in GameData.skill_meta:
		var meta: Dictionary = GameData.skill_meta[skill_id]
		if str(meta.get("cast_type", "")) != "passive":
			continue
		if GameData.player_level < int(meta.get("unlock_level", 1)):
			continue
		if str(meta.get("passive_handler", "")) == "regen_after_damage":
			if float(player.get("_time_since_last_damage")) >= float(meta.get("regen_delay", 0.0)):
				total += player.max_hp * float(meta.get("hp_regen_ratio", 0.0)) * elapsed
	return total

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

func _get_survival_skill_multiplier(skill_id: String = "", definition: Dictionary = {}) -> float:
	var multiplier := 1.0 + GameData.get_survival_bonus("damage") + GameData.get_survival_bonus("damage_reckless") + GameData.get_survival_bonus("skill_damage")
	var skill_meta: Dictionary = definition if not definition.is_empty() else GameData.skill_meta.get(skill_id, {})
	var bonus_type := str(skill_meta.get("bonus_type", ""))
	if bool(skill_meta.get("uses_magic_power", false)):
		multiplier += GameData.get_survival_bonus("magic_damage")
	else:
		multiplier += GameData.get_survival_bonus("physical_damage")
	if bonus_type == "fire":
		multiplier += GameData.get_survival_bonus("fire_damage")
	if bonus_type == "area":
		multiplier += GameData.get_survival_bonus("area_damage")
	return multiplier
