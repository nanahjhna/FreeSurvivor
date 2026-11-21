class_name SkillDatabase
extends RefCounted

const CATALOG_PATH := "res://data/skill_catalog.json"

static var _catalog_loaded := false
static var _catalog_cache: Array[Dictionary] = []
static var _catalog_index: Dictionary = {}

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
	},
	"swordsman_q": {
		"name": "질풍 베기", "icon": "🗡️", "desc": "전방으로 빠르게 파고들며 검기를 날립니다.",
		"base_cd": 3.0, "base_dmg_ratio": 1.6, "cd_step": 0.12, "dmg_step": 0.2, "cost_base": 0,
		"range": 13.0, "unlock_level": 1, "effect": "직선 검기", "cast_type": "wave", "bonus_type": "physical", "effect_scene": "res://scenes/skills/sword_wave.tscn"
	},
	"swordsman_w": {
		"name": "쌍검 회오리", "icon": "🌪️", "desc": "쌍검을 휘둘러 주변 적을 베어냅니다.",
		"base_cd": 5.5, "base_dmg_ratio": 1.75, "cd_step": 0.16, "dmg_step": 0.22, "cost_base": 0,
		"range": 5.0, "unlock_level": 1, "effect": "주변 참격", "cast_type": "spin", "bonus_type": "area", "effect_scene": "res://scenes/skills/spin_attack.tscn"
	},
	"swordsman_e": {
		"name": "섬광 연참", "icon": "✨", "desc": "전방을 가르는 섬광의 검격을 발사합니다.",
		"base_cd": 8.0, "base_dmg_ratio": 2.4, "cd_step": 0.2, "dmg_step": 0.3, "cost_base": 0,
		"range": 9.0, "unlock_level": 1, "effect": "전방 폭발", "cast_type": "flame", "bonus_type": "physical", "effect_scene": "res://scenes/skills/flame_attack.tscn"
	},
	"swordsman_r": {
		"name": "천강 낙월", "icon": "🌙", "desc": "강력한 검기를 폭발시켜 넓은 범위를 공격합니다.",
		"base_cd": 25.0, "base_dmg_ratio": 4.0, "cd_step": 0.5, "dmg_step": 0.55, "cost_base": 0,
		"range": 10.0, "unlock_level": 8, "effect": "광역 폭발", "cast_type": "burst", "bonus_type": "area", "effect_scene": "res://scenes/skills/explosion.tscn"
	},
	"archer_q": {
		"name": "관통 화살", "icon": "➶", "desc": "적을 관통하는 빠른 화살을 발사합니다.",
		"base_cd": 2.8, "base_dmg_ratio": 1.45, "cd_step": 0.1, "dmg_step": 0.18, "cost_base": 0,
		"range": 16.0, "unlock_level": 1, "effect": "직선 관통", "cast_type": "wave", "bonus_type": "physical", "effect_scene": "res://scenes/skills/sword_wave.tscn"
	},
	"archer_w": {
		"name": "매의 연사", "icon": "🏹", "desc": "세 방향으로 화살을 연속 발사합니다.",
		"base_cd": 6.0, "base_dmg_ratio": 0.85, "cd_step": 0.12, "dmg_step": 0.12, "cost_base": 0,
		"range": 15.0, "unlock_level": 1, "effect": "세 갈래 사격", "cast_type": "volley", "bonus_type": "physical",
		"cast_pattern": "fan", "projectile_count": 3, "spread_radians": 0.38, "effect_scene": "res://scenes/skills/sword_wave.tscn"
	},
	"archer_e": {
		"name": "올가미 사격", "icon": "🎯", "desc": "지정 방향을 강하게 꿰뚫는 사격을 가합니다.",
		"base_cd": 8.0, "base_dmg_ratio": 2.3, "cd_step": 0.18, "dmg_step": 0.28, "cost_base": 0,
		"range": 14.0, "unlock_level": 1, "effect": "강화 관통", "cast_type": "flame", "bonus_type": "physical", "effect_scene": "res://scenes/skills/flame_attack.tscn"
	},
	"archer_r": {
		"name": "유성 화살비", "icon": "☄️", "desc": "넓은 지역에 강력한 화살비를 쏟아붓습니다.",
		"base_cd": 24.0, "base_dmg_ratio": 3.8, "cd_step": 0.45, "dmg_step": 0.5, "cost_base": 0,
		"range": 11.0, "unlock_level": 8, "effect": "광역 폭발", "cast_type": "burst", "bonus_type": "area", "effect_scene": "res://scenes/skills/explosion.tscn"
	},
	"mage_q": {
		"name": "화염구", "icon": "🔥", "desc": "불덩이를 던져 전방의 적을 태웁니다.",
		"base_cd": 3.4, "base_dmg_ratio": 1.75, "cd_step": 0.12, "dmg_step": 0.22, "cost_base": 0,
		"range": 13.0, "unlock_level": 1, "effect": "마법 투사체", "cast_type": "wave", "bonus_type": "fire", "uses_magic_power": true, "effect_scene": "res://scenes/skills/sword_wave.tscn"
	},
	"mage_w": {
		"name": "잿불 폭풍", "icon": "🌋", "desc": "전방에 불꽃 폭풍을 일으킵니다.",
		"base_cd": 7.0, "base_dmg_ratio": 2.1, "cd_step": 0.18, "dmg_step": 0.28, "cost_base": 0,
		"range": 8.0, "unlock_level": 1, "effect": "화염 범위", "cast_type": "flame", "bonus_type": "fire", "uses_magic_power": true, "effect_scene": "res://scenes/skills/flame_attack.tscn"
	},
	"mage_e": {
		"name": "비전 폭발", "icon": "💥", "desc": "주변에 비전 에너지를 방출합니다.",
		"base_cd": 10.0, "base_dmg_ratio": 2.6, "cd_step": 0.22, "dmg_step": 0.32, "cost_base": 0,
		"range": 9.0, "unlock_level": 1, "effect": "주변 마법 폭발", "cast_type": "burst", "bonus_type": "magic", "uses_magic_power": true, "effect_scene": "res://scenes/skills/explosion.tscn"
	},
	"mage_r": {
		"name": "유성 낙하", "icon": "☄️", "desc": "거대한 마력 폭발로 넓은 범위의 적을 섬멸합니다.",
		"base_cd": 26.0, "base_dmg_ratio": 4.5, "cd_step": 0.5, "dmg_step": 0.55, "cost_base": 0,
		"range": 11.0, "unlock_level": 8, "effect": "대형 광역 폭발", "cast_type": "burst", "bonus_type": "magic", "uses_magic_power": true, "effect_scene": "res://scenes/skills/explosion.tscn"
	},
	"paladin_q": {
		"name": "심판의 강타", "icon": "⚔️", "desc": "성검을 내리쳐 전방의 적을 공격합니다.",
		"base_cd": 3.8, "base_dmg_ratio": 1.55, "cd_step": 0.12, "dmg_step": 0.2, "cost_base": 0,
		"range": 10.0, "unlock_level": 1, "effect": "전방 강타", "cast_type": "wave", "bonus_type": "physical", "effect_scene": "res://scenes/skills/sword_wave.tscn"
	},
	"paladin_w": {
		"name": "수호의 회전", "icon": "🛡️", "desc": "방패와 검을 휘둘러 주변의 적을 밀어냅니다.",
		"base_cd": 6.0, "base_dmg_ratio": 1.55, "cd_step": 0.16, "dmg_step": 0.2, "cost_base": 0,
		"range": 5.2, "unlock_level": 1, "effect": "주변 방어 타격", "cast_type": "spin", "bonus_type": "area", "effect_scene": "res://scenes/skills/spin_attack.tscn"
	},
	"paladin_e": {
		"name": "신성한 치유", "icon": "✚", "desc": "신성한 힘으로 최대 HP의 30%를 회복합니다.",
		"base_cd": 28.0, "base_dmg_ratio": 0.0, "cd_step": 0.0, "dmg_step": 0.0, "cost_base": 0,
		"range": 0.0, "unlock_level": 1, "effect": "자가 회복", "cast_type": "heal", "heal_ratio": 0.3
	},
	"paladin_r": {
		"name": "새벽의 심판", "icon": "☀️", "desc": "신성한 폭발로 주변의 적을 심판합니다.",
		"base_cd": 26.0, "base_dmg_ratio": 3.8, "cd_step": 0.48, "dmg_step": 0.5, "cost_base": 0,
		"range": 9.5, "unlock_level": 8, "effect": "광역 신성 폭발", "cast_type": "burst", "bonus_type": "magic", "uses_magic_power": true, "effect_scene": "res://scenes/skills/explosion.tscn"
	}
}

static func get_skill(skill_id: String) -> Dictionary:
	if GAME_SKILLS.has(skill_id):
		var registered_definition: Dictionary = GAME_SKILLS[skill_id]
		return registered_definition.duplicate(true)
	var reference := _get_catalog_entry(skill_id)
	if reference.is_empty() or not bool(reference.get("game_ready", false)):
		return {}
	var definition: Dictionary = {
		"name": str(reference.get("game_name", reference.get("reference_name", "스킬"))),
		"icon": str(reference.get("icon", "✨")),
		"desc": str(reference.get("reference_description", "")),
		"base_cd": float(reference.get("base_cd", 8.0)),
		"base_dmg_ratio": float(reference.get("base_dmg_ratio", 1.0)),
		"cd_step": float(reference.get("cd_step", 0.0)),
		"dmg_step": float(reference.get("dmg_step", 0.0)),
		"cost_base": int(reference.get("cost_base", 180)),
		"range": float(reference.get("range", 10.0)),
		"unlock_level": int(reference.get("unlock_level", 1)),
		"cast_type": str(reference.get("cast_type", "wave")),
		"bonus_type": str(reference.get("bonus_type", "physical")),
		"effect_scene": str(reference.get("effect_scene", ""))
	}
	for field in ["uses_magic_power", "cast_pattern", "projectile_count", "spread_radians", "passive_handler", "regen_delay", "hp_regen_ratio", "heal_ratio", "visual_color"]:
		if reference.has(field):
			definition[field] = reference[field]
	return definition


static func has_skill(skill_id: String) -> bool:
	if GAME_SKILLS.has(skill_id):
		return true
	return bool(_get_catalog_entry(skill_id).get("game_ready", false))


static func get_registered_skill_ids() -> Array[String]:
	var ids: Array[String] = []
	for skill_id in GAME_SKILLS.keys():
		ids.append(str(skill_id))
	for entry in _get_catalog():
		if bool(entry.get("game_ready", false)):
			ids.append(str(entry.get("id", "")))
	return ids


static func get_catalog_skill_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in _get_catalog():
		ids.append(str(entry.get("id", "")))
	return ids


static func get_champion_skill_ids(champion_id: String, include_passive: bool = true) -> Array[String]:
	var ids: Array[String] = []
	var normalized_champion_id := champion_id.to_lower()
	for entry in _get_catalog():
		if str(entry.get("champion_id", "")).to_lower() != normalized_champion_id:
			continue
		if not bool(entry.get("game_ready", false)):
			continue
		if not include_passive and str(entry.get("cast_type", "")) == "passive":
			continue
		ids.append(str(entry.get("id", "")))
	return ids

static func get_game_skills(skill_ids: Array) -> Dictionary:
	var result: Dictionary = {}
	for skill_id in skill_ids:
		var definition := get_skill(str(skill_id))
		if not definition.is_empty():
			result[str(skill_id)] = definition
	return result

static func get_catalog() -> Array[Dictionary]:
	return _get_catalog().duplicate(true)


static func _get_catalog() -> Array[Dictionary]:
	if _catalog_loaded:
		return _catalog_cache
	_catalog_loaded = true
	if not FileAccess.file_exists(CATALOG_PATH):
		return _catalog_cache
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		return _catalog_cache
	var json_text := file.get_as_text().trim_prefix("\uFEFF")
	var parsed: Variant = JSON.parse_string(json_text)
	if not parsed is Dictionary:
		return _catalog_cache
	for skill in parsed.get("skills", []):
		if skill is Dictionary:
			var entry: Dictionary = skill.duplicate(true)
			_catalog_cache.append(entry)
			_catalog_index[str(entry.get("id", ""))] = entry
	return _catalog_cache


static func _get_catalog_entry(skill_id: String) -> Dictionary:
	_get_catalog()
	var entry: Variant = _catalog_index.get(skill_id, {})
	return entry.duplicate(true) if entry is Dictionary else {}

static func get_reference_skill(skill_id: String) -> Dictionary:
	return _get_catalog_entry(skill_id)
