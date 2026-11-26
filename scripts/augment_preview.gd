extends RefCounted

## Display estimates from the active character and the proposed card.
static func describe(upgrade: Dictionary) -> String:
	var stat := str(upgrade.get("stat", ""))
	var value := float(upgrade.get("value", 0.0))
	var current := GameData.get_survival_bonus(stat)
	match stat:
		"damage_reduction":
			var before := 50.0 * (1.0 - clampf(current, -0.5, 0.75))
			var after := 50.0 * (1.0 - clampf(current + value, -0.5, 0.75))
			return "피격 피해 예시    %s → %s" % [String.num(before, 1), String.num(after, 1)]
		"hp_regen":
			var hp := GameData.get_max_player_hp()
			var base := GameData.get_character_stat_manager(GameData.get_leader_id()).hp_recovery_rate()
			return "초당 회복    %s → %s" % [String.num(base + hp * current, 1), String.num(base + hp * (current + value), 1)]
	var application := _skill_application_summary(upgrade)
	return _effect_summary(upgrade) if application.is_empty() else application


static func _effect_summary(upgrade_data: Dictionary) -> String:
	var stat := str(upgrade_data.get("stat", ""))
	var value := float(upgrade_data.get("value", 0.0))
	var current := GameData.get_survival_bonus(stat)
	if stat in ["last_stand", "revive"]:
		return "%d회 → 1회" % roundi(current)
	if stat in ["free_reroll", "extra_offer"]:
		return "%d회 → %d회" % [roundi(current), roundi(current + value)]
	if stat in ["xp_magnet_range", "potion_magnet_range"]:
		return "%.1fm → %.1fm" % [current, current + value]
	if stat == "instant_xp":
		return ""
	return "누적 %+d%% → %+d%%" % [roundi(current * 100.0), roundi((current + value) * 100.0)]

static func skill_damage_changes(upgrade_data: Dictionary) -> Array[Dictionary]:
	var stat := str(upgrade_data.get("stat", ""))
	var value := float(upgrade_data.get("value", 0.0))
	var damage_stats := ["damage", "damage_reckless", "skill_damage", "physical_damage", "magic_damage", "fire_damage", "area_damage"]
	var changes: Array[Dictionary] = []
	if stat not in damage_stats:
		return changes
	for slot in ["q", "w", "e", "r"]:
		var skill_id := GameData.get_equipped_skill(slot)
		var meta: Dictionary = GameData.skill_meta.get(skill_id, {})
		if meta.is_empty() or str(meta.get("cast_type", "")) in ["heal", "passive"] or not _damage_card_applies(stat, meta):
			continue
		changes.append({
			"slot": slot.to_upper(),
			"name": str(meta.get("name", "")),
			"before": roundi(_preview_skill_damage(skill_id, meta, "", 0.0)),
			"after": roundi(_preview_skill_damage(skill_id, meta, stat, value)),
		})
	return changes


static func _skill_application_summary(upgrade_data: Dictionary) -> String:
	var stat := str(upgrade_data.get("stat", ""))
	var damage_stats := ["damage", "damage_reckless", "skill_damage", "physical_damage", "magic_damage", "fire_damage", "area_damage"]
	if stat in damage_stats:
		var results := PackedStringArray()
		for change in skill_damage_changes(upgrade_data):
			results.append("%s %d → %d" % [change.slot, change.before, change.after])
		if results.is_empty():
			return "장착한 스킬 중 피해 적용 대상 없음" if stat != "area_damage" else "범위 피해 적용 대상 없음"
		var lines := PackedStringArray()
		for index in range(0, results.size(), 2):
			var line := results[index]
			if index + 1 < results.size():
				line += "     " + results[index + 1]
			lines.append(line)
		return "예상 스킬 피해\n" + "\n".join(lines)
	if stat in ["attack_speed", "kill_attack_speed_rate", "cooldown", "attack_range"]:
		var affected := PackedStringArray()
		for slot in ["q", "w", "e", "r"]:
			var meta: Dictionary = GameData.skill_meta.get(GameData.get_equipped_skill(slot), {})
			if meta.is_empty():
				continue
			if stat == "attack_range" and str(meta.get("bonus_type", "")) != "area" and str(meta.get("cast_type", "")) not in ["spin", "burst", "flame"]:
				continue
			affected.append(slot.to_upper())
		return "적용 슬롯  " + " · ".join(affected) if not affected.is_empty() else "장착한 스킬 중 적용 대상 없음"
	if stat in ["execute_damage", "boss_damage", "low_hp_damage", "kill_explosion"]:
		return "기본 스킬 피해 예상치에는 미반영"
	return ""

static func _damage_card_applies(stat: String, meta: Dictionary) -> bool:
	var uses_magic := bool(meta.get("uses_magic_power", false))
	if stat == "physical_damage":
		return not uses_magic
	if stat == "magic_damage":
		return uses_magic
	if stat == "fire_damage":
		return str(meta.get("bonus_type", "")) == "fire"
	if stat == "area_damage":
		return str(meta.get("bonus_type", "")) == "area"
	return true

static func _preview_skill_damage(skill_id: String, meta: Dictionary, bonus_stat: String, bonus_value: float) -> float:
	var stats := GameData.get_character_stat_manager(GameData.get_leader_id())
	var uses_magic := bool(meta.get("uses_magic_power", false))
	var power := stats.mag_atk() if uses_magic else stats.phys_atk()
	power *= GameData.attack_damage_mult
	var level := int(GameData.skill_levels.get(skill_id, 1))
	var ratio := float(meta.get("base_dmg_ratio", 0.0)) + float(meta.get("dmg_step", 0.0)) * float(level - 1)
	var multiplier := 1.0 + GameData.get_survival_bonus("damage") + GameData.get_survival_bonus("damage_reckless") + GameData.get_survival_bonus("skill_damage")
	multiplier += GameData.get_survival_bonus("magic_damage") if uses_magic else GameData.get_survival_bonus("physical_damage")
	if str(meta.get("bonus_type", "")) == "fire":
		multiplier += GameData.get_survival_bonus("fire_damage")
	if str(meta.get("bonus_type", "")) == "area":
		multiplier += GameData.get_survival_bonus("area_damage")
	if bonus_stat == "damage" or bonus_stat == "damage_reckless" or bonus_stat == "skill_damage":
		multiplier += bonus_value
	elif bonus_stat == "physical_damage" and not uses_magic:
		multiplier += bonus_value
	elif bonus_stat == "magic_damage" and uses_magic:
		multiplier += bonus_value
	elif bonus_stat == "fire_damage" and str(meta.get("bonus_type", "")) == "fire":
		multiplier += bonus_value
	elif bonus_stat == "area_damage" and str(meta.get("bonus_type", "")) == "area":
		multiplier += bonus_value
	var sequence := PackedFloat32Array(meta.get("effect_sequence_damage_ratios", PackedFloat32Array()))
	if sequence.size() > 0:
		var base_ratio := maxf(0.001, float(meta.get("base_dmg_ratio", 1.0)))
		var sequence_total := 0.0
		for hit_ratio in sequence:
			sequence_total += float(hit_ratio) * ratio / base_ratio
		return power * sequence_total * multiplier
	return power * ratio * multiplier
