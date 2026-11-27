extends Node

signal skill_cooldown_updated(skill_key: String, current_cd: float, max_cd: float)
signal skill_auto_cast(skill_key: String)

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
## Per-slot switches are intentionally runtime-only; the global auto switch still gates all of them.
var skill_auto_enabled: Dictionary = {
	"q": true, "w": true, "e": true, "r": true, "a": true, "s": true
}
var _auto_battle_timer: float = 0.0
var _cooldown_ui_timer: float = 0.0
var _manual_priority_timer: float = 0.0
var _queued_skill_key: String = ""
var _queued_skill_is_auto := false
const AUTO_BATTLE_INTERVAL := 0.10
const MANUAL_SKILL_PRIORITY_SECONDS := 1.25
const ENEMY_SCAN_INTERVAL := 0.10
var _enemy_scan_timer := 0.0
var _enemy_snapshot: Array[Node3D] = []
var _effect_scene_cache: Dictionary = {}

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
	_refresh_enemy_snapshot(delta)
	_manual_priority_timer = maxf(0.0, _manual_priority_timer - delta)
	
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
	if _process_queued_skill():
		return
	
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

func try_cast(skill_key: String, target: Node3D = null, is_automatic: bool = false) -> bool:
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
	if cooldowns[skill_key] > 0.0:
		return false
	var meta: Dictionary = GameData.skill_meta[ability_id]
	var cast_type := str(meta.get("cast_type", ""))
	if cast_type == "heal" and player.current_hp >= player.max_hp:
		return false
	if cast_type != "heal" and str(meta.get("effect_scene", "")).is_empty():
		push_warning("스킬 효과 씬이 등록되지 않았습니다: %s" % ability_id)
		return false
	if not is_automatic:
		_manual_priority_timer = MANUAL_SKILL_PRIORITY_SECONDS
	if player.is_skill_animation_busy():
		if _queued_skill_key.is_empty() or not is_automatic:
			_queued_skill_key = skill_key
			_queued_skill_is_auto = is_automatic
		return false
	_queued_skill_key = ""
	cooldowns[skill_key] = float(GameData.skill_cooldowns.get(ability_id, meta.get("base_cd", 1.0)))
	emit_signal("skill_cooldown_updated", skill_key, cooldowns[skill_key], get_max_cooldown(skill_key))
	var playback_rate: float = player.get_skill_playback_rate()
	if cast_type == "heal":
		player.play_skill_animation(skill_key, ability_id, PackedFloat32Array(), Callable(), playback_rate, Vector3.ZERO)
		player.heal(player.max_hp * float(meta.get("heal_ratio", 0.2)))
		var heal_sfx := get_tree().root.get_node_or_null("SfxManager")
		if heal_sfx and heal_sfx.has_method("play"):
			heal_sfx.play("heal", -2.0)
		if is_automatic:
			skill_auto_cast.emit(skill_key)
		return true
	var skill_sfx := get_tree().root.get_node_or_null("SfxManager")
	if skill_sfx and skill_sfx.has_method("play"):
		skill_sfx.play("skill_%s" % skill_key.to_lower(), -3.0)
	_play_attack_skill(skill_key, ability_id, meta, target, playback_rate)
	if is_automatic:
		skill_auto_cast.emit(skill_key)
	return true


func _play_attack_skill(skill_key: String, ability_id: String, meta: Dictionary, target: Node3D, playback_rate: float) -> void:
	var definition := _prepare_skill_definition(ability_id, meta)
	var damage_multiplier := _get_skill_total_multiplier(ability_id, definition)
	var impact_times := PackedFloat32Array(meta.get("effect_sequence_delays", PackedFloat32Array()))
	var impacts: Array[Dictionary] = []
	if impact_times.is_empty():
		impact_times.append(maxf(0.0, float(meta.get("impact_delay", 0.0))))
		impacts.append(definition)
	else:
		var ratios := PackedFloat32Array(meta.get("effect_sequence_damage_ratios", PackedFloat32Array()))
		var base_ratio := maxf(0.001, float(meta.get("base_dmg_ratio", 1.0)))
		for index in impact_times.size():
			var impact := definition.duplicate()
			impact["effect_sequence_index"] = index
			if index < ratios.size():
				impact["resolved_damage"] = float(definition["resolved_damage"]) * ratios[index] / base_ratio
			impacts.append(impact)

	var directional := str(meta.get("cast_type", "")) in ["wave", "volley", "flame"]
	var reach := float(definition["effect_range"])
	if directional and not is_instance_valid(target) and impact_times[0] > 0.0:
		target = _nearest_enemy(reach)
	var direction := _get_cast_direction(target)
	var facing := direction if directional else Vector3.ZERO
	var aim := {
		"target": weakref(target) if is_instance_valid(target) else null,
		"direction": direction,
		"update_facing": false,
	}
	var on_impact := _release_skill_impact.bind(ability_id, impacts, aim, damage_multiplier, directional)
	if player.play_skill_animation(skill_key, ability_id, impact_times, on_impact, playback_rate, facing):
		aim["update_facing"] = directional
		return
	# Allow data-only skills or missing model clips to keep their registered effects.
	for index in impact_times.size():
		var delay := maxf(0.0, impact_times[index]) / playback_rate
		if delay > 0.0:
			get_tree().create_timer(delay, false).timeout.connect(on_impact.bind(index))
		else:
			on_impact.call(index)


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
	return stats.phys_atk()


func _get_skill_total_multiplier(_skill_id: String, definition: Dictionary) -> float:
	var attack_power := maxf(1.0, _get_skill_attack_power(definition))
	var resolved_damage := maxf(0.0, float(definition.get("resolved_damage", attack_power)))
	return resolved_damage / attack_power


func _get_skill_range_multiplier(definition: Dictionary) -> float:
	var bonus := GameData.get_survival_bonus("area_damage") + GameData.get_survival_bonus("attack_range")
	if str(definition.get("cast_type", "")) in ["spin", "burst", "flame"] or str(definition.get("bonus_type", "")) == "area":
		return maxf(1.0, 1.0 + bonus)
	return 1.0


func _release_skill_impact(
	index: int, skill_id: String, impacts: Array[Dictionary], aim: Dictionary,
	damage_multiplier: float, directional: bool
) -> void:
	if not is_instance_valid(player) or player.is_dead:
		return
	if GameManager.current_location != GameManager.Location.BATTLE or GameManager.current_state != GameManager.GameState.PLAYING:
		return
	var definition := impacts[index]
	var target_ref := aim["target"] as WeakRef
	var target: Node3D = target_ref.get_ref() as Node3D if target_ref != null else null
	if target_ref != null and (not is_instance_valid(target) or bool(target.get("is_dead"))):
		target = _nearest_enemy(float(definition["effect_range"]))
		if is_instance_valid(target):
			aim["target"] = weakref(target)
	var direction: Vector3 = aim["direction"]
	if directional and is_instance_valid(target):
		direction = _get_cast_direction(target)
		aim["direction"] = direction
		if aim["update_facing"]:
			player.set_skill_facing_direction(direction)
	_spawn_registered_effect(skill_id, definition, target, direction, damage_multiplier)


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
	var effect_scene := _get_effect_scene(scene_path)
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
	if not enabled and _queued_skill_is_auto:
		_queued_skill_key = ""
	UiFeedback.show_info("자동 스킬 시전 %s" % ("ON" if enabled else "OFF"))

func set_skill_auto_enabled(skill_key: String, enabled: bool) -> void:
	if not skill_auto_enabled.has(skill_key):
		return
	skill_auto_enabled[skill_key] = enabled

func toggle_skill_auto(skill_key: String) -> bool:
	if not skill_auto_enabled.has(skill_key):
		return false
	var enabled := not bool(skill_auto_enabled[skill_key])
	set_skill_auto_enabled(skill_key, enabled)
	UiFeedback.show_info("%s 자동 사용 %s" % [skill_key.to_upper(), "ON" if enabled else "OFF"])
	return enabled

func is_skill_auto_enabled(skill_key: String) -> bool:
	return bool(skill_auto_enabled.get(skill_key, true))

func _run_auto_battle(delta: float):
	_auto_battle_timer += delta
	if _auto_battle_timer < AUTO_BATTLE_INTERVAL:
		return
	_auto_battle_timer = 0.0
	if _manual_priority_timer > 0.0 or not _queued_skill_key.is_empty():
		return
	if player.current_hp <= player.max_hp * 0.7:
		if is_skill_auto_enabled("s"):
			if try_cast("s", null, true) or not _queued_skill_key.is_empty():
				return
	var target := _nearest_enemy()
	if target == null:
		return
	var distance := player.global_position.distance_to(target.global_position)
	var candidates: Array[Dictionary] = []
	for key in ["r", "a", "q", "w", "e"]:
		if not is_skill_auto_enabled(key):
			continue
		if cooldowns[key] > 0.0:
			continue
		var ability_id := GameData.get_equipped_skill(key)
		if not GameData.is_survival_skill_unlocked(ability_id):
			continue
		var meta: Dictionary = GameData.skill_meta.get(ability_id, {})
		if str(meta.get("cast_type", "")) in ["heal", "passive"]:
			continue
		var reach := float(meta.get("range", 8.0)) * _get_skill_range_multiplier(meta)
		if distance > reach:
			continue
		var nearby_count := 0
		if _is_area_skill(meta):
			nearby_count = _count_nearby_enemies(maxf(1.0, reach))
			if nearby_count < maxi(1, int(meta.get("auto_min_targets", 2))):
				continue
		candidates.append({
			"key": key,
			"score": _get_auto_skill_score(key, meta, distance, reach, nearby_count)
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	for candidate in candidates:
		if try_cast(str(candidate.get("key", "")), target, true) or not _queued_skill_key.is_empty():
			return

func _get_auto_skill_score(key: String, meta: Dictionary, distance: float, reach: float, nearby_count: int) -> float:
	var slot_priority := float({"r": 5.0, "a": 4.0, "q": 3.0, "w": 2.2, "e": 2.0}.get(key, 1.0))
	var score := float(meta.get("auto_priority", 0.0))
	if score <= 0.0:
		score = float(slot_priority)
	score += float(meta.get("base_dmg_ratio", 1.0)) * 0.65
	score += clampf(1.0 - distance / maxf(0.1, reach), 0.0, 1.0) * 0.5
	if _is_area_skill(meta):
		score += minf(6.0, float(nearby_count)) * 1.35
	return score

func _is_area_skill(meta: Dictionary) -> bool:
	return str(meta.get("bonus_type", "")) == "area" or str(meta.get("cast_type", "")) in ["spin", "burst", "flame"]

func _count_nearby_enemies(radius: float) -> int:
	var count := 0
	var radius_squared := radius * radius
	for enemy in _enemy_snapshot:
		if not is_instance_valid(enemy) or bool(enemy.get("is_dead")):
			continue
		if player.global_position.distance_squared_to(enemy.global_position) <= radius_squared:
			count += 1
	return count

func _process_queued_skill() -> bool:
	if _queued_skill_key.is_empty():
		return false
	if player.is_skill_animation_busy():
		return false
	var key := _queued_skill_key
	var was_auto := _queued_skill_is_auto
	_queued_skill_key = ""
	_queued_skill_is_auto = false
	if was_auto:
		# Retry queued automatic casts after the current animation ends.
		# Previously the queued automatic skill was cleared and silently dropped.
		var target := _nearest_enemy()
		if try_cast(key, target, true):
			return true
		_auto_battle_timer = AUTO_BATTLE_INTERVAL
		return false
	return try_cast(key)

func should_use_basic_attack() -> bool:
	# 기본공격은 제거되었습니다. 자동 전투도 액티브 스킬만 사용합니다.
	return false

func _nearest_enemy(max_range: float = INF) -> Node3D:
	var nearest: Node3D = null
	var best_distance := max_range * max_range
	for enemy in _enemy_snapshot:
		if is_instance_valid(enemy) and not enemy.get("is_dead"):
			var distance := player.global_position.distance_squared_to(enemy.global_position)
			if distance < best_distance:
				nearest = enemy
				best_distance = distance
	return nearest

func _refresh_enemy_snapshot(delta: float) -> void:
	_enemy_scan_timer -= delta
	if _enemy_scan_timer > 0.0:
		return
	_enemy_scan_timer = ENEMY_SCAN_INTERVAL
	_enemy_snapshot.clear()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not bool(enemy.get("is_dead")):
			_enemy_snapshot.append(enemy as Node3D)

func _get_effect_scene(scene_path: String) -> PackedScene:
	if _effect_scene_cache.has(scene_path):
		return _effect_scene_cache[scene_path] as PackedScene
	var effect_scene := load(scene_path) as PackedScene
	_effect_scene_cache[scene_path] = effect_scene
	return effect_scene

func _get_cast_direction(target: Node3D) -> Vector3:
	if is_instance_valid(target):
		var direction := (target.global_position - player.global_position).slide(Vector3.UP)
		if not direction.is_zero_approx():
			return direction.normalized()
	return player.get_facing_direction()

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
