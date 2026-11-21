extends SceneTree

const CHARACTER_PATH := "res://data/characters/char01.tres"
const EXTRA_SKILL_NAMES := ["정조준 사격", "숲의 숨결", "쌍연 화살", "천궁 화살비"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var character := load(CHARACTER_PATH) as CharacterData
	if character == null:
		push_error("char01.tres를 읽지 못했습니다.")
		quit(1)
		return
	var retained: Array[SkillData] = []
	for skill in character.skills:
		if skill != null and not EXTRA_SKILL_NAMES.has(skill.display_name):
			retained.append(skill)
	character.skills = retained
	character.animation_aliases.merge({
		"AttackBase": ["Bow_Release_RT", "Bow_Shoot_RT", "Bow_Attack_RT", "Attack"],
		"Cast": ["Bow_Pull_Back_RT", "Bow_Release_RT", "Bow_Shoot_RT", "Cast"],
		"Dodge": ["Dodge_RT", "Roll_RT", "Dodge"],
		"Block": ["Blocking_RT", "Block_RT", "Block"],
		"Knockdown": ["Livershot_Knockdown_RT", "Knockdown", "Fall"],
		"Fall": ["Livershot_Knockdown_RT", "Knockdown", "Fall"],
		"GetUp": ["Get_Up_RT", "Getting_Up_RT", "Stand_Up_RT", "GetUp"],
		"Jump": ["Jump_RT", "Jump"],
		"Victory": ["Victory_1_RT", "Victory_RT", "Victory"]
	}, true)
	_add_active_skill(character, {
		"name": EXTRA_SKILL_NAMES[0], "slot": "a", "icon": "🎯",
		"desc": "정확하게 겨냥해 적 하나를 꿰뚫는 강화 화살을 쏩니다.",
		"cooldown": 10.0, "damage": 2.8, "range": 18.0, "unlock": 3,
		"cast_type": "wave", "animation": "Attack", "scene": "res://scenes/skills/sword_wave.tscn"
	})
	_add_active_skill(character, {
		"name": EXTRA_SKILL_NAMES[1], "slot": "s", "icon": "🌿",
		"desc": "자연의 기운을 모아 최대 체력의 28%를 회복합니다.",
		"cooldown": 26.0, "damage": 0.0, "range": 0.0, "unlock": 1,
		"cast_type": "heal", "animation": "Cast", "heal": 0.28
	})
	_add_active_skill(character, {
		"name": EXTRA_SKILL_NAMES[2], "slot": "", "icon": "🏹",
		"desc": "전방을 향해 세 발의 화살을 빠르게 연속 발사합니다.",
		"cooldown": 11.0, "damage": 0.78, "range": 17.0, "unlock": 5,
		"cast_type": "volley", "animation": "AttackAlt", "scene": "res://scenes/skills/sword_wave.tscn",
		"count": 3, "spread": 0.24, "pattern": "fan"
	})
	_add_active_skill(character, {
		"name": EXTRA_SKILL_NAMES[3], "slot": "", "icon": "☄️",
		"desc": "넓은 범위에 강력한 화살비를 쏟아붓습니다.",
		"cooldown": 32.0, "damage": 4.6, "range": 12.0, "unlock": 10,
		"cast_type": "burst", "animation": "Cast", "scene": "res://scenes/skills/explosion.tscn"
	})
	var error := ResourceSaver.save(character, CHARACTER_PATH)
	if error != OK:
		push_error("char01 스킬 저장 실패: %d" % error)
		quit(1)
		return
	print("CHAR01_READY skills=%d actions=%d" % [character.skills.size(), character.animation_aliases.size()])
	quit(0)


func _add_active_skill(character: CharacterData, data: Dictionary) -> void:
	var skill := SkillData.new()
	skill.resource_path = ""
	skill.id = ""
	skill.legacy_id = ""
	skill.slot_key = str(data.get("slot", ""))
	skill.reference_name = str(data.get("name", "스킬"))
	skill.display_name = skill.reference_name
	skill.reference_description = str(data.get("desc", ""))
	skill.description = skill.reference_description
	skill.icon = str(data.get("icon", "🏹"))
	skill.cooldown = float(data.get("cooldown", 8.0))
	skill.damage_ratio = float(data.get("damage", 1.0))
	skill.range = float(data.get("range", 10.0))
	skill.unlock_level = int(data.get("unlock", 1))
	skill.cast_type = str(data.get("cast_type", "wave"))
	skill.animation_key = str(data.get("animation", "AttackAlt"))
	skill.bonus_type = "physical"
	skill.cost = 0
	skill.mana_cost = 0
	skill.heal_ratio = float(data.get("heal", 0.0))
	skill.projectile_count = int(data.get("count", 1))
	skill.spread_radians = float(data.get("spread", 0.0))
	skill.cast_pattern = str(data.get("pattern", ""))
	var effect_path := str(data.get("scene", ""))
	if not effect_path.is_empty():
		skill.effect_scene = load(effect_path) as PackedScene
	skill.implemented = true
	skill.support_status = "game_skill"
	character.skills.append(skill)
