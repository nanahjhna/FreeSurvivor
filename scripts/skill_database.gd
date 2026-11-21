class_name SkillDatabase
extends RefCounted

const CATALOG_PATH := "res://data/skill_catalog.json"

# Game-facing definitions are authored independently from character slots.
# Add a definition here, then reference its ID from CharacterSkillDatabase.
const GAME_SKILLS: Dictionary = {
	"fighter_q": {
		"name": "쇄도 연권", "icon": "👊", "desc": "전방으로 기공을 실은 주먹을 날려 경로의 적을 관통합니다.",
		"base_cd": 3.2, "base_dmg_ratio": 1.45, "cd_step": 0.1, "dmg_step": 0.18, "cost_base": 180,
		"range": 12.0, "unlock_level": 1, "effect": "직선 관통", "cast_type": "wave", "bonus_type": "physical",
		"effect_scene": "res://scenes/skills/sword_wave.tscn"
	},
	"fighter_w": {
		"name": "선풍각", "icon": "🌀", "desc": "몸을 회전시켜 주위 적을 연속으로 걷어찹니다.",
		"base_cd": 5.0, "base_dmg_ratio": 1.9, "cd_step": 0.16, "dmg_step": 0.22, "cost_base": 200,
		"range": 4.8, "unlock_level": 1, "effect": "주변 연속 타격", "cast_type": "spin", "bonus_type": "area",
		"effect_scene": "res://scenes/skills/spin_attack.tscn"
	},
	"fighter_e": {
		"name": "홍련권", "icon": "🔥", "desc": "전방에 불꽃이 번지는 강한 주먹을 내질러 넓은 범위를 공격합니다.",
		"base_cd": 7.0, "base_dmg_ratio": 2.15, "cd_step": 0.2, "dmg_step": 0.28, "cost_base": 240,
		"range": 8.0, "unlock_level": 1, "effect": "전방 화염 범위", "cast_type": "flame", "bonus_type": "fire",
		"uses_magic_power": true, "effect_scene": "res://scenes/skills/flame_attack.tscn"
	},
	"fighter_r": {
		"name": "용호폭진", "icon": "🐉", "desc": "기운을 폭발시켜 주변 넓은 범위에 큰 피해를 줍니다.",
		"base_cd": 24.0, "base_dmg_ratio": 4.2, "cd_step": 0.5, "dmg_step": 0.5, "cost_base": 400,
		"range": 9.5, "unlock_level": 8, "effect": "광역 폭발", "cast_type": "burst", "bonus_type": "area",
		"uses_magic_power": true, "effect_scene": "res://scenes/skills/explosion.tscn"
	},
	"fighter_volley": {
		"name": "삼연 기공탄", "icon": "✴️", "desc": "세 갈래 기공탄을 부채꼴로 발사합니다.",
		"base_cd": 8.0, "base_dmg_ratio": 0.72, "cd_step": 0.0, "dmg_step": 0.0, "cost_base": 280,
		"range": 14.0, "unlock_level": 2, "effect": "세 방향 관통", "cast_type": "volley", "bonus_type": "physical",
		"cast_pattern": "fan", "projectile_count": 3, "spread_radians": 0.32,
		"effect_scene": "res://scenes/skills/sword_wave.tscn"
	},
	"fighter_renewal": {
		"name": "기혈 회복", "icon": "✚", "desc": "호흡을 가다듬어 최대 HP의 20%를 회복합니다.",
		"base_cd": 28.0, "base_dmg_ratio": 0.0, "cd_step": 0.0, "dmg_step": 0.0, "cost_base": 320,
		"range": 0.0, "unlock_level": 5, "effect": "자가 회복", "cast_type": "heal", "heal_ratio": 0.2
	},
	"fighter_passive": {
		"name": "단련된 기혈", "icon": "☯", "desc": "피해를 4초 동안 받지 않으면 매초 최대 HP의 1%를 회복합니다.",
		"base_cd": 0.0, "base_dmg_ratio": 0.0, "cd_step": 0.0, "dmg_step": 0.0,
		"range": 0.0, "unlock_level": 1, "effect": "피격 중단 시 회복", "cast_type": "passive",
		"passive_handler": "regen_after_damage", "regen_delay": 4.0, "hp_regen_ratio": 0.01
	}
}

static func get_skill(skill_id: String) -> Dictionary:
	var definition: Dictionary = GAME_SKILLS.get(skill_id, {})
	return definition.duplicate(true)


static func has_skill(skill_id: String) -> bool:
	return GAME_SKILLS.has(skill_id)


static func get_registered_skill_ids() -> Array[String]:
	var ids: Array[String] = []
	for skill_id in GAME_SKILLS.keys():
		ids.append(str(skill_id))
	return ids

static func get_game_skills(skill_ids: Array) -> Dictionary:
	var result: Dictionary = {}
	for skill_id in skill_ids:
		var definition := get_skill(str(skill_id))
		if not definition.is_empty():
			result[str(skill_id)] = definition
	return result

static func get_catalog() -> Array[Dictionary]:
	if not FileAccess.file_exists(CATALOG_PATH):
		return []
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		return []
	var json_text := file.get_as_text().trim_prefix("\uFEFF")
	var parsed: Variant = JSON.parse_string(json_text)
	if not parsed is Dictionary:
		return []
	var result: Array[Dictionary] = []
	for skill in parsed.get("skills", []):
		if skill is Dictionary:
			result.append(skill)
	return result

static func get_reference_skill(skill_id: String) -> Dictionary:
	for skill in get_catalog():
		if str(skill.get("id", "")) == skill_id:
			return skill.duplicate(true)
	return {}
