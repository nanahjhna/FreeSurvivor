extends SceneTree

const CHARACTER_SCRIPT := preload("res://scripts/resources/character_data.gd")
const SKILL_SCRIPT := preload("res://scripts/resources/skill_data.gd")
const MONSTER_SCRIPT := preload("res://scripts/resources/monster_data.gd")
const SKILL_DATABASE := preload("res://scripts/skill_database.gd")
const MONSTER_DATABASE := preload("res://scripts/monster_database.gd")
const CARD_BATTLE_MANAGER := preload("res://scripts/card_battle_manager.gd")
const CARD_FLOORS := {1: "묘지 쥐", 2: "해골 병사", 4: "강화 뮤턴트", 5: "심연의 카드 군주"}
const CHARACTER_CLASSES := {
	"fighter": {"name": "무도가", "title": "권법 수련자", "role": "무도가", "grade": "R", "icon": "🥋", "color": Color(0.85, 0.43, 0.2), "unlocked": true, "model_scene": "res://assets/char/char05/char05_textured.glb", "model_scale": Vector3.ONE, "animation_profile": "fighter", "base_attributes": {"STR": 7, "AGI": 7, "VIT": 6, "INT": 3, "DEX": 4, "LUK": 3}, "base_hp": 120.0, "base_atk": 20.0, "base_def": 10.0, "base_spd": 6.8, "signature_skill": "쇄도 연권", "weapon_name": "권갑", "combat_style": "기동성과 근접 타격", "desc": "권갑을 두른 두 주먹과 기공으로 싸우는 무도가.", "starting_gear": {"weapon": "wpn_handwraps", "armor": "arm_leather", "accessory": null}},
	"fighter_2d": {"name": "화염권객", "title": "2D 화염권 무도가", "role": "무도가 · 2D", "grade": "R", "icon": "🔥", "color": Color(0.82, 0.32, 0.18), "unlocked": false, "model_scene": "res://assets/char/char05/char05_textured.glb", "model_scale": Vector3.ONE, "animation_profile": "fighter", "base_attributes": {"STR": 7, "AGI": 7, "VIT": 6, "INT": 3, "DEX": 4, "LUK": 3}, "base_hp": 120.0, "base_atk": 20.0, "base_def": 10.0, "base_spd": 6.8, "signature_skill": "쇄도 연권", "weapon_name": "권갑", "combat_style": "2D 스프라이트 · 기동성과 근접 타격", "appearance": "2d_sprite", "desc": "불꽃 기운을 두른 2D 무도가. 기존 무도가와 같은 조작과 스킬을 사용합니다.", "starting_gear": {"weapon": "wpn_handwraps", "armor": "arm_leather", "accessory": null}},
	"char02": {"name": "유랑 검사", "title": "쌍검 방랑자", "role": "검사", "grade": "R", "icon": "⚔️", "color": Color(0.3, 0.52, 0.72), "unlocked": true, "model_scene": "res://assets/char/char02/char02.glb", "model_scale": Vector3.ONE, "animation_profile": "char02", "base_attributes": {"STR": 7, "AGI": 8, "VIT": 5, "INT": 3, "DEX": 6, "LUK": 4}, "base_hp": 112.0, "base_atk": 21.0, "base_def": 8.0, "base_spd": 7.2, "signature_skill": "질풍 쌍검", "weapon_name": "쌍검", "combat_style": "빠른 근접 전투와 연속 베기", "appearance": "char02", "desc": "새로 추가된 3D 캐릭터 모델을 사용하는 쌍검 검사.", "starting_gear": {"weapon": "wpn_iron_sword", "armor": "arm_leather", "accessory": null}},
	"archer": {"name": "추적자", "title": "황야의 명사수", "role": "궁수", "grade": "R", "icon": "🏹", "color": Color(0.35, 0.66, 0.39), "unlocked": true, "model_scene": "res://assets/char/char01/char01.glb", "model_scale": Vector3.ONE, "animation_profile": "archer", "base_attributes": {"STR": 4, "AGI": 8, "VIT": 4, "INT": 3, "DEX": 9, "LUK": 5}, "base_hp": 105.0, "base_atk": 18.0, "base_def": 7.0, "base_spd": 7.4, "signature_skill": "관통 화살", "weapon_name": "장궁", "combat_style": "원거리 관통과 빠른 연사", "desc": "먼 거리에서 약점을 노리고 관통 사격을 가하는 황야의 사냥꾼."},
	"mage": {"name": "원소술사", "title": "잿불의 계승자", "role": "마법사", "grade": "R", "icon": "🔮", "color": Color(0.55, 0.39, 0.82), "unlocked": true, "model_scene": "res://assets/char/char03/char03.glb", "model_scale": Vector3.ONE, "animation_profile": "mage", "base_attributes": {"STR": 3, "AGI": 4, "VIT": 4, "INT": 9, "DEX": 5, "LUK": 5}, "base_hp": 100.0, "base_atk": 17.0, "base_def": 6.0, "base_spd": 6.4, "signature_skill": "화염구", "weapon_name": "원소 지팡이", "combat_style": "마법 광역 공격과 원소 폭발", "desc": "마나 없이 재사용 대기시간을 활용해 원소 마법을 연속 시전하는 마법사."},
	"paladin": {"name": "성기사", "title": "새벽의 수호자", "role": "성기사", "grade": "R", "icon": "🛡️", "color": Color(0.82, 0.65, 0.29), "unlocked": true, "model_scene": "res://assets/char/char04/char04.glb", "model_scale": Vector3.ONE, "animation_profile": "paladin", "base_attributes": {"STR": 7, "AGI": 4, "VIT": 9, "INT": 5, "DEX": 3, "LUK": 3}, "base_hp": 145.0, "base_atk": 18.0, "base_def": 14.0, "base_spd": 5.9, "signature_skill": "심판의 강타", "weapon_name": "성검과 방패", "combat_style": "높은 체력과 방어, 자가 회복", "desc": "굳건한 방패로 버티고 신성한 힘으로 자신과 주변을 지키는 수호자."}
}
const CLASS_SKILL_LOADOUTS := {
	"fighter": {"q": "fighter_q", "w": "fighter_w", "e": "fighter_e", "r": "fighter_r", "a": "fighter_volley", "s": "fighter_renewal"},
	"fighter_2d": {"q": "fighter_q", "w": "fighter_w", "e": "fighter_e", "r": "fighter_r", "a": "fighter_volley", "s": "fighter_renewal"},
	"char02": {"q": "swordsman_q", "w": "swordsman_w", "e": "swordsman_e", "r": "swordsman_r"},
	"archer": {"q": "archer_q", "w": "archer_w", "e": "archer_e", "r": "archer_r"},
	"mage": {"q": "mage_q", "w": "mage_w", "e": "mage_e", "r": "mage_r"},
	"paladin": {"q": "paladin_q", "w": "paladin_w", "e": "paladin_e", "r": "paladin_r"}
}
const CLASS_PASSIVES := {"fighter": ["fighter_passive"], "fighter_2d": ["fighter_passive"]}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for folder in ["res://data/characters", "res://data/skills", "res://data/monsters"]:
		var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		if error != OK and error != ERR_ALREADY_EXISTS:
			push_error("리소스 폴더를 만들지 못했습니다: " + folder)
			quit(1)
			return

	var catalog_entries: Array = []
	var catalog_file := FileAccess.open("res://data/skill_catalog.json", FileAccess.READ)
	if catalog_file != null:
		var parsed: Variant = JSON.parse_string(catalog_file.get_as_text().trim_prefix("\uFEFF"))
		if parsed is Dictionary:
			catalog_entries = parsed.get("skills", [])
	var skill_ids_by_legacy: Dictionary = {}
	var skill_index := 1
	for entry in catalog_entries:
		if entry is Dictionary:
			var skill := _create_catalog_skill(entry, skill_index)
			if not _save_resource(skill, "res://data/skills/skill%02d.tres" % skill_index):
				quit(1)
				return
			skill_ids_by_legacy[str(entry.get("id", ""))] = skill.id
			skill_index += 1

	var game_skills: Dictionary = SKILL_DATABASE.GAME_SKILLS
	for legacy_id in game_skills:
		var skill := _create_game_skill(str(legacy_id), game_skills[legacy_id], skill_index)
		if not _save_resource(skill, "res://data/skills/skill%02d.tres" % skill_index):
			quit(1)
			return
		skill_ids_by_legacy[str(legacy_id)] = skill.id
		skill_index += 1

	var class_ids: Array = CHARACTER_CLASSES.keys()
	class_ids.sort()
	var character_index := 1
	for class_id_value in class_ids:
		var class_id := str(class_id_value)
		var source: Dictionary = CHARACTER_CLASSES[class_id]
		var character := CHARACTER_SCRIPT.new() as Resource
		character.set("id", "char%02d" % character_index)
		character.set("legacy_id", class_id)
		character.set("display_name", str(source.get("name", class_id)))
		character.set("title", str(source.get("title", "")))
		character.set("role", str(source.get("role", class_id)))
		character.set("grade", str(source.get("grade", "R")))
		character.set("icon", str(source.get("icon", "⚔️")))
		character.set("color", source.get("color", Color.WHITE))
		character.set("unlocked", bool(source.get("unlocked", true)))
		var model_path := str(source.get("model_scene", ""))
		character.set("model_scene", load(model_path) as PackedScene if not model_path.is_empty() else null)
		character.set("model_scale", source.get("model_scale", Vector3.ONE))
		character.set("animation_profile", str(source.get("animation_profile", "")))
		var attributes: Dictionary = source.get("base_attributes", {})
		for attribute in ["STR", "AGI", "VIT", "INT", "DEX", "LUK"]:
			character.set("base_" + attribute.to_lower(), int(attributes.get(attribute, 1)))
		for pair in [["base_hp", "base_hp"], ["base_atk", "base_atk"], ["base_def", "base_def"], ["base_spd", "base_spd"]]:
			character.set(str(pair[0]), float(source.get(str(pair[1]), 0.0)))
		var assigned_skills: Array[String] = []
		var old_skill_ids: Array = CLASS_PASSIVES.get(class_id, [])
		old_skill_ids.append_array(CLASS_SKILL_LOADOUTS.get(class_id, {}).values())
		for old_skill_id in old_skill_ids:
			var canonical_skill_id := str(skill_ids_by_legacy.get(str(old_skill_id), ""))
			if not canonical_skill_id.is_empty():
				assigned_skills.append(canonical_skill_id)
		character.set("skill_ids", assigned_skills)
		var old_loadout: Dictionary = CLASS_SKILL_LOADOUTS.get(class_id, {})
		var canonical_loadout: Dictionary = {}
		for slot in old_loadout:
			var canonical_skill_id := str(skill_ids_by_legacy.get(str(old_loadout[slot]), ""))
			if not canonical_skill_id.is_empty():
				canonical_loadout[str(slot)] = canonical_skill_id
		character.set("skill_loadout", canonical_loadout)
		character.set("signature_skill", str(source.get("signature_skill", "")))
		character.set("weapon_name", str(source.get("weapon_name", "")))
		character.set("combat_style", str(source.get("combat_style", "")))
		character.set("description", str(source.get("desc", "")))
		character.set("appearance", str(source.get("appearance", "")))
		character.set("starting_gear", source.get("starting_gear", {"weapon": null, "armor": null, "accessory": null}))
		if not _save_resource(character, "res://data/characters/char%02d.tres" % character_index):
			quit(1)
			return
		character_index += 1

	var monster_ids: Array = MONSTER_DATABASE.MONSTERS.keys()
	monster_ids.sort()
	var monster_index := 1
	var infected_scene := str(MONSTER_DATABASE.MONSTERS.get("infected", {}).get("scene", ""))
	for old_monster_id in monster_ids:
		var source: Dictionary = MONSTER_DATABASE.MONSTERS[old_monster_id]
		var monster := _create_monster(str(old_monster_id), source, monster_index)
		if not _save_resource(monster, "res://data/monsters/monster%02d.tres" % monster_index):
			quit(1)
			return
		monster_index += 1

	var card_enemies: Dictionary = CARD_BATTLE_MANAGER.ENEMIES
	var card_floors: Array = card_enemies.keys()
	card_floors.sort()
	for floor in card_floors:
		var source: Dictionary = card_enemies[floor]
		var card_monster := _create_monster("card_enemy_%d" % floor, {
			"name": CARD_FLOORS.get(floor, "카드 던전 적"), "scene": infected_scene,
			"hp": float(source.get("hp", 1)), "speed": 0.0, "damage": 0.0,
			"range": 0.0, "interval": 0.0, "xp": 0, "gold": 0,
			"potion_chance": 0.0, "icon": str(source.get("icon", "👾")),
			"grade": "던전", "desc": "턴제 카드 던전에서 사용하는 적 데이터."
		}, monster_index)
		card_monster.set("card_floor", int(floor))
		card_monster.set("card_hp", int(source.get("hp", 1)))
		card_monster.set("card_icon", str(source.get("icon", "👾")))
		var pattern: Array[Dictionary] = []
		for intent in source.get("pattern", []):
			if intent is Dictionary:
				pattern.append(intent.duplicate(true))
		card_monster.set("card_pattern", pattern)
		if not _save_resource(card_monster, "res://data/monsters/monster%02d.tres" % monster_index):
			quit(1)
			return
		monster_index += 1

	print("REGISTRY_RESOURCES_CREATED characters=%d skills=%d monsters=%d" % [character_index - 1, skill_index - 1, monster_index - 1])
	quit(0)


func _create_catalog_skill(source: Dictionary, index: int) -> Resource:
	var skill := SKILL_SCRIPT.new() as Resource
	skill.set("id", "skill%02d" % index)
	skill.set("legacy_id", str(source.get("id", "")))
	skill.set("champion_id", str(source.get("champion_id", "")))
	skill.set("champion_name", str(source.get("champion", "")))
	skill.set("slot_key", str(source.get("key", "")))
	skill.set("reference_name", str(source.get("reference_name", "")))
	skill.set("reference_description", str(source.get("reference_description", "")))
	skill.set("display_name", str(source.get("game_name", source.get("reference_name", ""))))
	skill.set("description", str(source.get("reference_description", "")))
	skill.set("icon_url", str(source.get("icon_url", "")))
	skill.set("mana_cost", 0)
	_apply_skill_values(skill, source)
	return skill


func _create_game_skill(legacy_id: String, source: Dictionary, index: int) -> Resource:
	var skill := SKILL_SCRIPT.new() as Resource
	skill.set("id", "skill%02d" % index)
	skill.set("legacy_id", legacy_id)
	skill.set("display_name", str(source.get("name", legacy_id)))
	skill.set("reference_name", str(source.get("name", legacy_id)))
	skill.set("description", str(source.get("desc", "")))
	skill.set("reference_description", str(source.get("desc", "")))
	skill.set("icon", str(source.get("icon", "✨")))
	_apply_skill_values(skill, source)
	return skill


func _apply_skill_values(skill: Resource, source: Dictionary) -> void:
	skill.set("cost", int(source.get("cost_base", 0)))
	skill.set("cooldown", float(source.get("base_cd", 0.0)))
	skill.set("damage_ratio", float(source.get("base_dmg_ratio", 0.0)))
	skill.set("cooldown_step", float(source.get("cd_step", 0.0)))
	skill.set("damage_step", float(source.get("dmg_step", 0.0)))
	skill.set("range", float(source.get("range", 10.0)))
	skill.set("unlock_level", int(source.get("unlock_level", 1)))
	skill.set("cast_type", str(source.get("cast_type", "unassigned")))
	skill.set("bonus_type", str(source.get("bonus_type", "physical")))
	var effect_path := str(source.get("effect_scene", ""))
	skill.set("effect_scene", load(effect_path) as PackedScene if not effect_path.is_empty() else null)
	var color_text := str(source.get("visual_color", "#ffffff"))
	skill.set("effect_color", Color.from_string(color_text, Color.WHITE))
	skill.set("uses_magic_power", bool(source.get("uses_magic_power", false)))
	skill.set("cast_pattern", str(source.get("cast_pattern", "")))
	skill.set("projectile_count", int(source.get("projectile_count", 1)))
	skill.set("spread_radians", float(source.get("spread_radians", 0.0)))
	skill.set("heal_ratio", float(source.get("heal_ratio", 0.0)))
	skill.set("passive_handler", str(source.get("passive_handler", "")))
	skill.set("regen_delay", float(source.get("regen_delay", 0.0)))
	skill.set("hp_regen_ratio", float(source.get("hp_regen_ratio", 0.0)))
	var cast_type := str(source.get("cast_type", "unassigned"))
	var default_ready := cast_type in ["wave", "volley", "spin", "flame", "burst", "heal", "passive"] and (not effect_path.is_empty() or cast_type in ["heal", "passive"])
	skill.set("implemented", bool(source.get("game_ready", default_ready)))
	skill.set("support_status", str(source.get("game_support_status", "game_skill" if default_ready else "unimplemented")))


func _create_monster(legacy_id: String, source: Dictionary, index: int) -> Resource:
	var monster := MONSTER_SCRIPT.new() as Resource
	monster.set("id", "monster%02d" % index)
	monster.set("legacy_id", legacy_id)
	monster.set("display_name", str(source.get("name", legacy_id)))
	var scene_path := str(source.get("scene", ""))
	monster.set("model_scene", load(scene_path) as PackedScene if not scene_path.is_empty() else null)
	monster.set("hp", float(source.get("hp", 1.0)))
	monster.set("speed", float(source.get("speed", 1.0)))
	monster.set("damage", float(source.get("damage", 1.0)))
	monster.set("attack_range", float(source.get("range", 1.5)))
	monster.set("attack_interval", float(source.get("interval", 1.0)))
	monster.set("xp", int(source.get("xp", 0)))
	monster.set("gold", int(source.get("gold", 0)))
	monster.set("loot", {"gold": int(source.get("gold", 0)), "xp": int(source.get("xp", 0)), "potion_chance": float(source.get("potion_chance", 0.0))})
	monster.set("is_boss", bool(source.get("is_boss", false)))
	monster.set("potion_chance", float(source.get("potion_chance", 0.0)))
	monster.set("visual_scale", source.get("visual_scale", Vector3.ONE))
	monster.set("collision_scale", source.get("collision_scale", Vector3.ONE))
	monster.set("fall_on_death", bool(source.get("fall_on_death", true)))
	monster.set("icon", str(source.get("icon", "👾")))
	monster.set("grade", str(source.get("grade", "보스" if bool(source.get("is_boss", false)) else "일반")))
	monster.set("description", str(source.get("desc", "")))
	return monster


func _save_resource(resource: Resource, path: String) -> bool:
	var error := ResourceSaver.save(resource, path)
	if error != OK:
		push_error("ResourceSaver 오류 %s: %s" % [error, path])
		return false
	return true
